# ADR-0007 — Claude TDD Pro skill consumption via symlinks into materialized cache

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, "develop per all files" instruction) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0001 (plugin-sync mechanism — this ADR uses the cache that ADR-0001 introduced); ADR-0006 (Grok orchestrator templates — this ADR is the consumer side of the dispatch the templates produce)

## Context

TICKET-004 calls for `.claude/` config that loads the three `tdd-pro-*` skills (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) from the pinned `claude-tdd-pro` plugin into prototype-repo sessions. The acceptance criterion is "running `claude -p` in the prototype repo surfaces the three skills."

The prime directive (R-1..R-5) forbids vendoring, copying, or forking upstream content. Skills must therefore be consumed *by reference* at a pinned version. Claude Code's native skill loader scans `.claude/skills/<name>/SKILL.md` — a filesystem convention — so any "by reference" mechanism must surface skill content at those exact paths without copying it there.

ADR-0001 already established `.harness/plugin-cache/claude-tdd-pro/` (gitignored) as the runtime materialization of the plugin at the pinned commit, but the original sync script only materialized this cache as a side effect of drift detection (`--check`), and only when the pin differed from upstream HEAD. The cache was therefore not guaranteed to exist when a session started in sync.

## Decision

### 1. Materialize via symlinks into the plugin cache

`.claude/skills/<name>` is a **symlink** with target `../../.harness/plugin-cache/claude-tdd-pro/.claude/skills/<name>`. Three symlinks committed to git:

- `.claude/skills/tdd-pro-cl-workflow`
- `.claude/skills/tdd-pro-batch-cl`
- `.claude/skills/tdd-pro-bash32-portability`

Symlinks are stored in git as symlinks (mode 120000), so the by-reference semantics are preserved through clone/checkout. The targets resolve at runtime once the cache is materialized.

### 2. New `--ensure` mode in `scripts/sync-plugin.sh`

`sync-plugin.sh --ensure` is the runtime-materialization primitive. Distinct from `--check` (drift detection vs upstream HEAD) and `--update` (bump pin to upstream HEAD), `--ensure`:

- No-op if `.harness/plugin-cache/claude-tdd-pro/` already exists at the pinned commit.
- Otherwise: `rm -rf` the cache, `git clone --depth=1 --branch <pinned-branch>` the upstream, then verify HEAD matches the pinned commit; if not, fetch the specific commit + checkout.
- Exit 0 on success; exit 2 on error (network unreachable, can't check out pinned commit).
- Idempotent.

### 3. Hook wiring

`.claude/hooks/session-start.sh` calls `--ensure` after `--check`. Even when `--check` reports "in sync," the cache may not exist in a fresh container, so `--ensure` is the guarantee. Both calls run synchronously per the SessionStart skill's "Don't use async mode in the first iteration" guidance — startup latency cost is ~1-3 seconds when cache is present, ~5-10 seconds on cold materialization.

### 4. Help-to-stderr hygiene

While editing `sync-plugin.sh` for this CL, the `-h|--help` output was changed to write to stderr (per the upstream `tdd-pro-bash32-portability` skill's "bonus rule"). The existing pattern wrote to stdout. No spec in this repo greps `--help` output today, but flipping to stderr is portability hygiene; the cost is zero and the failure mode it prevents is well-attested in the upstream skill's body.

## Alternatives considered

- **Git submodule of `claude-tdd-pro`.** Rejected in ADR-0001 (vendoring-equivalent footprint and merge-conflict surface). Same rejection applies here.
- **Copy `SKILL.md` files into `.claude/skills/` at session start (gitignored).** A "soft vendor." Rejected: even gitignored runtime copies look like vendoring per R-2, would diverge silently if the materializer broke, and a symlink to the cache is cleaner because Claude Code's loader follows the symlink directly to the canonical bytes.
- **Documentation-only references (no actual loading).** Rejected: fails the TICKET-004 acceptance criterion ("running `claude -p` surfaces the three skills").
- **A bespoke "skill resolver" abstraction.** Rejected per Musk's Algorithm step 3 (don't optimize what shouldn't exist). Native Claude Code filesystem discovery is the existing primitive; building a wrapper around it would re-implement what already works (D-11 violation).
- **Pre-fetching all three SKILL.md files at session start and writing them directly under `.claude/skills/<name>/SKILL.md`.** Rejected because at-rest the files would look identical to vendored content; a future maintainer wouldn't see the by-reference semantics without reading the hook. Symlinks make the indirection visible in `ls`.

## Consequences

### Positive

- Acceptance criterion met **end-to-end**: a SessionStart in this very session loaded the three skills successfully (proven by the system-reminder listing them as available).
- Prime directive (R-2) preserved structurally: no upstream content lives in this tree; symlinks are pointers.
- Drift detection (`--check`) and runtime materialization (`--ensure`) are separated, each with a single responsibility. `--check` can fail (network down) without breaking session start; `--ensure` can fail (pin not fetchable) and the session degrades to "skills unavailable" with a clear warning, not a crash.
- Cache rebuild cost is bounded (`--depth=1` clone, ~1 MB for the three SKILL.md plus minimal repo metadata).

### Negative

- Symlinks committed to git work on POSIX systems but require Windows operators to enable `core.symlinks=true` (or use WSL). For a CLI-and-cloud-targeted harness this is acceptable; if Windows-native support becomes a goal, a fallback materializer (copy SKILL.md to the symlink path at session start) can be added.
- The cache must exist at session start for skills to load. If `--ensure` fails (no network), the session has the skills' *symlinks* but not their *content* — Claude Code will log a missing-file error on skill scan. The session-start hook surfaces the failure in its output so the operator sees it immediately.
- The materialized cache is at the pinned commit, not at upstream HEAD. If a contributor updates the pin via `scripts/sync-plugin.sh --update`, they must also re-run `--ensure` for the new commit to be materialized in their current session. The SessionStart hook handles this automatically on the *next* session.

### Neutral

- `.gitignore` already excludes `.harness/plugin-cache/` (added in TICKET-001.e). No additional gitignore changes needed.
- D-rule count unchanged. §1 of `docs/founder-directives.md` untouched.
- TIER-0/1/2 authority hierarchy unchanged.

## Verification (executed before commit)

- `scripts/sync-plugin.sh --ensure` materializes the cache at `b277284` (the pinned commit).
- Second `--ensure` run is a no-op ("cache already at pinned commit").
- `ls -L .claude/skills/*/SKILL.md` resolves all three symlinks to real files in the cache.
- This Claude Code session itself (TICKET-004 implementation session) received the three skills in its available-skills list via the SessionStart hook, demonstrating end-to-end skill loading.
- `bash -n scripts/sync-plugin.sh` passes.
- `tdd-pro-bash32-portability` 9-gotcha audit: clean. Bonus help-to-stderr rule: now satisfied.

## Future work

- **Windows symlink support.** If/when a Windows operator hits this, add a fallback that materializes copies under the symlink paths when `core.symlinks=false` is detected. Land via ADR.
- **Skill drift hash check.** The lock file currently hashes `SKILL.md` contents at pin time. The materialized cache *could* re-verify those hashes on `--ensure` to catch corruption between drift-check and use. Not implemented now; would add ~100ms to session start. Defer until a real corruption case appears.
- **Skill set bump via `--update`.** When new `tdd-pro-*` skills land upstream, the contract-surface-files list in the lock file gains entries via an ADR. The symlinks themselves still need to be created by hand on the bump CL — not automated. That's fine; new skills are rare and the manual step forces ADR-driven thinking about what's being adopted.

## Implementation references

- New: `.claude/skills/tdd-pro-cl-workflow` (symlink)
- New: `.claude/skills/tdd-pro-batch-cl` (symlink)
- New: `.claude/skills/tdd-pro-bash32-portability` (symlink)
- Updated: `scripts/sync-plugin.sh` (added `--ensure` mode; help to stderr)
- Updated: `.claude/hooks/session-start.sh` (calls `--ensure` after `--check`)
- Updated: `.claude/README.md` (documents the mechanism)
- Updated: `TICKETS.md` (TICKET-004 → DONE)
- Ticket: `TICKET-004` in `TICKETS.md`
- Related: ADR-0001 (lock-file + sync mechanism), ADR-0006 (Grok orchestrator templates)
