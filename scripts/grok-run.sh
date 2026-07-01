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
#   scripts/grok-run.sh <phase> [--input k=v]... [--effort low|medium|high] [--dry-run] [--quiet]
#     <phase> ∈ research | decomposition | dispatch  (→ .grok/templates/<phase>.md)
#   --dry-run : emit a contract-valid STUB result without calling grok (testable w/o CLI+key)
#
# Exit codes (§14): 0 success-with-structured-output · 2 usage · 3 preflight (no grok/key)
#                   4 grok invocation failed / non-JSON output
#
# Overridable for tests: GROK_BIN (the CLI), GROK_RUNS_DIR, GROK_TEMPLATES_DIR.
# Portability: bash 3.2 + BSD coreutils. Auth (XAI_API_KEY) is read from the env only, never
# printed, never written to disk (G-2).

set -u

PHASE=""; DRY=0; QUIET=0; EFFORT=""
INPUTS=""
while [ $# -gt 0 ]; do
    case "$1" in
        research|decomposition|dispatch) PHASE="$1"; shift ;;
        --input) INPUTS="${INPUTS}${2}
"; shift 2 ;;
        --effort) EFFORT="${2:-}"; shift 2 ;;
        --dry-run) DRY=1; shift ;;
        --quiet) QUIET=1; shift ;;
        -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'grok-run.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done
emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*" >&2; return 0; }
[ -n "$PHASE" ] || { printf 'grok-run.sh: a phase (research|decomposition|dispatch) is required\n' >&2; exit 2; }

_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
TEMPLATES_DIR="${GROK_TEMPLATES_DIR:-$_DIR/.grok/templates}"
RUNS_DIR="${GROK_RUNS_DIR:-$_DIR/.harness/runs}"
GROK_BIN="${GROK_BIN:-grok}"
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
    printf '{"run_id":"%s","phase":"%s","event":"%s","status":"%s","effort":"%s","prompt_hash":"%s","stub":%s%s}\n' \
        "$RUN_ID" "$PHASE" "$1" "$2" "$EFFORT" "$PROMPT_HASH" "$STUBBED" "${3:-}" >> "$LOG" 2>/dev/null || true
}

# --- the ISOLATED grok invocation (single point of truth for CLI flags) ------
# Documented contract (§1, §14, .grok/templates/README): `grok -p` reads a self-contained prompt
# and returns Structured Output; `--output-format json`; auth via XAI_API_KEY env. If the real
# CLI's flags differ, THIS is the one line to correct (G-21 tolerant reader covers the rest).
_grok_invoke() {  # stdin: compiled prompt ; stdout: structured JSON ; return: grok's exit
    "$GROK_BIN" -p --output-format json --effort "$EFFORT"
}

# --- preflight (G-2) ---------------------------------------------------------
STUBBED=false
have_grok=0; command -v "$GROK_BIN" >/dev/null 2>&1 && have_grok=1
have_key=0; [ -n "${XAI_API_KEY:-}" ] && have_key=1

if [ "$DRY" -eq 1 ] || [ "$have_grok" -eq 0 ] || [ "$have_key" -eq 0 ]; then
    # STUB path (contract-valid, no network). Used for --dry-run and whenever the runtime is
    # absent — mirrors TICKET-006's stub-default. NEVER a silent success: the log + banner say stub.
    if [ "$DRY" -eq 0 ]; then
        [ "$have_grok" -eq 0 ] && emit "[grok-run] grok CLI not found (install from x.ai/cli) — STUB result."
        [ "$have_key" -eq 0 ]  && emit "[grok-run] XAI_API_KEY not set (G-2) — STUB result."
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
emit "[grok-run] $PHASE — live grok -p (effort=$EFFORT, run=$RUN_ID)..."
_log start running ""
out=$(_grok_invoke < "$compiled") ; rc=$?
if [ "$rc" -ne 0 ]; then
    _log complete failed ",\"exit\":$rc"
    emit "[grok-run] grok exited $rc — see $LOG"
    exit 4
fi
# Structured output must be JSON (G-3) — fail loudly if not.
if ! printf '%s' "$out" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{JSON.parse(d);}catch(e){process.exit(1);}});' 2>/dev/null; then
    _log complete failed ",\"reason\":\"non-json output\""
    emit "[grok-run] grok output was not valid JSON (G-3 violation) — see $LOG"
    exit 4
fi
printf '%s\n' "$out"
_log complete green ""
emit "[grok-run] $PHASE — OK (run $RUN_ID; structured output; log $LOG)."
exit 0
