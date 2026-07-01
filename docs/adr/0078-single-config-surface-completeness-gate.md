# ADR-0078 — Single-config OPTIONS-surface completeness gate (`config-sync --check`); profile-honoring deferred

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"build CL-H (single-config) next"*) + Claude Opus 4.8 (local session).
- **Trigger:** **CL-H** of the ADR-0072 "Known follow-up" #2 backlog — the single-config surface (§28.44–§28.52, §28.58/§28.59).

## Context

The `4668c2e` engine ships a single-config surface: one file (`ctp.config.yaml`, schema = the §2.5 profile) configures every scraped rule. `commands/config-sync.sh` materializes, for each rule, tool-native option objects seeded from `standards/tool-option-surfaces.yaml` (the ~80-tool option vocabulary) into `standards/config-options-view.yaml`. Its `--check` mode asserts that **every** option-bearing tool of **every** active rule has a projectable option surface — a rule with a gap is recorded `needs_mapping` (cite-or-decline, never silently omitted). `profiles/` ships many ready profiles (financial / government / healthcare / national-security-systems / node / react / …) + the `active.sh` resolver.

## Decision

Wire a harness validation gate — `scripts/audit-config-surface.sh` — that runs `config-sync --check` and asserts **`needs_mapping=0`**. Any gap is a hard red (the operator's single config would be "capability present, data empty"). Vacuous when `config-sync.sh` is absent (pre-§28.58 cache) or produces no summary (Ruby prerequisite missing). Wired into `session-start.sh` (WARN) — it is fast (~166 ms). Sources the epoch library (ADR-0071). Prime directive: `config-sync.sh` consumed by reference, never edited.

At the current pin the surface is complete: **`config-sync rules=118 materialized=118 needs_mapping=0`**.

## Scope — what CL-H does and does NOT do

**Does (this ADR):** validates the single-config **OPTIONS surface is total** — the precondition for the config to be usable at all.

**Deferred (needs operator UX decisions → follow-up, ADR-0079):**
1. **Profile selection** — *which* profile (`financial`/`government`/`healthcare`/…) the harness applies to a given product, and *where* that choice is configured (e.g. a `.harness/` setting).
2. **Profile threading** — passing `--profile <selected>` through the enforcement paths (`enforce-standards.sh`, the CL-C pre-write governor, the CL-D on-save path) so the selected config is honored at enforce-time.

These are genuine operator-facing config UX and depend on how you want products to select their standards profile; building them blind would guess the UX. CL-H delivers the completeness gate now; the selection + threading land once the UX is decided.

## Consequences

### Positive
- The single config's options data is gated as complete at session start (fast); a future upstream change that drops a tool-option mapping is caught.

### Neutral
- Vacuous when Ruby/config-sync absent (Ruby is a repo prerequisite). Profile-honoring deferred (documented, not silently skipped).

### Negative
- One more Ruby-backed audit in the WARN chain (~166 ms).

## Verification (executed before commit)
- `tests/test-audit-config-surface.sh` — 7/7 hermetic (help/unknown-flag; config-sync absent → vacuous; `needs_mapping=0` → green; `needs_mapping>0` → red; no-summary/Ruby-missing → vacuous; multi-digit needs_mapping).
- Live run against the `4668c2e` cache: green, `config-sync rules=118 materialized=118 needs_mapping=0` (~166 ms).
- No `claude-tdd-pro` path touched (prime directive). D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- Audit: `scripts/audit-config-surface.sh` · Tests: `tests/test-audit-config-surface.sh` · Wired: `session-start.sh` (WARN)
- Consumed entrypoints: `commands/config-sync.sh` (§28.58/59), `standards/tool-option-surfaces.yaml`, `profiles/` · Related: ADR-0074 (development-paths gate, same shape)
- Deferred: profile selection + `--profile` threading → ADR-0079 · Backlog: ADR-0072 KFU #2
