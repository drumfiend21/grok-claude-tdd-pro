#!/usr/bin/env bash
# tests/test-pre-tool-use-govern.sh — unit tests for .claude/hooks/pre-tool-use-govern.sh
# (CL-C / TICKET-102, ADR-0075). Hermetic: a fixture app_root + a stub plugin (stub
# enforce-standards-pre-write.sh + composite-dispatch.sh) drive deterministic verdicts.
# Exit: 0 all pass / 1 any fail / 2 harness error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-pre-tool-use-govern] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

HOOK=.claude/hooks/pre-tool-use-govern.sh
TMP=$(mktemp -d -t prew-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

mkdir -p "$TMP/app" "$TMP/other" "$TMP/plugin/hooks/scripts" "$TMP/plugin/rubric"
NATIVE="$TMP/plugin/hooks/scripts/enforce-standards-pre-write.sh"
DISPATCH="$TMP/plugin/rubric/composite-dispatch.sh"
# Default stubs: native ALLOWS, composite CRASHES (the real P-10 state).
native_allow() { printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$NATIVE"; }
native_deny()  { printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 2\n' > "$NATIVE"; }
disp_crash()   { printf '#!/usr/bin/env bash\necho "composite-dispatch.sh: ra[@]: unbound variable" >&2\nexit 1\n' > "$DISPATCH"; }
# composite-dispatch emits its authoritative verdict to STDERR (the wrapper captures 2>&1 >/dev/null).
disp_red()     { printf '#!/usr/bin/env bash\necho "composite-dispatch file=$2 status=red rule=g-x" >&2\nexit 1\n' > "$DISPATCH"; }
disp_green()   { printf '#!/usr/bin/env bash\necho "composite-dispatch file=$2 status=green" >&2\nexit 0\n' > "$DISPATCH"; }
native_allow; disp_crash

# Feed a Write PreToolUse envelope for <path>, with app_root scoping stubbed to $TMP/app.
run() {
    local fp="$1"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"a: b\\n"}}' "$fp" \
      | PREW_APP_ROOT="$TMP/app" PREW_APP_ROOT_BIN="$TMP/no-app-root.sh" PREW_PLUGIN_ROOT="$TMP/plugin" \
        bash "$HOOK" >/dev/null 2>&1
}

# Test 1: non-edit tool → allow (0)
printf '{"tool_name":"Read","tool_input":{"file_path":"%s/x.yaml"}}' "$TMP/app" \
  | PREW_APP_ROOT="$TMP/app" PREW_PLUGIN_ROOT="$TMP/plugin" bash "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "non-edit tool → allow (0)"

# Test 2: no app_root configured → vacuous allow (0)
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/x.yaml","content":"a: b"}}' "$TMP/app" \
  | PREW_APP_ROOT="" PREW_APP_ROOT_BIN="$TMP/no-app-root.sh" PREW_PLUGIN_ROOT="$TMP/plugin" bash "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "no app_root → vacuous allow (0)"

# Test 3: file OUTSIDE app_root → exempt (harness self-maintenance) → allow (0)
native_deny  # even with a denying native gate, out-of-scope must not be governed
run "$TMP/other/x.yaml"; assert_eq "$?" "0" "file outside app_root → exempt → allow (0)"
native_allow

# Test 4: file INSIDE app_root + native gate DENIES → deny (2)
native_deny
run "$TMP/app/config.yaml"; assert_eq "$?" "2" "inside app_root + native P0/P1 → deny (2)"
native_allow

# Test 5: inside app_root + native allows + composite AUTHORITATIVE status=red → deny (2)
disp_red
run "$TMP/app/config.yaml"; assert_eq "$?" "2" "§4 tools: authoritative composite status=red → deny (2)"
disp_crash

# Test 6: inside app_root + native allows + composite CRASH (P-10) → parse-then-block → allow (0)
run "$TMP/app/config.yaml"; assert_eq "$?" "0" "§4 tools: composite crash (no status=red) → allow (0) [P-10 inert]"

# Test 7: inside app_root + native allows + composite green → allow (0)
disp_green
run "$TMP/app/config.yaml"; assert_eq "$?" "0" "native allow + composite green → allow (0)"
disp_crash

# Test 8: unparseable input → fail-open allow (0)
printf 'not json{{' | PREW_APP_ROOT="$TMP/app" PREW_PLUGIN_ROOT="$TMP/plugin" bash "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "unparseable input → fail-open allow (0)"

total=$((passes + failures))
log ""
log "[test-pre-tool-use-govern] $passes/$total passed"
[ "$failures" -eq 0 ] || exit 1
exit 0
