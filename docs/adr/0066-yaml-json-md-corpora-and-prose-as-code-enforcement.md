# ADR-0066 — YAML/JSON/MD corpora + prose-as-code enforcement (GCTP side)

- **Status:** Proposed
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect; 2026-06-19 directive across three turns: (1) *"I want all rules enforced on everything created for this kata answer"*; (2) *"identify all the best standards and rules and patterns for writing YAML files"*; (3) *"if it is architectural, whatever it is, if it's going to influence the application that it needs to abide by the rules, standards, and patterns that CTP/GCTP uses"*) + Claude (cloud session).
- **Scope:** harness self-maintenance — `/decompose`, `/inner-loop`, `/audit`, the language-floor gate (ADR-0060), the deviation discipline, and the SARIF aggregation seam — per the agent-operating-compact (ADR-0057). Pairs with **PROPOSAL-003** (CTP-side rule content + LLM-judge engine). Composes on ADR-0046 (two-phase enforcement), ADR-0055 (EO-spine activation), ADR-0058 (`enforce.sh` `not_applicable` neutral), ADR-0060 (Fix A), ADR-0062/0063 (Fix B/C), ADR-0064/0065 (refresh cadence).

## Trigger

The PATH A audit of the O'Reilly kata submission (`../softarchcert-win25`) against all 42 rules in `active.json` returned `pass:19 / fail:13 / not_applicable:10 / not_enforced:0` — a `red` status, but the **honest** finding was the coverage gap: **31 of 77 files were the only files any detector could bite on**. The remaining 46 files (33 `.md`, 11 `.json`, 2 `.gitignore`) have no rule namespace in `active.json` at all. The architecture decision log, all 14 ADRs, the SUBMISSION itself, the C4 diagrams, the cost-benefit model, the traceability matrix, the CTP-engine session JSON — none of it was enforced. The operator's three-turn directive elevated this from "registry gap to log" to "primary thing to close, including the **semantic** projection of every code rule onto architectural prose."

## Context

Three research corpora were assembled this session as the seed (read-only research; no plugin edits):

- **YAML — 75 sources** covering YAML 1.2.2 spec, yamllint, k8s PSS / config / RBAC / Secrets, Helm, Compose, GitHub Actions (security-hardening, OIDC, pin-by-SHA, `pull_request_target` hygiene), GitLab CI, Azure DevOps, CircleCI / Bitbucket / Jenkins, Ansible, CloudFormation, OpenAPI, GitOps (Argo CD, Flux, Kustomize, Sealed Secrets, SOPS), observability (Prometheus, Grafana, OTel Collector), service meshes (Istio, Envoy, Kong), and the canonical IaC-linter catalogs (kube-linter, Polaris, Trivy-checks, Checkov, Kubescape, conftest).
- **JSON — 40 sources + SchemaStore's 700+ schemas** covering RFC 8259 / ECMA-404 / RFC 7493 (I-JSON), JSON Schema (drafts 4/6/7/2019-09/2020-12), OpenAPI JSON variant, JSON-LD, JSON:API, JSON-RPC, **RFC 8725 JWT BCP** (highest-leverage P0 cluster in the whole corpus), package.json + lockfiles, tsconfig, `.vscode/` + devcontainer.json, AWS IAM / GCP IAM / Azure RBAC, k8s JSON manifests, Helm `values.schema.json`, Renovate, CFN/Terraform JSON, OPA bundle manifest, CycloneDX + SPDX (SBOM), **SARIF 2.1.0** (proposed as the universal output bus), OTel JSON, CloudEvents, Schema.org JSON-LD, Elastic Common Schema.
- **MD — 40 sources, TWO LAYERS.** Layer 1 (syntactic): CommonMark, GFM, markdownlint (MD001..MD060), remark-lint, Vale + errata-ai style packs (Google / Microsoft / write-good / alex / proselint), markdown-link-check / lychee, cspell + codespell, REUSE 3.3, Hugo/Jekyll/Docusaurus frontmatter, Mermaid + PlantUML. Layer 2 (semantic / prose-as-code): MADR 4.0, Nygard, Y-Statements, arc42 (12 sections), C4 model, RFC 2119 + RFC 8174, Diátaxis, Write the Docs, Google + Microsoft writing style guides, standard-readme + Make a README + GitHub opensource.guide, Conventional Commits, Keep a Changelog, SemVer, Contributor Covenant, STRIDE + LINDDUN, GitHub Advisory Database.

