# End-to-End Demonstration — from a plain-English request to world-class software

> **Start here if you want to *see* what this harness actually does.** This is a
> guided, stepwise walk-through of one complete flow: a person with **no technical
> experience** describes the software they need in plain English, and the harness
> turns that into a **world-class architectural design** — every authoritative-source
> standard for their stack enforced, including the ones they could never name.

This demonstration is the human-readable companion to the executable integration
suite in [`tests/integration/`](../../tests/integration/README.md). The scenarios
there *assert* world-class delivery; the pages here *show* the conversation and
reasoning that produce it.

## The loop you're watching

The harness is two tiers (see [`docs/architecture.md`](../architecture.md)):

| Tier | Who | Job in this demo |
|---|---|---|
| **Outer loop** | Grok (planning) | Interview the non-technical user, explain technical forks in plain language, decompose the need into atomic tickets, and emit the handoff contract. **Never edits code.** |
| **Inner loop** | Claude TDD Pro (engineering) | Take one ticket and realize it under Red-Green-Refactor, with every applicable standard enforced at write-time. |

"World-class delivery" is concrete: for the user's **detected stack**, every rule in
[`.harness/rules/active.json`](../../tests/integration/README.md) that applies is
attached to the handoff and verified — fullstack (`react`, `typescript`, `node`,
`web-vitals`, `w3c`) and cloud/security (`owasp`, `slsa`) — plus the non-exemptible,
two-phase EO governance layer.

## Featured flow — the Shop owner (multi-region order pipeline)

**Aisha**, a craft-shop owner selling internationally with no engineering background,
says: *"My online shop is growing and sometimes orders get dropped during busy sales.
I need order processing that never loses an order and works for customers in different
countries."*

Walk the flow in order:

1. **[Requirements elicitation](shop-owner-order-pipeline/1-requirements-elicitation.md)** — plain-language questions that turn the request into technical parameters.
2. **[Guided technical decisions](shop-owner-order-pipeline/2-guided-technical-decisions.md)** — the harness explains each real fork in Aisha's terms, recommends, and records her choice.
3. **[Architecture synthesis](shop-owner-order-pipeline/3-architecture-synthesis.md)** — parameters + decisions become a concrete multi-region, event-driven design.
4. **[Handoff & standards](shop-owner-order-pipeline/4-handoff-and-standards.md)** — the completed design as the harness handoff, with every world-class standard mapped to the guarantee it delivers.

Or read the [flow overview](shop-owner-order-pipeline/README.md) first.

## The full cast (all six personas)

Each is a real scenario fixture under
[`tests/integration/scenarios/`](../../tests/integration/scenarios/), spanning both
generative domains. The Shop owner is fully written up here; the others share the
identical flow shape, differing only in stack and in the standard the user could never
name.

| Persona (no technical experience) | Domain | The standard they can't name |
|---|---|---|
| Home cook — recipe-sharing web app | fullstack | `w3c` (accessibility / WCAG 2.2) |
| Bakery owner — budget-tracker SPA | fullstack | `web-vitals` (mobile speed) |
| Community volunteer — event board | fullstack | `node` (backend correctness) |
| Photographer — serverless photo-resize API | cloud | `owasp` (input / secret security) |
| **Craft-shop owner — multi-region order pipeline** ⭐ | **cloud** | **`slsa` (supply-chain provenance)** |
| Nonprofit director — site + CDN + auth | cloud | `owasp` (auth boundary) |

## What's real, and what's illustrated (honesty per ADR-0008)

- **Illustrated:** the dialogue itself is a narrative reconstruction of the outer-loop
  elicitation — no live model was transcribed. The inner-loop generation runs in
  **stub mode** (live-LLM end-to-end is deferred per ADR-0008).
- **Real and verifiable:** the standards cited (`g-*` rule IDs) are the actual rules in
  the active registry; the handoff shape is the real wire contract
  ([`docs/handoff-contract.md`](../handoff-contract.md)); and the world-class-coverage
  invariant the flow culminates in is the one the integration suite enforces.

Run the executable version of this flow:

```bash
# Drive all six personas through the real harness gates:
./tests/integration/test-generative-integration.sh

# Inspect the Shop-owner delivery as a JSON report:
node tests/integration/simulate.mjs \
  tests/integration/scenarios/multiregion-order-pipeline.json \
  .harness/rules/active.json /tmp/out world-class eo-cyber-001
```
