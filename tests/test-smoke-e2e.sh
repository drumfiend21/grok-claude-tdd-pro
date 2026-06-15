#!/usr/bin/env bash
# tests/test-smoke-e2e.sh — unit tests for scripts/smoke-e2e.sh
# Covers ADR-0008 exit-code contract: 0 (clean stub-mode pass) / non-zero on hard failure.
# smoke-e2e.sh is itself an integration test; this suite asserts its top-level contract.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-smoke-e2e] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/smoke-e2e.sh

# Test 1: smoke runs and exits 0 on baseline
"$SCRIPT" >/dev/null 2>&1
assert_eq "$?" "0" "smoke exits 0 on baseline"

# Test 2: produces .req.json
[ -f .harness/handoffs/TICKET-042.req.json ] && { log "  ✓ produces .req.json"; passes=$((passes+1)); } \
                                                  || { log "  ✗ missing .req.json"; failures=$((failures+1)); }

# Test 3: produces .res.json
[ -f .harness/handoffs/TICKET-042.res.json ] && { log "  ✓ produces .res.json"; passes=$((passes+1)); } \
                                                  || { log "  ✗ missing .res.json"; failures=$((failures+1)); }

# Test 4: produces trail
[ -f .harness/trails/TICKET-042.md ] && { log "  ✓ produces trail"; passes=$((passes+1)); } \
                                          || { log "  ✗ missing trail"; failures=$((failures+1)); }

# Test 5: produces manifest (post-TICKET-010.a wiring)
[ -f .harness/audit/TICKET-042.manifest.json ] && { log "  ✓ produces manifest"; passes=$((passes+1)); } \
                                                    || { log "  ✗ missing manifest"; failures=$((failures+1)); }

# Test 6: smoke is idempotent — running twice both exit 0
"$SCRIPT" >/dev/null 2>&1
assert_eq "$?" "0" "smoke idempotent (second run exits 0)"

# Test 7: post-smoke, toy at Red baseline (smoke trap reverts)
# Verify by running node --test against the toy; expect 1 failure (slugify trim case)
toy_test_output=$(cd examples/string-utils && node --test 2>&1 || true)
case "$toy_test_output" in
    *"fail"*1*|*"fail"*"1"*|*"tests 1"*|*"fail 1"*)
        log "  ✓ smoke trap restored toy to Red baseline"; passes=$((passes+1)) ;;
    *)
        # Some node --test versions report differently; check exit code instead
        cd examples/string-utils && node --test >/dev/null 2>&1
        toy_exit=$?
        cd - >/dev/null
        if [ "$toy_exit" -ne 0 ]; then
            log "  ✓ smoke trap restored toy to Red baseline (toy tests non-zero)"; passes=$((passes+1))
        else
            log "  ✗ smoke trap did NOT restore Red baseline (toy tests pass)"; failures=$((failures+1))
        fi
        ;;
esac

# Test 8: the test gate pins the TAP reporter (regression guard per TICKET-054 /
# ADR-0051). Node >= 24 defaults to the `spec` reporter ("ℹ pass N"), which the
# "^# pass " parse cannot read; forcing --test-reporter=tap makes the gate work on
# every Node version. This assertion fails loudly if the flag is ever dropped, even
# on a Node version whose default output happens to still parse.
if grep -q -- '--test-reporter=tap' scripts/smoke-e2e.sh; then
    log "  ✓ test gate pins --test-reporter=tap (Node-version-robust)"; passes=$((passes+1))
else
    log "  ✗ test gate no longer pins --test-reporter=tap (will break on Node >= 24)"; failures=$((failures+1))
fi

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-smoke-e2e] OK — $passes/$total passed."; exit 0
else log "[test-smoke-e2e] FAIL — $failures/$total."; exit 1; fi
