#!/usr/bin/env bash
# scripts/standards-refresh.sh — GCTP-side orchestrator that DRIVES CTP's source-refresh
# pipeline on a configurable cadence (per TICKET-075 / ADR-0064).
#
# WHY THIS EXISTS. Every rule GCTP enforces is derived from + cited to a first-class
# published source (OWASP, Google, NIST, SLSA, AWS Well-Architected, federal EO, …),
# SCRAPED from its live URL by CTP's pipeline. CTP ships the whole refresh machinery
# (standards/initial-refresh.sh, commands/set-refresh-frequency.sh, the m/h/d/w/mo
# cadence grammar — v1.18 §28.23) and fires it from ITS OWN install.sh + SessionStart.
# But GCTP consumes CTP as a PINNED SNAPSHOT via sync-plugin.sh --ensure and never runs
# CTP's install/hooks — so that refresh never starts in the harness. This script is the
# missing trigger: at GCTP session start it drives CTP's refresh on the operator's chosen
# cadence (default: every active day), then re-aggregates active.json. It drives CTP's
# entrypoints through the contract surface; it does NOT re-implement scraping or the
# cadence grammar (prime directive — that content is CTP's).
#
# Modes:
#   (default) / --check     session-start: refresh if the cadence is due, surface
#                           significance, and prompt for cadence if unconfigured. Non-fatal.
#   --configure <freq>      set the cadence (<N>m|h|d|w|mo or a calendar token), validated
#                           by CTP's set-refresh-frequency.sh. Writes the GCTP config.
#   --force                 refresh now regardless of cadence.
#   --status                show cadence + last refresh + whether due.
#   --significance          print the source→enforcement significance explanation.
#   --quiet                 suppress non-essential output.
#
# Config: .harness/standards-refresh.json (operator-local, gitignored; .example tracked):
#   { "schema_version":"1", "frequency":"1d", "configured":false,
#     "last_refresh_ms":<int|null>, "last_refresh_at":<iso|null> }
#
# Env overrides (testability):
#   SR_CONFIG       default .harness/standards-refresh.json
#   SR_PLUGIN_ROOT  default .harness/plugin-cache/claude-tdd-pro
#   SR_REFRESH_BIN  default $SR_PLUGIN_ROOT/standards/initial-refresh.sh   (CTP scrape entrypoint)
#   SR_SETFREQ_BIN  default $SR_PLUGIN_ROOT/commands/set-refresh-frequency.sh (CTP grammar validator)
#   SR_SYNC_BIN     default ./scripts/standards-sync.sh
#   SR_STATE_DIR    default .harness/standards-cache  (CTP freshness baseline, GCTP-local)
#   SR_NOW          override "now" as epoch SECONDS (testing)
#
# Exit codes:
#   0  ok (incl. not-due, vacuous, and session-start non-fatal)
#   2  error / invalid frequency / bad invocation
#
# Portability: bash 3.2 + BSD coreutils. node parses the JSON config.

set -u

QUIET=0; MODE="check"; CFG_FREQ=""
while [ $# -gt 0 ]; do
    case "$1" in
        --check)        MODE="check" ;;
        --force)        MODE="force" ;;
        --status)       MODE="status" ;;
        --significance) MODE="significance" ;;
        --configure)    MODE="configure"; CFG_FREQ="${2-}"; shift ;;
        --quiet)        QUIET=1 ;;
        -h|--help)      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'standards-refresh.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

SR_CONFIG="${SR_CONFIG:-.harness/standards-refresh.json}"
SR_PLUGIN_ROOT="${SR_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
SR_REFRESH_BIN="${SR_REFRESH_BIN:-$SR_PLUGIN_ROOT/standards/initial-refresh.sh}"
SR_SETFREQ_BIN="${SR_SETFREQ_BIN:-$SR_PLUGIN_ROOT/commands/set-refresh-frequency.sh}"
SR_SYNC_BIN="${SR_SYNC_BIN:-./scripts/standards-sync.sh}"
SR_STATE_DIR="${SR_STATE_DIR:-.harness/standards-cache}"

