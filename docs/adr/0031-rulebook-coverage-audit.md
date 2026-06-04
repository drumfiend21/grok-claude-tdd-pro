# ADR-0031 — Rulebook coverage audit (Fowler #1 closure) (TICKET-026)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 directive: *"Proceed through three focused, triggered, filter-disciplined CLs to secure A+"* — closure #1 per Kua's ordering "biggest grade lift but longest effort") + Claude (cloud session, implementer)
- **Second voice (per ADR-0029 pattern):** Simulated Fowler+team regrade explicitly named: *"#1 second (biggest grade lift but longest effort) — Audit which rulebook clauses are dead code; merge or delete the long tail."* The regrade IS the second voice; this CL ships the audit phase.
- **Trigger:** Closes Fowler critique #1 ("Over-documentation / governance inflation; discipline-to-code ratio ~10:1; need an honest audit of which rulebook clauses have ever been operationally invoked vs. cited") per the architect's explicit 2026-05-26 directive to secure A+.
- **Supersedes:** none
- **Extends:** ADR-0028 (substrate-script test discipline — this audit follows the same pattern); ADR-0029 (regrade-driven closure + `Second voice` field — second application)

## Context

The simulated Fowler+team regrade identified critique #1 as the largest open grade-lift opportunity post-TICKET-024. Fowler's specific recommendation:

> *"Audit which rulebook clauses have ever been operationally invoked vs. cited. The R-/G-/C-rules likely have a long tail of never-invoked rules that exist for completeness, not for use. Fowler would push to merge or delete the tail."*

The architect's 2026-05-26 directive triggered the closure: *"Proceed through three focused, triggered, filter-disciplined CLs to secure A+."*

Audit run on 2026-05-26 against main at commit `38d6617`:

| Rulebook | Total rules | Zero-citation | % dead |
|---|---|---|---|
| D-rules (`founder-directives.md §3`) | 13 | 1 | 8% |
| R-rules (`architecture-principles.md`) | 20 | 12 | 60% |
| G-rules (`grok-orchestration-principles.md`) | 21 | 7 | 33% |
| C-rules (`claude-tdd-pro-principles.md`) | 24 | 20 | 83% |
| **Total** | **78** | **40** | **51%** |

**Fowler's critique was numerically accurate.** Half the rulebook (51%) has zero external citations.

Three design questions:

1. **What's the scope of "closure" for this critique?** Audit-only, or audit + deletion of dead clauses?
2. **What's the audit script's permanent home?** One-shot manual run, or shipped as substrate?
3. **How are findings recorded?** Inline in ADR, or as a separate TIER-2 audit report?

## Decision

### 1. Audit-only in this CL; deletion deferred per D-8

This CL closes Fowler #1 for the **audit phase** specifically. Actual deletion / consolidation of the 40 zero-citation rules is **deferred** to subsequent CLs per D-8 (deletion discipline) and the over-engineering filter:

- **Mass deletion in one CL** would be high-risk (40 rules touch multiple ADRs each; cross-reference impact is non-trivial).
- **Per-rule deletion** requires its own ADR per affected rulebook for the architectural authority change. Mass-amending 4 rulebooks in one CL is exactly the "kitchen sink" pattern D-13 rejects.
- **The audit IS the value-add.** Without it, the dead-code state is intuited but not measured. With it, future consolidation CLs can cite specific numbered findings as justification.

Proposed sequencing for actual deletion (in `docs/rulebook-coverage-audit.md §4`):

1. **C-rule consolidation** (biggest cohort — 20 candidates). Likely replaces harness-side `docs/claude-tdd-pro-principles.md` with a thin composition pointing at upstream. **Trigger:** architect signals readiness for structural simplification.
2. **R-rule audit** (12 microservices-pattern candidates). Each needs rationale-or-archive decision; some may be intellectual-cite-only rather than operationally-load-bearing. **Trigger:** future CL touches architecture rulebook anyway.
3. **G-rule rationalization** (7 candidates). Split between tacit-enforcement and deferred-mechanism cases. **Trigger:** self-healing implementation kicks off (per ADR-0011 deferral).
4. **D-rule retention** (only D-4 candidate). Likely retain with usage-strengthening pass.

