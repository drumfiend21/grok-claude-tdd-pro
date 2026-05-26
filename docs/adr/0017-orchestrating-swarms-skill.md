# ADR-0017 — orchestrating-swarms skill (worker-fanout materialization) (TICKET-015)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Architect Automation Briefing" + AskUserQuestion answers on 2026-05-26: worker-fanout mode + MVP scope) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** `docs/grok-orchestration-principles.md §§4, 9, 10` and G-7 / G-8 / G-9 / G-16 (the canonical orchestrator-worker pattern this ADR materializes); ADR-0006 (Grok templates — the decomposition producer the swarm consumes); ADR-0008 (smoke / handoff wire — the same schema each worker uses); ADR-0010 (quality-gate v1 — the per-worker output gate); ADR-0007 (sync-plugin / SKILL.md trio — the inner-loop discipline each worker runs)

## Context

The 2026-05-26 "Architect Automation Briefing" identified multi-agent swarm orchestration (Claude Code + Grok Build CLI for end-to-end feature delivery) as the highest-leverage enterprise opportunity, citing Wayfair, Babel Street, State Street, and HubSpot hiring signal. The briefing's #1 action was *"Prototype Today: Build a Swarm Orchestration Skill in Claude Code targeting one full cycle (ticket → PR) on a low-risk internal service."*

The orchestrator-worker pattern is **already defined** in this repo's rulebook:

- `docs/grok-orchestration-principles.md §4` — Orchestrator-Worker pattern (canonical form).
- §9 — Task Decomposition Strategies.
- §10 — Parallel Sub-Agents in Git Worktrees.
- **G-7** — *"Orchestrator-Worker. Grok is the orchestrator; Claude TDD Pro instances are workers. Synthesis happens in Grok. The orchestrator does not drift into worker territory."*
- **G-8** — *"Parallel via git worktrees. Sub-agents dispatched in parallel each get their own git worktree, branch, and PR. Decomposition is along file/feature boundaries to minimize file overlap."*
- **G-9** — *"Bounded fan-out. No supervisor manages more than 8 active workers at once."*
- **G-16** — *"Atomic tickets. Every ticket Grok dispatches is sized to one CL, with concrete acceptance criteria and a `file_scope`."*

What is missing is **materialization**: today the G-rules document the pattern, but no harness primitive instructs a Claude Code or Cursor agent how to participate as the worker-fanout coordinator. Operators reading `docs/grok-orchestration-principles.md` know the pattern exists; they have no operationalized "do this" surface.

Three design questions had to be resolved before the skill could be written; the user's 2026-05-26 AskUserQuestion answers resolved Q1 and Q2, and Q3 (sub-agent role mapping) is resolved internally by reference to the existing trio:

1. **Lead-agent positioning.** Does the new skill compose on Grok's outer-loop decomposition (worker-fanout mode), parallel/replace it (lead-orchestrator mode), or offer both modes?
2. **v1 scope.** Skill + AUTOMATION_INTEL only, or include PostToolUse hooks / self-healing tests / full-briefing items?
3. **Sub-agent role mapping.** The briefing names Architect / Builder / Validator sub-agents per ticket; how does that map to the existing R-G-R discipline?

## Decision

### 1. Worker-fanout mode only (composes on Grok's outer loop)

Per the user's 2026-05-26 direction: the skill is the Claude-Code / Cursor-side **worker-fanout coordinator**. Grok still owns the outer-loop decomposition per G-7. The skill reads Grok's decomposition output (typically N `.harness/handoffs/TICKET-NNN.req.json` files), spawns one worker per ticket on its own git worktree (G-8), collects worker outputs, and runs the quality gate per worker.

The skill does NOT decompose work; it does NOT issue research; it does NOT synthesize across workers (synthesis stays in Grok per G-7). It is a *participation primitive* for the worker side of the already-defined orchestrator-worker pattern.

The alternative "lead-orchestrator mode" (skill decomposes locally, bypassing Grok) was rejected because it would conflict with G-7 without an ADR amendment to the G-rules — a TIER-2 rule change with a documented amendment process per `docs/architecture-principles.md §19`. Deferred to a future ADR if and when operationally bitten.

