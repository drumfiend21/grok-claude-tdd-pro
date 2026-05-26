# ADR-0012 — AGENTS.md as the cross-tool agent-binding surface (TICKET-011)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed" instruction on the reconciled TICKETS-011-014 plan) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** `docs/grok-orchestration-principles.md §8` (G-rule that names AGENTS.md and mandates repo-root placement); composes on `docs/handoff-contract.md`, `docs/founder-directives.md §4`

## Context

The founder's 2026-05-24 X post (`docs/founder-directives.md §1` Source 1, line 15, T-B, immutable) named Cursor as a peer to Claude Code as an enterprise IDE the harness must compose with. Today the harness has a Claude-specific binding surface (`CLAUDE.md`) auto-loaded by Claude Code, but no cross-tool surface for Cursor, Codex, Amp, Jules, Factory, or Grok Build. A developer opening this repo in Cursor encounters no harness-aware UX: the scripts work if they know to run them, but Cursor's chat agent has no path to discover the skill enumeration, the file-edit fences, the session-start ritual, or the pre-commit gate sequence.

`docs/grok-orchestration-principles.md §8` (G-rule) already mandates AGENTS.md as the cross-tool interop surface and requires it to live at repo root. That G-rule has been on the books since TICKETS 002+ but no file has yet been written; this ADR closes that long-standing gap.

The decision space had three open questions:

1. **What fields belong in AGENTS.md at v1?** The LF open spec (agentsmd.net) is in drafting status; many advanced fields (telemetry hints, model preferences, capability declarations) are not yet stable across consumers.
2. **How does AGENTS.md relate to CLAUDE.md?** Claude Code reads CLAUDE.md; other AGENTS.md consumers do not. Does AGENTS.md duplicate CLAUDE.md content, supersede it, or compose with it?
3. **What authority tier does AGENTS.md hold?** It encodes operator-visible conventions, but it is not itself the source-of-truth for any rule it surfaces.

## Decision

### 1. Ship the agent-binding subset known stable across consumers; defer advanced fields

AGENTS.md ships with exactly eight sections at v1: build/test commands, file-scope rules, wire-format pointer, skill enumeration, authority-doc enumeration, outer-loop template pointers, session-start ritual, pre-commit gates. Every section is a path-anchored pointer (per R-3 single-source-of-truth — no duplication of the content it references).

Advanced fields from the LF draft (telemetry hints, model preferences, capability declarations, multi-agent coordination metadata) are deferred. Rationale: the LF spec is in drafting status; locking in advanced fields before the spec stabilizes would force a rewrite when consumers diverge. The eight-section agent-binding subset is the intersection observed in shipping Cursor / Codex / Amp / Jules / Factory / Grok Build agent-context files.

### 2. AGENTS.md composes with CLAUDE.md; does not duplicate or supersede it

AGENTS.md and CLAUDE.md sit side-by-side at repo root. Claude Code reads CLAUDE.md; non-Claude AGENTS.md consumers read AGENTS.md. Neither file duplicates the other:

- **CLAUDE.md** carries the full TIER-0/1/2 authority hierarchy framing, the prime-directive plugin-dependency model with its four invariants, the rulebook section headers with the "before designing or coding anything" rituals, the "two harness rules," and the "what this repo does NOT do" list. It is the Claude-Code-specific binding context — the file Claude Code auto-loads.
- **AGENTS.md** is a flat, pointer-only operator-surface index. It enumerates *where* the authority lives (TIER 0 / 1 / 2 pointers in §5) but does not restate the authority text. It enumerates *what* skills exist and where (§4) but does not restate SKILL.md bodies. It enumerates *which* commands run when (§§1, 7, 8) but does not restate script logic.

Cross-reference: CLAUDE.md gains a one-line pointer to AGENTS.md as the cross-tool surface (TICKET-011 modification to CLAUDE.md). AGENTS.md cross-references CLAUDE.md as the TIER-1 prime directive in its §5. Neither cycle-references the other's content body.

### 3. AGENTS.md is TIER-2 operator-surface convention, not authority

AGENTS.md is a surface, not a rule. Its content is wholly derivative of the TIER 0/1/2 sources it points at. When AGENTS.md and any other rulebook conflict, the rulebook wins — AGENTS.md is corrected to match. This sits AGENTS.md alongside `docs/quality-gate.md` and `docs/self-healing-design.md` in the TIER-2 band (operational rulebooks + operator-surface conventions); it does NOT join the TIER-1 prime-directive + founder-directives band.

Authority assertion in AGENTS.md itself: the file's preamble states *"this file is a TIER-2 operator-surface convention; it composes on (does not supersede) the TIER-0 supreme operating directive, the TIER-1 prime directive, and the TIER-1 founder-directives rulebook."*

## Alternatives considered

