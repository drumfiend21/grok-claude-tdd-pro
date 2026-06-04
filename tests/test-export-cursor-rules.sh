#!/usr/bin/env bash
# tests/test-export-cursor-rules.sh — unit tests for scripts/export-cursor-rules.sh
# Covers ADR-0014 exit-code contract: 0 (write success / --check clean) / 1 (--check drift) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-export-cursor-rules] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/export-cursor-rules.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: --check on clean state exits 0
"$SCRIPT" --check --quiet >/dev/null 2>&1
assert_eq "$?" "0" "--check clean exits 0"

# Test 4: Default write mode exits 0 + leaves --check clean (idempotent)
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "default write exits 0"
"$SCRIPT" --check --quiet >/dev/null 2>&1
assert_eq "$?" "0" "post-write --check exits 0 (idempotent)"

# Test 5: --check after hand-edit detects drift (exit 1)
TARGET=.cursor/rules/agent-context.mdc
backup=$(mktemp)
cp "$TARGET" "$backup"
printf '\n# UNIT-TEST TAMPER\n' >> "$TARGET"
"$SCRIPT" --check --quiet >/dev/null 2>&1
exit_code=$?
mv "$backup" "$TARGET"   # restore BEFORE asserting in case of test failure
assert_eq "$exit_code" "1" "--check after hand-edit exits 1"

# Test 6: post-restore --check is clean again
"$SCRIPT" --check --quiet >/dev/null 2>&1
assert_eq "$?" "0" "post-restore --check exits 0"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-export-cursor-rules] OK — $passes/$total passed."; exit 0
else log "[test-export-cursor-rules] FAIL — $failures/$total."; exit 1; fi
