# ADR-0045 — Elevate EO-2026 from feature design to a cross-cutting governance layer (harness-side enforcement; plugin-sourced rule content)

- **Status:** Accepted
- **Date:** 2026-06-13
- **Deciders:** drumfiend21 (architect; 2026-06-13 directive: *"the executive order ... should be a governance layer like an enforcement of quality and process and patterning on the entire plug in, on everything the plug in does ... not any siloed feature. Confirm."* — and the follow-on clarification: *"Claude tdd Pro has its own work happening at this time for the executive order architecture and design. That's happening in that repo."*) + Claude (cloud session, designer).
- **Second voice (per ADR-0029 pattern; 15th application):** The operator's two-part directive is the second voice — it named the failure mode (EO landing as a siloed feature rather than a governance layer) and the boundary (the plugin is doing its own EO work in its own repo). This ADR records the structural answer that honors both.
- **Trigger:** Operator-bitten signal — explicit operator direction that the EO must govern everything, not sit in TICKET-043..049 as isolated features.
- **Extends:** ADR-0037 (operator-declared-standards regime — this ADR makes the EO a first-class always-on member of it), ADR-0043 (the EO design — reframed here so the spine is primary), ADR-0044 (review-driven refinements), ADR-0026 (quality-gate non-negotiability). Does NOT supersede ADR-0043/0044 — purely additive (Nygard append-only).

## Context

ADR-0043/0044 landed the EO design as features F-EO-1..F-EO-10 / tickets TICKET-043..049. The operator directed that the EO be a **cross-cutting governance layer** — an enforcement of quality, process, and patterning across **everything the harness drives through the plugin** — not a siloed feature set.

Two constraints shape the answer:

1. **Prime directive (TIER-1):** the harness MUST NOT edit `claude-tdd-pro`. "Inform all the code of the plugin" cannot mean harness-driven edits to the plugin.
2. **The plugin is concurrently doing its own EO architecture/design work in its own repo** (operator-confirmed). So the EO **rule content** is being authored upstream; the harness must consume it, not duplicate it.

The synthesis: the harness already owns the contract surfaces that govern every unit of work — `applicable_rules` (per-ticket rule filtering, with a fail-closed "all rules apply" default), the quality gate (`green` contract), and the write-time review-gate / session-start binding (ADR-0037). Making the EO a governance layer therefore means declaring it a **first-class, always-on member of the existing operator-declared-standards regime** — *not* building a new enforcement mechanism, and *not* forking EO rules into the harness.

## Decision

Elevate the EO to a standing governance dimension with a strict ownership split:

- **Harness owns the enforcement spine.** EO-namespaced rules in `.harness/rules/active.json` are applicable to **every** ticket by default (the existing fail-closed default already does this; the EO layer makes it explicit and removes per-ticket exemption for the EO subset). The harness-native EO sub-gates (vuln remediation, provenance/signing) are standing `green` requirements. The review-gate + session-start bind both agents to the layer every session.
- **Plugin owns the rule content.** The EO-aligned standards/rubric are authored in `claude-tdd-pro` (its own in-flight EO work) and flow into `active.json` via `standards-sync.sh` on the next pin bump. **The harness MUST NOT invent harness-native EO rules** — that would duplicate/diverge from the plugin's work (prime-directive smell). The two efforts meet at the contract surface (`active.json` + `applicable_rules`); neither reaches into the other.
- **TICKET-043..049 are reframed as instances** of the layer, not the layer itself. The layer is the standing posture; the tickets are capabilities hanging off it.
- **Enforcement-spine wiring lands as TICKET-050** (gate dimension + always-on `applicable_rules` default for the EO subset + review-gate/session-start binding + the CLAUDE.md/AGENTS.md standing directive). Rule-content activation is **pin-bump-gated** on the plugin's EO work landing (separate CL + its own ADR per architecture-principles §15).
- **No plugin-side proposal is drafted from here** — the plugin's EO work is owned in its repo.

