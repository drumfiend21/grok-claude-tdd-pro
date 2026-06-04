#!/usr/bin/env bash
# tests/test-post-tool-use-review-gate.sh — unit tests for .claude/hooks/post-tool-use-review-gate.sh
# Covers ADR-0022 exit-code contract: 0 (allowed/no-op) / 2 (forbidden-path violation).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-post-tool-use-review-gate] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

HOOK=.claude/hooks/post-tool-use-review-gate.sh

# Allowed-path test: edit to docs/ should exit 0
echo '{"tool_name":"Edit","tool_input":{"file_path":"docs/quality-gate.md"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "Edit to docs/quality-gate.md exits 0 (allowed path)"

# Forbidden: .harness/plugin-cache/
echo '{"tool_name":"Edit","tool_input":{"file_path":".harness/plugin-cache/x/CLAUDE.md"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "2" ".harness/plugin-cache/ edit exits 2"

# Forbidden: claude-tdd-pro/
echo '{"tool_name":"Write","tool_input":{"file_path":"claude-tdd-pro/CLAUDE.md"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "2" "claude-tdd-pro/ edit exits 2"

# Forbidden: .claude/skills/tdd-pro-* symlinks
echo '{"tool_name":"Edit","tool_input":{"file_path":".claude/skills/tdd-pro-cl-workflow/SKILL.md"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "2" ".claude/skills/tdd-pro-* edit exits 2"

# Forbidden: .cursor/rules/*.mdc generator output
echo '{"tool_name":"Write","tool_input":{"file_path":".cursor/rules/agent-context.mdc"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "2" ".cursor/rules/*.mdc edit exits 2"

# Non-edit tool: Bash should be no-op
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "Bash tool (non-edit) exits 0 (no-op)"

# MultiEdit on forbidden path
echo '{"tool_name":"MultiEdit","tool_input":{"file_path":".cursor/rules/d-rules.mdc"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "2" "MultiEdit to .cursor/rules/*.mdc exits 2"

# Empty stdin (malformed) exits 0 (no tool_name → no-op)
echo '' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "empty stdin exits 0 (defensive no-op)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-post-tool-use-review-gate] OK — $passes/$total passed."; exit 0
else log "[test-post-tool-use-review-gate] FAIL — $failures/$total."; exit 1; fi
