#!/usr/bin/env bash
# tests/test-audit-claude-code-compat.sh — unit tests for scripts/audit-claude-code-compat.sh
# Per TICKET-031 / ADR-0036. Exit-code contract: 0 (in-range) / 1 (out-of-range) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-claude-code-compat] starting"

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

SCRIPT=./scripts/audit-claude-code-compat.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: --version 2.1.0 (in range) exits 0
"$SCRIPT" --version 2.1.0 --quiet
assert_eq "$?" "0" "in-range version 2.1.0 exits 0"

# Test 4: --version 2.0.0 (boundary min, inclusive) exits 0
"$SCRIPT" --version 2.0.0 --quiet
assert_eq "$?" "0" "boundary min 2.0.0 (inclusive) exits 0"

# Test 5: --version 3.0.0 (boundary max, exclusive) exits 1
"$SCRIPT" --version 3.0.0 --quiet
assert_eq "$?" "1" "boundary max 3.0.0 (exclusive) exits 1"

# Test 6: --version 1.9.99 (below min) exits 1
"$SCRIPT" --version 1.9.99 --quiet
assert_eq "$?" "1" "below-min 1.9.99 exits 1"

# Test 7: --version 4.5.0 (above max) exits 1
"$SCRIPT" --version 4.5.0 --quiet
assert_eq "$?" "1" "above-max 4.5.0 exits 1"

# Test 8: Output mentions supported_range
out=$("$SCRIPT" --version 2.1.0 2>&1)
assert_match "$out" "supported_range" "in-range output mentions supported_range"

# Test 9: Out-of-range output cites the architecture-principles bump policy
out=$("$SCRIPT" --version 5.0.0 2>&1)
assert_match "$out" "architecture-principles" "out-of-range output cites architecture-principles"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-claude-code-compat] OK — $passes/$total passed."; exit 0
else log "[test-audit-claude-code-compat] FAIL — $failures/$total."; exit 1; fi
