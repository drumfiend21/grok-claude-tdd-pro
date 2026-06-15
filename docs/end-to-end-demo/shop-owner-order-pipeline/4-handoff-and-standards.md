# Phase 4 — Handoff & standards

**Goal:** the completed architectural design, expressed as the artifact the conversation
actually *produces* — the harness handoff — and decomposed into the one-CL tickets the
inner loop will realize under Red-Green-Refactor.

## The completed design as the handoff (`req.json` shape)

This is the real Grok→Claude wire contract ([`docs/handoff-contract.md`](../../handoff-contract.md)),
and it matches the scenario fixture
[`tests/integration/scenarios/multiregion-order-pipeline.json`](../../../tests/integration/scenarios/multiregion-order-pipeline.json)
exactly:

```jsonc
{
  "ticket_id": "INTEG-multiregion-order-pipeline",
  "title": "event-driven multi-region order pipeline",
  "context": {
    "user_request": "…orders get dropped during busy sales… never loses an order… different countries.",
    "persona": "Aisha, a craft-shop owner selling internationally, no engineering background",
    "domain": "cloud",
    "detected_stack": ["TypeScript", "Node.js (event-driven services)", "Managed queue + IaC"]
  },
  "acceptance_criteria": [
    "Every placed order is durably enqueued and processed exactly once, even under a traffic spike",
    "A failed processing step retries with backpressure rather than dropping the order",
    "Each deployed dependency carries a verified build-provenance attestation",
    "Order events are validated against a schema before they enter the pipeline"
  ],
  "file_scope": { "may_edit": ["services/**", "infra/**", "tests/**"] },
  "applicable_rules": [
    // typescript
    "g-ts-003", "g-ts-006", /* + g-ts-001/002/005/008 */
    // node
    "g-node-002", "g-node-003", "g-node-004", "g-node-006", "g-node-009", /* + 005/007 */
    // owasp (cloud security — the critical guard rail)
    "g-node-001", "g-node-008",
    // slsa (critical_namespace — the standard Aisha could never name)
    "g-node-010"
    // + every non-exemptible eo-* rule (two-phase EO governance)
  ]
}
```

## Decomposition into one-CL tickets (outer loop → inner-loop R-G-R)

The outer loop does **not** code. It hands the inner loop atomic tickets, each realizable
in a single Red-Green-Refactor cycle, each carrying the subset of standards it touches:

| Ticket | Slice | `applicable_rules` (subset) |
|---|---|---|
| **A** | Durable ingest + boundary validation | `g-node-001`, `g-node-008`, `g-node-007`, `g-ts-006` |
| **B** | Idempotent processor + exhaustive order state machine | `g-ts-003`, `g-node-002`, `g-ts-006`, `g-node-005` |
| **C** | Queue, backpressure, retry + DLQ + alerting | `g-node-006`, `g-node-003`, `g-node-004`, `g-node-009` |
| **D** | Multi-region IaC + EU residency + SLSA provenance | `g-node-010`, `g-node-001` |

## The closure — why this is "world-class delivery"

Every standard for the detected `typescript + node + owasp + slsa` stack is present in
`applicable_rules` — **including the `slsa` provenance rule Aisha had no vocabulary to
request.** That is precisely the invariant the
[integration suite](../../../tests/integration/README.md) verifies for this persona, and:

- its **`world-class`** mode asserts the full coverage above is delivered green;
- its **`drop-stack`** negative mode proves the harness would **reject** this design if the
  `slsa` (or any critical) family were quietly dropped;
- the **EO governance** gate ([`scripts/audit-eo-governance.sh`](../../../scripts/audit-eo-governance.sh))
  requires the non-exemptible EO rule in `applicable_rules` *and* a two-phase design
  attestation in the response;
- the **citation-integrity** gate ([`scripts/audit-source-citations.sh`](../../../scripts/audit-source-citations.sh))
  proves every one of those enforced rules traces back to a cited authoritative source.

From one plain sentence to a multi-region, provenance-attested, exactly-once-effect order
pipeline — with the guard rails the user could never have named, and a test suite that
proves they're really there.

← [Phase 3](3-architecture-synthesis.md) · [Flow overview](README.md) · [Demonstration index](../README.md)
