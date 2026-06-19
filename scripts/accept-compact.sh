#!/usr/bin/env bash
# scripts/accept-compact.sh — record operator acceptance of the GCTP agent
# operating compact (docs/agent-operating-compact.md).
#
# Per TICKET-068 / ADR-0057. The compact is a TIER-1 behavioral binding on the
# agent that drives GCTP. The operator must accept it before the harness may be
# used for the user's product; acceptance is a tracked artifact at
# .harness/agent-compact-ack.json, keyed to the compact's content hash so that
# ANY amendment to the compact invalidates the prior acceptance (re-acceptance
# is then required — "prompted on installation" generalized to "on change").
#
# Writes (idempotent — overwrites the ack each run, which IS re-acceptance):
#   .harness/agent-compact-ack.json
#     { "accepted": true, "compact_path": "...", "compact_sha256": "...",
#       "accepted_by": "...", "accepted_at": "<ISO-8601 UTC>",
#       "adr": "ADR-0057" }
#
# Usage:
#   scripts/accept-compact.sh                 # accept as git user.email (or "operator")
#   scripts/accept-compact.sh --by "name"     # override the recorded identity
#   scripts/accept-compact.sh --quiet         # exit code only
#
# Env overrides (testability):
#   AC_COMPACT   default docs/agent-operating-compact.md
#   AC_ACK       default .harness/agent-compact-ack.json
#
# Exit codes:
#   0  acceptance recorded
#   1  compact file missing / unreadable (cannot accept what is not present)
#   2  error (bad invocation / no sha256 tool)
#
# Portability: bash 3.2 + BSD coreutils. sha256 via sha256sum OR shasum -a 256.

set -u

QUIET=0
BY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --quiet) QUIET=1 ;;
        --by)    shift; BY="${1:-}" ;;
        -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'accept-compact.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

COMPACT="${AC_COMPACT:-docs/agent-operating-compact.md}"
ACK="${AC_ACK:-.harness/agent-compact-ack.json}"

if [ ! -r "$COMPACT" ]; then
    printf 'accept-compact.sh: compact not found or unreadable: %s\n' "$COMPACT" >&2
    exit 1
fi

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        return 1
    fi
}

HASH=$(sha256_of "$COMPACT") || { printf 'accept-compact.sh: no sha256 tool (sha256sum/shasum)\n' >&2; exit 2; }

if [ -z "$BY" ]; then
    BY=$(git config user.email 2>/dev/null || true)
    [ -z "$BY" ] && BY="operator"
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$ACK")"
cat > "$ACK" <<JSON
{
  "accepted": true,
  "compact_path": "$COMPACT",
  "compact_sha256": "$HASH",
  "accepted_by": "$BY",
  "accepted_at": "$NOW",
  "adr": "ADR-0057"
}
JSON

emit "[accept-compact] acceptance recorded → $ACK"
emit "  compact   : $COMPACT"
emit "  sha256    : $HASH"
emit "  accepted_by: $BY"
emit "  accepted_at: $NOW"
exit 0
