# ADR-0001 — Adopt lock file + session-start sync for the claude-tdd-pro plugin dependency

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (owner) + Claude (cloud session)
- **Supersedes:** none
- **Superseded by:** none

## Context

The prime directive in `CLAUDE.md` declares that `grok-claude-tdd-pro` consumes `claude-tdd-pro` as a plugin — independent microservice-style repos, versioned consumption by reference, contract-only coupling (R-1 .. R-5). The plugin is never vendored, copied, or forked into this tree.

That contract leaves an operational question open: **how does this repo know, at any given time, what state of `claude-tdd-pro/main` it is built against?** Without a mechanism:

- Sessions in ephemeral cloud containers spin up with no knowledge of upstream.
- Drift between the contract surface this repo assumes and what upstream currently exposes is silent until something breaks.
- Rule R-5 ("contract changes are bilateral and explicit; bump `schema_version`, ship two coordinated PRs") becomes unenforceable because there is no "current pin" to bump.

Constraints that ruled out simpler options:

- **No long-lived poller.** Sessions are ephemeral; the container is reclaimed after inactivity. A background daemon cannot persist between sessions.
- **No third-party webhook subscription.** GitHub webhooks for a repo this session does not own require infrastructure outside the session.
- **No vendoring / submodule of the plugin tree.** Either would violate R-2 ("imported by reference, never copied, vendored, or forked").
- **No silent fetch on every action.** Latency and audit-trail noise would be unacceptable.

## Decision

Adopt a four-layer sync mechanism:

1. **Lock file** at `docs/claude-tdd-pro.lock.yaml` — the versioned, checked-in pin recording: upstream repo URL, pinned branch, pinned commit SHA, pin timestamp, and a sha256 hash for each contract-surface file. This file IS the "version" referenced by R-2 and the unit-of-bump referenced by R-5.

2. **Sync script** at `scripts/sync-plugin.sh` — POSIX-style bash, bash 3.2 portable per C-23. Fetches upstream HEAD, computes contract-surface hashes, compares with the lock file, emits a structured drift report. Flags: `--check` (read-only; exit 0 in sync, 1 on drift, 2 on error), `--update` (bumps the pin), `--quiet`.

3. **SessionStart hook** wired in `.claude/settings.json` — runs `scripts/sync-plugin.sh --check` at the start of every Claude Code session. The drift report enters the session context, so every agent (local, remote, cloud, Action, IDE) opens with current sync state.

4. **On-demand fetch within a session** — for tasks that depend on live upstream state, the agent calls the GitHub MCP server (once scope is expanded to include `drumfiend21/claude-tdd-pro`) or re-invokes `sync-plugin.sh`. Cached upstream snapshots live in `.harness/plugin-cache/` (gitignored).

**Drift policy: warn-only.** A drift report is informational unless the agent explicitly bumps the pin via `--update`. A bump that changes any contract-surface file hash REQUIRES a new ADR — this is the R-5 enforcement point.

## Consequences

**Positive:**
- The plugin-dependency invariant (R-1 .. R-5) becomes enforceable in code, not just in prose.
- Every session opens with auditable knowledge of what upstream state this repo is built against.
- Contract-surface drift surfaces immediately rather than failing at integration time.
- The lock file is reviewable in every PR — drift becomes a first-class signal in code review.
- The pin bump itself is an explicit, recorded act (a commit), satisfying R-5.

**Negative:**
- Adds ~1–3 seconds of session startup latency for the `git ls-remote` + hash-compare path.
- Requires either expanded GitHub MCP scope or network access to `github.com` from the session container. (Current container has the latter; the former is preferred for cleaner programmatic use.)
- Introduces a new file format (the lock file) and a new operator workflow (run `--update`, write an ADR when contract surface moves). The workflow is documented in `docs/plugin-sync.md`.
- A misconfigured hook can spam the session context. Mitigation: the `--check` output is bounded to ~10 lines.

**Neutral:**
- The lock file's `schema_version: 1` follows the same versioning discipline as the handoff contract; bumping it is itself an ADR-worthy change.
- The decision creates the `docs/adr/` directory required by architectural rule R-20 and §15 of the architecture-principles rulebook.

## Alternatives considered

- **Git submodule of `claude-tdd-pro`.** Rejected: even read-only, it pulls the upstream tree into this repo's working set, which the prime directive forbids (R-2 — "never copied, vendored, or forked into this tree"). A submodule is technically by-reference, but the working-tree footprint and merge-conflict surface treat it like vendoring in practice.
- **In-repo plugin cache committed to the tree.** Rejected for the same R-2 reason.
- **No sync mechanism; rely on humans to bump the pin.** Rejected: makes R-5 unenforceable and leaves cloud sessions blind to upstream state.
- **GitHub Action in `claude-tdd-pro` that opens a drift PR here on every upstream commit.** Considered; deferred. Heavier infrastructure than the harness currently warrants. Reachable from this design later — the lock file is the receiver-side anchor either way.

## Implementation references

- Lock file: `docs/claude-tdd-pro.lock.yaml`
- Sync script: `scripts/sync-plugin.sh`
- SessionStart hook: `.claude/settings.json`
- Operator documentation: `docs/plugin-sync.md`
- Ticket: `TICKET-001.e` in `TICKETS.md`
