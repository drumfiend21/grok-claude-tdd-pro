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
| `CHANGELOG.md` | DECLARED-NOT-CONSUMED | Plugin-internal changelog; harness tracks its own change history via TICKETS.md + AUTOMATION_INTEL.md. ADR-0041 (pin bump introduced this entry). |
| `CLAUDE.md` | DECLARED-NOT-CONSUMED | Plugin's session prompt; harness has its own `CLAUDE.md` at TIER-1. ADR-0037. |
| `CODEOWNERS` | DECLARED-NOT-CONSUMED | Plugin-internal GitHub code-ownership routing; harness is single-operator. ADR-0041. |
| `CONTRIBUTING.md` | DECLARED-NOT-CONSUMED | Plugin-internal contribution guide. ADR-0041. |
| `Dockerfile` | DECLARED-NOT-CONSUMED | Plugin's Docker image definition; harness runs in the operator's shell environment, not a container. ADR-0041. |
| `INSTALL.md` | DECLARED-NOT-CONSUMED | Plugin install procedure (irrelevant to harness consumption model). ADR-0037. |
| `COMMERCIAL-USE.md` | DECLARED-NOT-CONSUMED | Plugin-internal commercial-use posture (CTP-ADR-0008 §"sellable by construction" notes ship in the plugin tree); harness consumes the operational guarantee via `rubric/detectors/audit-commercial-license.sh` (a CONSUMED entry below), not by reading this prose doc. ADR-0070 (pin bump introduced this entry). |
| `LICENSE` | DECLARED-NOT-CONSUMED | Plugin license; harness carries its own license. ADR-0041. |
| `MAINTAINERS.md` | DECLARED-NOT-CONSUMED | Plugin-internal maintainer roster. ADR-0041. |
| `QUALITY-BAR.md` | CONSUMED via `docs/quality-gate.md` cross-reference | `docs/quality-gate.md` `lint_clean` sub-gate composes on §2.8 surface. |
| `QUICKSTART.md` | DECLARED-NOT-CONSUMED | Plugin-internal quickstart; harness has its own `QUICKSTART.md` at repo root. ADR-0041. |
| `README.md` | DECLARED-NOT-CONSUMED | Plugin-internal docs. ADR-0037. |
| `RECRUITING.md` | DECLARED-NOT-CONSUMED | Plugin-internal recruiting note. ADR-0041. |
| `SECURITY.md` | DECLARED-NOT-CONSUMED | Plugin-internal security posture; harness has its own `docs/security-review.md` per ADR-0034. ADR-0037. |
| `package.json` | DECLARED-NOT-CONSUMED | Plugin's npm manifest; harness has no npm runtime dependency on the plugin (consumes via shell + symlinks per R-2). ADR-0041. |
| `agents` | DECLARED-NOT-CONSUMED | Plugin-internal agent definitions; harness uses Claude Code directly. ADR-0037. |
| `ci` | DECLARED-NOT-CONSUMED | Plugin's CI workflows; harness CI deferred per ADR-0028. ADR-0037. |
| `commands` | CONSUMED via `scripts/standards-refresh.sh` (TICKET-075 / ADR-0064) | `commands/set-refresh-frequency.sh` is driven as the cadence-grammar authority (validates `<N>m\|h\|d\|w\|mo`). The plugin's other slash commands remain unconsumed (harness has its own `.cursor/commands/`). |
| `community` | DECLARED-NOT-CONSUMED | Plugin-internal community docs. ADR-0037. |
| `compatibility` | DECLARED-NOT-CONSUMED | Plugin-internal compatibility matrix (different concern from the harness's `docs/claude-code-compat.yaml` per ADR-0036). Trigger to revisit: operator decides to align the plugin's compatibility schema with the harness's Claude Code compat schema. ADR-0041. |
| `compliance` | CONSUMED via `scripts/smoke-e2e.sh` AIBOM emit (per TICKET-033 / ADR-0038 Batch 8) | `compliance/aibom-emit.sh` runs after green response; output at `.harness/audit/TICKET-NNN.aibom.json`. |
| `cross-loop` | DECLARED-NOT-CONSUMED | Cross-loop wiring is plugin-internal (Grok-via-plugin); harness handles outer loop directly. ADR-0037. |
| `design-tokens` | DECLARED-NOT-CONSUMED | Frontend platform addition per plugin v1.11 §26 amendment (R-9 design-token registry). Not applicable to harness substrate (bash + markdown); will become relevant when harness is used to ship a Next.js / frontend application. ADR-0041. |
| `docs` | DECLARED-NOT-CONSUMED | Plugin's internal docs (architecture-v1.9.md is referenced by hash via `docs/claude-tdd-pro.lock.yaml` contract surface). ADR-0037. |
| `evals` | CONSUMED via response-gate hook (planned Batch 6) | v1 status: declared, wire-in-progress. |
| `examples` | DECLARED-NOT-CONSUMED | Plugin's worked examples (e.g. `dog-walker-marketplace`), added upstream after the prior pin and introduced by the `bba77df`→`4354903` bump. The harness ships its own walkthrough at `docs/end-to-end-demo/`; it does not consume the plugin's examples. ADR-0052 (pin bump introduced this entry). |
| `formatters` | CONSUMED via PostToolUse hook (per TICKET-033 / ADR-0038 Batch 7) | `formatters/cli.sh --file <REL_PATH> --apply` runs after the rubric check; auto-applies formatting to app-code extensions. |
| `generated-code-quality-standards` | CONSUMED via `scripts/standards-sync.sh` (Batch 2) | `.harness/rules/active.json` aggregation source. |
| `git` | DECLARED-NOT-CONSUMED | Plugin's git tooling; harness uses git directly. ADR-0037. |
| `grok-build` | DECLARED-NOT-CONSUMED | Plugin's internal Grok Build integration scripts; harness drives Grok via its own `.grok/templates/` (research/decomposition/dispatch) and consumes the standards pipeline directly. Trigger to revisit: if `grok-build/` exposes a callable surface that materially simplifies the harness's outer-loop wiring. ADR-0041. |
| `hooks` | DECLARED-NOT-CONSUMED | Plugin's hook templates; harness has its own `.claude/hooks/`. ADR-0037. |
| `import` | DECLARED-NOT-CONSUMED | Plugin's project-import tooling; harness consumption-model uses sync-plugin instead. ADR-0037. |
| `lib` | DECLARED-NOT-CONSUMED | Plugin-internal helpers; harness re-implements where needed (per C-23 bash 3.2 portability). ADR-0037. |
| `lsp` | DECLARED-NOT-CONSUMED | Plugin's Language Server Protocol integration; harness has no LSP wire (operator works via Cursor/Claude Code editor surfaces). Trigger to revisit: a real IDE-integration use case surfaces. ADR-0041. |
| `meta-eval` | DECLARED-NOT-CONSUMED | Plugin-internal evaluation harness; harness has `tests/test-all.sh`. ADR-0037. |
| `metrics` | DECLARED-NOT-CONSUMED | Plugin's metrics infra; harness has `scripts/audit-metrics.sh` per ADR-0035. ADR-0037. |
| `migrations` | CONSUMED via `scripts/sync-plugin.sh` (existing) | Pin bumps consult `migrations/` per ADR-0025 pattern. |
| `monitors` | DECLARED-NOT-CONSUMED | Plugin's long-running monitors; harness self-healing deferred per ADR-0011. ADR-0037. |
| `output-styles` | DECLARED-NOT-CONSUMED | Plugin-internal output formatting; harness handles its own. ADR-0037. |
| `pr-corpus` | CONSUMED transitively via rubric rules + DEFERRED-findings peer-review surfacing (per TICKET-033 / ADR-0038 Batch 6) | PR-extracted patterns flow through `rubric/aggregator.sh` into rules; DEFERRED findings (rules requiring agent review like `g-eng-001-design-belongs-here`, `g-eng-002-yagni`) surfaced to stderr by PostToolUse hook as peer-review prompts. |
| `profiles` | DECLARED-NOT-CONSUMED | Plugin's per-team profile templates; harness is single-operator. ADR-0037. |
| `prompts` | DECLARED-NOT-CONSUMED | Plugin's prompt templates; harness uses `.grok/templates/`. ADR-0037. |
| `rubric` | CONSUMED via `scripts/standards-sync.sh` (Batch 2) + PostToolUse hook (Batch 4) | `rubric/aggregator.sh` + `rubric/runner.sh` are the consumption surface. |
| `rule-engine` | CONSUMED via rubric/runner.sh transitively (Batch 4) | Wired indirectly through the rubric. ADR-0037. |
| `runner-go` | DECLARED-NOT-CONSUMED | Plugin's Go-based runner; harness substrate is bash 3.2 + BSD coreutils per C-23. Trigger to revisit: a harness use case warrants Go-runtime performance. ADR-0041. |
| `scaffolds` | DECLARED-NOT-CONSUMED | Plugin's application scaffolds (e.g., O-12 next-saas per architecture-v1.9 §24). Harness substrate is not a Next.js app; will become relevant when harness is used to scaffold a frontend application. ADR-0041. |
| `schemas` | DECLARED-NOT-CONSUMED | Plugin-internal JSON schemas; harness handoff-contract.md is its own schema. ADR-0037. |
| `scripts` | DECLARED-NOT-CONSUMED | Plugin's substrate scripts; harness has its own `scripts/`. ADR-0037. |
| `seed` | DECLARED-NOT-CONSUMED | Plugin's seed data; not applicable to harness. ADR-0037. |
| `skills` | CONSUMED via symlinks (existing TICKET-004 / ADR-0007) | `.claude/skills/tdd-pro-*` symlinks into `skills/tdd-pro-*`. |
| `space` | DECLARED-NOT-CONSUMED | Plugin-internal scratch space. ADR-0037. |
| `standards` | CONSUMED via `scripts/standards-sync.sh` (Batch 2) | `standards/sources.yaml` is the canonical authority inventory. |
| `templates` | DECLARED-NOT-CONSUMED | Plugin's template scaffolding; harness uses its own. ADR-0037. |
| `tui` | DECLARED-NOT-CONSUMED | Plugin's TUI; harness has no TUI. ADR-0037. |
| `vendor` | DECLARED-NOT-CONSUMED | Plugin-internal vendored data (canonical-vocabulary mirrors at `vendor/canonical-vocabulary/{linguist-languages,purl-types,k8s-gvks,iac-dialects}.json` + `provenance.json` + `resolve.sh` + `refresh-vocabulary.sh`). Harness consumes these mirrors transitively via the composite engine entrypoints (`rubric/composite-dispatch.sh`, `rubric/enforce-file.sh`, etc.) per ADR-0068 — not by reading `vendor/` directly. ADR-0070 (pin bump introduced this entry). |
| `vscode-tdd-pro` | DECLARED-NOT-CONSUMED | Plugin's VS Code extension; harness has no VS Code wire (operator uses Cursor / Claude Code editor surfaces). ADR-0041. |
| `workflow` | DECLARED-NOT-CONSUMED | Plugin's workflow orchestration; harness's outer loop is Grok-driven per CLAUDE.md prime directive. ADR-0037. |

## Audit invariant

Pre-commit and SessionStart must both verify `scripts/audit-plugin-surface.sh` exits 0. Any plugin pin bump that introduces a new top-level directory will fail this audit until a row is added to the registry.

## Composition

- `scripts/audit-plugin-surface.sh` — the audit script.
- `scripts/sync-plugin.sh` — the pin sync that materializes the plugin cache.
- `docs/handoff-contract.md` — the contract surface (now extended with `applicable_rules` + `rules_verified` per Batch 3).
- ADR-0037 — records this registry's design + the wire CL sequence.
