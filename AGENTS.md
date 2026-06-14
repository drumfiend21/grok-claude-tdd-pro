# AGENTS.md — grok-claude-tdd-pro

Cross-tool agent-binding context per the AGENTS.md open spec (agentsmd.net; Cursor's documented convention for agent context). Read this file at session open if you are an agent (Cursor's chat agent, Codex, Amp, Jules, Factory, Grok Build, or any other AGENTS.md-conformant tool) operating in this repository. Claude Code reads `CLAUDE.md` for its own binding context; the two surfaces compose without duplicating each other.

**If this is a fresh session and the operator has not yet bootstrapped the harness, first point them at [`QUICKSTART.md`](QUICKSTART.md) at repo root** — it's the operator entry point (3-minute bootstrap + 15-minute first cycle). This AGENTS.md file is your binding context for what to do on every action; QUICKSTART is what the operator reads first.

Authority: this file is a TIER-2 operator-surface convention; it composes on (does not supersede) the TIER-0 supreme operating directive (`docs/ai-engineering-corpus.md`), the TIER-1 prime directive (`CLAUDE.md` plugin-dependency model), and the TIER-1 founder-directives rulebook (`docs/founder-directives.md`). Authority hierarchy and conflict-resolution: see CLAUDE.md and `docs/founder-directives.md §5`.

## 1. Build / test / verification commands

| Action | Command |
|---|---|
| Materialize plugin cache + skills (must run first in any session) | `./scripts/sync-plugin.sh --ensure` |
| Check plugin pin freshness only | `./scripts/sync-plugin.sh --check` |
| Run end-to-end smoke (handoff + R-G-R drive) | `./scripts/smoke-e2e.sh` |
| Run pre-commit doc-drift audit | `./scripts/audit-doc-drift.sh` |

All four exit 0 on success. The smoke script defaults to stub mode; live-Claude mode is deferred per ADR-0008.

## 2. File-scope rules (agent-edit fences)

Agents may edit files under: `AGENTS.md`, `CLAUDE.md`, `README.md`, `TICKETS.md`, `docs/`, `scripts/`, `.grok/`, `.cursor/`, `.claude/hooks/`, `.claude/settings.json`, `examples/`.

Agents MUST NOT edit:

- `.harness/plugin-cache/` — generator-managed via `sync-plugin.sh`. Hand-edits violate R-2 (Versioned consumption); they are clobbered on the next ensure.
- `claude-tdd-pro/` (sibling repo, if present) — TIER-1 prime-directive invariant. Cross-repo edits violate the plugin-dependency model.
- `.claude/skills/tdd-pro-*` symlinks — point at the materialized plugin cache; hand-edits silently leak into the unrelated upstream.
- `docs/founder-directives.md §1` — immutable, append-only. Per D-6, never edit any §1 entry, ever — even for typos. New §1 entries land via ADR.
- `docs/founder-directives.md §3` D-rule bodies — TIER-1 directives; amendments only via ADR.
- `.cursor/rules/*.mdc` (once shipped by TICKET-013) — generator output from `scripts/export-cursor-rules.sh`; hand-edits will be caught by audit-doc-drift.sh F-5.

## 3. Wire-format pointer (handoff contract)

The cross-tool wire format is documented in `docs/handoff-contract.md`. Two schemas:

- `§Grok→Claude` — request schema (`.harness/handoffs/TICKET-NNN.req.json`). Required fields: `schema_version`, `ticket_id`, `acceptance_criteria`, `file_scope`, `context`, `quality_gate`.
- `§Claude→Grok` — response schema (`.harness/handoffs/TICKET-NNN.res.json`). Required fields: `schema_version`, `ticket_id`, `status`, `changed_files`, `test_results`, `decision_trail_ref`, `gate_results`.

Both schemas at `schema_version: "1"`. Self-heal dispatches reuse the same schema with `SELF-HEAL-<UTC-date>-<seq>` ticket-id prefix (see `docs/self-healing-design.md`); no second wire format.

## 4. Skill enumeration (inner-loop discipline + orchestration)

Three **inner-loop discipline** skills are materialized as symlinks under `.claude/skills/` pointing into `.harness/plugin-cache/claude-tdd-pro/.claude/skills/`:

