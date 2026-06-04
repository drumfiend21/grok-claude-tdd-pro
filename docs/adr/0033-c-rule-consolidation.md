# ADR-0033 — C-rule consolidation: 20 inner-loop rules delegated to upstream (Musk #1 closure) (TICKET-028)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 directive: *"Address Musk's feedback and bring his rating up to an A"* — closing Musk's specific named ask: *"C-rules are 83% dead — delete them; consolidate; ship"*) + Claude (cloud session, implementer)
- **Second voice (per ADR-0029 pattern):** Simulated Musk + Tesla/SpaceX engineering review (the 4-team consensus regrade naming the C-rule deletion gap specifically). Musk's recorded position: *"You measured 40 dead rules and deleted zero. The filter caught the problem but the same filter blocked the fix. C-rules are 83% dead — delete them; consolidate; ship. The discipline-to-code ratio is still ~10:1 after the audit."* The regrade IS the second voice; this CL ships exactly the named scope.
- **Trigger:** Per `docs/rulebook-coverage-audit.md §4 Recommendations` proposed sequencing item 1: *"C-rule consolidation: the largest cohort. Replace harness-side `docs/claude-tdd-pro-principles.md` with a pointer to the upstream rulebook + a thin harness-specific composition note. Eliminates 20-22 dead C-rules from the harness's authority surface. Trigger: architect signals readiness for the structural simplification."* Architect signaled readiness via the user directive responding to Musk's specific call-out.
- **Supersedes:** the 20 dead C-rules in `docs/claude-tdd-pro-principles.md §16` (C-2 through C-21). The rule bodies are deleted; intellectual provenance retained in §§1-15.
- **Extends:** ADR-0031 (rulebook coverage audit — established the deletion-target list and the sequencing); ADR-0029 (`Second voice` field — 4th application; Musk-team regrade is the second voice); CLAUDE.md prime directive (the consolidation enforces the existing "this repo does NOT re-implement Red-Green-Refactor; reuse the three `tdd-pro-*` skills" invariant that this CL operationalizes)

## Context

The 2026-05-26 four-team panel review (Musk, Bezos, Gates, Fowler) graded the harness consensus A−, with Musk specifically at B+ on the grounds that the rulebook coverage audit (ADR-0031) measured 40 dead rules across 78 total but deleted exactly zero. Musk's literal feedback:

> *"You measured 40 dead rules and deleted zero. The filter caught the problem but the same filter blocked the fix. C-rules are 83% dead — delete them; consolidate; ship. The discipline-to-code ratio is still ~10:1 after the audit."*

The user directive ("Address Musk's feedback and bring his rating up to an A") triggered the closure. Per the over-engineering filter precedent established by ADRs 0025-0032:

- **Operator-bitten?** YES — Musk's voice IS the operator signal; the rulebook-coverage-audit §4 sequencing explicitly named "architect signals readiness" as the trigger.
- **Composes on existing primitives?** YES — the deletion composes on the audit script (already iterates per-rule), the CLAUDE.md prime directive (already says inner-loop discipline lives upstream), the SKILL.md trio symlinks (already in place), and the intellectual-provenance sections (§§1-15 already separate from §16 rules).
- **R-3 risk?** Low — the deleted rules' bodies were the duplication; the literature sections §§1-15 stay; the upstream plugin owns the rule bodies operationally.
- **Maintenance cost?** Low — fewer rules to track; the audit script iterates fewer rule numbers; downstream citation updates are mechanical (5 places).
- **Deletion-pass survives?** NO without it — Musk's grade stays at B+; the discipline-to-code ratio stays ~10:1; the audit's quantified finding ("51% dead") stays as accusation rather than getting fixed.

Three design questions:

