# ADR-0010 — Quality-gate v1 specification (per-CL "green" contract)

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, "Proceed" instruction per the existing ticket plan) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0008 (smoke script — the smoke is what enforces this gate end-to-end in stub mode); composes on the plugin's `architecture-v1.9.md §2.1 Rubric rule schema` (severity enum) and `§2.8 AI Provenance Manifest` (provenance gate inspiration)

## Context

TICKET-007's acceptance criterion was "Single-page doc; reviewer can checklist against it." The deliverable is `docs/quality-gate.md`, which formalizes the `quality_gate` object that already exists as a contract surface in `docs/handoff-contract.md`. Three open questions had to be resolved before the doc could be written:

1. **Should the existing three fields (`tests_must_pass`, `coverage_delta_min`, `lint_clean`) keep their current names, or be renamed to align with the plugin's `§2.1 Rubric rule schema`?** The plugin uses `severity` / `rule_state` / `deprecated` terminology; the harness's gate uses domain-specific boolean field names. Renaming would force a schema_version bump on a doc-only CL.
2. **Should a new sub-gate be added, or only the three be formalized?** The audit found no documented requirement for provenance enforcement, but the `decision_trail_ref` field has been treated as a required artifact (the smoke script writes one; the trail filename is referenced from the response). This implicit requirement deserves an explicit gate name.
3. **Where does the doc sit in the authority hierarchy?** TIER 0 is the corpus; TIER 1 is the prime directive + founder-directives; TIER 2 is the R/G/C rulebooks. Quality-gate is rulebook-level (composes on those rulebooks, sets per-CL bar).

## Decision

### 1. Keep existing field names; do NOT bump schema_version

The existing three fields (`tests_must_pass`, `coverage_delta_min`, `lint_clean`) stay. Reasons:

- They are domain-specific (test/coverage/lint), readable, and stable. The plugin's `severity` / `rule_state` enums describe rule classification — a different concept (which rule applies vs. whether a per-CL gate passes).
- A rename would force `schema_version = "2"` on a doc-only CL, requiring lockstep updates in `dispatch.md`, `smoke-e2e.sh`, and any future consumer. Per Musk's Algorithm step 2 (delete before optimize), the rename's value is ~zero and its cost is real.
- The plugin's enums ARE borrowed where they apply: `severity: P0 | P1 | P2` for sub-gate classification, `deprecated: true` for lint-rule exemption semantics. These are cited by name in `quality-gate.md §"Cross-references"`, not duplicated.

### 2. Add `provenance_complete` as a recommended (additive) fourth sub-gate

A fourth sub-gate is named: `provenance_complete`. It is **additive** at schema_version=1 (tolerant reader path per R-11) — consumers that don't recognize the field MUST ignore it without error; requestors MAY omit it; the dispatch template DOES NOT inject it by default. Promotion to required-at-v2 lands via a future ADR.

Rationale:

- The harness already produces a `decision_trail_ref` artifact (per ADR-0008). The field is referenced from the response and points at a real file. Making the existence + structure of that trail an explicit gate formalizes what was already required de facto.
- It is the natural composition point with the plugin's `§2.8 AI Provenance Manifest`. The harness's trail is a minimum-viable subset (just the R-G-R narrative); the plugin's manifest is the per-commit signature. Both can coexist.
- Naming it now (recommended) lets `quality-gate.md` document the full picture; promoting it later (required) is a follow-on ADR that bumps `schema_version`.

### 3. Place the doc at TIER 2, rulebook-level

`quality-gate.md` joins the existing TIER 2 rulebooks: `architecture-principles.md` (R-1..R-20), `grok-orchestration-principles.md` (G-1..G-21), `claude-tdd-pro-principles.md` (C-1..C-24). Quality-gate has no numbered rules of its own — it has sub-gates and checklist items, which is a different format because the per-CL gate is point-in-time rather than principle-set. The authority tier is the same.

Amendments follow `architecture-principles.md §19` (ADR process). Schema_version bumps that affect the wire format land per R-5 (bilateral) in one CL touching all three sites named by `dispatch.md`.

### 4. Reviewer checklist is the deliverable's binding artifact

The "Done when" column reads: "reviewer can checklist against it." Each sub-gate in the doc ships its own reviewer checklist. There is also a cross-cutting integrity-check section that applies to every response (scope, freshness, schema, idempotency). A human reviewer can apply these checklists to any `.res.json` and decide whether `status: "green"` was earned.

## Alternatives considered

- **Define entirely new sub-gate names aligned to `§2.1` enums.** Rejected per Decision 1. Cost > value.
- **Skip `provenance_complete`; let the trail file remain implicit.** Rejected. The harness already produces the trail; not naming it leaves a gap where future maintainers could "succeed" by emitting a `decision_trail_ref` that points at nothing.
- **Make `provenance_complete` required-at-v1 immediately.** Rejected. Would break existing consumers (the smoke script's stub-mode response doesn't set the field; it would have to be updated lockstep, with no functional improvement). Tolerant-reader path is cleaner.
- **Make `quality-gate.md` a TIER 1 document.** Rejected. TIER 1 is prime directive + founder-directives, which are *directive* (do-this) authority. Quality-gate is *gate-evaluation* authority — same tier as the other rulebooks.
- **Include mutation testing / property-based testing as v1 sub-gates.** Rejected per Musk's Algorithm step 1 (question requirements). The harness has never enforced mutation testing; making it required at v1 would block live-Claude work on most real projects until they adopted Stryker / Hypothesis. The "Out of scope (deferred)" section names these as future-ADR work.
- **Combine quality-gate + handoff-contract into one document.** Rejected per R-3 (single source of truth — but applied at field granularity). The wire format and the per-field semantics are different concerns; separating them lets each evolve at its own cadence.

