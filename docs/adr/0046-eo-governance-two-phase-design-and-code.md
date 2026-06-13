# ADR-0046 — EO governance is enforced at the inner loop's design-before-code phase, not only on code

- **Status:** Accepted
- **Date:** 2026-06-13
- **Deciders:** drumfiend21 (architect; 2026-06-13 directive: *"The executive order governance, patterning, design, standards, and process also are enforced by Claude TDD Pro on the code that it creates and also the designs that it creates before it codes, to be clear."*) + Claude (cloud session, designer).
- **Second voice (per ADR-0029 pattern; 16th application):** The operator's "to be clear" directive is the second voice — it named the phase gap (the ADR-0045 spine leaned code/output-side) and asserted the enforcer is Claude TDD Pro itself, at both the design and code phases.
- **Trigger:** Operator-bitten clarification of ADR-0045's scope, before TICKET-050 is implemented (cheapest point to fold it in).
- **Extends:** ADR-0045 (governance-layer elevation — this adds the phase dimension), ADR-0037 (operator-declared-standards regime), ADR-0026 (gate). Does NOT supersede — additive (Nygard append-only).

## Context

ADR-0045 elevated the EO to a cross-cutting governance layer governing "every ticket, handoff, and CL." That framing was correct but leaned **code/output-side**: the named teeth were the quality-gate sub-gates and `rules_verified` on the produced code. The operator clarified that EO governance must also pattern the **design Claude TDD Pro produces *before* it codes** — i.e., the inner loop's spec/plan phase — and that the **enforcer is Claude TDD Pro itself** (the plugin), at both phases, not merely a harness gate applied after the code exists.

The prime directive still binds: the plugin's design-phase and code-phase enforcement *behavior* is the plugin's own (its in-flight EO work). The harness cannot implement that behavior. But the harness owns the **contract**, and can require + verify that the enforcement happened at both phases.

## Decision

Make EO governance explicitly **two-phase** across the spine:

- **Phase 1 — design-before-code.** The EO patterns the spec/plan the inner loop produces *before* writing code. Enforcement is the plugin's (`tdd-pro-cl-workflow` design step). The harness requires the response/decision-trail to **attest** that EO patterning was applied at the design stage (which EO-relevant rules/standards shaped the design; which patterns were chosen/rejected and why).
- **Phase 2 — code.** The EO patterns the code (existing teeth: EO sub-gates + `rules_verified`).
- **Gate semantics.** `green` requires EO conformance evidence for **both** phases. Code that passes the rule checks but whose pre-code design carries no EO-conformance attestation is **not** `green` — the gate refuses it. This makes the harness verify that the EO shaped the design, not just the output.
- **Division of labor (prime directive).** The plugin *enforces* at both phases (in-flight EO work, its repo). The harness *demands + verifies* via the contract (handoff requires both-phase conformance; response/decision-trail attests; gate enforces). Neither reaches into the other; they meet at the contract surface.

Wiring lands under **TICKET-050** (the enforcement spine), extended to cover the design-phase attestation. No new mechanism — it rides the existing decision-trail + `rules_verified` + gate.

## Alternatives considered

- **Leave the spine code/output-side only.** REJECTED — the operator explicitly required design-phase governance.
- **Have the harness perform the design-phase enforcement.** REJECTED — that is the plugin's inner-loop behavior (prime directive); the harness only demands + verifies attestation via the contract.
- **Add a new design-review hook/engine.** REJECTED — rides the existing decision-trail + gate; no new mechanism (anti-framework-itis, ADR-0040).
- **Fold into ADR-0045 in place.** REJECTED — ADR-0045 is Accepted; Nygard append-only. Landed a follow-on ADR + design-doc §9 subsection.

## Consequences

### Positive

- **EO shapes the design, not just the code** — the most leveraged point, since design decisions constrain everything downstream.
- **Clean prime-directive division** — plugin enforces at both phases; harness demands + verifies via contract; meet at the contract surface.
- **No new mechanism** — reuses decision-trail + `rules_verified` + gate.
- **16th application of the `Second voice` field.**

### Negative

- **Design-phase attestation adds a `green` requirement.** Mitigation: it is satisfied by a decision-trail section, not new tooling; harness-native teeth remain even before the plugin's rule content lands.

### Neutral

- **TIER-0 corpus, prime directive, founder-directives, §1 provenance untouched.**
- **D-/R-/G-/C-rule bodies untouched** (D-6 honored).
- **Plugin pin `bba77df` + `schema_version` unchanged**; no `claude-tdd-pro` path touched (prime directive); no plugin proposal authored here.

## Verification (executed before commit)

- `docs/eo-2026-ai-innovation-security-alignment.md §9` gains the two-phase-enforcement subsection.
- `CLAUDE.md` EO subsection gains the design-before-code clause.
- `TICKETS.md` TICKET-050 scope extended with the design-phase attestation requirement.
- Cross-reference, doc-drift, rulebook-coverage audits green; `tests/test-all.sh` 18/18.
- `git diff docs/founder-directives.md` → 0 lines (D-6); no `claude-tdd-pro` path modified; pin + `schema_version` unchanged.

## Implementation references

- Modified: `docs/eo-2026-ai-innovation-security-alignment.md` (§9 two-phase subsection)
- Modified: `CLAUDE.md` (EO subsection design-before-code clause)
- Modified: `TICKETS.md` (TICKET-050 design-phase attestation)
- New: this ADR
- Related: ADR-0045 (governance layer extended), ADR-0037 (regime), ADR-0026 (gate), ADR-0029 (`Second voice` — 16th application)
