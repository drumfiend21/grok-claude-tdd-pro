# grok-claude-tdd-pro

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

TICKETS 001–006 shipped (plus the TIER-0 / TIER-1 rulebook expansion sub-tickets 001.e–001.j). The harness is wired end-to-end:

- Outer-loop substrate: three Grok prompt templates under `.grok/templates/` (research, decomposition, dispatch) per ADR-0006.
- Handoff contract: `docs/handoff-contract.md` — the JSON schemas Grok and Claude exchange.
- Inner-loop wiring: `.claude/skills/` symlinks resolve into a pinned, runtime-materialized cache of the `claude-tdd-pro` plugin per ADR-0007.
- Demo target: `examples/string-utils/` ships at 4 pass / 1 fail; one designed Red test that the inner loop closes.
- End-to-end smoke: `./scripts/smoke-e2e.sh` runs one full Red-Green-Refactor cycle through the wire format and exits 0 (per ADR-0008). Trap reverts the toy to Red baseline so re-runs are idempotent.

Pending: TICKETS 007–010 (quality-gate contract, self-healing extension design, Boston demo storyboard, provenance bridging).

## Reused assets

This repo does not duplicate Claude TDD Pro's quality core. It consumes three skills from `claude-tdd-pro/.claude/skills/`:

- `tdd-pro-cl-workflow`
- `tdd-pro-batch-cl`
- `tdd-pro-bash32-portability`

Wired by TICKET-004 (ADR-0007). The skill mechanism is described in [`.claude/README.md`](.claude/README.md).

## Plugin sync

The plugin dependency on `claude-tdd-pro` is pinned in [`docs/claude-tdd-pro.lock.yaml`](docs/claude-tdd-pro.lock.yaml) and reconciled on every session start. See [`docs/plugin-sync.md`](docs/plugin-sync.md) for how to read the drift report, when to bump the pin, and what triggers an ADR. Architectural rationale: [ADR-0001](docs/adr/0001-plugin-lockfile-session-sync.md).