The alternative "both modes selectable" was rejected per D-8 (delete the part): the "lead" mode has no v1 use case and would double the skill's surface area + ADR complexity.

### 2. MVP scope: SKILL.md + AUTOMATION_INTEL only

Per the user's 2026-05-26 direction (AskUserQuestion Q2 → "Skill + AUTOMATION_INTEL only"): v1 ships the SKILL.md, an AGENTS.md §4 enumeration addition, an AUTOMATION_INTEL.md append entry, this ADR, and a TICKETS.md row. Every other briefing item is deferred with documented rationale:

- **PostToolUse hooks for review gates** → future TICKET-015.a / new mechanism ADR. The harness has only SessionStart today; adding PostToolUse adds a new hook class that warrants its own ticket.
- **Self-healing tests (UI/DOM locator repair, 80-95% vendor benchmark)** → different scope from `docs/self-healing-design.md` (debt monitor). Vendor benchmark is T-D paraphrased per `docs/founder-directives.md §1` verification tiers; not founder-elevated. Defer.
- **Apple Shortcuts / Google Workspace triggers** → outside the harness boundary per D-13 kitchen-sink resistance.
- **Weekly tech-debt elimination cron** → already designed at signal level in `docs/self-healing-design.md §§3-6`; scheduling is TICKET-008.e's deferred concern per ADR-0011.
- **MCP server exposing the swarm as a Cursor tool** → deferred per TICKET-014 / ADR-0016 (future TICKET-017 + ADR-0017 path).
- **Hierarchical multi-supervisor pattern (G-rules §5)** → defer until single-supervisor fan-out hits G-9's 8-worker limit operationally.
- **Worker-output evaluator/optimizer loop (G-18)** → separate concern; composes on the swarm but lands separately.
- **Daemon supervision for orphan-worktree cleanup** → manual recovery documented in SKILL.md Step 7; no daemon at v1.

### 3. Sub-agent role mapping: Architect / Builder / Validator → R-G-R sequentially within ONE worker

The briefing names three TeammateTool sub-agents per ticket: Architect, Builder, Validator. The existing harness defines exactly one sub-agent discipline per ticket — `tdd-pro-cl-workflow/SKILL.md`'s Red-Green-Refactor sequence executed by a single worker.

The skill maps the names sequentially within one worker, not as three parallel sub-agents per ticket:

- **Architect** = Red (write the failing test that captures the acceptance criteria).
- **Builder** = Green (implement the minimum change to pass).
- **Validator** = Refactor + quality-gate pre-review (cleanup; verify sub-gates per `docs/quality-gate.md`).

Rationale: three sub-agents per ticket would multiply context, conflict over the same files, and violate G-16 (one ticket = one CL — atomic) by fragmenting the CL. The R-G-R discipline is already validated by `tdd-pro-cl-workflow/SKILL.md` and the entire C-rulebook (`docs/claude-tdd-pro-principles.md`); inventing a parallel three-agent-per-ticket pattern would either duplicate that discipline or replace it — both worse than reusing it under cross-vocabulary naming. The Architect / Builder / Validator labels are operator-facing readability, not structural.

The N-parallel-workers-across-N-tickets fan-out is the swarm; per-ticket fan-out is not.

## Alternatives considered

