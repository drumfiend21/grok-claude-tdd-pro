# CLAUDE.md — hybrid-harness-proto

Project instructions for Claude when operating in this repo.

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
