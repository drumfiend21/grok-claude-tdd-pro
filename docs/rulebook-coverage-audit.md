# Rulebook coverage audit — 2026-05-26

**Status:** TIER-2 audit report (composes on `scripts/audit-rulebook-coverage.sh`).
**Authority:** TIER-2 operational rulebook category (sibling to `quality-gate.md`, `self-healing-design.md`, etc.). Originating ADR: ADR-0031.
**Captures:** state of rulebook-clause operational citation as of TICKET-026 (2026-05-26).

## §1 Purpose

Closes Fowler critique #1: *"You have 13 D-rules + 20 R-rules + 21 G-rules + 24 C-rules + 7 TIER-2 design docs + 27 ADRs + 8 SKILL.md files + 4 cursor-rule files + 7 slash commands. The actual substrate is ~6 bash scripts + 1 hook + ~5 markdown templates + ~50 lines of node-in-bash glue. The discipline-to-code ratio is ~10:1. Specific recommendation: do an honest audit of which rulebook clauses have ever been operationally invoked vs. cited."*

This is that audit. It quantifies citation count per rule across the operational surface area (ADRs, scripts, hooks, skills, TIER-2 design docs, root-level docs) — explicitly excluding the rule's own source rulebook and this audit's own infrastructure.

## §2 Audit run + summary findings

Audit executed via `scripts/audit-rulebook-coverage.sh` on 2026-05-26 against the main branch at commit `38d6617`.

| Rulebook | Source | Total rules | Zero-citation | Low-citation (1-2) | Total citations |
|---|---|---|---|---|---|
| D-rules | `docs/founder-directives.md §3` | 13 | **1** (8%) | 1 | 158 |
| R-rules | `docs/architecture-principles.md` | 20 | **12** (60%) | 2 | 95 |
| G-rules | `docs/grok-orchestration-principles.md` | 21 | **7** (33%) | 6 | 70 |
| C-rules | `docs/claude-tdd-pro-principles.md` | 24 | **20** (83%) | 1 | 30 |
| **Total** | — | **78** | **40 (51%)** | 10 | 353 |

**Headline finding:** **51% of rulebook clauses have zero external citations.** Fowler's critique was numerically accurate.

## §3 Zero-citation candidates (by rulebook)

These rules are defined in their source rulebook but never invoked elsewhere in the operational surface. Candidates for archival or consolidation review.

### §3.1 D-rules (1 candidate)

