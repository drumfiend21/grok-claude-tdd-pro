# ADR-0015 — Cursor as host IDE (TICKET-012)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed" instruction on the reconciled TICKETS-011-014 plan) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0012 (AGENTS.md as cross-tool surface — this ADR builds the Cursor-specific operational rulebook on top of the cross-tool enumeration); composes on `docs/founder-directives.md §1 Source 1` (the @teslayoda 2026-05-24 X post naming Cursor inside Marcohard); `docs/grok-orchestration-principles.md §8` (G-rule that mandates AGENTS.md as the cross-tool surface)

## Context

`docs/founder-directives.md §1` Source 1 (line 15, T-B, immutable) is the founder's explicit directive: *"Grok Build should watch and learn from Claude Code and Cursor inside Marcohard."* — @teslayoda, 2026-05-24. Cursor is named as a peer to Claude Code as the enterprise IDE the harness must compose with.

`AGENTS.md` (TICKET-011 / ADR-0012) ships the cross-tool *enumeration* — which surfaces exist, where authority lives, what commands to run, what the file-edit fences are. It is flat, pointer-only, and equally applicable to Cursor / Codex / Amp / Jules / Factory / Grok Build.

`AGENTS.md` does NOT explain *how* a developer working inside Cursor specifically drives the harness — which Cursor surface (chat agent, compose mode, terminal, `.cursor/rules/`, `.cursor/commands/`) maps to which harness feature, what the session-start ritual looks like under Cursor's architectural model (always-loaded rules, no push-hook), how the inner-loop driver decision (Cursor's chat agent vs. headless Claude Code) plays out, what failure modes are specific to the Cursor surface, and how TICKETS 013-014 materialize the remaining Cursor-specific primitives. That gap is what `docs/cursor-integration.md` fills.

Three design questions had to be resolved before this doc could be written:

1. **Cursor's position in the operator stack.** Is Cursor a peer to Claude Code (parallel consumer), or the host IDE that runs Claude Code / Grok / the harness substrate underneath?
2. **Doc scope: a single Cursor operational rulebook, or an extension to existing rulebooks?** Does Cursor-specific operator knowledge get distributed across `docs/grok-orchestration-principles.md`, `docs/claude-tdd-pro-principles.md`, and `AGENTS.md`, or does it warrant its own consolidated doc?
3. **Doc authority tier.** Cursor-integration sits where in the TIER-0 / TIER-1 / TIER-2 hierarchy?

## Decision

### 1. Cursor is the host IDE at the top of the operator stack

`docs/cursor-integration.md §2` documents the operator stack: developer → Cursor IDE → outer-loop templates → handoff contract → inner-loop SKILL.md → handoff response → quality gate → commit. Cursor sits at the **top** of the stack, above the harness substrate (Grok-templated outer loop, Claude-skilled inner loop). Cursor's chat agent, compose mode, terminal, and git surface are the operator surfaces; everything underneath is unchanged by Cursor's presence.

This framing is a reconciliation of an earlier plan iteration that positioned Cursor as a *parallel consumer* (i.e., a peer to Claude Code that the developer might use *instead of* Claude Code). The corrected framing per the user's 2026-05-25 redirect: Cursor IS the developer's editor; Claude Code / Grok / the harness primitives run UNDER Cursor; the surfaces in `.cursor/rules/` and `.cursor/commands/` (TICKETS 013-014) are how the developer drives the harness from Cursor's cockpit.

The harness's two-tier loop (outer / inner) and its quality gate, handoff contract, and skill discipline are unchanged. Cursor adds a new top-of-stack operator interface; it does not change the substrate.

### 2. Single consolidated Cursor operational rulebook (`docs/cursor-integration.md`)

A new TIER-2 operational rulebook lives at `docs/cursor-integration.md`. It indexes every harness feature against its Cursor surface (§3), explains the inner-loop driver decision and trade-offs (§§4-5), documents the outer-loop template invocation paths (§6), names the session-start mechanism asymmetry between Cursor and Claude Code (§7), enumerates eight failure modes with structural mitigations (§8), and sequences TICKETS 013-014 (§9). It mirrors `docs/self-healing-design.md` in structure and tier.

The alternative was to distribute Cursor-specific operator knowledge across the existing rulebooks (`docs/grok-orchestration-principles.md` for outer-loop-from-Cursor, `docs/claude-tdd-pro-principles.md` for inner-loop-from-Cursor, `AGENTS.md` for cross-tool basics, plus prose in TICKETS 013-014 ADRs). Rejected per D-9 (simple composable patterns): a single Cursor index is more discoverable, less prone to drift across files, and matches the existing pattern of TIER-2 docs covering one cross-cutting concern apiece (quality-gate, self-healing, handoff, plugin-sync).