This ADR ships the CLAUDE.md standing-directive section + the design-doc §9 reframe + TICKET-050; the substrate wiring with tests lands under TICKET-050.

## Alternatives considered

- **Leave the EO as features TICKET-043..049.** REJECTED — the operator explicitly rejected the siloed-feature framing.
- **Invent harness-native EO rules to enforce immediately.** REJECTED — duplicates the plugin's in-flight EO rule work; prime-directive smell; guarantees divergence. The harness sources content from the plugin via `active.json`.
- **Build a new EO-specific enforcement mechanism (new gate engine / new hook).** REJECTED — the operator-declared-standards regime (ADR-0037) already enforces per-ticket rules via `applicable_rules` + quality gate + review-gate. The EO becomes a member of it, not a parallel system (avoids the "framework-itis" critique from ADR-0040).
- **Create a new TIER above the prime directive for the EO.** REJECTED — the EO is an operator-declared standard (TIER-1 regime), not a supreme directive. It does not outrank the prime directive, founder-directives, or the TIER-0 corpus.
- **Edit ADR-0043 in place to absorb the elevation.** REJECTED — Nygard append-only; landed a follow-on ADR + §9 instead.
- **Wait for the plugin's EO work before any harness elevation.** REJECTED — the enforcement spine (TICKET-050) can land now and is content-agnostic; it activates EO rules whenever they appear in `active.json`. Decoupling spine-from-content is the loose-coupling-correct move (R-rules).

## Consequences

### Positive

- **The EO governs everything the harness drives through the plugin, by construction** — via the always-on `applicable_rules` + quality gate, not via per-feature opt-in.
- **Zero cross-repo coupling violation** — the harness enforces; the plugin authors; they meet at `active.json`. Honors the prime directive and the independent-release-cadence invariant.
- **No duplication / no divergence risk** — the harness never forks EO rules; it consumes the plugin's.
- **Reuses existing machinery** (ADR-0037 regime), avoiding a parallel enforcement system.
- **15th application of the `Second voice` field.**

### Negative

- **Full EO rule-content enforcement is pin-bump-gated** on the plugin's EO work landing. Mitigation: the spine (TICKET-050) lands now and is content-agnostic; harness-native EO sub-gates (vuln/provenance) provide teeth immediately even before the plugin's rule content arrives.
- **CLAUDE.md grows** by one standing-directive subsection. Mitigation: it extends the existing operator-declared-standards section rather than adding a new top-level authority tier.

### Neutral

- **TIER-0 corpus, prime directive, founder-directives, §1 provenance untouched.** The EO sits inside the existing TIER-1 operator-declared-standards regime, below all of them.
- **D-/R-/G-/C-rule bodies untouched** (D-6 honored).
- **Plugin pin `bba77df` + `schema_version` unchanged**; no `claude-tdd-pro` path touched (prime directive).
- **No plugin-side proposal authored here** (plugin owns its EO work).

## Verification (executed before commit)

- CLAUDE.md gains the "EO-2026 as a standing governance dimension" subsection inside the operator-declared-standards section; `git diff docs/founder-directives.md` → 0 lines (D-6).
- `docs/eo-2026-ai-innovation-security-alignment.md` gains §9 (governance-layer elevation); 043..049 reframed as instances.
- `TICKETS.md` gains TICKET-050 (enforcement-spine wiring; pin-bump-gated content activation noted).
- Cross-reference, doc-drift, rulebook-coverage audits green; `tests/test-all.sh` 18/18.
- No `claude-tdd-pro` path modified; plugin pin + `schema_version` unchanged.

## Implementation references

- Modified: `CLAUDE.md` (standing-directive subsection)
- Modified: `docs/eo-2026-ai-innovation-security-alignment.md` (§9)
- Modified: `TICKETS.md` (TICKET-050)
- New: this ADR
- Related: ADR-0037 (operator-declared-standards regime extended), ADR-0043/0044 (EO design refined), ADR-0026 (gate non-negotiability), ADR-0040 (framework-itis caution heeded), ADR-0029 (`Second voice` — 15th application)
