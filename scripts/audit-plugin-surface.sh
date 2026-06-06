#!/usr/bin/env bash
# scripts/audit-plugin-surface.sh — enumerate the pinned plugin's top-level
# surface and verify every directory is either CONSUMED, DECLARED-NOT-CONSUMED
# (with ADR ref), or UNKNOWN (= regression: a new plugin surface appeared and
# nobody declared its consumption status).
#
# Per TICKET-032 / ADR-0037. The structural failure mode that motivated this:
# the harness was treating the plugin as a 3-SKILL surface (cl-workflow,
# batch-cl, bash32-portability) while the plugin grew to 39+ top-level
# directories (standards/, rubric/, generated-code-quality-standards/,
# pr-corpus/, compliance/, monitors/, etc.). None of those new surfaces were
# acknowledged by the harness. This audit forces explicit acknowledgment of
# every plugin surface — either consume it or document why not.
#
# Usage:
#   scripts/audit-plugin-surface.sh           # human-readable summary
#   scripts/audit-plugin-surface.sh --quiet   # exit code only
#
# Exit codes:
#   0  every plugin surface is either CONSUMED or DECLARED-NOT-CONSUMED
#   1  one or more UNKNOWN surfaces (new plugin directory; declare consumption)
#   2  error (plugin cache missing or registry file missing)
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies.

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-plugin-surface.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

PLUGIN_CACHE=".harness/plugin-cache/claude-tdd-pro"
REGISTRY="docs/plugin-surface-consumption.md"

[ -d "$PLUGIN_CACHE" ] || { printf 'plugin cache missing: %s (run sync-plugin.sh --ensure)\n' "$PLUGIN_CACHE" >&2; exit 2; }
[ -f "$REGISTRY" ]      || { printf 'consumption registry missing: %s\n' "$REGISTRY" >&2; exit 2; }

emit "[plugin-surface] scanning $PLUGIN_CACHE top-level entries..."

unknowns=0
consumed=0
declared=0
total=0

for entry in "$PLUGIN_CACHE"/*; do
    name=$(basename "$entry")
    # Skip files at root (registry lists directories + top-level docs only by name).
    total=$((total + 1))

    # Match against the registry: a line that contains | <name> |
    if grep -qE "^\| \`?${name}\`? \|" "$REGISTRY" 2>/dev/null; then
        # Determine status by checking the registry row for status markers.
        row=$(grep -E "^\| \`?${name}\`? \|" "$REGISTRY" | head -1)
        case "$row" in
            *"DECLARED-NOT-CONSUMED"*) declared=$((declared + 1)) ;;
            *"CONSUMED"*)              consumed=$((consumed + 1)) ;;
            *)                          unknowns=$((unknowns + 1)); emit "  [UNKNOWN-STATUS] $name (listed in registry but no CONSUMED/DECLARED-NOT-CONSUMED marker)" ;;
        esac
    else
        unknowns=$((unknowns + 1))
        emit "  [UNKNOWN] $name — not declared in $REGISTRY"
    fi
done

emit ""
emit "[plugin-surface] summary:"
emit "  total entries:           $total"
emit "  CONSUMED:                $consumed"
emit "  DECLARED-NOT-CONSUMED:   $declared"
emit "  UNKNOWN:                 $unknowns"

if [ "$unknowns" -gt 0 ]; then
    emit ""
    emit "[plugin-surface] $unknowns surface(s) are UNKNOWN. Add a row to $REGISTRY for each:"
    emit "  | <name> | CONSUMED via <path> | -- |  ← if the harness consumes it"
    emit "  | <name> | DECLARED-NOT-CONSUMED | ADR-XXXX |  ← if explicitly not consumed"
    exit 1
fi

emit "[plugin-surface] OK — every plugin surface is declared."
exit 0
