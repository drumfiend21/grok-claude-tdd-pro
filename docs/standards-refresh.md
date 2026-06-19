# Standards source-refresh (operator cadence)

**Authority tier:** TIER 2 (operational runbook). Per TICKET-075 / ADR-0064. Re-runnable via `scripts/standards-refresh.sh`.

## Why this exists (the significance)

Every rule GCTP enforces is **derived from and cited to a first-class published source** — OWASP (ASVS + Top 10), Google's style guides, NIST, SLSA build provenance, AWS Well-Architected, the federal AI Executive Order, W3C/WCAG, Web Vitals, the Node.js + React + TypeScript guidance — **scraped from its live URL** by the plugin's fetch pipeline. The standards are not a frozen copy: they are a *cache of upstream guidance*.

So enforcement is only as current as the last scrape. **Re-scraping on a schedule keeps enforcement tracking upstream**: when a source publishes new guidance, the next refresh turns it into new rules, which flow into `active.json`, which the harness's gates enforce — automatically. Skipping refresh silently freezes the quality bar at an old edition of every standard. Refreshing is how "world-class, current standards" stays *current*.

## The model (who does what)

- **CTP (the plugin) owns the scraping + the cadence grammar + the significance.** It ships `standards/initial-refresh.sh` (begin-on-install + first-use-of-day refresh, seeding per-source freshness baselines), `commands/set-refresh-frequency.sh` (the `<N>m|h|d|w|mo` grammar), and the `§28.23` significance framing. CTP fires these from *its own* `install.sh` + SessionStart hook.
- **GCTP consumes CTP as a pinned snapshot** (`sync-plugin.sh --ensure`) and never runs CTP's install/hooks — so CTP's on-install refresh **does not fire in the harness**. `scripts/standards-refresh.sh` is the GCTP-side trigger that **drives** CTP's entrypoints through the contract surface. It does not re-implement scraping or the grammar (prime directive).

## Cadence

Configured per operator, stored in `.harness/standards-refresh.json` (operator-local, gitignored; `.example` tracked):

```bash
./scripts/standards-refresh.sh --configure <freq>     # <N>m|h|d|w|mo OR daily|weekly|monthly|quarterly|on-demand
./scripts/standards-refresh.sh --status               # current cadence + last refresh + whether due
./scripts/standards-refresh.sh --force                # refresh now regardless of cadence
./scripts/standards-refresh.sh --significance         # print the explanation above
```

- **Grammar:** `<N>m` (minutes), `<N>h` (hours), `<N>d` (days), `<N>w` (weeks), `<N>mo` (months); or a calendar token. Validated by CTP's `set-refresh-frequency.sh` (the authority). Invalid → exit 2.
- **Default:** `1d` — **every active day**. Until the operator chooses, the harness uses the default and prompts (once per session) to configure one.
- **`on-demand` / `quarterly` etc.** are honored; `on-demand` means refresh only on `--force`.

## When it runs (honest scope)

`scripts/standards-refresh.sh --check` runs at **session start** (`.claude/hooks/session-start.sh`). A session-start hook fires once per session, not as a daemon, so the cadence is enforced **at session boundaries**: a refresh runs if the configured interval has elapsed since the last one (or on first run). Sub-day cadences (e.g. `30m`) therefore refresh on the first session that opens after the interval lapses — not on a wall-clock timer between sessions. The refresh itself is **non-fatal and offline-tolerant**: when the environment has no network egress it degrades to cached standards and retries next session; it never blocks or fails the session.

## What a refresh does

1. Drives CTP `standards/initial-refresh.sh --quiet --state-dir .harness/standards-cache` — seeds/updates per-source freshness baselines and best-effort live-scrapes the cited sources (conditional GET; `304 Not Modified` is cheap).
2. Re-runs `scripts/standards-sync.sh` so any refreshed rules land in `.harness/rules/active.json` for this session's gates.
3. Records `last_refresh_ms` / `last_refresh_at` in the config.

## Related

- CTP design: `architecture-v1.9.md §28.22` (refresh-driven universal coverage) + `§28.23` (begin-on-install + cadence + significance).
- Adopted at pin `7a7f74d` (ADR-0061). Consumed surfaces: `standards/`, `commands/` (`docs/plugin-surface-consumption.md`).
- Composes on `scripts/standards-sync.sh` (TICKET-032 / ADR-0037) and `scripts/sync-plugin.sh`.