## Consequences

### Positive

- **TICKET-007 acceptance criterion met.** Single-page (~5KB), reviewer can checklist against it. The reviewer's job for every `.res.json` is now mechanical: walk the four sub-gate checklists + the cross-cutting section.
- **The "what does 'green' mean" question is closed at schema_version=1.** Future CLs that produce `.res.json` documents have an authoritative reference for what they must satisfy.
- **Plugin contracts are composed on, not duplicated.** `§2.1` severity enum and `§2.8` provenance manifest are cited; their authoritative files remain the source. R-3 honored.
- **`docs/handoff-contract.md` line 58's future-tense "TICKET-007 will formalize" is gone.** That's a known drift pattern (F-3 in the audit script); closing it as part of TICKET-007 keeps the doc-drift audit clean.
- **`provenance_complete` field is named but additive.** Live consumers don't break; future schema_version=2 promotion is well-flagged.

### Negative

- **Three sub-gates have "tooling-absent" exemptions.** Coverage and lint vacuously pass when tooling is absent (true today on the toy module). This means a project can claim "green" with zero coverage and zero lint enforcement — which is exactly the bar the toy passes. Mitigation: the response notes MUST document the exemption; the reviewer checklist explicitly checks for the documentation. When real-Claude mode runs on real projects, real tooling will be present.
- **Reviewer checklists are human-applied, not machine-checked.** A future CL could mechanize parts of this (validate `.res.json` against the checklist, error if claimed `green` with a missing trail). Defer until there's a real consumer (TICKET-008 self-healing extension is the likely first).
- **The "P0 / P1 / P2" severity labels were borrowed from `§2.1` but mapped to per-gate decisions.** The plugin uses these labels for rule classification (how often the rule fires, what severity per fire). The harness uses them for sub-gate weighting (which gate is binary-blocking vs. relaxable). Same labels, related-but-distinct semantics. Documented in `quality-gate.md §"Cross-references"` to avoid confusion.
- **The doc references plugin sections by their `§2.X` numbers.** If the plugin's section numbering changes (it's at v1.9 now; a future v2.0 could renumber), the cross-references go stale. Mitigation: the references include both the §-number AND the section title, so a future grep can find the renamed section.

### Neutral

- D-rule count unchanged. §1 of `docs/founder-directives.md` untouched.
- TIER-0 corpus untouched.
- `schema_version` stays at `"1"`. The dispatch template's `quality_gate` injection defaults unchanged.
- `scripts/audit-doc-drift.sh` Q-DOC-DRIFT-applied to this CL: `handoff-contract.md` was the only doc whose surface this CL changed (line 58 reference), and it was updated in the same CL.

## Verification (executed before commit)

- `docs/quality-gate.md` exists and is single-page (renders in one GitHub view; reviewable in one sitting — measured 182 lines, ~13KB at commit time).
- Four sub-gate sections each have: definition, severity classification, override policy, reviewer checklist.
- Cross-cutting integrity-check section present with four items (scope, freshness, schema, idempotency).
- "What this contract does NOT cover" section names ≥ 5 deferred items + future-ADR path.
- "Cross-references" section names `§2.1`, `§2.8`, `§2.11` from the plugin's architecture, composing on rather than duplicating.
- `docs/handoff-contract.md:58` no longer reads "TICKET-007 will formalize"; it now points at `quality-gate.md`.
- `./scripts/audit-doc-drift.sh` exit 0 (no F-1/F-2/F-3/F-4 patterns introduced; F-3 closed).
- `./scripts/smoke-e2e.sh` exit 0 (the smoke's stub-mode response satisfies the four-sub-gate checklist when manually evaluated).

## Out of scope (deferred, named)

- **Mutation testing sub-gate.** Future ADR. The plugin's `claude-tdd-pro-principles.md §C-22` is the upstream lineage.
- **Property-based testing sub-gate.** Future ADR.
- **Performance / bundle-size / type-check sub-gates.** Future ADRs.
- **Cross-CL aggregate metrics (DORA, SPACE).** Adjacent to but outside the per-CL gate. The plugin's `§2.11 SPACE metric schema` covers reporting; per-CL gate is point-in-time.
- **Mechanized response validation against the checklist.** Defer until TICKET-008 (self-healing extension) gives the response validator a real consumer.
- **schema_version=2 promotion of `provenance_complete` to required.** Lands when there is a concrete need (likely TICKET-010 provenance bridging or earlier).

## Implementation references

- New: `docs/quality-gate.md`
- Updated: `docs/handoff-contract.md` (line 58 reference)
- Updated: `TICKETS.md` (TICKET-007 → DONE)
- This ADR
- Composes on: `claude-tdd-pro/docs/architecture-v1.9.md §2.1`, `§2.8`, `§2.11` (cited, not duplicated)
- Related: ADR-0008 (smoke script — the stub-mode response is currently the only consumer of this gate spec)
