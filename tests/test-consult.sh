#!/usr/bin/env bash
# tests/test-consult.sh — unit tests for scripts/consult.sh
# Per TICKET-063 / ADR-0056. Exit-code contract: 0 (ok) / 1 (prereq missing) / 2 (usage).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-consult] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}
assert_match() {
    case "$1" in *"$2"*) log "  ✓ $3"; passes=$((passes+1)) ;; *) log "  ✗ $3 (no '$2')"; failures=$((failures+1)) ;; esac
}

SCRIPT=./scripts/consult.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: no args exits 2
"$SCRIPT" >/dev/null 2>&1; assert_eq "$?" "2" "no args exits 2"
# Test 3: unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 4: --preflight with ruby + engine present → 0
"$SCRIPT" --preflight >/dev/null 2>&1; assert_eq "$?" "0" "--preflight OK (ruby + engine present) exits 0"

# Test 5: ruby absent → 1
CONSULT_RUBY_BIN=/no/such/ruby "$SCRIPT" --preflight >/dev/null 2>&1
assert_eq "$?" "1" "ruby absent → exit 1 (hard prereq, ADR-0056 D-D)"

# Test 6: ruby too old (raise the minimum so current ruby fails) → 1
out=$(CONSULT_MIN_RUBY=99.0 "$SCRIPT" --preflight 2>&1); ec=$?
assert_eq "$ec" "1" "ruby below CONSULT_MIN_RUBY → exit 1"
assert_match "$out" "required on PATH" "old-ruby path explains the requirement"

# Test 7: engine absent (empty cache fixture) → 1
TMP=$(mktemp -d -t consult-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/commands"   # commands dir exists but no engine scripts
CONSULT_PLUGIN_CACHE="$TMP" "$SCRIPT" --preflight >/dev/null 2>&1
assert_eq "$?" "1" "CTP engine absent → exit 1"

# Test 8: --engine-path resolves a real engine script → 0 + prints a path
out=$("$SCRIPT" --engine-path architect-session.sh 2>&1); ec=$?
assert_eq "$ec" "0" "--engine-path architect-session.sh → exit 0"
assert_match "$out" "commands/architect-session.sh" "--engine-path prints the resolved path"

# Test 9: --engine-path rejects a non-allowlisted name → 1
"$SCRIPT" --engine-path evil.sh >/dev/null 2>&1
assert_eq "$?" "1" "--engine-path disallowed name → exit 1"

# Test 10: --engine-path missing arg → 2
"$SCRIPT" --engine-path >/dev/null 2>&1
assert_eq "$?" "2" "--engine-path missing arg → exit 2"

# --- --validate (consult-artifact gate, A-4) ---
if command -v node >/dev/null 2>&1; then
    # Valid artifact → 0
    cat > "$TMP/good.json" <<'JSON'
{"schema_version":"1","feature_id":"FEATURE-001","ruby_ok":true,"needs_grounding":0,
 "decisions":[{"juncture":"auth","user_choice":"hosted","complexity":"medium","applicable_rules":["g-security-governance-require-provenance"]}]}
JSON
    "$SCRIPT" --validate "$TMP/good.json" >/dev/null 2>&1
    assert_eq "$?" "0" "--validate: contract-valid artifact → exit 0"

    # needs_grounding != 0 → 1
    cat > "$TMP/ng.json" <<'JSON'
{"schema_version":"1","needs_grounding":2,"decisions":[{"juncture":"x","complexity":"small","applicable_rules":["r"]}]}
JSON
    "$SCRIPT" --validate "$TMP/ng.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--validate: needs_grounding != 0 → exit 1 (cite-or-decline)"

    # decision missing complexity → 1
    cat > "$TMP/nc.json" <<'JSON'
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"x","applicable_rules":["r"]}]}
JSON
    "$SCRIPT" --validate "$TMP/nc.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--validate: decision missing complexity → exit 1"

    # decision empty applicable_rules → 1
    cat > "$TMP/nr.json" <<'JSON'
{"schema_version":"1","needs_grounding":0,"decisions":[{"juncture":"x","complexity":"large","applicable_rules":[]}]}
JSON
    "$SCRIPT" --validate "$TMP/nr.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--validate: decision empty applicable_rules → exit 1"

    # invalid JSON → 1
    printf '{not json\n' > "$TMP/bad.json"
    "$SCRIPT" --validate "$TMP/bad.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--validate: non-JSON → exit 1"

    # missing file → 2
    "$SCRIPT" --validate "$TMP/nope.json" >/dev/null 2>&1
    assert_eq "$?" "2" "--validate: missing file → exit 2"

    # missing arg → 2
    "$SCRIPT" --validate >/dev/null 2>&1
    assert_eq "$?" "2" "--validate: missing arg → exit 2"

    # --- --roadmap (Stage 7 renderer, CL-4) ---
    # missing arg → 2
    "$SCRIPT" --roadmap >/dev/null 2>&1
    assert_eq "$?" "2" "--roadmap: missing arg → exit 2"
    # missing file → 2
    "$SCRIPT" --roadmap "$TMP/nope.json" >/dev/null 2>&1
    assert_eq "$?" "2" "--roadmap: missing file → exit 2"
    # refuses to render an invalid artifact → 1
    "$SCRIPT" --roadmap "$TMP/ng.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--roadmap: invalid artifact → exit 1 (never render from invalid)"

    # valid multi-decision artifact: B depends_on A (listed B-first to prove sequencing).
    cat > "$TMP/rm.json" <<'JSON'
{"schema_version":"1","feature_id":"FEATURE-007","user_request":"build a thing","ruby_ok":true,"needs_grounding":0,
 "recommended_option":"opt-a","options":[{"id":"opt-a","grounded_in":["nist-800-53","owasp-asvs"]}],
 "decisions":[
   {"juncture":"B","user_choice":"do B","complexity":"large","applicable_rules":["r1"],"depends_on":["A"]},
   {"juncture":"A","user_choice":"do A","complexity":"small","applicable_rules":["r1"]}
 ]}
