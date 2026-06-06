# Plugin Surface Consumption Registry

**Authority tier:** TIER 2 (operational registry). Per TICKET-032 / ADR-0037, this registry enumerates every top-level entry in the pinned `claude-tdd-pro` plugin cache and declares its consumption status from the harness side. Amendments via ADR per `docs/architecture-principles.md §19`.

**Why this exists:** The harness was historically scoped to consume only three SKILLs (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`). The plugin grew to 39+ top-level surfaces (standards, rubric, generated-code-quality-standards, pr-corpus, compliance, monitors, etc.) without the harness acknowledging any of them. This registry forces explicit acknowledgment: every plugin surface is either CONSUMED (with the wire documented) or DECLARED-NOT-CONSUMED (with an ADR rationale).

**Enforcement:** `scripts/audit-plugin-surface.sh` walks `.harness/plugin-cache/claude-tdd-pro/` and exits 1 on any UNKNOWN surface. Wired into the pre-commit audit chain. Re-runnable.

## Status legend

- **CONSUMED** — the harness actively reads, runs, or symlinks this surface; the wire is documented.
- **DECLARED-NOT-CONSUMED** — the harness explicitly does not consume this surface; ADR records why.
- **UNKNOWN** — registry rows must classify; UNKNOWN is a regression caught by the audit.

## Registry

| Plugin entry | Status | Wire / ADR |
|---|---|---|
| `BACKLOG.md` | DECLARED-NOT-CONSUMED | Plugin-internal backlog; harness has its own `TICKETS.md`. ADR-0037. |
| `CLAUDE.md` | DECLARED-NOT-CONSUMED | Plugin's session prompt; harness has its own `CLAUDE.md` at TIER-1. ADR-0037. |
| `INSTALL.md` | DECLARED-NOT-CONSUMED | Plugin install procedure (irrelevant to harness consumption model). ADR-0037. |
| `QUALITY-BAR.md` | CONSUMED via `docs/quality-gate.md` cross-reference | `docs/quality-gate.md` `lint_clean` sub-gate composes on §2.8 surface. |
| `README.md` | DECLARED-NOT-CONSUMED | Plugin-internal docs. ADR-0037. |
| `SECURITY.md` | DECLARED-NOT-CONSUMED | Plugin-internal security posture; harness has its own `docs/security-review.md` per ADR-0034. ADR-0037. |
| `agents` | DECLARED-NOT-CONSUMED | Plugin-internal agent definitions; harness uses Claude Code directly. ADR-0037. |
| `ci` | DECLARED-NOT-CONSUMED | Plugin's CI workflows; harness CI deferred per ADR-0028. ADR-0037. |
| `commands` | DECLARED-NOT-CONSUMED | Plugin's slash commands; harness has its own `.cursor/commands/`. ADR-0037. |
| `community` | DECLARED-NOT-CONSUMED | Plugin-internal community docs. ADR-0037. |
| `compliance` | CONSUMED via `scripts/standards-sync.sh` AIBOM hook (Batch 5+) | Wire ships in TICKET-032 follow-on batch; v1 status: declared, wire-in-progress. |
| `cross-loop` | DECLARED-NOT-CONSUMED | Cross-loop wiring is plugin-internal (Grok-via-plugin); harness handles outer loop directly. ADR-0037. |
| `docs` | DECLARED-NOT-CONSUMED | Plugin's internal docs (architecture-v1.9.md is referenced by hash via `docs/claude-tdd-pro.lock.yaml` contract surface). ADR-0037. |
| `evals` | CONSUMED via response-gate hook (planned Batch 6) | v1 status: declared, wire-in-progress. |
| `formatters` | CONSUMED via PostToolUse standards check (Batch 4) | v1 status: declared, wire-in-progress. |
| `generated-code-quality-standards` | CONSUMED via `scripts/standards-sync.sh` (Batch 2) | `.harness/rules/active.json` aggregation source. |
| `git` | DECLARED-NOT-CONSUMED | Plugin's git tooling; harness uses git directly. ADR-0037. |
| `hooks` | DECLARED-NOT-CONSUMED | Plugin's hook templates; harness has its own `.claude/hooks/`. ADR-0037. |
| `import` | DECLARED-NOT-CONSUMED | Plugin's project-import tooling; harness consumption-model uses sync-plugin instead. ADR-0037. |
| `lib` | DECLARED-NOT-CONSUMED | Plugin-internal helpers; harness re-implements where needed (per C-23 bash 3.2 portability). ADR-0037. |
| `meta-eval` | DECLARED-NOT-CONSUMED | Plugin-internal evaluation harness; harness has `tests/test-all.sh`. ADR-0037. |
| `metrics` | DECLARED-NOT-CONSUMED | Plugin's metrics infra; harness has `scripts/audit-metrics.sh` per ADR-0035. ADR-0037. |
| `migrations` | CONSUMED via `scripts/sync-plugin.sh` (existing) | Pin bumps consult `migrations/` per ADR-0025 pattern. |
| `monitors` | DECLARED-NOT-CONSUMED | Plugin's long-running monitors; harness self-healing deferred per ADR-0011. ADR-0037. |
| `output-styles` | DECLARED-NOT-CONSUMED | Plugin-internal output formatting; harness handles its own. ADR-0037. |
| `pr-corpus` | CONSUMED via peer-review hook (planned Batch 6) | v1 status: declared, wire-in-progress. |
| `profiles` | DECLARED-NOT-CONSUMED | Plugin's per-team profile templates; harness is single-operator. ADR-0037. |
| `prompts` | DECLARED-NOT-CONSUMED | Plugin's prompt templates; harness uses `.grok/templates/`. ADR-0037. |
| `rubric` | CONSUMED via `scripts/standards-sync.sh` (Batch 2) + PostToolUse hook (Batch 4) | `rubric/aggregator.sh` + `rubric/runner.sh` are the consumption surface. |
| `rule-engine` | CONSUMED via rubric/runner.sh transitively (Batch 4) | Wired indirectly through the rubric. ADR-0037. |
| `schemas` | DECLARED-NOT-CONSUMED | Plugin-internal JSON schemas; harness handoff-contract.md is its own schema. ADR-0037. |
| `scripts` | DECLARED-NOT-CONSUMED | Plugin's substrate scripts; harness has its own `scripts/`. ADR-0037. |
| `seed` | DECLARED-NOT-CONSUMED | Plugin's seed data; not applicable to harness. ADR-0037. |
| `skills` | CONSUMED via symlinks (existing TICKET-004 / ADR-0007) | `.claude/skills/tdd-pro-*` symlinks into `skills/tdd-pro-*`. |
| `space` | DECLARED-NOT-CONSUMED | Plugin-internal scratch space. ADR-0037. |
| `standards` | CONSUMED via `scripts/standards-sync.sh` (Batch 2) | `standards/sources.yaml` is the canonical authority inventory. |
| `templates` | DECLARED-NOT-CONSUMED | Plugin's template scaffolding; harness uses its own. ADR-0037. |
| `tui` | DECLARED-NOT-CONSUMED | Plugin's TUI; harness has no TUI. ADR-0037. |
| `workflow` | DECLARED-NOT-CONSUMED | Plugin's workflow orchestration; harness's outer loop is Grok-driven per CLAUDE.md prime directive. ADR-0037. |

## Audit invariant

Pre-commit and SessionStart must both verify `scripts/audit-plugin-surface.sh` exits 0. Any plugin pin bump that introduces a new top-level directory will fail this audit until a row is added to the registry.

## Composition

- `scripts/audit-plugin-surface.sh` — the audit script.
- `scripts/sync-plugin.sh` — the pin sync that materializes the plugin cache.
- `docs/handoff-contract.md` — the contract surface (now extended with `applicable_rules` + `rules_verified` per Batch 3).
- ADR-0037 — records this registry's design + the wire CL sequence.
