# ADR-0023 — Researcher discipline for `host_not_allowed` URLs (TICKET-016)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 direction: *"Persist the solution in order that the problem never blocks work in this repo again."*) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0002 (verification-tier model — this ADR operationalizes its USE); ADR-0003 (T-A capture pattern — referenced as the upper-fidelity branch); composes on `docs/founder-directives.md §1` (the canonical model home) and `docs/architecture-principles.md §19` (ADR amendment process)

## Context

The harness's outbound network policy returns HTTP 403 with `x-deny-reason: host_not_allowed` for several primary-source hosts (observed 2026-05-26: `x.ai`, `x.com`, and intermittently `anthropic.com` paths and `darioamodei.com`). This is the harness's proxy explicitly blocking the host — NOT the upstream server refusing the request.

As of 2026-05-26, six `docs/founder-directives.md §1` sources have hit this blocker: Source 4 (xAI Grok Build announcement), Source 5 (Anthropic Building Effective Agents), Source 6 (Amodei Machines of Loving Grace), Source 7 (Karpathy agentic shift), Source 8 (Anthropic Best Practices for Claude Code — eventually recovered T-A via persistence), and Source 9 (xAI Grok Build Beta canonical docs at x.ai/cli, landing in TICKET-017 per the same direction).

The existing recovery procedure (WebFetch → WebSearch → cross-attribute across ≥ 3 secondary sources → T-C) WORKS. Sources 4 and 5 successfully landed via it. ADR-0002 established the verification-tier MODEL (T-A / T-B / T-C / T-D). But the procedure for USING the model lived only in:

1. ADR-0002's prose (describing the situation in past tense).
2. The verification blocks of individual §1 entries (re-asserting the procedure each time).
3. The architect's session memory + tribal knowledge.

This is a recurring class of problem. Every future researcher (human or agent) had to rediscover the procedure from ADR-0002 archaeology or from imitating prior verification blocks. Per the user's 2026-05-26 direction (*"Persist the solution in order that the problem never blocks work in this repo again"*), the workaround should be extracted into a discoverable, operator-facing rulebook.

Three design questions had to be resolved:

1. **Where does the procedure live?** New TIER-2 doc, extension to existing §1, or new sub-section inside §1?
2. **Should the harness ship an automation script (`scripts/research-fallback.sh`) wrapping the chain?**
3. **What's the cross-source acceptance bar for T-C?** Strict (≥ 3 sources, primary-operated anchor) or lenient (any 2 corroborating quotes)?

## Decision

### 1. New TIER-2 doc `docs/researcher-discipline.md`

The procedure lives in a NEW TIER-2 operational rulebook at `docs/researcher-discipline.md`, joining `docs/quality-gate.md`, `docs/self-healing-design.md`, `docs/cursor-integration.md`, `docs/handoff-contract.md`, `docs/provenance-bridging-design.md` as a sibling.

Rationale:

- **§1 is immutable per D-6.** Adding a procedure sub-section inside `docs/founder-directives.md §1` would be a §1 amendment — forbidden (even though the procedure is metadata, not a source entry, the strict reading of D-6 forbids any §1 edit). A separate TIER-2 doc is the unambiguous path.
- **TIER-2 is the right authority level.** The verification-tier MODEL is foundational (TIER-1 §1 home). The PROCEDURE that operationalizes the model is operational (TIER-2 sibling). The model/procedure separation honors the existing tier discipline.
- **AGENTS.md §5 enumeration is the discovery mechanism.** The new doc joins the existing TIER-2 list; every researcher reading AGENTS.md as session-start context sees the doc; the F-5 audit ensures the `.cursor/rules/agent-context.mdc` regenerated output stays in sync.

### 2. No automation script at v1

Per D-8 (deletion discipline): no `scripts/research-fallback.sh`. The procedure is human-judgment-driven:

- Identifying the block class from `curl -sIL` output requires reading + interpretation.
- Cross-source acceptance bar (≥ 3 sources, primary-operated anchor, reject SEO-spam) requires evaluating source reputation — not a mechanical check.
- Verbatim-phrase recovery from multiple snippets requires recognizing when "the same thing in different words" warrants T-D vs. when "the same exact phrase across sources" warrants T-C.

