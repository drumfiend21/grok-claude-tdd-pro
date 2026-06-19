# ADR-0065 — Align CTP's fetch registry to the GCTP refresh cadence (two-layer)

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect; 2026-06-19 follow-up: *"I want to make sure both GCTP and CTP are re-scraping at the user-specified interval. Confirm."*) + Claude (cloud session).
- **Composes on:** ADR-0064 (GCTP-side `standards-refresh.sh` cadence). This refines — does not replace — that decision.
- **Scope:** harness self-maintenance.

## Context

ADR-0064 gave GCTP a session-start orchestrator that drives CTP's scraper on a GCTP-side cadence (`.harness/standards-refresh.json`). But there are **two** cadence layers:

1. **GCTP drive cadence** — how often GCTP *triggers* a re-scrape.
2. **CTP fetch cadence** — CTP's own per-source freshness/poll economy, governed by its S-22 registry `.claude-tdd-pro/FETCH-FREQUENCIES.yaml` (written by `commands/set-refresh-frequency.sh`, read by `standards/fetch-frequency-registry.sh` + the poll-scheduler).

In ADR-0064, `--configure` used CTP's `set-refresh-frequency.sh` only as a **validator** (pointed at a throwaway path). So GCTP could drive the scraper every 6h while CTP still self-gated at *its* default daily — the operator's interval would govern the trigger but not CTP's actual fetch decision. The operator asked, explicitly, that **both** layers honor the chosen interval.

## Decision

`scripts/standards-refresh.sh --configure <freq>` now writes the validated cadence into **CTP's own registry** at `SR_CTP_FREQ_FILE` (default cwd-relative `.claude-tdd-pro/FETCH-FREQUENCIES.yaml` — the path CTP's fetch layer reads), via CTP's `set-refresh-frequency.sh` (which both validates the grammar *and* writes the registry). The single call thus:

- validates `<N>m|h|d|w|mo` / calendar grammar (invalid → exit 2, and **no** registry write);
- persists the cadence into CTP's S-22 registry (CTP's per-source scraping now honors the interval);
- and GCTP records its own drive cadence in `.harness/standards-refresh.json`.

`.claude-tdd-pro/` is gitignored (operator-local runtime state). When unconfigured, both layers default to daily, so they are already aligned; `--configure` keeps them aligned at any interval. The write is still through CTP's own command (operator-config surface) — no CTP code/rule is edited (prime directive).

**Honest note (in the doc):** CTP uses conditional GET; a scheduled re-scrape returning `304 Not Modified` is the correct cheap path (checked on schedule, unchanged), not a missed refresh.

## Alternatives considered

- **Leave CTP at its own default (ADR-0064 as-is).** REJECTED — the operator explicitly wants CTP's fetch layer on the same interval; validator-only left a real gap.
- **Have GCTP write the YAML registry by hand.** REJECTED — `set-refresh-frequency.sh` is CTP's authority for the grammar + file shape; driving it keeps authorship with CTP (prime directive). GCTP only chooses the path.
- **Make GCTP's config the only source and pass `--freq-file` to every CTP fetch.** REJECTED as primary — writing CTP's standard registry path is simpler and is what CTP's whole fetch layer already reads, with no per-invocation plumbing.

## Consequences

### Positive
- A single `--configure <freq>` now aligns **both** the GCTP trigger cadence and CTP's per-source fetch cadence — the operator's interval governs end-to-end.

### Neutral
- No `claude-tdd-pro` path edited; CTP's registry written via CTP's own command into an operator-local, gitignored file. No `schema_version` change. D-6 honored.

### Negative / cost
- One more operator-local file (`.claude-tdd-pro/FETCH-FREQUENCIES.yaml`). Documented + gitignored.

## Verification (this CL)
- `tests/test-standards-refresh.sh` — extended 17 → 19 (asserts `--configure` writes the CTP registry with the chosen freq; an invalid freq writes neither layer).
- Round-trip verified against the real CTP `set-refresh-frequency.sh` (writes `default: daily` + `chosen_at_install`) read back by CTP's `fetch-frequency-registry.sh`.
- Full audit chain green; `tests/test-all.sh` all suites; D-6 clean; no `claude-tdd-pro` path touched.

## Implementation references
- Modified: `scripts/standards-refresh.sh` (`--configure` writes `SR_CTP_FREQ_FILE`), `tests/test-standards-refresh.sh` (+2), `.gitignore` (`.claude-tdd-pro/`), `docs/standards-refresh.md` (two-layer section), `tests/README.md`, `TICKETS.md` (TICKET-075 note)
- Drives (CTP-side, not edited): `commands/set-refresh-frequency.sh`
- Related: ADR-0064 (GCTP cadence orchestrator), ADR-0061 (pin adopting §28.23)
