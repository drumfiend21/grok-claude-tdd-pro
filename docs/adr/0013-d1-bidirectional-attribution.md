# ADR-0013 — D-1 bidirectional attribution (TICKET-011)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed" instruction on the reconciled TICKETS-011-014 plan) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** `docs/founder-directives.md §3 D-1` (Grok-side primitives cite their Claude / Cursor analog); composes on `docs/founder-directives.md §4` (the pre-commit self-audit checklist)

## Context

D-1 (`docs/founder-directives.md §3`, lines 688–694) reads in part: *"The harness's job is to make Grok composable with the patterns observed in enterprise deployments of Claude Code and Cursor, not to reinvent orchestration in a vacuum."* The §4 checklist item D-1 reads: *"If a new Grok-side primitive was added, its Claude Code and/or Cursor analog is documented in the PR description or an accompanying ADR."*

The checklist item is correct but unidirectional. It catches the case where a `.grok/` template, monitor, or system prompt was added without attribution to a Claude Code / Cursor pattern it was modeled on. It does NOT catch the symmetric case: a Cursor-side primitive (`.cursor/rules/`, `.cursor/commands/`, AGENTS.md surface) or a Claude Code-side primitive (`.claude/hooks/`, `.claude/skills/` wiring, `CLAUDE.md` section) was added without attribution to the Grok analog (or rationale for absence).

TICKETS 011–014 ship four such Cursor-side primitives (AGENTS.md, four `.cursor/rules/*.mdc` files, seven `.cursor/commands/*.md` files, the `docs/cursor-integration.md` design doc). Without a symmetric reading of D-1, those primitives could land without any pointer back to the Grok / Claude Code patterns they compose on — a structural drift away from D-1's "no reinvention in a vacuum" intent.

Two open questions:

1. **Edit D-1's existing §4 checklist item, or add a parallel item?** Editing the existing item compresses both directions into one bullet; adding a parallel item keeps the original (Grok→Claude/Cursor) intact and makes the reverse direction (Claude/Cursor→Grok) visible.
2. **Does this require a §3 D-rule body amendment?** §3 D-1's body already names *"the patterns observed in enterprise deployments of Claude Code and Cursor"* — bidirectionality is implied by the bidirectional pattern landscape; the §3 body does not need editing.

## Decision

### 1. Add a parallel §4 checklist item; do NOT edit existing D-1 item

The existing D-1 §4 item remains untouched:

> `[ ] (D-1) If a new Grok-side primitive was added, its Claude Code and/or Cursor analog is documented in the PR description or an accompanying ADR.`

A new parallel item is added immediately after:

> `[ ] (D-1 reverse, ADR-0013) If a new Cursor-side or Claude Code-side primitive was added, its Grok analog (or rationale for absence) is documented in the PR description or an accompanying ADR. Symmetric reading of D-1 per ADR-0013.`