now_s() { [ -n "${SR_NOW:-}" ] && { printf '%s' "$SR_NOW"; return; }; date -u +%s; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- significance explanation (operator-facing; sources are CTP's, framing is GCTP UX) ---
print_significance() {
    emit "  Why standards refresh matters:"
    emit "    • Every rule GCTP enforces is DERIVED FROM and CITED TO a first-class published"
    emit "      source — OWASP, Google style guides, NIST, SLSA, AWS Well-Architected, the"
    emit "      federal AI EO, W3C/WCAG, web-vitals — scraped from its live URL by CTP."
    emit "    • Re-scraping on a schedule keeps enforcement TRACKING UPSTREAM: when a source"
    emit "      publishes new guidance, it becomes new enforcement automatically."
    emit "    • So your architecture + code are measured against CURRENT standards, not a"
    emit "      frozen snapshot — stale standards silently erode the quality bar."
    return 0
}

# --- cadence grammar → interval in ms (time arithmetic; the grammar AUTHORITY is CTP's
#     set-refresh-frequency.sh, used for validation in --configure). -1 = manual/never. ---
freq_to_ms() {
    case "$1" in
        daily)                 echo 86400000 ;;
        weekly)                echo 604800000 ;;
        monthly)               echo 2592000000 ;;
        quarterly)             echo 7776000000 ;;
        on-demand|any-frequency) echo -1 ;;
        *mo) n="${1%mo}"; case "$n" in ''|*[!0-9]*) echo ERR; return 1 ;; *) echo $(( n * 2592000000 )) ;; esac ;;
        *m)  n="${1%m}";  case "$n" in ''|*[!0-9]*) echo ERR; return 1 ;; *) echo $(( n * 60000 )) ;; esac ;;
        *h)  n="${1%h}";  case "$n" in ''|*[!0-9]*) echo ERR; return 1 ;; *) echo $(( n * 3600000 )) ;; esac ;;
        *d)  n="${1%d}";  case "$n" in ''|*[!0-9]*) echo ERR; return 1 ;; *) echo $(( n * 86400000 )) ;; esac ;;
        *w)  n="${1%w}";  case "$n" in ''|*[!0-9]*) echo ERR; return 1 ;; *) echo $(( n * 604800000 )) ;; esac ;;
        *) echo ERR; return 1 ;;
    esac
}

# --- config read (echo "freq|configured|last_ms") ---
read_config() {
    if [ -f "$SR_CONFIG" ] && command -v node >/dev/null 2>&1; then
        SR_CFG_F="$SR_CONFIG" node -e '
const fs=require("fs");let c={};try{c=JSON.parse(fs.readFileSync(process.env.SR_CFG_F,"utf8"));}catch(e){}
const f=(typeof c.frequency==="string"&&c.frequency)?c.frequency:"1d";
const cfg=(c.configured===true)?"1":"0";
const ms=(typeof c.last_refresh_ms==="number")?String(c.last_refresh_ms):"";
process.stdout.write(f+"|"+cfg+"|"+ms);
' 2>/dev/null && return 0
    fi
    printf '1d|0|'
}

write_config() {
    # args: frequency configured(0|1) last_ms("" or int) last_iso("" or value)
    local f="$1" cfg="$2" lms="$3" liso="$4"
    local cfgbool="false"; [ "$cfg" = "1" ] && cfgbool="true"
    local lms_json="null"; [ -n "$lms" ] && lms_json="$lms"
    local liso_json="null"; [ -n "$liso" ] && liso_json="\"$liso\""
    mkdir -p "$(dirname "$SR_CONFIG")"
    cat > "$SR_CONFIG" <<JSON
{
  "schema_version": "1",
  "frequency": "$f",
  "configured": $cfgbool,
  "last_refresh_ms": $lms_json,
  "last_refresh_at": $liso_json
}
JSON
}

# --- modes -----------------------------------------------------------------

if [ "$MODE" = "significance" ]; then
    print_significance
    exit 0
fi

