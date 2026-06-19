# ADR-0066 — YAML/JSON/MD corpora + prose-as-code enforcement (GCTP side)

- **Status:** Proposed
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect; 2026-06-19 directive across three turns: (1) *"I want all rules enforced on everything created for this kata answer"*; (2) *"identify all the best standards and rules and patterns for writing YAML files"*; (3) *"if it is architectural, whatever it is, if it's going to influence the application that it needs to abide by the rules, standards, and patterns that CTP/GCTP uses"*) + Claude (GCTP cloud session).
- **Scope:** harness self-maintenance — `/decompose`, `/inner-loop`, `/audit`, the language-floor gate (ADR-0060), the deviation discipline, the SARIF aggregation seam, and the dispatch design-phase gate — per the agent-operating-compact (ADR-0057).
- **Pairs with:** **PROPOSAL-003** (CTP-side rule content + LLM-judge engine; lives in `proposals/PROPOSAL-003-ctp-session-brief.md`). This ADR governs the GCTP-side wiring; PROPOSAL-003 governs the CTP-side content. Neither side touches the other.
- **Composes on:** ADR-0046 (two-phase enforcement), ADR-0055 (EO-spine activation), ADR-0058 (`enforce.sh` `not_applicable` neutral), ADR-0060 (Fix A — decompose union + language-floor gate), ADR-0062 (Fix B — `enforce-standards.sh` real verdicts), ADR-0063 (Fix C — dynamic re-run gate), ADR-0064/0065 (refresh cadence).
- **Stable references:**
  - `docs/standards-sources-yaml.md` — 75-source YAML corpus master table (license + URL + refreshability per row).
  - `docs/standards-sources-json.md` — 40+ source JSON corpus master table + SchemaStore meta-catalog.
  - `docs/standards-sources-md.md` — 40-source MD corpus master table, two layers.
  - `proposals/PROPOSAL-003-ctp-session-brief.md` — paired CTP-side ADR draft + full `prose-judge.sh` contract + rule namespace catalog.

## Trigger

The PATH A audit of the O'Reilly kata submission (`../softarchcert-win25`) against all 42 rules in `active.json` returned `pass:19 / fail:13 / not_applicable:10 / not_enforced:0` — a `red` status, but the **honest finding was the coverage gap**: only **31 of 77 files** had any detector that could fire on them.

| File type in app tree | Count | Detector status | Status |
|---|---:|---|---|
| `.ts` (src + test) | 27 | TS / Node / OWASP / SLSA / Google rules fire | enforced |
| `.tf` (Terraform) | 3 | AWS / Azure / GCP / Hashicorp / US-Gov / security-governance | enforced |
| `.yaml` (k8s manifest) | 1 | linux-foundation (thin) | enforced |
| **`.md`** (33 architecture docs, ADRs, README, SUBMISSION, C4 diagrams, decision log) | **33** | **NONE** — no detector exists | **unenforced** |
| **`.json`** (CTP-engine session dumps, package.json, tsconfig, FEATURE artifacts) | **11** | **NONE** | **unenforced** |
| **`.gitignore`** | **2** | **NONE** | **unenforced** |

**46 of 77 files (60%) had no detector in the active registry that could bite on them.** The operator's three-turn directive escalated this from "log the gap" to "primary thing to close, including the semantic projection of every code rule onto architectural prose."

## Context

Three research corpora were assembled this session as the seed (read-only research; no plugin edits, per prime directive). They now live as stable in-repo manifests:

- **YAML — 75 sources** (`docs/standards-sources-yaml.md`): YAML 1.2.2 spec, yamllint, k8s upstream (PSS / config / RBAC / Secrets), Helm, Compose, GitHub Actions (security-hardening / OIDC / pin-by-SHA / `pull_request_target` hygiene / concurrency / no-script-injection), GitLab CI, Azure DevOps, CircleCI / Bitbucket / Jenkins, Ansible, CloudFormation, OpenAPI (Spectral), GitOps (Argo CD / Flux / Kustomize / Sealed Secrets / SOPS), observability (Prometheus / Grafana / OTel Collector), service meshes (Istio / Envoy / Kong), IaC-linter aggregators (kube-linter / Polaris / Trivy / Checkov / Kubescape / conftest). License posture: Apache 2.0 / CC-BY / CC-BY-SA dominate.
- **JSON — 40+ sources + SchemaStore's 700+ schemas** (`docs/standards-sources-json.md`): RFC 8259 / ECMA-404 / RFC 7493 (I-JSON), JSON Schema (drafts 4/6/7/2019-09/2020-12), OpenAPI JSON variant, JSON-LD, JSON:API, JSON-RPC, **RFC 8725 JWT BCP** (highest-leverage P0 cluster), package.json + lockfiles, tsconfig, `.vscode/` + devcontainer.json, AWS IAM / GCP IAM / Azure RBAC, k8s JSON manifests, Helm `values.schema.json`, Renovate, CFN/Terraform JSON, OPA bundle manifest, **CycloneDX 1.6 + SPDX 2.3** (SBOM), **SARIF 2.1.0**, OTel JSON, CloudEvents, Schema.org JSON-LD, Elastic Common Schema.
- **MD — 40 sources, two layers** (`docs/standards-sources-md.md`):
  - **Layer 1 syntactic:** CommonMark, GFM, markdownlint MD001..MD060, remark-lint, Vale + errata-ai style packs, lychee, cspell + codespell, REUSE 3.3, frontmatter schemas (Hugo / Jekyll / Docusaurus), Mermaid + PlantUML.
  - **Layer 2 semantic / prose-as-code:** MADR 4.0, Nygard, Y-Statements, arc42 (12 sections), C4 model, RFC 2119 + RFC 8174, Diátaxis, Write the Docs, Google + Microsoft writing style guides, standard-readme + Make a README + GitHub opensource.guide, Conventional Commits, Keep a Changelog, SemVer, Contributor Covenant, STRIDE + LINDDUN, GitHub Advisory Database.

