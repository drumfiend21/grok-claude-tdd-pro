# Changelog

Notable milestones in `grok-claude-tdd-pro`. Append-only; oldest entries below. Per-CL detail lives in `TICKETS.md`; per-decision detail in `docs/adr/`.

## 2026-06-07 — TICKET-036 / ADR-0041 — Plugin pin bump activates static-context wire

- Plugin pin advanced `23e5c2b` → `bba77df`. Contract-surface drift reviewed (2 files, both additive); CLI contracts on rubric runner + aggregator + AIBOM emitter preserved.
- Static planner context (`PROJECT_CONTEXT_FOR_PLANNER.md`) now injected into `.harness/context/` on every session start. Grok's decomposition template reads it before sizing tickets.
- Plugin-surface registry extended with 16 new entries (39 → 55 declared surfaces; 11 CONSUMED + 44 DECLARED-NOT-CONSUMED + 0 UNKNOWN).
- 11th application of the `Second voice` field per ADR-0029.

## 2026-06-06 — TICKETS 035 + 034 — Static context injection supersedes architecture-consult

- ADR-0040 supersedes ADR-0039. The dynamic per-feature consult mechanism (architecture-consult template + handoff schema) shipped in TICKET-034 was reversed in TICKET-035 after an adversarial review identified four substantive critiques (framework-itis, static-vs-dynamic data mismatch, coupling cost, unfalsifiable success criterion).
- Plugin upstream published the paired `PROJECT_CONTEXT_FOR_PLANNER.md` + plugin-side ADR-0006.
- Harness side: `sync-plugin.sh --ensure` extended to copy the static context defensively; SUPERSEDED markers added to the deprecated artifacts per Nygard append-only.

## 2026-06-06 — TICKET-033 + 033.a + 032 — Full plugin-feature wire

- Standards rule registry materialized at `.harness/rules/active.json` — 28 rules from 9 namespaces (google, node, owasp, react, slsa, typescript, w3c, web-vitals, _community).
- PostToolUse hook now runs `rubric/runner.sh --diff --severity P0` on app-code extensions; blocks writes on P0 violations.
- Pre-commit `audit-standards-conformance.sh` re-verifies the diff against `docs/deviations.md` (append-only registry of operator-justified exceptions).
- `compliance/aibom-emit.sh` invoked per green response — every ticket produces an AI Bill of Materials artifact alongside the manifest.
- `formatters/cli.sh` auto-applies after rubric checks pass.
- Plugin-surface declaration registry shipped (`docs/plugin-surface-consumption.md`) — every plugin top-level surface now classified CONSUMED or DECLARED-NOT-CONSUMED.

## 2026-05-26 — TICKETS 029 + 030 + 031 — Musk Engineering Leadership letter closures

- TICKET-031 / ADR-0036: Claude Code host-CLI version range pinned (symmetric with plugin pin discipline). Hook payload contract tests with golden fixtures. Upgrade runbook.
- TICKET-030 / ADR-0035: DORA metrics computed from real `.harness/audit/*.manifest.json` corpus — deployment frequency, change failure rate, lead time. No fabrication.
- TICKET-029 / ADR-0034: Security audit (`scripts/audit-hook-security.sh`) — six pattern classes mapped to CWE / OWASP; approval-baseline pattern. QUICKSTART §0 "Fastest path" — clone-to-green in under 2 minutes.

## 2026-05-26 — TICKETS 026 + 027 + 028 — Fowler critique closures + Musk #1 deletion

- TICKET-028 / ADR-0033: C-rule consolidation. 20 dead inner-loop rules removed from harness side (consolidated upstream); 4 retained (C-1 TDD, C-22 batching, C-23 portability, C-24 DORA).
- TICKET-027 / ADR-0032: Cross-reference audit with approval-baseline pattern.
- TICKET-026 / ADR-0031: Rulebook coverage audit — operational citation count per rule.

## 2026-05-26 — TICKET-025 / ADR-0030 — Swarm orchestration integration test

- `tests/test-orchestrating-swarms.sh` — 19 assertions covering Step 5 collection contract; Step 4 worktree spawn remains operator-attested by design.

## 2026-05-25 — TICKETS 020-024 — Production-ready milestones

- TICKET-024 / ADR-0029: Five Fowler critique closures (drift-detectable rename, second-voice field, others).
- TICKET-023 / ADR-0028: 100% substrate-script test discipline (one `test-<base>.sh` per executable).
- TICKET-020 / 022: README + QUICKSTART updated for operator entry.

## 2026-05-25 — TICKETS 001-019 — Foundational architecture

- Plugin-dependency model shipped (R-1, R-2 — versioned consumption, no cross-repo edits).
- Two-tier orchestration: Grok outer loop (research / decompose / dispatch templates) + Claude TDD Pro inner loop (R-G-R per ticket).
- Quality gate v2 (ADR-0026) — 4 sub-gates all REQUIRED including `provenance_complete`.
- Provenance trilogy (ADRs 0019-0021) — per-ticket manifest + emitter + validator + `--regenerate` audit mode.
- Cross-tool surface — `AGENTS.md` (cross-tool binding), `.cursor/rules/` (always-loaded), `.claude/skills/orchestrating-swarms/` (swarm coordinator).

---

## Status snapshot (2026-06-07)

- **Tickets:** 36 numbered tickets DONE.
- **ADRs:** 41 numbered decision records (0001-0041; Nygard append-only).
- **Test discipline:** 18/18 substrate test suites passing (~194 assertions across the harness).
- **Audit chain:** 10 audits green at every commit (doc-drift, cross-references, hook-security, manifest, plugin-surface, standards-conformance, metrics, claude-code-compat, sync-plugin --check, smoke-e2e).
- **Plugin surface:** 55 top-level surfaces declared (11 CONSUMED + 44 DECLARED-NOT-CONSUMED + 0 UNKNOWN).
- **Standards loaded:** 28 rules from 9 namespaces (Google, OWASP, SLSA, WCAG, Web Vitals, React, Node, TypeScript, community).
- **PR-quality corpus:** 10 elite source orgs at tier 1-2 (JPMorgan Chase, Stripe, Capital One, FINOS, Bloomberg, Kubernetes, CFPB, 18F, VA, GSA).
- **Plugin pin:** `bba77df` (2026-06-07). Cross-repo paired with `claude-tdd-pro` ADR-0006.
- **Claude Code pin:** declared range `>=2.0.0,<3.0.0`; tested version `2.1.x`.
- **Founder-directives `§1`:** immutable; 9 elevated sources (Karpathy, Musk, xAI Grok Build, Anthropic Building Effective Agents + Best Practices, Amodei, Schluntz/Zhang, @teslayoda + @elonmusk, xAI Grok Build Beta canonical).
