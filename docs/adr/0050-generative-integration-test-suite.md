# ADR-0050 — Generative integration test suite (non-technical user → world-class delivery, cloud + fullstack)

- **Status:** Accepted
- **Date:** 2026-06-15
- **Deciders:** drumfiend21 (architect; 2026-06-15 directive: *"I want integration tests for all generative functions (cloud architecture and fullstack development). The tests will simulate a user building various software with no technical experience and the plugin delivering world class software to satisfy the unique usecase of the user."*) + Claude (cloud session, designer).
- **Second voice (per ADR-0029 pattern; 19th application):** The operator's "simulate a user … with no technical experience and the plugin delivering world class software" directive is the second voice — it defines the integration tier's success criterion: a layperson's plain-English ask must yield software that enforces every applicable world-class standard, including ones the user could never name.
- **Trigger:** The suite had unit coverage of each substrate script and one stub end-to-end smoke (`smoke-e2e.sh`, the toy module), but no *scenario-driven integration tier* exercising the generative pipeline across diverse real-world use cases and both target domains (cloud architecture, fullstack development).
- **Extends:** TICKET-006/ADR-0008 (stub-mode e2e + deferred live-Claude), ADR-0037 (operator-declared standards), ADR-0045..0048 (EO governance), ADR-0049 (citation integrity). Supersedes nothing — additive (Nygard append-only).

## Context

The harness's "generative functions" are the outer-loop → inner-loop pipeline: a plain-English user request is decomposed into a ticket (Grok), handed off (the `req.json` wire contract), realized by the plugin's `tdd-pro-cl-workflow` R-G-R (Claude), and returned green (the `res.json` wire contract) only if every quality gate passes. "World-class delivery" means: for the user's **detected stack**, every applicable authoritative-source standard in `.harness/rules/active.json` is enforced via `applicable_rules` — fullstack (`react`, `typescript`, `node`, `web-vitals`, `w3c`) and cloud/security (`owasp`, `slsa`) — plus the non-exemptible, two-phase EO governance layer, even for standards a layperson can never articulate (accessibility, Core Web Vitals, OWASP boundary validation, SLSA provenance).

**Honest constraint (ADR-0008):** the harness cannot invoke a live LLM deterministically in CI; live-Claude e2e is deferred. So, exactly as `smoke-e2e.sh` does, the integration tier runs in **stub mode** — a deterministic simulator stands in for the live generation, while the *wire contract*, the *world-class-coverage definition*, and the *harness gates* are REAL and asserted.

## Decision

Add a **`tests/integration/`** tier:

- **`scenarios/*.json`** — 6 personas, each a non-technical user describing software in plain English, across both domains:
  - *Fullstack:* recipe-sharing web app (home cook), budget-tracker SPA (bakery owner), neighborhood event board (community volunteer).
  - *Cloud:* serverless photo-resize API (photographer), multi-region order pipeline (craft-shop owner), static-site + CDN + auth (nonprofit director).
  - Each declares `detected_stack`, `expected_namespaces`, a `critical_namespace` the user could never name (e.g. `w3c` accessibility, `owasp` security, `slsa` provenance), and plain-English `acceptance_criteria`.
- **`simulate.mjs`** — emits a contract-valid `req.json`/`res.json` pair simulating a world-class inner-loop delivery: `applicable_rules` = every active rule for the detected stack + the non-exemptible EO rule; `status: green`; `rules_verified` all `pass`; two-phase `eo_design_conformance`. It validates the wire schema and the **world-class stack-coverage** invariant (every standard for every detected namespace is enforced). Supports negative modes (`drop-stack`, `omit-eo-attestation`, `omit-eo-rule`).
- **`test-generative-integration.sh`** — drives every scenario in `world-class` mode and asserts delivery; runs the **real** `audit-eo-governance.sh` (over the emitted artifacts, with a fixture EO registry so the pin-bump-gated EO layer is exercised) and `audit-source-citations.sh`; and runs **negative scenarios** proving the gates REJECT sub-world-class delivery (dropped accessibility/security family; missing EO design attestation; dropped non-exemptible EO rule). Negative cases make a green run a real signal, not a rubber stamp.

The tier is wired into `tests/test-all.sh` (single-command coverage) and CI.

## Alternatives considered

- **Drive a live `claude -p` generation per scenario.** REJECTED — non-deterministic, needs API credentials, not reproducible in CI; contradicts ADR-0008's deferral. Stub mode is the established pattern; live mode remains a future tier behind an ADR amendment.
- **Assert on generated source code (e.g. that a real React app exists).** REJECTED — the harness does not own code generation (prime directive: the plugin does). The harness owns the *contract + gates*; the integration tier asserts those, not plugin internals.
- **Only positive scenarios.** REJECTED — without negative cases the tests would pass even if the gates were no-ops. The `drop-stack`/`omit-eo-*` modes prove the world-class bar is enforced.
- **Put scenarios in the unit tier.** REJECTED — Cohn's pyramid: integration is a distinct tier (composes multiple real scripts, needs node). Kept under `tests/integration/`, discovered by `test-all.sh` for convenience.

## Consequences

### Positive

- **Every generative function is integration-tested** across cloud + fullstack, from a non-technical user's plain-English ask to a world-class, fully-standards-enforced delivery.
- **The gates are proven to bite** — negative scenarios reject dropped standards and missing EO attestation.
- **Honest stub-mode boundary** documented; live-LLM tier is a clean future extension.
- **19th application of the `Second voice` field.**

### Negative

- **Stub mode does not execute generated code.** That is the ADR-0008 boundary, not a regression; the wire contract + gates are real.

### Neutral

- **Requires node** (as `smoke-e2e.sh` already does); present in CI via `setup-node`.
- **No `claude-tdd-pro` path touched** (prime directive); plugin pin `bba77df` + `schema_version` unchanged.
- **D-6 honored** — `docs/founder-directives.md` untouched.

## Verification (executed before commit)

- `tests/integration/test-generative-integration.sh` — 17/17 (6 scenarios × world-class delivery; both domains present; real EO + citation gates green; 3 negative gate-rejection cases).
- `tests/test-all.sh` — 21/21 suites (integration tier discovered).
- Full audit chain green (incl. hook-security with the integration test's `mktemp $TMP` trap baselined).
- `git diff docs/founder-directives.md` → 0 lines (D-6); no `claude-tdd-pro` path modified; pin + `schema_version` unchanged.

## Implementation references

- New: `tests/integration/simulate.mjs`, `tests/integration/scenarios/*.json` (6), `tests/integration/test-generative-integration.sh`, `tests/integration/README.md`
- Modified: `tests/test-all.sh` (discover integration tier), `.github/workflows/test.yml` (CI step), `tests/hook-security-baseline.txt` (1 `mktemp $TMP` trap), `tests/README.md` (integration tier note), `TICKETS.md` (TICKET-052)
- New: this ADR
- Related: ADR-0008 (stub-mode e2e), ADR-0037 (standards registry), ADR-0045..0049 (EO governance + citation integrity), ADR-0029 (`Second voice` — 19th application)
