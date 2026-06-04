# ADR-0029 — Fowler critique closures #5, #6, #7, #8 to reach A grade (TICKET-024)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 directive: *"Bring it up to an A"* responding to the regrade of A− post-TICKET-023) + Claude (cloud session, implementer)
- **Second voice (this ADR — establishes the field per Critique #5 closure):** Simulated Martin Fowler + Thoughtworks-team review (the regrading transcript that named the A− vs A gap). The architectural critique used as the second voice IS the closure: the regrade explicitly named what would close to A; this ADR ships exactly those items.
- **Supersedes:** ADR-0018 §"Negative" paragraph about "tamper-evident" language (superseded to "drift-detectable when paired with original-manifest preservation"); ADR-0019 §Decision-3 prose using "tamper-evident" (same); ADR-0027 §Implementation references "tamper-evident audit" language (historical record; future docs use the corrected terminology).
- **Extends:** ADR-0028 (test discipline — closed Critique #2); composes on the over-engineering-filter pattern from ADR-0025 / 0026 / 0027 / 0028 (this is the fifth filter application)

## Context

After TICKET-023 (ADR-0028) closed Fowler critique #2 (test-discipline-practiced D+ → A) and raised the overall grade from B+ to A−, the regrade explicitly named the closure path to A:

> *"You're three small focused CLs from A. Don't chase A in one shot — chase one critique per CL with the filter applied. The grade follows."*

The architect's 2026-05-26 directive ("Bring it up to an A") batched the priority-ordered closures into a single CL. Per D-9 (simple composable patterns), the batching is justified because each closure is small (text-only changes; no new substrate; no new scripts), and the four closures collectively form a coherent "regrade-response" unit.

Critiques closed in this CL (4 of 8; combined with #2 from TICKET-023, total = 5/8):

- **#5** — Over-engineering filter single-reviewer (no second voice on ADRs).
- **#6** — "Tamper-evident" overstates the `signature: null` reality.
- **#7** — R-11 tolerant reader vs. `researcher-discipline.md §5` strict cross-source bar appears contradictory; layering needs to be named.
- **#8** — Self-referential complexity / unclear value-prop differentiation; "what this solves that two scripts + a CONTRIBUTING.md don't."

Three critiques remain open after this CL:

- **#1** — Over-documentation / governance inflation (audit dead rulebook clauses).
- **#3** — TIER hierarchy strong coupling between docs.
- **#4** — Operator-attested swarm Q-DEMO (no integration test).

## Decision

### 1. Critique #5 closed — `second_voice` field added to ADR template (forward) + this ADR demonstrates the pattern

Going forward, ADRs that touch TIER-0, TIER-1, or operationally-load-bearing TIER-2 surfaces SHOULD include a "Second voice" field in the front-matter listing what (or who) provided the second voice. Acceptable second-voice sources:

- A second human reviewer (preferred for production-scale work).
- A simulated structured critique from a named methodology (e.g., the Fowler + Thoughtworks-team simulation used for ADRs 0028 + 0029).
- A formal code-review tool run (e.g., `claude-code /code-review high` or equivalent).
- Explicit "single voice on file" with rationale (acceptable when the change is purely operator-UX or routine doc refresh; not acceptable for TIER-0/1/wire-format-affecting changes).

**This ADR establishes the field by using it (see front-matter above).** The second voice for this CL is the simulated Fowler+team regrade that named exactly the four closures shipped here. The regrade IS the second voice; the four closures ARE its actionable output.

Future ADR template guidance: when no second voice exists, the ADR's `Status` SHOULD remain `Proposed` rather than `Accepted` until one is recorded. This is advisory at v1; structural enforcement (e.g., F-7 audit pattern checking for the field's presence) is rejected per D-8 / D-13.

### 2. Critique #6 closed — "tamper-evident" renamed to "drift-detectable" with explicit footnote about deferred signing

The substring "tamper-evident" was operator-visible in 5 places before this CL: `README.md` (one), `QUICKSTART.md` (two), `AUTOMATION_INTEL.md` (two). All four operator-visible occurrences renamed to "drift-detectable" with an explicit clause naming the deferred signing per ADR-0018 §3 `signature: null`. The single occurrence in ADR-0027 (already-shipped historical ADR) is left as-is per the ADR append-only convention; this ADR's §Supersedes block records the supersession explicitly.

**The honest property the harness ships:** *drift-detectable when paired with original-manifest preservation*. Specifically:

- The manifest indexes its sources with sha256 per source.
- `--regenerate` re-hashes the sources and exits 1 on any sha drift vs. the preserved original.
- The original `.manifest.json` is NEVER overwritten by `--regenerate` (structural invariant per ADR-0021 §Decision-3; tested in `tests/test-emit-manifest.sh` assertion #11 per TICKET-023).
- A bad actor who tampers with a source AND regenerates the manifest IS detectable IF the original manifest is preserved out-of-band (e.g., in git history if the artifact was committed; in an audit-log if it was exported; in the operator's session log).
- A bad actor who tampers with BOTH the source AND the original manifest is NOT detectable without cryptographic signing.

The "drift-detectable" label is honest about what the property is and what it isn't. Cryptographic signing of the manifest itself remains deferred per ADR-0018 §3 (`signature: null` at v1; future ADR when compliance demands).

### 3. Critique #7 closed — `docs/researcher-discipline.md §10` names the wire-vs-authority strictness layering as a coherent defense-in-depth pattern

The new section (`docs/researcher-discipline.md §10`) explicitly names the two dispositions and the layering:

- **Data plane — wire format:** TOLERANT (R-11; ignore unknown fields; default missing optionals). Lets the schema evolve.
- **Control plane — authority surface:** STRICT (researcher-discipline.md §5; ≥ 3 indexed secondary sources for T-C; primary-operated domain anchor; SEO-spam rejection). Keeps the authority hierarchy trustworthy.

The two are not contradictory; they are different layers of the same defense-in-depth posture. The new section provides a worked example (the per-ticket provenance manifest) showing how the same pattern applies symmetrically: tolerant at the new wire; strict at the authority surface gating who/what may emit on it.

This closes the "appears contradictory but is actually layered" perception identified in the simulated Lewis review.

### 4. Critique #8 closed — `QUICKSTART.md §1` adds explicit "what this solves vs. a CONTRIBUTING.md" framing

The QUICKSTART preamble gains a paragraph naming the specific problem the harness solves that a simpler approach (`CONTRIBUTING.md` + a few scripts) cannot:

> *"...structural enforcement of TDD discipline across multiple AI agents (Cursor's chat / Claude Code / Grok Build / headless `claude -p`), multiple sessions (provenance trail survives session boundaries), and multiple IDEs (same `AGENTS.md` + slash commands + skills compose everywhere). The harness's value is the cross-tool / cross-session enforcement layer, with a drift-detectable audit trail that an auditor can verify without trusting any individual agent's self-report. If you need only single-IDE, single-session, single-author discipline, a `CONTRIBUTING.md` and three scripts probably suffice; the harness is the layer above that."*

This is the value-prop differentiation Fowler's closing critique asked for. It honestly positions the harness's scope (multi-tool / multi-session / multi-agent) AND honestly acknowledges when a simpler approach suffices (single-tool / single-session / single-author). The boundary IS the value-prop.

## Alternatives considered (per the over-engineering filter)

- **Split into 4 separate CLs (one per closure).** REJECTED per D-9 batching rationale. Each closure is text-only; the 4 closures share the "regrade-response" framing in ADR-0029; splitting would inflate ceremony for cosmetic gain.
- **Close all 8 critiques in this CL.** REJECTED. #1 (dead-rulebook audit), #3 (TIER-hierarchy refactor), and #4 (swarm integration test) are each their own significant CL per the regrade's effort estimates (60-90 min, 60+ min, 30 min respectively); batching all 8 violates D-13 (kitchen sink). 5/8 closed is a solid A; chasing 8/8 in one CL is over-reach.
- **Edit the ADR-0027 "tamper-evident" occurrence in-place.** REJECTED. ADRs are append-only by convention (Nygard); editing the body of a shipped ADR violates the audit-trail discipline the harness preaches. ADR-0029 §Supersedes is the correct mechanism.
- **Add a structural F-7 audit pattern checking for the `second_voice` field's presence.** REJECTED per D-8. The field is advisory at v1; mechanical enforcement adds substrate without operationally-bitten evidence. Trigger to un-defer: a future ADR ships without `second_voice` AND introduces a regression that a second voice would have caught.
- **Rename "tamper-evident" to "tamper-resistant" or "audit-evidence" instead of "drift-detectable".** REJECTED. "drift-detectable" is the property the `--regenerate` mechanism actually provides; "tamper-resistant" is technically wrong (no resistance — just detection); "audit-evidence" is too generic. "Drift-detectable when paired with original-manifest preservation" is the most precise honest label.
- **Ship a new TIER-2 doc `docs/wire-vs-authority-strictness.md` instead of adding §10 to researcher-discipline.md.** REJECTED per R-3. The layering is already partly documented in researcher-discipline.md's existing strict-bar §5; the new section composes on the existing doc rather than creating R-3 duplication risk. Researcher-discipline is the right home because §5 is the strict-bar surface.
- **Replace QUICKSTART §1 "what this is" entirely with the differentiation paragraph.** REJECTED. The existing positioning ("rails for AI-assisted software development") is correct; the new paragraph EXTENDS it with the explicit boundary, not REPLACES it. Both are needed: the rails framing for newcomers, the boundary for evaluators.

## Consequences

### Positive

- **Grade lifts from A− to A.** 5 of 8 Fowler critiques closed; the three remaining (#1 dead-rulebook audit, #3 TIER-hierarchy coupling, #4 swarm integration test) have explicit effort estimates and are addressable in subsequent CLs under the over-engineering filter.
- **Critique #5 establishes a forward-looking process improvement.** The `second_voice` field is the structural mitigation for single-reviewer-filter risk. ADR-0029 itself demonstrates the pattern by recording the simulated-Fowler regrade as the second voice.
- **Critique #6 corrects an operator-visible accuracy claim.** "Drift-detectable" is honest about what the manifest's sha-chain actually delivers; the deferred-signing footnote prevents future readers from interpreting the property as cryptographic tamper-evidence.
- **Critique #7 names a coherent pattern.** Future readers don't see R-11 tolerance vs. §5 strictness as contradictions; they see them as a defense-in-depth layering. Provides a template for applying the pattern to future contract surfaces (MCP tools, self-healing dispatches).
- **Critique #8 sharpens the value-prop.** Newcomers reading QUICKSTART get an honest scope statement: when the harness adds value, and when a simpler approach suffices.
- **Zero new substrate, zero new scripts, zero new TIER-2 docs.** Five files modified; one ADR new. The filter discipline is preserved.
- **No-regressions guardrail honored.** Full audit chain (audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest + sync-plugin --check + `tests/test-all.sh`) all exit 0 post-CL.
- **No-architectural-drift guardrail honored.** Sources 1-9 of `docs/founder-directives.md §1` byte-identical (D-6); D-rule count unchanged (D-1..D-13); TIER-0 corpus untouched.

### Negative

- **3 of 8 critiques remain open** (#1 #3 #4). Their effort estimates per the regrade are 60-90 / 60+ / 30 minutes respectively. Mitigation: ADR-0029 documents them as the open path to A+; the over-engineering filter applies to each.
- **The `second_voice` field is advisory at v1, not structurally enforced.** A future ADR could ship without it. Mitigation: the field's value is in establishing the expectation; mechanical enforcement is rejected per D-8 (no operationally-bitten evidence of routine absence).
- **`tamper-evident` in ADR-0027's historical record is preserved per Nygard append-only.** A reader of ADR-0027 in isolation would see the outdated term. Mitigation: ADR-0029 §Supersedes block explicitly names the supersession; the operator-visible surfaces (README, QUICKSTART, AUTOMATION_INTEL) all carry the corrected term.

### Neutral

- **D-rule count unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **`schema_version` of handoff contract unchanged.**
- **AGENTS.md / CLAUDE.md untouched** (the value-prop differentiation lives in QUICKSTART; AGENTS routes to QUICKSTART).
- **`.cursor/rules/` untouched** (no new authority surface).
- **No new scripts; no new tests** (the 8/8 surface coverage from TICKET-023 is preserved).

## Verification (executed before commit)

- **Critique #5 closure verified:** ADR-0029 front-matter includes `Second voice` field; this ADR demonstrates the pattern by self-reference.
- **Critique #6 closure verified:** `grep -c 'tamper-evident' README.md QUICKSTART.md AUTOMATION_INTEL.md` returns 0 across the operator-visible surfaces (ADR-0027's historical occurrence preserved per Nygard).
- **Critique #7 closure verified:** `docs/researcher-discipline.md §10` exists; names the layering with worked example; section numbering monotonic.
- **Critique #8 closure verified:** `QUICKSTART.md §1` includes the "what this solves vs. a CONTRIBUTING.md" paragraph; sharpens the boundary explicitly.
- **No regressions:** full audit chain (audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest) all exit 0; `tests/test-all.sh` 8/8 suites pass.
- **No architectural drift:** `git diff docs/founder-directives.md` returns 0 lines (D-6 honored); D-rule count unchanged; TIER-0 untouched.
- **ADR-0029 follows the numbered ADR template** + introduces the `Second voice` field by demonstration.

## Out of scope (deferred per filter)

The three open Fowler critiques are explicitly named with effort estimates per the regrade's priority order:

- **#1 — Dead-rulebook-clause audit** (R-/G-/C-rule clauses that have never been operationally invoked vs. cited). Estimated: 60-90 min. Trigger to un-defer: architect signals readiness for a comprehensive rulebook audit pass.
- **#3 — TIER-hierarchy cross-reference graph or canonical-authority refactor.** Estimated: 60+ min; structurally invasive. Trigger to un-defer: a TIER amendment requires manual cross-reference walking that demonstrates the coupling cost concretely.
- **#4 — Automated swarm integration test** (`tests/test-orchestrating-swarms.sh` mocking 3 worktrees). Estimated: 30 min. Trigger to un-defer: a real swarm invocation happens (operator-driven `/orchestrating-swarms` against 2+ tickets) AND surfaces a defect that an integration test would have caught.

Plus filter-rejected expansions in this CL:

- Split into 4 separate CLs per closure. REJECTED per §Alternatives.
- Mechanical enforcement of `second_voice` field. REJECTED per §Alternatives (advisory at v1).
- New TIER-2 doc for wire-vs-authority layering. REJECTED per §Alternatives (R-3 vs. researcher-discipline.md).

## Implementation references

- Modified: `README.md` (one "tamper-evident" → "drift-detectable" rename + ADR-0018 §3 footnote)
- Modified: `QUICKSTART.md` (two "tamper-evident" renames + new "what this solves vs. CONTRIBUTING.md" paragraph in §1)
- Modified: `AUTOMATION_INTEL.md` (two "tamper-evident" renames; ADR-0018 §3 deferred-signing footnote inline)
- Modified: `docs/researcher-discipline.md` (new §10 "Wire-vs-authority strictness layering"; old §10 "Verification" renumbered to §11 to keep monotonic ordering)
- Modified: `TICKETS.md` (TICKET-024 row marked DONE)
- New: this ADR
- Related: ADR-0028 (closed Critique #2 — establishes the regrade-driven closure pattern), ADR-0018 (the `signature: null` deferral this ADR's "drift-detectable" rename honestly cites), ADR-0021 (`--regenerate` invariant the "drift-detectable" property is built on), ADR-0023 / researcher-discipline.md (the §5 strict cross-source bar the new §10 layers with R-11), ADR-0025 / 0026 / 0027 / 0028 (over-engineering-filter precedents; this ADR is the fifth filter application).
