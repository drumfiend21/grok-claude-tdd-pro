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

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-arch-crosscheck] OK — $passes/$total passed."; exit 0
else log "[test-arch-crosscheck] FAIL — $failures/$total."; exit 1; fi
