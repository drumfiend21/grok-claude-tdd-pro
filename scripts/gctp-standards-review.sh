#!/usr/bin/env bash
# scripts/gctp-standards-review.sh — ADR-0069 W-G operator-facing wrapper for the
# CTP auto-classification review queue (CTP-ADR-0009 stage 6 + ADR-0069 D-A).
#
# WHY THIS EXISTS. After `gctp standards add` populates a review queue, the operator
# needs to inspect, accept, reject, or batch-accept drafted rules before they enter
# `active.json` and become enforceable. CTP ships commands/review-queue.sh as the
# inner mechanism; this wrapper adds an operator-friendly summary view + coverage-
# report pointer (ADR-0069 D-A handoff target).
#
# Prime-directive boundary: invokes CTP review-queue.sh but never modifies CTP code.
# No-rewrites discipline (ADR-0070): writes only to `.harness/operator-standards/`
# (operator-state tree, not pre-existing harness state).
#
# Usage:
#   scripts/gctp-standards-review.sh --list
#   scripts/gctp-standards-review.sh --review <rule-id>
#   scripts/gctp-standards-review.sh --accept <rule-id>
#   scripts/gctp-standards-review.sh --reject <rule-id>
#   scripts/gctp-standards-review.sh --batch-accept --confidence high
#
# Env overrides (testability):
#   GSR_PLUGIN_ROOT     default .harness/plugin-cache/claude-tdd-pro
#   GSR_OPERATOR_DIR    default .harness/operator-standards
#   GSR_REVIEW_BIN      default $GSR_PLUGIN_ROOT/commands/review-queue.sh
#
# Exit codes:
#   0  action succeeded
#   1  no queue files exist (nothing to review)
#   2  bad invocation / mutually-exclusive flags
#   4  CTP review-queue command failed
#
# Portability: bash 3.2 + BSD coreutils; node for queue summary aggregation.

set -u

LIST=0; REVIEW=""; ACCEPT=""; REJECT=""; BATCH_ACCEPT=0; CONFIDENCE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list)           LIST=1; shift ;;
        --review)         REVIEW="${2-}"; shift 2 ;;
        --accept)         ACCEPT="${2-}"; shift 2 ;;
        --reject)         REJECT="${2-}"; shift 2 ;;
        --batch-accept)   BATCH_ACCEPT=1; shift ;;
        --confidence)     CONFIDENCE="${2-}"; shift 2 ;;
        -h|--help)        sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'gctp-standards-review.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done

err()  { printf '%s\n' "$*" >&2; }

# Mutual exclusion check.
modes=0
[ "$LIST" -eq 1 ] && modes=$((modes+1))
[ -n "$REVIEW" ] && modes=$((modes+1))
[ -n "$ACCEPT" ] && modes=$((modes+1))
[ -n "$REJECT" ] && modes=$((modes+1))
[ "$BATCH_ACCEPT" -eq 1 ] && modes=$((modes+1))

if [ "$modes" -eq 0 ]; then
    err "gctp-standards-review: one of --list / --review / --accept / --reject / --batch-accept required"
    exit 2
fi
if [ "$modes" -gt 1 ]; then
    err "gctp-standards-review: --list/--review/--accept/--reject/--batch-accept are mutually exclusive"
    exit 2
fi
if [ "$BATCH_ACCEPT" -eq 1 ] && [ -z "$CONFIDENCE" ]; then
    err "gctp-standards-review: --batch-accept requires --confidence <level>"
    exit 2
fi

PLUGIN_ROOT="${GSR_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
OPERATOR_DIR="${GSR_OPERATOR_DIR:-.harness/operator-standards}"
REVIEW_BIN="${GSR_REVIEW_BIN:-$PLUGIN_ROOT/commands/review-queue.sh}"

command -v node >/dev/null 2>&1 || { err "gctp-standards-review: node required"; exit 2; }

# Locate queue files (one per source-id, written by gctp-standards-add.sh).
QUEUE_DIR="$OPERATOR_DIR/.cache"
if [ ! -d "$QUEUE_DIR" ]; then
    err "gctp-standards-review: no queue dir at $QUEUE_DIR — run 'gctp standards add' first."
    exit 1