- **Lead-orchestrator mode (skill decomposes + fans out).** Rejected per user direction Q1. Would conflict with G-7 without an ADR amendment. The harness's "Grok owns the outer loop" invariant is foundational; bypassing it for a single skill creates a structural split.
- **Both modes selectable.** Rejected per user direction Q1 + D-8. Doubles the skill's surface area; "lead" mode has no v1 use case.
- **Three sub-agents per ticket (Architect / Builder / Validator as parallel TeammateTools).** Rejected per Decision-3. Violates G-16 atomic-ticket discipline; multiplies context; duplicates or replaces the existing R-G-R sequence. The sequential mapping preserves the existing discipline and gives the briefing's vocabulary an honest home.
- **Adopt full briefing literally (Apple Shortcuts, vendor benchmarks, weekly cron).** Rejected per user direction Q2 + D-8 + D-12. The briefing has T-D paraphrased vendor claims and out-of-harness items that conflict with documented invariants.
- **Bypass `tdd-pro-cl-workflow/SKILL.md` — write a swarm-specific R-G-R inside this skill.** Rejected per R-3 / D-11. The trio is the inner-loop discipline; the swarm composes on it, not replaces.
- **Use shared filesystem for sub-agents (per the briefing).** Rejected. Shared filesystem violates G-8 (one sub-agent = one worktree = one branch = one PR). The skill explicitly mandates worktree isolation.
- **No worktree cleanup at v1 — let operators garbage-collect manually.** Rejected. Step 7 of the skill names the cleanup commands explicitly; the discipline is structural in the procedure, even though the recovery for crash-orphans is manual until a future TICKET-015.b daemon.
- **Skip the "Driver compatibility" section.** Rejected. Cursor's chat agent lacks Claude Code's Task tool at v1; documenting the serial-degradation path is a D-12 trustability requirement.
- **Skip pre-decomposition file-scope conflict check (Step 2).** Rejected. G-8 mandates the discipline; the skill operationalizes it. Without it, parallel workers could write to overlapping files and corrupt the merge.

## Consequences

### Positive

- **G-7 / G-8 / G-9 / G-16 are materialized into an operator-invokable primitive.** The pattern was documented since the G-rules landed; this CL ships the participation surface.
- **The "swarm-orchestration" enterprise hiring signal is operationally addressed.** A developer who reads AGENTS.md §4 + this SKILL.md has the playbook for Wayfair / State Street / HubSpot-scale parallel-feature delivery on day one.
- **The harness's "Grok owns outer loop" invariant is preserved.** Worker-fanout mode composes on Grok's decomposition; no TIER-1 amendment required.
- **R-3 honored (no duplication).** The skill cites G-rules / handoff contract / SKILL.md trio / quality-gate by path; no content is restated.
- **D-1 reverse honored per ADR-0013.** The skill cites its Grok-side analog explicitly (the decomposition template + G-rules).
- **D-8 honored.** Eight named items deferred with rationale.
- **D-11 honored.** Composes on Claude Code Task tool + git worktrees + headless invocation + existing SKILL.md trio. No reinvention.
- **D-12 honored.** Every step is exit-0-verifiable (worktree exists, `.req.json` validates, worker produces `.res.json`, gate runs). Driver-compatibility documented honestly (Cursor degrades to serial; not papered over).
- **Cross-vocabulary readability.** Architect / Builder / Validator labels from the briefing have a clean home as R-G-R phase names within one worker. Future briefings using the same vocabulary land in the same skill.

### Negative

