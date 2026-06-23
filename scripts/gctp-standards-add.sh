#!/usr/bin/env bash
# scripts/gctp-standards-add.sh — ADR-0069 W-F operator-facing wrapper for the CTP
# auto-classification + custom-rule drafting pipeline (CTP-ADR-0009).
#
# WHY THIS EXISTS. CTP ships the pipeline (extract → classify → route → draft →
# review-queue) as commands/* under the plugin tree. The harness exposes a single
# learnable operator command (`gctp standards add`) that wraps it and adds the
# operator-workflow spine GCTP owns per ADR-0069 D-A:
#
#   1. Validate the source is declared in .harness/operator-standards/namespaces.yaml
#      (W-I — declared-source-only ingest; rejects ad-hoc URLs before any LLM cost).
#   2. Surface a cost estimate (best-effort) before starting.
#   3. Confirm operator over --budget-usd when present.
#   4. Invoke the CTP pipeline end-to-end.
#   5. Hand off to `gctp standards review` after the queue populates.
#
# Prime-directive boundary: this wrapper invokes CTP commands but never modifies
# CTP code. CTP owns the pipeline; GCTP owns the operator-workflow spine.
# No-rewrites discipline (ADR-0070): this script CREATES `.harness/operator-standards/`
# tree (operator-supplied data, not pre-existing harness state); it never modifies
# `.harness/handoffs/*`.
#
# Usage:
#   scripts/gctp-standards-add.sh --source-id <id> --url <url> [--shape <doc-shape>]
#                                 [--budget-usd <max>] [--auto-accept] [--quiet]
#
#     --source-id     id from .harness/operator-standards/namespaces.yaml (required)
#     --url           the source URL or local file path (required)
#     --shape         markdown-headings (default) | numbered-list — per CTP extract shape
#     --budget-usd    advisory cap; if exceeded, operator confirmation requested
#     --auto-accept   pass-through to review-queue; auto-stages high-confidence rules
#     --quiet         minimal output
#
# Env overrides (testability):
#   GSA_PLUGIN_ROOT     default .harness/plugin-cache/claude-tdd-pro
#   GSA_OPERATOR_DIR    default .harness/operator-standards
#   GSA_NAMESPACES      default $GSA_OPERATOR_DIR/namespaces.yaml
#   GSA_PIPELINE_CMD    default $GSA_PLUGIN_ROOT/commands  (extract-/classify-/route-/draft-/review-queue.sh)
#   GSA_PRICE_PER_RULE  default 0.10 (USD; rough estimate per rule for budget preview)
#   GSA_NONINTERACTIVE  set to 1 to skip operator confirmation prompts (test mode)
#
# Exit codes:
#   0  pipeline completed; rules in review queue
#   1  source unknown / namespaces.yaml missing the declared source
#   2  bad invocation / required CLI args missing
#   3  budget exceeded + operator declined to proceed
#   4  CTP pipeline error (one of the 5 stages exited non-zero)
#
# Portability: bash 3.2 + BSD coreutils; node for JSON parsing; ruby for YAML.

set -u

QUIET=0; SOURCE_ID=""; URL=""; SHAPE="markdown-headings"; BUDGET=""; AUTO=0
while [ $# -gt 0 ]; do
    case "$1" in
        --source-id)    SOURCE_ID="${2-}"; shift 2 ;;
        --url)          URL="${2-}"; shift 2 ;;
        --shape)        SHAPE="${2-}"; shift 2 ;;
        --budget-usd)   BUDGET="${2-}"; shift 2 ;;
        --auto-accept)  AUTO=1; shift ;;
        --quiet)        QUIET=1; shift ;;
        -h|--help)      sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'gctp-standards-add.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
err()  { printf '%s\n' "$*" >&2; }

[ -n "$SOURCE_ID" ] || { err "gctp-standards-add: --source-id required"; exit 2; }
[ -n "$URL" ]       || { err "gctp-standards-add: --url required"; exit 2; }

PLUGIN_ROOT="${GSA_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
OPERATOR_DIR="${GSA_OPERATOR_DIR:-.harness/operator-standards}"
NAMESPACES="${GSA_NAMESPACES:-$OPERATOR_DIR/namespaces.yaml}"
PIPELINE_CMD="${GSA_PIPELINE_CMD:-$PLUGIN_ROOT/commands}"
PRICE_PER_RULE="${GSA_PRICE_PER_RULE:-0.10}"
NONINTERACTIVE="${GSA_NONINTERACTIVE:-0}"

command -v node >/dev/null 2>&1 || { err "gctp-standards-add: node required"; exit 2; }

# Step 1: validate the source is declared in namespaces.yaml.
if [ ! -f "$NAMESPACES" ]; then
    err "gctp-standards-add: $NAMESPACES not found."
    err "  Create .harness/operator-standards/namespaces.yaml first with at least:"
    err "    sources:"
    err "      - id: $SOURCE_ID"
    err "        url: $URL"
    err "        namespace: <ns>"
    err "  See docs/operator-runbook.md §Adding standards from a URL."
    exit 1
fi