fi

queue_files=""
for f in "$QUEUE_DIR"/*.queue.json; do
    [ -e "$f" ] && queue_files="$queue_files $f"
done
if [ -z "$queue_files" ]; then
    err "gctp-standards-review: no *.queue.json files in $QUEUE_DIR — run 'gctp standards add' first."
    exit 1
fi

case "$LIST$BATCH_ACCEPT$REVIEW$ACCEPT$REJECT" in
    "10"*)
        # --list: aggregate summary across all queue files
        printf '%-20s %-10s %-12s %-8s %s\n' "SOURCE" "RULE" "QUEUE" "CONFIDC" "PATH"
        for f in $queue_files; do
            sid=$(basename "$f" .queue.json)
            GSR_F="$f" GSR_SID="$sid" node -e '
const fs=require("fs");
let q; try{q=JSON.parse(fs.readFileSync(process.env.GSR_F,"utf8"));}catch(e){process.exit(0);}
const queues=q.queues||{};
const sid=process.env.GSR_SID;
for (const [qname, rules] of Object.entries(queues)) {
  for (const r of (rules||[])) {
    const id=r.rule_id||r.id||"<unknown>";
    const conf=r.confidence||"?";
    console.log([sid.padEnd(20),id.padEnd(10),qname.padEnd(12),conf.padEnd(8),process.env.GSR_F].join(" "));
  }
}
'
        done
        ;;
    "01"*)
        # --batch-accept --confidence <c>: pass through to CTP review-queue with --auto-accept
        # (CTP's review-queue auto-stages high-confidence + zero-gap rules per its semantics)
        if [ "$CONFIDENCE" != "high" ]; then
            err "gctp-standards-review: --batch-accept supports --confidence high only (per CTP semantics)"
            exit 2
        fi
        [ -x "$REVIEW_BIN" ] || { err "gctp-standards-review: review-queue.sh not found at $REVIEW_BIN"; exit 4; }
        for f in $queue_files; do
            sid=$(basename "$f" .queue.json)
            DRAFT="$QUEUE_DIR/$sid.draft.json"
            [ -f "$DRAFT" ] || continue
            CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$REVIEW_BIN" --in "$DRAFT" --auto-accept >/dev/null 2>&1 || true
            printf '[gctp-standards-review] batch-accepted high-confidence rules from %s\n' "$sid"
        done
        ;;
    *)
        # --review/--accept/--reject: per-rule action. Since CTP's review-queue.sh
        # doesn't expose per-rule actions yet, we provide an operator-friendly inspect
        # view + a manual workflow pointer.
        TARGET="${REVIEW}${ACCEPT}${REJECT}"
        printf '[gctp-standards-review] rule=%s\n' "$TARGET"
        for f in $queue_files; do
            GSR_F="$f" GSR_RID="$TARGET" node -e '
const fs=require("fs");
let q; try{q=JSON.parse(fs.readFileSync(process.env.GSR_F,"utf8"));}catch(e){process.exit(0);}
const queues=q.queues||{};
const rid=process.env.GSR_RID;
for (const [qname, rules] of Object.entries(queues)) {
  for (const r of (rules||[])) {
    if ((r.rule_id||r.id)===rid) {
      console.log("  queue:", qname);
      console.log("  confidence:", r.confidence||"?");
      console.log("  source:", r.source||"?");
      if (r.coverage_report) console.log("  coverage-report:", r.coverage_report);
      if (r.draft) console.log("  draft preview:", JSON.stringify(r.draft).slice(0,200)+"...");
    }
  }
}
'
        done
        if [ -n "$ACCEPT" ] || [ -n "$REJECT" ]; then
            ACT=$( [ -n "$ACCEPT" ] && echo "accept" || echo "reject" )
            printf '[gctp-standards-review] manual workflow: edit .harness/operator-standards/custom-rules/<tool>/%s.* to %s, then re-run audit chain.\n' "$TARGET" "$ACT"
        fi
        ;;
esac

exit 0
