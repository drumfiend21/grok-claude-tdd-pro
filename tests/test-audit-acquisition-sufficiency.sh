#!/usr/bin/env bash
# tests/test-audit-acquisition-sufficiency.sh — unit tests for
# scripts/audit-acquisition-sufficiency.sh (TICKET-127.a, P-18 §3.1).
# Exit-code contract: 0 (all pass) / 1 (assertions failed) / 2 (harness error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-acquisition-sufficiency] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}
assert_match() {
    case "$1" in *"$2"*) log "  ✓ $3"; passes=$((passes+1)) ;; *) log "  ✗ $3 (no '$2')"; failures=$((failures+1)) ;; esac
}

SCRIPT=./scripts/audit-acquisition-sufficiency.sh

TMP=$(mktemp -d -t aas-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/store/FEATURE-TEST"
mkdir -p "$TMP/consult/FEATURE-TEST/intake"

# Minimal rules.json — needed by the global-count node -e block; empty rules is fine.
cat > "$TMP/rules.json" <<'JSON'
{"rules":[{"id":"g-vue-external","source_namespace":"vue"}]}
JSON

# Baseline env for every run.
run() {
    AAS_RULES_FILE="$TMP/rules.json" \
    AAS_PROJECT_STORE="$TMP/store" \
    AAS_CONSULT_WORK="$TMP/consult" \
    "$SCRIPT" "$@" --quiet
}

# --- Test 1: --help exits 0.
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"

# --- Test 2: missing --project exits 2.
"$SCRIPT" --quiet >/dev/null 2>&1; assert_eq "$?" "2" "missing --project exits 2 (usage error)"

# --- Test 3: unknown flag exits 2.
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# --- Test 4: project with no stacked techs → vacuous pass (exit 0).
run --project FEATURE-EMPTY; assert_eq "$?" "0" "no stacked techs (no overlay dir, no stage-0) → vacuous pass"

# --- Test 5: stacked tech with rule count below threshold → exit 1.
mkdir -p "$TMP/store/FEATURE-TEST/vue"
cat > "$TMP/store/FEATURE-TEST/vue/stub.yaml" <<'YAML'
rules:
- id: vue/rule-1
  name: rule-1
- id: vue/rule-2
  name: rule-2
- id: vue/rule-3
  name: rule-3
YAML
run --project FEATURE-TEST; assert_eq "$?" "1" "vue with 3 rules < threshold 30 → violation exit 1"

# --- Test 6: violation output identifies tech + count + shortfall.
out=$(AAS_RULES_FILE="$TMP/rules.json" AAS_PROJECT_STORE="$TMP/store" AAS_CONSULT_WORK="$TMP/consult" "$SCRIPT" --project FEATURE-TEST 2>&1)
assert_match "$out" "tech=vue" "violation output names the tech"
assert_match "$out" "count=4" "violation output shows count=4 (3 overlay + 1 global)"
assert_match "$out" "threshold=30" "violation output shows threshold"
assert_match "$out" "shortfall=26" "violation output shows shortfall"

# --- Test 7: --threshold override honored (raise to 100; still fails).
run --project FEATURE-TEST --threshold 100; assert_eq "$?" "1" "--threshold 100 → still fails"
out=$(AAS_RULES_FILE="$TMP/rules.json" AAS_PROJECT_STORE="$TMP/store" AAS_CONSULT_WORK="$TMP/consult" "$SCRIPT" --project FEATURE-TEST --threshold 100 2>&1)
assert_match "$out" "threshold=100" "output reflects overridden threshold"

# --- Test 8: --threshold override honored (lower to 4; should pass since overlay 3 + global 1 = 4).
run --project FEATURE-TEST --threshold 4; assert_eq "$?" "0" "--threshold 4 (equal to actual count) → pass"

# --- Test 9: substantial acquisition (30 stub rules) → pass at default threshold.
mkdir -p "$TMP/store/FEATURE-BIG/vue"
{
    echo "rules:"
    for i in $(seq 1 32); do
        echo "- id: vue/rule-$i"
        echo "  name: rule-$i"
    done
} > "$TMP/store/FEATURE-BIG/vue/stub.yaml"
run --project FEATURE-BIG; assert_eq "$?" "0" "32 rules >= threshold 30 → pass"

# --- Test 10: stage-0 stack is honored — a tech in stack[] but with no overlay
# still counts against global; if global is 0 and no overlay → violation.
mkdir -p "$TMP/consult/FEATURE-STACKED/intake"
cat > "$TMP/consult/FEATURE-STACKED/intake/stage-0-classifier.json" <<'JSON'
{"workload_classification":{"stack":[{"namespace":"react","source":"stack-add","trigger":"--stack-add react","added_at":"2026-07-11T00:00:00Z"}]}}
JSON
run --project FEATURE-STACKED; assert_eq "$?" "1" "stage-0 stack.react with no overlay + no global → violation"
out=$(AAS_RULES_FILE="$TMP/rules.json" AAS_PROJECT_STORE="$TMP/store" AAS_CONSULT_WORK="$TMP/consult" "$SCRIPT" --project FEATURE-STACKED 2>&1)
assert_match "$out" "tech=react" "violation output names react (from stage-0 stack.namespace)"

# --- Test 11: mixed pass/fail — one tech OK, one below → violation lists only failing tech.
mkdir -p "$TMP/store/FEATURE-MIX/vue"
mkdir -p "$TMP/store/FEATURE-MIX/angular"
{
    echo "rules:"
    for i in $(seq 1 35); do echo "- id: vue/rule-$i"; echo "  name: r$i"; done
} > "$TMP/store/FEATURE-MIX/vue/stub.yaml"
{
    echo "rules:"
    for i in $(seq 1 5); do echo "- id: angular/rule-$i"; echo "  name: r$i"; done
} > "$TMP/store/FEATURE-MIX/angular/stub.yaml"
run --project FEATURE-MIX; assert_eq "$?" "1" "mixed pass/fail → violation exit 1"
out=$(AAS_RULES_FILE="$TMP/rules.json" AAS_PROJECT_STORE="$TMP/store" AAS_CONSULT_WORK="$TMP/consult" "$SCRIPT" --project FEATURE-MIX 2>&1)
assert_match "$out" "tech=angular" "mixed violation names the failing tech"
case "$out" in
    *"[VIOLATION] tech=vue"*) log "  ✗ mixed: passing vue must NOT appear as VIOLATION"; failures=$((failures+1)) ;;
    *) log "  ✓ mixed: passing vue does not appear as VIOLATION"; passes=$((passes+1)) ;;
esac

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-acquisition-sufficiency] OK — $passes/$total passed."; exit 0
else log "[test-audit-acquisition-sufficiency] FAIL — $failures/$total."; exit 1; fi
