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
#   (4) If a sibling FEATURE-NNN.business-intake.json is present AND its
#       schema_version is "1.1" (P-12 / TICKET-114 / ADR-0087; resolved at CTP
#       pin f060a8e — S-57 / §2.35 / §30), every entry in
#       workload_classification.activated_probe_namespaces appears as a
#       source_namespace on at least one decisions[*].applicable_rules rule — i.e.
#       committed business postures propagate into the design layer. v1.0 profiles
#       (or absent profile) vacuous-pass this check.
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
#   XC_PROJECT_ID     P-15 Phase 2 pre-wire (TICKET-121.b) — the project scope for
#                     this audit run. Required when a profile carries
#                     workload_classification.project_id (fail-loud A16 otherwise).
#                     When set and matching, project_overlay_namespaces[] on the
#                     profile fold into invariant-4's target set (first-class-but-
#                     scoped per convergence doc B4). When set and MISMATCHING,
#                     invariant-4 fails-loud with a scope-mismatch diagnostic (A15
#                     — the no-silent-globalization spine on the intra-repo axis).
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
# P-15 Phase 2 (TICKET-121.b): current-project scope. Empty ⇒ global-only run.
PROJECT_ID="${XC_PROJECT_ID:-}"

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
    # v1.1 profile propagation (invariant 4, TICKET-114): sibling business-intake.json.
    prof="${art%.architecture.json}.business-intake.json"
    [ -f "$prof" ] || prof=""
    out=$(XC_ART="$art" XC_CC="$cc" XC_RULES="$RULES_FILE" XC_EO="$EO_NS" XC_PROF="$prof" XC_PROJECT_ID="$PROJECT_ID" node -e '
const fs = require("fs");
const rd = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const errs = [];
let art, rules;
try { art = rd(process.env.XC_ART); } catch (e) { console.log("ERR|"+process.env.XC_ART+"|not JSON: "+e.message); process.exit(0); }
try { rules = rd(process.env.XC_RULES); } catch (e) { console.log("ERR|rules|"+e.message); process.exit(0); }
const ids = new Set((rules.rules||[]).map(r=>r.id));
const idToNs = new Map((rules.rules||[]).map(r=>[r.id, r.source_namespace]));
const eoNs = (process.env.XC_EO||"").split(/\s+/).filter(Boolean);
const eoIds = (rules.rules||[]).filter(r=>eoNs.includes(r.source_namespace)).map(r=>r.id);
const decisions = Array.isArray(art.decisions) ? art.decisions : [];
const referencedNs = new Set();
for (const d of decisions) {
  const j = (d && d.juncture) ? d.juncture : "?";
  const ar = Array.isArray(d && d.applicable_rules) ? d.applicable_rules : [];
  for (const rid of ar) {
    if (!ids.has(rid)) errs.push("decision ["+j+"] applicable_rule not in active.json: "+rid);
    else referencedNs.add(idToNs.get(rid));
  }
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
// Invariant 4: v1.1 probe-namespace propagation (TICKET-114 / ADR-0087; generalized in
// TICKET-118.a / P-13 §30.5 pre-wire). v1.0 or absent profile → vacuous.
//   • Pre-§30.5 (no stack[]): target = activated_probe_namespaces (unchanged behavior).
//   • §30.5+ (stack[] present): target = activated_probe_namespaces ∪ stack[].namespace.
// Rationale: §30.5 makes rule activation progressive — a namespace committed to the stack
// at any stage (classifier, universal-answer, probe-answer, design-decision, operator)
// carries the same enforcement-floor obligation as an activated probe namespace. Invariant 4
// still means "every namespace known to be in-stack must be considered by at least one
// decision"; §30.5 just widens the "known to be in-stack" set.
if (process.env.XC_PROF) {
  let prof; try { prof = rd(process.env.XC_PROF); } catch (e) { errs.push("business-intake profile not JSON: "+e.message); }
  if (prof && prof.schema_version === "1.1") {
    const wc = prof.workload_classification || {};
    const activated = Array.isArray(wc.activated_probe_namespaces) ? wc.activated_probe_namespaces : [];
    const stackNs = Array.isArray(wc.stack) ? wc.stack.map(e => e && e.namespace).filter(x => typeof x === "string" && x) : [];
    // P-15 Phase 2 (TICKET-121.b): overlay namespaces from project scope. When the
    // profile carries project_id + project_overlay_namespaces (schema-validated by
    // consult.sh --validate-profile), those namespaces are first-class-but-scoped
    // per convergence doc B4. Cross-project leakage rejection (A15) + --project
    // required (A16) fire before the union expansion.
    const overlayNs = Array.isArray(wc.project_overlay_namespaces) ? wc.project_overlay_namespaces.filter(x => typeof x === "string" && x) : [];
    const profileProjectId = (typeof wc.project_id === "string" && wc.project_id) ? wc.project_id : "";
    const auditProjectId = process.env.XC_PROJECT_ID || "";
    // A16: --project required when profile carries project_id.
    if (profileProjectId && !auditProjectId) {
      errs.push("v1.1 profile carries workload_classification.project_id [" + profileProjectId + "] but XC_PROJECT_ID unset (--project required per convergence doc B1/A16 — no ambient current-project)");
    }
    // A15: cross-project leakage rejection when scopes mismatch.
    else if (profileProjectId && auditProjectId && profileProjectId !== auditProjectId) {
      errs.push("v1.1 scope mismatch: profile scoped to [" + profileProjectId + "], audit run scoped to [" + auditProjectId + "] (cross-project leakage rejected per convergence doc B4/A15 — no silent globalization)");
    }
    // A15 companion: an overlay namespace present when auditProjectId is set but
    // profileProjectId is empty is a schema-level anomaly already caught by
    // --validate-profile (B4 orphan-overlay). Assert here defensively.
    else if (!profileProjectId && overlayNs.length > 0) {
      errs.push("v1.1 orphan overlay: project_overlay_namespaces present without project_id (schema violation — should have been caught by --validate-profile B4 spine)");
    }
    // Only expand invariant-4 target when scoping is consistent (or global).
    const scopeOk = errs.length === 0 || !errs.some(e => e.startsWith("v1.1 scope mismatch") || e.startsWith("v1.1 profile carries") || e.startsWith("v1.1 orphan overlay"));
    let target;
    if (scopeOk && profileProjectId && profileProjectId === auditProjectId) {
      // Matching scope — fold overlay into target.
      target = new Set([...activated, ...stackNs, ...overlayNs]);
    } else if (scopeOk) {
      // Global-only or no overlay — unchanged from P-13.
      target = new Set([...activated, ...stackNs]);
    } else {
      // Scope mismatch already logged; skip target expansion to avoid noise.
      target = new Set();
    }
    for (const ns of target) {
      if (!referencedNs.has(ns)) {
        const inAct = activated.includes(ns);
        const inStack = stackNs.includes(ns);
        const inOverlay = overlayNs.includes(ns);
        const from = [
          inAct ? "activated_probe_namespaces" : null,
          inStack ? "stack[]" : null,
          inOverlay ? "project_overlay_namespaces (scope:" + profileProjectId + ")" : null,
        ].filter(x => x).join(" + ");
        errs.push("v1.1 profile in-stack namespace [" + ns + "] (from " + from + ") does not propagate into any decision applicable_rules (no rule with source_namespace=" + ns + " referenced)");
      }
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
        _prof_tag=""
        if [ -n "$prof" ]; then
            _sv=$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).schema_version||"1.0")}catch(e){console.log("?")}' "$prof" 2>/dev/null || echo "?")
            case "$_sv" in
                "1.1") _prof_tag=" + v1.1 probe-group propagation verified" ;;
                "1.0") _prof_tag=" + profile v1.0 (v1.1 propagation N/A)" ;;
                *)     _prof_tag=" + profile schema=$_sv" ;;
            esac
        fi
        emit "  [ok] $(basename "$art"): applicable_rules resolve + EO non-exemptible present$([ -n "$cc" ] && printf ' + cross-check record valid')${_prof_tag}"
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
