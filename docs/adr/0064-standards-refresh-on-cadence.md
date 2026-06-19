# ADR-0064 — Begin refreshing standards sources at session start, on an operator-chosen cadence

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect; 2026-06-19 directive: *"when this plugin is installed, begin scraping its … sources … prompt for the user to configure the frequency (minutes/hours/days/weeks/months) default every day the session is active, and surface the significance of their enforcement … and to keeping them fresh"*) + Claude (cloud session).
- **Scope:** harness self-maintenance (a GCTP-side session-start orchestrator), per the agent-operating-compact's scope boundary.

## Context

Every rule GCTP enforces is derived from + cited to a first-class published source (OWASP, Google, NIST, SLSA, AWS Well-Architected, the federal AI EO, W3C, Web Vitals, …) **scraped from its live URL**. CTP (the plugin) ships the entire refresh machinery — `standards/initial-refresh.sh` (begin-on-install + first-use-of-day), `commands/set-refresh-frequency.sh` (the `<N>m|h|d|w|mo` cadence grammar), and the source→enforcement significance framing (v1.18 §28.23) — and fires it from CTP's *own* `install.sh` + SessionStart hook.

But **GCTP consumes CTP as a pinned snapshot** via `sync-plugin.sh --ensure` and never runs CTP's install or hooks. So in the harness, CTP's begin-on-install refresh **never fires** — the standards are materialized once at the pinned commit and never re-scraped. The operator asked for the harness to begin refreshing on install (= GCTP session start), let them pick the cadence (minutes…months, default daily), and surface why it matters.

## Decision

Add **`scripts/standards-refresh.sh`**, a GCTP-side orchestrator wired into `.claude/hooks/session-start.sh`, that **drives** CTP's refresh entrypoints through the contract surface (it does not re-implement scraping or the cadence grammar — prime directive):

- **`--check` (session start):** if the configured cadence is due (or first run), drive CTP `standards/initial-refresh.sh --quiet --state-dir .harness/standards-cache` (re-scrape the cited sources; non-fatal + offline-tolerant) then re-run `scripts/standards-sync.sh` (land refreshed rules in `active.json`); record the timestamp. Always surface the **significance**; until a cadence is chosen, **prompt** for one.
- **`--configure <freq>`:** set the cadence, validated by CTP's `commands/set-refresh-frequency.sh` (the grammar authority: `<N>m|h|d|w|mo` or a calendar token; invalid → exit 2). Stored in `.harness/standards-refresh.json` (operator-local, gitignored).
- **`--force` / `--status` / `--significance`:** refresh now / report cadence + due-state / print the explanation.
- **Default cadence `1d`** — every active day. **Honest scope:** a SessionStart hook fires once per session (not a daemon), so the cadence is enforced at **session boundaries** — a refresh runs if the interval has elapsed since the last; sub-day cadences refresh on the next session after the interval lapses, not on a wall-clock timer.

## Alternatives considered

- **Re-implement scraping + the cadence grammar in GCTP.** REJECTED — that is CTP-owned content; re-implementing it forks the standards pipeline and risks drift (prime directive). Drive CTP's entrypoints.
- **Run CTP's `install.sh` from GCTP to get its on-install refresh.** REJECTED — CTP's installer is Cursor/standalone-oriented and writes outside the harness's model (`docs/upstream-ctp-proposals.md` P-4); GCTP consumes by pinned reference, not by installing CTP. Driving the one refresh entrypoint is the contract-clean path.
- **Block the session until the operator picks a cadence.** REJECTED — refresh is informational/non-fatal; a missing cadence falls back to the daily default and prompts, never blocks (contrast the agent-compact gate, which is a genuine authorization gate).
- **Write the cadence only into CTP's `.claude-tdd-pro/FETCH-FREQUENCIES.yaml`.** REJECTED as the source of truth — that registry lives in CTP's runtime-state dir, which has no stable home in the harness consumption path. GCTP keeps its session-cadence state in `.harness/standards-refresh.json` and uses CTP's command purely as the grammar validator.

## Consequences

### Positive
- The harness now begins re-scraping the cited sources from session start, on the operator's chosen cadence — enforcement tracks upstream instead of freezing at the pinned snapshot's edition.
- The operator sees, every session, *why* the standards matter and how freshness preserves the quality bar.

### Neutral
- No `claude-tdd-pro` path edited (prime directive); CTP's `standards/` + `commands/` consumed via the contract surface (`docs/plugin-surface-consumption.md` updated: `commands` → CONSUMED). No `schema_version` change. D-6 honored.

### Negative / cost
- Cadence is enforced at session boundaries, not continuously (documented honestly). Live scraping needs network egress; absent it, the refresh degrades to cached + retries (never fails).

## Verification (this CL)
- `tests/test-standards-refresh.sh` — 17 assertions (grammar accept/reject m/h/d/w/mo + calendar; configure/status/significance; cadence due/not-due/after-interval via `SR_NOW`; `--force`; on-demand manual; missing-entrypoint non-fatal). Green via stubbed CTP entrypoints.
- Drove the real CTP `standards/initial-refresh.sh` (exit 0, offline-tolerant) + `set-refresh-frequency.sh` (validates 30m/2h/1d/1w/1mo/daily; rejects bogus/5x).
- Full audit chain green; `tests/test-all.sh` all suites; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path touched.

## Implementation references
- New: this ADR; `scripts/standards-refresh.sh`; `tests/test-standards-refresh.sh`; `.harness/standards-refresh.json.example`; `docs/standards-refresh.md`
- Modified: `.claude/hooks/session-start.sh` (drive refresh at session start), `.gitignore` (`standards-refresh.json` + `standards-cache/`), `docs/plugin-surface-consumption.md` (`commands` → CONSUMED), `tests/README.md`, `tests/hook-security-baseline.txt`, `TICKETS.md` (TICKET-075)
- Drives (CTP-side, not edited): `standards/initial-refresh.sh` (§28.23), `commands/set-refresh-frequency.sh` (§28.23 grammar)
- Related: ADR-0061 (pin `7a7f74d` adopting §28.22/§28.23), ADR-0037 (`standards-sync.sh`)
