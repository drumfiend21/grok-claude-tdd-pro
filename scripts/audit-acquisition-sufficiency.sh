#!/usr/bin/env bash
# scripts/audit-acquisition-sufficiency.sh — TIER-1 quality-gate audit per P-18
# §3.1 (TICKET-127.a). Enforces the operator's ≥ N rules per stacked technology
# floor as a NON-NEGOTIABLE operator-declared standard (per ADR-0037 discipline).
#
# For a given --project <id>, walks:
#   .harness/plugin-cache/claude-tdd-pro/generated-code-quality-standards/_project/<id>/*/
# counting rules per namespace directory (`^- id:` lines across YAML files). For every
# technology committed to the project's stack — read from the project's business-intake
# profile at `.harness/consult-work/<id>/intake/business-profile.json` if present, or
# from `stack` in the persisted stage-0 classifier output — assert that the effective
# rule set for that tech (project overlay + globally-provisioned rules in active.json
# with matching `source_namespace`) meets the threshold. Fail-loud when any tech is
# below.
#
# The seam matches P-18's contract: CTP emits `rule_count=<n> sufficiency=ok|
# below-threshold-<N>` on `acquire-technology-live.sh`; this audit is the GCTP-side
# durable gate that survives across acquisitions (the CTP signal is per-invocation;
# the audit re-checks per-consult).
#
# Usage:
#   scripts/audit-acquisition-sufficiency.sh --project <id>
#   scripts/audit-acquisition-sufficiency.sh --project <id> --quiet
#   scripts/audit-acquisition-sufficiency.sh --project <id> --threshold 50
#
# Env overrides (testability):
#   AAS_THRESHOLD          default 30 (operator-declared floor per P-18)
#   AAS_RULES_FILE         default .harness/rules/active.json
#   AAS_PROJECT_STORE      default .harness/plugin-cache/claude-tdd-pro/generated-code-quality-standards/_project
#   AAS_CONSULT_WORK       default .harness/consult-work
#
# Exit codes:
#   0  every stacked tech meets threshold (or no stacked techs — vacuous pass)
#   1  one or more techs below threshold; diagnostic names each with count + shortfall
#   2  usage error (missing --project / missing project store / node absent)

set -u

PROJECT=""
QUIET=0
THRESHOLD="${AAS_THRESHOLD:-30}"
for arg in "$@"; do :; done  # placeholder to expose all args to the loop below
while [ $# -gt 0 ]; do
    case "$1" in
        --project)   PROJECT="${2-}"; shift 2 ;;
        --threshold) THRESHOLD="${2-}"; shift 2 ;;
        --quiet)     QUIET=1; shift ;;
        -h|--help)   sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-acquisition-sufficiency.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[ -n "$PROJECT" ] || { printf 'audit-acquisition-sufficiency.sh: --project <id> required\n' >&2; exit 2; }

RULES_FILE="${AAS_RULES_FILE:-.harness/rules/active.json}"
PROJECT_STORE="${AAS_PROJECT_STORE:-.harness/plugin-cache/claude-tdd-pro/generated-code-quality-standards/_project}"
CONSULT_WORK="${AAS_CONSULT_WORK:-.harness/consult-work}"

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

# Determine the stacked technologies for the project. Prefer the persisted profile
# from Stage 0 if present (it names the exact stack the consult committed to). Fall
# back to the presence of overlay directories under _project/<id>/*/ as the applied set.
STACK_TECHS=""
STAGE0="$CONSULT_WORK/$PROJECT/intake/stage-0-classifier.json"
if [ -f "$STAGE0" ]; then
    STACK_TECHS=$(python3 -c '
import json, sys
try:
    d = json.load(open("'"$STAGE0"'"))
    wc = d.get("workload_classification", {})
    techs = set()
    for entry in (wc.get("stack") or []):
        ns = (entry or {}).get("namespace")
        if ns: techs.add(ns)
    for ns in (wc.get("families_active") or []):
        if ns: techs.add(ns)
    print(" ".join(sorted(techs)))
except Exception:
    pass
' 2>/dev/null)
fi

# Overlay directories are the DE-FACTO stacked techs (whatever has been acquired).
# Union with the stage-0-declared stack so we cover both intent and actuality.
OVERLAY_TECHS=""
if [ -d "$PROJECT_STORE/$PROJECT" ]; then
    OVERLAY_TECHS=$(cd "$PROJECT_STORE/$PROJECT" && ls -d */ 2>/dev/null | tr -d '/' | tr '\n' ' ')
fi

# Union without dupes (bash 3.2 friendly).
ALL_TECHS=$(printf '%s %s\n' "$STACK_TECHS" "$OVERLAY_TECHS" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')

if [ -z "$ALL_TECHS" ]; then
    emit "[audit-acquisition-sufficiency] no stacked techs for project $PROJECT — vacuous pass (nothing to acquire yet)"
    exit 0
fi

# Count rules per tech: overlay YAML files' `^- id:` lines + active.json rules with
# matching source_namespace. Node is available (used by other audits); use it for
# JSON parsing to stay consistent with the existing audit chain conventions.
violations=0
for tech in $ALL_TECHS; do
    overlay_dir="$PROJECT_STORE/$PROJECT/$tech"
    overlay_count=0
    if [ -d "$overlay_dir" ]; then
        overlay_count=$(grep -h "^- id:" "$overlay_dir"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
    fi
    global_count=0
    if [ -f "$RULES_FILE" ] && command -v node >/dev/null 2>&1; then
        global_count=$(RULES="$RULES_FILE" NS="$tech" node -e '
const fs = require("fs");
try {
  const d = JSON.parse(fs.readFileSync(process.env.RULES, "utf8"));
  const n = (d.rules || []).filter(r => r.source_namespace === process.env.NS).length;
  console.log(n);
} catch (e) { console.log(0); }
' 2>/dev/null)
    fi
    total=$((overlay_count + global_count))
    if [ "$total" -lt "$THRESHOLD" ]; then
        emit "  [VIOLATION] tech=$tech count=$total (overlay=$overlay_count + global=$global_count) < threshold=$THRESHOLD — shortfall=$((THRESHOLD - total)) — acquire more via 'kata acquire $tech --project $PROJECT' or add source-registry entries via §31.4 PR"
        violations=$((violations + 1))
    else
        emit "  [ok] tech=$tech count=$total (overlay=$overlay_count + global=$global_count) >= threshold=$THRESHOLD"
    fi
done

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[audit-acquisition-sufficiency] $violations tech(s) below threshold=$THRESHOLD for project $PROJECT."
    emit "  Design cross-check and roadmap render will refuse to proceed until every stacked tech meets"
    emit "  the operator-declared ≥ $THRESHOLD rules floor (per P-18 / ADR-0037 TIER-1 operator-declared-standards regime)."
    exit 1
fi
emit "[audit-acquisition-sufficiency] OK — every stacked tech for project $PROJECT meets threshold=$THRESHOLD."
exit 0
