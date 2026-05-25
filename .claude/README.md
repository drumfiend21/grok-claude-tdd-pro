# .claude/

Claude Code harness config for grok-claude-tdd-pro. Wires the prototype-repo sessions to the three `tdd-pro-*` skills exposed by the pinned `claude-tdd-pro` plugin, via filesystem symlinks into a runtime-materialized cache (no vendoring, per R-2).

## Contents

| Path | Role |
|---|---|
| `settings.json` | SessionStart hook wiring + future Claude Code settings. |
| `hooks/session-start.sh` | Runs at every session start: `sync-plugin.sh --check` (drift report) + `sync-plugin.sh --ensure` (materialize cache at pinned commit). |
| `skills/tdd-pro-cl-workflow` → cache | Symlink to the upstream per-CL Red-Green-Refactor skill. |
| `skills/tdd-pro-batch-cl` → cache | Symlink to the upstream substrate-touch CL batching skill. |
| `skills/tdd-pro-bash32-portability` → cache | Symlink to the upstream bash 3.2 + BSD-tool portability skill. |

## How skill loading works

The mechanism honors **R-2 (versioned consumption, by reference) — never copied, vendored, or forked into this tree**:

1. `docs/claude-tdd-pro.lock.yaml` pins the upstream commit (currently `b277284`).
2. `.claude/hooks/session-start.sh` runs at every session start. It calls `scripts/sync-plugin.sh --ensure`, which materializes the upstream repo at the pinned commit into `.harness/plugin-cache/claude-tdd-pro/` (gitignored).
3. `.claude/skills/<name>` symlinks resolve into `.harness/plugin-cache/claude-tdd-pro/.claude/skills/<name>/` via a relative path (`../../.harness/plugin-cache/...`).
4. Claude Code's skill loader follows the symlink, reads `SKILL.md` in the materialized cache, and surfaces the skill in the session.

The symlinks themselves are committed to git (as symlinks, not as copies of the upstream content). The cache they point into is gitignored and rebuilt from the lock-file pin on every session in every container.

## What this satisfies

- **R-2** — versioned consumption by reference. No upstream content lives in this tree; symlinks are pointers, not copies.
- **R-3 / R-5** — single source of truth + bilateral schema changes. The upstream `SKILL.md` files are the source; this repo references them at a pinned commit.
- **R-11** — tolerant reader at the boundary. The lock file's contract-surface hash list catches any unexpected change to the `SKILL.md` content as drift (`scripts/sync-plugin.sh --check`).
- **D-11 (founder directive)** — design FOR agent-CLI primitives. Claude Code's native skill-loading filesystem convention IS the loading mechanism; nothing reimplements it.
- **TIER-0 corpus §3** — "Skills extend Claude's knowledge with information specific to your project, team, or domain." This wiring is exactly that.

## Verifying the wiring

```bash
# 1. Cache materialized at pinned commit
scripts/sync-plugin.sh --ensure

# 2. Symlinks resolve
ls -L .claude/skills/*/SKILL.md

# 3. In any Claude Code session, the three skills appear in the available-skills
#    list, invocable via the Skill tool or by name match.
```

If a symlink resolves but its target is missing, run `scripts/sync-plugin.sh --ensure` to rebuild the cache.

## What this does NOT do

- It does NOT pre-load the skills' content into git. Skills live upstream; this repo references them. Per R-2, copying would be a contract violation.
- It does NOT invoke the skills automatically. Skills run when their description matches the current task, or when called explicitly. The harness presents them; the agent (or user) chooses.
- It does NOT modify the upstream skills. Per the prime directive, no cross-repo edits. If an upstream skill needs a change, file an amendment proposal in `claude-tdd-pro` separately.

## Cross-references

- Lock file: [`../docs/claude-tdd-pro.lock.yaml`](../docs/claude-tdd-pro.lock.yaml)
- Sync script: [`../scripts/sync-plugin.sh`](../scripts/sync-plugin.sh)
- Plugin-sync runbook: [`../docs/plugin-sync.md`](../docs/plugin-sync.md)
- ADR-0001 (plugin-sync mechanism): [`../docs/adr/0001-plugin-lockfile-session-sync.md`](../docs/adr/0001-plugin-lockfile-session-sync.md)
- ADR-0007 (skill consumption wiring): [`../docs/adr/0007-claude-skill-consumption-wiring.md`](../docs/adr/0007-claude-skill-consumption-wiring.md)
