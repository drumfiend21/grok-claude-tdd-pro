# ADR-0093 — Plugin pin bump `b886658` → `16e9623` (adopt CTP CL-561 §31.8 — production-fetch wrapper `acquire-technology-live.sh` + `--explain` mode on the four shipped P-15 commands; both CTP post-adoption offers BUILT and merged)

- **Status:** Accepted
- **Date:** 2026-07-10
- **Deciders:** operator (`drumfiend21`; 2026-07-10: accepted CTP's two post-adoption offers via TICKET-122.b handoff; CTP built + shipped both same day at `16e9623` and asked GCTP to pin) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** After P-15's adoption at ADR-0092 (pin `b886658`), CTP flagged two post-adoption opportunities: (1) a production-fetch wrapper unblocking real KA-2 acquisition (without `--source-file` boundary stub), and (2) `--explain` mode on the four shipped P-15 commands surfacing operator-friendly narrative alongside the terse `key=value` markers GCTP's E2E assertion suite consumes. GCTP accepted both via TICKET-122.b (`docs/handoff-ctp-post-adoption-pending-items.md`, 2026-07-10). CTP built both same-day at CL-561 §31.8 and merged to `main` at `16e9623`, reporting: 5013 → 5022 CTP-side test suite (+9 `cl561-*` specs), verified live wrapper against a cached `typescript-handbook` matching 4 sources + acquiring 2 Vue-mentioning lines + dropping the non-Vue line, and confirming honest-non-fabricating behavior on empty cache (`acquired_total=0`).
- **Continues:** the pin chain ADR-0072 → ADR-0079 → ADR-0085 → ADR-0086 → ADR-0087 → ADR-0088 → ADR-0089 → ADR-0090 → ADR-0091 → ADR-0092 → this ADR (`b886658 → 16e9623`).
- **Process:** §15-gated pin bump (upstream `docs/architecture-v1.9.md` contract hash changes — §31.8 appended; hash `8caadb14… → e2e0576e…`; other 4 contract files byte-identical). **Consumer-side reconciliation on GCTP is ZERO** — both shipped surfaces are additive: `acquire-technology-live.sh` is a new command (not a change to any existing contract-surface command), and `--explain` is an additive flag on four commands whose default terse output is unchanged. GCTP's TICKET-121.a schema tolerance, TICKET-121.b invariant-4 enforcement, TICKET-121.c preservation, and TICKET-123.a A1–A4 E2E tests all pass unchanged at the new pin.

## Compatibility verdict (verified `b886658 → 16e9623`)

| Check | Result |
|---|---|
| Span | **1 semantic CTP CL** (CL-561 §31.8 shipping both the live wrapper `commands/acquire-technology-live.sh` and `--explain` mode on `resolve-technology.sh` / `acquire-technology-rules.sh` / `promote-project-rule.sh` / `recommend-technology.sh` plus supporting `commands/explain.sh` shared helper) plus the merge commit carrying the aligned §31.8 architecture record |
| upstream `docs/architecture-v1.9.md` | **CHANGED** — **purely additive**: §31.8 BUILT record appended (+7 lines; verified `git -C cache diff b886658..16e9623 -- docs/architecture-v1.9.md \| grep -cE '^-[^-]'` returns 0; ADR-0047 additive-only invariant preserved) |
| `CLAUDE.md` + 3 consumed `SKILL.md` | **all byte-identical** — verified via `sync-plugin.sh --check` (0 files drifted on 4 of 5 at new pin) |
| `active.json` | **118 → 118 rules byte-identical** — verified via `standards-sync.sh` regeneration; §31.8 adds no authored rules (just new command + additive flag on existing commands) |
| GCTP schema tolerance (TICKET-121.a) | **unchanged** — `families_active[]`/`project_id`/`project_overlay_namespaces[]` fields not touched by §31.8; 17 assertions in `tests/test-consult.sh` pass unchanged |
| GCTP invariant-4 enforcement (TICKET-121.b) | **unchanged** — XC_PROJECT_ID scoping not touched by §31.8; 11 assertions in `tests/test-audit-architecture-crosscheck.sh` pass unchanged |
| GCTP preservation (TICKET-121.c/TICKET-122) | **unchanged** — nested `generated-code-quality-standards/_project/` path not touched by §31.8; 4 preservation assertions in `tests/test-sync-plugin.sh` pass unchanged |
| GCTP Phase 1 E2E (TICKET-123.a) | **unchanged** — `resolve-technology.sh` terse-marker output preserved as default; `--explain` is additive; 41 A1–A4 assertions in `tests/test-p15-family-activation.sh` pass unchanged |
| Full suite | `test-all.sh --no-cache` **43/43** green |

## Decision

Bump the pin `b886658 → 16e9623` — upstream HEAD carrying CL-561 §31.8. This adopts CTP's response to GCTP's TICKET-122.b handoff:

1. **`commands/acquire-technology-live.sh` (item 2b — production-fetch wrapper).** New command orchestrating the full acquire lifecycle: resolves the technology's umbrella, selects source-catalog entries whose `applies_to` matches the umbrella's namespaces (the "search the same sources" model from §31), reads each source's fetched content from `--cache <dir>`, feeds each into `acquire --only-mentioning <tech>` so only the tech-mentioning lines from a general source become rules. Verified live: Vue against a cached `typescript-handbook` matched 4 sources, acquired 2 Vue-mentioning lines, dropped the non-Vue line. Unresolved tech → declines; empty cache → `acquired_total=0` (honest, non-fabricating).

2. **`--explain` mode on the four commands.** Plain-language `EXPLAIN:` output alongside the terse `key=value` markers. `resolve` explains what naming a technology turns on (and why an unknown one is declined); `acquire` explains "these apply to your project only and are NOT official until a promotion PR"; `promote` explains the reviewed-PR gate; `recommend` explains the grounded rationale ("angular matches enterprise"). Additive: existing terse output is preserved as default (GCTP's A1–A4 E2E assertions in `tests/test-p15-family-activation.sh` continue to key on the same markers unchanged).

## Boundary clarification — network fetch stays with the harness

CTP's honest note in the CL-561 handoff (which this ADR records durably): **the network fetch itself is deliberately external — harness-owned.** CTP's wrapper orchestrates `resolve → select-sources → read-cache → acquire → filter-by-mentioning`; it does NOT itself download URLs. That is the correct boundary — the plugin makes no live network calls; GCTP's harness populates the `--cache <dir>` via the already-shipped `standards/fetchers/*` invoked against umbrella-matched source URLs. This preserves the prime directive's "plugin is imported by reference, never mutated at runtime" clause and the security posture that a plugin can never make surprise outbound network calls when consumed.

**Consequence for GCTP:** the "live" wrapper is only as live as the content the harness drops into the cache dir. The GCTP-side fetch orchestrator that populates the cache from URLs (via the plugin's fetcher scripts) is queued as TICKET-125.a scope (see §"What changes for GCTP" below).

## What §31.8 delivers (the substantive change)

1. **Real KA-2 acquisition path unblocked.** At `b886658` the acquire pipeline stubs at the `--source-file <pre-fetched>` boundary — kata run required manual pre-fetch. At `16e9623` `acquire-technology-live.sh --technology vue --project FEATURE-003 --cache <populated-dir>` runs the full lifecycle in one command. The harness owns URL fetch into the cache; CTP owns everything downstream.
2. **`--only-mentioning` filter.** The wrapper's design pulls only tech-mentioning lines from a general umbrella-matched source (e.g. the TypeScript handbook mentions Vue in a section on framework interop; only those lines become Vue rules, not the whole handbook). This is precise: general sources contribute per-tech precisely when they discuss the tech, not indiscriminately.
3. **Operator-facing narrative on the command surface.** `--explain` output belongs to the command that owns the shipped behavior. GCTP's `/consult` skill can quote it verbatim in loop-level narrative (design juncture, roadmap, cross-check) rather than re-paraphrasing terse markers. TICKET-124.a wires this into the skill.
4. **Honest-non-fabricating behavior.** Empty cache → `acquired_total=0`. Unresolved tech → declines (no phantom acquire). Preserves cite-or-decline at the wrapper layer.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `16e9623`; `docs/architecture-v1.9.md` sha256 updated (`8caadb14… → e2e0576e…`); other 4 contract-file hashes unchanged (byte-identical, verified via `sync-plugin.sh --check`). Bumped by hand under this ADR (the manual-edit-under-ADR path per ADR-0079/…/0092 precedent — `--update` refuses on contract drift by design).
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `16e9623` via `sync-plugin.sh --ensure` (verified 0 drift at the new pin). Nested `generated-code-quality-standards/_project/` preservation logic tested green at TICKET-121.c/TICKET-122; unchanged here since §31.8 didn't touch that path.
- **`scripts/consult.sh --validate-profile`**: **unchanged** — §31.8 added no new profile fields.
- **`scripts/audit-architecture-crosscheck.sh`**: **unchanged** — §31.8 added no new invariant.
- **`scripts/sync-plugin.sh`**: **unchanged** — preservation path already corrected at TICKET-122; §31.8 didn't touch `_project/` layout.
- **`.harness/rules/active.json`**: 118 → 118 rules byte-identical (§31.8 adds behavior + narrative, not authored rules).
- **`docs/upstream-ctp-proposals.md` P-15 row**: appended §31.8 BUILT sub-note to the existing ADOPTED entry noting the two post-adoption offers landed; status stays ADOPTED (no re-conversion required).
- **`docs/handoff-ctp-post-adoption-pending-items.md`**: items 1 and 2 flipped from PENDING → **BUILT and ADOPTED**; item 3 (P-14 §30.7) still FILED — genuinely on CTP's plate.
- **TICKETS.md**: TICKET-125 row added (this pin bump), DONE, pointing at this ADR.
- **Follow-up GCTP-side tickets**: TICKET-125.a (E2E acquisition tests exercising `acquire-technology-live.sh` — startable NOW since the wrapper ships); TICKET-125.b (E2E promotion tests exercising `promote-project-rule.sh --dry-run`); TICKET-125.c (E2E recommender tests exercising `recommend-technology.sh`); TICKET-124 (kata.sh P-15 awareness — startable NOW); TICKET-124.a (`/consult` skill picks up `--explain` output).

## Consequences

**Positive.**

- **KA-2 kata acquisition is truly end-to-end.** Operator runs one command; the harness fetches URLs; CTP's wrapper handles resolve → select → read → acquire → filter. The prime-directive network-boundary is preserved.
- **`--explain` narrative belongs to the command that owns the behavior.** Downstream GCTP `/consult` skill can quote verbatim instead of paraphrasing terse markers — the operator-facing surface stays truthful to the shipped semantics.
- **Consumer-side reconciliation is zero.** All 43 test suites (test-consult 85/85, test-audit-architecture-crosscheck 33/33, test-sync-plugin 12/12, test-p15-family-activation 41/41, plus the pre-existing 39 suites) pass unchanged. Additive per ADR-0047 by construction.
- **`--only-mentioning` filter is precisely what "acquire from the same sources" needed.** Prevents indiscriminate rule extraction from general umbrella-matched sources.
- **Honest-non-fabricating semantics.** Empty cache → `acquired_total=0`; unresolved tech → declines. Both are cite-or-decline surfaces at the wrapper layer.

**Negative / knowingly accepted.**

- **The GCTP-side fetch orchestrator is now the gating piece.** CTP has shipped the "orchestrate acquire from a cache dir" side; GCTP owns the "populate cache from URLs via fetchers" side. TICKET-125.a scope: a small script wrapping the existing plugin `standards/fetchers/*` per umbrella-matched source URL, populating the cache dir, then invoking `acquire-technology-live.sh`. Roughly the same shape as `standards-sync.sh` but per-project-scoped and URL-driven.
- **The two-CL sequence (`b886658 → 16e9623`) is unusually fast** — CL-561 landed same day as ADR-0092. Rate reflects the operator-flagged post-adoption offers being real gaps rather than optional polish.

**Neutral.**

- `active.json` unchanged (118 → 118 byte-identical). §31.8 adds behavior + narrative, not authored rules — the "no-silent-globalization" spine A9 continues to hold trivially.
- P-14 (§30.7) still FILED at CTP — genuinely orthogonal to §31.8; independent CTP decision.

## Rollback

`git revert` this commit → lockfile snaps back to `b886658`; `acquire-technology-live.sh` disappears from the cache; `--explain` mode reverts to unrecognized flag on the four commands; GCTP's terse-marker E2E assertions (A1–A4) continue to pass since default output is unchanged. No downstream schema migration required.

## References

- CTP §31.8 (BUILT record): `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §31.8` @ `16e9623`
- CTP CL-561 (`acquire-technology-live.sh` + `--explain`): `.harness/plugin-cache/claude-tdd-pro/commands/acquire-technology-live.sh` + `commands/explain.sh` + additive flag in `resolve-technology.sh` / `acquire-technology-rules.sh` / `promote-project-rule.sh` / `recommend-technology.sh` @ `16e9623`
- CTP acceptance surface: `.harness/plugin-cache/claude-tdd-pro/evals/specs/cl561-*.json` (9 specs)
- GCTP TICKET-122.b handoff (accepted both offers): `docs/handoff-ctp-post-adoption-pending-items.md`
- GCTP E2E Phase 1 tests: `tests/test-p15-family-activation.sh` (41 A1–A4 assertions, unchanged at new pin)
- Preceding pin bump: ADR-0092 (adopt P-15 §31/§31.1/§31.2/§31.3/§31.4)
- Additivity invariant: ADR-0047
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model"