JSON
    out=$("$SCRIPT" --roadmap "$TMP/rm.json" 2>&1); ec=$?
    assert_eq "$ec" "0" "--roadmap: contract-valid artifact → exit 0"
    assert_match "$out" "§Roadmap JSON" "--roadmap: emits the §Roadmap JSON block"
    assert_match "$out" "world_class_basis" "--roadmap: carries world_class_basis"
    assert_match "$out" "1. [small] do A" "--roadmap: topo-sequences dependency A first"
    assert_match "$out" "2. [large] do B" "--roadmap: dependent B second"
    assert_match "$out" "nist-800-53" "--roadmap: grounding pulled from recommended option"

    # dependency cycle (A↔B) → 1
    cat > "$TMP/cyc.json" <<'JSON'
{"schema_version":"1","feature_id":"FEATURE-008","ruby_ok":true,"needs_grounding":0,
 "decisions":[
   {"juncture":"A","complexity":"small","applicable_rules":["r"],"depends_on":["B"]},
   {"juncture":"B","complexity":"small","applicable_rules":["r"],"depends_on":["A"]}
 ]}
JSON
    out=$("$SCRIPT" --roadmap "$TMP/cyc.json" 2>&1); ec=$?
    assert_eq "$ec" "1" "--roadmap: dependency cycle → exit 1"
    assert_match "$out" "cycle" "--roadmap: names the cycle as the reason"

    # --- --validate-profile (business-profile.json gate, TICKET-114) ---
    # missing arg → 2
    "$SCRIPT" --validate-profile >/dev/null 2>&1
    assert_eq "$?" "2" "--validate-profile: missing arg → exit 2"
    # missing file → 2
    "$SCRIPT" --validate-profile "$TMP/no-such-profile.json" >/dev/null 2>&1
    assert_eq "$?" "2" "--validate-profile: missing file → exit 2"

    # v1.0 profile — valid (as CTP emits at pin 0cf28fe today)
    cat > "$TMP/prof10.json" <<'JSON'
{"schema_version":"1.0","complete":true,
 "answers":{"workload":"grade certification exams at 5-10x volume","motivation":"revenue"},
 "grounded_in":["azure-waf-business-requirements","nist-800-53"]}
