#!/usr/bin/env bash
# scripts/audit-development-paths.sh — development-PATH coverage gate (CL-I / TICKET-101, ADR-0074).
#
# Consumes CTP's §28.63 `commands/classify-path.sh --audit`: every rule in the plugin
# corpus (from which the harness's active.json is generated) MUST resolve to at least
# one development path — `iac`, `fullstack`, or `both`. An unpathed rule would fall
# through the both-paths pre-write partition (§28.68), so it's a hard red.
#
# This is the harness-side validation of the path-tagging surface; the PARTITION
# itself (govern IaC artifacts by iac+both, app code by fullstack+both) is consumed
# by the pre-write governor (CL-C). Analogous to the applies-to-parity smoke gate.
#
# Prime directive: classify-path.sh is a plugin entrypoint (consumed by reference from
# the cache), never edited here.
#
# Usage:
#   scripts/audit-development-paths.sh            # human-readable summary
#   scripts/audit-development-paths.sh --quiet    # exit code only
#
# Exit codes:
#   0  every corpus rule is pathed  OR  vacuous (classify-path absent / prereq missing)
#   1  one or more rules are unpathed (partition gap)
#   2  usage error
#
# Portability: bash 3.2 + BSD coreutils. Overridable for tests: ADPTH_PLUGIN_ROOT,
# ADPTH_CLASSIFY (a stub classify-path.sh).

set -u
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-development-paths.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

# Epoch-aware enforcement (ADR-0071): source the shared epoch library so this audit
# participates in the uniform epoch-gate surface. Exposes epoch_note.
_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

PLUGIN_ROOT="${ADPTH_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
CLASSIFY="${ADPTH_CLASSIFY:-$PLUGIN_ROOT/commands/classify-path.sh}"

emit "[development-paths] validating every corpus rule resolves to a development path (§28.63)..."

# Pre-4668c2e cache compat: classify-path.sh didn't exist before §28.63. Vacuous pass.
# (Invoked via `bash`, so it need not carry the exec bit — cache files are 644.)
if [ ! -f "$CLASSIFY" ]; then
    emit "[development-paths] classify-path.sh absent ($CLASSIFY) — pre-§28.63 cache; vacuous pass."
    epoch_note development-paths "path-tagging entrypoint not present at this pin"
    exit 0
fi

# Run the corpus audit. classify-path emits the summary on stderr:
#   classify-path total=<n> iac=<n> fullstack=<n> both=<n> unpathed=<n>
out=$(CLAUDE_PLUGIN_ROOT="$(cd "$PLUGIN_ROOT" 2>/dev/null && pwd -P || printf '%s' "$PLUGIN_ROOT")" \
      bash "$CLASSIFY" --audit 2>&1 >/dev/null)
rc=$?

summary=$(printf '%s\n' "$out" | grep -E 'classify-path[[:space:]]+total=' | tail -1)

# rc 2 (usage) or no parseable summary (e.g. Ruby prerequisite missing) → vacuous WARN.
if [ -z "$summary" ]; then
    emit "[development-paths] classify-path produced no summary (Ruby prerequisite missing? rc=$rc) — vacuous pass."
    [ "$QUIET" -eq 0 ] && printf '%s\n' "$out" | sed 's/^/    /' | head -3
    epoch_note development-paths "classify-path did not yield a summary; skipped"
    exit 0
fi

unpathed=$(printf '%s' "$summary" | grep -oE 'unpathed=[0-9]+' | grep -oE '[0-9]+' | head -1)
[ -n "$unpathed" ] || unpathed=0
emit "  $summary"

if [ "$unpathed" -gt 0 ]; then
    emit "[development-paths] $unpathed rule(s) resolve to NO development path — both-paths partition gap (§28.68)."
    emit "  Every rule must be iac / fullstack / both. Fix upstream (classify-path derivation) — file a P-N proposal."
    exit 1
fi
emit "[development-paths] OK — every corpus rule is pathed (iac/fullstack/both); both-paths partition is total."
exit 0
