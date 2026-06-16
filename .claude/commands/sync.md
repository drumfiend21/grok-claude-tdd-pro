---
description: Materialize the pinned claude-tdd-pro plugin cache + regenerate Cursor rules
---

Refresh the plugin cache (Claude Code mirror of `.cursor/commands/sync.md`).

Run `./scripts/sync-plugin.sh --ensure` (materializes the pinned CTP commit into `.harness/plugin-cache/`, resolves the `tdd-pro-*` skill symlinks, and regenerates `.cursor/rules/`). Then run `./scripts/sync-plugin.sh --check` and report the pin/contract/status lines. Both are safe to re-run; `--check` leaves the cache at the pinned commit.