A script that automated any of these would over-constrain the judgment + introduce false-positive failure modes. The doc + the existing `WebFetch` + `WebSearch` + `Bash` (for header probe) primitives are the right tools.

Future TICKET-016.a could revisit if the procedure proves volatile and script-helpful operationally; explicit deferral.

### 3. Strict cross-source acceptance bar for T-C (≥ 3 sources + primary-operated anchor)

Per the existing Source 4 verification block (which cites 10 secondary sources), the bar in practice has been strict. This ADR codifies the strict bar:

- **≥ 3 indexed secondary sources** quoting the same exact phrase from the primary.
- **At least one primary-operated domain** in the citation chain (`x.ai`, `anthropic.com`, etc.) as the anchor.
- **Reject SEO-spam sites** by editorial reputation.
- **Single-source** OR **single primary-operated source without secondary corroboration** = T-D, not T-C.

Rationale: the verification tier is a load-bearing claim about evidence weight; a lenient T-C threshold would dilute D-12 (production-grade trust). The strict bar matches what Sources 4 + 5 actually did; codifying it prevents future regression.

## Alternatives considered

- **Add a `### Capture procedure when WebFetch is blocked` sub-section to `docs/founder-directives.md §1`.** Rejected per D-6 — §1 is immutable. Even adding a new sub-section IS a §1 edit; the model says "New §1 entries land via ADR" referring to source entries, but a strict reading of immutability forbids any structural change to §1 beyond appending source entries.
- **Extend `docs/grok-orchestration-principles.md` with a research-procedure section.** Rejected. The procedure is cross-tool (applies to Claude Code, Cursor, Grok Build equally) and not specifically Grok-orchestration concerns. Putting it under a Grok-specific rulebook would obscure its cross-tool scope.
- **Bundle the procedure into AGENTS.md itself.** Rejected. AGENTS.md is the cross-tool agent-binding surface (per ADR-0012); it points AT TIER-2 docs but doesn't host TIER-2 content. The model/procedure separation that motivates this doc would be lost.
- **Ship a `scripts/research-fallback.sh` automation script alongside the doc.** Rejected per D-8 + Decision-2. Human judgment is load-bearing for the procedure; over-automation creates false positives.
- **Lenient T-C threshold** (≥ 2 sources, optional primary-operated anchor). Rejected. The bar collapses too easily into "I found two blog posts that said the same thing"; D-12 demands strictness.
- **No `docs/researcher-discipline.md`; just document the workaround inline in ADR-0023 prose.** Rejected per the user's explicit direction: *"Persist the solution in order that the problem never blocks work in this repo again."* ADR prose is harder to discover than a TIER-2 doc enumerated in AGENTS.md §5 + `.cursor/rules/agent-context.mdc`.
- **Edit ADR-0002 to add the procedure.** Rejected. ADRs are append-only by convention (per `docs/architecture-principles.md §19`); editing a prior ADR to add new content is a backward-compatibility hazard. ADR-0023 extends ADR-0002 by reference, not by edit.

## Consequences

### Positive

- **TICKET-016 acceptance criterion met.** TIER-2 doc ships; ADR records the decision; AGENTS.md + generator + cursor rule all updated.
- **The workaround is now persistently discoverable.** Future researchers (human or agent) hitting `host_not_allowed` find the procedure via AGENTS.md §5 enumeration → cursor agent-context rule → direct doc read.
- **Tribal knowledge → codified rulebook.** ADR-0002's prose is preserved as the model's origin; this doc is the model's procedure. Both surfaces remain available; neither replaces the other.
- **Sources 4, 5, 6, 7, 8's verification blocks are RETROACTIVELY anchored** to this doc. Source 9 (TICKET-017) will be the first §1 entry to cite this doc explicitly; subsequent entries can cite by path rather than re-asserting the procedure.
- **Cross-tool: doc applies to Claude Code, Cursor, Grok Build, headless `claude -p` / `grok -p` equally.** The verification-tier model is tool-agnostic; the procedure operates at the research methodology layer, not the agent-orchestration layer.
- **D-12 (production-grade trust) reinforced.** Strict ≥ 3 sources + primary-operated anchor codifies what was previously case-by-case judgment.
- **D-6 (immutability) preserved.** No edits to §1; the procedure lives in TIER-2 where ADR amendment is the proper change path.

