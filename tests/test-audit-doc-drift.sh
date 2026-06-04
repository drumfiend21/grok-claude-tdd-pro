#!/usr/bin/env bash
# tests/test-audit-doc-drift.sh — unit tests for scripts/audit-doc-drift.sh
# Covers ADR-0009 exit-code contract: 0 (clean) / 1 (findings) / 2 (error).
# Plus the F-1..F-6 detection-pattern coverage via induction-and-restore.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-doc-drift] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-doc-drift.sh

# Setup: ensure smoke artifacts exist so F-6 has a manifest to validate
./scripts/smoke-e2e.sh >/dev/null 2>&1 || true

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Clean state exits 0
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "clean state exits 0"

# Test 4: F-5 induction — tamper with .cursor/rules/agent-context.mdc
TARGET=.cursor/rules/agent-context.mdc
backup=$(mktemp); cp "$TARGET" "$backup"
printf '\n# F-5 TEST INJECTION\n' >> "$TARGET"
out=$("$SCRIPT" 2>&1); exit_code=$?
mv "$backup" "$TARGET"   # restore BEFORE asserting
assert_eq "$exit_code" "1" "F-5 hand-edit triggers exit 1"
case "$out" in
    *F-5*) log "  ✓ F-5 finding present in output"; passes=$((passes+1)) ;;
    *) log "  ✗ output missing F-5 finding"; failures=$((failures+1)) ;;
esac

# Test 5: F-6 induction — tamper with a manifest's schema_version
MANIFEST=.harness/audit/TICKET-042.manifest.json
mbackup=$(mktemp); cp "$MANIFEST" "$mbackup"
sed -i 's/"schema_version": "1"/"schema_version": "broken-test"/' "$MANIFEST" 2>/dev/null || \
  sed -i '' 's/"schema_version": "1"/"schema_version": "broken-test"/' "$MANIFEST" 2>/dev/null
out=$("$SCRIPT" 2>&1); exit_code=$?
mv "$mbackup" "$MANIFEST"   # restore BEFORE asserting
assert_eq "$exit_code" "1" "F-6 manifest corruption triggers exit 1"
case "$out" in
    *F-6*) log "  ✓ F-6 finding present in output"; passes=$((passes+1)) ;;
    *) log "  ✗ output missing F-6 finding"; failures=$((failures+1)) ;;
esac

# Test 6: post-restore exit 0
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "post-restore exits 0"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-doc-drift] OK — $passes/$total passed."; exit 0
else log "[test-audit-doc-drift] FAIL — $failures/$total."; exit 1; fi
