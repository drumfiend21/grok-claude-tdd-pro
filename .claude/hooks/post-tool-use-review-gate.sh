#!/usr/bin/env bash
# .claude/hooks/post-tool-use-review-gate.sh — PostToolUse review gate
#
# Materializes ADR-0017's deferred TICKET-015.a: PostToolUse hooks for review
# gates (named in the 2026-05-26 Architect Automation Briefing). Detects
# file-edit-fence violations per AGENTS.md §2 immediately after Edit / Write /
# MultiEdit / NotebookEdit tool calls, surfacing them as a hook-level error
# so the operator (or agent) sees the violation before continuing the
# session.
#
# Claude Code hook protocol: stdin receives a JSON envelope per
# https://docs.claude.com/en/docs/claude-code/hooks. For PostToolUse, the
# envelope includes session_id, hook_event_name, tool_name, tool_input,
# tool_response. This hook extracts tool_input.file_path and checks it
# against the forbidden-path list.
#
# Exit codes:
#   0  no violation (or non-edit tool — hook is a no-op)
#   2  forbidden-path violation detected (stderr message displayed by Claude Code)
#
# Portability: bash 3.2 + BSD coreutils; uses `node -e` for JSON parsing
# (node is already a harness dependency per scripts/smoke-e2e.sh).

set -u

# Read all of stdin into a variable. The hook protocol sends one JSON object
# per invocation.
INPUT=$(cat)

# Extract tool_name + tool_input.file_path via node. Empty string if absent.
parsed=$(printf '%s' "$INPUT" | node -e '
    let data = "";
    process.stdin.on("data", c => data += c);
    process.stdin.on("end", () => {
        try {
            const m = JSON.parse(data);
            const tool = m.tool_name || "";
            // tool_input shape varies by tool: Edit/Write use file_path;
            // MultiEdit has file_path; NotebookEdit has notebook_path
            const fp = (m.tool_input && (m.tool_input.file_path || m.tool_input.notebook_path)) || "";
            console.log(tool + "\t" + fp);
        } catch (e) {
            console.log("\t");                    // unparseable -> empty
        }
    });
' 2>/dev/null || printf '\t')

TOOL_NAME=$(printf '%s' "$parsed" | awk -F'\t' '{print $1}')
FILE_PATH=$(printf '%s' "$parsed" | awk -F'\t' '{print $2}')

# Only review edit-class tools. Other tool calls are no-ops for this gate.
case "$TOOL_NAME" in
    Edit|Write|MultiEdit|NotebookEdit) ;;
    *) exit 0 ;;
esac

# Empty file_path = nothing to gate.
[ -n "$FILE_PATH" ] || exit 0

# Normalize: strip leading $CLAUDE_PROJECT_DIR / cwd if present so the
# fence patterns match consistently regardless of absolute / relative input.
WORKDIR="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$FILE_PATH" in
    "$WORKDIR"/*) REL_PATH="${FILE_PATH#"$WORKDIR"/}" ;;
    /*)           REL_PATH="$FILE_PATH" ;;        # absolute, outside workdir — let it pass; not our concern
    *)            REL_PATH="$FILE_PATH" ;;
esac

# Forbidden patterns per AGENTS.md §2:
#   1. .harness/plugin-cache/  — generator-managed; clobbered by sync-plugin.sh
#   2. claude-tdd-pro/         — sibling repo; TIER-1 prime-directive invariant
#   3. .claude/skills/tdd-pro- — symlinks into the plugin cache
#   4. .cursor/rules/*.mdc     — generator output per ADR-0014; F-5 catches at audit time

violation=""
case "$REL_PATH" in
    .harness/plugin-cache/*)   violation="ADR-0007 / R-2: .harness/plugin-cache/ is generator-managed (scripts/sync-plugin.sh --ensure). Hand-edits violate R-2 (versioned consumption) and will be clobbered on the next ensure." ;;
    claude-tdd-pro/*)          violation="CLAUDE.md prime directive: claude-tdd-pro/ is the sibling plugin repo. Cross-repo edits violate the plugin-dependency model (R-1 + R-2). File a v1.11 amendment proposal upstream instead." ;;
    .claude/skills/tdd-pro-*)  violation="ADR-0007: .claude/skills/tdd-pro-* are symlinks into the plugin cache. Hand-edits leak into the unrelated upstream — fix the upstream and re-pin, or use the symlinked target read-only." ;;
    .cursor/rules/*.mdc)       violation="ADR-0014: .cursor/rules/*.mdc are generator output from scripts/export-cursor-rules.sh. Hand-edits are detected at pre-commit by audit-doc-drift.sh F-5. Edit the generator (scripts/export-cursor-rules.sh) and re-run instead." ;;
esac

if [ -n "$violation" ]; then
    printf 'PostToolUse review gate: forbidden-path violation detected.\n' >&2
    printf '  Tool: %s\n' "$TOOL_NAME" >&2
    printf '  Path: %s\n' "$FILE_PATH" >&2
    printf '  Rule: %s\n' "$violation" >&2
    printf '  Source: AGENTS.md §2 file-edit-fences; TICKET-015.a / ADR-0022 (PostToolUse review gate).\n' >&2
    exit 2
fi

exit 0