The full per-context tables (org / URL / refreshability / license / key rules / enforcement feasibility) are the input to PROPOSAL-003 and are kept verbatim in the research bundle (`/tmp/yaml-corpus-report.md` + JSON + MD agent outputs persisted in this session's transcript). The harness does **not** mirror rule bodies — those are CTP-owned content (prime directive).

The operator's prose-as-code principle is the architecturally novel piece. It says: if `g-aws-no-unrestricted-ingress` fires when a `.tf` declares `0.0.0.0/0`, it must also fire when an ADR says in plain English *"we'll allow unrestricted ingress on the dev cluster for convenience"* — same rule, same gate, two surfaces (code and design). Enforcement requires a **semantic** detector layer (LLM-judge) alongside the existing **syntactic** layer.

## Decision

**D-A. Consume the new namespaces via the existing channel.** When PROPOSAL-003 lands in CTP and a pin bump adopts it, `scripts/standards-sync.sh` materializes the new rule families into `.harness/rules/active.json` without any code change on the harness side. The new namespaces expected at landing (target list, finalized by the CTP team): `yaml`, `k8s`, `helm`, `compose`, `gha`, `glci`, `azdo`, `circleci`, `bbp`, `jenkins`, `ansible`, `cfn`, `oas`, `gitops`, `observability`, `mesh`, `iac-linter`, `json`, `jsonschema`, `iam`, `sbom`, `sarif`, `jwt`, `md` (syntactic), `arch` (semantic projection). No harness work to add channels; the channel is `active.json` itself.

**D-B. Extend the language-floor gate (ADR-0060) to MD.** `scripts/audit-applicable-rules.sh` adds: when a ticket's `file_scope.may_edit` contains an explicit `**/*.md` glob, the union MUST include every `g-md-*` rule (Layer 1 floor) **and** every rule in `active.json` whose `applies_to_prose: true` flag is set (Layer 2 projection). The latter mechanism is content-agnostic — it reads `applies_to_prose` live from `active.json`, so any CTP-side rule promoted to prose enforcement is picked up automatically without a harness change. Over-scoping remains safe (per ADR-0058: a rule that matches no prose-applicable section returns `not_applicable` (neutral), not `fail`).

**D-C. `/inner-loop` runs both detector layers without harness logic changes.** The existing `scripts/enforce-standards.sh` (Fix B / ADR-0062) reads each applicable rule's `detector` from `active.json` and invokes it. The Layer 1 detectors (markdownlint, Vale, lychee, cspell, reuse, mmdc) ship from CTP under the new namespaces and are exercised exactly like the existing `cloud-guidance-rule.sh` family — no harness change required. The Layer 2 detector (`prose-judge.sh` or equivalent, defined in PROPOSAL-003) honors the existing `LLM_JUDGE=1` environment toggle (already used in `no-any.sh` / `naked-throw.sh`), so when the model CLI is unavailable, it falls back deterministically to a coarse regex pre-check and returns `not_enforced` with an explicit reason — which the dynamic gate (Fix C / ADR-0063) treats as `red`. No silent green.

**D-D. Two-phase enforcement (composes on ADR-0046).** The first phase scores architectural MD **before** dispatch: a ticket whose `file_scope.may_edit` includes `docs/architecture/**/*.md` or any frontmatter-tagged `kind: architecture` document must satisfy both layers' `applicable_rules` before `dispatch.sh` will emit. The harness wires this into the consult-loop output (ADR-0056 §Stage-5 roadmap presentation): roadmap items derived from MD prose are scored, and operator-visible red findings block the dispatch step until either the prose is rewritten or a `docs/deviations.md` row lands. The second phase scores the code-phase MD after implementation — drift between an accepted ADR and the shipped code surfaces as a `drift-detected` audit signal.

**D-E. SARIF 2.1.0 as the universal output bus (harness side).** Every detector wired through `enforce-standards.sh` is expected to emit SARIF 2.1.0 (the OASIS standard). The harness adds **`scripts/sarif-aggregate.sh`** that concatenates per-rule SARIF runs into one log per CL under `.harness/audit/sarif/TICKET-NNN.sarif.json`, validates the aggregate against the OASIS schema (cached in the plugin), and exposes a deterministic summary to the audit chain. SARIF is read-only output; if a detector cannot emit it, the harness wraps the exit code into a minimal SARIF result.

**D-F. Deviation discipline for cross-provider / non-applicable-framework rules.** Per the prior turn's directive (*"don't exclude anything"*), no rule is preemptively dropped from `applicable_rules`. When an over-scoped rule cannot apply (e.g. `g-azure-encrypt-at-rest` against an AWS-only project per ADR-0010 of the app), the operator records a row in **`<app_root>/docs/deviations.md`** with: rule ID, why-cannot-apply, citation to the locking ADR/decision, and a one-line operator acceptance. The audit chain treats `deviated` as green; absence of a deviation row plus a failing verdict stays `red`. This is **visible** scoping, not silent exclusion.

**D-G. Refresh discipline covers the new sources.** `scripts/standards-refresh.sh` (ADR-0064) drives CTP's `standards/initial-refresh.sh` which is expected to enumerate the new corpora's raw-URL sources (per the master tables in PROPOSAL-003). No harness work; the cadence (ADR-0065 alignment) governs all sources uniformly. Until PROPOSAL-003 lands, the harness's refresh tick on the new sources is a no-op (vacuous-true) — surfaced explicitly in `--status`.

**D-H. Scope guardrail — the harness does not author rule content.** Per the prime directive: the harness MUST NOT define `g-yaml-*` / `g-md-*` / `g-arch-*` / `g-jwt-*` / `g-iam-*` / `g-sbom-*` / `g-sarif-*` rule bodies in-tree. Any reach into rule content is a contract violation. When the harness needs a behavior the plugin doesn't expose, the path is PROPOSAL-003 (or a successor), not in-tree authoring.

## Alternatives considered

- **Author the YAML/JSON/MD rules in the harness so the kata is enforced today.** REJECTED — prime-directive violation. The two-week speedup is not worth forking the rule pipeline; PROPOSAL-003 is the right shape.
- **Make the MD coverage syntactic-only (Layer 1) and skip the LLM-judge layer.** REJECTED — that retreats from the operator's prose-as-code directive. A markdown that says *"we'll disable encryption at rest"* would pass MD001..MD060, validate against MADR, and never fire `g-aws-encrypt-at-rest`. Same gate, two surfaces, or the gate is incoherent.
- **Run the LLM-judge layer eagerly on every MD on every session.** REJECTED — unbounded token cost. The cache by `(rule_body_hash, prose_section_hash)` (delegated to the plugin per PROPOSAL-003) and the two-phase trigger (design-phase before dispatch, code-phase before merge) bound the cost.
- **Adopt a single canonical IaC linter (e.g. Checkov) and treat its catalog as the registry.** REJECTED — couples the harness to one vendor's policy choices and licensing. The corpora design is multi-source with explicit pick-upstream rules ("Checkov for IaC density, kube-linter for K8s catalog cleanliness, Trivy for SBOM, kubescape for compliance mapping"), preserving the existing namespace-per-org discipline and citation integrity.
- **Skip SARIF and define a harness-native finding format.** REJECTED — fragments the ecosystem. SARIF 2.1.0 is OASIS-standard, GitHub-code-scanning ready, supported by every detector in the corpora. Reusing it costs nothing and earns interop.
- **Drop cross-provider rules from `applicable_rules` instead of demanding deviation rows.** REJECTED — that is the silent-exclusion path the operator explicitly rejected in this session. Deviations stay visible.

## Consequences

### Positive
- The 46-file enforcement dead zone in the PATH A audit closes once PROPOSAL-003 lands — every MD, every JSON, and (deeper) every YAML in the kata tree is bitten by at least one rule.
- The prose-as-code principle is enforceable by construction, not by reviewer vigilance: an ADR that proposes a design that would violate any rule in `active.json` fires the same gate, in plain language, **before** the implementing code is written.
- The harness gains zero new content-authoring authority — the consumption channel (`active.json`) is unchanged; only the language-floor gate (ADR-0060) and the SARIF aggregation seam are extended.
- SARIF as the output bus makes harness audit output compose into the wider security tool ecosystem (GitHub code-scanning, Azure DevOps, Sonar, Snyk).
- Two-phase ADR-0046 enforcement is materially strengthened: the design-phase MD now has detector teeth, not just review prose.

### Neutral
- `schema_version` of the handoff contract unchanged. The new `applies_to_prose` rule flag lives in `active.json`'s rule shape (CTP-owned); the handoff contract continues to consume `applicable_rules` as opaque IDs.
- No `claude-tdd-pro` path touched from the harness (D-6 honored). The path is the proposal, not an in-place edit.
- The existing audit chain (`audit-applicable-rules.sh`, `audit-eo-governance.sh`, `audit-rules-verified.sh`, the dynamic Fix C gate) reads `active.json` live, so new namespaces flow through automatically when the pin bumps.

### Negative / cost
- LLM-judge token cost for the Layer 2 detectors is non-zero. Mitigated by `(rule_body_hash, prose_section_hash)` caching and the two-phase trigger; an unmitigated session running judge on a deep architecture corpus could be expensive, so the cache is non-optional.
- Operator UX gains a new failure mode: a prose `red` blocks dispatch. This is desired (the whole point) but is a new gate operators must learn to either rewrite prose or land a deviation row. Documented in the kata runbook and `docs/first-time-guide.md`.
- Until PROPOSAL-003 lands, the operator-visible state is: layer-1 + layer-2 detectors absent from `active.json`, the MD/`g-arch-*` floor in `audit-applicable-rules.sh` warns vacuously, and the kata's MD coverage remains gap-disclosed (not gap-fixed). The honest report stays the operator's primary artifact in the interim.

## Verification (this CL)

- This ADR is the GCTP-side specification record. Wiring CLs land separately and each carries its own verification:
  - CL-A — extend `audit-applicable-rules.sh` with the `.md → g-md-* + applies_to_prose:true` floor + unit tests (vacuous on registry-empty; under-scope on MD-only ticket; pass on full union; `applies_to_prose` flag honored when present, ignored when absent).
  - CL-B — add `scripts/sarif-aggregate.sh` + tests (single-file detector emission, multi-rule aggregation, OASIS schema validation, exit-code mapping for non-SARIF detectors).
  - CL-C — extend the dispatch gate so design-phase MD is scored before `dispatch.sh` will emit (composes on ADR-0046; tests for design-red blocks dispatch, deviation row unblocks, code-phase drift fires `drift-detected`).
  - CL-D — kata-runbook update + `docs/first-time-guide.md` update documenting the new failure modes and the deviation-row workflow.
- All four CLs are vacuous-green until PROPOSAL-003 lands; the existing audit chain remains green.

## Implementation references

- **New (this ADR):** `docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md`; `proposals/PROPOSAL-003-yaml-json-md-corpora-and-llm-judge.md` (paired CTP-side ADR draft).
- **Modified (this CL, this ADR only):** `docs/adr/INDEX.md` (regenerated via `regenerate-index.sh`).
- **Wiring (later CLs):** `scripts/audit-applicable-rules.sh` (MD floor + `applies_to_prose` union), `scripts/sarif-aggregate.sh` (new), `scripts/dispatch.sh` (design-phase MD gate per ADR-0046), `docs/kata-runbook.md`, `docs/first-time-guide.md`.
- **Composes on:** ADR-0046 (two-phase enforcement), ADR-0055 (EO-spine), ADR-0056 (consult loop / stage-5 roadmap), ADR-0057 (agent compact), ADR-0058 (`enforce.sh` `not_applicable` neutral), ADR-0060 (Fix A — decompose union + language-floor gate), ADR-0062 (Fix B — real detector verdicts), ADR-0063 (Fix C — dynamic re-run gate), ADR-0064/0065 (refresh cadence).
- **Hands off to:** PROPOSAL-003 (CTP-side rule content + `prose-judge.sh` engine). When that lands and a pin bump (ADR-gated) adopts it, this ADR's wiring CLs flip from vacuous-true to live.