Rationale: editing the existing item would lose the historical phrasing (which is the canonical statement of D-1's forward direction). Adding a parallel item makes both directions independently checkable in code review; either can fail without ambiguity about which direction broke.

### 2. No §3 D-rule body amendment

D-1's §3 body (lines 688–694) already references the bidirectional pattern landscape (*"the patterns observed in enterprise deployments of Claude Code and Cursor"*). The forward direction was the only one operationally bitten at the time §3 was written (Grok-side primitives were the additive surface); now that Cursor-side and Claude Code-side primitives are being added in TICKETS 011-014, the reverse direction becomes operationally bitten and merits a checklist item. The §3 body still reads correctly without amendment, and per D-6 *"§3 D-rule bodies are TIER 1; amendments only via ADR"* is preserved (this ADR adds a §4 checklist item, not a §3 body amendment).

### 3. Cross-tool attribution standard

The standard for "analog is documented" applies symmetrically in both directions:

- **Grok→Claude/Cursor (forward D-1).** Example: `.grok/templates/research.md:5` *"Drawn from (per D-1): Cursor's ask-mode context gather."* Example: `.grok/templates/decomposition.md:5` *"Drawn from (per D-1): Cursor's compose mode (multi-edit plan)."*
- **Cursor/Claude→Grok (reverse D-1).** Example: `.cursor/commands/research.md` (TICKET-014) should cite the `.grok/templates/research.md` pattern it composes on. Example: `.cursor/rules/agent-context.mdc` (TICKET-013) should cite the `.claude/hooks/session-start.sh` pattern it mirrors.

The attribution lives in the file itself (header line or front-matter), in the PR description, or in the accompanying ADR — operator preference. The §4 checklist item is satisfied by any of the three.

## Alternatives considered

- **Edit the existing D-1 §4 item to be bidirectional in a single bullet.** Rejected. Compresses two operationally distinct checks into one; reviewer ambiguity ("which direction failed?") would arise. Two parallel bullets are mechanically clearer.
- **Amend the §3 D-1 body to add bidirectional phrasing.** Rejected. §3 body already implies the bidirectional landscape; explicitly adding "and the reverse" would be redundant with the body's existing language. D-6 prefers minimal §3 edits.
- **Defer bidirectional attribution to a future ADR after TICKETS 011-014 ship.** Rejected. The four new Cursor-side primitives in TICKETS 011-014 would land without the checklist enforcement, then need retroactive ADR pointer additions when the rule finally landed. Shipping ADR-0013 alongside TICKET-011 puts the rule in place before the primitives are written.
- **No new rule — handle attribution case-by-case in code review.** Rejected per D-12 (production-grade trustability requires structural, not aspirational, mechanisms). A checklist item is a structural enforcement point; ad-hoc review is not.
- **Generate the attribution table mechanically from a manifest.** Rejected per D-8 (delete the part). No manifest exists today; building one to enforce a checklist is over-engineering. The text attribution standard is sufficient at v1.

## Consequences

### Positive

- **TICKETS 012-014's Cursor-side primitives have a structural attribution requirement.** Every `.cursor/rules/*.mdc`, every `.cursor/commands/*.md`, and `docs/cursor-integration.md` itself must cite either a Grok analog or rationale for absence. This keeps D-1's "no reinvention in a vacuum" intent honored as the harness grows new surfaces.
- **§4 checklist gains structural symmetry.** D-1 (forward) and D-1 reverse (parallel item) are independently checkable; neither can be silently relaxed without a reviewer noticing.
- **§3 D-rule bodies remain untouched.** D-6 is honored; the §3 D-1 body is the original §1-derived statement.
- **The attribution standard is operator-facing, not buried in tooling.** Reviewers can audit attribution by reading the file header or PR description; no manifest lookup required.

### Negative

- **§4 checklist gains one item, marginally lengthening the pre-commit review.** Mitigation: the new item is parallel to an existing item; reviewers familiar with D-1 will recognize it immediately. The cost is well below the value of catching reverse-direction reinvention.
- **The reverse-direction attribution sometimes has no analog** (e.g., a Cursor-specific surface like `.cursor/rules/agent-context.mdc` is a Cursor-specific mechanism with no exact Grok analog). Mitigation: the checklist item explicitly accepts "(or rationale for absence)" — documenting the absence is itself a valid pass.
- **Existing Grok-side files written before this ADR may have weaker attribution standards than the reverse-direction items now mandate.** Mitigation: not retroactive. The checklist applies to commits landing after this ADR. Existing files are unchanged.

### Neutral

- **D-rule count unchanged.** No new D-rule; this ADR adds a §4 checklist item under D-1's authority.
- **TIER-0 corpus untouched.**
- **`schema_version` of the handoff contract unchanged.**
- **D-1's §3 body untouched per D-6.**

## Verification (executed before commit)

- `grep -q 'D-1 reverse, ADR-0013' docs/founder-directives.md` exits 0.
- `grep -q '^- \[ \] (D-1)' docs/founder-directives.md` exits 0 (original D-1 item preserved).
- D-1's §3 body (lines 688–694 region) byte-identical to pre-CL state.
- §1 provenance entries untouched (`git diff` on §1 shows zero changes).
- `./scripts/audit-doc-drift.sh` exits 0.
- ADR-0013 references ADR-0012 (sibling, same CL) and the existing D-1 checklist item.
- AGENTS.md (ADR-0012's deliverable) honors the new D-1 reverse item: its "Composition + provenance" trailer cites `docs/grok-orchestration-principles.md §8` as the G-rule it composes on.

## Out of scope (deferred)

- **Mechanical attribution audit.** A future ADR could add an F-pattern to `audit-doc-drift.sh` that grep-checks every new `.cursor/` file for an attribution line. Deferred per D-8; manual reviewer enforcement is sufficient at v1.
- **Symmetric §4 items for other directives** (D-2 reverse, D-11 reverse, etc.). Deferred. D-1 reverse is uniquely operationally bitten by TICKETS 011-014's Cursor-side primitives; other reverses can be added when operationally bitten.
- **Retroactive attribution audit of pre-ADR-0013 files.** Not retroactive per "Consequences/Negative" above.

## Implementation references

- Modified: `docs/founder-directives.md §4` (one new parallel checklist item under D-1)
- New: this ADR
- Related: ADR-0012 (AGENTS.md as cross-tool surface — the sibling ADR in the same CL), `docs/founder-directives.md §3 D-1` (the §3 body that this ADR's checklist item operationalizes bidirectionally), `.grok/templates/research.md:5` + `.grok/templates/decomposition.md:5` (existing forward-direction attribution examples).
