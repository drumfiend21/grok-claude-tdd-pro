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
#   --model     : run on a cheaper/faster model (also GROK_MODEL env). If it fails to produce
#                 valid structured output, the runner escalates ONCE to the standing default
#                 model with the reason recorded in the run log (G-20 — no silent escalation,
#                 and escalation only ever raises capability). Default: unset → the standing
#                 default model, GROK_DEFAULT_MODEL (grok-4.3 — the §2 general-agentic-reasoning
#                 pick; the CLI's own non-reasoning default rejects the G-4-mandated --effort).
#   --fresh     : bypass G-19 result reuse and re-invoke grok
#
# Cost controls (TICKET-110 / ADR-0082 — all quality-preserving):
#   • G-19 result reuse — an identical DISPATCH (same phase+prompt+effort+model) returns the
#     recorded output of the prior green run byte-for-byte without re-invoking grok; announced
#     on stderr + logged as "cached", never silent. research/decomposition stay FRESH by default
#     (G-17 freshness); opt into TTL-bound reuse with GROK_REUSE_TTL_SECONDS=<secs>.
#     GROK_REUSE=0 disables all reuse. A different --effort/--model is a different cache slot,
#     so an explicit quality ask always runs live.
#   • G-15 usage capture — real token usage (parsed from the CLI debug meta) is recorded in the
#     run log AND a day-keyed ledger (.harness/runs/usage-ledger.jsonl), and printed per run.
#   • --cwd isolation — the CLI runs in an empty scratch dir (GROK_WORKDIR), never the repo:
#     the agentic session context injection measured ~26k input tokens/run in-repo vs ~13k
#     isolated (~1k non-cached). The §14 self-contained prompt makes that injection pure cost.
#   • DAILY BUDGET GATE (G-13) — once today's ledger reaches GROK_DAILY_BUDGET_UNITS (default
#     150000 ≈ $0.5–1.5/day at typical flagship rates; units = fresh-in + cached/10 +
#     5×(out+reasoning)), live runs are REFUSED (exit 3) until the operator raises the budget
#     or sets GROK_BUDGET_OVERRIDE=1. Stubs, --dry-run, and cached re-runs are free, never blocked.
#
# Exit codes (§14): 0 success-with-structured-output · 2 usage · 3 preflight (no grok/key)
#                   or daily budget reached · 4 grok invocation failed / non-JSON output
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
# The standing default is an explicit REASONING model (§2: "Grok 4.3 for general agentic
# reasoning"; TICKET-111): the CLI's own default (grok-4.20-*-non-reasoning at go-live) rejects
# --effort, which G-4 mandates. MODEL (--model / GROK_MODEL) requests a cheaper model; empty
# means DEFAULT_MODEL. G-20 escalation goes cheap-model → DEFAULT_MODEL.
DEFAULT_MODEL="${GROK_DEFAULT_MODEL:-grok-4.3}"
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
        -h|--help) sed -n '2,58p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
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
# Compile the self-contained prompt (§14): the template body + a structured inputs block +
# the byte-stable (G-5) headless transport contract. The footer exists because the real CLI
# (verified at go-live, TICKET-111) is an agentic session runner: without it the model tries
# tool calls (e.g. persisting the handoff itself), which headless mode cancels
# (cancellationCategory=PermissionCancelled). Under §14 the harness owns all persistence;
# Grok's job in `-p` mode is to EMIT the phase document as its reply text.
HEADLESS_FOOTER='## Headless transport contract (runner-appended; G-2/§14)
You are running as ONE headless `-p` invocation. Do NOT invoke any tool, do NOT read or write
any file, do NOT persist anything — the harness owns all disk writes and will persist your
output. Reply with EXACTLY ONE JSON document (the phase output defined above) as your message
text: no markdown fences, no prose before or after.'
compiled=$(mktemp -t grok-prompt.XXXXXX) || exit 4
trap 'rm -f -- "$compiled"' EXIT INT TERM
{ cat "$TEMPLATE"; printf '\n\n## Inputs\n%s' "$INPUTS"; printf '\n%s\n' "$HEADLESS_FOOTER"; } > "$compiled"
PROMPT_HASH=$(_sha < "$compiled")
# run-id is deterministic on (phase + prompt hash) so re-runs are idempotent (G-19) and stable
# without wall-clock (which the harness forbids in scripts that must be replayable).
RUN_ID="${PHASE}-$(printf '%s' "$PROMPT_HASH" | cut -c1-12)"