JSON
    "$SCRIPT" --validate-profile "$TMP/prof10.json" >/dev/null 2>&1
    assert_eq "$?" "0" "--validate-profile: v1.0 valid profile → exit 0"

    # v1.0 profile — missing workload
    cat > "$TMP/prof10-bad.json" <<'JSON'
{"schema_version":"1.0","complete":false,"answers":{"motivation":"revenue"},"grounded_in":["s"]}
JSON
    out=$("$SCRIPT" --validate-profile "$TMP/prof10-bad.json" 2>&1); ec=$?
    assert_eq "$ec" "1" "--validate-profile: v1.0 missing workload → exit 1"
    assert_match "$out" "answers.workload" "--validate-profile: v1.0 error names workload"

    # v1.0 profile — grounded_in empty
    cat > "$TMP/prof10-ng.json" <<'JSON'
{"schema_version":"1.0","complete":true,"answers":{"workload":"x"},"grounded_in":[]}
JSON
    "$SCRIPT" --validate-profile "$TMP/prof10-ng.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--validate-profile: v1.0 empty grounded_in → exit 1"

    # v1.1 profile — valid (contract-conformant)
    cat > "$TMP/prof11.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{
   "signals_detected":["backend","ai-high-risk","regulated"],
   "signals_forced":[],"signals_suppressed":[],
   "activated_probe_groups":["universal","security-governance","iam"]
 },
 "probes":{
   "universal":{
     "workload":"grade exams","motivation":"revenue","criticality":"mission-critical",
     "availability_tolerance":"hours","data_loss_tolerance":"minutes",
     "data_sensitivity":"confidential","compliance_regime":"gdpr","scale":"large",
     "budget_posture":"balanced"
   },
   "security-governance":{"ai_risk_tier":"annex-iii-high","provenance_commitment":"signed-attested"},
   "iam":{"identity_federation":"oidc-federated","mfa_scope":"all-users"}
 },
 "grounded_in":["azure-waf-business-requirements","nist-800-53","oauth2-oidc"],
 "grounded_in_namespaces":["_universal","security-governance","iam"],
 "answers":{
   "workload":"grade exams","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes",
   "data_sensitivity":"confidential","compliance_regime":"gdpr","scale":"large",
   "budget_posture":"balanced"
 }}
JSON
    "$SCRIPT" --validate-profile "$TMP/prof11.json" >/dev/null 2>&1
    assert_eq "$?" "0" "--validate-profile: v1.1 valid profile → exit 0"

    # v1.1 profile — missing workload_classification
    cat > "$TMP/prof11-nc.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "probes":{"universal":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}},
 "grounded_in":["s"],"grounded_in_namespaces":["_universal"],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
    out=$("$SCRIPT" --validate-profile "$TMP/prof11-nc.json" 2>&1); ec=$?
    assert_eq "$ec" "1" "--validate-profile: v1.1 missing classifier → exit 1"
    assert_match "$out" "workload_classification" "--validate-profile: v1.1 error names classifier"

    # v1.1 profile — activated probe group but no probes.<group> block
    cat > "$TMP/prof11-np.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{"signals_detected":["x"],"signals_forced":[],"signals_suppressed":[],
   "activated_probe_groups":["universal","iam"]},
 "probes":{"universal":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}},
 "grounded_in":["s"],"grounded_in_namespaces":["_universal","iam"],
 "answers":{"workload":"x","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
    out=$("$SCRIPT" --validate-profile "$TMP/prof11-np.json" 2>&1); ec=$?
    assert_eq "$ec" "1" "--validate-profile: v1.1 activated group with no probes block → exit 1"
    assert_match "$out" "probes.iam" "--validate-profile: v1.1 error names the group"

    # v1.1 profile — universal-9 mirror invariant broken
    cat > "$TMP/prof11-mm.json" <<'JSON'
{"schema_version":"1.1","complete":true,
 "workload_classification":{"signals_detected":["x"],"signals_forced":[],"signals_suppressed":[],
   "activated_probe_groups":["universal"]},
 "probes":{"universal":{"workload":"one","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}},
 "grounded_in":["s"],"grounded_in_namespaces":["_universal"],
 "answers":{"workload":"TWO","motivation":"revenue","criticality":"mission-critical",
   "availability_tolerance":"hours","data_loss_tolerance":"minutes","data_sensitivity":"confidential",
   "compliance_regime":"gdpr","scale":"large","budget_posture":"balanced"}}
JSON
    out=$("$SCRIPT" --validate-profile "$TMP/prof11-mm.json" 2>&1); ec=$?
    assert_eq "$ec" "1" "--validate-profile: v1.1 mirror invariant broken → exit 1"
    assert_match "$out" "does not mirror" "--validate-profile: v1.1 error explains mirror"

    # unsupported schema_version → 1
    printf '{"schema_version":"2.0"}\n' > "$TMP/prof2.json"
    "$SCRIPT" --validate-profile "$TMP/prof2.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--validate-profile: unsupported schema_version → exit 1"

    # non-JSON → 1
    printf '{not json\n' > "$TMP/prof-bad.json"
    "$SCRIPT" --validate-profile "$TMP/prof-bad.json" >/dev/null 2>&1
    assert_eq "$?" "1" "--validate-profile: non-JSON → exit 1"
else
    log "  (skipped --validate / --roadmap / --validate-profile tests: node not on PATH)"
fi

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-consult] OK — $passes/$total passed."; exit 0
else log "[test-consult] FAIL — $failures/$total."; exit 1; fi
