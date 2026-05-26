# Cursor integration — using grok-claude-tdd-pro INSIDE the Cursor IDE

Status: TIER-2 operational rulebook (companion to `docs/self-healing-design.md` in tier and shape; both add to the operational rulebook band beneath the TIER-1 prime directive and founder-directives).
Authority: composes on the TIER-0 supreme operating directive (`docs/ai-engineering-corpus.md`), the TIER-1 prime directive (`CLAUDE.md`), the TIER-1 founder-directives (`docs/founder-directives.md`); cited by ADR-0015.

## §1 Purpose

This doc explains how the harness is used **inside** the Cursor IDE — i.e., when Cursor is the developer's host editor and the harness runs under it. Cursor is named as a peer to Claude Code in `docs/founder-directives.md §1` Source 1 (line 15, T-B, immutable): *"Grok Build should watch and learn from Claude Code and Cursor inside Marcohard."* — @teslayoda, 2026-05-24. The harness's value proposition (D-12 production-grade trustability across enterprise IDE deployments) requires that every harness feature be drivable from inside Cursor, not just from Claude Code's terminal.

This doc is the operator-facing index of *which Cursor surface drives which harness feature*. It composes on the cross-tool surface enumeration in `AGENTS.md` (TICKET-011 / ADR-0012) without duplicating it (R-3): `AGENTS.md` lists *what* exists; this doc explains *how* the developer drives it from Cursor specifically.

## §2 Position in harness (operator stack)

The harness's two-tier loop (Grok outer / Claude inner) is unchanged by Cursor's presence. What Cursor adds is a new top of the operator stack — the developer's host IDE:

```
Developer
   │
   ▼
Cursor IDE  ◄── this doc's scope
   │ chat agent / compose mode / terminal / git surface
   ▼
Outer loop  ── .grok/templates/{research,decomposition,dispatch}.md
   │
   ▼
Handoff contract  ── .harness/handoffs/TICKET-NNN.req.json
   │
   ▼
Inner loop  ── .claude/skills/tdd-pro-cl-workflow/SKILL.md (R-G-R)
   │
   ▼
Handoff response  ── .harness/handoffs/TICKET-NNN.res.json + .harness/trails/TICKET-NNN.md
   │
   ▼
Quality gate  ── docs/quality-gate.md sub-gates
   │
   ▼
Commit / push (via Cursor's git surface or terminal)
```

ADR-0015 records the "Cursor as host IDE" decision: Cursor sits at the top of the operator stack; Grok / Claude TDD Pro substrate sits underneath unchanged.

## §3 Surfaces — every harness feature mapped to its Cursor driver

This table is the operational index. Each row names a harness feature, its source-of-truth, the Cursor surface a developer uses to drive it, and the ticket that landed the operator path. All seven slash commands ship in TICKET-014 / ADR-0016.

