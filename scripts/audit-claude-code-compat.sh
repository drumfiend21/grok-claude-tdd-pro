#!/usr/bin/env bash
# scripts/audit-claude-code-compat.sh — Claude Code host-CLI version compat audit
#
# Per TICKET-031 / ADR-0036. Reads `claude --version`, parses the semver, and
# compares against the supported_range declared in docs/claude-code-compat.yaml.
# Mirrors the plugin-pin drift-detect pattern (scripts/sync-plugin.sh --check).
#
# Usage:
#   scripts/audit-claude-code-compat.sh           # human-readable summary
#   scripts/audit-claude-code-compat.sh --quiet   # exit code only
#   scripts/audit-claude-code-compat.sh --version <semver>   # check supplied version (testing)
#
# Exit codes:
#   0  detected version is inside supported_range (or claude CLI unavailable; WARN-not-FAIL)
#   1  detected version is outside supported_range (regression)
#   2  error (compat file missing, parse failure)
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
VERSION_OVERRIDE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --quiet) QUIET=1; shift ;;
        --version) VERSION_OVERRIDE="$2"; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-claude-code-compat.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

COMPAT_FILE="docs/claude-code-compat.yaml"
[ -f "$COMPAT_FILE" ] || { printf 'audit-claude-code-compat.sh: %s missing\n' "$COMPAT_FILE" >&2; exit 2; }

# Extract semver values from YAML (jq/yq-free; bash 3.2 portable).
extract_yaml_scalar() {
    grep -E "^[[:space:]]*$2:" "$1" | head -1 | sed -E 's/^[[:space:]]*[a-z_]+:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'
}

MIN=$(extract_yaml_scalar "$COMPAT_FILE" min)
MAX=$(extract_yaml_scalar "$COMPAT_FILE" max)
if [ -z "$MIN" ] || [ -z "$MAX" ]; then
    printf 'audit-claude-code-compat.sh: could not parse min/max from %s\n' "$COMPAT_FILE" >&2
    exit 2
fi

# Detect running version.
if [ -n "$VERSION_OVERRIDE" ]; then
    DETECTED="$VERSION_OVERRIDE"
elif command -v claude >/dev/null 2>&1; then
    DETECTED=$(claude --version 2>/dev/null | head -1 | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
else
    emit "[claude-code-compat] WARN: 'claude' CLI not on PATH; compat check skipped."
    emit "  supported_range: $MIN <= version < $MAX (per $COMPAT_FILE)"
    exit 0
fi

if [ -z "$DETECTED" ]; then
    emit "[claude-code-compat] WARN: could not parse semver from 'claude --version' output; compat check skipped."
    exit 0
fi

# Semver compare via awk (bash 3.2 portable).
# Returns: 0 if a == b, -1 if a < b, 1 if a > b
semver_cmp() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        n=split(a, A, ".")
        split(b, B, ".")
        for (i=1; i<=3; i++) {
            ai = (i <= n ? A[i]+0 : 0)
            bi = B[i]+0
            if (ai < bi) { print -1; exit }
            if (ai > bi) { print 1; exit }
        }
        print 0
    }'
}

cmp_min=$(semver_cmp "$DETECTED" "$MIN")
cmp_max=$(semver_cmp "$DETECTED" "$MAX")

# In-range: DETECTED >= MIN AND DETECTED < MAX
if [ "$cmp_min" -ge 0 ] && [ "$cmp_max" -lt 0 ]; then
    emit "[claude-code-compat] OK — $DETECTED is inside supported_range ($MIN <= version < $MAX)."
    exit 0
fi

emit "[claude-code-compat] WARN — $DETECTED is OUTSIDE supported_range ($MIN <= version < $MAX)."
emit "  Per $COMPAT_FILE notes: run smoke-e2e + test-all; if green, write an ADR bumping the range."
emit "  Per architecture-principles §15: bumping the range requires an ADR."
exit 1
