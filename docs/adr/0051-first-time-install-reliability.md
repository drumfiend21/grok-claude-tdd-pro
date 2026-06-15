# ADR-0051 — First-time install reliability: `install.sh` + Node-version-robust smoke + read-only `--check`

- **Status:** Accepted
- **Date:** 2026-06-15
- **Deciders:** drumfiend21 (architect; 2026-06-15 directive: *"I want this to install in less than 30 seconds from a simple install script. Make it happen"* — accompanied by a bug report that the documented setup command failed silently on Node 24) + Claude (cloud session).
- **Trigger:** A newcomer ran the documented one-liner (`sync-plugin.sh --ensure && smoke-e2e.sh`) on Node v24 and it failed silently with no `smoke OK`. Investigation surfaced three first-run reliability defects.
- **Extends/amends:** ADR-0008 (stub-mode smoke; this amends its TAP-format assumption), ADR-0001/0007 (plugin sync). Supersedes nothing — additive (Nygard append-only).

## Context

Three defects degraded the very first thing a non-technical user does:

1. **No install script.** Setup was a documented two-command sequence, not a single robust entry point with plain-language output.
2. **`smoke-e2e.sh` parsed Node's test output as TAP (`^# pass N`).** Node ≥ 24 defaults to the `spec` reporter (`ℹ pass N`) even when piped. Under `set -euo pipefail`, the `grep '^# pass '` matched nothing, the failed pipeline aborted the script **before** its own `fail "could not parse…"` handler, and the `EXIT` trap reverted the toy — so the user saw a silent exit 1, not a diagnosis. The underlying tests pass 5/5; the harness just couldn't read modern Node's output. (Tellingly, the local Claude Code settings file already allow-listed `node --test --test-reporter=tap` — the fix was half-discovered but never applied to the script.)
3. **`sync-plugin.sh --check` left the cache on the wrong commit.** `--check` is a read-only drift report, but it `rm -rf`'d the real cache and re-cloned it at **branch HEAD** to compare contract-surface hashes, then exited without restoring the pin. The `.claude/skills/*` symlinks resolve into that cache at the **pinned** commit, so a standalone `--check` silently parked an operator's skills on the wrong plugin version. It also made `tests/test-all.sh` non-idempotent: a sibling test runs `--check`, leaving the cache at branch HEAD; once upstream `main` advanced past the pin **and added a top-level `examples/` dir**, the next run's `audit-plugin-surface` saw an undeclared surface and failed. (Latent for months; exposed the moment upstream diverged.)

## Decision

1. **Add `install.sh` (repo root).** One command: materialize the pinned plugin (`sync-plugin.sh --ensure`) + run the end-to-end self-check (`smoke-e2e.sh`), with plain-language ✓/✗ output, prerequisite checks (git, node), a `--quick` flag (skip verification), and a "what now" pointer. Exit codes `0`/`1`/`2`. Dominant cost is the one-time plugin download (~20–30 s); the script itself is near-instant.
2. **Pin the TAP reporter in `smoke-e2e.sh`.** Force `node --test --test-reporter=tap`, making the parse deterministic on every Node version (output is byte-identical on the LTS line). Defense-in-depth: append `|| true` to the parse pipelines so a future format drift surfaces via the script's explicit `fail "could not parse…"` guard instead of dying silently under `pipefail`.
3. **Make `--check` read-only w.r.t. cache state.** After the upstream comparison, restore the cache to the pinned commit (fetch + checkout the pin). `--update` is intentionally excluded — it leaves the cache at the new HEAD, which it is about to make the pin. This fixes both the operator-facing "my skills load the wrong version" bug and the `test-all` idempotency bug.

Regression guards: `test-smoke-e2e.sh` asserts the script pins `--test-reporter=tap`; `test-sync-plugin.sh` asserts `--check` leaves the cache at the pinned commit; `test-install.sh` covers the installer's exit-code contract + prerequisite guard.

## Alternatives considered

- **Fix only the docs (note "use Node ≤ 22").** REJECTED — the script was genuinely incompatible with current Node; capping the runtime version is a worse user experience than making the script robust. Forcing TAP makes "node — any recent version" honest again.
- **`--check` clones to a throwaway temp dir (never touch the cache).** Cleaner long-term, but a larger change to a load-bearing primitive (the `--update` lock-bump path also reads `$CLONE_DIR`). The surgical "restore the pin after comparison" fix removes the defect with minimal blast radius; the temp-clone refactor is deferred unless evidence demands it.
- **Make the *test* restore the cache (teardown only).** REJECTED — the pollution is operator-facing (`--check` is a public command), not just a test artifact; fixing the script is the correct layer.
- **Skip the self-check in `install.sh` to be faster.** REJECTED — verifying end-to-end is the point of an installer that exists to catch install problems. `--quick` is offered for the impatient.

## Consequences

### Positive

- **First run works on any recent Node**, in one command, with a clear pass/fail.
- **`--check` is now side-effect-safe** on cache *commit* — operators' skills always resolve at the pin; `test-all` is idempotent across back-to-back runs.
- **Silent-failure class closed** — the smoke gate now reports a parse error instead of dying before its handler.

### Negative

- **`--check` does one extra shallow fetch+checkout** (single commit). Negligible; runs at session start.

### Neutral

- **No `claude-tdd-pro` path touched** (prime directive); plugin pin `bba77df` + `schema_version` unchanged.
- **D-6 honored** — `docs/founder-directives.md` untouched.
- **ADR-0008's stub-mode design stands**; only its TAP-format assumption is amended.

## Verification (executed before commit)

- `./install.sh` → `✅ Done`; `./install.sh --quick` skips verification; bad flag → exit 2; copy run from a non-project folder → exit 1 with a clear message.
- `scripts/smoke-e2e.sh` → `smoke OK` (Node v22 here; TAP output identical, robust on v24+).
- `scripts/sync-plugin.sh --check` leaves the cache at `bba77df`; `audit-plugin-surface` green; `tests/test-all.sh` run twice back-to-back → **22/22 both times**, cache stays at the pin.
- New/updated tests: `test-install.sh` 9/9, `test-smoke-e2e.sh` (+TAP guard), `test-sync-plugin.sh` (+pin-restore guard). Full audit chain green.
- `git diff docs/founder-directives.md` → 0 lines (D-6); no `claude-tdd-pro` path modified; pin + `schema_version` unchanged.

## Implementation references

- New: `install.sh`, `tests/test-install.sh`, this ADR
- Modified: `scripts/smoke-e2e.sh` (TAP reporter + defensive parse), `scripts/sync-plugin.sh` (`--check` pin restore), `tests/test-smoke-e2e.sh` + `tests/test-sync-plugin.sh` (regression guards), `tests/hook-security-baseline.txt` (line-shift + new trap), `tests/test-all.sh` (already discovers new suite), `tests/README.md`, `README.md` + `QUICKSTART.md` (install path), `TICKETS.md` (TICKET-054)
- Related: ADR-0008 (stub-mode smoke; TAP assumption amended), ADR-0001/0007 (plugin sync)
