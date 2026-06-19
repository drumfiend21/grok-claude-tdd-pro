# ADR-0063 — Fix C: the dynamic re-run gate (`rules_verified` claims must be TRUE)

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect) + Claude (cloud session). Final GCTP-side CL of the O'Reilly-kata enforcement-gap loop (PROPOSAL-002); composes on Fix B (ADR-0062), the `app_root` model (ADR-0059), and CTP's `enforce.sh` contract (ADR-0058).
- **Trigger:** the kata's gate weakness — `audit-rules-verified.sh` (static) only checks that a green response's `rules_verified` *covers* the named rules and carries no `fail`; it never re-runs detectors, so a response could **claim** `pass` on code that actually violates a rule and stay green. Fix B made the inner loop *produce* verdicts from a real run; Fix C is the backstop that proves they are *true*.
- **Scope:** harness self-maintenance (a new dynamic gate), per the agent-operating-compact's scope boundary.

## Decision

**`scripts/audit-standards-enforced.sh`** — for every `.harness/handoffs/*.res.json` with `status: green` whose matching request carries `applicable_rules`, with a resolvable `app_root`, it **re-runs the detectors** against the app tree via `scripts/enforce-standards.sh` (the same spine the inner loop uses) and asserts:
1. every claimed `rules_verified[rule]` **equals the live verdict** for that rule — a response claiming `pass` on a rule the code now violates is RED;
2. every live `pass` has **`files_evaluated > 0`** — a "pass" that evaluated zero files is a vacuous/asserted pass and is RED.

This converts the `rules_verified` gate from *"claims complete"* (static, Fix-A-era) to *"claims true"* (dynamic).

**Vacuous (pass) when** no `app_root` is configured (no external app to verify — the common CI case, since `.harness/app.json` is operator-local/gitignored) or no green response carries `applicable_rules`. The gate only bites once an operator points the harness at a real app tree — at which point it has full teeth. Wired WARN-not-FAIL at session start; the pre-commit chain + CI are the hard gate.

## Alternatives considered

- **Fold the re-run into `audit-rules-verified.sh`.** REJECTED — that gate is static + content-agnostic + always-runs; the dynamic gate needs an `app_root` + Ruby + `enforce.sh`, and is vacuous without them. Keeping them separate preserves the static gate's universality and isolates the Ruby/app-tree dependency to the dynamic one.
- **Re-implement the detector run in the gate.** REJECTED — call `enforce-standards.sh` (which calls the one `enforce.sh` contract surface). Re-implementing dispatch is the prime-directive drift risk.
- **Hard-fail at session start when no app_root.** REJECTED — no app_root means there is genuinely nothing to re-verify; vacuous-pass is correct, and consistent with the other handoff gates' WARN-at-start / hard-in-CI posture.

## Consequences

### Positive
- Closes the loop the kata exposed: a green response cannot survive if its claims diverge from a live detector run, or if a "pass" evaluated no files. No asserted passes, no vacuous passes — end to end.
- Reuses Fix B's spine, so the gate verifies against the *identical* mechanism the producer used.

### Neutral
- No `claude-tdd-pro` path edited (prime directive). No `schema_version` change. D-6 honored.

### Negative / cost
- When an `app_root` is configured, the gate needs Ruby ≥ 3.0 + the app tree present (the `enforce.sh` prerequisite). Vacuous (no cost) in CI until then; the unit test stays hermetic via a stub `enforce.sh`.

## Verification (this CL)
- `tests/test-audit-standards-enforced.sh` — 10 assertions (claims-match→0; claim-pass-on-live-fail→1; vacuous-pass `files_evaluated 0`→1; not_applicable match→0; claimed-na-but-live-pass→1; skipped when non-green / no applicable_rules; vacuous when no app_root / no green response). Green via a stub `enforce.sh`.
- Real-tree run with no `.harness/app.json` → vacuous pass.
- Full audit chain green; `tests/test-all.sh` all suites; `smoke-e2e` green; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path touched.

## Implementation references
- New: this ADR; `scripts/audit-standards-enforced.sh`; `tests/test-audit-standards-enforced.sh`
- Modified: `.claude/hooks/session-start.sh` (WARN gate), `.claude/commands/audit.md` + `.github/workflows/test.yml` (hard gate), `tests/README.md`, `tests/hook-security-baseline.txt`, `TICKETS.md` (TICKET-074)
- Completes: the GCTP-side Fix A–D of PROPOSAL-002 (Fix D ADR-0059, Fix A ADR-0060, Fix B ADR-0062, Fix C this ADR), on top of the CTP-side Fix E/F/G adopted at pin `7a7f74d` (ADR-0058/0061).
- Related: ADR-0062 (Fix B / `enforce-standards.sh`), ADR-0058 (`enforce.sh` contract)
