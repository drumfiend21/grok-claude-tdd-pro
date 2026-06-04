#!/usr/bin/env bash
# tests/test-audit-hook-security.sh — unit tests for scripts/audit-hook-security.sh
# Per TICKET-029 / ADR-0034. Exit-code contract: 0 (baseline-matched) / 1 (new
# findings) / 2 (script error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-hook-security] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-hook-security.sh
BASELINE=tests/hook-security-baseline.txt

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Default mode exits 0 (baseline matched)
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "default mode exits 0 (baseline matched)"

# Test 4: Baseline file present
[ -s "$BASELINE" ] && { log "  ✓ baseline exists + non-empty"; passes=$((passes+1)); } \
                   || { log "  ✗ baseline missing or empty"; failures=$((failures+1)); }

# Test 5: NEW finding (eval injection) → exit 1
TMPSH=tests/__sec_test__.sh
printf '%s\n' '#!/bin/bash' 'eval "$1"' > "$TMPSH"
chmod +x "$TMPSH"
"$SCRIPT" --quiet >/dev/null 2>&1
exit_code=$?
rm -f "$TMPSH"   # restore BEFORE asserting
assert_eq "$exit_code" "1" "new eval pattern triggers exit 1"

# Test 6: Post-restore returns to baseline
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "post-restore exits 0 (back to baseline)"

# Test 7: NEW hardcoded secret → exit 1
TMPSH=tests/__sec_test_secret__.sh
printf '%s\n' '#!/bin/bash' 'API_TOKEN="abc123secret"' > "$TMPSH"
"$SCRIPT" --quiet >/dev/null 2>&1
exit_code=$?
rm -f "$TMPSH"
assert_eq "$exit_code" "1" "hardcoded _TOKEN= triggers exit 1"

# Test 8: Output mentions key terminology
out=$("$SCRIPT" 2>&1)
case "$out" in
    *baseline*) log "  ✓ output mentions baseline"; passes=$((passes+1)) ;;
    *)          log "  ✗ output missing baseline mention"; failures=$((failures+1)) ;;
esac
case "$out" in
    *finding*) log "  ✓ output mentions findings"; passes=$((passes+1)) ;;
    *)         log "  ✗ output missing findings mention"; failures=$((failures+1)) ;;
esac

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-hook-security] OK — $passes/$total passed."; exit 0
else log "[test-audit-hook-security] FAIL — $failures/$total."; exit 1; fi
