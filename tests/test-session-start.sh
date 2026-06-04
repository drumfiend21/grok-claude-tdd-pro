#!/usr/bin/env bash
# tests/test-session-start.sh — unit tests for .claude/hooks/session-start.sh
# Per ADR-0001 warn-only policy: hook always exits 0 (warns but never blocks session).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-session-start] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

HOOK=.claude/hooks/session-start.sh

# Test 1: hook is executable
[ -x "$HOOK" ] && { log "  ✓ hook is executable"; passes=$((passes+1)); } \
                || { log "  ✗ hook not executable"; failures=$((failures+1)); }

# Test 2: hook always exits 0 (warn-only policy per ADR-0001)
"$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "hook exits 0 (warn-only policy)"

# Test 3: hook emits sync-plugin output to stdout
out=$("$HOOK" 2>&1)
case "$out" in
    *plugin-sync*) log "  ✓ hook emits [plugin-sync] log line"; passes=$((passes+1)) ;;
    *) log "  ✗ hook missing [plugin-sync] line"; failures=$((failures+1)) ;;
esac

# Test 4: hook emits plugin-ensure output
case "$out" in
    *plugin-ensure*) log "  ✓ hook emits [plugin-ensure] log line"; passes=$((passes+1)) ;;
    *) log "  ✗ hook missing [plugin-ensure] line"; failures=$((failures+1)) ;;
esac

# Test 5: hook respects $CLAUDE_PROJECT_DIR if set
CLAUDE_PROJECT_DIR="$(pwd)" "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "hook with CLAUDE_PROJECT_DIR set exits 0"

# Test 6: hook degrades gracefully if scripts/sync-plugin.sh is missing
# (Simulate by renaming temporarily; restore in finally-style cleanup)
mv scripts/sync-plugin.sh scripts/sync-plugin.sh.bak
degraded_out=$("$HOOK" 2>&1)
degraded_exit=$?
mv scripts/sync-plugin.sh.bak scripts/sync-plugin.sh  # restore BEFORE asserting
assert_eq "$degraded_exit" "0" "hook with sync-plugin.sh missing still exits 0 (warn-only)"
case "$degraded_out" in
    *WARN*sync-plugin*) log "  ✓ hook emits WARN when sync-plugin.sh missing"; passes=$((passes+1)) ;;
    *) log "  ✗ hook missing degradation WARN"; failures=$((failures+1)) ;;
esac

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-session-start] OK — $passes/$total passed."; exit 0
else log "[test-session-start] FAIL — $failures/$total."; exit 1; fi
