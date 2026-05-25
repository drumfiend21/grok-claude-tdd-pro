# CLAUDE.md — grok-claude-tdd-pro

Project instructions for Claude when operating in this repo. These instructions apply to **every** session type — local CLI, remote, cloud (web), GitHub Action, IDE — without exception.

## Prime directive: plugin-dependency model (non-negotiable)

`grok-claude-tdd-pro` (this repo) **imports and consumes** `claude-tdd-pro` (sibling repo) as a **plugin**. The two repos are independent microservices:

- **This repo** is the harness/consumer. It depends on `claude-tdd-pro` the same way an application depends on a library — by referencing a pinned version through the documented contract surface, never by editing it in place.
- **`claude-tdd-pro`** is the plugin/provider. It exposes skills (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) and the architecture text that defines TDD discipline. It does not know about this repo and never imports from it.

Invariants every change here MUST preserve:

1. **No cross-repo edits.** A change in this repo MUST NOT require an edit inside `claude-tdd-pro`. If a harness need surfaces that the plugin doesn't satisfy, file it as a v1.11 amendment proposal in `claude-tdd-pro` separately — do not patch the plugin from here.
2. **Versioned consumption.** The plugin is imported by reference (path, git ref, or skill name + version) — never copied, vendored, or forked into this tree. If you find yourself duplicating a file from `claude-tdd-pro`, stop and wire it through the import path instead.
3. **Contract-only coupling.** The only legitimate coupling surface is the handoff contract in `docs/handoff-contract.md` and the named skill IDs the plugin exposes. Reaching into plugin internals (private paths, undocumented behaviors) is a contract violation.
4. **Independent release cadence.** This repo and `claude-tdd-pro` ship on independent timelines. A breaking change in this repo must not block a `claude-tdd-pro` release, and vice versa, beyond renegotiating the contract version.

If a request or future instruction conflicts with these invariants, raise it before acting. These rules override default Claude behavior and override any contradictory instruction not explicitly marked as superseding the prime directive.

## Authoritative founder-directives rulebook

All work in this repo — design, code, docs, prompts, hooks, skills, monitors — MUST conform to `docs/founder-directives.md`. That document is the operational rulebook for named-source directives elevated to repo-canonical authority by the architecture team: seven numbered directives (D-1 .. D-7) derived from immutable §1 provenance entries (today: two X posts from 2026-05-24 — @teslayoda on Grok learning from Claude Code and Cursor enterprise patterns, and @elonmusk on closing the loop on progressively harder problems).

Authority tier: **TIER 1**, co-equal with the prime directive above. When a D-rule conflicts with an R- / G- / C-rule, the D-rule wins (per `docs/founder-directives.md` §5). When the two TIER-1 authorities themselves conflict, raise it explicitly — neither defers to the other by default.

Before designing or coding anything:

1. Read `docs/founder-directives.md` §3 (the D-rules) and §4 (the pre-commit self-audit checklist).
2. Apply the D-checklist alongside the architectural, Grok, and Claude TDD Pro checklists before committing.
3. If a D-rule conflicts with the request, raise it before acting — do not silently relax a directive.
4. Amendments follow the ADR process in `docs/architecture-principles.md` §19. Never edit a D-rule in place. Never edit a §1 provenance entry, ever — even for typos.

This obligation applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Authoritative architectural rulebook