| Harness feature | Source-of-truth | Cursor surface | Ticket |
|---|---|---|---|
| Cross-tool agent-binding context | `AGENTS.md` | Auto-loaded by Cursor's chat agent on session open (per AGENTS.md open spec) | 011 (DONE) |
| Plugin cache materialization (session-start ritual) | `scripts/sync-plugin.sh --ensure` | Chat agent reads `.cursor/rules/agent-context.mdc` always-loaded rule → runs script. Manual re-trigger: `/sync` slash command. | 013 + 014 (DONE) |
| Plugin pin freshness check | `scripts/sync-plugin.sh --check` | Cursor terminal (CLI invocation) | (existing) |
| Outer-loop research | `.grok/templates/research.md` | Developer types `/research <topic>`; chat agent reads template, follows schema, produces `research_refs`. | 014 (DONE) |
| Outer-loop decomposition | `.grok/templates/decomposition.md` | Developer types `/decompose`; chat agent reads template and produces atomic ticket decomposition. | 014 (DONE) |
| Outer-loop dispatch | `.grok/templates/dispatch.md` | Developer types `/dispatch TICKET-NNN`; chat agent reads template + `docs/handoff-contract.md §Grok→Claude` and writes contract-valid `.req.json`. | 014 (DONE) |
| Handoff contract (wire format) | `docs/handoff-contract.md` | Read directly by chat agent during dispatch / inner-loop invocation; enumerated in AGENTS.md §3. | 011 (DONE) |
| Inner-loop R-G-R skill | `.claude/skills/tdd-pro-cl-workflow/SKILL.md` | Developer types `/inner-loop TICKET-NNN`; chat agent loads SKILL.md and runs R-G-R; writes `.res.json` + trail. See §4 below. | 014 (DONE) |
| Inner-loop batching skill | `.claude/skills/tdd-pro-batch-cl/SKILL.md` | Chat agent reads when batching multiple substrate-touch CLs (per AGENTS.md §4). | 011 (DONE) |
| Inner-loop portability skill | `.claude/skills/tdd-pro-bash32-portability/SKILL.md` | Chat agent reads before any new `.sh` edit (per AGENTS.md §4). | 011 (DONE) |
| End-to-end smoke | `scripts/smoke-e2e.sh` | Developer types `/smoke`; chat agent runs the script and reports pass/fail. | 014 (DONE) |
| Doc-drift audit | `scripts/audit-doc-drift.sh` | Developer types `/audit`; chat agent runs the script and surfaces findings. | 014 (DONE) |
| Plugin sync (manual) | `scripts/sync-plugin.sh --ensure` | Developer types `/sync`; chat agent runs the script. (Also fired automatically per `.cursor/rules/agent-context.mdc` on session open.) | 014 (DONE) |
| Quality-gate sub-gates | `docs/quality-gate.md` | `.cursor/rules/quality-gate.mdc` agent-loaded so chat agent enforces during diff review. | 013 (DONE) |
| Authority hierarchy (TIER 0/1/2) | `AGENTS.md §5` + `CLAUDE.md` | Chat agent reads on session open. | 011 (DONE) |
| Decision-trail surface | `.harness/trails/TICKET-NNN.md` | Written by chat agent during `/inner-loop` (or by manual inner-loop invocation). | 014 (DONE) |
| Headless Claude Code as alternative inner-loop driver | `claude -p` headless mode | Cursor terminal — see §5. | (existing, no new code) |
| Demo storyboard | `docs/demo-storyboard.md` | Read as documentation in Cursor's editor. | (existing) |
| Self-healing design (deferred implementation) | `docs/self-healing-design.md` | Read as TIER-2 design doc. | (existing) |

The eighteen-row table above covers every harness feature against a Cursor surface; the seven slash commands shipped in TICKET-014 close the operator-surface loop. No feature is unreachable from Cursor.

## §4 Cursor's chat agent as the inner-loop driver (primary path)

When the developer is working inside Cursor, the primary inner-loop driver is **Cursor's chat agent itself**, not headless Claude Code. The agent:

1. Receives the `/inner-loop TICKET-NNN` slash command (TICKET-014's `.cursor/commands/inner-loop.md`).
2. Reads `.harness/handoffs/TICKET-NNN.req.json` to load the ticket's `acceptance_criteria`, `file_scope`, `context`, `quality_gate`.
3. Reads `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (the per-CL R-G-R discipline) — enumerated in `AGENTS.md §4`; the symlink resolves through `.harness/plugin-cache/`.
4. Follows the R-G-R sequence against the ticket: writes failing test (Red), implements the minimum change to pass (Green), refactors safely (Refactor). The discipline lives in the skill's body; this doc does not duplicate it.
5. Writes `.harness/handoffs/TICKET-NNN.res.json` per `docs/handoff-contract.md §Claude→Grok` — status, changed_files, test_results, decision_trail_ref, gate_results.
6. Writes `.harness/trails/TICKET-NNN.md` naming the three R-G-R steps (or skip rationale per SKILL.md's allowance for stub-shape commits).

Cursor's chat agent runs in-process inside the developer's IDE — no separate Claude Code spawn, no separate model context. The trade-off vs. headless Claude Code (see §5) is that the chat agent is whichever model the developer has selected in Cursor (Sonnet, GPT, Grok-in-Cursor, etc.), not necessarily a Claude model. The discipline is enforced by the SKILL.md the agent reads, not by which model executes it. ADR-0016 (lands with TICKET-014) records the inner-loop driver decision and its trade-offs.

## §5 Headless Claude Code as alternative inner-loop driver

The harness's original inner-loop driver is **headless Claude Code** (`claude -p`) per `docs/handoff-contract.md` and `scripts/smoke-e2e.sh`. That path remains fully available inside Cursor:

1. Developer opens Cursor's terminal pane.
2. Developer runs `claude -p "<inner-loop prompt referencing .harness/handoffs/TICKET-NNN.req.json>"` — exactly as they would in any other terminal.
3. Headless Claude Code reads the ticket, the SKILL.md, the request JSON, runs R-G-R, writes the response JSON and the trail.

No new code needed; this path has worked since TICKET-006 (smoke script). It is documented here for completeness so a Cursor developer who prefers to delegate inner-loop work to a guaranteed-Claude model rather than to Cursor's current chat-model selection has the path. Trade-off: `claude -p` spawns a new process and context, which adds latency vs. the in-process chat-agent path; but it pins the inner-loop driver to a Claude model regardless of Cursor's chat-model setting.

Both paths produce contract-valid `.res.json` + `.harness/trails/` artifacts. The harness's downstream consumers (smoke, audit, quality gate) cannot tell which path produced them.

## §6 Outer-loop templates from Cursor

The outer-loop templates (`.grok/templates/{research,decomposition,dispatch}.md`) were originally written for Grok CLI (`grok -p`) consumption, per `docs/grok-orchestration-principles.md`. The templates themselves are model-agnostic structured-output prompts; any agent capable of following the documented output schema can drive them. From inside Cursor:

- **Primary path:** developer types `/research <topic>`, `/decompose`, `/dispatch TICKET-NNN` in Cursor chat (TICKET-014's `.cursor/commands/*.md`). The agent reads the corresponding template from `.grok/templates/` and follows its output schema. No Grok CLI installation required.
- **Fallback path (also valid):** developer opens Cursor's terminal and runs `grok -p` against the template directly, if Grok CLI is installed. This is the original path; the slash-command path is the addition.
- **Manual path (always works):** developer pastes the template body into Cursor chat with the input variables filled in. Useful for exploratory work that doesn't fit the structured commands cleanly.

D-1 forward attribution lives in each template (`.grok/templates/research.md:5` *"Drawn from (per D-1): Cursor's ask-mode context gather."*; `.grok/templates/decomposition.md:5` *"Drawn from (per D-1): Cursor's compose mode (multi-edit plan)."*). D-1 reverse attribution (per ADR-0013) for the slash commands lives in each `.cursor/commands/*.md` file's "Composition" trailer.

## §7 Session-start ritual under Cursor

Claude Code has a push-hook mechanism (`.claude/hooks/session-start.sh`, registered in `.claude/settings.json`) that auto-runs the plugin-cache materialization before any other action. Cursor lacks an equivalent push-hook mechanism. The TICKET-013 always-loaded rule `.cursor/rules/agent-context.mdc` is the **functional equivalent**:

| Mechanism | Claude Code | Cursor |
|---|---|---|
| Trigger | SessionStart event → shell script | Chat-agent reads always-loaded rule on session open |
| Invocation | `bash .claude/hooks/session-start.sh` automatic | Agent invokes `./scripts/sync-plugin.sh --ensure` per the rule's instruction |
| Idempotency | Script handles | Same script handles |
| Failure visibility | stdout/stderr to Claude Code's session log | Reported by agent in chat |

The behavior is equivalent (both surface the session-start ritual to the agent before any other action); the mechanism differs (push-hook vs. always-loaded rule). This is a tool architectural difference between Cursor and Claude Code, not a harness feature gap — `AGENTS.md §7` documents this explicitly.

TICKET-013 has shipped the always-loaded rule (`.cursor/rules/agent-context.mdc` plus the three sibling rules). The Cursor session-start ritual is now automatic via that always-loaded rule; the `/sync` slash command (TICKET-014) is the manual re-trigger for mid-session refreshes (e.g., after a `git pull`). AGENTS.md §7 remains the documented entry point for non-Cursor AGENTS.md consumers.

## §8 Failure modes

Eight failure modes the design considered; each with a structural mitigation or explicit deferral.

1. **Cursor session opened without running the session-start ritual.** Mitigation: AGENTS.md §7 names the ritual as the first command; TICKET-013's `.cursor/rules/agent-context.mdc` mandates it as always-loaded context; if both are bypassed, the SKILL.md symlinks fail to resolve and the inner-loop invocation visibly errors (not a silent corruption).
2. **Cursor's chat agent ignores `.cursor/rules/*.mdc`.** Mitigation: rules are best-effort context, not a hard contract. The TICKET-014 Q-DEMO step (operator-attested per the smoke-script Q-DEMO pattern) confirms the agent honored them in a real session. If a class of agents systematically ignores rules, escalate to ADR-0014 amendment.
3. **Developer hand-edits a generated `.cursor/rules/*.mdc` file.** Mitigation: TICKET-013 ships every generated file with a `# Generated by scripts/export-cursor-rules.sh — DO NOT EDIT` header; TICKET-013 also extends `scripts/audit-doc-drift.sh` with the F-5 pattern to catch hand-edits at pre-commit. ADR-0014 records the generator-output-only invariant.
4. **Cursor's chat-model selection produces a model that cannot follow the SKILL.md R-G-R discipline reliably.** Mitigation: the discipline is enforced by the skill body and the §5 alternative path (headless `claude -p`); if a developer finds their selected model unreliable, they fall back to §5. The harness's quality gate (`docs/quality-gate.md` `tests_must_pass`) catches the failure at diff review regardless of which model produced the change.
5. **Outer-loop template output drift between Grok CLI and Cursor's chat agent.** Mitigation: templates document their output schema explicitly (per `.grok/templates/dispatch.md` and `docs/handoff-contract.md §Grok→Claude`); contract-validity is the bar, not byte-for-byte equivalence. If a chat-agent-produced `.req.json` fails contract validation, the inner-loop driver rejects it visibly.
6. **AGENTS.md or `docs/cursor-integration.md` drift behind the surfaces they index.** Mitigation: every CL that changes an operator-visible surface must update the downstream operator-facing docs in the same CL per Q-DOC-DRIFT (`docs/founder-directives.md §4`); `scripts/audit-doc-drift.sh` exit 0 is required at pre-commit.
7. **Cursor releases a breaking change to `.cursor/rules/` or `.cursor/commands/` schema.** Mitigation: the rule and command files are markdown with documented structure, not opaque binary or proprietary format. A schema break requires a regeneration (TICKET-013's generator) or a content pass (TICKET-014); both are mechanical. Documented in `docs/cursor-integration.md` rather than left implicit.
8. **Multiple developers with different Cursor versions edit the repo concurrently.** Mitigation: not a harness concern at v1. `.cursor/rules/` and `.cursor/commands/` are checked into git; whichever Cursor version reads them must accept the documented schema. If a future Cursor version requires schema migration, regenerate and commit per the same Q-DOC-DRIFT discipline.

## §9 Sequencing (this doc references the materialization tickets)

- **TICKET-011 (DONE)** — `AGENTS.md` shipped (the cross-tool surface this doc composes on); ADRs 0012 + 0013.
- **TICKET-012 (DONE — this doc)** — `docs/cursor-integration.md` + ADR-0015 (Cursor as host IDE).
- **TICKET-013 (DONE)** — `scripts/export-cursor-rules.sh` + four `.cursor/rules/*.mdc` files + ADR-0014; extends `scripts/audit-doc-drift.sh` with F-5; wires into `scripts/sync-plugin.sh --ensure`.
- **TICKET-014 (DONE)** — seven `.cursor/commands/*.md` files + ADR-0016; §3 table above surfaces the slash commands; `AUTOMATION_INTEL.md` appended with "Hybrid Harness v0.2 reconciliation complete" entry per the v0.2 spec's §5 directive. The Q-DEMO step is operator-attested per the smoke-script Q-DEMO pattern: the first Cursor session after this CL lands runs `/dispatch TICKET-DEMO` and `/inner-loop TICKET-DEMO` against `examples/string-utils/` and confirms contract-valid `.req.json` + `.res.json` with passing tests.

Each ticket is a single CL; the four together close the gap "harness usable inside Cursor IDE." The Out-of-scope items (MCP server exposure, devcontainer, custom Cursor extension) are deferred per the plan's Out-of-scope section; they are not required to satisfy the founder's "Cursor inside Marcohard" intent at v1.

## Composition + provenance

This doc composes on:

- `AGENTS.md` (TICKET-011) — the cross-tool surface enumeration this doc operationalizes for Cursor specifically.
- `docs/founder-directives.md §1 Source 1` (line 15, T-B, immutable) — the founder's "Cursor inside Marcohard" directive that motivates this doc.
- `docs/grok-orchestration-principles.md §8` — the G-rule mandating AGENTS.md at repo root.
- `docs/handoff-contract.md` — the wire format the §3 surfaces table references.
- `docs/quality-gate.md` — the sub-gates `quality-gate.mdc` (TICKET-013) will surface.
- `docs/self-healing-design.md` — the structural template this doc mirrors in tier and shape.
- `.grok/templates/*.md` — the outer-loop templates §6 describes.
- `.claude/skills/tdd-pro-cl-workflow/SKILL.md` — the inner-loop discipline §4 references.
- `.claude/hooks/session-start.sh` — the mechanism §7 contrasts with the Cursor always-loaded-rule equivalent.

This doc does NOT duplicate the content it points at (R-3). When a source-of-truth changes, this doc's pointers may need re-pointing; its content reads only against the sources.

D-1 reverse attribution (per ADR-0013): this doc is a Cursor-side operational rulebook; its Grok analog is `docs/grok-orchestration-principles.md` (which is itself the cross-tool-orchestrator rulebook); the rationale for the parallel doc rather than an extension to the Grok orchestration doc is that Cursor's operator-surface conventions differ enough from Grok-orchestrator conventions to warrant a separate index — combining them would dilute both rulebooks. ADR-0015 records this rationale.

History: introduced in TICKET-012 (ADR-0015 — Cursor as host IDE).