### Negative

- **Doc + ADR add Q-DOC-DRIFT surface area.** Mitigation: per §10 verification, audit + cursor-rules-check both clean; AGENTS.md §5 + generator output stay in sync.
- **Researcher judgment is still required.** The doc cannot eliminate the judgment cost of identifying SEO-spam vs. editorial-quality secondary sources; it codifies the BAR but the operator must still evaluate each source. Mitigation: the doc names anti-patterns explicitly; future researchers can quote the anti-patterns as the rejection rationale.
- **Strict bar might block some legitimate T-C entries** where only 2 high-quality secondary sources are available. Mitigation: T-D is always available as a fallback; T-D is honest about the lower evidence weight. Future ADR can revisit the bar if operationally bitten.
- **The doc duplicates structural patterns from `docs/founder-directives.md §1` "Verification tiers used in §1" sub-section.** Mitigation: the duplication is intentional — §1's sub-section is the canonical MODEL; this doc is the procedural OPERATIONALIZATION. R-3 (single source of truth) is honored because the model lives in one place; the procedure is the second concern, not the same content.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **`schema_version` of the handoff contract unchanged.**
- **`scripts/sync-plugin.sh --help` unchanged** (F-4 still passes).
- **No new scripts** at v1 (per Decision-2).

## Verification (executed before commit)

- `test -f docs/researcher-discipline.md`.
- §1–§10 section markers grep-detectable in the new doc.
- ADR-0023 follows the numbered template.
- `AGENTS.md §5` lists `docs/researcher-discipline.md` in the TIER-2 enumeration.
- `scripts/export-cursor-rules.sh` updated to include the new doc in the agent-context.mdc TIER-2 list.
- `.cursor/rules/agent-context.mdc` regenerated.
- `./scripts/export-cursor-rules.sh --check` exits 0.
- `./scripts/audit-doc-drift.sh` exits 0 (F-1..F-6 clean).
- `./scripts/smoke-e2e.sh` exits 0.
- `./scripts/audit-manifest.sh` exits 0.
- TICKETS.md gains TICKET-016 row marked DONE.

## Out of scope (deferred)

- **`scripts/research-fallback.sh` automation script.** TICKET-016.a if operationally bitten.
- **Retroactive update of Source 4 + 5's verification blocks to cite `docs/researcher-discipline.md` by path.** Per D-6, §1 entries are immutable. Future sources cite by path; past sources stay as-is.
- **Cross-tool integration with Grok Build's `/feedback` slash command** (when a §1 source can't be verified, the researcher could route to xAI via `/feedback`). Speculative; defer.
- **Mechanical secondary-source-reputation scoring.** Out of scope per Decision-2; human judgment is load-bearing.
- **`docs/researcher-discipline.md §2` block-class catalog extension** when new block classes appear. The catalog is starter; ADR amendment via `docs/architecture-principles.md §19` extends it.
- **Researcher-discipline checklist item in `docs/founder-directives.md §4` D-checklist.** Defer per D-8 — Q-DOC-DRIFT already covers the audit dimension; per-PR forced re-walk of the discipline doc would inflate the checklist without proportional value.

## Implementation references

- New: `docs/researcher-discipline.md` (TIER-2; 10 sections; ~12 KB)
- Modified: `AGENTS.md §5` (TIER-2 enumeration adds the new doc)
- Modified: `scripts/export-cursor-rules.sh` (`gen_agent_context` TIER-2 list adds the new doc)
- Regenerated: `.cursor/rules/agent-context.mdc` (mirrors AGENTS.md §5 update)
- Modified: `TICKETS.md` (TICKET-016 row marked DONE)
- New: this ADR
- Related: ADR-0002 (verification-tier model — operationalized here), ADR-0003 (T-A capture pattern — referenced as upper-fidelity branch), ADR-0018 (provenance-bridging design — sibling TIER-2 doc; same pattern of "extract tribal knowledge into discoverable rulebook"), ADR-0024 (Source 9 elevation — the first §1 entry to cite this doc; lands in TICKET-017).
