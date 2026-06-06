#!/usr/bin/env bash
# tests/test-audit-plugin-surface.sh — unit tests for scripts/audit-plugin-surface.sh
# Per TICKET-032 / ADR-0037. Exit-code contract: 0 (all declared) / 1 (unknown) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-plugin-surface] starting"

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

SCRIPT=./scripts/audit-plugin-surface.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Default mode exits 0 (all declared)
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "default mode exits 0 (all declared)"

# Test 4: Output mentions summary + counts
out=$("$SCRIPT" 2>&1)
assert_match "$out" "summary" "output contains summary"
assert_match "$out" "CONSUMED" "output mentions CONSUMED count"
assert_match "$out" "DECLARED-NOT-CONSUMED" "output mentions DECLARED-NOT-CONSUMED count"

# Test 5: Inject unknown surface → exit 1
TMPDIR=$(mktemp -d -t plugin-surface-test.XXXXXX) || { log "  ✗ mktemp failed"; failures=$((failures+1)); }
mkdir -p "$TMPDIR/__sneaky_new_dir__"
# Symlink into the plugin cache to simulate a new plugin surface (without actually mutating the pinned cache).
ln -sf "$TMPDIR/__sneaky_new_dir__" .harness/plugin-cache/claude-tdd-pro/__sneaky_new_dir__ 2>/dev/null
"$SCRIPT" --quiet >/dev/null 2>&1
exit_code=$?
rm -f .harness/plugin-cache/claude-tdd-pro/__sneaky_new_dir__
rm -rf "$TMPDIR"
assert_eq "$exit_code" "1" "injected unknown surface triggers exit 1"

# Test 6: Post-restore returns to 0
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "post-restore exits 0 (back to baseline)"

# Test 7: Registry file present
[ -s docs/plugin-surface-consumption.md ] && { log "  ✓ registry file present + non-empty"; passes=$((passes+1)); } \
                                            || { log "  ✗ registry file missing"; failures=$((failures+1)); }

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-plugin-surface] OK — $passes/$total passed."; exit 0
else log "[test-audit-plugin-surface] FAIL — $failures/$total."; exit 1; fi