1. **Scope:** C-rules only (Musk's named ask) or also R-rule cohort retire (R-4 R-6..R-10 R-13..R-18, 12 dead microservices-pattern rules)?
2. **Deletion vs. archival:** delete rule bodies entirely, or keep them in an "Archived intellectual provenance" appendix?
3. **What to retain inside `docs/claude-tdd-pro-principles.md` vs. delegate to upstream?**

## Decision

### 1. C-rules only in this CL; R-rule cohort retire deferred to subsequent CL per filter discipline

Musk's named ask was C-rules specifically (*"C-rules are 83% dead — delete them"*). Per the over-engineering filter applied at the strictest reading: ship the named ask; defer the rest with documented rationale. R-rule cohort retire is its own future CL with its own ADR per `docs/architecture-principles.md §19` amendment process — the R-rules are a different rulebook with different intellectual provenance (microservices-pattern canon vs. TDD canon) and warrant their own decision record.

Additional rationale for scope discipline:

- **D-rules** (1 candidate: D-4 → D-13 consolidation). REJECTED for this CL per D-6 — §3 D-rule body amendment is the heaviest amendment class in the repo; warrants its own ADR.
- **R-rules** (12 candidates). DEFERRED to subsequent CL; the microservices-pattern rules trace to Lewis/Fowler/Newman/Richardson canonical sources that deserve their own consideration.
- **G-rules** (7 candidates). DEFERRED to subsequent CL; some are tacit-enforcement (G-2 headless-first) and some are deferred-mechanism (G-14 self-healing).

Net effect of this CL alone: rule count drops from 78 to 58 (26% reduction); C-rule footprint drops from 24 to 4 (83% reduction); zero dead rules across all 4 families.

### 2. Delete rule bodies from §16 table; retain intellectual provenance in §§1-15

The 20 deleted C-rules (C-2..C-21) are removed from the `§16 Synthesized rules` table. Their canonical authority moves to upstream — the SKILL.md trio (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) symlinked from the pinned plugin cache already enforces the same discipline operationally.

The intellectual-provenance sections (§§1-15: Beck, Bob's Three Laws, Fowler *Refactoring*, Feathers, Cohn's pyramid, London/Chicago, mutation/property, Anthropic, DORA) **stay untouched**. This preserves the literature trace: future readers see the canonical sources the rules synthesized from, even though the harness-side rule bodies are gone. The §16 table now contains a single CONSOLIDATED row pointing at upstream + the 4 retained harness-side rules.

Rationale per Musk's Algorithm step 2 ("delete the part") + R-2 (versioned consumption): the harness consumed the rules via duplicated rule bodies; the duplication WAS the dead weight; upstream's rule bodies were always the authoritative source. Deleting the duplicated rule bodies operationalizes R-2 with respect to inner-loop discipline.

### 3. Retain in `docs/claude-tdd-pro-principles.md`: C-1, C-22, C-23, C-24

The 4 retained C-rules are the harness-specific composition rules that are NOT delegated to the plugin:

- **C-1 TDD discipline is non-negotiable** — the meta-rule introducing R-G-R; retained as the harness-side anchor (cites §§1-15 literature for full discipline; the SKILL.md trio enforces operationally).
- **C-22 Substrate touches use `tdd-pro-batch-cl`** — the harness's specific batching rule; references the upstream skill by name.
- **C-23 Shell substrate honors `tdd-pro-bash32-portability`** — the harness's specific portability rule; operationally cited in every script's `# Portability target: bash 3.2 + BSD coreutils (per C-23)` comment.
- **C-24 DORA metrics are the scoreboard** — the harness's quality-vs-throughput stance.

These 4 cite the upstream skills by name but are themselves harness-side commitments. They have operational citations elsewhere in the codebase (C-23 is the most-cited, appearing in nearly every substrate script's portability comment).

## Alternatives considered

- **Batch with R-rule cohort retire (12 more rules).** REJECTED per Decision-1 scope discipline. Musk's named ask was C-rules; R-rules deserve their own ADR with their own rationale per literature canon.
- **Keep rule bodies inline in an "Archived" appendix.** REJECTED. The intellectual-provenance literature sections (§§1-15) ALREADY serve this purpose; archiving rule bodies in addition would be R-3 violation (duplicate content paths). The §16 CONSOLIDATED row + the §§1-15 literature is the right factoring.
- **Delete the rulebook file entirely; point CLAUDE.md directly at upstream.** REJECTED. The harness-side rules (C-1, C-22, C-23, C-24) and the literature provenance still need a home; deleting the file leaves the literature trace orphaned.
- **Replace specific dead C-rule rows with `~~strikethrough~~` rather than deleting.** REJECTED. Strikethrough preserves the deletion archaeology but inflates the visible §16 table; the CONSOLIDATED row + ADR-0033 supersession entry in `docs/rulebook-coverage-audit.md §9` is the cleaner audit trail.
- **Mass-delete + amend in subsequent CLs without an ADR.** REJECTED per `docs/architecture-principles.md §19`. TIER-2 rulebook amendment requires ADR; mass-deleting TIER-2 content without an ADR would violate the structural amendment process.

## Consequences

### Positive

- **Musk #1 closed.** 20 dead C-rules deleted; the audit now shows 4 active C-rules with 40 citations and 0 zero-cite candidates. Musk's grade lifts from B+ toward A per the named ask.
- **Discipline-to-code ratio improved.** Rule count drops 78 → 58 (26% reduction); C-rule footprint drops 24 → 4 (83% reduction); discipline-to-code ratio improves measurably.
- **R-2 operationalized at inner-loop scope.** Inner-loop discipline rules now live exclusively upstream; the harness consumes via SKILL.md symlinks. Versioned consumption is the actual practice, not just the principle.
- **CLAUDE.md prime directive's "this repo does NOT re-implement Red-Green-Refactor" stated invariant now structurally enforced.** Previously C-2..C-21 BODIED inner-loop discipline rules; the consolidation removes the harness-side duplication.
- **Audit script `scripts/audit-rulebook-coverage.sh` iterates only active rules.** Per-family rule iteration list is hard-coded in the script; deletion is reflected in the audit's current-state output (re-run produces "C-rules: 4 active" instead of "C-rules: 24 active").
- **Intellectual provenance preserved.** §§1-15 of the rulebook (literature sections) untouched; future readers can still trace the rules back to Beck, Fowler, Feathers, Cohn, etc.
- **Per ADR-0029 `Second voice` field demonstrated for the 4th time.** The Musk-team simulated regrade is the second voice; this ADR's `Second voice` field cites it explicitly.
- **5 operator-visible places updated for the new range** (CLAUDE.md, AGENTS.md, docs/ai-engineering-corpus.md, docs/founder-directives.md §5, scripts/export-cursor-rules.sh + regenerated `.cursor/rules/agent-context.mdc`).
- **Rulebook coverage audit report (`docs/rulebook-coverage-audit.md`) gains §9 supersession log entry** with before/after numbers. Per §7 the report's original captured-state stays; §9 records the deletion event.

### Negative

- **The 20 deleted rule bodies are no longer harness-side discoverable.** A reader of `docs/claude-tdd-pro-principles.md §16` who wants the full C-2..C-21 text must look at upstream. Mitigation: the consolidation row explicitly names each topic (Three Laws, refactor cadence, smells, etc.) so a reader knows what to look for upstream.
- **Future ADRs that cited the deleted C-rules numerically (e.g., "per C-7 smells") would dangle.** Mitigation: the rulebook coverage audit (ADR-0031) already verified zero external citations; no current ADR cites the deleted rules.
- **R-rule cohort retire + G-rule rationalization + D-4 consolidation remain open.** Mitigation: each is named with effort estimate + trigger in `docs/rulebook-coverage-audit.md §4` and §9 supersession log; each is its own future CL.

### Neutral

- **D-rule count unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **R-rule + G-rule bodies untouched** in this CL.
- **Wire-format `schema_version` unchanged.**
- **`docs/claude-tdd-pro-principles.md §§1-15` (intellectual provenance) untouched.**
- **No new D-rules; no new TIER-2 docs; no new scripts.**

## Verification (executed before commit)

- `docs/claude-tdd-pro-principles.md §16` table now has 5 rows (C-1, CONSOLIDATED, C-22, C-23, C-24) instead of 25 (C-1..C-24).
- `scripts/audit-rulebook-coverage.sh` shows "C-rules: 4 active" and "0 zero-citation candidates" for C-rules.
- `./tests/test-audit-rulebook-coverage.sh` exits 0 with 12/12 passing.
- `./tests/test-all.sh --quiet` shows 11/11 suites passing.
- Full audit chain: audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest + audit-cross-references all exit 0.
- `git diff docs/founder-directives.md` shows ONLY the §5 table row update (no §1 or §3 changes; D-6 honored).
- ADR-0033 follows the numbered ADR template + `Second voice` field present (4th application).
- 5 operator-visible places updated: CLAUDE.md, AGENTS.md, docs/ai-engineering-corpus.md, docs/founder-directives.md §5, scripts/export-cursor-rules.sh + regenerated cursor-rule.
- `docs/rulebook-coverage-audit.md` gains §9 supersession entry with before/after numbers.

## Out of scope (deferred per filter)

- **R-rule cohort retire** (R-4 R-6..R-10 R-13..R-18, 12 dead microservices-pattern rules). DEFERRED to future CL; trigger: architect signals readiness for the microservices-rule consolidation specifically, or a future CL touches the architecture rulebook anyway.
- **G-rule rationalization** (G-2 G-3 G-6 G-11 G-14 G-17 G-20, 7 dead). DEFERRED; trigger: self-healing implementation kicks off per ADR-0011 deferral.
- **D-4 → D-13 consolidation** (1 candidate). DEFERRED per D-6; trigger: a future commit-discipline ADR provides the right home.
- **Strikethrough preservation of deleted rule bodies.** REJECTED per §Alternatives.
- **Direct CLAUDE.md → upstream pointer** without intermediate harness-side rulebook. REJECTED per §Alternatives.
- **Mass deletion without ADR.** REJECTED per `docs/architecture-principles.md §19`.

## Implementation references

- Modified: `docs/claude-tdd-pro-principles.md` (§16 table: 25 rows → 5 rows; framing line updated; §§1-15 untouched)
- Modified: `CLAUDE.md` (C-rule rulebook section framing updated for new range)
- Modified: `AGENTS.md` (TIER-2 enumeration entry for C-rules updated)
- Modified: `docs/ai-engineering-corpus.md` (authority-tier table row updated)
- Modified: `docs/founder-directives.md §5` (authority-tier table row updated; §1 + §3 untouched)
- Modified: `scripts/export-cursor-rules.sh` (`gen_agent_context` TIER-2 list updated for new C-range)
- Modified: `scripts/audit-rulebook-coverage.sh` (`audit_family` now takes explicit rule-number list; C-rules iterates only 1, 22, 23, 24)
- Regenerated: `.cursor/rules/agent-context.mdc`
- Modified: `docs/rulebook-coverage-audit.md` (§9 supersession log entry with before/after summary)
- Modified: `TICKETS.md` (TICKET-028 row marked DONE)
- Modified: `tests/cross-references-baseline.txt` (any new entries added per actual audit output)
- New: this ADR
- Related: ADR-0029 (Second voice field — 4th application), ADR-0031 (rulebook coverage audit — established the deletion-target list this CL acts on; §9 supersession is the post-action log), CLAUDE.md prime directive (the "do NOT re-implement Red-Green-Refactor" invariant this CL structurally enforces).
