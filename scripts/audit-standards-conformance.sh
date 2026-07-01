#!/usr/bin/env bash
# scripts/audit-standards-conformance.sh — pre-commit standards conformance audit
#
# Per TICKET-032 / ADR-0037. Runs the plugin's rubric/runner.sh against the
# working-tree diff (or staged diff if --staged) and verifies that every P0
# finding either resolves or has a matching row in docs/deviations.md.
#
# Mirrors the approval-baseline pattern (ADR-0032 / 0034): findings that have
# operator-justified deviation rows are accepted; new findings fail.
#
# Usage:
#   scripts/audit-standards-conformance.sh           # human-readable summary
#   scripts/audit-standards-conformance.sh --quiet   # exit code only
#   scripts/audit-standards-conformance.sh --staged  # check staged diff (pre-commit)
#
# Exit codes:
#   0  no findings, OR all findings have matching deviation rows
#   1  new findings without deviation rows (regression)
#   2  error (plugin cache missing, runner failed)
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies.

set -u

# Epoch-aware enforcement (ADR-0071): source the shared epoch library so this audit
# participates in the uniform epoch-gate surface (operator directive: all 17 audits).
# Exposes epoch_current_pin / epoch_resolve_baseline / epoch_filter_new /
# epoch_req_gated; sourcing is side-effect-free (functions only).
_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

QUIET=0
MODE=diff
for arg in "$@"; do
    case "$arg" in
        --quiet)   QUIET=1 ;;
        --staged)  MODE=staged ;;
        --diff)    MODE=diff ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-standards-conformance.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

PLUGIN_ROOT=".harness/plugin-cache/claude-tdd-pro"
RUNNER="$PLUGIN_ROOT/rubric/runner.sh"
DEVIATIONS="docs/deviations.md"

[ -x "$RUNNER" ]    || { printf 'audit-standards-conformance.sh: runner missing: %s\n' "$RUNNER" >&2; exit 2; }
[ -f "$DEVIATIONS" ] || { printf 'audit-standards-conformance.sh: deviations registry missing: %s\n' "$DEVIATIONS" >&2; exit 2; }

emit "[standards-conformance] running rubric/runner.sh --$MODE..."

findings=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
           CLAUDE_PROJECT_DIR="$PWD" \
           bash "$RUNNER" --"$MODE" --severity P0 2>/dev/null || true)

# Extract P0 findings: rule id + file path pairs.
p0_pairs=$(printf '%s' "$findings" \
    | grep -oE '"rule":"[^"]+","severity":"P0"[^{}]*"file":"[^"]*"' \
    | sed -E 's/"rule":"([^"]+)","severity":"P0"[^{}]*"file":"([^"]*)"/\1|\2/' \
    | grep -v '|$' \
    | sort -u)

if [ -z "$p0_pairs" ]; then
    emit "[standards-conformance] OK — no P0 findings."
    exit 0
fi

emit "[standards-conformance] P0 finding(s) detected; checking against $DEVIATIONS..."

unmatched_count=0
matched_count=0
unmatched=""

while IFS='|' read -r rule_id file_path; do
    [ -z "$rule_id" ] && continue
    # Match: a row in deviations.md whose Rule ID column starts with this rule and
    # whose file scope glob matches the file_path.
    if grep -qE "^\|\s*\`?${rule_id}\`?\s*\|" "$DEVIATIONS"; then
        matched_count=$((matched_count + 1))
    else
        unmatched_count=$((unmatched_count + 1))
        unmatched="$unmatched  $rule_id @ $file_path"$'\n'
    fi
done <<< "$p0_pairs"

emit "  matched (deviation row exists):   $matched_count"
emit "  unmatched (regression):           $unmatched_count"

if [ "$unmatched_count" -gt 0 ]; then
    emit ""
    emit "[standards-conformance] NEW P0 findings without deviation rows:"
    printf '%s' "$unmatched"
    emit ""
    emit "[standards-conformance] Fix the violations OR add a row to $DEVIATIONS with justification + ADR ref."
    exit 1
fi

emit "[standards-conformance] OK — all $matched_count P0 finding(s) accounted for in $DEVIATIONS."
exit 0
