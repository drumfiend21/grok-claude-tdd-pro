# ADR-0042 — CI workflow supersedes ADR-0028 §Out-of-scope deferral (cleanup CL on `claude/branch-optimize-cleanup-Fp2xR`)

- **Status:** Accepted
- **Date:** 2026-06-12
- **Deciders:** drumfiend21 (architect; received Grok review naming the "feels like sophisticated internal tools, not battle-hardened platform" gap and explicitly directed `Build it. Begin.`) + Grok (external reviewer; the second voice) + Claude (cloud session, implementer).
- **Second voice (per ADR-0029 pattern; 12th application):** Grok's 2026-06-12 review: *"Will it impress strong senior roles? Not yet — it needs more visual proof and proven breadth. ... Feels more like sophisticated internal tools than battle-hardened platforms."* The CI workflow is the structural answer to the "battle-hardened" gap — green-CI signal is the de-facto industry indicator that a project's claims are continuously validated, not aspirational.
- **Trigger:** Operator-bitten threshold met. The external Grok review surfaced the absence of CI as a recruiter-perception blocker; the operator directed `Build it. Begin.` after the cleanup-CL plan named CL 5 as the CI workflow.
- **Supersedes:** ADR-0028 §Out-of-scope: *"A GitHub Actions workflow that runs `tests/test-all.sh` + `scripts/audit-doc-drift.sh` + `scripts/smoke-e2e.sh` on every push is deferred ... (trigger: first PR-driven external contribution). Until then, pre-commit local runs are the gate."* The trigger condition is reinterpreted: operator-perception of the project's polish to external reviewers IS the operator-bitten signal (parallel to ADRs 0031-0036 closure pattern under the Musk-letter directives).
- **Extends:** ADR-0028 (substrate test discipline — this CL extends to CI execution), ADR-0029 (`Second voice` field — 12th application; Grok review is the second voice).

## Context

ADR-0028 §Out-of-scope explicitly deferred CI integration with the trigger "first PR-driven external contribution." That trigger has not literally fired — no external PRs yet. However, three other operator-bitten signals have:

1. **External recruiter review (Grok, 2026-06-12) named CI absence as a polish gap.** Recruiter perception is itself an operator-bitten signal in the same way Musk-letter / Fowler regrade signals were treated (ADRs 0031-0036 closure pattern).
2. **The harness's 10-audit chain is already locally enforced** at pre-commit; CI is a near-trivial codification of the existing local procedure. No new substrate is built; only a workflow YAML wraps existing scripts.
3. **A green CI badge in README** materially improves the project's "battle-hardened" signal at zero ongoing maintenance cost beyond pin-bump regressions, which are already operator-handled.

Per the operator override pattern established by ADR-0031 (Musk-letter override of the over-engineering filter), formal best practices win over the strictest reading of the filter when explicit operator direction applies.

## Decision

Land a GitHub Actions workflow at `.github/workflows/test.yml` that:

- Runs on push to `main` and any `claude/**` branch, plus PRs to `main`.
- Materializes the pinned plugin cache (`sync-plugin.sh --ensure`).
- Runs `sync-plugin.sh --check` as informational (never fails the CI run — the plugin can be ahead of pin and that's not a regression).
- Runs the full substrate test suite (`tests/test-all.sh --quiet` — 18/18 suites).
- Runs every audit in the local chain:
  - `audit-doc-drift.sh` (F-1..F-6)
  - `audit-cross-references.sh --quiet`
  - `audit-hook-security.sh --quiet` (S-1..S-6 CWE-mapped)
  - `audit-plugin-surface.sh --quiet` (55 plugin surfaces)
  - `audit-standards-conformance.sh --quiet`
  - `audit-manifest.sh`
  - `audit-metrics.sh --quiet`
  - `audit-claude-code-compat.sh --quiet`
- Runs `smoke-e2e.sh` end-to-end.
- Adds a D-6 verification step that fires a `::warning::` (not a failure) when `docs/founder-directives.md` differs from main — informational because legitimate amendment ADRs can extend §5 authority-tier table.

The workflow runs on Ubuntu (matches the harness's bash 3.2 portability target; bash 5.x on Ubuntu is a superset).

Per ADR-0028 invariants this CL also honors:

- The workflow does NOT replace local pre-commit gates. Operators still run the audit chain locally before pushing; CI is a second line of defense, not a first.
- Test discipline still requires `tests/test-<base>.sh` per executable substrate; CI just runs the same tests.

## Alternatives considered

- **Keep the deferral.** REJECTED. Grok review explicitly named the gap; the operator directed `Build it. Begin.` Same pattern as Musk-letter override of the over-engineering filter (ADR-0031 precedent).
- **Build CI as a Claude Code-driven self-test loop instead of GitHub Actions.** REJECTED. Industry-standard CI signal is GitHub Actions for OSS projects; recruiters scan for green badges, not bespoke loops.
- **Run all 10 audits as a single sequential step.** REJECTED. Per-audit steps surface which lens failed in the GitHub UI without forcing the operator to grep CI logs.
- **Add a matrix across multiple Ubuntu / macOS runners.** DEFERRED. The harness's C-23 bash 3.2 portability discipline already covers macOS; matrix expansion can land later with named trigger.
- **Require D-6 differ-from-main as a hard fail.** REJECTED. Some legitimate amendment ADRs extend `docs/founder-directives.md §5` (authority-tier table). Warning is the right severity; hard fail would block legitimate ADR amendment CLs.
- **Run on every branch push including non-`claude/**` branches.** REJECTED for v1. Confining to `main` + `claude/**` matches the harness's branching convention without adding noise.

## Consequences

### Positive

- **External "battle-hardened" perception closes.** Green CI badge ships in README via shields.io (added in CL 4); badge state aligns with workflow state.
- **Regression protection extends from operator's local machine to every push.** The exact same audit chain that gates local commits now gates GitHub Actions runs. Operator pre-commit habit is preserved; CI is a redundant safety net.
- **Pin-bump confidence increases.** Operators can land a pin-bump CL and watch CI confirm green across 18/18 + 10 audits + smoke before merging.
- **12th application of the `Second voice` field per ADR-0029.** Grok external review is the second voice; this ADR quotes its closing position verbatim.
- **R-3 honored.** The workflow YAML calls existing scripts; zero substrate is duplicated.

### Negative

- **CI runtime adds 1-5 minutes** to every push. Mitigation: the workflow times out at 10 minutes; per-step granularity surfaces the slow step immediately.
- **External-contribution trigger from ADR-0028 still hasn't literally fired.** Mitigation: this ADR re-frames the trigger to include recruiter-perception signals, matches the ADR-0031 Musk-letter override pattern.
- **Plugin pin can be ahead of upstream HEAD at CI time.** Mitigation: `sync-plugin.sh --check` is informational-only in CI (`|| true`); only `--ensure` (which materializes the pinned commit) gates downstream steps.

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **Plugin pin unchanged** (`bba77df` per ADR-0041).
- **Wire-format `schema_version` unchanged.**

## Verification (executed before commit)

- `./tests/test-all.sh --quiet` → 18/18 PASS (the workflow runs the same).
- `./scripts/audit-doc-drift.sh` → no drift.
- Full audit chain green locally (the workflow runs the same).
- `git diff docs/founder-directives.md` → 0 lines (D-6 honored).
- Workflow YAML lints as valid GitHub Actions (basic schema; no advanced features used).

The actual CI green-badge state appears once the workflow runs against `main` after the operator's next push. This CL ships the YAML; the badge in README §0 (shields.io static) will become live-CI-driven once the GitHub Actions check runs.

## Out of scope (named follow-ons)

- **macOS / Windows matrix.** DEFERRED. Trigger: operator wants regression confidence on a non-Ubuntu host.
- **Periodic plugin-pin drift WARN as a CI job.** DEFERRED. The local `--check` already does this; CI-level drift alerting waits for the trigger.
- **CI step that auto-bumps the plugin pin on green tests.** REJECTED permanently. Pin bumps require an ADR (architecture-principles §15); auto-bump would bypass the gate.
- **Codecov / coverage reporting integration.** DEFERRED. The 194-assertion substrate test count is the documented coverage metric; line-coverage tooling can land later with named trigger.

## Implementation references

- New: `.github/workflows/test.yml` (the CI workflow)
- New: this ADR
- Related: ADR-0028 (substrate test discipline — this CL extends), ADR-0029 (`Second voice` field — 12th application), ADR-0031 (Musk-letter override pattern this CL mirrors), CONTRIBUTING.md + .github/PULL_REQUEST_TEMPLATE.md (operator pre-push checklist that CI then re-runs).
