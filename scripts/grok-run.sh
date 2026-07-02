#!/usr/bin/env bash
# scripts/grok-run.sh — headless Grok outer-loop runner (TICKET-108 / ADR-0080).
#
# The G-2 CONTRACT SURFACE: "Every Grok invocation MUST work in `-p` mode with XAI_API_KEY
# env-var auth; the headless path is the contract" (grok-orchestration-principles §15 G-2, §14).
# Completes the runner the `.grok/templates/README` references — TICKET-006 shipped only the
# smoke-e2e stub (live deferred per ADR-0008). Follows that same STUB-FIRST pattern: fully
# contract-valid now, live the moment the `grok` CLI + XAI_API_KEY are present.
#
# Runs one outer-loop phase (research | decomposition | dispatch) as ONE self-contained,
# stateless `grok -p` invocation (§14), captures Structured Output (G-3, JSON), tunes reasoning
# effort per phase (G-4), and emits the audit-trail record to .harness/runs/<run-id>.jsonl (G-15).
#
# Usage:
#   scripts/grok-run.sh <phase> [--input k=v]... [--effort low|medium|high] [--model <id>]
#                       [--fresh] [--dry-run] [--quiet]
#   scripts/grok-run.sh --preflight
#     <phase> ∈ research | decomposition | dispatch  (→ .grok/templates/<phase>.md)
#   --dry-run   : emit a contract-valid STUB result without calling grok (testable w/o CLI+key)
#   --preflight : report live-readiness (grok CLI + key discoverable) without any network call;
#                 exit 0 = LIVE-ready, 3 = something missing (run ./install.sh to wire it)
#   --model     : run on a cheaper/faster model (e.g. grok-4-fast; default GROK_MODEL env). If it
#                 fails to produce valid structured output, the runner escalates ONCE to the CLI's
#                 default model with the reason recorded in the run log (G-20 — no silent
#                 escalation, and escalation only ever raises capability). Default: unset → the
#                 CLI's default model; response quality unchanged.
#   --fresh     : bypass G-19 result reuse and re-invoke grok
#
# Cost controls (TICKET-110 / ADR-0082 — all quality-preserving):
#   • G-19 result reuse — an identical DISPATCH (same phase+prompt+effort+model) returns the
#     recorded output of the prior green run byte-for-byte without re-invoking grok; announced
#     on stderr + logged as "cached", never silent. research/decomposition stay FRESH by default
#     (G-17 freshness); opt into TTL-bound reuse with GROK_REUSE_TTL_SECONDS=<secs>.
#     GROK_REUSE=0 disables all reuse. A different --effort/--model is a different cache slot,
#     so an explicit quality ask always runs live.
#   • G-15 usage capture — token usage from grok's JSON response is recorded in the run log.
#
# Exit codes (§14): 0 success-with-structured-output · 2 usage · 3 preflight (no grok/key)
#                   4 grok invocation failed / non-JSON output
#
# Overridable for tests: GROK_BIN (the CLI), GROK_RUNS_DIR, GROK_TEMPLATES_DIR,
#                        GROK_ENV_FILE, GCTP_KEY_FILE.
# Portability: bash 3.2 + BSD coreutils.
#
# Auth (G-2, TICKET-109): env-var auth is the contract. If XAI_API_KEY is not already in the
# env, it is DISCOVERED from the operator-local files install.sh maintains — repo-local
# `.grok/.env` (gitignored), then `~/.config/gctp/xai_key` (chmod 600) — and exported into the
# env for the single `grok` child process. The runner only ever READS the key: never prints it,
# never writes it, never puts it in a template, a log, or an argv (argv is visible in `ps`).

set -u

PHASE=""; DRY=0; QUIET=0; EFFORT=""; PREFLIGHT=0; FRESH=0
MODEL="${GROK_MODEL:-}"
INPUTS=""
while [ $# -gt 0 ]; do
    case "$1" in
        research|decomposition|dispatch) PHASE="$1"; shift ;;
        --input) INPUTS="${INPUTS}${2}