mkdir -p "$RUNS_DIR" 2>/dev/null || true
LOG="$RUNS_DIR/$RUN_ID.jsonl"

_log() { # $1=event $2=status $3=extra-json
    printf '{"run_id":"%s","phase":"%s","event":"%s","status":"%s","effort":"%s","model":"%s","prompt_hash":"%s","stub":%s%s}\n' \
        "$RUN_ID" "$PHASE" "$1" "$2" "$EFFORT" "${EFFECTIVE_MODEL:-}" "$PROMPT_HASH" "$STUBBED" "${3:-}" >> "$LOG" 2>/dev/null || true
}

# --- the ISOLATED grok invocation (single point of truth for CLI flags) ------
# Verified against the real CLI at go-live (grok 0.2.81, TICKET-111 — the flag check ADR-0080
# deferred): `-p, --single <PROMPT>` takes the prompt as its VALUE (not stdin), so the compiled
# prompt is read off our stdin contract and passed as the argument; `--output-format json` is a
# documented headless value; `--effort low|medium|high` and `--model <id>` are native flags.
# Auth via XAI_API_KEY env (G-2). If a future CLI version's flags differ, THIS is the one
# function to correct (G-21 tolerant reader covers the rest).
_grok_invoke() {  # $1: model override or "" (= DEFAULT_MODEL) ; stdin: compiled prompt ; stdout: structured JSON
    _prompt=$(cat)
    # --cwd ISOLATION + --tools "" (TICKET-112): run in an empty scratch dir, never the repo,
    # with the built-in tool surface REMOVED. The CLI is an agentic session runner that injects
    # the working directory's context into EVERY -p call (measured ~26k input tokens/run
    # in-repo → ~13k isolated → ~11.7k with tools off; ~1k non-cached) and whose model would
    # otherwise non-deterministically attempt tool calls, which headless mode cancels
    # (PermissionCancelled). §14 makes the compiled prompt fully self-contained and the harness
    # owns all persistence (G-1/G-7), so pure generation is the contract — tools are pure cost
    # + flakiness here. --debug-file is the only surface where this CLI reports usage (G-15).
    "$GROK_BIN" -p "$_prompt" --output-format json --effort "$EFFORT" --model "${1:-$DEFAULT_MODEL}" \
        --cwd "$GROK_WORKDIR" --tools "" --debug-file "$GROK_DEBUG_FILE"
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
EFFECTIVE_MODEL="${MODEL:-$DEFAULT_MODEL}"
CACHE_KEY=$(printf '%s|%s' "$EFFORT" "$EFFECTIVE_MODEL" | _sha | cut -c1-8)
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

# --- daily budget gate (TICKET-112 / G-13) ------------------------------------
# Live runs are METERED: every green run's measured usage lands in the day-keyed ledger, and a
# new live run is REFUSED once today's spend reaches GROK_DAILY_BUDGET_UNITS. Units approximate
# billable input-token equivalents: fresh-input ×1, cached-input ×1/10, output+reasoning ×5.
# The default (150000/day) keeps a heavy architecting day in the ~$0.5–1.5 range at typical
# flagship rates. Overage needs the operator's explicit GROK_BUDGET_OVERRIDE=1 (G-13 HITL on
# spend thresholds). Stubs, --dry-run, and G-19 cached re-runs are free and never blocked.
LEDGER="$RUNS_DIR/usage-ledger.jsonl"
TODAY=$(date +%Y-%m-%d 2>/dev/null || echo unknown)
BUDGET="${GROK_DAILY_BUDGET_UNITS:-150000}"
spent=0
if [ -f "$LEDGER" ]; then
    spent=$(TODAY="$TODAY" node -e 'const fs=require("fs");let t=0;for(const l of fs.readFileSync(process.argv[1],"utf8").split("\n")){if(!l.trim())continue;try{const o=JSON.parse(l);if(o.date===process.env.TODAY)t+=(o.units||0);}catch(e){}}console.log(t);' "$LEDGER" 2>/dev/null || echo 0)
fi
if [ "$spent" -ge "$BUDGET" ] 2>/dev/null && [ "${GROK_BUDGET_OVERRIDE:-0}" != "1" ]; then
    _log complete budget-blocked ",\"spent_units\":$spent,\"budget_units\":$BUDGET"
    emit "[grok-run] DAILY BUDGET REACHED — $spent of $BUDGET units already spent today; live run refused (G-13)."
    emit "[grok-run] Raise GROK_DAILY_BUDGET_UNITS, or set GROK_BUDGET_OVERRIDE=1 to approve this overage. G-19 cached re-runs remain free."
    exit 3
fi

# Isolated CLI working dir + the usage-reporting debug file (see _grok_invoke). The workdir
# MUST live outside the repo tree — a dir inside it (even an empty one) lets the CLI walk up,
# detect the repo, and re-inject the very context the isolation removes (measured live).
_RM_WORKDIR=0
if [ -z "${GROK_WORKDIR:-}" ]; then
    GROK_WORKDIR=$(mktemp -d -t grok-cwd.XXXXXX) || exit 4
    _RM_WORKDIR=1
fi
GROK_DEBUG_FILE=$(mktemp -t grok-debug.XXXXXX) || exit 4
trap 'rm -f -- "$compiled"; [ -n "${GROK_DEBUG_FILE:-}" ] && rm -f -- "$GROK_DEBUG_FILE"; [ "${_RM_WORKDIR:-0}" = "1" ] && rm -rf -- "$GROK_WORKDIR"; :' EXIT INT TERM

# --- LIVE path (G-2/G-3/§14) -------------------------------------------------
emit "[grok-run] $PHASE — live grok -p (effort=$EFFORT, model=$EFFECTIVE_MODEL, run=$RUN_ID)..."
_log start running ""
# Validate + extract the phase's structured output (G-3, G-21 tolerant reader; TICKET-111).
# The real CLI wraps the reply in an envelope {text, stopReason, ...}: a completed turn is
# stopReason=EndTurn and the phase JSON lives in .text (a cancelled/permission-cancelled turn
# has empty text and MUST fail — never reach stdout or the reuse cache). Output with no .text
# field is treated as the structured output itself (tolerant: covers direct-JSON emitters).
# stdin: raw CLI stdout → stdout: phase JSON ; exit 0 ok / 2 non-json / 3 turn-not-completed.
_extract() {
    node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
        let o; try{o=JSON.parse(d);}catch(e){process.exit(2);}
        if(o && typeof o==="object" && typeof o.text==="string"){
            if(o.stopReason && o.stopReason!=="EndTurn"){process.exit(3);}
            try{JSON.parse(o.text);}catch(e){process.exit(2);}
            process.stdout.write(o.text);
        } else { process.stdout.write(d); }
    });' 2>/dev/null
}
_attempt_fail() { # sets $final + $fail from one attempt's $out/$rc
    fail=""
    if [ "$rc" -ne 0 ]; then fail="exit $rc"; return 0; fi
    final=$(printf '%s' "$out" | _extract); xrc=$?
    case "$xrc" in
        0) : ;;
        3) fail="turn not completed (cancelled)" ;;
        *) fail="non-json output" ;;
    esac
    return 0
}
final=""
out=$(_grok_invoke "$MODEL" < "$compiled") ; rc=$?
_attempt_fail
if [ -n "$fail" ] && [ "$EFFECTIVE_MODEL" != "$DEFAULT_MODEL" ]; then
    # G-20: the cheaper requested model failed structured output — escalate ONCE to the
    # standing default (stronger) model, with the reason recorded. Never silent; only raises
    # capability.
    _log escalate running ",\"from_model\":\"$MODEL\",\"reason\":\"$fail\""
    emit "[grok-run] model $MODEL failed ($fail) — escalating to $DEFAULT_MODEL (G-20, recorded)."
    out=$(_grok_invoke "" < "$compiled") ; rc=$?
    _attempt_fail