D-1 reverse attribution: this Cursor-side operational rulebook's analog is `docs/grok-orchestration-principles.md` (the Grok-side orchestrator rulebook). The rationale for the parallel doc rather than an extension of the Grok-orchestration doc: Cursor's operator-surface conventions (`.cursor/rules/`, `.cursor/commands/`, chat-agent-as-driver) differ enough from Grok-orchestrator conventions (`.grok/templates/`, headless invocation, monitor patterns) that combining them would dilute both rulebooks. Two parallel TIER-2 docs, one per cross-tool surface, is the cleaner factoring.

### 3. TIER-2 operational rulebook, not TIER-1 directive

`docs/cursor-integration.md` joins `docs/quality-gate.md`, `docs/self-healing-design.md`, and `docs/handoff-contract.md` in the TIER-2 band. It is operational — it indexes paths, names commands, lists trade-offs — not foundational. TIER-1 (prime directive + founder-directives) is unchanged by this doc; TIER 0 (corpus) is unchanged.

Authority statement in the doc itself: the preamble says *"Status: TIER-2 operational rulebook (companion to `docs/self-healing-design.md` in tier and shape)"* and cites the TIER-0 / TIER-1 sources it composes on without claiming to supersede them.

## Alternatives considered

- **Position Cursor as a parallel consumer (peer to Claude Code).** Rejected per the user's 2026-05-25 redirect. The earlier plan iteration positioned Cursor that way; the corrected framing is Cursor IS the host IDE, with Claude Code / Grok running under it. The current `docs/cursor-integration.md §2` operator-stack diagram is the canonical statement.
- **Distribute Cursor knowledge across existing rulebooks; no new doc.** Rejected per D-9 (simple composable patterns). Cursor-specific operator knowledge has its own coherent shape and warrants its own index; spreading it across three rulebooks plus the TICKETS-013-014 ADRs would create drift surface area (Q-DOC-DRIFT cost) and would be less discoverable.
- **TIER-1 authority for the Cursor rulebook.** Rejected. The doc is wholly derivative of TIER-0 / TIER-1 sources (it indexes paths and names commands; it does not establish principles). Promoting it would inflate the TIER-1 authority band without adding new foundational rules.
- **Defer this doc until TICKETS 013-014 land.** Rejected. The doc establishes the operator-stack framing and the surfaces-table contract that TICKETS 013-014 then materialize against; writing it after-the-fact would risk TICKETS 013-014 building primitives that don't compose into a coherent operator surface. Front-loading the design doc is the same pattern as TICKET-008 (self-healing-design ships before implementation sub-tickets 008.a..e).
- **Single doc replacing AGENTS.md, not in addition to it.** Rejected. AGENTS.md is the cross-tool surface (Cursor + Codex + Amp + Jules + Factory + Grok Build); `docs/cursor-integration.md` is the Cursor-specific operational depth. Both are needed: AGENTS.md serves agents that don't know about this doc; this doc serves Cursor developers and the implementation of TICKETS 013-014.
- **Skip the failure-modes section.** Rejected. Per the existing harness convention (self-healing-design §8, quality-gate §X, smoke-script ADR-0008), every operational rulebook names its failure modes with structural mitigation. Cursor-integration's eight modes (session-start bypass, rule ignored, hand-edit-of-generated, model-discipline failure, template-output drift, doc-drift, Cursor schema break, version skew) are the ones the design considered.

## Consequences

### Positive

- **Founder's "Cursor inside Marcohard" directive operationally honored.** Source 1 line 15 is no longer a directive without an operational doc; `docs/cursor-integration.md` is the doc, this ADR records the decision.
- **TICKETS 013-014 have a design anchor.** The §3 surfaces table names what TICKET-013's `.cursor/rules/` files and TICKET-014's `.cursor/commands/` files must materialize against. Sub-ticket implementation has less freedom to drift from the design intent.
- **Operator-stack framing is recorded.** Future contributors asking "is Cursor a peer or a host?" have a canonical answer in §2 + ADR-0015 §Decision-1. Reverting that framing requires an ADR amendment, not a silent rewrite.
- **R-3 honored (no duplication).** The doc points at AGENTS.md, the rulebooks, and the existing primitives by path; it does not restate their content. AGENTS.md indexes *what*; this doc explains *how* under Cursor specifically.
- **D-1 reverse honored (per ADR-0013).** The doc's "Composition + provenance" trailer cites the Grok analog (`docs/grok-orchestration-principles.md`) and explains the rationale for the parallel-doc factoring.

