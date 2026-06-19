#!/usr/bin/env bash
# tests/test-audit-rules-verified.sh — unit tests for scripts/audit-rules-verified.sh.
# Per TICKET-067 / ADR-0037. Exit-code contract: 0 (gate holds / vacuous) / 1 (violation) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-rules-verified] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-rules-verified.sh

TMP=$(mktemp -d -t rv-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/h"

# A deviations registry fixture: r-dev has a row, r-nodev does not.
cat > "$TMP/dev.md" <<'MD'
| Rule ID | File scope | Justification | ADR | Expiry |
|---|---|---|---|---|
| r-dev | src/** | legacy | ADR-0099 | when X |
MD

run() { RV_HANDOFFS_DIR="$TMP/h" RV_DEVIATIONS="$TMP/dev.md" "$SCRIPT" --quiet >/dev/null 2>&1; }
mkreq() { printf '%s\n' "$2" > "$TMP/h/$1.req.json"; }
mkres() { printf '%s\n' "$2" > "$TMP/h/$1.res.json"; }
clear_h() { rm -f "$TMP/h"/*.json; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: no pairs → vacuous pass (0)
clear_h; run; assert_eq "$?" "0" "no req/res pairs → vacuous pass (0)"

# Test 4: req with no matching res → still vacuous (no pair) (0)
clear_h
mkreq T1 '{"ticket_id":"T1","applicable_rules":["r1"]}'
run; assert_eq "$?" "0" "request without a response → vacuous (0)"

# Test 5: green, every applicable rule pass → 0
clear_h
mkreq T1 '{"ticket_id":"T1","applicable_rules":["r1","r2"]}'
mkres T1 '{"ticket_id":"T1","status":"green","rules_verified":{"r1":"pass","r2":"pass"}}'
run; assert_eq "$?" "0" "green + all applicable rules pass → 0"

# Test 6: green but a rule failed → violation (1)
clear_h
mkreq T1 '{"applicable_rules":["r1","r2"]}'
mkres T1 '{"status":"green","rules_verified":{"r1":"pass","r2":"fail"}}'
run; assert_eq "$?" "1" "green with a fail → violation (1)"

# Test 7: green but an applicable rule has no rules_verified key → violation (1)
clear_h
mkreq T1 '{"applicable_rules":["r1","r2"]}'
mkres T1 '{"status":"green","rules_verified":{"r1":"pass"}}'
run; assert_eq "$?" "1" "green with a missing applicable-rule key → violation (1)"

# Test 8: green + deviated WITH a deviations.md row → accepted (0)
clear_h
mkreq T1 '{"applicable_rules":["r1","r-dev"]}'
mkres T1 '{"status":"green","rules_verified":{"r1":"pass","r-dev":"deviated"}}'
run; assert_eq "$?" "0" "green + deviated w/ deviations row → accepted (0)"

# Test 9: green + deviated but NO deviations.md row → violation (1)
clear_h
mkreq T1 '{"applicable_rules":["r1","r-nodev"]}'
mkres T1 '{"status":"green","rules_verified":{"r1":"pass","r-nodev":"deviated"}}'
run; assert_eq "$?" "1" "green + deviated w/o deviations row → violation (1)"

# Test 10: RED response with a fail → NOT a violation (gate binds only green) (0)
clear_h
mkreq T1 '{"applicable_rules":["r1","r2"]}'
mkres T1 '{"status":"red","rules_verified":{"r1":"pass","r2":"fail"}}'
run; assert_eq "$?" "0" "red with a fail → not gated (0)"

# Test 11: invalid rules_verified value (even on red) → violation (1)
clear_h
mkreq T1 '{"applicable_rules":["r1"]}'
mkres T1 '{"status":"red","rules_verified":{"r1":"maybe"}}'
run; assert_eq "$?" "1" "invalid rules_verified value → violation (1)"

# Test 12: request without applicable_rules → fail-closed note, not gated (0)
clear_h
mkreq T1 '{"ticket_id":"T1"}'
mkres T1 '{"status":"green","rules_verified":{}}'
run; assert_eq "$?" "0" "no applicable_rules → fail-closed note, not gated (0)"

# Test 13: non-JSON response → violation (1)
clear_h
mkreq T1 '{"applicable_rules":["r1"]}'
printf '{not json\n' > "$TMP/h/T1.res.json"
run; assert_eq "$?" "1" "non-JSON response → violation (1)"

# --- ADR-0062 (Fix B) extended verdicts: not_applicable (neutral) + not_enforced (red) ---

# Test 14: green + not_applicable on an applicable rule → accepted (0)
clear_h
mkreq T1 '{"applicable_rules":["r1","r2"]}'
mkres T1 '{"status":"green","rules_verified":{"r1":"pass","r2":"not_applicable"}}'
run; assert_eq "$?" "0" "green + not_applicable → accepted (0)"

# Test 15: green + not_enforced on an applicable rule → violation (1)
clear_h
mkreq T1 '{"applicable_rules":["r1","r2"]}'
mkres T1 '{"status":"green","rules_verified":{"r1":"pass","r2":"not_enforced"}}'
run; assert_eq "$?" "1" "green + not_enforced → violation (1)"

# Test 16: red response carrying not_enforced → not gated (0)
clear_h
mkreq T1 '{"applicable_rules":["r1"]}'
mkres T1 '{"status":"red","rules_verified":{"r1":"not_enforced"}}'
run; assert_eq "$?" "0" "red + not_enforced → not gated (0)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-rules-verified] OK — $passes/$total passed."; exit 0
else log "[test-rules-verified] FAIL — $failures/$total."; exit 1; fi