The harness does NOT mirror rule bodies — those are CTP-owned content (prime directive).

**The operator's prose-as-code principle** is the architecturally novel piece. If `g-aws-no-unrestricted-ingress` fires when a `.tf` declares `cidr_blocks = ["0.0.0.0/0"]`, it must also fire when an ADR says in plain English *"we'll allow unrestricted ingress on the dev cluster for convenience"* — **same rule, same gate, two surfaces (code and design)**. Enforcement requires a semantic detector layer (LLM-judge) alongside the syntactic layer. PROPOSAL-003 specifies the CTP-side `prose-judge.sh`; this ADR specifies how the harness wires it into the existing enforcement spine without authoring any rule content.

## Decision

Eight decisions; D-A through D-H. Each defines a contract or wiring change. Implementation work is itemized as four CLs (CL-A through CL-D) in §"Wiring CLs" below, each with file paths, acceptance criteria, and test names.

### D-A. Consume the new namespaces via the existing channel (zero-touch on the harness control surface).

When PROPOSAL-003 lands in CTP and a pin bump (separate ADR, e.g. ADR-0067) adopts it, `scripts/sync-plugin.sh --ensure` + `scripts/standards-sync.sh` materialize the new rule families into `.harness/rules/active.json` without any code change here. The new namespaces expected at landing — finalized by the CTP team — are:

`yaml`, `k8s`, `helm`, `compose`, `gha`, `glci`, `azdo`, `circleci`, `bbp`, `jenkins`, `ansible`, `cfn`, `oas`, `gitops`, `observability`, `mesh`, `iac-linter`, `json`, `jsonschema`, `iam`, `sbom`, `sarif`, `jwt`, `md` (syntactic), `arch` (semantic projection).

No harness work to add channels; the channel is `active.json` itself. Future CTP-side rule additions to these namespaces flow through automatically on a pin bump.

### D-B. Extend the language-floor gate (ADR-0060) to MD + honor the `applies_to_prose` flag.

`scripts/audit-applicable-rules.sh` (the static gate from ADR-0060) currently gates by typed `file_scope.may_edit` glob extensions: `.ts → g-ts-* + g-node-*`, `.tsx → … + g-react-*`, `.tf → g-hashicorp-*`, `.yaml → g-linux-foundation-*`, plus the universal floor (`g-universal-*`) and EO floor (`security-governance`). This ADR extends the gate with **two new rules**:

1. **Language-floor row for `.md`:** when a ticket's `file_scope.may_edit` contains an explicit `**/*.md` glob, the union MUST include every `g-md-*` rule in `active.json` (Layer 1 floor). Same shape as the existing `.ts → g-ts-*` row.

2. **`applies_to_prose` dimension (NEW):** when a ticket's `file_scope.may_edit` contains an explicit `**/*.md` glob, the union MUST ALSO include every rule in `active.json` for which `applies_to_prose: true` (Layer 2 floor — semantic projection). The flag is read live from `active.json` per rule; new rules promoted by CTP to prose enforcement flow in automatically.

**Both new requirements are content-agnostic.** The gate does not enumerate rule IDs — it computes the floor from `active.json` at runtime. The diff to `audit-applicable-rules.sh` is one additional case in the language-floor table and one filter over `applies_to_prose`. Vacuous when `active.json` is registry-empty for `g-md-*` or `applies_to_prose:true` (no false RED before PROPOSAL-003 lands).

Over-scoping remains safe (per ADR-0058: a rule that matches no prose-applicable section returns `not_applicable` neutral, not `fail`).

### D-C. `/inner-loop` runs both detector layers without harness logic change.

