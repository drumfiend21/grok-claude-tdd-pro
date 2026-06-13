# ADR-0047 — EO standards are additive to the pre-existing world-class standards, never a replacement or relaxation

- **Status:** Accepted
- **Date:** 2026-06-13
- **Deciders:** drumfiend21 (architect; 2026-06-13 directive: *"The executive order standards, patterns, design patterns, coding patterns, all the executive ordered standards that are being enforced are in addition to the standards which are already in place. All those world class, first class, best in the world software patterns, and coding guides that were established at the beginning of the work of this repo. confirm."*) + Claude (cloud session, designer).
- **Second voice (per ADR-0029 pattern; 17th application):** The operator's "in addition to ... confirm" directive is the second voice — it asserts the EO layer composes on top of the foundational standards and must never displace them.
- **Trigger:** Operator-bitten clarification of the EO governance layer's relationship to the base standards, before TICKET-050 is implemented.
- **Extends:** ADR-0045 (governance layer), ADR-0046 (two-phase enforcement), ADR-0037 (operator-declared-standards regime — the base registry), and composes on the architecture R-rules, founder-directives D-rules, the TIER-0 corpus, and the TDD/C-rule discipline. Does NOT supersede anything — additive (Nygard append-only).

## Context

ADR-0045/0046 elevated the EO to a two-phase cross-cutting governance layer. The operator clarified the layer's relationship to everything that came before: the EO standards/patterns are **in addition to** the world-class standards established at the start of this repo — they do not replace, relax, or substitute for them.

The base standards in force:
- The full `.harness/rules/active.json` registry (ADR-0037): `google`, `node`, `owasp`, `react`, `slsa`, `typescript`, `w3c`, `web-vitals`, `_community` — Google style guides, OWASP ASVS + Top 10, SLSA, WCAG 2.2, Web Vitals, React/Next.js, Node.js, TypeScript handbook.
- The architecture R-rules (`docs/architecture-principles.md`).
- The founder-directives D-rules (`docs/founder-directives.md`).
- The TIER-0 AI engineering corpus (`docs/ai-engineering-corpus.md`).
- The TDD / C-rule discipline (`docs/claude-tdd-pro-principles.md` + the plugin's inner-loop SKILL.md).

The repo already encodes a composition principle ("other checklists compose on top but never override"). This ADR makes that principle explicit for the EO layer with monotonicity semantics.

## Decision

The EO governance layer is **additive, never subtractive**:

- **Add-only.** The EO layer may only ADD required rules, gates, and attestations. It MUST NOT remove, relax, weaken, or substitute for any pre-existing standard.
- **Conjunction (AND), not disjunction (OR).** `green` requires the base standards **and** the EO layer to pass. Satisfying an EO requirement never excuses a base-standard miss; satisfying a base standard never excuses an EO miss.
- **Strictest-wins on overlap (monotonic).** Where an EO standard and a base standard address the same concern, the **stricter** requirement governs. Adding the EO layer can only ever tighten the bar, never loosen it.
- **Deviation discipline unchanged and per-rule.** An EO deviation never waives a base standard; a base deviation never waives an EO requirement. Each deviation is scoped to its own rule and still requires an ADR + a `docs/deviations.md` row.

No mechanism change — this is a binding interpretation of how the EO layer composes with the existing regime.

## Alternatives considered

- **Let the EO layer be a "compliance profile" that selects a subset (and implicitly de-emphasizes the rest).** REJECTED — that could read as relaxing non-selected base standards. The base registry stays fully in force; the EO is purely additional.
- **Allow an EO requirement to substitute for an overlapping base standard.** REJECTED — substitution risks a net loosening; strictest-wins keeps it monotonic.
- **Leave additivity implicit (the composition principle already exists).** REJECTED — the operator asked to confirm it explicitly; recording it prevents a future misread that EO conformance could stand in for the base bar.
- **Fold into ADR-0045/0046 in place.** REJECTED — those are Accepted; Nygard append-only.

## Consequences

### Positive

- **The foundational standards are protected** — the EO layer can never be used (intentionally or by drift) to weaken the Google/OWASP/SLSA/WCAG/TS/React/Node base, the R-rules, the D-rules, the corpus, or the TDD discipline.
- **Monotonic quality** — every layer added can only raise the bar.
- **Unambiguous gate semantics** — `green` is the conjunction of all layers.
- **17th application of the `Second voice` field.**

### Negative

- **The combined bar is strictly higher.** That is the intent, not a cost.

### Neutral

- **No mechanism change**; no new tooling.
- **TIER-0 corpus, prime directive, founder-directives, §1 provenance untouched** (D-6 honored).
- **D-/R-/G-/C-rule bodies untouched**; plugin pin `bba77df` + `schema_version` unchanged; no `claude-tdd-pro` path touched (prime directive).

## Verification (executed before commit)

- `docs/eo-2026-ai-innovation-security-alignment.md §9` gains the "additive, never subtractive" invariant.
- `CLAUDE.md` EO subsection gains the additivity clause.
- Cross-reference, doc-drift, rulebook-coverage audits green; `tests/test-all.sh` 18/18.
- `git diff docs/founder-directives.md` → 0 lines (D-6); no `claude-tdd-pro` path modified; pin + `schema_version` unchanged.

## Implementation references

- Modified: `docs/eo-2026-ai-innovation-security-alignment.md` (§9 additivity invariant)
- Modified: `CLAUDE.md` (EO subsection additivity clause)
- New: this ADR
- Related: ADR-0045/0046 (governance layer + two-phase), ADR-0037 (base registry), `docs/architecture-principles.md` (R-rules), `docs/founder-directives.md` (D-rules), `docs/ai-engineering-corpus.md` (TIER-0), ADR-0029 (`Second voice` — 17th application)
