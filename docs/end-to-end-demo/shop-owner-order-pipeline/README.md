# Shop owner — multi-region order pipeline

A complete, stepwise walk-through of the outer-loop flow that turns one non-technical
sentence into a world-class cloud architecture, for the scenario fixture
[`tests/integration/scenarios/multiregion-order-pipeline.json`](../../../tests/integration/scenarios/multiregion-order-pipeline.json).

## The person and the ask

> 🧑‍🌾 **Aisha**, a craft-shop owner selling internationally, no engineering background:
> *"My online shop is growing and sometimes orders get dropped during busy sales. I need
> order processing that never loses an order and works for customers in different countries."*

She cannot name a queue, an idempotency key, or a provenance attestation. The harness's
job is to deliver all three anyway — and to *explain* the ones that affect her choices.

## The flow (read in order)

| Phase | Page | What happens |
|---|---|---|
| 1 | [Requirements elicitation](1-requirements-elicitation.md) | Small clusters of plain-language questions convert the request into five technical parameters. |
| 2 | [Guided technical decisions](2-guided-technical-decisions.md) | The harness surfaces each genuine fork, explains the trade-off in Aisha's terms, recommends, and records her choice — plus the world-class defaults it attaches without asking. |
| 3 | [Architecture synthesis](3-architecture-synthesis.md) | Parameters + decisions become a concrete active-active, event-driven, EU-residency-aware design with exactly-once *effect*. |
| 4 | [Handoff & standards](4-handoff-and-standards.md) | The completed design as the harness's `req.json` handoff, decomposed into one-CL tickets, with every standard mapped to the guarantee it delivers. |

## The outcome in one line

Every standard for the detected `typescript + node + owasp + slsa` stack is enforced —
**including the `slsa` build-provenance rule Aisha had no vocabulary to request** — which
is exactly the "world-class delivery" invariant the
[integration suite](../../../tests/integration/README.md) verifies, and which its
`drop-stack` negative test proves the harness would *reject* if quietly dropped.

← Back to the [demonstration index](../README.md).
