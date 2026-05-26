# /smoke — run end-to-end harness smoke

## Purpose

Run the end-to-end smoke script (`scripts/smoke-e2e.sh`) and report the result. The smoke drives one full handoff cycle: outer-loop dispatch → request JSON → stub inner-loop → response JSON + decision trail → quality-gate sub-gate cross-checks. Exit 0 confirms the handoff contract, the inner-loop driver, and the trail surface all work end-to-end against the `examples/string-utils/` demo target. The script restores the toy module to its Red baseline on exit (per ADR-0008), so it is idempotent across runs.

## Inputs

None at v1. (The script defaults to stub mode; live-Claude mode is deferred per ADR-0008.)

## Steps

1. Run `./scripts/smoke-e2e.sh` in the terminal.
2. Capture stdout/stderr.
3. Report to the user: pass/fail; the three artifact paths the script names (`.req.json`, `.res.json`, `.harness/trails/TICKET-NNN.md`); the line `smoke OK — outer loop → handoff → inner loop → green tests → response`.

## Success criteria

- Script exits 0.
- Output includes `smoke OK — outer loop → handoff → inner loop → green tests → response`.
- `examples/string-utils/` ends the run at its Red baseline (`node --test` returns 4 pass / 1 fail per TICKET-005) — the script's trap reverts the inner-loop write.

## Composition (D-1 reverse per ADR-0013)

Wraps the existing `scripts/smoke-e2e.sh` (TICKET-006 / ADR-0008). Grok analog: the outer-loop dispatch templates the script invokes (`.grok/templates/dispatch.md`) — the smoke is the cross-tool verification that the wire format between outer and inner is real.
