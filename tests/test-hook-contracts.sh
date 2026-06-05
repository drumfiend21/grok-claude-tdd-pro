#!/usr/bin/env bash
# tests/test-hook-contracts.sh — hook-payload contract tests
# Per TICKET-031 / ADR-0036: pins the Claude Code hook payload contract by
# feeding golden fixtures to each hook script and asserting the documented
# exit-code + output shape. If Anthropic changes a hook payload field, the
# fixtures stay frozen and the test fails — surfacing the breakage in CI
# rather than at runtime.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-hook-contracts] starting"

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

FIXTURES=tests/fixtures/hook-payloads
GATE_HOOK=.claude/hooks/post-tool-use-review-gate.sh

# Test 1: Fixtures directory present
[ -d "$FIXTURES" ] && { log "  ✓ fixtures directory present"; passes=$((passes+1)); } \
                  || { log "  ✗ fixtures directory missing"; failures=$((failures+1)); }

# Test 2: All required fixtures present
for f in post-tool-use-edit.json post-tool-use-write.json post-tool-use-forbidden.json post-tool-use-non-edit.json; do
    if [ -f "$FIXTURES/$f" ]; then
        log "  ✓ fixture $f present"
        passes=$((passes+1))
    else
        log "  ✗ fixture $f missing"
        failures=$((failures+1))
    fi
done

# Test 3: Each fixture is valid JSON parseable by node
for f in "$FIXTURES"/post-tool-use-*.json; do
    bn=$(basename "$f")
    if node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" 2>/dev/null; then
        log "  ✓ $bn is valid JSON"
        passes=$((passes+1))
    else
        log "  ✗ $bn is invalid JSON"
        failures=$((failures+1))
    fi
done

# Test 4: Allowed-path Edit fixture → hook exits 0
"$GATE_HOOK" < "$FIXTURES/post-tool-use-edit.json" >/dev/null 2>&1
assert_eq "$?" "0" "allowed-path Edit fixture → hook exits 0"

# Test 5: Allowed-path Write fixture → hook exits 0
"$GATE_HOOK" < "$FIXTURES/post-tool-use-write.json" >/dev/null 2>&1
assert_eq "$?" "0" "allowed-path Write fixture → hook exits 0"

# Test 6: Forbidden-path fixture (docs/founder-directives.md per D-6) → hook exits 2
"$GATE_HOOK" < "$FIXTURES/post-tool-use-forbidden.json" >/dev/null 2>&1
assert_eq "$?" "2" "forbidden-path fixture → hook exits 2"

# Test 7: Non-edit tool fixture → hook exits 0 (no-op for Read)
"$GATE_HOOK" < "$FIXTURES/post-tool-use-non-edit.json" >/dev/null 2>&1
assert_eq "$?" "0" "non-edit fixture (Read) → hook exits 0 (no-op)"

# Test 8: Forbidden-path fixture surfaces a stderr message naming the path
err=$("$GATE_HOOK" < "$FIXTURES/post-tool-use-forbidden.json" 2>&1 >/dev/null)
assert_match "$err" ".cursor/rules" "forbidden-path fixture stderr names the forbidden path"

# Test 9: Hook reads expected fields (tool_name + tool_input.file_path) — verified
# by mutating a fixture to remove tool_name and confirming the hook still exits 0
# (defensive: missing tool_name should not crash the hook).
TMPFIX=tests/__contract_no_tool_name__.json
node -e '
const fs = require("fs");
const m = JSON.parse(fs.readFileSync("'$FIXTURES'/post-tool-use-edit.json","utf8"));
delete m.tool_name;
fs.writeFileSync("'$TMPFIX'", JSON.stringify(m));
' 2>/dev/null
"$GATE_HOOK" < "$TMPFIX" >/dev/null 2>&1
exit_code=$?
rm -f "$TMPFIX"
assert_eq "$exit_code" "0" "hook is defensive against missing tool_name (exits 0)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-hook-contracts] OK — $passes/$total passed."; exit 0
else log "[test-hook-contracts] FAIL — $failures/$total."; exit 1; fi