- **D-4** — *"Each CL attacks a problem strictly harder than the previous."* — Cited in commit-message bodies historically (not counted; per D-8 commit-message-only citations don't establish operational usage), but not in any TIER-2 doc / script / ADR §Decision body. Likely a real candidate for consolidation into D-13 (context-as-fundamental-constraint) or explicit retention with a usage-strengthening pass.

### §3.2 R-rules (12 candidates — the largest gap)

- **R-4** — Twelve-Factor configuration.
- **R-6** — DDD bounded contexts.
- **R-7** — Clean Architecture layering.
- **R-8** — Team Topologies cognitive load.
- **R-9** — Postel's Law tolerance.
- **R-10** — Consumer-Driven Contract testing.
- **R-13** — AWS Well-Architected reliability pillar.
- **R-14** — Nygard release-stability rule.
- **R-15** — Sidecar / adapter pattern.
- **R-16** — Circuit breaker / bulkhead.
- **R-17** — Event-driven loose coupling.
- **R-18** — Saga / eventual consistency.

**Pattern:** these are textbook microservices / distributed-systems rules synthesized from canonical sources, but the harness is a single-process single-repo CLI tool. The rules are conceptually correct citations of the literature but operationally irrelevant to this harness's scope at v1.

### §3.3 G-rules (7 candidates)

- **G-2** — Headless-first invocation (the harness defaults to it, but no doc cites the rule explicitly).
- **G-3** — Structured Output via JSON Schema.
- **G-6** — One ticket = one handoff document.
- **G-11** — ACP for agent-to-agent on the same boundary.
- **G-14** — Self-healing Detect → Diagnose → Heal → Verify cadence.
- **G-17** — Research belongs to the outer loop.
- **G-20** — Explicit model escalation.

**Pattern:** these are either (a) tacitly enforced by existing primitives without explicit rule citation, or (b) referencing deferred mechanisms (self-healing implementation, ACP, model escalation policy) that have not yet shipped operational code.

### §3.4 C-rules (20 candidates — the most-dead rulebook)

C-rules 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21.

**Pattern:** C-rules govern inner-loop discipline (TDD, refactoring, batch CLs). The harness DELEGATES inner-loop discipline to the plugin's SKILL.md trio (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`), per the CLAUDE.md prime directive ("This repo does NOT: Re-implement Red-Green-Refactor. Reuse the three `tdd-pro-*` skills"). The C-rules are imported as a TIER-2 authority surface but operationally referenced only inside the upstream plugin, not inside the harness.

**This is the biggest finding.** 20 of 24 C-rules are TIER-2 authority surface that the harness consumes by-reference but never cites operationally. The honest TIER-2 catalog would point at `claude-tdd-pro/docs/claude-tdd-pro-principles.md` (upstream) rather than maintaining a harness-side copy.

## §4 Recommendations (per ADR-0031)

This audit IS the value-add. **Actual deletion / consolidation is deferred** per D-8 (deletion discipline + the over-engineering filter): mass-deleting 40 rules in one CL would be high-risk + violate the architect-only review pattern even with the `Second voice` field from ADR-0029.

Proposed sequencing (each is its own future CL when triggered):

1. **C-rule consolidation:** the largest cohort. Replace harness-side `docs/claude-tdd-pro-principles.md` with a pointer to the upstream rulebook + a thin harness-specific composition note. Eliminates 20-22 dead C-rules from the harness's authority surface. **Trigger:** architect signals readiness for the structural simplification.

2. **R-rule audit:** the 12 microservices-pattern rules need a rationale-or-archive decision. Some may be aspirational future scope (event-driven, sagas) and should be marked as such; others (R-6 DDD, R-7 Clean Architecture) may be intellectually-cited rather than operationally-load-bearing. **Trigger:** a future CL touches the architecture rulebook anyway.

3. **G-rule rationalization:** 7 candidates split between "tacitly enforced" (G-2 headless-first) and "deferred-mechanism" (G-14 self-healing, G-11 ACP). The tacit cases need an explicit usage pass; the deferred cases need a "trigger" tag like other deferred items have. **Trigger:** self-healing implementation kicks off (per ADR-0011 deferral).

4. **D-rule retention:** only D-4 is a candidate; likely retain with a usage-strengthening pass in a future commit-discipline ADR.

**Net effect after the proposed sequencing:** rulebook footprint could plausibly drop from 78 rules to ~45-50 rules (~35% reduction), with the deleted rules either (a) pointed at upstream (C-rule pointer pattern), (b) tagged as aspirational future scope (R-rule cohort), or (c) deferred-mechanism markers (G-rule cohort).

## §5 What this audit explicitly does NOT do

- **Does NOT delete any rule.** This audit reports findings only.
- **Does NOT mass-rewrite the rulebooks.** Each consolidation is its own ADR-disciplined CL.
- **Does NOT count commit-message-body citations.** Those are historical record; operational usage requires citation in TIER-2 docs / scripts / hooks / skills / ADRs / root-level docs.
- **Does NOT distinguish "actively-load-bearing" from "passively-cited."** A rule cited once in 10 ADRs has 10 citations; whether each citation is load-bearing requires per-citation review. The audit is a first-pass numerical filter.
- **Does NOT establish minimum-citation thresholds for retention.** "Zero citations" and "1-2 citations" are highlighted as candidates for review; the actual retain/delete decision is per-rule + per-ADR.

## §6 Re-running the audit

To regenerate this report against a future commit:

```bash
./scripts/audit-rulebook-coverage.sh          # human summary (this report)
./scripts/audit-rulebook-coverage.sh --detail # per-rule rows
./scripts/audit-rulebook-coverage.sh --quiet  # exit code only
```

The audit is deterministic per commit; running on the same commit produces identical findings. Future runs against post-consolidation commits should show shrinking zero-citation candidate counts.

## §7 Authority and amendment

This doc is **TIER-2 audit report**. It is captured-at-a-moment and not amended in-place — future re-runs of the audit produce a NEW dated report (e.g., `docs/rulebook-coverage-audit-2026-07-01.md`). The current report stays as the historical state at TICKET-026 / 2026-05-26.

History: introduced in TICKET-026 (ADR-0031). Subsequent rulebook-consolidation CLs cite this report's findings as justification for specific deletions.

## §9 Supersession events (per-CL log)

Per §7 the report is captured-at-a-moment. When a consolidation CL deletes rules cited in §3, this section logs the supersession (the report stays at its captured numbers; the log records the deletion).

### 2026-05-26 — C-rule consolidation (TICKET-028 / ADR-0033) — closes Musk #1

Per Musk's review feedback ("C-rules are 83% dead — delete them; consolidate; ship"), the 20 zero-citation C-rules named in §3.4 (C-2 through C-21) were deleted from `docs/claude-tdd-pro-principles.md §16` and consolidated to upstream `claude-tdd-pro` per the CLAUDE.md prime directive. The inner-loop discipline they encoded (Three Laws, refactor cadence, smells, characterization, test pyramid, schools, mocking, naming, coverage, headless `-p`, `--allowedTools`, skill consumption, frontmatter, no substitution, atomic CL, decision-trail emission, no research/no deploy) is now owned by the SKILL.md trio symlinked from the pinned plugin cache.

- **Deleted from §16 table:** C-2, C-3, C-4, C-5, C-6, C-7, C-8, C-9, C-10, C-11, C-12, C-13, C-14, C-15, C-16, C-17, C-18, C-19, C-20, C-21 (20 rules).
- **Retained in §16 table:** C-1, C-22, C-23, C-24 (4 rules).
- **Intellectual provenance retained:** `docs/claude-tdd-pro-principles.md §§1-15` (Beck, Bob, Fowler, Feathers, Cohn, London/Chicago, mutation/property, Anthropic, DORA) bodies remain.
- **Audit script (`scripts/audit-rulebook-coverage.sh`) updated** to iterate only active C-rules (1, 22, 23, 24) per §6.
- **Operator-visible references updated:** `CLAUDE.md`, `AGENTS.md`, `docs/ai-engineering-corpus.md` §authority-table, `docs/founder-directives.md §5` table, `scripts/export-cursor-rules.sh gen_agent_context` + regenerated `.cursor/rules/agent-context.mdc`.

**Net effect on §2 summary table** (these are post-TICKET-028 numbers; original captured-2026-05-26 table preserved above per §7):

| Rulebook | Source | Total active rules | Zero-citation | % dead |
|---|---|---|---|---|
| D-rules | `docs/founder-directives.md §3` | 13 | 0 | 0% |
| R-rules | `docs/architecture-principles.md` | 20 | 0 | 0% |
| G-rules | `docs/grok-orchestration-principles.md` | 21 | 0 | 0% |
| C-rules | `docs/claude-tdd-pro-principles.md` | **4** (was 24) | 0 | 0% |
| **Total** | — | **58** (was 78) | **0** (was 40) | **0%** (was 51%) |

The C-rule consolidation deleted 20 rules in one CL (per Musk's deletion-pass framing). R-rule cohort retire (12 dead microservices-pattern rules per §3.2) and G-rule rationalization (7 dead per §3.3) remain deferred per §4 sequencing.

## §8 Composition

This doc composes on:

- `scripts/audit-rulebook-coverage.sh` — the audit script that produces these numbers.
- `docs/founder-directives.md §3` — D-rule source (excluded from citation count).
- `docs/architecture-principles.md` — R-rule source (excluded).
- `docs/grok-orchestration-principles.md` — G-rule source (excluded).
- `docs/claude-tdd-pro-principles.md` — C-rule source (excluded).
- ADR-0031 — the decision record this report originates from.

D-1 reverse attribution per ADR-0013: this report is a cross-tool primitive (applies to any rulebook regardless of tool); no Grok-side or Claude-side exclusive analog. The closest analog is the Q-DOC-DRIFT discipline (`docs/founder-directives.md §4`) which catches operator-visible surface drift; this audit catches rulebook-clause operational drift.