- **Cursor's chat agent loses parallelism vs. Claude Code.** Mitigation: the skill's "Driver compatibility" section documents the degradation explicitly; the worktree-per-ticket discipline is preserved either way; a future Cursor extension (deferred per TICKET-014 Out-of-scope) could add parallel-spawn capability.
- **Orphan worktrees on lead-agent crash require manual operator recovery at v1.** Mitigation: worktree paths follow a predictable pattern (`TICKET-NNN`); the recovery commands are documented in Step 7; future TICKET-015.b could add daemon-based cleanup if operationally needed.
- **The skill is invokable by Claude Code's skill loader; Cursor's chat agent must read it as a markdown file** (no Cursor skill-loader equivalent at v1). Mitigation: same situation as the existing trio (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`); the per-AGENTS.md-§4 enumeration is the cross-tool discovery surface; the SKILL.md body is the cross-tool content surface.
- **Vendor benchmark from the briefing (80-95% test self-heal) is unverified.** Mitigation: explicitly treated as T-D paraphrased per `docs/founder-directives.md §1` verification tiers; not founder-elevated; deferred from v1 entirely.
- **G-9's 8-worker cap is a hard limit at v1.** Mitigation: §5 hierarchical-multi-supervisor pattern is documented in G-rules but deferred; v1 swarms over 8 tickets get queued, not paralleled. Operationally bitten in a future swarm with >8 atomic tickets → trigger for a follow-up ADR.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance, §3 D-rule bodies, §4 D-checklist untouched** (D-1 reverse from ADR-0013 already covers this CL).
- **`schema_version` of the handoff contract unchanged** (workers consume / produce the existing v1 schema).
- **AGENTS.md §4 gains one bullet** (the new skill); no section restructure.
- **No new scripts** (the skill is markdown; the worktree commands are git-native; no new automation script lands in this CL).

## Verification (executed before commit)

- `test -f .claude/skills/orchestrating-swarms/SKILL.md` exits 0.
- YAML frontmatter parseable; `name: orchestrating-swarms`; `description` non-empty.
- All required Step markers grep-detectable (`## Step 0` through `## Step 7`).
- All cited primitives resolve to real paths in the repo.
- D-1 reverse attribution trailer present (`D-1 reverse.*ADR-0013` grep-detectable in the SKILL.md).
- `AGENTS.md §4` lists four skills, not three.
- `AUTOMATION_INTEL.md` gains a `## 2026-05-26 — Swarm orchestration v1 (MVP)` entry.
- `./scripts/audit-doc-drift.sh` exit 0 (F-1..F-5 all clean).
- `./scripts/smoke-e2e.sh` exit 0 (toy at Red baseline; this CL touched no executable).
- `./scripts/export-cursor-rules.sh --check` exit 0 (`.cursor/rules/*.mdc` untouched; the new skill is a `.claude/skills/` addition).
- ADR-0017 follows the numbered ADR template.
- Q-DEMO (operator-attested per the smoke-script + TICKET-014 pattern): the next session that runs `/decompose` to produce 2+ non-overlapping tickets, then invokes the orchestrating-swarms skill, confirms parallel worktree workers produce contract-valid `.res.json` + `.harness/trails/*.md` per worker.

## Out of scope (deferred)

- **PostToolUse hooks for review gates** — future TICKET-015.a / new mechanism ADR.
- **Self-healing tests (UI/DOM locator repair)** — future ADR; distinct scope from `docs/self-healing-design.md` debt monitor.
- **"Lead-orchestrator" mode (skill decomposes locally)** — would conflict with G-7; defer until ADR amendment to G-rules.
- **Apple Shortcuts / Google Workspace triggers** — outside harness boundary per D-13.
- **Weekly tech-debt elimination cron** — already designed in `docs/self-healing-design.md`; scheduling is TICKET-008.e's concern.
- **MCP server exposing swarm as a Cursor tool** — deferred per TICKET-014 / ADR-0016 (future TICKET-017+ path).
- **Daemon supervision for orphan-worktree cleanup** — future TICKET-015.b candidate.
- **Hierarchical multi-supervisor pattern (G-rules §5)** — defer until single-supervisor 8-worker limit hits operationally.
- **Worker-output evaluator/optimizer loop (G-18)** — separate concern; composes on the swarm but lands separately.
- **Cursor extension for parallel-spawn capability** — deferred per TICKETS 011-014 Out-of-scope.
- **Three sub-agents per ticket (Architect / Builder / Validator as parallel TeammateTools)** — per Decision-3, the names map sequentially within one worker, not as parallel sub-agents per ticket.

## Implementation references

- New: `.claude/skills/orchestrating-swarms/SKILL.md`
- New: this ADR
- Modified: `AGENTS.md` (§4 adds fourth skill enumeration item)
- Modified: `AUTOMATION_INTEL.md` (append "2026-05-26 — Swarm orchestration v1 (MVP)" entry per briefing's #2 action)
- Modified: `TICKETS.md` (TICKET-015 row + TICKET-014 marked DONE)
- Related: ADR-0006 (Grok templates — the decomposition producer the swarm consumes), ADR-0008 (smoke / handoff wire — the schema each worker uses), ADR-0010 (quality-gate v1 — the per-worker gate), ADR-0007 (sync-plugin + SKILL.md trio — the inner-loop discipline each worker runs), ADR-0011 (self-healing design — adjacent concern, not in-scope here), ADR-0013 (D-1 bidirectional — the reverse attribution policy the SKILL.md follows), ADR-0014 (Cursor rules as generator output — the operator-surface companion), ADR-0016 (Cursor slash commands — the operator-invocation companion).
