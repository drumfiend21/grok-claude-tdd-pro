# ADR-0039 — Architecture-consult phase: Grok → Claude-TDD-Pro before decomposition (TICKET-034)

- **Status:** Accepted
- **Date:** 2026-06-06
- **Deciders:** drumfiend21 (architect; 2026-06-06 directive surfaced the gap: *"when the planning is being done, it should consider how Claude TDD Pro is going to plan the architecture. Right? So, like, the... how can you size something if you don't know the actual technical approach?"*) + Grok (architectural reviewer; ratified the proposal with refinements — caching, operator toggle, advisory-not-gospel framing, schema discipline) + Claude (cloud session, implementer).
- **Second voice (per ADR-0029 pattern; 9th application):** Grok's own review of the proposal, recorded verbatim in the conversation trail before this CL. Grok's literal closing position: *"Yes — ship it. The current blind decomposition is the biggest remaining source of 'ticket rework.' Adding this consult phase will materially improve ticket quality and reduce downstream waste."* The four refinements Grok added (caching, operator toggle, advisory-not-gospel, schema discipline) are incorporated below; this CL implements Grok's reviewed plan, not the original proposal as-stated.
- **Trigger:** Operator-bitten signal — the architect named the gap explicitly: Grok was decomposing blind because it had no round-trip into claude-tdd-pro's test-shape / refactor-sequencing / mutation-seam / ADR-trigger / portability knowledge. Decomposition was therefore producing tickets that got auto-corrected during R-G-R, which is wasteful and risks mid-ticket scope expansion (a one-ticket-per-CL violation).
- **Supersedes:** the silent assumption (across `.grok/templates/research.md`, `decomposition.md`, `dispatch.md` since TICKET-003 / ADR-0006) that research output alone is sufficient input to decomposition.
- **Extends:** ADR-0006 (Grok template trilogy — this CL adds a 4th template upstream of decomposition); ADR-0010 (handoff contract — new `Architecture-Consult` schema); ADR-0029 (`Second voice` field — 9th application; Grok IS the second voice this time, not the operator); ADR-0037 (standards consumption — the consult populates `applicable_rules` per ticket against `.harness/rules/active.json`).

## Context

Across TICKETS 032 + 033 + 033.a, the harness shipped the standards consumption wire end-to-end: OWASP / Google / SLSA / etc. rules reach Claude's writes; PostToolUse blocks P0 violations; deviation registry handles legitimate exceptions; AIBOM emits per-ticket. The operator confirmed this was the architecture intent.

Then the operator asked a sharper question: *"when the planning is being done, it should consider how Claude TDD Pro is going to plan the architecture. ... how can you size something if you don't know the actual technical approach?"*

Verified by grepping `.grok/templates/decomposition.md`: **0 references to "consult", "technical-approach", "inner-loop", or any callback into claude-tdd-pro**. Grok was decomposing on its own judgment + the research bundle, with no architectural review from the system that holds the production-grade engineering knowledge.

The consequence: tickets were getting auto-corrected during R-G-R. Specific patterns the consult would have caught:

- **Test-shape determines file_scope.** TDD-driven design might extract a value object that needs its own ticket. Grok didn't know.
- **Refactoring sequencing.** Claude's `tdd-pro-cl-workflow` may dictate green-before-refactor across multiple tickets. Grok didn't know.
- **Mutation-test seams.** Claude's testing discipline shapes what's mockable. Grok didn't know.
- **ADR triggers.** Claude might say "this is a structural change requiring an ADR before code." Grok didn't know.
- **C-23 portability for `.sh` substrate.** 9 named gotchas affect implementation shape. Grok didn't know.
- **Per-rule sequencing.** Some rules in `active.json` shape design (e.g., OWASP V5.1 schema validation at boundary). Grok didn't know which applied per ticket.

The operator's sharper question is the operator-bitten trigger. Grok's review of the proposal added the refinements that make the consult ship-able rather than over-engineered.

## Decision

### 1. Insert an architecture-consult phase between research and decomposition

`.grok/templates/architecture-consult.md` is a new template. It calls into Claude-TDD-Pro (via the same SKILL.md trio + dispatch wrapper the rest of the harness uses) with the feature brief + research bundle and asks the **six numbered questions**:

1. **Test-shape.** What's the test structure that drives this feature's design?
2. **Decomposition.** What's the natural decomposition into atomic R-G-R tickets?
3. **Sequencing.** What's the `depends_on` graph?
4. **Scope per ticket.** What `file_scope.may_edit` + `may_read` does each ticket need?
5. **Applicable rules.** Which rules from `.harness/rules/active.json` apply per ticket?
6. **Complexity.** Estimated complexity (small / medium / large) + any ADR-required flags.

Output: `.harness/handoffs/FEATURE-NNN.architecture.json` per the schema in `docs/handoff-contract.md §Architecture-Consult`.

### 2. The consult artifact is REQUIRED input to decomposition

`.grok/templates/decomposition.md` now requires `architecture_consult` as a 3rd input variable alongside `research_output` + `decomposition_brief`. Decomposition consumes:

- `recommended_tickets` as the proposed structure (Grok can refine but is no longer blind).
- `prior_decisions` flows into each generated `.req.json`'s `context.prior_decisions`.
- `applicable_rules` per ticket populates the request's field directly (closes the gap TICKET-033.a opened — Grok now has the data it needs).

### 3. Advisory, not gospel (per Grok's refinement)

Critical framing: the consult artifact is **advisory input** to decomposition, not a hard contract. Grok retains decomposition authority. When Grok overrides a `prior_decisions` entry, the override rationale is recorded in:

- `grok_notes` of the FEATURE-level artifact.
- `context.prior_decisions` of the affected `.req.json`.

This preserves Grok's creative high-level decomposition capability while closing the technical-blindness gap.

### 4. Cache + operator toggle (per Grok's refinement)

- **Cache key:** `sha256(json.canonicalize(research_bundle) + "\n" + decomposition_brief)`.
- **Cache location:** `.harness/cache/architecture-consult/<cache_key>.json` (gitignored).
- **Hit policy:** byte-identical input → byte-identical output read from cache; no round-trip.
- **Plugin pin bump invalidates** the cache (skill + rules may have shifted). `sync-plugin.sh --ensure` clears on pin-commit change.
- **`consult_toggle: off`** is permitted for trivial / single-line tickets where round-trip cost exceeds benefit. Default `on`. Skipped consults emit a stub artifact with `consult_skipped: true` + rationale; decomposition falls back to pre-TICKET-034 behavior with a visible WARN.

### 5. Pre-emit validation

The consult template validates against the schema BEFORE writing. Every `recommended_tickets[].applicable_rules` ID must resolve in `.harness/rules/active.json` (unknown rule = `error.code: "unknown_rule"`; operator re-runs `standards-sync`). Every `must_not_touch` includes the prime-directive denylist (`.grok/**`, `.claude/**`, `claude-tdd-pro/**`).

## Alternatives considered