Each step is a separate CL with its own ADR (the rulebooks are TIER-1 / TIER-2 surfaces; any structural change warrants its own decision record per `docs/architecture-principles.md §19`).

### 2. `scripts/audit-rulebook-coverage.sh` shipped as substrate

The audit script is reusable infrastructure, not a one-shot. Ships in `scripts/` with the existing substrate scripts (sync-plugin, smoke-e2e, audit-doc-drift, emit-manifest, audit-manifest, export-cursor-rules).

Properties:

- Bash 3.2 + BSD coreutils portable (C-23).
- Default human-readable summary mode; `--detail` for per-rule rows; `--quiet` for exit-code only.
- Exits 0 on audit completion; 2 on script-invocation error.
- Composes on `grep -rEl` + `wc -l` + `tr -d`; no new dependencies.
- Deterministic per commit (re-running produces identical findings on the same tree).

Per ADR-0028 pattern: ship the script with its own test suite (`tests/test-audit-rulebook-coverage.sh`; 12 assertions). Coverage table updated to 10/10 surfaces.

### 3. Findings recorded in separate TIER-2 audit report

`docs/rulebook-coverage-audit.md` is the report. Captured-at-a-moment (the 2026-05-26 snapshot); not amended in-place. Future re-runs against post-consolidation commits produce NEW dated reports (e.g., `docs/rulebook-coverage-audit-2026-07-01.md`). The current report stays as historical state at TICKET-026.

Rationale per R-3: ADRs are decision records, not data dumps. The numerical findings belong in a TIER-2 audit report; the DECISION to defer deletion belongs in this ADR.

The report is enumerated in `AGENTS.md §5` TIER-2 list so future readers (operators and agents) discover it through the standard authority-doc enumeration.

## Alternatives considered (over-engineering filter applied to each)

- **Delete the 40 zero-citation rules in this CL.** REJECTED per D-8 + D-13. High-risk; cross-reference impact non-trivial; would amend 4 rulebooks in one CL.
- **Defer the audit entirely until subsequent CL drives are ready.** REJECTED. The audit IS the closure for Fowler #1; without it, the critique remains open. Deferring closure on the architect's explicit directive contradicts the directive.
- **Inline the audit findings in this ADR.** REJECTED per R-3. ADR carries the decision; report carries the data.
- **Build a more sophisticated audit** (count citations per kind: docstring vs. code vs. test vs. ADR). REJECTED per D-13. Numerical citation count is sufficient for the first-pass filter; refined categorization is a subsequent ADR's concern if needed.
- **Use a different threshold for "dead"** (e.g., < 5 citations). REJECTED. Zero citations is the unambiguous threshold for "never operationally invoked elsewhere"; low-citation (1-2) is reported separately as a softer signal.
- **Skip the test for the audit script.** REJECTED per ADR-0028 substrate-script-test-discipline precedent. Every substrate script ships with its test suite.
- **Don't add `docs/rulebook-coverage-audit.md` to AGENTS.md §5.** REJECTED. The audit report is operationally-discoverable infrastructure; enumeration in AGENTS.md §5 is how future readers find it.

## Consequences

### Positive

- **Fowler critique #1 closed for the audit phase.** Numerical state of rulebook coverage is now documented; future consolidation CLs cite this report as justification.
- **`scripts/audit-rulebook-coverage.sh` is reusable.** Re-runnable on any commit; deterministic; substrate for future rulebook hygiene work.
- **Coverage table extended to 10/10 surfaces tested.** `tests/test-audit-rulebook-coverage.sh` (12 assertions) follows the established ADR-0028 pattern.
- **TIER-2 audit report sets a pattern.** Future audits (e.g., G-rule materialization audit if Fowler ever asks) can use the same captured-at-a-moment report shape.
- **Deletion-discipline preserved.** D-8 applied: zero rules deleted in this CL; 7 alternatives REJECTED with rationale; deletion sequencing documented in the report.
- **D-12 honored.** Honest reporting: 51% of rules have zero external citations. No softening of the finding.
- **D-rule body untouched.** §3 D-rule bodies remain immutable; the audit operates on citation counts, not on rule definitions.
- **Per ADR-0029 `Second voice` field demonstrated** for the second time (regrade transcript is the second voice).

### Negative

