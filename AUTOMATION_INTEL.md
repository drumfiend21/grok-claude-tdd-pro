# AUTOMATION_INTEL.md

Append-only intel log for the hybrid-harness pitch. Each entry is dated and immutable; corrections land as new entries below, not as edits above.

## 2026-05-24 — Initial Boston/US opportunities table

Hybrid-harness focus: Grok Build CLI (outer orchestration) + Claude TDD Pro (quality core).

| Tier   | Company         | Signal                          | Automation focus                                    | Source                  |
| ------ | --------------- | ------------------------------- | --------------------------------------------------- | ----------------------- |
| High   | State Street    | Agentic Architecture roles      | Hybrid TDD + orchestration for compliance platforms | State Street careers    |
| High   | HubSpot         | Breeze AI expansions            | Standardized quality core in agent flows            | HubSpot eng blog        |
| Medium | Fidelity        | Enterprise AI                   | Regulated TDD harness for pipelines                 | Recent VP postings      |
| Medium | Moderna         | Enterprise AI                   | Regulated TDD harness for pipelines                 | Recent VP postings      |
| Medium | Wayfair         | Modernization initiatives       | Hybrid for monolith refactoring                     | Tech signals            |

## 2026-05-24 — Pitch hook

"Grok Build CLI gives you the speed of end-to-end automation. Claude TDD Pro gives you the discipline that survives 1,000 engineers shipping in parallel. The harness is the bridge — your outer pipeline is autonomous, but every code change still passes a Red-Green-Refactor gate with provenance you can show an auditor."

Target demo industries: regulated finance (State Street, Fidelity), regulated life sciences (Moderna), large-scale platform engineering (HubSpot, Wayfair).

## Append new entries below this line.

## 2026-05-26 — Hybrid Harness v0.2 reconciliation complete

TICKETS 011-014 landed the "harness usable INSIDE Cursor IDE" extension per the founder's "Cursor inside Marcohard" directive (founder-directives.md §1 Source 1 line 15, T-B, immutable). Closed the gap where Cursor sessions opened with no harness-aware UX. Materialized:

- `AGENTS.md` (TICKET-011 / ADR-0012) — cross-tool agent-binding surface for Cursor, Codex, Amp, Jules, Factory, Grok Build.
- `docs/cursor-integration.md` (TICKET-012 / ADR-0015) — TIER-2 operational rulebook framing Cursor as host IDE atop the operator stack.
- `.cursor/rules/*.mdc` (TICKET-013 / ADR-0014) — four generator-output always-loaded / agent-loaded rules; F-5 audit pattern catches hand-edits at pre-commit.
- `.cursor/commands/*.md` (TICKET-014 / ADR-0016) — seven slash commands across three classes (terminal wrappers, outer-loop drivers, inner-loop driver). Cursor's chat agent is the default inner-loop driver inside Cursor per ADR-0016; headless `claude -p` remains the documented alternative.

The user-provided "Technical Implementation Plan: grok-Claude-tdd-pro Hybrid Harness v0.2" spec was adapted to extend the existing architecture (rather than adopted literally) per the user's 2026-05-25 direction; reconciliation mapping recorded in the implementation plan. Zero TIER-1 invariants violated; zero v0.2 directives lost; explicit deferrals documented in each ticket's ADR.

Enterprise positioning: every harness feature is now drivable from inside Cursor — the named enterprise IDE alongside Claude Code. Pitch hook (2026-05-24) extended: outer-loop autonomy + inner-loop discipline + cross-IDE operator surface = production-grade trustability that survives both 1,000 engineers shipping in parallel AND a heterogeneous IDE fleet (Cursor + Claude Code + Grok Build).
