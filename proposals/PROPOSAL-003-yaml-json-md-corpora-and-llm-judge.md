# PROPOSAL-003 — YAML/JSON/MD rule corpora + `prose-judge.sh` LLM-judge engine (CTP-side ADR draft)

**Status:** Draft / RFC for the `claude-tdd-pro` (CTP) development chat.
**Author provenance:** GCTP session 2026-06-19. The PATH A ground-truth audit of the O'Reilly kata submission (`softarchcert-win25`) exposed that **46 of 77 files** in the app tree had no detector in `active.json` that could fire on them (33 `.md`, 11 `.json`, 2 `.gitignore`). The operator's three-turn directive then escalated the request: (1) enforce all rules on every file; (2) seed standards for YAML; (3) project every code rule onto architectural prose in MD via a semantic layer. This proposal is the CTP-side response that the GCTP-side ADR-0066 hands off to.
**Authority:** TIER-1 process change; the CTP team lands it as an ADR in `claude-tdd-pro/docs/adr/` (or wherever the plugin's ADR root sits) per the architecture-amendment process. Respects the prime directive — GCTP owns the enforcement spine; CTP owns rule content; the two meet at the contract surface (`active.json` + the pinned plugin-cache detectors). No cross-repo edits from the harness.
**Paired with:** GCTP ADR-0066 (`docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md`).

The draft ADR body below is written **as the CTP team should adopt it**, so the CTP maintainers can copy it into the plugin's ADR tree, renumber, and land it without rewriting the substance. Bracketed `[CTP-…]` placeholders mark fields the CTP side owns (their ADR number, their pin commit, their schema-version bump).

---

# CTP-ADR-[NNNN] — YAML/JSON/MD rule corpora + `prose-judge.sh`: semantic projection of `active.json` onto architectural prose

- **Status:** Proposed (drafted as PROPOSAL-003 in GCTP `proposals/`; adopted into CTP at [CTP-pin]).
- **Date:** [CTP-adoption-date]
- **Deciders:** drumfiend21 (architect; directive 2026-06-19) + Claude (GCTP cloud session, research) + [CTP-team-reviewers].
- **Scope:** plugin substrate — `standards/`, `rubric/detectors/`, `generated-code-quality-standards/`, `commands/`, `SKILL.md` trio, and the rule-shape extension in `active.json`. Lands the YAML, JSON, and MD corpora researched in GCTP session 2026-06-19 (full per-context tables persist in the GCTP transcript and in `proposals/PROPOSAL-003-…`). Introduces the `applies_to_prose` rule flag and the `prose-judge.sh` semantic detector. Composes on §28.21 (universal coverage), §28.23 (refresh significance), and CTP's existing LLM_JUDGE shell-out pattern (`no-any.sh`, `naked-throw.sh`).

## Trigger

The GCTP harness's PATH A audit of the O'Reilly kata submission returned `pass:19 / fail:13 / not_applicable:10 / not_enforced:0` against the current 42-rule `active.json` — but only **31 of 77** files in the kata tree had any detector that could bite on them. The remaining 46 (33 `.md` architecture docs and ADRs, 11 `.json` config + engine dumps, 2 `.gitignore`) were unenforced because **no rule namespace exists for them in the plugin** today. The operator then issued a three-part directive: enforce every rule on every file, seed YAML standards, and apply every existing code rule **semantically** to architectural prose in MD ("if it is architectural… it needs to abide by the rules, standards, and patterns that CTP/GCTP uses"). The harness side cannot author rule content (prime directive); this proposal lands the content + engine in CTP.

## Context

A GCTP research bundle assembled this session catalogues, with stable URLs / license / refresh-friendliness / per-source key rules / enforcement feasibility:

- **YAML (75 sources)** — YAML 1.2.2 + yamllint; Kubernetes upstream (PSS / config / RBAC / Secrets); Helm; Docker Compose; GitHub Actions (security-hardening, OIDC, pin-by-SHA, `pull_request_target` hygiene, concurrency, no-script-injection); GitLab CI; Azure DevOps; CircleCI / Bitbucket / Jenkins; Ansible (ansible-lint); CloudFormation; OpenAPI (Spectral); GitOps (Argo CD, Flux, Kustomize, Sealed Secrets, SOPS); observability (Prometheus, Grafana, OTel Collector); service meshes (Istio, Envoy, Kong); and the IaC-linter aggregators (kube-linter, Polaris, Trivy-checks, Checkov, Kubescape, conftest). License posture: Apache 2.0 / CC-BY / CC-BY-SA dominate; GPL flagged for yamllint + ansible-lint (config-only mirror, rule descriptions fine); cite-link-only for CIS K8s Benchmark, Microsoft Learn, AWS CFN docs, Snyk.

- **JSON (40 sources + SchemaStore's 700+ schemas)** — RFC 8259 / ECMA-404 / RFC 7493 (I-JSON); JSON Schema (drafts 4/6/7/2019-09/2020-12); OpenAPI 3.x JSON variant; JSON-LD; JSON:API; JSON-RPC; **RFC 8725 JWT BCP (the highest-leverage P0 cluster — `alg:none`, alg-allowlist, key-confusion, iss/aud validation, kid sanitization)**; package.json + lockfiles (npm/composer/Pipenv); tsconfig; `.vscode/` + devcontainer.json; AWS IAM (`"Action": "*"` family); GCP IAM (`allUsers`/`allAuthenticatedUsers`); Azure RBAC (custom-role wildcards); k8s JSON manifests; Helm `values.schema.json`; Renovate; CFN/Terraform JSON; OPA bundle manifest; **CycloneDX 1.6 + SPDX 2.3 JSON schemas (SBOM)**; **SARIF 2.1.0 (proposed as the universal detector output bus)**; OTel JSON; CloudEvents; Schema.org JSON-LD; Elastic Common Schema. License posture: IETF RFC public domain + Apache + MIT + W3C/OASIS RF dominant.

- **MD (40 sources, two layers)** —
  - **Layer 1 (syntactic):** CommonMark 0.31.2, GitHub Flavored Markdown, markdownlint (MD001..MD060), remark-lint, Vale + errata-ai style packs (Google / Microsoft / write-good / alex / proselint), markdown-link-check + lychee, cspell + codespell, REUSE 3.3, Hugo/Jekyll/Docusaurus frontmatter, Mermaid + PlantUML.
  - **Layer 2 (semantic / prose-as-code):** MADR 4.0, Nygard, Y-Statements, arc42 (12 sections), C4 model, RFC 2119 + RFC 8174, Diátaxis, Write the Docs, Google + Microsoft writing style guides, standard-readme + Make a README + GitHub opensource.guide, Conventional Commits, Keep a Changelog, SemVer, Contributor Covenant, OWASP STRIDE + LINDDUN, GitHub Advisory Database.

The operator's prose-as-code principle is the architecturally novel piece: every rule in `active.json` (today's 42, tomorrow's 200+) must ALSO bind architectural MD prose. An ADR claiming a design that would violate `g-aws-no-unrestricted-ingress` should red-flag in plain English, before the implementing Terraform is written. CTP's existing LLM_JUDGE shell-out pattern (already in `no-any.sh` + `naked-throw.sh`) is the substrate; this ADR generalizes it to a first-class detector.

## Decision

### CTP-D-1. Add 22 new rule namespaces.

Authored under `claude-tdd-pro/standards/` + `rubric/` + `generated-code-quality-standards/` with the source-citation discipline §28.23 demands (every rule carries `provenance[]` with author, source URL, retrieval date, license, version-or-commit pin). The namespaces, paired to their highest-leverage seed sources (full per-context tables in GCTP's research bundle):

| Namespace | Seed source(s) (Apache/MIT/CC unless noted) | Representative rule IDs (P0 anchors) |
|---|---|---|
| `yaml` | yamllint default.yaml (GPLv3, config-only mirror) + YAML 1.2.2 spec | `g-yaml-no-tabs-indent`, `g-yaml-no-bare-norway`, `g-yaml-key-duplicates`, `g-yaml-utf8-only` |
| `k8s` | Pod Security Standards (CC-BY-4.0) + kube-linter checks.md + kubeconform | `g-k8s-no-privileged`, `g-k8s-run-as-non-root`, `g-k8s-no-host-network`, `g-k8s-resource-requests-set`, `g-k8s-rbac-no-star`, `g-k8s-schema-valid` |
| `helm` | helm.sh chart-best-practices | `g-helm-chart-yaml-required-fields`, `g-helm-semver-chart-version`, `g-helm-no-secret-default-values` |
| `compose` | compose-spec/compose-spec | `g-compose-no-host-network`, `g-compose-secrets-not-env`, `g-compose-no-privileged`, `g-compose-pin-image-digest` |
| `gha` | docs.github.com Actions (CC-BY-4.0) + Checkov github_actions.md | `g-gha-pin-actions-by-sha`, `g-gha-permissions-explicit`, `g-gha-no-pull-request-target-checkout-head`, `g-gha-oidc-over-secrets`, `g-gha-no-script-injection` |
| `glci` | docs.gitlab.com/ci + Checkov gitlab_ci.md | `g-glci-pin-image-digest`, `g-glci-protected-variables-for-secrets`, `g-glci-rules-not-only-except` |
| `azdo` | learn.microsoft.com Azure Pipelines (cite-link) + Checkov azure_pipelines.md | `g-azdo-required-template-approval`, `g-azdo-secret-variable-not-logged`, `g-azdo-no-script-on-pr-from-fork` |
| `circleci` / `bbp` / `jenkins` | per-platform docs + community linters | `g-circleci-context-for-secrets`, `g-bbp-secured-variables-marked`, `g-jenkins-no-script-block` |
| `ansible` | ansible-lint (GPLv3, descriptions-only mirror) | `g-ansible-no-log-secrets`, `g-ansible-vault-encrypted-secrets`, `g-ansible-risky-shell-pipe`, `g-ansible-fqcn` |
| `cfn` | AWS CFN docs (cite-link) + cfn-lint + Checkov cloudformation.md | `g-cfn-no-secret-default`, `g-cfn-iam-no-star-action`, `g-cfn-parameters-constrained` |
| `oas` | OAI/OpenAPI-Specification (Apache 2.0) + Spectral oas ruleset | `g-oas-security-schemes-defined`, `g-oas-no-basic-over-http`, `g-oas-no-additionalProperties-true-on-write` |
| `gitops` | Argo CD + Flux + Kustomize + Sealed Secrets + SOPS | `g-argo-sync-wave-on-crd-installs`, `g-flux-decryption-sops-for-secrets`, `g-sealedsecrets-no-plain-secret-in-git`, `g-sops-encrypted-regex-set` |
| `observability` | Prometheus + Grafana + OTel Collector | `g-prom-tls-on-remote-write`, `g-prom-alert-has-for-clause`, `g-otelcol-tls-on-otlp-exporter`, `g-otelcol-pipeline-references-defined-components` |
| `mesh` | Istio + Envoy + Kong | `g-istio-mtls-strict`, `g-envoy-admin-bind-loopback`, `g-kong-no-anonymous-on-auth-routes` |
| `iac-linter` | kube-linter + Polaris + Trivy-checks + Checkov + Kubescape (all Apache 2.0) | wrapper rules that shell out to the canonical linter; SARIF-translated verdicts |
| `json` | RFC 8259 + I-JSON RFC 7493 | `g-json-utf8-only`, `g-json-no-bom`, `g-json-no-duplicate-keys`, `g-ijson-no-surrogate-codepoints` |
| `jsonschema` | json-schema.org Draft 2020-12 + Ajv | `g-jsonschema-pin-draft`, `g-jsonschema-format-assertion-explicit`, `g-jsonschema-no-mixed-drafts-in-bundle` |
| `iam` | AWS IAM grammar + best-practices + Checkov CKV_AWS_* | `g-iam-no-action-star`, `g-iam-no-resource-star`, `g-iam-no-notprincipal-with-allow`, `g-gcpiam-no-allusers`, `g-azurerbac-no-actions-star` |
| `sbom` | CycloneDX 1.6 + SPDX 2.3 raw schemas | `g-cdx-specversion-supported`, `g-cdx-components-purl-present`, `g-spdx-datalicense-cc0`, `g-spdx-documentnamespace-uri` |
| `sarif` | OASIS SARIF 2.1.0 schema | self-conformance rules so the harness's own SARIF output validates; `g-sarif-version-literal`, `g-sarif-results-have-ruleId` |
| `jwt` | RFC 7519 + **RFC 8725 BCP** | `g-jwt-no-alg-none` (P0), `g-jwt-alg-allowlist`, `g-jwt-no-key-confusion`, `g-jwt-validate-iss`, `g-jwt-validate-aud`, `g-jwt-no-password-as-hmac-key` |
| `md` | CommonMark + GFM + markdownlint (MIT) | `g-md-fenced-code-language-declared` (MD040 wrapper), `g-md-required-headings` (MD043 wrapper — enforces MADR / arc42 shape mechanically), `g-md-no-duplicate-headings`, `g-md-link-fragments-resolve` |
| `arch` | MADR 4.0 + arc42 + C4 + RFC 2119 + Diátaxis + STRIDE/LINDDUN + Contributor Covenant + Conventional Commits + Keep a Changelog + SemVer + standard-readme | semantic projection rules; see CTP-D-3 |

### CTP-D-2. Extend the rule shape with `applies_to_prose: bool`.

In every rule's JSON shape under `active.json`, add an optional `applies_to_prose` flag (default `false`). When `true`, GCTP's `/decompose` (per harness ADR-0066) includes the rule in the `applicable_rules` of any ticket whose `file_scope.may_edit` touches `**/*.md`, and `enforce-standards.sh` invokes the rule via `prose-judge.sh` (CTP-D-3) instead of the rule's regular code-shape detector. The flag is content-agnostic: a code rule promoted to prose enforcement just flips the bit in the standards-pipeline output; no harness change required (`audit-applicable-rules.sh` reads the flag live).

Recommended initial settings:
- **`applies_to_prose: true`** for every rule whose intent can be claimed in prose: IAM least-privilege, encryption-at-rest, no-unrestricted-ingress, provenance, no-known-exploited-ingress, OAS security schemes, JWT alg discipline, K8s privileged/host-network/root-fs, secret-handling, SBOM presence, etc. Effectively: every `g-aws-*` / `g-azure-*` / `g-gcp-*` / `g-iam-*` / `g-security-governance-*` / `g-slsa-*` / `g-owasp-*` / `g-jwt-*` / `g-k8s-*` (security subset) / `g-oas-*` (security subset) rule.
- **`applies_to_prose: false`** for rules that are mechanically about syntax (`g-yaml-no-tabs-indent`, `g-md-fenced-code-language-declared`, `g-json-utf8-only`, `g-ts-001`).

### CTP-D-3. New detector: `prose-judge.sh` (LLM-judge engine, generalized).

A new entry under `rubric/detectors/prose-judge.sh` that the standards pipeline references as the `detector` for every `g-arch-*` rule AND for any other rule with `applies_to_prose: true`. Contract:

- **Input flags** (composing with the existing `§2.2` detector contract — `--json`, `--paths`, `--dry-run`, `--severity`, `--max-violations`, `CLAUDE_PLUGIN_ROOT`):
  - `--rule <rule-id>` — the rule body to judge against (read live from `active.json`).
  - `--paths <glob>` — defaults to `**/*.md` if absent.
  - `--llm-judge` (or honor `LLM_JUDGE=1` env) — opt-in semantic mode; absence ⇒ regex-only fallback returning `not_enforced` for any prose section that contains rule-keyword hits but cannot be judged.
- **Pipeline:**
  1. Tokenize each `.md` via `remark-parse` (or a yq-on-AST equivalent that ships in the plugin cache) into `{section_path, heading_level, prose_body, fenced_code_by_language, frontmatter}`. Sections inherit a `kind` from frontmatter (`kind: architecture | adr | readme | changelog | …`).
  2. For each (section, rule) pair where the section's `kind` is in the rule's `applies_to_prose_kinds[]` (default `[architecture, adr]`; configurable per rule), construct a judge prompt of the form `{rule_id, rule_body_verbatim_from_active_json, section_prose_verbatim}` and ask **YES (violates) / NO (compatible) / ABSTAIN (insufficient signal)**.
  3. Cache by `sha256(rule_body_verbatim) ++ sha256(section_prose_verbatim)` — re-judge only on hash change.
  4. Aggregate: file-level `red` if any (section, rule) → YES; `yellow` if all NO + ≥1 ABSTAIN on a P0 rule; `green` otherwise.
- **Output:** SARIF 2.1.0 (CTP-D-5). Each YES becomes a SARIF `result` with `ruleId`, `level: error`, `locations[].physicalLocation` pointing at the offending heading line, `message.text` = the judge's one-sentence rationale, `properties.judge_model`, `properties.judge_confidence`, `properties.rule_body_sha`, `properties.section_sha`.
- **Fallback:** when the model CLI is unavailable, `prose-judge.sh` returns `not_enforced` per rule (not `pass`) so GCTP's Fix C dynamic gate (ADR-0063) keeps the verdict `red` until the judge runs. No silent green.

### CTP-D-4. New Layer-1 detector wrappers under `md`/`yaml`/`json` namespaces.

Each is a thin shell-out to a canonical tool, exit-code mapped + SARIF-translated. Apache/MIT/ISC tools preferred:

- `md-syntax.sh` → markdownlint-cli2 (MIT). Maps MD040 to `g-md-fenced-code-language-declared`, MD043 to `g-md-required-headings`, etc.
- `md-prose.sh` → Vale (MIT) with `errata-ai/Google` + `errata-ai/Microsoft` + `errata-ai/alex` packages loaded.
- `md-links.sh` → lychee (Apache 2.0 OR MIT).
- `md-spell.sh` → cspell (MIT) + codespell (GPL — descriptions only).
- `md-license.sh` → `reuse lint` (CC-BY-SA / GPL — wrapper only).
- `mermaid.sh` → `mmdc --validate` (MIT).
- `yaml-syntax.sh` → yamllint (GPLv3 — config-only mirror; rule descriptions fine).
- `yaml-iac.sh` → multiplexer for `kube-linter | trivy config | checkov | conftest | spectral | promtool | ansible-lint | cfn-lint`, one per applicable file class.
- `json-schema.sh` → Ajv (MIT) with SchemaStore catalog.
- `json-iam.sh` → grep+regex tier for the AWS/GCP/Azure IAM wildcards; Checkov tier for semantic checks.
- `sbom-validate.sh` → cyclonedx-cli (Apache 2.0) + `spdx-tools` (Apache 2.0).
- `jwt-bcp.sh` → regex/grep on serialized JWTs + JWK Sets, applying RFC 8725 rules.

### CTP-D-5. SARIF 2.1.0 as the universal detector output bus.

Every new detector (and, on a follow-up CL, every existing one) emits SARIF 2.1.0 conforming to the OASIS schema (https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json). The plugin caches the schema and validates each emission. GCTP's `scripts/sarif-aggregate.sh` (per ADR-0066 CL-B) concatenates per-rule SARIF into one log per CL. Composing into the wider security tool ecosystem (GitHub code-scanning, Azure DevOps, Sonar, Snyk) is a free byproduct.

### CTP-D-6. Refresh discipline covers the new sources.

`standards/initial-refresh.sh` (the begin-on-install + first-use-of-day mechanism per §28.23) enumerates the new corpora's raw-URL seeds. The full per-source list — with refreshability and license per row — lives in this proposal's appendix and in the GCTP research bundle. License posture is the gating filter: only sources whose license permits re-distribution are mirrored; cite-link-only sources (CIS, AWS docs, MS Learn, Snyk, the two Norway-problem blog posts, ISO 42010) are referenced by URL with no body mirror. GPL sources (yamllint, ansible-lint, codespell) ship as config-only mirrors with prominent attribution; rule descriptions are independently authored under CTP's license to avoid copyleft drift in detector code.

### CTP-D-7. Schema-version bump.

The introduction of `applies_to_prose` in the rule shape is an additive field with a safe default (`false`). Bump `active.json`'s `schema_version` from `[CTP-current]` → `[CTP-next]` so GCTP's audit chain can branch on capability cleanly. The handoff contract (`docs/handoff-contract.md`) does NOT bump — `applicable_rules` continues to consume rule IDs as opaque strings.

## Alternatives considered

- **Author a single mega-detector that handles all 22 new namespaces.** REJECTED — violates §2.2's per-rule detector contract; makes failure attribution opaque; precludes per-rule SARIF; breaks the existing `enforce.sh` loop.
- **Bundle prose-judge as a CTP-internal feature flag rather than a flag in the rule shape.** REJECTED — that hides the opt-in from the rule registry, and GCTP's `audit-applicable-rules.sh` (ADR-0060) cannot then enforce the prose floor. The flag belongs in the rule body so the channel is transparent.
- **Make `applies_to_prose` default `true` for every rule.** REJECTED for v1 — too aggressive a default; many syntactic rules (`g-yaml-no-tabs-indent`) have no meaningful prose analog and would generate ABSTAIN noise. Defaulted `false`; promote per rule.
- **Skip SARIF; define a CTP-native finding format.** REJECTED — same reasoning as harness ADR-0066: fragments the ecosystem for no benefit. SARIF is OASIS-standard; every linter in the corpora emits it.
- **Make prose-judge eager (run on every MD, every session).** REJECTED — unbounded token cost. The two-phase trigger (design-phase before dispatch; code-phase before merge) plus the hash cache bounds cost. Eager mode opt-in only via `CLAUDE_TDD_PRO_PROSE_JUDGE_EAGER=1`.
- **Pull the LLM-judge engine entirely from inside CTP and require GCTP to ship it.** REJECTED — that's the prime-directive violation in the opposite direction. The engine is rule content + detector substrate; it belongs in CTP.

## Consequences

### Positive
- The 46-file enforcement dead zone on GCTP's PATH A audit closes once this lands. The kata's architecture decision log, ADRs, SUBMISSION.md, C4 diagrams, cost-benefit model, traceability matrix, and CTP-engine JSON all become first-class enforcement targets.
- The prose-as-code principle is structural: any rule the plugin authors becomes enforceable against the design prose by flipping a single flag in `active.json` — no harness change, no per-rule wiring, no schema-version bump on the handoff contract.
- SARIF as the output bus earns interoperability with the wider security tooling stack (GitHub code-scanning, Sonar, Snyk, Azure DevOps).
- Coverage in YAML deepens markedly: kube-linter + Trivy + Checkov + Kubescape + Polaris layered through the `iac-linter` namespace gives 1000+ effective rules per scan against a typical k8s/IaC tree.
- The JWT BCP cluster (RFC 8725) alone closes one of the most-exploited prose-vs-code drifts in the industry — an ADR proposing `"alg": "none"` for "dev convenience" red-flags before the code is written.
- The harness side (ADR-0066) is a pure consumption update: no rule content in-tree; the channel (`active.json`) is unchanged; the language-floor gate extends mechanically.

### Neutral
- `schema_version` bump on `active.json` only; the handoff contract is stable.
- The existing namespaces (`google`, `aws`, `azure`, `gcp`, `hashicorp`, `node`, `owasp`, `react`, `slsa`, `typescript`, `us-government`, `w3c`, `web-vitals`, `_community`, `security-governance`) are untouched. Composition with EO-2026 (ADR-0045/0047/0055) is additive — never subtractive — so the EO spine stays load-bearing.

### Negative / cost
- LLM-judge token cost for Layer 2 is non-zero. Mitigated by the hash cache + the two-phase trigger; an unmitigated session running judge on a deep architecture corpus could be expensive, so the cache is non-optional.
- Plugin substrate grows materially — 22 new namespaces, ~30 new detector wrappers, the `prose-judge.sh` engine, SARIF emission across all detectors. The change is large enough that it warrants a tracking ticket and likely lands in waves (suggested: wave 1 = `yaml`+`k8s`+`md`+`arch` Layer-1; wave 2 = `json`+`jwt`+`iam`+`sbom`+`sarif`; wave 3 = `gha`+`glci`+`azdo`+`circleci`+`bbp`+`jenkins`+`ansible`+`cfn`+`oas`+`gitops`+`observability`+`mesh`+`iac-linter` and the `prose-judge.sh` semantic engine).
- Refresh sources expand from the current ~15 to ~150. Cadence (ADR-0064/0065 on the GCTP side) absorbs the increase but the per-tick cost grows; recommend tiering raw-MD pin-by-commit sources separately from HTML-scrape sources, with the latter on a slower cadence (e.g. weekly default vs. daily for the raw-MD seeds).

## Verification

- **Wave 1** — adds `yaml` + `k8s` + `md` (Layer 1 only) + `arch` (template-shape rules only, no LLM-judge yet): unit tests for each new detector wrapper (input YAML/MD → expected SARIF), a GCTP-side smoke test that re-runs the PATH A audit on `softarchcert-win25` and shows the .md/.yaml coverage delta (expect MD coverage flips from 0% → ≥90% of files reached by at least one detector).
- **Wave 2** — adds `json` + `jwt` + `iam` + `sbom` + `sarif`: unit tests including the RFC 8725 P0 cluster (positive: `"alg":"none"` red; negative: `"alg":"RS256"` green), an IAM-wildcard test (positive: `"Action":"*"` red; negative: scoped action green), and an SBOM-shape test (positive: missing `bomFormat` red).
- **Wave 3** — adds the CI/CD/IaC family + `prose-judge.sh`: unit tests for each shell-out wrapper + a GCTP-paired test that flips `g-aws-no-unrestricted-ingress.applies_to_prose: true` and asserts an ADR with the prose *"we'll allow 0.0.0.0/0 ingress on dev"* fires the rule against the .md file. The GCTP harness's existing `audit-applicable-rules.sh` (ADR-0060) is exercised after wave 3 to confirm the MD floor lights up under the new union.
- **Standards-refresh** — `standards/initial-refresh.sh` is run against the full new source list in dry-run; the source-cite registry must enumerate every new rule with `provenance[]` per §28.23. Cite-link-only sources fail-closed if mirrored.
- **License audit** — a manual review confirms GPL sources (yamllint, ansible-lint, codespell) ship as config-only mirrors with attribution; no GPL code enters CTP-licensed detector code.

## Implementation references

- **New (this ADR, CTP side):**
  - `claude-tdd-pro/docs/adr/[CTP-NNNN]-yaml-json-md-corpora-and-prose-judge.md` (adopt this proposal verbatim).
  - `claude-tdd-pro/standards/<ns>/...` for each of the 22 new namespaces.
  - `claude-tdd-pro/rubric/detectors/prose-judge.sh` + `md-syntax.sh` + `md-prose.sh` + `md-links.sh` + `md-spell.sh` + `md-license.sh` + `mermaid.sh` + `yaml-syntax.sh` + `yaml-iac.sh` + `json-schema.sh` + `json-iam.sh` + `sbom-validate.sh` + `jwt-bcp.sh` + per-platform CI shell-outs (`gha-*.sh`, `glci-*.sh`, `azdo-*.sh`, `circleci-*.sh`, `bbp-*.sh`, `jenkins-*.sh`, `ansible-*.sh`, `cfn-*.sh`, `oas-*.sh`, `gitops-*.sh`, `observability-*.sh`, `mesh-*.sh`).
  - `claude-tdd-pro/generated-code-quality-standards/<ns>/` for the materialized rule bodies.
  - `claude-tdd-pro/standards/initial-refresh.sh` — extend the source enumeration.
  - Rule-shape schema — add `applies_to_prose: bool` (optional, default false).

- **Modified (CTP side):** `active.json` (new namespaces + `applies_to_prose` flag); `schema_version` bump; `SKILL.md` trio (note the new namespaces + prose-as-code surface).

- **Paired (GCTP side, in this repo):** `docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md` (the harness consumes the new content; the channel is unchanged; the language-floor gate extends to MD).

- **Composes on (CTP side):** §28.21 (universal coverage / `g-universal-*` apply-by-default), §28.23 (refresh significance), the existing `LLM_JUDGE=1` shell-out pattern in `no-any.sh` / `naked-throw.sh`, EO governance (CTP ADR-0045/0047/0055-equivalents).

- **Provenance:** the YAML + JSON + MD research bundles assembled in GCTP session 2026-06-19. Master tables persisted in this proposal's appendix (and in `/tmp/yaml-corpus-report.md` for the YAML half during the authoring session). Every rule body landed under CTP-D-1 must trace to one of those sources, per §28.23.

---

## Appendix — Source manifest (target for CTP's refresh registry)

The full per-context master tables (org / URL / refreshability / license / key rules / enforcement feasibility) for all three corpora are part of this proposal but too long for inline embedding (75 + 40 + 40 = 155 rows). They live verbatim in the GCTP session transcript at the point of authoring (research-agent outputs for YAML, JSON, and MD) and should be lifted into `claude-tdd-pro/docs/standards-source-manifest.md` when this ADR is adopted. Highest-leverage seeds (start here, in priority order):

1. **YAML:** Checkov policy index (Apache 2.0); kube-linter checks.md (Apache 2.0); Trivy-checks Rego repo (Apache 2.0); Kubescape regolibrary (Apache 2.0); yamllint default.yaml (GPLv3, config-only).
2. **JSON:** SchemaStore (Apache 2.0, 700+ schemas); RFC 8725 JWT BCP (public); CycloneDX 1.6 + SPDX 2.3 raw JSON schemas; OASIS SARIF 2.1.0 schema; AWS IAM grammar page (cite-link, regex P0s).
3. **MD Layer 1:** markdownlint Rules.md (MIT); Vale + errata-ai style packs (MIT, MD orchestrator).
4. **MD Layer 2:** MADR 4.0 (MIT/CC0); arc42 (CC-BY-SA-4.0); C4 model (CC-BY-4.0); RFC 2119 + RFC 8174 (public); Diátaxis (CC-BY-SA-4.0).

License posture summary: 80%+ of seeds are Apache 2.0 / MIT / CC-BY / CC-BY-SA / RFC-public — fully mirror-able. Cite-link-only: CIS K8s Benchmark, AWS docs, MS Learn, Snyk, the Norway-problem blog posts, ISO 42010. GPL (config-only mirror, attribution required): yamllint, ansible-lint, codespell.
