#!/usr/bin/env bash
# tests/test-install.sh — unit tests for install.sh
# Per TICKET-054 / ADR-0051. Exit-code contract: 0 (installed) / 1 (prereq missing
# or a step failed) / 2 (usage error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-install] starting"

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

SCRIPT=./install.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: --quick sets up and exits 0, skipping the end-to-end verification
out=$("$SCRIPT" --quick 2>&1); ec=$?
assert_eq "$ec" "0" "--quick exits 0"
assert_match "$out" "skipped" "--quick skips the verification step"

# Test 4: default run exits 0 and reports readiness
out=$("$SCRIPT" 2>&1); ec=$?
assert_eq "$ec" "0" "default run exits 0"
assert_match "$out" "ready to go" "default run reports readiness"
assert_match "$out" "verified" "default run runs the end-to-end verification"

# Test 5: prerequisite/location guard — run a copy from a folder with no scripts/.
# install.sh cd's to its own dirname, so a copy in an empty temp dir must detect
# that it is not in the project folder and exit 1 (not 0, not crash).
TMP=$(mktemp -d -t install-test.XXXXXX) || { log "mktemp failed"; exit 1; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
cp install.sh "$TMP/install.sh"
out=$(bash "$TMP/install.sh" 2>&1); ec=$?
assert_eq "$ec" "1" "missing project folder exits 1"
assert_match "$out" "project folder" "missing-folder path explains the problem"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-install] OK — $passes/$total passed."; exit 0
else log "[test-install] FAIL — $failures/$total."; exit 1; fi
