#!/usr/bin/env bash
# tests/test-audit-architecture-crosscheck.sh — unit tests for
# scripts/audit-architecture-crosscheck.sh. Per TICKET-065 / ADR-0056.
# Exit-code contract: 0 (invariants hold / vacuous) / 1 (violation) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-arch-crosscheck] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-architecture-crosscheck.sh

TMP=$(mktemp -d -t xc-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/h"

cat > "$TMP/rules.json" <<'JSON'
{"rules":[{"id":"g-node-007","source_namespace":"node"},
{"id":"g-iam-001","source_namespace":"iam"},
{"id":"g-aws-001","source_namespace":"aws"},
{"id":"g-react-001","source_namespace":"react"},
{"id":"g-security-governance-require-provenance","source_namespace":"security-governance"},
{"id":"g-security-governance-no-known-exploited-ingress","source_namespace":"security-governance"}]}
JSON
EO_ALL='"g-security-governance-require-provenance","g-security-governance-no-known-exploited-ingress"'

run() { XC_RULES_FILE="$TMP/rules.json" XC_HANDOFFS_DIR="$TMP/h" "$SCRIPT" --quiet >/dev/null 2>&1; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: no artifacts → vacuous pass (0)
rm -f "$TMP/h"/*.json
run; assert_eq "$?" "0" "no consult artifacts → vacuous pass (0)"

# Test 4: valid artifact (rules resolve + both EO rules present) → 0
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"db","complexity":"medium","applicable_rules":["g-node-007",$EO_ALL]}]}
JSON
run; assert_eq "$?" "0" "valid artifact (rules resolve + EO present) → 0"

# Test 5: applicable_rule not in active.json → violation (1)
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"db","complexity":"medium","applicable_rules":["g-bogus-999",$EO_ALL]}]}
JSON
run; assert_eq "$?" "1" "unresolved applicable_rule → violation (1)"

# Test 6: missing a non-exemptible EO rule → violation (1)
cat > "$TMP/h/FEATURE-1.architecture.json" <<'JSON'
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"db","complexity":"medium","applicable_rules":["g-node-007","g-security-governance-require-provenance"]}]}
JSON
run; assert_eq "$?" "1" "missing non-exemptible EO rule → violation (1)"

# Test 7: cross-check record with fail + NO deviation row → violation (1)
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"db","complexity":"medium","applicable_rules":["g-node-007",$EO_ALL]}]}
JSON
cat > "$TMP/h/FEATURE-1.crosscheck.json" <<'JSON'
{"feature_id":"FEATURE-1","checks":[{"rule":"R-7","result":"fail"}],"deviations":[]}
JSON
run; assert_eq "$?" "1" "crosscheck fail w/o deviation → violation (1)"

# Test 8: same fail BUT with a deviation row → accepted (0)
cat > "$TMP/h/FEATURE-1.crosscheck.json" <<'JSON'
{"feature_id":"FEATURE-1","checks":[{"rule":"R-7","result":"fail"}],"deviations":[{"rule":"R-7","deviations_md_row":"docs/deviations.md#r7"}]}
JSON
run; assert_eq "$?" "1" "crosscheck fail even with deviation stays a violation unless result!=fail"
# (Design: a 'fail' result is always a violation; an accepted deviation is recorded as result 'deviated'.)
cat > "$TMP/h/FEATURE-1.crosscheck.json" <<'JSON'
{"feature_id":"FEATURE-1","checks":[{"rule":"R-7","result":"deviated"}],"deviations":[{"rule":"R-7","deviations_md_row":"docs/deviations.md#r7"}]}
JSON
run; assert_eq "$?" "0" "crosscheck result 'deviated' (w/ deviation row) → accepted (0)"

# Test 9: non-JSON artifact → violation (1)
printf '{not json\n' > "$TMP/h/FEATURE-1.architecture.json"
rm -f "$TMP/h/FEATURE-1.crosscheck.json"
run; assert_eq "$?" "1" "non-JSON artifact → violation (1)"

# --- Invariant 4: v1.1 probe-group propagation (TICKET-114) ---

# Test 10: v1.0 profile alongside a valid artifact → vacuous-pass on invariant 4 (0)
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"db","complexity":"medium","applicable_rules":["g-node-007",$EO_ALL]}]}
JSON
cat > "$TMP/h/FEATURE-1.business-intake.json" <<'JSON'
{"schema_version":"1.0","complete":true,"answers":{"workload":"x"},"grounded_in":["s"]}
JSON
run; assert_eq "$?" "0" "invariant 4: v1.0 profile → vacuous pass (0)"

# Test 11: v1.1 profile — every activated namespace propagates via a matching source_namespace → 0
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"auth","complexity":"medium","applicable_rules":["g-node-007","g-iam-001",$EO_ALL]}
]}
JSON
cat > "$TMP/h/FEATURE-1.business-intake.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{
   "workload_types":["rest-api"],"namespaces":["iam","security-governance"],
   "activated_probe_namespaces":["iam","security-governance"]
 },
 "probes":{
   "iam":{"identity_federation":"oidc-federated"},
   "security-governance":{"ai_risk_tier":"annex-iii-high"}
 },
 "grounded_in":["s"],"grounded_in_namespaces":["iam","security-governance"],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"},
 "unanswered":[]}
JSON
run; assert_eq "$?" "0" "invariant 4: v1.1 propagation complete → 0"

# Test 12: v1.1 profile activates `iam` but no iam-namespaced rule referenced → violation (1)
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"other","complexity":"medium","applicable_rules":["g-node-007",$EO_ALL]}
]}
JSON
# (business-intake still activates iam+security-governance from Test 11; iam not present in applicable_rules)
run; assert_eq "$?" "1" "invariant 4: v1.1 activated namespace with no matching rule → violation (1)"

# Test 13: v1.1 profile with no activated probe namespaces → invariant 4 trivially passes
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"one","complexity":"medium","applicable_rules":["g-node-007",$EO_ALL]}
]}
JSON
cat > "$TMP/h/FEATURE-1.business-intake.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{
   "workload_types":["baseline"],"namespaces":[],
   "activated_probe_namespaces":[]
 },
 "probes":{},
 "grounded_in":["s"],"grounded_in_namespaces":[],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
run; assert_eq "$?" "0" "invariant 4: v1.1 with no activated probes → 0"

# Test 14: v1.1 profile is malformed JSON → violation (1)
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"x","complexity":"small","applicable_rules":["g-node-007",$EO_ALL]}]}
JSON
printf '{not json\n' > "$TMP/h/FEATURE-1.business-intake.json"
run; assert_eq "$?" "1" "invariant 4: malformed v1.1 profile → violation (1)"

# Test 15: no profile file → invariant 4 vacuous (already-covered baseline still applies)
rm -f "$TMP/h/FEATURE-1.business-intake.json"
run; assert_eq "$?" "0" "invariant 4: no profile file → vacuous pass"

# --- Invariant 4 generalization: v1.1 profile with stack[] (TICKET-118.a / P-13 §30.5 pre-wire) ---
# Rationale: §30.5 makes rule activation progressive — a namespace committed to the stack at
# ANY stage carries the same enforcement-floor obligation as an activated probe namespace.
# The generalized invariant 4 keys on activated_probe_namespaces ∪ stack[].namespace.

# Test 16: v1.1 profile with stack[] adds a namespace beyond activated — decision covers it → 0
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"auth","complexity":"medium","applicable_rules":["g-node-007","g-iam-001",$EO_ALL]},
  {"juncture":"platform","complexity":"medium","applicable_rules":["g-node-007","g-aws-001",$EO_ALL]}
]}
JSON
cat > "$TMP/h/FEATURE-1.business-intake.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{
   "workload_types":["rest-api","aws-platform"],"namespaces":["iam","security-governance","aws"],
   "activated_probe_namespaces":["iam","security-governance"],
   "stack":[
     {"namespace":"iam","source":"classifier","trigger":"vision fired rest-api","added_at":"2026-07-07T14:00:00Z"},
     {"namespace":"security-governance","source":"classifier","trigger":"vision fired regulated","added_at":"2026-07-07T14:00:00Z"},
     {"namespace":"aws","source":"universal-answer","trigger":"answer named AWS","added_at":"2026-07-07T14:05:00Z"}
   ]
 },
 "probes":{
   "iam":{"identity_federation":"oidc-federated"},
   "security-governance":{"ai_risk_tier":"annex-iii-high"}
 },
 "grounded_in":["s"],"grounded_in_namespaces":["iam","security-governance"],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
run; assert_eq "$?" "0" "invariant 4 §30.5: stack[] namespace covered by a decision → 0"

# Test 17: stack[] adds `aws` but no decision references an aws-namespaced rule → violation (1)
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"auth","complexity":"medium","applicable_rules":["g-node-007","g-iam-001",$EO_ALL]}
]}
JSON
# (business-intake still carries iam + security-governance + stack.aws from Test 16; aws now uncovered)
run; assert_eq "$?" "1" "invariant 4 §30.5: stack[] namespace uncovered → violation (1)"

# Test 18: violation error message names the "from stack[]" source
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"auth","complexity":"medium","applicable_rules":["g-node-007","g-iam-001",$EO_ALL]}
]}
JSON
out=$(XC_RULES_FILE="$TMP/rules.json" XC_HANDOFFS_DIR="$TMP/h" "$SCRIPT" 2>&1)
echo "$out" | grep -q "from stack\[\]" && stack_msg_ok=1 || stack_msg_ok=0
assert_eq "$stack_msg_ok" "1" "invariant 4 §30.5: violation names 'from stack[]' provenance"

# Test 19: stack[].namespace and activated_probe_namespaces overlap — no double-report
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"auth","complexity":"medium","applicable_rules":["g-node-007","g-iam-001","g-aws-001",$EO_ALL]}
]}
JSON
cat > "$TMP/h/FEATURE-1.business-intake.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{
   "workload_types":["aws-platform"],"namespaces":["iam","security-governance","aws"],
   "activated_probe_namespaces":["iam","security-governance","aws"],
   "stack":[
     {"namespace":"iam","source":"classifier","trigger":"vision fired","added_at":"2026-07-07T14:00:00Z"},
     {"namespace":"aws","source":"classifier","trigger":"vision fired","added_at":"2026-07-07T14:00:00Z"}
   ]
 },
 "probes":{
   "iam":{"identity_federation":"oidc-federated"},
   "security-governance":{"ai_risk_tier":"annex-iii-high"},
   "aws":{"aws_region_strategy":"multi-region"}
 },
 "grounded_in":["s"],"grounded_in_namespaces":["iam","security-governance","aws"],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
run; assert_eq "$?" "0" "invariant 4 §30.5: stack ∪ activated with all covered → 0"

# Test 20: stack[] empty (v1.1 pre-§30.5-adoption) → falls back to activated_probe_namespaces (unchanged behavior)
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"auth","complexity":"medium","applicable_rules":["g-node-007","g-iam-001",$EO_ALL]}
]}
JSON
cat > "$TMP/h/FEATURE-1.business-intake.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{
   "workload_types":["rest-api"],"namespaces":["iam","security-governance"],
   "activated_probe_namespaces":["iam","security-governance"],
   "stack":[]
 },
 "probes":{
   "iam":{"identity_federation":"oidc-federated"},
   "security-governance":{"ai_risk_tier":"annex-iii-high"}
 },
 "grounded_in":["s"],"grounded_in_namespaces":["iam","security-governance"],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
run; assert_eq "$?" "0" "invariant 4 §30.5: stack[] present-but-empty behaves as pre-§30.5 → 0"

# Test 21: stack[] with a namespace not covered even though activated_probe_namespaces IS covered → violation (1)
# This proves the invariant widens correctly, not just that it's ignored.
cat > "$TMP/h/FEATURE-1.architecture.json" <<JSON
{"schema_version":"1","needs_grounding":0,"decisions":[
  {"juncture":"auth","complexity":"medium","applicable_rules":["g-node-007","g-iam-001",$EO_ALL]}
]}
JSON
cat > "$TMP/h/FEATURE-1.business-intake.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{
   "workload_types":["rest-api"],"namespaces":["iam","security-governance","react"],
   "activated_probe_namespaces":["iam","security-governance"],
   "stack":[
     {"namespace":"iam","source":"classifier","trigger":"vision fired","added_at":"2026-07-07T14:00:00Z"},
     {"namespace":"react","source":"design-decision","trigger":"architect-recommend picked React","added_at":"2026-07-07T14:05:00Z"}
   ]
 },
 "probes":{
   "iam":{"identity_federation":"oidc-federated"},
   "security-governance":{"ai_risk_tier":"annex-iii-high"}
 },
 "grounded_in":["s"],"grounded_in_namespaces":["iam","security-governance"],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
run; assert_eq "$?" "1" "invariant 4 §30.5: stack[] adds react uncovered by any decision → violation (1)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-arch-crosscheck] OK — $passes/$total passed."; exit 0
else log "[test-arch-crosscheck] FAIL — $failures/$total."; exit 1; fi
