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

## 2026-05-26 — Swarm orchestration v1 (MVP)

TICKET-015 / ADR-0017 ships `.claude/skills/orchestrating-swarms/SKILL.md` — the Claude-Code / Cursor-side materialization of the orchestrator-worker pattern named in `docs/grok-orchestration-principles.md §§4, 9, 10` + G-7 / G-8 / G-9 / G-16. Per the 2026-05-26 "Architect Automation Briefing" #1 action item (Wayfair / Babel Street / State Street / HubSpot agentic-swarm hiring signal).

Design (per 2026-05-26 user direction):

- **Mode: worker-fanout.** Composes on Grok's outer-loop decomposition per G-7; does NOT replace it. Grok still decomposes; the new skill is the Claude-side fanout consumer.
- **MVP scope.** SKILL.md + this AUTOMATION_INTEL entry + AGENTS.md §4 enumeration + TICKETS.md row + ADR-0017. PostToolUse hooks, self-healing tests, weekly debt cron, Apple/Google triggers, lead-orchestrator mode, hierarchical multi-supervisor pattern — all explicitly deferred per ADR-0017 Out-of-scope with rationale.
- **Sub-agent role mapping.** The briefing's Architect / Builder / Validator labels map sequentially within one worker to R-G-R phases (Architect = Red, Builder = Green, Validator = Refactor + gate pre-review), not as three parallel TeammateTools per ticket. N parallel workers across N tickets is the swarm; per-ticket fan-out is not.
- **Worktree discipline.** Per G-8: one worker = one git worktree = one branch = one PR. Pre-decomposition file-scope conflict map serializes overlapping tickets (not papered over). G-9 caps parallel workers at 8 per supervisor.

Vendor benchmark claim in the briefing (80-95% UI-DOM self-healing tests) treated as T-D paraphrased per `docs/founder-directives.md §1` verification tiers; not founder-elevated; out-of-scope.

Enterprise positioning extended: outer-loop autonomy (Grok) + parallel worker fan-out on isolated worktrees (this CL) + inner-loop discipline (tdd-pro-cl-workflow trio) + per-worker quality gate (`docs/quality-gate.md`) + cross-IDE operator surface (TICKETS 011-014) = the harness now operationalizes parallel multi-ticket delivery without surrendering production-grade trust. Direct addressable pitch for >1,000-IC orgs running heterogeneous IDE fleets shipping agentic platforms.

## 2026-05-26 — Grok Build Beta GA + Source 9 elevation

TICKET-017 / ADR-0024 elevates `x.ai/cli` as `docs/founder-directives.md §1` Source 9 (Grok Build Beta canonical product surface). Distinct from Source 4 (the 2026-05-14 launch announcement at `x.ai/news/grok-build-cli`) — Source 4 = one-time launch event; Source 9 = living product surface with installer command, slash commands, plan-mode rules, extensions-out-of-the-box composition.

Operational intel for demos / pitches:

- **Distribution.** Available to all SuperGrok and X Premium Plus subscribers as of 2026-05-26.
- **Installer (verbatim from Source 9):** `curl -fsSL https://x.ai/cli/install.sh | bash` — single-command install on Linux + macOS.
- **Cross-tool composability (verbatim, ratifying harness G-10):** *"Your AGENTS.md, plugins, hooks, skills, and MCP servers all work out of the box. Start Grok Build in your repo and it picks up your conventions instantly."* This is the harness's value-prop validated by xAI's own product positioning: the harness's `AGENTS.md` + `.claude/skills/` + `.claude/hooks/` + `.cursor/rules/` + `.cursor/commands/` ARE the conventions Grok Build "picks up instantly."
- **Plan-mode (verbatim, ratifying G-12):** *"Plan mode is for planning first. When it is active, write tools are blocked except for the session plan file."* Matches Claude Code's plan-mode semantics; supports the cross-tool plan-first discipline the harness already enforces.
- **Architecture (verbatim, ratifying G-7/G-8/G-9):** *"Grok Build delegates larger tasks to specialized subagents, with each child running in parallel with its own context window."* Source 9 ratifies the orchestrator-worker pattern the harness's `orchestrating-swarms` SKILL.md (TICKET-015 / ADR-0017) materializes on the Claude/Cursor side.

The Daniel Farinax X post (`x.com/Daniel_Farinax/status/2059002180481204461`, 2026-05-25) is the community-onboarding video for non-technical SuperGrok / X Premium+ users — folded as supplementary into Source 9's verification block at T-D paraphrase tier (community-adoption evidence; demos Source 9 content; no independent architectural weight).

Verification procedure cited inline: `docs/researcher-discipline.md` (TICKET-016 / ADR-0023). Both URLs returned 403 in capture session per the harness's outbound network policy (`x-deny-reason: host_not_allowed`); WebSearch + 11-source cross-attribution recovered T-C content per `docs/researcher-discipline.md §3`. Source 9 is the FIRST §1 entry to cite the new researcher-discipline doc by path rather than open-coding the procedure.

Pitch hook extension (2026-05-26): the harness composes cleanly with both Anthropic's Claude Code (existing path) AND xAI's Grok Build (Source 9-ratified path). The cross-vendor positioning is exactly what >1,000-IC enterprise procurement teams want: their AI tooling stack survives vendor diversification without architectural rewrites. AGENTS.md + plugins + hooks + skills + MCP servers are the cross-tool primitives both vendors honor.
