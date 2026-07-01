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

# ---------- ADR-0066 / TICKET-081: extended extension list for write-time enforcement ----------
# .md, .yaml/.yml, .tf/.tfvars, .json now go through the rubric runner branch. Vacuous-pass
# today (no detectors for these in active.json yet); activates on PROPOSAL-003 pin bump.
echo '{"tool_name":"Edit","tool_input":{"file_path":"docs/architecture/adr/0001.md"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" ".md write enters rubric branch + vacuous-pass → 0"

echo '{"tool_name":"Write","tool_input":{"file_path":"infra/k8s/grading-worker.yaml"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" ".yaml write enters rubric branch + vacuous-pass → 0"

echo '{"tool_name":"Edit","tool_input":{"file_path":".github/workflows/test.yml"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" ".yml write enters rubric branch + vacuous-pass → 0"

echo '{"tool_name":"Write","tool_input":{"file_path":"infra/main.tf"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" ".tf write enters rubric branch + vacuous-pass → 0"

echo '{"tool_name":"Edit","tool_input":{"file_path":"infra/variables.tfvars"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" ".tfvars write enters rubric branch + vacuous-pass → 0"

echo '{"tool_name":"Write","tool_input":{"file_path":"package.json"}}' | "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" ".json write enters rubric branch + vacuous-pass → 0"

# ---------- CL-D / ADR-0076: composite-dispatch on-save is app_root-scoped ----------
# A stub plugin (silent runner + authoritative-red composite-dispatch) lets us assert
# the on-save composite path fires ONLY under app_root. The runner stays harness-wide.
PTMP=$(mktemp -d -t ptu-scope.XXXXXX) || exit 2
trap 'rm -rf -- "$PTMP"' EXIT INT TERM
mkdir -p "$PTMP/app" "$PTMP/plugin/rubric"
printf '#!/usr/bin/env bash\nexit 0\n' > "$PTMP/plugin/rubric/runner.sh"; chmod +x "$PTMP/plugin/rubric/runner.sh"
printf '#!/usr/bin/env bash\necho "composite-dispatch file=$2 status=red rule=g-x" >&2\nexit 1\n' > "$PTMP/plugin/rubric/composite-dispatch.sh"; chmod +x "$PTMP/plugin/rubric/composite-dispatch.sh"
printf 'a: b\n' > "$PTMP/app/config.yaml"
printf 'a: b\n' > "$PTMP/outside.yaml"

# Under app_root → composite-dispatch runs → authoritative red → deny (2)
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/app/config.yaml"}}' "$PTMP" \
  | PTU_PLUGIN_ROOT="$PTMP/plugin" PTU_APP_ROOT="$PTMP/app" "$HOOK" >/dev/null 2>&1
assert_eq "$?" "2" "on-save composite-dispatch fires under app_root (authoritative red → 2)"

# Outside app_root (harness self-maintenance) → composite-dispatch SKIPPED → allow (0)
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/outside.yaml"}}' "$PTMP" \
  | PTU_PLUGIN_ROOT="$PTMP/plugin" PTU_APP_ROOT="$PTMP/app" "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "on-save composite-dispatch SKIPPED outside app_root (self-maintenance exempt → 0)"

# No app_root configured → composite-dispatch never fires → allow (0)
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/app/config.yaml"}}' "$PTMP" \
  | PTU_PLUGIN_ROOT="$PTMP/plugin" PTU_APP_ROOT="" PTU_APP_ROOT_BIN="$PTMP/no-app-root.sh" "$HOOK" >/dev/null 2>&1
assert_eq "$?" "0" "no app_root → composite-dispatch never fires (vacuous → 0)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-post-tool-use-review-gate] OK — $passes/$total passed."; exit 0
else log "[test-post-tool-use-review-gate] FAIL — $failures/$total."; exit 1; fi
