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

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-consult] OK — $passes/$total passed."; exit 0
else log "[test-consult] FAIL — $failures/$total."; exit 1; fi