- `.claude/skills/tdd-pro-cl-workflow/SKILL.md` — the per-CL Red-Green-Refactor loop. Read BEFORE writing any spec, substrate, or commit. Enforces architecture-quote pre-flight → spec-write → self-audit → verify → propose commit.
- `.claude/skills/tdd-pro-batch-cl/SKILL.md` — substrate-touch CL batching convention. Read BEFORE planning the next CL boundary; decides when to ship multiple features as ONE commit vs. separate commits.
- `.claude/skills/tdd-pro-bash32-portability/SKILL.md` — macOS bash 3.2 + BSD-tool portability checklist. Reference BEFORE any new Write/Edit of a `.sh` file; catches the 9 recurring portability gotchas.

The three SKILL.md files are the inner-loop discipline. The harness adds no fourth core skill — per CLAUDE.md "What this repo does NOT do": *"Define a new tdd-pro-core SKILL.md. The existing trio is the core."*

One **orchestration-tier** skill lives at the harness's repo (NOT a tdd-pro-core skill — joins the trio as a sibling at the orchestration tier, not the inner-loop tier):

- `.claude/skills/orchestrating-swarms/SKILL.md` — worker-fanout coordinator for the orchestrator-worker pattern named in `docs/grok-orchestration-principles.md §§4, 9, 10` + G-7 / G-8 / G-9 / G-16. Use AFTER `/decompose` produces ≥2 atomic tickets with non-overlapping `file_scope`. Spawns one worker per ticket on its own git worktree (G-8); each worker runs the existing `tdd-pro-cl-workflow` R-G-R discipline; lead collects worker outputs and runs the per-worker quality gate. Composes on Grok's outer-loop decomposition per G-7 (does NOT replace it). Introduced in TICKET-015 / ADR-0017.

## 5. Authority-doc enumeration (TIER 0 / TIER 1 / TIER 2)

**TIER 0 — supreme operating directive:**

- `docs/ai-engineering-corpus.md` — the AI engineering corpus. Highest authority in this repo; supersedes every other rule when in conflict. Amendments only via ADR per `docs/architecture-principles.md §19`.

**TIER 1 — co-equal under TIER 0:**

- `CLAUDE.md` — prime directive (plugin-dependency model: this repo imports `claude-tdd-pro` as a versioned plugin; four invariants in §"Prime directive").
- `docs/founder-directives.md` — D-1..D-13 directives derived from immutable §1 provenance (Karpathy's agentic-engineering shift; Musk's 5-step Algorithm; xAI Grok Build CLI announcement; Anthropic's "Building Effective Agents" + "Best practices for Claude Code"; Amodei's "Machines of Loving Grace"; @teslayoda + @elonmusk 2026-05-24 X posts).

**TIER 2 — operational rulebooks:**