"; shift 2 ;;
        --effort) EFFORT="${2:-}"; shift 2 ;;
        --model) MODEL="${2:-}"; shift 2 ;;
        --fresh) FRESH=1; shift ;;
        --dry-run) DRY=1; shift ;;
        --preflight) PREFLIGHT=1; shift ;;
        --quiet) QUIET=1; shift ;;
        -h|--help) sed -n '2,49p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'grok-run.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done
emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*" >&2; return 0; }
[ -n "$PHASE" ] || [ "$PREFLIGHT" -eq 1 ] || { printf 'grok-run.sh: a phase (research|decomposition|dispatch) is required\n' >&2; exit 2; }

_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
TEMPLATES_DIR="${GROK_TEMPLATES_DIR:-$_DIR/.grok/templates}"
RUNS_DIR="${GROK_RUNS_DIR:-$_DIR/.harness/runs}"
GROK_BIN="${GROK_BIN:-grok}"

# --- key discovery (TICKET-109) -----------------------------------------------
# Precedence: env XAI_API_KEY > repo-local .grok/.env > ~/.config/gctp/xai_key.
# The .env file is PARSED (sed), never sourced — a key file must not execute code.
GROK_ENV_FILE="${GROK_ENV_FILE:-$_DIR/.grok/.env}"
GCTP_KEY_FILE="${GCTP_KEY_FILE:-$HOME/.config/gctp/xai_key}"
KEY_SOURCE="env"
if [ -z "${XAI_API_KEY:-}" ] && [ -f "$GROK_ENV_FILE" ]; then
    XAI_API_KEY=$(sed -n 's/^[[:space:]]*XAI_API_KEY[[:space:]]*=[[:space:]]*//p' "$GROK_ENV_FILE" | head -n 1 | sed "s/^[\"']//; s/[\"']\$//")
    [ -n "${XAI_API_KEY:-}" ] && { export XAI_API_KEY; KEY_SOURCE=".grok/.env"; }
fi
if [ -z "${XAI_API_KEY:-}" ] && [ -f "$GCTP_KEY_FILE" ]; then
    IFS= read -r XAI_API_KEY < "$GCTP_KEY_FILE" || true
    [ -n "${XAI_API_KEY:-}" ] && { export XAI_API_KEY; KEY_SOURCE="$GCTP_KEY_FILE"; }
fi

have_grok=0; command -v "$GROK_BIN" >/dev/null 2>&1 && have_grok=1
have_key=0; [ -n "${XAI_API_KEY:-}" ] && have_key=1

# --- --preflight: readiness report, no phase, no network, never the key -------
if [ "$PREFLIGHT" -eq 1 ]; then
    if [ "$have_grok" -eq 1 ]; then printf '[grok-run] preflight: grok CLI — found\n'
    else printf '[grok-run] preflight: grok CLI — MISSING (./install.sh auto-installs it, or see x.ai/cli)\n'; fi
    if [ "$have_key" -eq 1 ]; then printf '[grok-run] preflight: XAI_API_KEY — found (source: %s)\n' "$KEY_SOURCE"
    else printf '[grok-run] preflight: XAI_API_KEY — MISSING (./install.sh asks once and persists it)\n'; fi
    if [ "$have_grok" -eq 1 ] && [ "$have_key" -eq 1 ]; then
        printf '[grok-run] preflight: outer loop is LIVE-ready\n'; exit 0
    fi
    printf '[grok-run] preflight: outer loop would run as STUB\n'; exit 3
fi

TEMPLATE="$TEMPLATES_DIR/$PHASE.md"
[ -f "$TEMPLATE" ] || { printf 'grok-run.sh: template not found: %s\n' "$TEMPLATE" >&2; exit 2; }

# Reasoning effort per phase (G-4): match to latency budget, not capability ceiling.
if [ -z "$EFFORT" ]; then
    case "$PHASE" in
        research) EFFORT="medium" ;;
        decomposition) EFFORT="medium" ;;
        dispatch) EFFORT="low" ;;
    esac
fi