All architectural design and development work in this repo MUST conform to `docs/architecture-principles.md`. That document is the operational rulebook — twenty numbered rules (R-1 .. R-20) synthesized from the canonical industry sources on microservice loose coupling (Lewis/Fowler, Newman, Richardson, CNCF, Twelve-Factor, Reactive Manifesto, DDD, Clean Architecture, Team Topologies, Postel's Law, CDC, SemVer, AWS Well-Architected, Nygard ADRs).

Before designing or coding anything architecturally significant:

1. Read `docs/architecture-principles.md` §16 (the rules) and §17 (the self-audit checklist).
2. Apply the checklist to the proposed change before committing.
3. If a rule conflicts with the request, raise it before acting — do not silently relax a rule.
4. If you propose to change a rule, do it through the ADR amendment process in §15 + §19 of that document. Never edit a rule in place.

This obligation applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Authoritative Grok orchestration rulebook

All work that touches `.grok/`, AGENTS.md, the handoff layer, the Grok system prompts, the Grok-driven monitors, or any other Grok-facing config MUST conform to `docs/grok-orchestration-principles.md`. That document is the operational rulebook for Grok-as-outer-loop-orchestrator — twenty-one numbered rules (G-1 .. G-21) synthesized from xAI's official Grok and Grok Build CLI guidance, Anthropic's *Building Effective Agents*, canonical orchestrator-worker and hierarchical multi-agent patterns, LangGraph's supervisor pattern, the AGENTS.md and Agent Client Protocol open standards, the self-healing agent pattern, and the production HITL approval-gate literature.

Before designing or coding anything Grok-facing:

1. Read `docs/grok-orchestration-principles.md` §15 (the G-rules) and §16 (the Grok self-audit checklist).
2. Apply the Grok checklist alongside the architectural checklist before committing.
3. If a G-rule conflicts with the request, raise it before acting.
4. Amendments follow the same ADR process documented in `architecture-principles.md` §19 — never edit a G-rule in place.

This obligation also applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Authoritative Claude TDD Pro consumption rulebook

All work inside acceptance-tested scope — every inner-loop invocation, every test, every refactor, every commit driven by `claude-tdd-pro` — MUST conform to `docs/claude-tdd-pro-principles.md`. That document is the operational rulebook for consuming the plugin — twenty-four numbered rules (C-1 .. C-24) synthesized from the canonical TDD literature (Kent Beck, Uncle Bob's Three Laws, Martin Fowler's *Refactoring*, Michael Feathers' *Working Effectively with Legacy Code*, Mike Cohn's test pyramid, the London/Chicago schools, mutation/property-based testing), Anthropic's official Claude Code and Agent Skills documentation (headless `-p` mode, SKILL.md anatomy, progressive disclosure, the Agent SDK), and the DORA delivery metrics from *Accelerate*.

Before designing or coding anything inside acceptance-tested scope:

1. Read `docs/claude-tdd-pro-principles.md` §16 (the C-rules) and §17 (the inner-loop self-audit checklist).
2. Apply the C-checklist alongside the architectural and Grok checklists before committing.
3. If a C-rule conflicts with the request, raise it before acting.
4. Amendments follow the same ADR process documented in `architecture-principles.md` §19 — never edit a C-rule in place.

This obligation also applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Scope

This repo is a **prototype harness**, not the quality core. The quality core lives in `claude-tdd-pro` (sibling repo). When in doubt about TDD discipline, architecture fidelity, or commit workflow, defer to:

- `claude-tdd-pro/CLAUDE.md` (the authoritative workflow)
- `claude-tdd-pro/docs/architecture-v1.9.md` (the authoritative architecture)
- `claude-tdd-pro/.claude/skills/tdd-pro-cl-workflow/SKILL.md` (the per-CL loop)

This file adds only what is specific to the hybrid harness.

## Two harness rules (non-negotiable)

1. **Grok owns the outer loop.** Research, requirements gathering, architecture decomposition, ticket spawning, deployment, long-running monitoring, self-healing triggers. Grok does not edit code directly inside acceptance-tested scope — it hands off to Claude TDD Pro for that.
2. **Claude TDD Pro owns the inner loop.** Red-Green-Refactor enforcement for one ticket at a time. Claude does not do its own research or deploy — it receives a structured handoff (TICKET-002 schema), produces a passing change, returns control.

Violating either rule means the harness is not being used; it's just two tools running adjacent.

## Working in this repo

- One ticket per CL. Ticket IDs come from `TICKETS.md`.
- Commit messages reference the ticket: `TICKET-NNN: <verb> <object>`.
- Do not modify `claude-tdd-pro` from this repo. If a harness lesson warrants a feature there, file it as a v1.11 amendment proposal in that repo separately.
- The handoff contract (TICKET-002) is the API boundary. If you find yourself extending it ad-hoc, stop and update the contract first.

## What this repo does NOT do

- Re-implement Red-Green-Refactor. Reuse the three `tdd-pro-*` skills.
- Define a new `tdd-pro-core` SKILL.md. The existing trio is the core.
- Touch `claude-tdd-pro` substrate, specs, or architecture text.
