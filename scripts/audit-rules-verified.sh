#!/usr/bin/env bash
# scripts/audit-rules-verified.sh — static verifier of the handoff rules_verified
# gate (the inner-loop quality gate the plugin produces, enforced by the harness).
#
# Per TICKET-067 / ADR-0037 (Proposal B, harness-side). The harness owns the
# ENFORCEMENT SPINE; the plugin owns the RULE CONTENT + detectors. The plugin's
# rubric/runner.sh runs detectors against the diff at commit time
# (scripts/audit-standards-conformance.sh, TICKET-032). THIS audit closes the
# other half: for every handoff request/response pair, it statically enforces the
# docs/handoff-contract.md `rules_verified` field rules (contract §rules_verified):
#
#   For a response whose status is "green", with applicable_rules present on the
#   matching request:
#     (1) every applicable_rules id has a key in the response's rules_verified;
#         a missing key forces red (contract: missing key ⇒ gate_failed).
#     (2) every rules_verified value is one of pass | fail | deviated |
#         not_applicable | not_enforced (enum extended per ADR-0062, Fix B).
#     (3) a green response carries NO "fail" and NO "not_enforced" — either forces
#         red (not_applicable is NEUTRAL/green-eligible; the rule does not pertain).
#     (4) every "deviated" rule has a matching row in docs/deviations.md
#         (a deviation is a violation justified by an operator-landed row).
#
# Non-green responses (red/blocked/error) are allowed to carry fails/missing keys
# — the gate only binds "green". Requests without applicable_rules use the
# fail-closed default (all rules apply) and are noted, not gated here (the EO
# slice is enforced separately by scripts/audit-eo-governance.sh).
#
# CONTENT-AGNOSTIC + VACUOUS when no req/res pairs carry applicable_rules.
# Additive: it ADDS a gate over the existing contract; it relaxes nothing.
#
# Usage:
#   scripts/audit-rules-verified.sh           # human-readable
#   scripts/audit-rules-verified.sh --quiet   # exit code only
#
# Env overrides (testability):
#   RV_HANDOFFS_DIR   default .harness/handoffs
#   RV_DEVIATIONS     default docs/deviations.md
#
# Exit codes:
#   0  gate holds (incl. vacuous: no gated pairs)
#   1  one or more violations
#   2  error (bad invocation / node missing when a pair is present)
#
# Portability: bash 3.2 + BSD coreutils; node used only when a req/res pair exists.

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
        -h|--help) sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-rules-verified.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

HANDOFFS_DIR="${RV_HANDOFFS_DIR:-.harness/handoffs}"
DEVIATIONS="${RV_DEVIATIONS:-docs/deviations.md}"

# Collect request/response pairs.
have_pair=0
if [ -d "$HANDOFFS_DIR" ]; then
    for req in "$HANDOFFS_DIR"/*.req.json; do
        [ -e "$req" ] || continue
        res="${req%.req.json}.res.json"
        [ -f "$res" ] && have_pair=1 && break
    done
fi
if [ "$have_pair" -eq 0 ]; then
    emit "[rules-verified] no request/response pairs in $HANDOFFS_DIR — vacuous pass (no handoff to gate)."
    exit 0
fi

command -v node >/dev/null 2>&1 || { printf 'audit-rules-verified.sh: node required\n' >&2; exit 2; }

violations=0
for req in "$HANDOFFS_DIR"/*.req.json; do
    [ -e "$req" ] || continue
    res="${req%.req.json}.res.json"
    [ -f "$res" ] || continue
    out=$(RV_REQ="$req" RV_RES="$res" RV_DEV="$DEVIATIONS" node -e '
const fs = require("fs");
const rd = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const errs = [];
let req, res;
try { req = rd(process.env.RV_REQ); } catch (e) { console.log("ERR|"+process.env.RV_REQ+"|not JSON: "+e.message); process.exit(0); }
try { res = rd(process.env.RV_RES); } catch (e) { console.log("ERR|"+process.env.RV_RES+"|not JSON: "+e.message); process.exit(0); }
const applicable = Array.isArray(req.applicable_rules) ? req.applicable_rules : null;
if (applicable === null) { console.log("NOTE|no applicable_rules (fail-closed default; not gated here)"); process.exit(0); }
const rv = (res && typeof res.rules_verified === "object" && res.rules_verified) ? res.rules_verified : {};
// Verdict vocabulary extended additively per ADR-0062 (Fix B): the detector-run
// verdicts not_applicable (NEUTRAL) + not_enforced (RED) join pass/fail/deviated.
const valid = ["pass","fail","deviated","not_applicable","not_enforced"];
// green-eligible = pass | deviated | not_applicable. fail + not_enforced force red
// (checked per-rule below). Enum check across all reported values:
for (const k of Object.keys(rv)) if (!valid.includes(rv[k])) errs.push("rules_verified["+k+"] invalid value: "+rv[k]);
// The gate binds only "green".
if (res.status === "green") {
  let dev = "";
  try { dev = fs.readFileSync(process.env.RV_DEV, "utf8"); } catch (e) { dev = ""; }
  for (const rid of applicable) {
    if (!(rid in rv)) { errs.push("green but rules_verified omits applicable rule: "+rid+" (missing key ⇒ must be red)"); continue; }
    if (rv[rid] === "fail") errs.push("green but applicable rule failed: "+rid+" (any fail ⇒ must be red)");
    if (rv[rid] === "not_enforced") errs.push("green but applicable rule not_enforced: "+rid+" (un-verified ⇒ must be red)");
    if (rv[rid] === "deviated" && dev.indexOf(rid) === -1) errs.push("rule "+rid+" marked deviated but no row in docs/deviations.md");
  }
}
for (const e of errs) console.log("VIOL|"+e);
process.exit(0);
' 2>&1)
    if printf '%s' "$out" | grep -q '^ERR|'; then
        emit "  [VIOLATION] $(basename "$req"): $(printf '%s' "$out" | sed -n 's/^ERR|//p' | head -1)"
        violations=$((violations + 1))
        continue
    fi
    nviol=$(printf '%s\n' "$out" | grep -c '^VIOL|' || true)
    if [ "$nviol" -gt 0 ]; then
        printf '%s\n' "$out" | sed -n 's/^VIOL|/  [VIOLATION] '"$(basename "$res")"': /p' | while IFS= read -r line; do emit "$line"; done
        violations=$((violations + nviol))
    elif printf '%s' "$out" | grep -q '^NOTE|'; then
        emit "  [ok] $(basename "$req"): $(printf '%s' "$out" | sed -n 's/^NOTE|//p' | head -1)"
    else
        emit "  [ok] $(basename "$res"): rules_verified gate satisfied (all applicable rules pass/deviated)."
    fi
done

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[rules-verified] $violations violation(s). A green response MUST verify every applicable rule"
    emit "  as pass or deviated (deviations need a docs/deviations.md row); any fail/missing forces red."
    exit 1
fi
emit "[rules-verified] OK — every green handoff response satisfies the rules_verified gate."
exit 0
