# hybrid-harness-proto

A prototype harness that pairs **Grok Build CLI** (outer loop — research, decomposition, coordination, deployment) with **Claude TDD Pro** (inner loop — Red-Green-Refactor enforcement via existing `tdd-pro-*` skills).

## Why this exists

Enterprise engineering orgs (1,000+ ICs) need both pipeline-level automation AND quality discipline that survives velocity. Grok Build CLI is strong on the outer loop; Claude TDD Pro is strong on the inner loop. This repo is the design + integration substrate that lets them compose.

## How to read this repo

Read in this order:

1. `docs/architecture.md` — the harness architecture and role split
2. `TICKETS.md` — the ordered backlog (TICKET-001 .. TICKET-010)
3. `AUTOMATION_INTEL.md` — Boston/US enterprise signal log
4. `CLAUDE.md` — workflow rules when Claude Code operates inside this repo

The `docs/`, `.grok/`, `.claude/`, and `examples/` subtrees contain stubs that are filled in by individual tickets.

## Status

Design-only. No code yet. TICKET-001 lands the scaffold (this commit). All other tickets land in subsequent CLs.

## Reused assets

This repo does not duplicate Claude TDD Pro's quality core. It consumes three skills from `claude-tdd-pro/.claude/skills/`:

- `tdd-pro-cl-workflow`
- `tdd-pro-batch-cl`
- `tdd-pro-bash32-portability`

Wiring is defined in TICKET-004.
