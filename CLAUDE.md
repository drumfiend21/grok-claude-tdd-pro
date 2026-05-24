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