# --- run identity + prompt hash (G-15) ---------------------------------------
_sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'; else sha256sum | awk '{print $1}'; fi; }
# Compile the self-contained prompt (§14): the template body + a structured inputs block.
compiled=$(mktemp -t grok-prompt.XXXXXX) || exit 4
trap 'rm -f -- "$compiled"' EXIT INT TERM
{ cat "$TEMPLATE"; printf '\n\n## Inputs\n%s' "$INPUTS"; } > "$compiled"
PROMPT_HASH=$(_sha < "$compiled")
# run-id is deterministic on (phase + prompt hash) so re-runs are idempotent (G-19) and stable
# without wall-clock (which the harness forbids in scripts that must be replayable).
RUN_ID="${PHASE}-$(printf '%s' "$PROMPT_HASH" | cut -c1-12)"

mkdir -p "$RUNS_DIR" 2>/dev/null || true
LOG="$RUNS_DIR/$RUN_ID.jsonl"

_log() { # $1=event $2=status $3=extra-json
    printf '{"run_id":"%s","phase":"%s","event":"%s","status":"%s","effort":"%s","model":"%s","prompt_hash":"%s","stub":%s%s}\n' \
        "$RUN_ID" "$PHASE" "$1" "$2" "$EFFORT" "$MODEL" "$PROMPT_HASH" "$STUBBED" "${3:-}" >> "$LOG" 2>/dev/null || true
}

# --- the ISOLATED grok invocation (single point of truth for CLI flags) ------
# Documented contract (§1, §14, .grok/templates/README): `grok -p` reads a self-contained prompt
# and returns Structured Output; `--output-format json`; auth via XAI_API_KEY env. If the real
# CLI's flags differ, THIS is the one function to correct (G-21 tolerant reader covers the rest).
_grok_invoke() {  # $1: model override or "" ; stdin: compiled prompt ; stdout: structured JSON
    if [ -n "${1:-}" ]; then
        "$GROK_BIN" -p --output-format json --effort "$EFFORT" --model "$1"
    else
        "$GROK_BIN" -p --output-format json --effort "$EFFORT"
    fi
}

# --- preflight (G-2) ---------------------------------------------------------
STUBBED=false

# --- G-19 result reuse (TICKET-110 / ADR-0082) --------------------------------
# Sits BEFORE the stub decision so an already-paid live result is usable even on a machine
# without the CLI/key. dispatch is fully idempotent (G-19; .grok/templates/README) → reuse by
# default. research/decomposition are FRESH by default (G-17 freshness is a quality property) →
# reuse only under an explicit GROK_REUSE_TTL_SECONDS opt-in. The cache slot is keyed on
# effort+model, so an explicit quality ask (--effort high / --model) never gets a lesser run's
# result. Reuse is NEVER silent: stderr banner + "cached" events in the run log.
CACHE_KEY=$(printf '%s|%s' "$EFFORT" "$MODEL" | _sha | cut -c1-8)
OUT_CACHE="$RUNS_DIR/$RUN_ID.$CACHE_KEY.out.json"
reuse=0
if [ "$DRY" -eq 0 ] && [ "$FRESH" -eq 0 ] && [ "${GROK_REUSE:-1}" != "0" ] && [ -s "$OUT_CACHE" ]; then
    case "$PHASE" in
        dispatch) reuse=1 ;;
        research|decomposition)
            ttl="${GROK_REUSE_TTL_SECONDS:-0}"
            if [ "$ttl" -gt 0 ] 2>/dev/null; then
                now=$(date +%s 2>/dev/null || echo 0)
                mt=$(stat -f %m "$OUT_CACHE" 2>/dev/null || stat -c %Y "$OUT_CACHE" 2>/dev/null || echo 0)
                if [ "$now" -gt 0 ] && [ "$mt" -gt 0 ] && [ $((now - mt)) -le "$ttl" ]; then reuse=1; fi
            fi ;;
    esac
fi
if [ "$reuse" -eq 1 ]; then
    _log start cached ""
    cat "$OUT_CACHE"
    _log complete cached ""
    emit "[grok-run] $PHASE — CACHED (G-19 idempotent reuse of run $RUN_ID; --fresh to re-invoke; log $LOG)."
    exit 0
