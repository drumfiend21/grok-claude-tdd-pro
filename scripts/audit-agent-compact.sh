#!/usr/bin/env bash
# scripts/audit-agent-compact.sh — fail-closed gate for the GCTP agent operating
# compact (docs/agent-operating-compact.md).
#
# Per TICKET-068 / ADR-0057. The compact is a TIER-1 behavioral binding on the
# agent driving GCTP: the operator must accept it before the harness may be used
# for the user's product, and the agent is enforced by that agreement. This audit
# is the MACHINE half of the enforcement (the BINDING half is the agent honoring
# CLAUDE.md/AGENTS.md). It verifies, fail-closed:
#
#   (1) the compact document exists + is non-empty;
#   (2) it is WIRED into CLAUDE.md (Claude Code's binding surface);
#   (3) it is WIRED into AGENTS.md (other agents' binding surface);
#   (4) an acceptance record exists (.harness/agent-compact-ack.json), is valid
#       JSON, and has accepted == true;
#   (5) the recorded compact_sha256 MATCHES the current compact bytes — i.e. the
#       acceptance is for THIS version of the compact, not a stale prior one
#       (any amendment invalidates acceptance until the operator re-accepts).
#
# Unlike most harness lenses this is NOT vacuous and NOT warn-only: the compact
# is always present in this repo, so the gate always has teeth. This is the
# deliberate ADR-0057 exception to ADR-0001's session-start warn-only policy
# (which governs plugin-pin drift, an informational signal).
#
# Usage:
#   scripts/audit-agent-compact.sh           # human-readable
#   scripts/audit-agent-compact.sh --quiet   # exit code only
#
# Env overrides (testability):
#   AC_COMPACT    default docs/agent-operating-compact.md
#   AC_ACK        default .harness/agent-compact-ack.json
#   AC_CLAUDEMD   default CLAUDE.md
#   AC_AGENTSMD   default AGENTS.md
#
# Exit codes:
#   0  compact present + wired + currently accepted
#   1  one or more invariants violated (fail-closed)
#   2  error (bad invocation / no sha256 tool)
#
# Portability: bash 3.2 + BSD coreutils. sha256 via sha256sum OR shasum -a 256.
# JSON ack parsed with node when present; falls back to a bounded grep parse.

set -u

# Epoch-aware enforcement (ADR-0071): source the shared epoch library so this audit
# participates in the uniform epoch-gate surface (operator directive: all 17 audits).
# Exposes epoch_current_pin / epoch_resolve_baseline / epoch_filter_new /
# epoch_req_gated; sourcing is side-effect-free (functions only).
_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet)   QUIET=1 ;;
        -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-agent-compact.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

COMPACT="${AC_COMPACT:-docs/agent-operating-compact.md}"
ACK="${AC_ACK:-.harness/agent-compact-ack.json}"
CLAUDEMD="${AC_CLAUDEMD:-CLAUDE.md}"
AGENTSMD="${AC_AGENTSMD:-AGENTS.md}"

# The wiring token both binding surfaces must reference.
WIRE_REF="agent-operating-compact.md"

violations=0
viol() { emit "  [VIOLATION] $*"; violations=$((violations + 1)); }

# (1) compact present + non-empty
if [ ! -s "$COMPACT" ]; then
    viol "compact document missing or empty: $COMPACT"
    # Without the compact, the remaining checks are moot.
    emit ""
    emit "[agent-compact] FAIL — the operating compact is absent. GCTP is not authorized for use."
    exit 1
fi

# (2)+(3) wired into both binding surfaces
if [ ! -f "$CLAUDEMD" ] || ! grep -q "$WIRE_REF" "$CLAUDEMD"; then
    viol "compact not wired into $CLAUDEMD (expected a reference to $WIRE_REF)"
fi
if [ ! -f "$AGENTSMD" ] || ! grep -q "$WIRE_REF" "$AGENTSMD"; then
    viol "compact not wired into $AGENTSMD (expected a reference to $WIRE_REF)"
fi

# Current compact hash.
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        return 1
    fi
}
CUR_HASH=$(sha256_of "$COMPACT") || { printf 'audit-agent-compact.sh: no sha256 tool (sha256sum/shasum)\n' >&2; exit 2; }

# (4) acceptance record present + valid + accepted == true; (5) hash matches.
if [ ! -f "$ACK" ]; then
    viol "no acceptance record at $ACK — the operator has not accepted the compact (run scripts/accept-compact.sh)"
else
    ACK_OK=""
    if command -v node >/dev/null 2>&1; then
        ACK_OK=$(AC_ACK_F="$ACK" node -e '
const fs=require("fs");
let a;
try { a=JSON.parse(fs.readFileSync(process.env.AC_ACK_F,"utf8")); }
catch(e){ console.log("PARSE_ERR|"+e.message); process.exit(0); }
console.log("OK|"+(a.accepted===true?"1":"0")+"|"+(typeof a.compact_sha256==="string"?a.compact_sha256:""));
' 2>&1)
    else
        # Bounded grep fallback: pull the two fields we gate on.
        acc=$(grep -o '"accepted"[[:space:]]*:[[:space:]]*true' "$ACK" >/dev/null 2>&1 && echo 1 || echo 0)
        h=$(grep -o '"compact_sha256"[[:space:]]*:[[:space:]]*"[0-9a-f]*"' "$ACK" 2>/dev/null | head -1 | sed 's/.*"\([0-9a-f]*\)"$/\1/')
        ACK_OK="OK|$acc|$h"
    fi

    case "$ACK_OK" in
        PARSE_ERR\|*)
            viol "acceptance record is not valid JSON: $ACK (${ACK_OK#PARSE_ERR|})" ;;
        OK\|*)
            acc_flag=$(printf '%s' "$ACK_OK" | cut -d'|' -f2)
            ack_hash=$(printf '%s' "$ACK_OK" | cut -d'|' -f3)
            if [ "$acc_flag" != "1" ]; then
                viol "acceptance record present but accepted != true: $ACK"
            fi
            if [ -z "$ack_hash" ]; then
                viol "acceptance record missing compact_sha256: $ACK"
            elif [ "$ack_hash" != "$CUR_HASH" ]; then
                viol "acceptance is STALE — recorded compact_sha256 does not match the current compact."
                emit "             recorded: $ack_hash"
                emit "             current : $CUR_HASH"
                emit "             the compact was amended; re-accept with scripts/accept-compact.sh"
            fi ;;
        *)
            viol "could not parse acceptance record: $ACK" ;;
    esac
fi

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[agent-compact] FAIL ($violations) — GCTP is NOT authorized for the user's product until the"
    emit "  operating compact (docs/agent-operating-compact.md) is present, wired, and currently accepted."
    exit 1
fi

emit "[agent-compact] OK — compact present, wired into CLAUDE.md + AGENTS.md, and currently accepted."
exit 0