- **Bake the consult into decomposition.md itself (no separate template).** REJECTED per separation of concerns. The consult is a distinct round-trip (Grok → Claude → Grok) with its own cache, its own schema, and its own toggle. Bundling into decomposition would conflate two different operations and prevent the cache-skip optimization on repeated decompositions of the same input.
- **Treat consult output as gospel (hard contract).** REJECTED per Grok's refinement. Decomposition needs creative authority; the consult informs, doesn't dictate.
- **Skip caching at v1.** REJECTED per Grok's latency/cost concern. Without caching, every decomposition incurs a full Claude round-trip even when the input hasn't changed; that compounds across iterative planning sessions.
- **Make consult unconditional (no operator toggle).** REJECTED per Grok's concern about trivial tickets. A one-line typo-fix ticket doesn't warrant an architectural consult.
- **Run consult asynchronously after decomposition with a "compare" step.** REJECTED — would re-introduce the "decomposing blind, auto-correcting during R-G-R" pattern this CL closes.
- **Add an "applicable_rules-only" lightweight consult.** REJECTED — the operator's named gap was about sizing tickets correctly, which requires the full six-question consult. Half-measures wouldn't close the gap.
- **Skip evals at v1 (per Grok's proposal).** ACCEPTED. The plugin's `evals/` directory validates plugin-internal substrate; harness-side evals would need a separate harness. Deferred to a follow-on; trigger: first ticket that gets auto-corrected during R-G-R despite a green consult (i.e., the consult was wrong).

## Consequences

### Positive

- **Decomposition is no longer blind.** Grok consults Claude-TDD-Pro for the technical approach BEFORE sizing tickets. The six questions cover test-shape, decomposition, sequencing, scope, applicable rules, and complexity.
- **Tickets are sized correctly the first time.** Mid-ticket scope expansion (a one-ticket-per-CL violation) becomes structurally rarer because the consult catches it at planning time.
- **`applicable_rules` is now sourced from real analysis** rather than blind language-detection. The consult identifies which rules materially shape each ticket's design.
- **`prior_decisions` becomes structured.** ADR-required scopes, extract-to-value-object opportunities, and explicit-delete entries flow into each ticket's context.
- **Caching keeps the round-trip cheap.** Iterative planning on the same input is a cache hit; the round-trip happens only on genuine input changes.
- **Operator toggle preserves trivial-ticket ergonomics.** One-line fixes don't pay the consult round-trip cost.
- **9th application of the `Second voice` field per ADR-0029.** Grok IS the second voice this time (not the operator); the refinements Grok added are incorporated rather than rejected.
- **R-3 honored.** The consult composes on existing primitives (handoff contract round-trip, SKILL.md trio, dispatch wrapper, active.json registry); no duplication.

### Negative

- **One additional round-trip per feature on cache miss.** Mitigation: cache + operator toggle + the round-trip occurs ONCE per feature (not per ticket). Compared to the cost of mid-R-G-R ticket re-sizing, the latency is a net win.
- **The consult prompt itself can bloat.** Mitigation: the template constrains output to the six questions + the schema; ADR explicitly names "schema bloat" as a risk and the schema as the constraint.
- **Operator may not understand when consult was skipped.** Mitigation: `consult_skipped: true` is visible in the artifact + a WARN line in decomposition; the operator can re-run with the toggle to compare.
- **Pre-emit validation may reject otherwise-valid consults** if `active.json` is stale (a rule was added upstream but the harness hasn't synced). Mitigation: the error code (`unknown_rule`) explicitly directs the operator to re-run `standards-sync.sh`.

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **Plugin pin unchanged** (`23e5c2b` per ADR-0025).
- **Wire-format `schema_version` unchanged** — the consult is a NEW handoff type, not a modification of `.req.json` / `.res.json` schemas.

## Verification (executed before commit)

- `.grok/templates/architecture-consult.md` exists with the six questions, schema, cache contract, system prompt, pre-emit checks, failure modes, operator-visible surfaces.
- `docs/handoff-contract.md` §Architecture-Consult section present with full schema.
- `.grok/templates/decomposition.md` requires `architecture_consult` input + has pre-emit checks naming the consult's `prior_decisions` entries.
- `.gitignore` excludes `.harness/cache/`.
- `./tests/test-all.sh --quiet` passes.
- Full audit chain green (10 audits + smoke-e2e + test-all).
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- ADR-0039 follows the numbered ADR template + `Second voice` field present (9th application; Grok IS the second voice).

## Out of scope (named follow-ons)

- **2-3 harness-side evals for consult quality.** DEFERRED per Grok's proposal — the plugin's `evals/` validates plugin-internal substrate; harness-side evals need their own harness. Trigger: first ticket auto-corrected during R-G-R despite a green consult.
- **README.md / QUICKSTART.md updates** with the new flow diagram. DEFERRED — operator-facing surfaces describe the planning layer at high level; the consult is internal Grok→Claude round-trip, invisible from operator POV on cache hit.
- **Architecture-consult test suite** (`tests/test-architecture-consult.sh`). DEFERRED — the template is descriptive (Grok-prompt-driven), not executable substrate; the schema validation lives in the consult execution itself.
- **`scripts/audit-architecture-consult.sh`** for batch validation of cached consult artifacts. DEFERRED — current cache is per-feature; batch validation triggers when the cache grows.

## Implementation references

- New: `.grok/templates/architecture-consult.md` (6 questions, schema, cache contract, pre-emit, failure modes)
- Modified: `.grok/templates/decomposition.md` (3rd input variable + pre-emit checks + system prompt)
- Modified: `docs/handoff-contract.md` (new §Architecture-Consult section with schema)
- Modified: `.gitignore` (excludes `.harness/cache/`)
- New: this ADR
- Modified: `AUTOMATION_INTEL.md` (2026-06-06 entry recording the gap + Grok's review + the ship)
- Modified: `TICKETS.md` (TICKET-034 row marked DONE)
- Related: ADR-0006 (Grok template trilogy — this CL adds a 4th template upstream of decomposition); ADR-0010 (handoff contract); ADR-0029 (`Second voice` field — 9th application; Grok IS the second voice); ADR-0037 (standards consumption — consult populates `applicable_rules`); ADR-0038 (full plugin-feature wire — this CL closes the planning-layer gap left after TICKET-033).