- **40 zero-citation rules remain in the rulebooks.** The audit measures them but doesn't delete them. Future operators reading the rulebooks see all 78 rules. Mitigation: `docs/rulebook-coverage-audit.md` is enumerated in AGENTS.md §5; the dead-code state is now discoverable + numerically documented.
- **Subsequent consolidation CLs are work the architect must drive.** No automation forces the deletions. Mitigation: each consolidation has a named trigger in the report's §4 sequencing.
- **The audit is deterministic per commit but expensive to re-run** (grep across 78 rules × 6 file categories = ~470 grep invocations; ~5 seconds on this tree). Mitigation: the script is not called on hot paths; manual re-run when needed, or once-per-quarter cadence.

### Neutral

- **D-rule count unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **R-/G-/C-rule bodies untouched.**
- **Wire-format schema_version unchanged.**
- **AGENTS.md §5 gains one TIER-2 enumeration entry** (`docs/rulebook-coverage-audit.md`).
- **CLAUDE.md / QUICKSTART untouched.**

## Verification (executed before commit)

- `bash -n scripts/audit-rulebook-coverage.sh` clean.
- `bash -n tests/test-audit-rulebook-coverage.sh` clean.
- `./scripts/audit-rulebook-coverage.sh` exits 0 + produces summary table.
- `./scripts/audit-rulebook-coverage.sh --detail` exits 0 + produces per-rule rows (>100 lines).
- `./scripts/audit-rulebook-coverage.sh --quiet` exits 0 + emits no stdout.
- `./tests/test-audit-rulebook-coverage.sh` exits 0 with 12/12 passing.
- `./tests/test-all.sh --quiet` shows 10/10 suites now passing (was 9/9 pre-CL).
- Full audit chain: audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest all exit 0.
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- `docs/rulebook-coverage-audit.md` exists with §1..§8 sections.
- `AGENTS.md §5` lists `docs/rulebook-coverage-audit.md`.
- ADR-0031 follows the numbered ADR template + uses `Second voice` field.

## Out of scope (deferred)

- **Per-rule deletion / consolidation CLs** for the 40 zero-citation candidates. Sequencing documented in `docs/rulebook-coverage-audit.md §4`; each is its own future CL with its own ADR per `docs/architecture-principles.md §19`.
- **Citation-quality classification** (load-bearing vs. passing reference). REJECTED at v1; numerical count is sufficient for first-pass filter.
- **Automated rulebook freshness audit at pre-commit.** REJECTED per D-8 — audit is not hot-path; manual run cadence is sufficient at v1.
- **Cross-rulebook coupling audit** (which rules cite which other rules). Deferred; the current audit is per-rule citation, not inter-rule.
- **`scripts/audit-rulebook-coverage.sh --update` mode** that would delete zero-citation rules. EXPLICITLY REJECTED per D-12 trust calibration — automated deletion of authority-tier rules would be reckless; deletion requires per-rule ADR review.

## Implementation references

- New: `scripts/audit-rulebook-coverage.sh` (bash 3.2 + BSD portable; --detail / --quiet flags; ~100 lines)
- New: `docs/rulebook-coverage-audit.md` (TIER-2 audit report; §1..§8 sections; captured 2026-05-26)
- New: `tests/test-audit-rulebook-coverage.sh` (12 assertions; follows ADR-0028 test pattern)
- Modified: `AGENTS.md §5` (TIER-2 enumeration adds the new report)
- Modified: `scripts/export-cursor-rules.sh` (gen_agent_context TIER-2 list adds the new report)
- Regenerated: `.cursor/rules/agent-context.mdc` (mirrors AGENTS.md §5)
- Modified: `tests/README.md` (coverage table 10/10 surfaces)
- Modified: `TICKETS.md` (TICKET-026 row marked DONE)
- New: this ADR
- Related: ADR-0028 (substrate-script test discipline — pattern this CL follows), ADR-0029 (Second voice field — second application), ADR-0030 (swarm test — preceding CL in the three-CL A+ run), `docs/founder-directives.md §3` (D-rule source; bodies untouched), `docs/architecture-principles.md` (R-rule source), `docs/grok-orchestration-principles.md` (G-rule source), `docs/claude-tdd-pro-principles.md` (C-rule source).