- `docs/architecture-principles.md` — R-1..R-20 (microservice loose coupling, Twelve-Factor, ADR discipline).
- `docs/grok-orchestration-principles.md` — G-1..G-21 (Grok-as-outer-loop orchestrator; AGENTS.md surface convention at §8).
- `docs/claude-tdd-pro-principles.md` — active harness-side C-rules (C-1, C-22, C-23, C-24); 20 inner-loop discipline rules consolidated to upstream plugin per Musk #1 / ADR-0033 (intellectual provenance retained §§1-15).
- `docs/quality-gate.md` — four sub-gates (`tests_must_pass`, `coverage_delta_min`, `lint_clean`, `provenance_complete`).
- `docs/self-healing-design.md` — design for long-running outer-loop monitor; implementation deferred per ADR-0011.
- `docs/handoff-contract.md` — wire format (see §3 above).
- `docs/provenance-bridging-design.md` — design for the per-ticket provenance manifest at `.harness/audit/TICKET-NNN.manifest.json` bridging Grok's `research_refs` + Claude's decision trail + `.res.json` `gate_results` into a single audit entry point; emitter + validator + `--regenerate` CLI shipped in TICKET-010.a..c per ADRs 0019/0020/0021.
- `docs/researcher-discipline.md` — operational rulebook for `docs/founder-directives.md §1` source verification: WebFetch → WebSearch → cross-attribute fallback chain when the harness's outbound proxy returns `host_not_allowed`; T-A/T-B/T-C/T-D tier mapping; cross-source acceptance bar (≥ 3 sources + primary-operated anchor for T-C); anti-patterns. Per ADR-0023.
- `docs/rulebook-coverage-audit.md` — TIER-2 audit report (captured 2026-05-26) measuring operational citation count per D/R/G/C-rule across the codebase; identifies 40 zero-citation candidates (51% of 78 rules) for future archival/consolidation review. Re-runnable via `scripts/audit-rulebook-coverage.sh`. Per ADR-0031 (Fowler critique #1 closure).
- `docs/security-review.md` — TIER-2 operational rulebook codifying the harness's code-execution-surface threat model + six-pattern shell-security scan policy (S-1 eval, S-2 curl\|bash, S-3 rm -rf, S-4 hardcoded credentials, S-5 sudo, S-6 bash -c with unquoted var) + baseline-tolerant exit policy. Re-runnable via `scripts/audit-hook-security.sh`; baseline at `tests/hook-security-baseline.txt`. Per ADR-0034 (Musk Engineering Leadership letter #4 closure).
- `docs/dora-metrics.md` — TIER-2 operational rulebook operationalizing C-24 (DORA metrics are the scoreboard). Computes 3 of the 4 DORA Four Keys (Deployment frequency, Change failure rate, Lead time for changes) from the existing `.harness/audit/*.manifest.json` corpus; Time to restore deferred to v2. Re-runnable via `scripts/audit-metrics.sh` (human / `--json` / `--quiet` modes). Per ADR-0035 (Musk Engineering Leadership letter #3 closure).
- `docs/claude-code-upgrade-strategy.md` — TIER-2 operational rulebook documenting the harness's host-CLI (Claude Code) upgrade posture. Mirrors the plugin-pin discipline (declared range + drift detect + ADR-gated bumps + contract tests) for Claude Code itself. Per ADR-0036 (Musk-letter-class upgrade discipline; symmetric with ADR-0001 + ADR-0025).
- `docs/claude-code-upgrade-runbook.md` — TIER-2 operator procedure for Claude Code version bumps: pre-upgrade checklist → upgrade → verification chain → decision tree (green/red) → rollback path → post-upgrade smoke → AUTOMATION_INTEL recording → anti-patterns. Re-runnable via `scripts/audit-claude-code-compat.sh`. Per ADR-0036.
- `docs/plugin-surface-consumption.md` — TIER-2 registry of every plugin top-level surface (39 entries) classified CONSUMED / DECLARED-NOT-CONSUMED with ADR rationale. Per TICKET-032 / ADR-0037; enforced by `scripts/audit-plugin-surface.sh` at SessionStart and pre-commit.
- `docs/deviations.md` — TIER-2 append-only registry of accepted deviations from operator-declared standards in `.harness/rules/active.json`. Each row: rule_id, file_scope, justification, ADR, expiry_trigger. Per TICKET-032 / ADR-0037; enforced by `scripts/audit-standards-conformance.sh` + the PostToolUse hook.

Conflict-resolution: TIER 0 > TIER 1 > TIER 2. Within TIER 1, prime-directive vs. founder-directives conflicts must be raised explicitly — neither defers to the other by default. See `CLAUDE.md` and `docs/founder-directives.md §5`.

## 6. Outer-loop template pointers

The outer loop (research / decomposition / dispatch) is template-driven, not code-driven. Templates live at:

- `.grok/templates/research.md` — produce structured `research_refs` for a topic.
- `.grok/templates/architecture-consult.md` — **SUPERSEDED by ADR-0040 (TICKET-035).** The per-feature consult is replaced by static context injection at session start (`.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md`, copied from the pinned plugin by `scripts/sync-plugin.sh --ensure`). Template body retained per Nygard append-only; do not invoke.
- `.grok/templates/decomposition.md` — turn research into atomic, contract-shaped tickets. Consults the static planner context for test-shape patterns, refactor sequencing, mutation seams, ADR triggers, and Bash 3.2 portability gotchas.
- `.grok/templates/dispatch.md` — emit a contract-valid `.harness/handoffs/TICKET-NNN.req.json` for one ticket; populates `applicable_rules` from `.harness/rules/active.json` filtered by detected language.

Any agent capable of following structured-output instructions can drive these. The original driver was Grok CLI (`grok -p`); Cursor's chat agent, Claude Code, and other AGENTS.md-conformant tools drive them equivalently by reading the template and following its documented output schema.

## 7. Session-start ritual

**First action in any session: `./scripts/sync-plugin.sh --ensure`.** This materializes the pinned plugin commit under `.harness/plugin-cache/claude-tdd-pro/`, validates the symlinks at `.claude/skills/`, and reports plugin/upstream drift. Without it, the SKILL.md files enumerated in §4 will not resolve.

**Second action: `./scripts/standards-sync.sh`** (per TICKET-032 / ADR-0037). This aggregates the plugin's standards pipeline (`standards/sources.yaml` → `rubric/aggregator.sh` → `generated-code-quality-standards/*`) into `.harness/rules/active.json` — the operator-declared rule registry covering OWASP ASVS + Top 10, Google TS/JS/Python style guides, SLSA build provenance, WCAG 2.2, Web Vitals, React + Next.js, Node.js best practices, TypeScript handbook. **Both Grok and Claude MUST read `.harness/rules/active.json` and treat it as TIER-1 binding** when handling any ticket that touches application code. Grok populates `applicable_rules` in the request; Claude returns `rules_verified` in the response. See `docs/quality-gate.md §lint_clean` for enforcement details and `docs/handoff-contract.md` for the contract surface.

**EO-2026 governance (standing, cross-cutting — per ADR-0045/0046/0047/0048; mirrors `CLAUDE.md`).** The 2026-06-02 Executive Order *"Promoting Advanced AI Innovation and Security"* is a first-class, always-on member of the operator-declared-standards regime — it patterns quality, process, and security across **every** ticket/handoff/CL, not as a siloed feature. Mechanics both agents MUST honor: (1) **additive, never subtractive** — the EO layer only ADDS rules/gates/attestations on top of the base standards; it never relaxes them (ADR-0047). (2) **Non-exemptible** — Grok MUST include every EO-namespace rule (`source_namespace: eo`) in `applicable_rules` on every ticket; no per-ticket exemption (ADR-0045). (3) **Two-phase** — the EO governs both the design Claude TDD Pro produces *before* it codes AND the code; a `green` response MUST carry a non-empty `eo_design_conformance` attesting design-phase conformance (ADR-0046). (4) **Rule content is the plugin's, enforcement is the harness's** — EO rule content is authored in `claude-tdd-pro` and arrives via `active.json` on a pin bump; the harness never forks EO rules. Verified by `scripts/audit-eo-governance.sh`. Design + decision records: `docs/eo-2026-ai-innovation-security-alignment.md` + ADR-0043..0048.

Equivalent intent across tools:

| Tool | Session-start mechanism |
|---|---|
| Claude Code | Automatic via `.claude/hooks/session-start.sh` (configured in `.claude/settings.json`). |
| Cursor (and other AGENTS.md consumers) | Read `.cursor/rules/agent-context.mdc` (once shipped by TICKET-013) which instructs the agent to run `./scripts/sync-plugin.sh --ensure` before any other action. Cursor lacks a push-hook mechanism; always-loaded rules are the equivalent surface. |
| Grok Build / Codex / Amp / Jules / Factory | This file. Run `./scripts/sync-plugin.sh --ensure` as your first command. |

The script is idempotent — repeated calls without upstream changes are no-ops.

## 8. Pre-commit gates

Before every commit:

1. **`./scripts/audit-doc-drift.sh`** — exit 0 required. Catches stale stubs (F-1), stale README framing (F-2), future-tense references to DONE tickets (F-3), `sync-plugin.sh` impl-vs-help drift (F-4), and (once TICKET-013 lands) hand-edits to `.cursor/rules/*.mdc` generator output (F-5).
2. **`docs/founder-directives.md §4` D-checklist** — walk D-1..D-13 + Q-DOC-DRIFT. If a directive is not satisfied, document the rationale in the commit body or raise the conflict before committing.
3. **`docs/architecture-principles.md §17` R-checklist** — apply when the change is architecturally significant.
4. **`docs/grok-orchestration-principles.md §16` G-checklist** — apply when the change touches `.grok/`, AGENTS.md, the handoff layer, or other Grok-facing config.
5. **`docs/claude-tdd-pro-principles.md §17` C-checklist** — apply when the change is inside acceptance-tested scope (inner-loop code, tests, refactors).
6. **TIER-0 corpus pre-commit checklist** — applied first, per CLAUDE.md §"Supreme operating directive."

Commit message format: `TICKET-NNN: <verb> <object>` (see `TICKETS.md §Conventions`).

## Composition + provenance

This file composes on:

- `docs/grok-orchestration-principles.md §8` — G-rule that names AGENTS.md as the cross-tool surface and mandates repo-root placement.
- `docs/handoff-contract.md` — wire format (§3).
- `docs/founder-directives.md §4` — pre-commit checklist (§8).
- `.claude/skills/tdd-pro-*/SKILL.md` (via plugin cache) — inner-loop discipline (§4).
- `.grok/templates/*.md` — outer-loop templates (§6).

This file does NOT duplicate the content it points at (per R-3 single-source-of-truth). Pointers may need re-pointing when a source-of-truth moves, but the content here is read-only against the sources.

History: introduced in TICKET-011 (ADR-0012 — AGENTS.md as cross-tool surface). D-1 bidirectional attribution policy: ADR-0013.
