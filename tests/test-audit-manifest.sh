#!/usr/bin/env bash
# tests/test-audit-manifest.sh — unit tests for scripts/audit-manifest.sh
# Covers ADR-0020 exit-code contract: 0 (clean / no manifests) / 1 (findings) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-manifest] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-manifest.sh

# Setup: ensure smoke artifacts exist
./scripts/smoke-e2e.sh >/dev/null 2>&1 || true

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Walk-all mode on clean state exits 0
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "walk-all clean exits 0"

# Test 4: One-shot mode on a valid manifest exits 0
"$SCRIPT" --quiet .harness/audit/TICKET-042.manifest.json >/dev/null 2>&1
assert_eq "$?" "0" "one-shot on valid manifest exits 0"

# Test 5: One-shot on missing file exits 2
"$SCRIPT" --quiet /tmp/does-not-exist.manifest.json >/dev/null 2>&1
assert_eq "$?" "2" "one-shot on missing file exits 2"

# Test 6: Two explicit files exits 2 (only one allowed)
"$SCRIPT" --quiet a.json b.json >/dev/null 2>&1
assert_eq "$?" "2" "two explicit files exits 2"

# Test 7: Corrupt manifest (schema_version mutated) is detected (exit 1)
TARGET=.harness/audit/TICKET-042.manifest.json
backup=$(mktemp); cp "$TARGET" "$backup"
sed -i 's/"schema_version": "1"/"schema_version": "broken"/' "$TARGET" 2>/dev/null || \
  (sed -i '' 's/"schema_version": "1"/"schema_version": "broken"/' "$TARGET" 2>/dev/null)
"$SCRIPT" --quiet >/dev/null 2>&1
exit_code=$?
mv "$backup" "$TARGET"   # restore BEFORE asserting
assert_eq "$exit_code" "1" "corrupt schema_version triggers exit 1"

# Test 8: post-restore audit clean
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "post-restore exits 0"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-manifest] OK — $passes/$total passed."; exit 0
else log "[test-audit-manifest] FAIL — $failures/$total."; exit 1; fi
