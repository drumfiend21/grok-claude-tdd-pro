# /sync — materialize plugin cache + regenerate `.cursor/rules/`

## Purpose

Run the session-start ritual: materialize the pinned `claude-tdd-pro` plugin commit at `.harness/plugin-cache/` and regenerate `.cursor/rules/*.mdc` from sources-of-truth. Equivalent to what `.claude/hooks/session-start.sh` runs automatically for Claude Code; Cursor lacks a push-hook mechanism, so this command is the manual trigger.

## Inputs

None.

## Steps

1. Run `./scripts/sync-plugin.sh --ensure` in the terminal.
2. Capture stdout/stderr.
3. Report the status to the user: cache commit, drift findings, `.cursor/rules` regeneration line.

## Success criteria

- Script exits 0.
- Output includes `status    : OK (cache materialized at <commit>)` and `cursor    : .cursor/rules/*.mdc generated`.
- `.claude/skills/tdd-pro-*` symlinks resolve (verify with `ls -L .claude/skills/` if the script reports drift or warnings).

## Composition (D-1 reverse per ADR-0013)

Wraps the existing `scripts/sync-plugin.sh --ensure` (TICKET-001.e / ADR-0007) and the `.cursor/rules/` generator (TICKET-013 / ADR-0014). Grok analog: none — `sync-plugin.sh` is harness-native and is invoked equally by Claude Code's SessionStart hook and this Cursor command. See `AGENTS.md §7` and `docs/cursor-integration.md §7` for the session-start mechanism asymmetry.
