# ADR-0085 — Plugin pin bump `127804b` → `a69f380` (docs-only tip catch-up; picks up CTP CL-539 + CL-540 handoff/adoption records; contract surface stable)

- **Status:** Accepted
- **Date:** 2026-07-02
- **Deciders:** operator (`drumfiend21`; 2026-07-02: *"Get the latest. This repo and chat shouldn't be behind at all."*) + Claude Opus 4.7 (local session, 1M context).
- **Trigger:** CTP dev-chat confirmation (2026-07-02) that CTP `main` HEAD is `a69f380` — fully merged and pushed — and that the four commits between GCTP's pin `127804b` and CTP's tip are documentation-only (the P-10 handoff records CL-539 + CL-540 and their merges). Operator asked to close the pin gap so neither the repo nor this session is behind.
- **Continues:** the pin chain ADR-0072 (`230e99d → 4668c2e`) → ADR-0079 (`4668c2e → 127804b`) → this ADR (`127804b → a69f380`).
- **Process:** §15-gated pin bump via `sync-plugin.sh --update` (allowed because contract-surface hash-drift = 0; the manual-edit path from ADR-0079 was not required here).

## Compatibility verdict (verified `127804b → a69f380`)

| Check | Result |
|---|---|
| Span | **4 commits** (all upstream commits between pin and tip) |
| Files changed across the delta | **1** — `handoff-ctp-to-gctp-p10-fixed.md` in upstream `docs/` (upstream-only handoff record; not a consumed file) |
| `CLAUDE.md` | **byte-identical** (sha256 `814e43c2…` unchanged) |
| `architecture-v1.9.md` (upstream) | **byte-identical** (sha256 `efdd3805…` unchanged) |
| 3 consumed `SKILL.md` (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) | **all byte-identical** (sha256 unchanged for all three) |
| `active.json` | **118 → 118 rules** across the same 43 namespaces |
| Skills, rules, scripts, contract-surface files | **all identical** |
| Files removed | **0** (ADR-0047 additive-only invariant preserved) |

## The 4 upstream commits picked up

| SHA | Date | Message |
|---|---|---|
| `f53aa6f` | 2026-07-01T22:41:54Z | CL-539: CTP→GCTP handoff doc — P-10 fixed (composite-dispatch bash-3.2), re-pin to 127804b |
| `7d41370` | 2026-07-01T22:41:57Z | Merge: CTP→GCTP P-10-fixed handoff doc |
| `f7e5452` | 2026-07-01T23:03:58Z | CL-540: record GCTP P-10 adoption confirmation (live bash-3.2 validation) |
| `a69f380` | 2026-07-01T23:04:01Z | Merge: record GCTP P-10 adoption confirmation |

All four touch the same one file: an upstream handoff-record document. Nothing GCTP consumes has changed.

## Decision

Bump the pin `127804b → a69f380` — CTP's current `main` HEAD. The delta is docs-only and contract-identical, so `sync-plugin.sh --check` reports **0 drift** at both `127804b` and `a69f380`; `--update` cleanly advances the lock file. No functional change lands with this bump; the routed-FOSS-tool paths that ADR-0079 activated (pre-write, on-save, audit-time) remain byte-identical in behavior.

The point of this bump is not capability — it's **freshness discipline**: keeping the pin at the true CTP tip when doing so is trivially safe closes the "safe to bump" WARN that session-start reports and eliminates a class of "am I really up to date?" cognitive tax on every subsequent session.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced; contract-surface hashes unchanged (verified); `last_synced_at` + `last_synced_session` refreshed to reference this ADR.
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `a69f380` via `sync-plugin.sh --ensure` (idempotent).
- **`active.json`**: regenerated via `standards-sync.sh` — **118 rules unchanged** (no file diff; the git working tree does not show `active.json` modified).
- **No handoff regeneration** (no-rewrites discipline, ADR-0070 §1); no `applicable_rules` change on any open ticket.
- **No P-10 status change** in `docs/upstream-ctp-proposals.md`: it was already ✅ ADOPTED under ADR-0079 at `127804b`; the newer upstream commits are the record of that adoption, not a new fix.

## Consequences

- **Positive:** the pin now sits at true upstream tip. Session-start will report `status: OK` (was `WARN — pin behind upstream; safe to bump`). No more "safe to bump" nudge on every session.
- **Neutral:** functional behavior is byte-identical to `127804b`. Every consumed file (`CLAUDE.md`, `architecture-v1.9.md`, 3× `SKILL.md`) hashes to the exact same sha256 as at `127804b`. The rule surface is the same 118 rules / 43 namespaces.
- **Cost:** none in production behavior. One-time cost: re-materializing the cache + regenerating `active.json` (both idempotent, seconds).

## Verification (executed before commit)

- `sync-plugin.sh --update` reported: `action: safe to bump pin (no contract drift) — updating lock file`, `status: OK (pin bumped to a69f380)`.
- `sync-plugin.sh --ensure` reported: `status: OK (cache already at pinned commit)`. Installed cache `git rev-parse HEAD` = `a69f3801f327d4e919ffa3b559c677126bc169d6`.
- `sync-plugin.sh --check` reported: `pinned: a69f380 · upstream: a69f380 (main, in sync) · contract: 0 files drifted (pin matches HEAD) · status: OK`.
- `standards-sync.sh` reported: `rules: 118`, same 43 namespaces; `git status` shows `active.json` unchanged (byte-identical output — no rule content shifted).
- GitHub-truth checks via `gh api` (before this bump): GCTP `main` HEAD = `2c2a48b` (local matches); CTP `main` HEAD = `a69f380` (target of this bump).
- Prime directive: no `claude-tdd-pro` path edited (cache only re-materialized). D-6: `docs/founder-directives.md` unchanged. Compact scope: harness self-maintenance, not app-architecture — permitted under the scope boundary in `docs/agent-operating-compact.md`.

## Implementation references

- Lockfile: `docs/claude-tdd-pro.lock.yaml`
- Sync tooling: `scripts/sync-plugin.sh`, `scripts/standards-sync.sh`
- Prior bumps: ADR-0072 (`230e99d → 4668c2e`), ADR-0079 (`4668c2e → 127804b`)
- Process: `docs/plugin-sync.md`, `docs/architecture-principles.md` §15
- Session context: `dev/kata-2026-07-02` branch open for O'Reilly Winter 2025 kata attempt (Certifiable, Inc.); this bump lands on `main` and the dev branch fast-forwards.
