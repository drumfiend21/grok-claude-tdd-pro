# Phase 3 — Architecture synthesis

**Goal:** the outer loop converts the five parameters ([Phase 1](1-requirements-elicitation.md))
and the recorded decisions ([Phase 2](2-guided-technical-decisions.md)) into a concrete
architecture — and shows precisely which standard delivers each of Aisha's guarantees.

## Topology — active-active, three regions, EU residency

```
                     Geo-DNS / edge router
        ┌──────────────────┼───────────────────┐
     US region          EU region            AU region
   ┌──────────────────────────────────────────────────────────────────┐
   │ 1. Ingest fn  (validate order @ boundary — g-node-001)            │
   │      │  write-ahead → "ACCEPTED" + confirmation < 500ms           │
   │      ▼                                                            │
   │ 2. Durable order store (regional; EU stays in EU)                 │
   │      │  transactional outbox row (atomic — g-node-007)            │
   │      ▼                                                            │
   │ 3. Managed queue (absorbs 700/hr bursts — backpressure g-node-006)│
   │      ▼                                                            │
   │ 4. Idempotent processor  (dedup by order_id + idempotency_key)    │
   │      └─ order state machine: Received→Validated→Paid→Fulfilling   │
   │         →Shipped→Closed  | Failed→Retry(n)→DLQ  (assertNever g-ts-003)
   │      ▼ side-effects, each idempotent + timeout/retry (g-node-003) │
   │   Payment   Inventory   Email/Notify                              │
   │      │ exhausted retries ▼                                        │
   │ 5. Dead-Letter Queue → operator alert ("needs-attention tray")    │
   └──────────────────────────────────────────────────────────────────┘
   All of the above defined as Infrastructure-as-Code; CI emits SLSA
   provenance attestation for every dependency (g-node-010).
```

## The mechanism that delivers each guarantee

| Aisha's words | Technical decision | Enforced standard(s) |
|---|---|---|
| "never loses an order" | write-ahead durable accept **before** any risky step; transactional outbox | `g-node-007`, `g-node-001` |
| "never double-charge" (implied) | idempotency key + dedup store; every side-effect idempotent | `g-node-002`, `g-ts-003` |
| "busy sales / bursts" | managed queue + backpressure; bounded-concurrency workers | `g-node-006`, `g-node-003` |
| "different countries" | active-active geo-routed ingest; **regional** processing + storage; EU residency | (architecture) |
| "tell me when stuck" | retry → DLQ → alert; structured, typed errors | `g-node-002`, `g-node-004` |
| *(unasked) trustworthy* | schema validation at boundary; secrets via env; **SLSA provenance** | `g-node-001`, `g-node-008`, `g-node-010` |

## Why "exactly-once effect" without "exactly-once delivery"

Aisha asked that orders are "never lost" and (implicitly) never double-charged. The design
delivers this with **at-least-once delivery + idempotency**, not brittle exactly-once
transport:

1. The order is **durably accepted first** (Phase 2, Decision 2), so it can never vanish.
2. Each processing attempt is keyed by `order_id` + an `idempotency_key`; the dedup store
   makes a replay a no-op — so retries are safe and a charge happens **once**.
3. The order **state machine** is exhaustive (`g-ts-003` `assertNever`): a new state added
   later won't compile until every branch handles it, so the life-cycle can't silently rot.

This is the deliberate, robust choice — the same one the harness *explained* to Aisha in
Phase 2 rather than quietly picking.

Next: **[Phase 4 — Handoff & standards](4-handoff-and-standards.md)** →

← [Phase 2](2-guided-technical-decisions.md) · [Flow overview](README.md) · [Demonstration index](../README.md)