`scripts/enforce-standards.sh` (Fix B / ADR-0062) reads each applicable rule's `detector` field from `active.json` and invokes it. This composition is preserved: Layer 1 detectors (`md-syntax.sh`, `md-prose.sh`, `md-links.sh`, `md-spell.sh`, `md-license.sh`, `mermaid.sh`, `yaml-syntax.sh`, `yaml-iac.sh`, `json-schema.sh`, `json-iam.sh`, `sbom-validate.sh`, `jwt-bcp.sh`, …) ship from CTP under the new namespaces and are exercised exactly like the existing `cloud-guidance-rule.sh` family — no harness change required.

For Layer 2 semantic rules, CTP's `prose-judge.sh` (specified in PROPOSAL-003 CTP-D-3) reads the rule body from `active.json` and shells out to the configured model CLI. It honors the existing `LLM_JUDGE=1` environment toggle (already used in `no-any.sh` / `naked-throw.sh`). When the model CLI is unavailable, `prose-judge.sh` returns `not_enforced` per rule (not `pass`) — which Fix C's dynamic gate (ADR-0063) treats as `red`. **No silent green.**

Operator escape hatch: setting `LLM_JUDGE_PROSE=0` in `.harness/runtime.env` skips semantic enforcement for the session and surfaces `not_enforced` on every prose rule, forcing operator acknowledgement.

### D-D. Two-phase enforcement (composes on ADR-0046) with explicit triggers.

ADR-0046 defines two-phase enforcement at the principle level. This ADR binds the principle to concrete triggers:

**Phase 1 — design-phase MD scoring (before dispatch):** `scripts/dispatch.sh` rejects any handoff request whose `file_scope.may_edit` includes a path matching ANY of:
- glob `docs/architecture/**/*.md`
- glob `docs/adr/**/*.md`
- glob `docs/decisions/**/*.md` (alternate convention)
- any `.md` file whose YAML frontmatter declares `kind: architecture` or `kind: adr`

…until the `applicable_rules` for that ticket have been run against the MD content and the aggregate verdict is `green` OR an entry exists in `<app_root>/docs/deviations.md` referencing the failing rule(s) and the ticket ID.

**Phase 2 — code-phase MD re-scoring (drift detection):** when the implementing code for a feature is dispatched, the design-phase MD is re-scored against the same applicable_rules set. If the verdict differs from the accepted-at-dispatch verdict, the audit chain emits a `drift-detected` signal (warning at session start, hard fail in pre-commit + CI).

The triggers are config-agnostic: the gate reads frontmatter via the same `remark-parse`-based tokenizer used by `prose-judge.sh` and falls back to path heuristics when no frontmatter is present.

### D-E. SARIF 2.1.0 as the universal output bus — `scripts/sarif-aggregate.sh` contract.

Every detector wired through `enforce-standards.sh` is expected to emit SARIF 2.1.0 (per the OASIS schema; cached in the plugin per PROPOSAL-003 CTP-D-5). The harness aggregates per-ticket via a new script:

**`scripts/sarif-aggregate.sh`** — full contract:

| Flag | Required | Description |
|---|---|---|
| `--ticket TICKET-NNN` | yes | Ticket whose detector outputs to aggregate. |
| `--inputs <dir>` | no (default `.harness/audit/sarif/raw/TICKET-NNN/`) | Directory of per-rule SARIF files: `<rule-id>.sarif.json`. |
| `--output <path>` | no (default `.harness/audit/sarif/TICKET-NNN.sarif.json`) | Aggregated SARIF log path. |
| `--schema <path>` | no (default `.harness/plugin-cache/claude-tdd-pro/schemas/sarif-2.1.0.json`) | OASIS schema for validation. |
| `--strict` | no | Exit 2 on any validation failure (default: warn). |
| `--summary` | no | Also write `.harness/audit/sarif/TICKET-NNN.summary.json` (compact: counts per rule, top offending files). |

**Behavior:**
1. Enumerate `<inputs>/*.sarif.json`.
2. Validate each file against the OASIS schema (skip with warning if invalid; in `--strict` mode, exit 2).
3. Merge into a single `sarifLog` with `version: "2.1.0"`, `$schema` set, and one `runs[]` entry per source rule's `tool.driver` (preserving distinctness — markdownlint's `runs[0]` and prose-judge's `runs[0]` remain separate).
4. Validate the aggregated log against the OASIS schema.
5. Write to `--output`.
6. Exit 0 on success; 1 on aggregation error; 2 on strict-mode validation failure.

