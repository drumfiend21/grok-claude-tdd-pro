#!/usr/bin/env bash
# tests/test-audit-standards-conformance.sh — unit tests for
# scripts/audit-standards-conformance.sh. Per TICKET-032 / ADR-0037.
# Exit-code contract: 0 (no findings or all matched) / 1 (unmatched) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-standards-conformance] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}
assert_match() {
    case "$1" in
        *"$2"*) log "  ✓ $3"; passes=$((passes+1)) ;;
        *)      log "  ✗ $3 (no match for '$2')"; failures=$((failures+1)) ;;
    esac
}

SCRIPT=./scripts/audit-standards-conformance.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Default mode exits 0 (no P0 findings on harness substrate)
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "default mode exits 0"

# Test 4: --staged mode exits 0
"$SCRIPT" --staged --quiet >/dev/null 2>&1
assert_eq "$?" "0" "--staged mode exits 0"

# Test 5: Output mentions runner + deviations
out=$("$SCRIPT" 2>&1)
assert_match "$out" "rubric/runner.sh" "output names the rubric runner"

# Test 6: Deviations registry exists + grep-discoverable
[ -s docs/deviations.md ] && { log "  ✓ deviations registry present + non-empty"; passes=$((passes+1)); } \
                          || { log "  ✗ deviations registry missing"; failures=$((failures+1)); }

# Test 7: Deviations registry has the expected header + columns
grep -q "^# Standards Deviation Registry" docs/deviations.md \
    && { log "  ✓ deviations registry has correct title"; passes=$((passes+1)); } \
    || { log "  ✗ deviations registry title missing"; failures=$((failures+1)); }

grep -q "Rule ID.*File scope.*Justification.*ADR.*Expiry trigger" docs/deviations.md \
    && { log "  ✓ deviations registry has correct columns"; passes=$((passes+1)); } \
    || { log "  ✗ deviations registry columns missing"; failures=$((failures+1)); }

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-standards-conformance] OK — $passes/$total passed."; exit 0
else log "[test-audit-standards-conformance] FAIL — $failures/$total."; exit 1; fi
