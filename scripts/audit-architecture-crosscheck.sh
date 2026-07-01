#!/usr/bin/env bash
# scripts/audit-architecture-crosscheck.sh — GCTP's dual-enforcement gate on CTP's
# architecture output (Stage 5 of the consult loop).
#
# Per TICKET-065 / ADR-0056. After CTP architects (under its own standards), GCTP
# independently checks the proposed architecture against GCTP's OWN rules — the
# shared active.json registry PLUS the GCTP-native governance (R/D/EO/citation).
# This audit verifies the cross-check RECORD + the consult artifact's rule claims
# for any present FEATURE-NNN.architecture.json:
#
#   (1) Every artifact's decisions[*].applicable_rules id resolves in active.json.
#   (2) Every artifact includes the non-exemptible EO-governance rules
#       (source_namespace eo / security-governance) in EVERY decision's
#       applicable_rules (ADR-0045/0055 — EO is always-on, even in the design phase).
#   (3) If a cross-check record (FEATURE-NNN.crosscheck.json) is present, every
#       check is pass | deviated | reconsulted; any "fail" without a deviation row
#       is a violation (ADR-0056 D-E — never silently accept).
#
# CONTENT-AGNOSTIC + VACUOUS when no consult artifacts exist (the loop hasn't run
# yet) — armed, not biting. Additive: it ADDS a gate; it relaxes nothing.
#
# Usage:
#   scripts/audit-architecture-crosscheck.sh           # human-readable
#   scripts/audit-architecture-crosscheck.sh --quiet   # exit code only
#
# Env overrides (testability):
#   XC_RULES_FILE     default .harness/rules/active.json
#   XC_HANDOFFS_DIR   default .harness/handoffs
#   XC_EO_NAMESPACES  default "eo security-governance"
#
# Exit codes:
#   0  cross-check invariants hold (incl. vacuous: no artifacts)
#   1  one or more violations
#   2  error (bad invocation / node missing when an artifact is present)
#
# Portability: bash 3.2 + BSD coreutils; node used only when an artifact is present.

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
        -h|--help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-architecture-crosscheck.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

RULES_FILE="${XC_RULES_FILE:-.harness/rules/active.json}"
HANDOFFS_DIR="${XC_HANDOFFS_DIR:-.harness/handoffs}"
EO_NS="${XC_EO_NAMESPACES:-eo security-governance}"

# Collect consult artifacts.
have_artifact=0
if [ -d "$HANDOFFS_DIR" ]; then
    for art in "$HANDOFFS_DIR"/*.architecture.json; do
        [ -e "$art" ] && have_artifact=1 && break
    done
fi
if [ "$have_artifact" -eq 0 ]; then
    emit "[arch-crosscheck] no consult artifacts in $HANDOFFS_DIR — vacuous pass (loop not yet run; ADR-0056)."
    exit 0
fi

command -v node >/dev/null 2>&1 || { printf 'audit-architecture-crosscheck.sh: node required\n' >&2; exit 2; }
[ -f "$RULES_FILE" ] || { printf 'audit-architecture-crosscheck.sh: rules file missing: %s\n' "$RULES_FILE" >&2; exit 2; }

violations=0
for art in "$HANDOFFS_DIR"/*.architecture.json; do
    [ -e "$art" ] || continue
    cc="${art%.architecture.json}.crosscheck.json"
    [ -f "$cc" ] || cc=""
    out=$(XC_ART="$art" XC_CC="$cc" XC_RULES="$RULES_FILE" XC_EO="$EO_NS" node -e '
const fs = require("fs");
const rd = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const errs = [];
let art, rules;
try { art = rd(process.env.XC_ART); } catch (e) { console.log("ERR|"+process.env.XC_ART+"|not JSON: "+e.message); process.exit(0); }
try { rules = rd(process.env.XC_RULES); } catch (e) { console.log("ERR|rules|"+e.message); process.exit(0); }
const ids = new Set((rules.rules||[]).map(r=>r.id));
const eoNs = (process.env.XC_EO||"").split(/\s+/).filter(Boolean);
const eoIds = (rules.rules||[]).filter(r=>eoNs.includes(r.source_namespace)).map(r=>r.id);
const decisions = Array.isArray(art.decisions) ? art.decisions : [];
for (const d of decisions) {
  const j = (d && d.juncture) ? d.juncture : "?";
  const ar = Array.isArray(d && d.applicable_rules) ? d.applicable_rules : [];
  for (const rid of ar) if (!ids.has(rid)) errs.push("decision ["+j+"] applicable_rule not in active.json: "+rid);
  for (const eid of eoIds) if (!ar.includes(eid)) errs.push("decision ["+j+"] missing non-exemptible EO rule: "+eid);
}
if (process.env.XC_CC) {
  let cc; try { cc = rd(process.env.XC_CC); } catch (e) { errs.push("crosscheck record not JSON: "+e.message); }
  if (cc && Array.isArray(cc.checks)) {
    const deviated = new Set((cc.deviations||[]).map(x=>x.rule));
    for (const c of cc.checks) {
      const ok = ["pass","deviated","reconsulted"].includes(c && c.result);
      if (!ok) errs.push("crosscheck ["+(c&&c.rule||"?")+"] result not pass/deviated/reconsulted: "+(c&&c.result));
      if (c && c.result === "fail" && !deviated.has(c.rule)) errs.push("crosscheck ["+c.rule+"] failed with no deviation row (ADR-0056 D-E)");
    }
  }
}
for (const e of errs) console.log("VIOL|"+e);
process.exit(0);
' 2>&1)
    if printf '%s' "$out" | grep -q '^ERR|'; then
        emit "  [VIOLATION] $(basename "$art"): $(printf '%s' "$out" | sed -n 's/^ERR|//p' | head -1)"
        violations=$((violations + 1))
        continue
    fi
    nviol=$(printf '%s\n' "$out" | grep -c '^VIOL|' || true)
    if [ "$nviol" -gt 0 ]; then
        printf '%s\n' "$out" | sed -n 's/^VIOL|/  [VIOLATION] '"$(basename "$art")"': /p' | while IFS= read -r line; do emit "$line"; done
        violations=$((violations + nviol))
    else
        emit "  [ok] $(basename "$art"): applicable_rules resolve + EO non-exemptible present$([ -n "$cc" ] && printf ' + cross-check record valid')"
    fi
done

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[arch-crosscheck] $violations violation(s). GCTP dual-enforcement: CTP's architecture must"
    emit "  satisfy GCTP's own rules (active.json + EO non-exemptibility); fails need a deviation row (ADR-0056 D-E)."
    exit 1
fi
emit "[arch-crosscheck] OK — CTP architecture output passes GCTP's cross-check."
exit 0
