# ADR-0062 — Fix B: the inner loop produces `rules_verified` from real detector runs

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect) + Claude (cloud session). GCTP-side of the O'Reilly-kata enforcement-gap loop (PROPOSAL-002); consumes CTP's frozen `enforce.sh` contract (ADR-0058) + the `app_root` model (ADR-0059) and composes on the decompose-union (ADR-0060).
- **Trigger:** the kata's core failure — `rules_verified` was **asserted** in the `.res.json`, never produced by a detector run; the `rules-verified` gate only checked that the claims *covered* the named rules, never that they were *true*. Generation under enforcement requires the verdicts to come from a real run.
- **Scope:** harness self-maintenance (a new enforcement script + a wire-contract enum extension + the inner-loop discipline + the `rules-verified` gate), per the agent-operating-compact's scope boundary. Runs on the ADR + TDD plane.

## Decision

**D-A. `scripts/enforce-standards.sh` — the enforcement spine.** Given `--ticket <id>`, it resolves the `app_root` (`scripts/app-root.sh`, with the empty-tree hard guard), reads the ticket's `applicable_rules` from `.harness/handoffs/<id>.req.json`, and runs CTP's frozen entrypoint
`enforce.sh --root <app_root> --rules <ids> --json`,
then maps the per-rule 4-state verdict straight into a `rules_verified` map + an overall status. It does **not** re-implement detector dispatch (that is CTP-owned content; re-implementing it is the prime-directive drift risk the kata analysis flagged) — it calls the one contract surface. Exit `0` green / `1` red (any fail/unknown_rule) / `3` incomplete (a not_enforced, no fail) / `2` error. Ruby is required only for the real (default) `enforce.sh`.

**D-B. The wire contract gains two verdicts (additive).** `docs/handoff-contract.md`'s `rules_verified` values extend `pass | fail | deviated` → `+ not_applicable + not_enforced`:
- `not_applicable` — the detector matched **no files** in the app tree (e.g. an EO/cloud rule on a pure-TS ticket). NEUTRAL and green-eligible, but **distinct from `pass`** (kills the vacuous-green class).
- `not_enforced` — files existed but the detector could not verify them (tool/model absent) → **RED**, never a pass.

`schema_version` stays `"1"` — the addition is backward-compatible (a tolerant reader treats an unknown verdict as non-green; R-11).

**D-C. The `rules-verified` gate honors the extended enum.** `scripts/audit-rules-verified.sh`: a `green` response may carry `pass | deviated | not_applicable` for an applicable rule; any `fail` **or** `not_enforced` (or `unknown_rule`) forces red; missing keys still force red. Non-green responses remain ungated.

**D-D. The inner loop writes `rules_verified` from step 4a, never by hand.** `/inner-loop` (Claude + Cursor) gains a mandatory step between the quality gate and writing `.res.json`: run `enforce-standards.sh` and write `rules_verified` straight from its output; a `fail`/`not_enforced` means fix-and-rerun, not assert-green.

## Alternatives considered

- **Map `not_enforced → fail` and `not_applicable → pass` to avoid touching the schema.** REJECTED — `not_applicable` collapsed into `pass` is exactly the vacuous-green the effort targets; `not_enforced` collapsed into `fail` loses the "couldn't verify" vs "verified-bad" distinction an operator needs. The additive enum is honest and backward-compatible.
- **Have GCTP run the per-detector scripts directly (skip `enforce.sh`).** REJECTED — re-implements CTP-owned rule→detector dispatch and risks drift (prime directive). Call the one frozen contract surface.
- **Keep `rules_verified` asserted; verify only in the audit gate.** REJECTED — the producer (inner loop) must generate from a real run; the dynamic gate (Fix C) is the backstop, not the source.

## Consequences

### Positive
- `rules_verified` is now backed by a real detector run against the app tree; the kata's asserted-pass class is closed at the producer. A leaking file yields `fail` → red (verified live in this CL).
- The 4-state is preserved end-to-end into the wire format, so the operator can tell verified-clean from not-applicable from couldn't-verify.

### Neutral
- No `claude-tdd-pro` path edited (prime directive). `schema_version` unchanged. D-6 honored. `audit-eo-governance` is unaffected (it checks EO presence + attestation, not verdicts).

### Negative / cost
- Real enforcement needs Ruby ≥ 3.0 at inner-loop time (the `enforce.sh` prerequisite, ADR-0056). The unit test stays hermetic via a stub `enforce.sh`; CI surfaces Ruby in the environment step (Fix C wires the Ruby-dependent gate).

## Verification (this CL)
- `tests/test-enforce-standards.sh` — 13 assertions (verdict→status→exit mapping via a stub `enforce.sh`: green/red/incomplete; not_applicable neutral; empty rules; `--json` 4-state mapping + `files_evaluated`; empty app_root refused; missing enforce.sh). Green.
- `tests/test-audit-rules-verified.sh` — extended to 16 (green+not_applicable accepted; green+not_enforced rejected; red+not_enforced ungated). Green.
- Real integration sanity: `enforce-standards.sh` against a fixture app with a hardcoded secret → `g-universal-no-hardcoded-secrets: fail`, status red.
- Full audit chain green; `tests/test-all.sh` all suites; `smoke-e2e` green; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path touched.

## Implementation references
- New: this ADR; `scripts/enforce-standards.sh`; `tests/test-enforce-standards.sh`
- Modified: `docs/handoff-contract.md` (`rules_verified` enum + produce-don't-assert), `scripts/audit-rules-verified.sh` + `tests/test-audit-rules-verified.sh` (extended enum), `.claude/commands/inner-loop.md` + `.cursor/commands/inner-loop.md` (step 4a), `.github/workflows/test.yml` (Ruby visibility), `tests/README.md`, `tests/hook-security-baseline.txt`, `TICKETS.md` (TICKET-073)
- Enables: Fix C (`audit-standards-enforced.sh`, ADR-0063) — the dynamic re-run gate
- Related: ADR-0058 (`enforce.sh` contract), ADR-0059 (`app_root`), ADR-0060 (decompose-union), `proposals/PROPOSAL-002-app-enforcement-spine.md`
