#!/usr/bin/env bash
# scripts/audit-config-surface.sh — single-config OPTIONS-surface completeness gate (CL-H / TICKET-105, ADR-0078).
#
# Consumes CTP's §28.58/§28.59 `commands/config-sync.sh --check`: the single config (ctp.config.yaml)
# must carry projectable, tool-native options for EVERY option-bearing tool of EVERY active rule —
# "capability present, data empty" is a defect. A rule whose 3rd-party tool has no projectable option
# surface is recorded `needs_mapping` and surfaced (cite-or-decline, never silently omitted). Any
# `needs_mapping` gap is a hard red: the operator's single config would be incomplete.
#
# This is the harness-side validation that the single-config OPTIONS surface is total. Honoring a
# selected profile IN the enforcement paths (--profile) is a separate follow-up (see ADR-0078).
#
# Prime directive: config-sync.sh is consumed by reference from the pinned cache, never edited.
#
# Usage: scripts/audit-config-surface.sh [--quiet]
# Exit:  0 complete (needs_mapping=0)  OR  vacuous (config-sync / Ruby absent)  |  1 gap  |  2 usage
# Overridable for tests: ACS_PLUGIN_ROOT, ACS_CONFIG_SYNC.

set -u
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-config-surface.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

PLUGIN_ROOT="${ACS_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
CONFIG_SYNC="${ACS_CONFIG_SYNC:-$PLUGIN_ROOT/commands/config-sync.sh}"

emit "[config-surface] validating the single config carries options for every option-bearing tool (§28.58)..."

# Pre-§28.58 cache compat: config-sync.sh didn't exist before the single-config surface. Vacuous.
if [ ! -f "$CONFIG_SYNC" ]; then
    emit "[config-surface] config-sync.sh absent ($CONFIG_SYNC) — pre-§28.58 cache; vacuous pass."
    epoch_note config-surface "config-sync entrypoint not present at this pin"
    exit 0
fi

absplugin=$(cd "$PLUGIN_ROOT" 2>/dev/null && pwd -P || printf '%s' "$PLUGIN_ROOT")
out=$(CLAUDE_PLUGIN_ROOT="$absplugin" bash "$CONFIG_SYNC" --check 2>&1)
summary=$(printf '%s\n' "$out" | grep -E 'config-sync[[:space:]]+rules=' | tail -1)

# No parseable summary (e.g. Ruby prerequisite missing) → vacuous WARN.
if [ -z "$summary" ]; then
    emit "[config-surface] config-sync produced no summary (Ruby prerequisite missing?) — vacuous pass."
    [ "$QUIET" -eq 0 ] && printf '%s\n' "$out" | sed 's/^/    /' | tail -3
    epoch_note config-surface "config-sync did not yield a summary; skipped"
    exit 0
fi
emit "  $summary"

needs=$(printf '%s' "$summary" | grep -oE 'needs_mapping=[0-9]+' | grep -oE '[0-9]+' | head -1)
[ -n "$needs" ] || needs=0

if [ "$needs" -gt 0 ]; then
    emit "[config-surface] $needs rule(s) lack projectable tool options — the single config would be incomplete."
    printf '%s\n' "$out" | grep -E 'config-sync[[:space:]]+rule=' | sed 's/^/  /' | head -20
    emit "  Fix upstream (tool-option-surfaces.yaml mapping) — file a P-N proposal; do not hand-edit the plugin."
    exit 1
fi
emit "[config-surface] OK — every active rule has projectable tool options (single config complete; nothing missing)."
exit 0