decl=$(GSA_NS="$NAMESPACES" GSA_SID="$SOURCE_ID" node -e '
const fs=require("fs");
const ns=fs.readFileSync(process.env.GSA_NS,"utf8");
// minimal YAML: look for "- id: <sid>" line under sources:
const lines=ns.split("\n");
let inSources=false, found=false;
for (const l of lines) {
  if (/^sources\s*:/.test(l)) { inSources=true; continue; }
  if (inSources) {
    const m=l.match(/^\s*-\s*id\s*:\s*([\w\-.]+)\s*$/);
    if (m && m[1]===process.env.GSA_SID) { found=true; break; }
  }
}
process.stdout.write(found?"OK":"MISSING");
')
if [ "$decl" != "OK" ]; then
    err "gctp-standards-add: source-id '$SOURCE_ID' not declared in $NAMESPACES."
    err "  Add a row under 'sources:' for this id before re-running."
    err "  Per ADR-0069 D-A: declared-source-only ingest (prevents ad-hoc LLM cost)."
    exit 1
fi

# Step 2: extract first (to count rules → cost preview).
EXTRACT="$PIPELINE_CMD/extract-rules-from-url.sh"
[ -x "$EXTRACT" ] || { err "gctp-standards-add: pipeline missing extract entry: $EXTRACT (run scripts/sync-plugin.sh --ensure)"; exit 4; }

emit "[gctp-standards-add] extracting candidate rules from $URL (shape=$SHAPE)..."
EXTRACT_OUT="$OPERATOR_DIR/.cache/$SOURCE_ID.extract.json"
mkdir -p "$(dirname "$EXTRACT_OUT")"
if ! CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$EXTRACT" --source "$URL" --shape "$SHAPE" --source-id "$SOURCE_ID" --json > "$EXTRACT_OUT" 2>/dev/null; then
    err "gctp-standards-add: extract stage failed (see $EXTRACT_OUT for partial output)"
    exit 4
fi

RULES_COUNT=$(node -e '
let s=""; process.stdin.on("data",d=>s+=d); process.stdin.on("end",()=>{
  try { const a=JSON.parse(s); process.stdout.write(String(Array.isArray(a)?a.length:0)); }
  catch(e) { process.stdout.write("0"); }
});' < "$EXTRACT_OUT")

emit "[gctp-standards-add] extracted $RULES_COUNT candidate rule(s) from $SOURCE_ID."

# Step 3: cost preview + budget check.
EST_COST=$(node -e "process.stdout.write(($RULES_COUNT * $PRICE_PER_RULE).toFixed(2))")
emit "[gctp-standards-add] estimated LLM cost: \$$EST_COST (at \$$PRICE_PER_RULE/rule × $RULES_COUNT rules)"

if [ -n "$BUDGET" ]; then
    over=$(node -e "process.stdout.write($EST_COST > $BUDGET ? 'OVER' : 'OK')")
    if [ "$over" = "OVER" ]; then
        emit "[gctp-standards-add] WARNING: estimated cost \$$EST_COST exceeds --budget-usd \$$BUDGET."
        if [ "$NONINTERACTIVE" -eq 1 ]; then
            err "[gctp-standards-add] non-interactive mode + budget exceeded → declining."
            exit 3
        fi
        printf 'Proceed anyway? [y/N] ' >&2
        read -r ans </dev/tty || ans=""
        case "$ans" in y|Y|yes|YES) ;; *) emit "[gctp-standards-add] aborted by operator."; exit 3 ;; esac
    fi
fi

# Step 4: run classify → route → draft → review-queue.
emit "[gctp-standards-add] classifying $RULES_COUNT candidate rule(s)..."
CLASSIFY_OUT="$OPERATOR_DIR/.cache/$SOURCE_ID.classify.json"
if ! CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PIPELINE_CMD/classify-rule.sh" --in "$EXTRACT_OUT" --json > "$CLASSIFY_OUT" 2>/dev/null; then
    err "gctp-standards-add: classify stage failed"
    exit 4
fi

emit "[gctp-standards-add] routing classified rules to FOSS tools..."
ROUTE_OUT="$OPERATOR_DIR/.cache/$SOURCE_ID.route.json"
if ! CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PIPELINE_CMD/route-rule.sh" --in "$CLASSIFY_OUT" --json > "$ROUTE_OUT" 2>/dev/null; then
    err "gctp-standards-add: route stage failed"
    exit 4
fi

emit "[gctp-standards-add] drafting custom rules (LLM)..."
DRAFT_OUT="$OPERATOR_DIR/.cache/$SOURCE_ID.draft.json"
if ! CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PIPELINE_CMD/draft-custom-rule.sh" --in "$ROUTE_OUT" --json > "$DRAFT_OUT" 2>/dev/null; then
    err "gctp-standards-add: draft stage failed"
    exit 4
fi

emit "[gctp-standards-add] routing to review queue..."
AUTO_FLAG=""; [ "$AUTO" -eq 1 ] && AUTO_FLAG="--auto-accept"
if ! CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PIPELINE_CMD/review-queue.sh" --in "$DRAFT_OUT" $AUTO_FLAG --json >"$OPERATOR_DIR/.cache/$SOURCE_ID.queue.json" 2>/dev/null; then
    err "gctp-standards-add: review-queue stage failed"
    exit 4
fi

emit ""
emit "[gctp-standards-add] OK — pipeline completed for $SOURCE_ID."
emit "  Queue file: $OPERATOR_DIR/.cache/$SOURCE_ID.queue.json"
emit "  Next: bash scripts/gctp-standards-review.sh --list"
emit "        (or bash scripts/gctp-standards-review.sh --batch-accept --confidence high)"

exit 0