- **AGENTS.md duplicates CLAUDE.md verbatim.** Rejected per R-3 (single source of truth). Maintainers would have to update two files in lockstep; drift would be guaranteed (the audit-doc-drift script's whole reason for existing).
- **AGENTS.md supersedes CLAUDE.md (one binding surface for all tools).** Rejected. Claude Code's auto-load contract is CLAUDE.md, not AGENTS.md; switching surfaces would silently break Claude Code's session-start. The two-surface composition is the documented LF pattern.
- **Ship all LF-draft AGENTS.md fields at v1.** Rejected per D-8 (deletion discipline). The agent-binding subset is the part shipping consumers actually read; advanced fields are speculative until the LF spec stabilizes.
- **Defer AGENTS.md to TICKET-013+ (when Cursor `.cursor/rules/` ship together).** Rejected. AGENTS.md is independent of `.cursor/rules/` and useful to every AGENTS.md consumer (Codex / Amp / Jules / Factory / Grok Build), not just Cursor. Shipping AGENTS.md first establishes the cross-tool entry point; TICKETS 012-014 layer the Cursor-specific surfaces on top.
- **TIER-1 authority for AGENTS.md.** Rejected. AGENTS.md restates content from TIER 0/1/2 sources; promoting the surface above its sources inverts the authority chain.
- **Skip the "Composition + provenance" trailer.** Rejected. Per the existing harness ADR convention, every cross-tool surface declares what it composes on by name — that is the signal that the file is pointer-only.

## Consequences

### Positive

- **Long-standing G-§8 gap closed.** `docs/grok-orchestration-principles.md §8` has mandated AGENTS.md since the G-rules landed; this ADR ships the file.
- **Cursor's chat agent (and Codex / Amp / Jules / Factory / Grok Build agents) now have a documented session-start path.** No agent has to discover the harness by archaeology; AGENTS.md §7 gives the ritual and AGENTS.md §1 gives the verification commands.
- **R-3 honored across CLAUDE.md and AGENTS.md.** Each file has its own purpose; neither restates the other's content; both cross-reference.
- **D-8 honored.** Eight sections shipped; LF-draft advanced fields explicitly deferred with rationale.
- **D-12 honored.** AGENTS.md ships paths and exit-0 commands an operator can verify; nothing in AGENTS.md lies about state.

### Negative

- **Eight-section schema may evolve as the LF spec stabilizes.** When the spec ships v1, this file may need a structural pass to match the canonical field names. Mitigation: the section content is path-anchored, so reorganization is mechanical; ADR-0012 amendment will document the migration.
- **AGENTS.md cross-references `.cursor/rules/agent-context.mdc` and audit pattern F-5 which ship in TICKET-013.** Until TICKET-013 lands, those cross-references are forward-looking. Mitigation: every forward reference is hedged ("once shipped by TICKET-013"). When TICKET-013 lands, audit-doc-drift.sh's F-3 pattern will NOT flag these (TICKET-013 is not yet DONE in TICKETS.md at the time of this ADR); when TICKET-013 lands, the hedge can be removed in the same CL.
- **AGENTS.md is a new operator-visible surface and so a new operator-visible drift vector.** Mitigation: any change to a source that AGENTS.md points at must update AGENTS.md in the same CL per Q-DOC-DRIFT. The audit-doc-drift.sh script's F-1/F-2/F-3 patterns generalize to AGENTS.md content; F-4 already covers sync-plugin.sh which AGENTS.md surfaces.

### Neutral

- **D-rule count unchanged.** No new D-rule; ADR-0013 (separate) records the D-1 bidirectional reading and adds a §4 checklist item.
- **TIER-0 corpus untouched.**
- **`schema_version` of the handoff contract unchanged.**
- **Plugin-cache symlinks untouched.**

## Verification (executed before commit)

- `test -f AGENTS.md` exits 0.
- All eight required section markers grep-detectable:
  - `grep -q '## 1\. Build / test' AGENTS.md`
  - `grep -q 'handoff-contract.md' AGENTS.md`
  - `grep -q 'skills' AGENTS.md`
  - `grep -q 'TIER 0' AGENTS.md`
  - `grep -q 'TIER 1' AGENTS.md`
  - `grep -q 'TIER 2' AGENTS.md`
  - `grep -q '\.grok/templates' AGENTS.md`
  - `grep -q 'sync-plugin' AGENTS.md`
  - `grep -q 'audit-doc-drift' AGENTS.md`
- `./scripts/audit-doc-drift.sh` exits 0 (no stale stubs, no stale framing, no future-tense to DONE tickets, no sync-plugin.sh drift).
- `./scripts/smoke-e2e.sh` exits 0 (toy at Red baseline; this CL touched no executable).
- CLAUDE.md gains one-line pointer to AGENTS.md as cross-tool surface; existing TIER 0/1/2 hierarchy + prime directive + plugin-dependency invariants untouched.
- ADR-0013 lands in the same CL (D-1 bidirectional attribution + §4 checklist item).

## Out of scope (deferred)

- **LF-draft advanced fields** (telemetry hints, model preferences, capability declarations). Defer until LF v1 stabilizes.
- **AGENTS.md per-environment overrides** (per-workspace or per-IDE variants). Single canonical file at repo root per G-§8 mandate.
- **Auto-generation of AGENTS.md from the rulebooks it points at.** Considered but rejected: AGENTS.md is short and its pointers are stable; generator overhead exceeds maintenance overhead.
- **Cursor-specific surface layers** (`.cursor/rules/`, `.cursor/commands/`). Land in TICKETS 013-014 (separate ADRs 0014, 0016).

## Implementation references

- New: `AGENTS.md`
- Modified: `CLAUDE.md` (one-line cross-tool surface pointer)
- Modified: `docs/founder-directives.md §4` (D-1 bidirectional checklist item — see ADR-0013)
- Modified: `TICKETS.md` (TICKET-011 row)
- New: this ADR
- Related: ADR-0013 (D-1 bidirectional attribution), `docs/grok-orchestration-principles.md §8` (G-rule mandating AGENTS.md), `docs/handoff-contract.md` (wire), `docs/founder-directives.md §4` (pre-commit checklist).