**Detector-side contract (consumed by `enforce-standards.sh` per ADR-0062):** detectors write per-rule SARIF to `.harness/audit/sarif/raw/TICKET-NNN/<rule-id>.sarif.json`. Detectors that do NOT natively emit SARIF (legacy `no-any.sh` etc. until they're updated) have their exit-code + stdout wrapped into a minimal SARIF result by `enforce-standards.sh` itself; the wrapper produces a single `result` with `ruleId` = the rule ID, `level` = `error` if exit ≠ 0 else `none`, `message.text` = a one-line summary.

**Consumption:** the audit chain (`audit-applicable-rules.sh`, `audit-rules-verified.sh`, the Fix C dynamic gate) reads `.harness/audit/sarif/TICKET-NNN.sarif.json` as the canonical detector-output surface. The existing `req.json` / `res.json` handoff contract is unchanged; the SARIF log is auxiliary.

### D-F. Deviation discipline — visible scoping, never silent exclusion.

Per the operator's directive (*"don't exclude anything"*), no rule is preemptively dropped from `applicable_rules`. When an over-scoped rule cannot apply (e.g. `g-azure-encrypt-at-rest` against an AWS-only project), the operator records a row in `<app_root>/docs/deviations.md` using this format:

```markdown
## Deviation — <RULE-ID> on <TICKET-ID>

- **Rule:** `g-azure-encrypt-at-rest` (P0, source_namespace: azure)
- **Scope:** TICKET-NNN, file_scope `infra/**/*.tf`
- **Why-cannot-apply:** the project is AWS-only per `docs/architecture/adr/0010-data-residency-region-extensible-iac.md`; no Azure resources exist in the tree.
- **Operator acceptance:** <operator-email> on YYYY-MM-DD
- **Re-eval condition:** revisit when ADR-0010 is amended or new clouds enter the architecture.
```

The audit chain (`audit-applicable-rules.sh`) treats `deviated` (rule has a matching row) as `green`. Absence of a deviation row plus a failing verdict stays `red`. A deviation row applies to a single ticket; cross-ticket deviation requires a separate row or an ADR-blessed standing exception.

For the app tree (`app_root`), the file is `<app_root>/docs/deviations.md`. For harness-self-maintenance tickets, the file is the existing `docs/deviations.md` in this repo.

### D-G. Refresh discipline covers the new sources via the existing mechanism.

`scripts/standards-refresh.sh` (ADR-0064) drives CTP's `standards/initial-refresh.sh`, which (per PROPOSAL-003 CTP-D-6) will enumerate the new corpora's raw-URL seeds. No harness work; the cadence governs all sources uniformly. The two-tier cadence recommendation in PROPOSAL-003 (daily for raw-MD pin-by-commit seeds; weekly for HTML-scrape seeds) is honored at the CTP side; the harness consumes whatever cadence CTP declares.

Until PROPOSAL-003 lands, the harness's refresh tick on the new sources is a no-op (vacuous-true). `scripts/standards-refresh.sh --status` surfaces the no-op explicitly so the operator is not surprised.

### D-H. Scope guardrail — the harness does NOT author rule content.

Per the prime directive: the harness MUST NOT define `g-yaml-*` / `g-md-*` / `g-arch-*` / `g-jwt-*` / `g-iam-*` / `g-sbom-*` / `g-sarif-*` rule bodies in-tree. Any in-tree authoring of rule content is a contract violation, regardless of how convenient. When the harness needs a behavior the plugin doesn't expose, the path is PROPOSAL-003 (or a successor), not in-tree authoring.

The single exception: the **stable source manifests** (`docs/standards-sources-yaml.md`, `-json.md`, `-md.md`) live in this repo as a research record — they catalog WHERE rule content should come from. They do NOT author rule bodies; they only specify the sources CTP authors from.

## Worked example — end-to-end trace of the prose-as-code principle

A worked trace, end-to-end, of how the harness behaves once D-A through D-H are wired and PROPOSAL-003 has landed. This is the canonical example the wiring CLs must satisfy.

**Setup:**
- App tree `app_root = ../my-app`. The operator is drafting an ADR for a new feature.
- Plugin pin is at the CTP commit that ships PROPOSAL-003 wave 3 (all 22 namespaces + `prose-judge.sh`).
- `active.json` has `g-aws-no-unrestricted-ingress` with `applies_to_prose: true` and `applies_to_prose_kinds: ["architecture", "adr"]`.

**Step 1 — operator writes the ADR.** They draft `<app_root>/docs/architecture/adr/0015-dev-cluster-network.md`:

```markdown
---
status: proposed
kind: adr
date: 2026-06-19
---

# ADR-0015 — Dev-cluster network posture

## Decision

For developer convenience, we will leave dev-cluster ingress unrestricted
(`0.0.0.0/0` on all egress ports) and rely on a private VPN to keep the cluster
off the public internet. Production stays locked-down per ADR-0010.
```

**Step 2 — operator runs `/decompose` for a ticket that touches this ADR.** The ticket's `file_scope.may_edit` is `docs/architecture/adr/**/*.md` (typed glob). `audit-applicable-rules.sh` (D-B) computes the floor:

- Universal floor: every `g-universal-*` rule (per ADR-0060).
- Language floor (`.md`): every `g-md-*` rule (D-B new row).
- Prose-projection floor: every rule in `active.json` with `applies_to_prose: true` — including `g-aws-no-unrestricted-ingress`, `g-aws-tag-resources`, `g-iam-no-action-star`, `g-jwt-no-alg-none`, the `security-governance` rules, etc.
- EO floor: every `security-governance` rule (per ADR-0055).

The ticket's `applicable_rules` union now includes `g-aws-no-unrestricted-ingress`. If `/decompose` had emitted the ticket without it, `audit-applicable-rules.sh` returns RED.

**Step 3 — operator runs `/dispatch` to emit the contract-valid request.** D-D's design-phase gate fires: the `file_scope.may_edit` matches `docs/architecture/adr/**/*.md`, so dispatch SUSPENDS pending design-phase MD scoring. `scripts/dispatch.sh` invokes `enforce-standards.sh --ticket TICKET-NNN --phase design`.

**Step 4 — `enforce-standards.sh` runs each applicable rule's detector against the MD.** For `g-aws-no-unrestricted-ingress` (which has `applies_to_prose: true`), the rule's `detector` field points to `prose-judge.sh`. `prose-judge.sh`:

1. Tokenizes `<app_root>/docs/architecture/adr/0015-dev-cluster-network.md` into sections.
2. The "Decision" section has frontmatter `kind: adr`, which is in `applies_to_prose_kinds`.
3. Sends `{rule_id: "g-aws-no-unrestricted-ingress", rule_body: "...AWS resources MUST NOT allow ingress from 0.0.0.0/0...", prose_section: "For developer convenience, we will leave dev-cluster ingress unrestricted (0.0.0.0/0 on all egress ports)..."}` to the LLM judge.
4. The judge replies **YES — the prose proposes a design that violates the rule (`0.0.0.0/0` ingress is explicitly forbidden by the AWS no-unrestricted-ingress standard).**
5. Emits SARIF to `.harness/audit/sarif/raw/TICKET-NNN/g-aws-no-unrestricted-ingress.sarif.json` with `level: error`, `locations[].physicalLocation` pointing at the ADR's "Decision" heading, `message.text` = the judge's rationale.

**Step 5 — `sarif-aggregate.sh` (D-E) merges all per-rule SARIF into the per-ticket log.** The aggregate carries the `g-aws-no-unrestricted-ingress: error` finding plus whatever Layer 1 (markdownlint MD040 etc.) and other Layer 2 rules found.

**Step 6 — audit chain reads the aggregated SARIF.** `audit-rules-verified.sh` sees `g-aws-no-unrestricted-ingress` → `fail`. Verdict: RED. `dispatch.sh` REFUSES to emit the request.

**Step 7 — operator sees the gate and decides.** Two paths:

- **Path 1 — rewrite the prose.** Operator edits the ADR to *"We will use a private VPN gateway + an AWS WAF with explicit IP allowlist for developer SSH access; no 0.0.0.0/0 ingress on any port."* Re-runs `/dispatch`. `prose-judge.sh` re-tokenizes; the section hash has changed; cache miss; judge replies NO. Verdict: GREEN. Dispatch proceeds.
- **Path 2 — file a deviation (D-F).** Operator decides the dev-cluster is genuinely isolated by a layer the rule can't see, and adds to `<app_root>/docs/deviations.md`:
  ```markdown
  ## Deviation — g-aws-no-unrestricted-ingress on TICKET-NNN
  - Rule: g-aws-no-unrestricted-ingress
  - Scope: TICKET-NNN, dev-cluster network
  - Why-cannot-apply: dev cluster is in an isolated VPC with no IGW; the "0.0.0.0/0" reference in ADR-0015 is intra-VPC only.
  - Operator acceptance: <email> on 2026-06-19
  ```
  Re-runs `/dispatch`. `audit-rules-verified.sh` sees the deviation row + matching ticket ID; treats the verdict as `deviated`-as-green. Dispatch proceeds.

**Step 8 — code phase (later, per D-D).** When the implementing Terraform lands, `enforce-standards.sh --phase code` re-runs `g-aws-no-unrestricted-ingress` against both the ADR (prose) and the Terraform (code). If the prose verdict changed since dispatch — e.g., operator edited the ADR back to the unsafe form after dispatch — the audit chain emits `drift-detected: TICKET-NNN | g-aws-no-unrestricted-ingress | design-phase-was-green-now-red`. Pre-commit + CI block on this signal.

**Net effect:** the same rule that fires on Terraform also fires on the design prose, **before** the implementing code is written. The operator sees the red in the language they're authoring, not in a code review three steps downstream.

## Wiring CLs — what to build, with acceptance criteria

Four CLs, each independently landable. None are vacuous-RED before PROPOSAL-003 lands — the gates surface no findings when the new namespaces aren't yet in `active.json`. They activate automatically on the CTP pin bump that adopts PROPOSAL-003.

### CL-A — extend `scripts/audit-applicable-rules.sh` with the MD floor + `applies_to_prose` dimension (D-B)

**Files modified:**
- `scripts/audit-applicable-rules.sh` — add the `.md` language-floor case to the typed-glob table; add the `applies_to_prose: true` filter that unions over `active.json` live.
- `tests/test-audit-applicable-rules.sh` — extend with new assertions.

**Files added:**
- `tests/fixtures/req-md-only-underscoped.json` — req with `file_scope.may_edit: ["docs/architecture/adr/**/*.md"]` and `applicable_rules` missing `g-md-*` and prose-projection rules.
- `tests/fixtures/req-md-only-full-union.json` — same with the full union.
- `tests/fixtures/active-json-with-prose-flag.json` — minimal `active.json` carrying one rule with `applies_to_prose: true`.

**Acceptance criteria:**
1. **`test_md_underscope_red`** — running `audit-applicable-rules.sh` against the under-scoped fixture exits 1 with message `"missing required g-md-* floor: g-md-fenced-code-language-declared, g-md-required-headings, ..."`.
2. **`test_md_full_union_green`** — running against the full-union fixture exits 0.
3. **`test_applies_to_prose_floor_red`** — given the active.json fixture with one prose-flagged rule and a req under-scoping it, exit 1 with message `"missing required applies_to_prose floor: g-aws-no-unrestricted-ingress"`.
4. **`test_applies_to_prose_floor_vacuous`** — given an active.json with NO `applies_to_prose: true` rules, the prose-projection floor is empty; exit 0 (vacuous-pass before PROPOSAL-003 lands).
5. **`test_md_extensionless_glob_not_gated`** — a req with `file_scope.may_edit: ["docs/architecture/**"]` (no `.md` extension) does not trigger the MD floor; exit 0. (Forces typed-glob discipline per ADR-0060.)
6. **Existing assertions pass unchanged** — the `.ts → g-ts-* + g-node-*`, `.tsx → … + g-react-*`, `.tf → g-hashicorp-*`, `.yaml → g-linux-foundation-*`, universal-floor, and EO-floor cases (per ADR-0060) all continue to pass.

**Verification command:** `bash tests/test-audit-applicable-rules.sh` exits 0; smoke-e2e remains green.

### CL-B — add `scripts/sarif-aggregate.sh` + tests (D-E)

**Files added:**
- `scripts/sarif-aggregate.sh` — the script. Contract per D-E above.
- `tests/test-sarif-aggregate.sh` — test suite.
- `tests/fixtures/sarif/valid-single-result.sarif.json` — minimal valid SARIF with one result.
- `tests/fixtures/sarif/valid-multi-result.sarif.json` — multi-result, multi-tool.
- `tests/fixtures/sarif/invalid-no-version.sarif.json` — missing required `version` field.
- `tests/fixtures/sarif/invalid-bad-level.sarif.json` — `level: "broken"`.

**Files modified:**
- `tests/README.md` — register the new test.
- `.harness/audit/sarif/.gitkeep` — ensure the audit-sarif directory tree exists.

**Acceptance criteria:**
1. **`test_aggregate_single_file_passthrough`** — given one valid SARIF input, output is a valid SARIF with the same single `runs[0]`. Exit 0.
2. **`test_aggregate_multi_file_merges_distinct_runs`** — given two valid SARIF inputs with different `tool.driver.name`, output preserves both `runs[]` entries (does not collapse). Exit 0.
3. **`test_aggregate_validates_against_oasis_schema`** — output validates against `sarif-2.1.0.json`. Exit 0.
4. **`test_aggregate_invalid_input_warns_non_strict`** — given one valid + one invalid SARIF input, non-strict mode skips the invalid with a stderr warning and aggregates the valid. Exit 0.
5. **`test_aggregate_invalid_input_strict_fails`** — same scenario in `--strict` mode exits 2.
6. **`test_aggregate_empty_inputs_dir_emits_empty_log`** — given no input files, emits a valid SARIF with `runs: []`. Exit 0.
7. **`test_aggregate_summary_compact_correct`** — `--summary` produces a JSON with per-rule counts matching the aggregate.
8. **`test_aggregate_default_paths`** — invoked with `--ticket TICKET-123` only, reads `.harness/audit/sarif/raw/TICKET-123/` and writes `.harness/audit/sarif/TICKET-123.sarif.json`.

**Verification command:** `bash tests/test-sarif-aggregate.sh` exits 0; running `scripts/sarif-aggregate.sh --ticket TICKET-042` (existing TICKET in `.harness/handoffs/`) against an empty input dir produces a valid empty aggregate.

### CL-C — extend `scripts/dispatch.sh` with the design-phase MD gate (D-D)

**Files modified:**
- `scripts/dispatch.sh` — add design-phase gate BEFORE emitting the request. Trigger conditions per D-D (path globs + frontmatter `kind`).
- `tests/test-dispatch.sh` — extend with new assertions.

**Files added:**
- `scripts/_lib/md-tokenize.sh` — small helper that lifts frontmatter `kind` from a `.md` file (uses `yq` if present, falls back to a deterministic awk script). Reused by `prose-judge.sh` consumers.
- `tests/fixtures/app-tree/adr-with-violation/docs/architecture/adr/0015-dev-cluster-network.md` — the canonical worked-example ADR (the unsafe version).
- `tests/fixtures/app-tree/adr-clean/docs/architecture/adr/0015-dev-cluster-network.md` — the rewritten safe version.
- `tests/fixtures/app-tree/adr-with-deviation/docs/architecture/adr/0015-dev-cluster-network.md` + `tests/fixtures/app-tree/adr-with-deviation/docs/deviations.md` — the deviation-row case.

**Acceptance criteria:**
1. **`test_dispatch_md_design_red_blocks`** — req with `file_scope.may_edit` matching `docs/architecture/adr/**/*.md` against the violation fixture: `dispatch.sh` exits 1 with `"design-phase MD scoring failed: g-aws-no-unrestricted-ingress (and N more)"`, no `req.json` written.
2. **`test_dispatch_md_design_green_proceeds`** — same req against the clean fixture: exits 0, `req.json` is emitted.
3. **`test_dispatch_md_design_deviated_proceeds`** — same req against the deviation fixture: exits 0, `req.json` is emitted, a one-line stderr notice mentions the deviation row.
4. **`test_dispatch_md_no_architectural_scope_skips_gate`** — req with `file_scope.may_edit: ["src/**/*.ts"]` and no `.md` in scope: gate does not fire; exits 0. Backwards-compatible for code-only tickets.
5. **`test_dispatch_frontmatter_kind_detection`** — req touching `docs/notes/random.md` whose frontmatter is `kind: architecture` triggers the gate (path heuristic fails but frontmatter wins).
6. **`test_dispatch_path_heuristic_detection`** — req touching `docs/architecture/notes/foo.md` with no frontmatter triggers the gate via path glob.
7. **`test_dispatch_gate_vacuous_when_no_prose_rules`** — when `active.json` has no rules with `applies_to_prose: true` and no `g-md-*` rules, the gate is silently vacuous-pass. Backwards-compatible before PROPOSAL-003 lands.
8. **`test_dispatch_code_phase_drift_detection`** — after a dispatch that was accepted, mutate the ADR so the verdict changes; running `enforce-standards.sh --phase code` against the same ticket emits a `drift-detected` audit signal in stderr.

**Verification command:** `bash tests/test-dispatch.sh` exits 0; `bash scripts/smoke-e2e.sh` remains green (the smoke uses code-only scopes and is unaffected).

### CL-D — operator-facing documentation + kata-runbook update (D-D / D-F operator UX)

**Files modified:**
- `docs/kata-runbook.md` — add a new "PATH C — fix architectural prose under enforcement" section documenting the worked example above.
- `docs/first-time-guide.md` — add a "When dispatch is blocked by design-phase MD scoring" subsection explaining the operator's two paths (rewrite vs. deviation).

**Files added:**
- `docs/deviations-template.md` — copyable template for `<app_root>/docs/deviations.md` rows.

**Acceptance criteria:**
1. The runbook documents both PATH C paths (rewrite vs. deviation) with copy-paste-ready commands.
2. `docs/first-time-guide.md` covers the new failure mode and links to `docs/deviations-template.md`.
3. The template is copyable as-is into any `app_root`.

**Verification:** documentation-only CL; manual review.

## Alternatives considered

- **Author the YAML/JSON/MD rules in the harness so the kata is enforced today.** REJECTED — prime-directive violation. PROPOSAL-003 is the right shape; the two-week speedup is not worth forking the rule pipeline.
- **Make the MD coverage syntactic-only (Layer 1) and skip the LLM-judge layer.** REJECTED — retreats from the operator's prose-as-code directive. An ADR that says *"we'll disable encryption at rest"* would pass MD001..MD060, validate against MADR, and never fire `g-aws-encrypt-at-rest`. Same gate, two surfaces, or the gate is incoherent.
- **Run the LLM-judge layer eagerly on every MD on every session.** REJECTED — unbounded token cost. The hash cache (delegated to the plugin per PROPOSAL-003) plus the two-phase trigger (design-phase before dispatch, code-phase before merge) bounds cost.
- **Adopt a single canonical IaC linter (e.g. Checkov) and treat its catalog as the registry.** REJECTED — couples the harness to one vendor's policy choices and licensing. The corpora preserve the namespace-per-org discipline.
- **Skip SARIF and define a harness-native finding format.** REJECTED — SARIF 2.1.0 is OASIS-standard and consumed by every detector in the corpora. Reusing it earns interop with GitHub code-scanning, Azure DevOps, Sonar, Snyk for free.
- **Drop cross-provider rules from `applicable_rules` instead of demanding deviation rows.** REJECTED — silent-exclusion path the operator explicitly rejected in this session. Deviations stay visible.
- **Make the design-phase gate fire on every `.md` regardless of `kind`.** REJECTED — too aggressive. README and CHANGELOG content shouldn't run heavyweight LLM-judge cycles. The trigger condition (`kind: architecture | adr` OR path-glob match) keeps the gate where the operator authors architecture.

## Consequences

### Positive
- The 46-file enforcement dead zone in the PATH A audit closes once PROPOSAL-003 lands.
- The prose-as-code principle is enforceable by construction, not by reviewer vigilance: an ADR that proposes a design that would violate any rule in `active.json` fires the same gate, in plain language, **before** the implementing code is written.
- The harness gains zero new content-authoring authority — the consumption channel is unchanged.
- SARIF as the output bus makes harness audit output compose into the wider security-tool ecosystem.
- Two-phase ADR-0046 enforcement is materially strengthened — design-phase MD now has detector teeth, not just review prose.
- Drift detection (D-D phase 2) catches prose-vs-code divergence automatically.

### Neutral
- `schema_version` of the handoff contract unchanged. The new `applies_to_prose` rule flag lives in `active.json`'s rule shape (CTP-owned); the handoff contract continues to consume `applicable_rules` as opaque rule-IDs.
- No `claude-tdd-pro` path touched from the harness (D-6 honored). The path is the proposal, not an in-place edit.
- The existing audit chain (`audit-applicable-rules.sh`, `audit-eo-governance.sh`, `audit-rules-verified.sh`, the dynamic Fix C gate) reads `active.json` live, so new namespaces flow through automatically when the pin bumps.

### Negative / cost
- LLM-judge token cost for Layer 2 detectors is non-zero. Mitigated by the cache (CTP-side, per PROPOSAL-003) and the two-phase trigger.
- Operator UX gains a new failure mode: a prose `red` blocks dispatch. This is desired (the whole point) but is a new gate operators must learn. Documented in CL-D.
- Until PROPOSAL-003 lands, the layer-1 + layer-2 detectors are absent from `active.json`, the MD/`g-arch-*` floor in `audit-applicable-rules.sh` is vacuous-pass, and the kata's MD coverage remains gap-disclosed (not gap-fixed). The honest report stays the operator's primary artifact in the interim.
- `scripts/sarif-aggregate.sh` adds a new audit-chain step. Cost is small (single `jq`/`node` pass per ticket) but non-zero.

## Verification (this ADR alone)

This ADR is the specification record. The four wiring CLs (CL-A through CL-D) land separately and each carries its own verification (above). Aggregate-level verification once all four CLs land:

- **`tests/test-all.sh`** — green across the full suite.
- **`smoke-e2e`** — green with the new gates (vacuous-pass before PROPOSAL-003 lands; activates on pin bump).
- **`git diff docs/founder-directives.md` == 0** — D-6 honored.
- **No `.harness/plugin-cache/claude-tdd-pro/**` path edited** — prime directive honored.

## Implementation references

- **New (this ADR):**
  - `docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md` — this file.
  - `docs/standards-sources-yaml.md` — YAML 75-source manifest (stable in-repo mirror).
  - `docs/standards-sources-json.md` — JSON 40+ source manifest + SchemaStore.
  - `docs/standards-sources-md.md` — MD 40-source two-layer manifest.
  - `proposals/PROPOSAL-003-yaml-json-md-corpora-and-llm-judge.md` — paired CTP-side ADR draft (record-keeping).
  - `proposals/PROPOSAL-003-ctp-session-brief.md` — self-contained brief for the CTP development session.

- **Wiring (CL-A through CL-D):** `scripts/audit-applicable-rules.sh`, `scripts/sarif-aggregate.sh` (new), `scripts/dispatch.sh`, `scripts/_lib/md-tokenize.sh` (new), `docs/kata-runbook.md`, `docs/first-time-guide.md`, `docs/deviations-template.md` (new), `tests/test-audit-applicable-rules.sh`, `tests/test-sarif-aggregate.sh` (new), `tests/test-dispatch.sh`, `tests/fixtures/sarif/*`, `tests/fixtures/app-tree/{adr-with-violation,adr-clean,adr-with-deviation}/*`.

- **Composes on:** ADR-0046 (two-phase enforcement), ADR-0055 (EO-spine activation), ADR-0056 (consult loop / stage-5 roadmap), ADR-0057 (agent compact), ADR-0058 (`enforce.sh` `not_applicable` neutral), ADR-0060 (Fix A — decompose union + language-floor gate), ADR-0062 (Fix B — real detector verdicts), ADR-0063 (Fix C — dynamic re-run gate), ADR-0064/0065 (refresh cadence).

- **Hands off to:** PROPOSAL-003 (CTP-side rule content + `prose-judge.sh` engine). When that lands and a pin bump (separate ADR-0067) adopts it, this ADR's wiring CLs flip from vacuous-true to live. The pin bump's verification re-runs the kata PATH A audit and expects MD coverage to flip from 0% → ≥ 90% (per PROPOSAL-003's wave-1 acceptance).

- **Operator entrypoint after landing:** `docs/kata-runbook.md` "PATH C" section + `docs/first-time-guide.md` design-phase-MD-blocked subsection. The worked example in this ADR's §"Worked example" is the canonical end-to-end trace.