fi

if [ "$DRY" -eq 1 ] || [ "$have_grok" -eq 0 ] || [ "$have_key" -eq 0 ]; then
    # STUB path (contract-valid, no network). Used for --dry-run and whenever the runtime is
    # absent — mirrors TICKET-006's stub-default. NEVER a silent success: the log + banner say stub.
    if [ "$DRY" -eq 0 ]; then
        [ "$have_grok" -eq 0 ] && emit "[grok-run] grok CLI not found — STUB result. ./install.sh auto-installs it (or see x.ai/cli)."
        [ "$have_key" -eq 0 ]  && emit "[grok-run] XAI_API_KEY not found in env, .grok/.env, or ~/.config/gctp/xai_key (G-2) — STUB result. ./install.sh asks once and persists it."
    fi
    STUBBED=true
    _log start stub ""
    printf '{"run_id":"%s","phase":"%s","effort":"%s","stub":true,"structured_output":{"status":"stub","note":"grok not invoked; contract-valid placeholder","phase":"%s"}}\n' \
        "$RUN_ID" "$PHASE" "$EFFORT" "$PHASE"
    _log complete stub ""
    emit "[grok-run] $PHASE — STUB (run $RUN_ID; log $LOG). Live once grok CLI + XAI_API_KEY are present."
    exit 0
fi

# --- LIVE path (G-2/G-3/§14) -------------------------------------------------
emit "[grok-run] $PHASE — live grok -p (effort=$EFFORT${MODEL:+, model=$MODEL}, run=$RUN_ID)..."
_log start running ""
# Structured output must be JSON (G-3) — checked on every attempt.
_is_json() { printf '%s' "$1" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{JSON.parse(d);}catch(e){process.exit(1);}});' 2>/dev/null; }
out=$(_grok_invoke "$MODEL" < "$compiled") ; rc=$?
fail=""
[ "$rc" -ne 0 ] && fail="exit $rc"
if [ -z "$fail" ] && ! _is_json "$out"; then fail="non-json output"; fi
if [ -n "$fail" ] && [ -n "$MODEL" ]; then
    # G-20: the cheaper requested model failed structured output — escalate ONCE to the CLI's
    # default (stronger) model, with the reason recorded. Never silent; only raises capability.
    _log escalate running ",\"from_model\":\"$MODEL\",\"reason\":\"$fail\""
    emit "[grok-run] model $MODEL failed ($fail) — escalating to the default model (G-20, recorded)."
    out=$(_grok_invoke "" < "$compiled") ; rc=$?
    fail=""
    [ "$rc" -ne 0 ] && fail="exit $rc"
    if [ -z "$fail" ] && ! _is_json "$out"; then fail="non-json output"; fi
fi
if [ -n "$fail" ]; then
    if [ "$fail" = "non-json output" ]; then
        _log complete failed ",\"reason\":\"non-json output\""
        emit "[grok-run] grok output was not valid JSON (G-3 violation) — see $LOG"
    else
        _log complete failed ",\"exit\":$rc"
        emit "[grok-run] grok exited $rc — see $LOG"
    fi
    exit 4
fi
# G-15: record token usage when grok reports it (tolerant reader — absent usage is fine, G-21).
usage_extra=""
u=$(printf '%s' "$out" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const o=JSON.parse(d);if(o&&typeof o==="object"&&o.usage)process.stdout.write(JSON.stringify(o.usage));}catch(e){}});' 2>/dev/null)
[ -n "$u" ] && usage_extra=",\"usage\":$u"
# G-19: record the green result for idempotent reuse (structured output only — never the key;
# the runs dir is operator-local and gitignored).
printf '%s\n' "$out" > "$OUT_CACHE" 2>/dev/null || true
printf '%s\n' "$out"
_log complete green "$usage_extra"
emit "[grok-run] $PHASE — OK (run $RUN_ID; structured output; log $LOG)."
exit 0
