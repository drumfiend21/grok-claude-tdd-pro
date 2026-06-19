# ADR-0061 — Plugin pin bump `eb7b2af` → `7a7f74d` (adopt refresh-driven universal coverage)

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect) + Claude (cloud session).
- **Trigger:** CTP `main` advanced two CLs `eb7b2af → 7a7f74d` (§28.22–§28.23): refresh-driven universal coverage (effort proportional to the upstream source delta) + begin-refreshing-on-install with an operator-chosen cadence. These are the operator-directed extensions that grew from the universal-coverage foundation; the GCTP-side Fix B/C build against the **same frozen `enforce.sh` contract**, so the bump keeps GCTP current without changing what Fix B/C consume.
- **Continues:** the ADR-0054 → 0058 pin chain.
- **Process:** §15-gated pin bump (`architecture-v1.9.md` contract hash changed); lockfile updated by hand under this ADR.

## Compatibility verdict (verified `eb7b2af → 7a7f74d`)

| Check | Result |
|---|---|
| Span size | **3 commits** (CL-482, CL-483, a gitignore chore) |
| CTP's `architecture-v1.9.md` | **+22 / −0** (the §28.22–§28.23 notes; Nygard append-only) |
| `CLAUDE.md` + the 3 consumed skills | **unchanged** (sha256 identical) |
| `rubric/enforce.sh` | **unchanged** (byte-identical — the contract Fix B/C build against is stable) |
| Files deleted / commands removed | **0** |
| New top-level surfaces | **none** (`audit-plugin-surface` 56 → 56) |
| Rubric rules `active.json` | **46 → 46** (CL-482/483 are a refresh *mechanism*, not new rules) |

## Decision

Bump the pin `eb7b2af` → `7a7f74d`:
- **Lockfile:** update `pinned_commit` / `pinned_at` / `pinned_message` / `last_synced_*` and re-hash `architecture-v1.9.md` (`4e1bc2c2…` → `af6b6d52…`). `CLAUDE.md` + the 3 skill hashes unchanged.
- **Adopt read-only** — no `claude-tdd-pro` path edited from here (prime directive).

## What changes for GCTP

- **Gained:** CTP's standards now refresh on the operator's chosen cadence (default daily); re-running `standards-sync` picks up refreshed catalog rules automatically, and the refresh is delta-gated (cheap). The GCTP-side enforcement (Fix B/C) is unaffected — the `enforce.sh` contract is byte-identical.
- **Unchanged:** the enforced rule set (46), the 3 executed skills, `CLAUDE.md`, `schema_version`, the `enforce.sh` 4-state contract.

## Consequences

### Positive
- Keeps GCTP pinned to CTP's named target (`7a7f74d`) so Fix B/C are written against the current, stable contract.

### Neutral
- No behavior change for GCTP enforcement; purely a freshness/mechanism adoption. No `claude-tdd-pro` path edited. D-6 honored. `schema_version` unchanged.

## Verification (executed before commit)
- `sync-plugin.sh --check` → pin matches HEAD, **0 contract drift**; `--ensure` → cache at `7a7f74d`.
- `standards-sync` → **46 rules** (unchanged); full audit chain green; `tests/test-all.sh` all suites; `smoke-e2e` green; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path modified.

## Implementation references
- Modified: `docs/claude-tdd-pro.lock.yaml` (pin + `architecture-v1.9.md` hash), `README.md` (pin badge), `TICKETS.md` (TICKET-072)
- New: this ADR
- Adopts (CTP-side, not edited here): CL-482 (§28.22 refresh-driven coverage), CL-483 (§28.23 begin-on-install + cadence)
- Related: ADR-0058 (prior pin bump `6d2fe13`→`eb7b2af`)
