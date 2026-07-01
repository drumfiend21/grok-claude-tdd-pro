#!/usr/bin/env bash
# scripts/audit-eo-governance.sh — EO-2026 governance-layer enforcement spine.
#
# Per TICKET-050. Realizes ADR-0045 (cross-cutting governance layer),
# ADR-0046 (two-phase: design-before-code AND code), ADR-0047 (additive,
# never subtractive), and ADR-0048 (handoff-contract extension). Verifies the
# harness-side EO governance invariants over any present handoff artifacts.
#
# CONTENT-AGNOSTIC: the EO rule CONTENT is owned by claude-tdd-pro (its in-flight
# EO work) and flows into active.json via standards-sync on a future pin bump.
# This audit ENFORCES NOTHING until an EO-namespace rule appears in the registry
# (the spine is "armed"); once one does, it enforces:
#
#   (1) Non-exemptibility (ADR-0045 always-on): every EO-namespace rule in the
#       registry MUST appear in a request's applicable_rules WHEN that field is
#       present. Absent applicable_rules = the handoff-contract fail-closed
#       "all rules apply" default, which already covers EO — not a violation.
#   (2) Two-phase attestation (ADR-0046): a green response MUST carry a non-empty
#       eo_design_conformance attestation (the design-before-code evidence).
#
# The harness DEMANDS + VERIFIES via the contract; the plugin ENFORCES at both
# phases (prime directive — no plugin edits here). EO governance is ADDITIVE:
# it never relaxes a base standard (ADR-0047); this audit only ADDS checks.
#
# Usage:
#   scripts/audit-eo-governance.sh           # human-readable summary
#   scripts/audit-eo-governance.sh --quiet   # exit code only
#
# Env overrides (testability):
#   EO_RULES_FILE     default .harness/rules/active.json
#   EO_HANDOFFS_DIR   default .harness/handoffs
#   EO_NAMESPACES     default "eo security-governance" — space/comma-separated
#                     source_namespace values that denote EO-governance rules.
#                     `eo` is the canonical name reserved by the spec; CTP ships its
#                     EO authorities (CISA SSDF/KEV, NIST AI RMF, SLSA) under
#                     `security-governance`, which is live at pin 6d2fe13+ (ADR-0055).
#                     Override to add/replace namespaces as the plugin evolves.
#
# Exit codes:
#   0  invariants hold (incl. vacuous: no EO rules active, or no handoffs)
#   1  one or more EO governance violations
#   2  error (bad invocation)
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies (no jq/node).

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
        -h|--help) sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-eo-governance.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

RULES_FILE="${EO_RULES_FILE:-.harness/rules/active.json}"
HANDOFFS_DIR="${EO_HANDOFFS_DIR:-.harness/handoffs}"
EO_NS=$(printf '%s' "${EO_NAMESPACES:-eo security-governance}" | tr ',' ' ')

emit "[eo-governance] EO namespace set: $EO_NS"

# --- Step 1: collect EO-namespace rule IDs from the registry -----------------
# Robust to nested JSON braces: scan id/source_namespace tokens in document
# order (within a rule object the "id" precedes "source_namespace"; nested
# objects use neither key), pairing each id with the next source_namespace.
eo_rule_ids=""
if [ -f "$RULES_FILE" ]; then
    eo_rule_ids=$(grep -oE '"(id|source_namespace)":"[^"]*"' "$RULES_FILE" 2>/dev/null \
        | awk -v nsset="$EO_NS" '
            BEGIN { n = split(nsset, a, " ") }
            {
                k = $0; sub(/":".*/, "", k); sub(/^"/, "", k)
                v = $0; sub(/^"[^"]*":"/, "", v); sub(/"$/, "", v)
                if (k == "id") last = v
                else if (k == "source_namespace") {
                    for (i = 1; i <= n; i++) if (v == a[i] && last != "") print last
                }
            }' \
        | sort -u | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
fi

if [ -z "$eo_rule_ids" ]; then
    emit "[eo-governance] no EO-namespace rules active in $RULES_FILE."
    emit "[eo-governance] spine ARMED, vacuous pass (EO rule content is pin-bump-gated on the plugin's EO work; ADR-0045)."
    exit 0
fi

emit "[eo-governance] active EO rules: $eo_rule_ids"

violations=0
flag() { violations=$((violations + 1)); emit "  [VIOLATION] $*"; }

# --- Step 2: non-exemptibility over requests ---------------------------------
if [ -d "$HANDOFFS_DIR" ]; then
    for req in "$HANDOFFS_DIR"/*.req.json; do
        [ -e "$req" ] || continue
        flat=$(tr -d '\n' < "$req")
        if printf '%s' "$flat" | grep -qE '"applicable_rules"[[:space:]]*:[[:space:]]*\['; then
            body=$(printf '%s' "$flat" | sed -E 's/.*"applicable_rules"[[:space:]]*:[[:space:]]*\[([^]]*)\].*/\1/')
            for rid in $eo_rule_ids; do
                if printf '%s' "$body" | grep -q "\"$rid\""; then :; else
                    flag "$(basename "$req"): applicable_rules omits EO rule '$rid' (non-exemptible per ADR-0045)"
                fi
            done
        else
            emit "  [ok] $(basename "$req"): no applicable_rules → fail-closed default (all rules apply, incl EO)"
        fi
    done
fi

# --- Step 3: two-phase design attestation over green responses ---------------
if [ -d "$HANDOFFS_DIR" ]; then
    for res in "$HANDOFFS_DIR"/*.res.json; do
        [ -e "$res" ] || continue
        flat=$(tr -d '\n' < "$res")
        printf '%s' "$flat" | grep -qE '"status"[[:space:]]*:[[:space:]]*"green"' || continue
        if printf '%s' "$flat" | grep -qE '"eo_design_conformance"[[:space:]]*:[[:space:]]*(null|""|\{\}|\[\])'; then
            flag "$(basename "$res"): green but eo_design_conformance is empty/null (design-before-code attestation required per ADR-0046)"
        elif printf '%s' "$flat" | grep -qE '"eo_design_conformance"[[:space:]]*:'; then
            emit "  [ok] $(basename "$res"): green + eo_design_conformance present"
        else
            flag "$(basename "$res"): green but missing eo_design_conformance attestation (ADR-0046)"
        fi
    done
fi

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[eo-governance] $violations violation(s). EO governance is non-exemptible + two-phase + additive (ADR-0045/0046/0047)."
    exit 1
fi

emit "[eo-governance] OK — EO governance invariants hold."
exit 0
