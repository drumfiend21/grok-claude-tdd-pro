# examples/

Demo targets the harness operates on end-to-end.

| Path | Role |
|---|---|
| [`string-utils/`](./string-utils/) | TICKET-005 toy module. Demonstrates one R-G-R cycle through the full outer-loop → handoff → inner-loop pipeline. Ships at 4 pass / 1 red; the smoke script (TICKET-006) closes the gap once. |

**D-5 lockdown** applies to everything under this tree: no CL after TICKET-005 lands purely against the toy. Future demos that materially expand `examples/` either target real problem instances or require an explicit ADR. See [`./string-utils/README.md`](./string-utils/README.md) for the full notice.