### Negative

- **§3 surfaces table cross-references TICKETS 013-014 surfaces that don't exist yet.** Mitigation: every forward reference is hedged ("once shipped by TICKET-013/014" or "until shipped"). When TICKETS 013-014 land, the hedges can be removed in the same CL. The `audit-doc-drift.sh` F-3 pattern only flags future-tense references to *DONE* tickets; TICKETS 013-014 are not yet DONE at the time of this ADR.
- **New TIER-2 rulebook adds Q-DOC-DRIFT surface area.** Mitigation: §3 is path-anchored; the audit script's F-1/F-2/F-3 patterns apply; any change to a source-of-truth requires updating this doc's pointers in the same CL.
- **The "Cursor's chat agent ignores `.cursor/rules/`" failure mode (§8 mode 2) is acknowledged but not mechanically prevented.** Mitigation: the TICKET-014 Q-DEMO step is operator-attested — a real Cursor session running the slash commands against `examples/string-utils/` confirms the agent honored the rules. If a class of agents systematically fails to honor rules, an ADR amendment escalates the response.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance and §3 D-rule bodies untouched.**
- **`schema_version` of the handoff contract unchanged.**
- **AGENTS.md untouched in this CL** (TICKET-014 updates AGENTS.md if/when slash commands ship; TICKET-012 itself does not modify it).

## Verification (executed before commit)

- `test -f docs/cursor-integration.md` exits 0.
- Nine numbered section markers grep-detectable: `grep -cE '^## §[1-9] ' docs/cursor-integration.md` returns ≥ 9.
- Every cited primitive resolves to a real path:
  - `test -f AGENTS.md` (TICKET-011 DONE).
  - `test -f docs/founder-directives.md`.
  - `test -f docs/handoff-contract.md`.
  - `test -f docs/quality-gate.md`.
  - `test -f docs/self-healing-design.md`.
  - `test -f docs/grok-orchestration-principles.md`.
  - `test -f .grok/templates/research.md` / `.grok/templates/decomposition.md` / `.grok/templates/dispatch.md`.
  - `test -L .claude/skills/tdd-pro-cl-workflow` (symlink — verified post-ensure).
  - `test -f .claude/hooks/session-start.sh`.
- `./scripts/audit-doc-drift.sh` exits 0.
- `./scripts/smoke-e2e.sh` exits 0 (toy at Red baseline; this CL touched no executable).
- No duplication of upstream content (R-3): doc cites by path; no SKILL.md body, no template body, no handoff-contract schema, no quality-gate sub-gate definitions are restated.
- ADR-0015 follows the numbered ADR template (Status / Date / Deciders / Context / Decision / Alternatives / Consequences / Verification / Out of scope / Implementation references) consistent with ADRs 0001–0013.

## Out of scope (deferred)

- **`.cursor/rules/` materialization.** Lands in TICKET-013 (ADR-0014).
- **`.cursor/commands/` materialization.** Lands in TICKET-014 (ADR-0016).
- **MCP server exposing harness operations as Cursor tools.** Deferred per plan Out-of-scope (TICKET-017 + ADR-0017).
- **Devcontainer (`.devcontainer/devcontainer.json`).** Deferred per D-8 / plan Out-of-scope.
- **Cursor extension (custom integration).** Deferred per D-11 / plan Out-of-scope.
- **Cursor handoff via ACP.** Deferred per `docs/grok-orchestration-principles.md §7` and plan Out-of-scope.
- **Per-model rule tuning** (Cursor's Sonnet/GPT-4/Grok-in-Cursor selection). Deferred per D-8 — don't optimize before the un-tuned version is in use.
- **Operator journey end-to-end demo** beyond the §3 surfaces table. Lands operationally with TICKET-014's Q-DEMO step.

## Implementation references

- New: `docs/cursor-integration.md`
- Modified: `TICKETS.md` (TICKET-012 row)
- New: this ADR
- Related: ADR-0012 (AGENTS.md cross-tool surface — TICKET-011), ADR-0013 (D-1 bidirectional — TICKET-011), ADR-0014 (Cursor rules as generator output — lands TICKET-013), ADR-0016 (Cursor slash commands — lands TICKET-014), `docs/grok-orchestration-principles.md §8` (G-rule mandating AGENTS.md), `docs/founder-directives.md §1 Source 1` (the founder directive that motivates Cursor integration).
