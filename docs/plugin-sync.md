# Plugin Sync — operator guide

This doc is the runbook for the `claude-tdd-pro` plugin sync mechanism. The architectural decision is recorded in [ADR-0001](./adr/0001-plugin-lockfile-session-sync.md). The contract this implements is rule **R-2** ("versioned consumption, by reference") and **R-5** ("contract changes are bilateral and explicit") of [`architecture-principles.md`](./architecture-principles.md), plus the prime directive in `CLAUDE.md`.

## What it does

Every Claude Code session — local, remote, cloud, GitHub Action, IDE — opens with a fresh comparison between this repo's pinned version of `claude-tdd-pro` and that repo's current `main` HEAD. The result lands in session context so the agent knows up front:

- Whether the pin is in sync with upstream.
- If not, whether the drift is benign (commits moved, contract surface stable) or hostile (a contract-surface file's hash changed).

There is **no live editing of the plugin** — this is a read-only awareness mechanism. The plugin remains imported by reference, never vendored.

## The pieces

| File | Role |
|---|---|
| `docs/claude-tdd-pro.lock.yaml` | The pin. Records upstream URL, pinned commit, pinned timestamp, and sha256 of each contract-surface file. |
| `scripts/sync-plugin.sh` | Compares the pin against upstream HEAD and materializes the pinned commit on disk. Modes: `--check` (read-only drift report), `--ensure` (materialize the pinned commit into `.harness/plugin-cache/`, idempotent), `--update` (bump the pin to upstream HEAD; requires an ADR per `architecture-principles.md §15`), `--quiet`. |
| `.claude/hooks/session-start.sh` | Thin wrapper that calls `sync-plugin.sh --check` (drift report) then `sync-plugin.sh --ensure` (cache materialization, so symlinked skills resolve). Always exits 0 (warn-only policy). |
| `.claude/settings.json` | Wires the hook to Claude Code's `SessionStart` event. |
| `.harness/plugin-cache/` | Gitignored shallow-clone cache used when hashing requires fetching upstream files. |

## Reading the drift report

In sync (most common):
```
[plugin-sync] https://github.com/drumfiend21/claude-tdd-pro
  pinned    : b277284  (2026-05-24T17:43:52-04:00)
  upstream  : b277284  (main, in sync)
  contract  : 0 files drifted (pin matches HEAD)
  status    : OK
```

Pin is behind, but contract surface is unchanged:
```
[plugin-sync] https://github.com/drumfiend21/claude-tdd-pro
  pinned    : b277284  (2026-05-23T...)
  upstream  : e4f5g6h  (main, 3 commits ahead)
  contract  : 0 files drifted (commits moved, contract surface stable)
  status    : WARN — pin is behind upstream; safe to bump (run --update)
```

Contract surface drifted (requires ADR):
```
[plugin-sync] https://github.com/drumfiend21/claude-tdd-pro
  pinned    : b277284  (2026-05-23T...)
  upstream  : e4f5g6h  (main, 3 commits ahead)
  contract  : 1 file(s) drifted
    - .claude/skills/tdd-pro-cl-workflow/SKILL.md
  status    : WARN — contract surface drifted; review upstream before bumping
              Bumping the pin requires an ADR (architecture-principles §15)
```

## When to bump the pin

**Safe bump** (no contract drift):
```bash
scripts/sync-plugin.sh --update
git add docs/claude-tdd-pro.lock.yaml
git commit -m "TICKET-XXX: bump claude-tdd-pro pin to <short-sha>"
```
The script will refuse to bump if contract-surface drift is detected — that's by design.

**Bump after contract-surface drift**:
1. Read the upstream change. Understand what the contract delta means for this repo.
2. Write an ADR in `docs/adr/000N-*.md` recording: which contract-surface files changed, the upstream rationale, and what (if anything) this repo must adapt.
3. Only then run `scripts/sync-plugin.sh --update`. Commit the ADR and the lock-file update in the same change.

The script enforces step 3 by refusing `--update` when contract-surface hashes differ, so the human pause for the ADR is structural, not procedural.

## When to add a file to the contract surface

The contract surface is the set of upstream files this repo's architecture genuinely depends on. Today: `CLAUDE.md`, `docs/architecture-v1.9.md`, and the three `tdd-pro-*` `SKILL.md` files.

Adding a file means: future drift in that file will trigger a contract-surface warning. Don't add files casually — the surface should be small. If you add one, do it via ADR. Removing one also goes through ADR.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | In sync. |
| 1 | Drift detected. Session NOT blocked (warn-only). |
| 2 | Error (network unavailable, lock file malformed, missing tool). |

The SessionStart wrapper always exits 0 regardless — drift never blocks a session. Use `scripts/sync-plugin.sh --check` directly (not via the hook) when you want the real exit code in a script.

## Failure modes

- **No network.** `git ls-remote` fails. Script reports `status: ERROR`. Session continues; agent should treat the plugin state as "unknown".
- **Lock file missing or malformed.** Script exits 2 with a specific message. Fix the lock file before continuing.
- **`scripts/sync-plugin.sh` missing or not executable.** The hook prints a single-line warning and exits 0; the session continues with no sync awareness.

## Future work

- Once the GitHub MCP scope is expanded to include `drumfiend21/claude-tdd-pro`, replace the `git ls-remote` + `git clone --depth=1` path with MCP calls. The lock-file format and exit-code contract don't change.
- A nightly GitHub Action in `claude-tdd-pro` that opens a drift PR here when its `main` moves is a deferred follow-up — see ADR-0001 alternatives.