if [ "$MODE" = "configure" ]; then
    [ -n "$CFG_FREQ" ] || { printf 'standards-refresh.sh: --configure requires <freq> (e.g. 30m, 6h, 1d, 1w, 1mo)\n' >&2; exit 2; }
    # Validate the cadence with CTP's grammar authority when available; else GCTP grammar.
    if [ -f "$SR_SETFREQ_BIN" ]; then
        bash "$SR_SETFREQ_BIN" "$CFG_FREQ" --config "$SR_STATE_DIR/FETCH-FREQUENCIES.yaml" >/dev/null 2>&1 \
            || { printf 'standards-refresh.sh: invalid frequency: %s (expected <N>m|h|d|w|mo or daily|weekly|monthly|quarterly|on-demand)\n' "$CFG_FREQ" >&2; exit 2; }
    else
        freq_to_ms "$CFG_FREQ" >/dev/null 2>&1 || { printf 'standards-refresh.sh: invalid frequency: %s\n' "$CFG_FREQ" >&2; exit 2; }
    fi
    parts=$(read_config); old_ms=$(printf '%s' "$parts" | cut -d'|' -f3)
    write_config "$CFG_FREQ" 1 "$old_ms" ""
    emit "[standards-refresh] cadence set to '$CFG_FREQ' → $SR_CONFIG"
    exit 0
fi

# Resolve cadence state.
parts=$(read_config)
FREQ=$(printf '%s' "$parts" | cut -d'|' -f1)
CONFIGURED=$(printf '%s' "$parts" | cut -d'|' -f2)
LAST_MS=$(printf '%s' "$parts" | cut -d'|' -f3)
INTERVAL=$(freq_to_ms "$FREQ" 2>/dev/null || echo 86400000)
NOW_MS=$(( $(now_s) * 1000 ))

# Is a refresh due?
DUE=0; REASON=""
if [ "$MODE" = "force" ]; then
    DUE=1; REASON="forced"
elif [ -z "$LAST_MS" ]; then
    DUE=1; REASON="first run (no prior refresh)"
elif [ "$INTERVAL" = "-1" ]; then
    DUE=0; REASON="manual cadence ($FREQ) — refresh only on --force"
elif [ $(( NOW_MS - LAST_MS )) -ge "$INTERVAL" ]; then
    DUE=1; REASON="cadence elapsed ($FREQ)"
else
    DUE=0; REASON="not due (within $FREQ window)"
fi

if [ "$MODE" = "status" ]; then
    emit "[standards-refresh] cadence=$FREQ configured=$CONFIGURED last_refresh_ms=${LAST_MS:-none} due=$DUE ($REASON)"
    exit 0
fi

# --check / --force
if [ "$DUE" -eq 1 ]; then
    if [ -f "$SR_REFRESH_BIN" ]; then
        emit "[standards-refresh] $REASON → scraping sources via CTP standards/initial-refresh.sh (non-fatal, offline-tolerant)…"
        mkdir -p "$SR_STATE_DIR"
        CLAUDE_PLUGIN_ROOT="$SR_PLUGIN_ROOT" bash "$SR_REFRESH_BIN" --quiet --state-dir "$SR_STATE_DIR" >/dev/null 2>&1 || true
        # Re-aggregate active.json so refreshed rules are live this session.
        [ -x "$SR_SYNC_BIN" ] && "$SR_SYNC_BIN" >/dev/null 2>&1 || true
        write_config "$FREQ" "$CONFIGURED" "$NOW_MS" "$(now_iso)"
        emit "[standards-refresh] refresh complete; active.json re-aggregated."
    else
        emit "[standards-refresh] plugin refresh entrypoint not found ($SR_REFRESH_BIN) — run scripts/sync-plugin.sh --ensure. Skipping (non-fatal)."
    fi
else
    emit "[standards-refresh] $REASON — no refresh this session (cadence=$FREQ)."
fi

# Surface significance + the config prompt (once-per-session, informational).
print_significance
if [ "$CONFIGURED" != "1" ]; then
    emit ""
    emit "  Standards-refresh cadence is at the DEFAULT (every active day, '1d')."
    emit "  To choose your own — minutes/hours/days/weeks/months:"
    emit "    ./scripts/standards-refresh.sh --configure <N>m|h|d|w|mo   (e.g. 30m · 6h · 1d · 2w · 1mo)"
    emit "  See docs/standards-refresh.md."
fi
exit 0