fi
if [ -n "$fail" ]; then
    case "$fail" in
        "exit "*)
            _log complete failed ",\"exit\":$rc"
            emit "[grok-run] grok exited $rc — see $LOG" ;;
        *)
            _log complete failed ",\"reason\":\"$fail\""
            emit "[grok-run] grok produced no valid structured output ($fail; G-3 violation) — see $LOG" ;;
    esac
    exit 4
fi
# G-15: record token usage (TICKET-112). This CLI reports usage only in the debug meta (the
# json envelope has none); parse the LAST session/prompt meta (= final attempt). Tolerant:
# absent numbers → fall back to an envelope usage object if a future CLI adds one; else omit.
usage_extra=""
in_t=$(grep -o '"inputTokens":[0-9]*' "$GROK_DEBUG_FILE" 2>/dev/null | tail -1 | grep -o '[0-9]*$'); in_t=${in_t:-0}
out_t=$(grep -o '"outputTokens":[0-9]*' "$GROK_DEBUG_FILE" 2>/dev/null | tail -1 | grep -o '[0-9]*$'); out_t=${out_t:-0}
cached_t=$(grep -o '"cachedReadTokens":[0-9]*' "$GROK_DEBUG_FILE" 2>/dev/null | tail -1 | grep -o '[0-9]*$'); cached_t=${cached_t:-0}
reas_t=$(grep -o '"reasoningTokens":[0-9]*' "$GROK_DEBUG_FILE" 2>/dev/null | tail -1 | grep -o '[0-9]*$'); reas_t=${reas_t:-0}
if [ "$in_t" -gt 0 ] 2>/dev/null; then
    fresh=$((in_t - cached_t)); [ "$fresh" -lt 0 ] && fresh=0
    units=$((fresh + cached_t / 10 + (out_t + reas_t) * 5))
    usage_extra=",\"usage\":{\"input\":$in_t,\"cached\":$cached_t,\"output\":$out_t,\"reasoning\":$reas_t,\"units\":$units}"
    printf '{"date":"%s","run_id":"%s","phase":"%s","model":"%s","input":%s,"cached":%s,"output":%s,"reasoning":%s,"units":%s}\n' \
        "$TODAY" "$RUN_ID" "$PHASE" "$EFFECTIVE_MODEL" "$in_t" "$cached_t" "$out_t" "$reas_t" "$units" >> "$LEDGER" 2>/dev/null || true
    emit "[grok-run] usage: in=$in_t (cached $cached_t) out=$out_t reasoning=$reas_t → $units units; today $((spent + units))/$BUDGET units."
else
    u=$(printf '%s' "$out" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const o=JSON.parse(d);if(o&&typeof o==="object"&&o.usage)process.stdout.write(JSON.stringify(o.usage));}catch(e){}});' 2>/dev/null)
    [ -n "$u" ] && usage_extra=",\"usage\":$u"
fi
# G-19: record the green result for idempotent reuse (structured output only — never the key;
# the runs dir is operator-local and gitignored).
printf '%s\n' "$final" > "$OUT_CACHE" 2>/dev/null || true
printf '%s\n' "$final"
_log complete green "$usage_extra"
emit "[grok-run] $PHASE — OK (run $RUN_ID; structured output; log $LOG)."
exit 0
