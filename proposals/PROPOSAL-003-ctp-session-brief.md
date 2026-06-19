# CTP Work Brief — YAML/JSON/MD rule corpora + `prose-judge.sh` LLM-judge engine

**Audience:** the `claude-tdd-pro` (CTP) development session.
**Author:** the consuming harness (`grok-claude-tdd-pro`, GCTP) cloud session, 2026-06-19.
**Authority:** TIER-1 process change for CTP. Land as a new ADR in `claude-tdd-pro/docs/adr/` (next sequential number) and the substrate it specifies. Composes on CTP's existing architecture sections — §28.21 (universal coverage / `g-universal-*` apply-by-default), §28.23 (refresh significance), and the existing `LLM_JUDGE=1` shell-out pattern in `no-any.sh` / `naked-throw.sh`.

This brief is self-contained. It carries all the context CTP needs: the originating operator directive, the empirical evidence that triggered the work, how the consuming harness will use the new content, the full source corpora to seed from, the detector specifications, the SARIF output contract, license posture per source, verification criteria, and a suggested landing-waves plan.

---

## 1. Background: how the consumer (GCTP) uses CTP

CTP is consumed by a harness called GCTP as a pinned-by-commit plugin. The two repos are strictly decoupled:

- **CTP** ships rule content (`standards/`, `rubric/detectors/`, `generated-code-quality-standards/`), the three SKILL.md skills (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`), and the refresh / standards-sync machinery.
- **GCTP** ships the enforcement spine: a session-start sync that materializes the pinned CTP cache, generates `.harness/rules/active.json` from CTP's `standards/` + `rubric/` + `generated-code-quality-standards/` pipeline, then drives CTP's detectors against an external app working tree (`app_root`). Per-ticket the harness scopes `applicable_rules` from `active.json` and runs each rule's `detector` against the app tree, collecting real `pass / fail / not_applicable / not_enforced` verdicts.
- **The contract surface is `active.json` + the per-rule `detector` scripts shipped under `rubric/detectors/`.** Every rule entry in `active.json` carries (at minimum) `id`, `severity`, `source_namespace`, `detector` (filename in `rubric/detectors/`), and `provenance[]` (author + URL + retrieval date + license + pin). The CTP team owns the schema of `active.json`; the GCTP harness consumes it as the API.

Important: **CTP does NOT edit GCTP and GCTP does NOT edit CTP.** Work specified here lands entirely in the CTP repo. GCTP's consumption changes are filed in a paired GCTP ADR; CTP does not need to read it.

---

## 2. What triggered this work — the empirical finding

The consuming harness (GCTP) was used to audit a real software-architecture submission (an O'Reilly kata: an AI-assisted grading platform with ~77 files — TypeScript reference implementation, Terraform AWS infra, a Kubernetes manifest, and architecture docs). The audit ran CTP's `enforce.sh` against the full app tree with every rule in the current `active.json` (42 rules across namespaces `aws`, `azure`, `gcp`, `google`, `hashicorp`, `linux-foundation`, `node`, `owasp`, `react`, `security-governance`, `slsa`, `typescript`, `us-government`, `w3c`, `web-vitals`, `_community`).

Result: `pass:19 / fail:13 / not_applicable:10 / not_enforced:0`. CTP's detectors are sound and fast.

But the **coverage gap** is the headline: **only 31 of 77 files in the app tree had any detector that could fire on them.** Breakdown:

| File type | Count | What detector ran | Status |
|---|---:|---|---|
| `.ts` (src + test) | 27 | TS / Node / OWASP / SLSA / Google rules | enforced |
| `.tf` (Terraform) | 3 | AWS / Azure / GCP / Hashicorp / US-Gov / security-governance | enforced |
| `.yaml` (k8s manifest) | 1 | linux-foundation | enforced |
| **`.md`** (architecture docs, ADRs, README, SUBMISSION, C4 diagrams) | **33** | **NONE — no detector exists** | **unenforced** |
| **`.json`** (CTP-engine session dumps, package.json, tsconfig, FEATURE artifacts) | **11** | **NONE — no detector exists** | **unenforced** |
| **`.gitignore`** | **2** | **NONE** | **unenforced** |

**46 of 77 files (60%) were untouchable by any rule in the active registry** — including the entire architecture decision log, all 14 ADRs, the SUBMISSION.md itself, the C4 diagrams, the cost-benefit model, the traceability matrix, and the CTP-engine session JSON. The root cause is on the CTP side: the rule registry has no `g-doc-*`, no `g-yaml-*` (beyond the thin `linux-foundation` k8s subset), and no broad `g-json-*` namespace. Detectors don't fail — they don't exist.

The operator then issued a three-part directive (paraphrased into the canonical statement):

> *"I want every rule enforced on every file. Identify the best free/open/scrapeable standards for YAML and JSON — from the most respected software-engineering departments in the world — for every context where they appear. And for Markdown: if the .md is being used to write architecture that will influence the application, then ALL the same rules, standards, and patterns CTP/GCTP enforces on the code must also bind that prose."*

This is the operational directive this brief implements.

---

## 3. The architecturally novel piece — the prose-as-code principle

This is the part most likely to be unfamiliar in the CTP development chat. State it clearly:

**Every rule in `active.json` (today's 42, tomorrow's 200+) must be enforceable against architectural Markdown prose, not only against the code-shape it currently bites on.**

Concrete example: today, `g-aws-no-unrestricted-ingress` fires when a `.tf` declares `cidr_blocks = ["0.0.0.0/0"]`. Under the prose-as-code principle, the **same rule** must also fire when an Architecture Decision Record (ADR) says in plain English:

> *"For developer convenience, we will leave dev-cluster ingress unrestricted (0.0.0.0/0) and rely on private VPN."*

Same rule, same gate, two surfaces (code and design prose). The MD is a candidate for enforcement before the implementing code is written.

Enforcement of this principle requires a **semantic** detector — regex isn't enough to read prose intent. CTP already has the substrate: the `LLM_JUDGE=1` shell-out pattern in `no-any.sh` and `naked-throw.sh` shows the model. This brief generalizes that pattern into a first-class detector (`prose-judge.sh`) that takes any rule body and any prose section and returns YES (violates) / NO (compatible) / ABSTAIN.

---

## 4. Decision — what to build in CTP

Seven decisions, each independently landable but waves are recommended (§9 below).

### CTP-D-1. Add 22 new rule namespaces under `standards/` + `rubric/` + `generated-code-quality-standards/`.

Each new namespace has the same shape as existing ones: a `standards/<ns>/<rule-id>.md` body (cite-or-decline per §28.23), a `rubric/detectors/<detector>.sh` script, and a generated entry in `active.json` carrying `id`, `severity` (P0/P1/P2/P3), `source_namespace`, `detector`, `provenance[]`, and the new `applies_to_prose: bool` (CTP-D-2).

| Namespace | Highest-leverage seed sources | Representative P0/P1 rule IDs |
|---|---|---|
| `yaml` | YAML 1.2.2 spec (HTML + raw MD); yamllint default.yaml (GPLv3, config-only mirror) | `g-yaml-utf8-only`, `g-yaml-no-bare-norway`, `g-yaml-key-duplicates`, `g-yaml-no-tabs-indent`, `g-yaml-anchor-unique`, `g-yaml-merge-key-explicit` |
| `k8s` | Kubernetes Pod Security Standards (CC-BY-4.0); kube-linter checks.md (Apache 2.0); kubeconform (Apache 2.0) | `g-k8s-no-privileged`, `g-k8s-no-host-network`, `g-k8s-run-as-non-root`, `g-k8s-no-allow-privilege-escalation`, `g-k8s-drop-all-caps`, `g-k8s-read-only-root-fs`, `g-k8s-seccomp-runtime-default`, `g-k8s-pin-image-tag`, `g-k8s-resource-requests-set`, `g-k8s-rbac-no-star`, `g-k8s-no-cluster-admin-binding`, `g-k8s-secret-not-configmap`, `g-k8s-probe-liveness-readiness`, `g-k8s-schema-valid` |
| `helm` | helm.sh chart_best_practices (Apache 2.0) | `g-helm-chart-yaml-required-fields`, `g-helm-semver-chart-version`, `g-helm-values-schema-present`, `g-helm-no-hardcoded-namespace`, `g-helm-no-secret-default-values` |
| `compose` | github.com/compose-spec/compose-spec (Apache 2.0) | `g-compose-no-host-network`, `g-compose-secrets-not-env`, `g-compose-pin-image-digest`, `g-compose-healthcheck-required`, `g-compose-user-non-root`, `g-compose-no-privileged` |
| `gha` | docs.github.com Actions (CC-BY-4.0); Checkov github_actions.md | `g-gha-pin-actions-by-sha`, `g-gha-permissions-explicit`, `g-gha-least-privilege-permissions`, `g-gha-no-pull-request-target-checkout-head`, `g-gha-oidc-over-secrets`, `g-gha-no-script-injection`, `g-gha-concurrency-set` |
| `glci` | docs.gitlab.com/ci (CC-BY-SA-4.0); Checkov gitlab_ci.md | `g-glci-pin-image-digest`, `g-glci-protected-variables-for-secrets`, `g-glci-rules-not-only-except`, `g-glci-cache-key-includes-branch`, `g-glci-no-shell-runner-for-untrusted` |
| `azdo` | learn.microsoft.com Azure Pipelines (cite-link); Checkov azure_pipelines.md | `g-azdo-required-template-approval`, `g-azdo-checkout-clean-pinned`, `g-azdo-secret-variable-not-logged`, `g-azdo-no-script-on-pr-from-fork` |
| `circleci`, `bbp`, `jenkins` | per-platform docs + community linters | `g-circleci-context-for-secrets`, `g-circleci-pin-orb-version`, `g-bbp-secured-variables-marked`, `g-jenkins-no-script-block`, `g-jenkins-pin-agent-image` |
| `ansible` | ansible-lint (GPLv3, rule descriptions independently authored); docs.ansible.com | `g-ansible-no-log-secrets`, `g-ansible-vault-encrypted-secrets`, `g-ansible-risky-shell-pipe`, `g-ansible-fqcn`, `g-ansible-yaml`, `g-ansible-no-changed-when`, `g-ansible-name-required` |
| `cfn` | AWS CFN docs (cite-link); cfn-lint (Apache 2.0); Checkov cloudformation.md | `g-cfn-no-secret-default`, `g-cfn-no-hardcoded-secret`, `g-cfn-iam-no-star-action`, `g-cfn-parameters-constrained`, `g-cfn-stack-policy-protected-resources` |
| `oas` | OAI/OpenAPI-Specification (Apache 2.0); Spectral oas ruleset (Apache 2.0) | `g-oas-spec-version-explicit`, `g-oas-info-required`, `g-oas-security-schemes-defined`, `g-oas-no-basic-over-http`, `g-oas-operation-id-unique`, `g-oas-no-additionalProperties-true-on-write` |
| `gitops` | argo-cd.readthedocs.io (Apache 2.0); fluxcd.io (Apache 2.0); kubernetes.io kustomization; bitnami-labs/sealed-secrets; getsops/sops | `g-argo-sync-wave-on-crd-installs`, `g-argo-no-automated-self-heal-on-prod`, `g-flux-decryption-sops-for-secrets`, `g-sealedsecrets-no-plain-secret-in-git`, `g-sops-encrypted-regex-set`, `g-sops-creation-rules-defined` |
| `observability` | prometheus.io (Apache 2.0); opentelemetry.io collector (CC-BY-4.0); grafana.com (AGPLv3 project, docs CC-BY-NC-SA) | `g-prom-tls-on-remote-write`, `g-prom-alert-has-for-clause`, `g-prom-alert-has-severity-label`, `g-otelcol-pipeline-references-defined-components`, `g-otelcol-tls-on-otlp-exporter`, `g-grafana-datasource-tls-on` |
| `mesh` | istio.io (Apache 2.0); envoyproxy.io (Apache 2.0); docs.konghq.com | `g-istio-mtls-strict`, `g-istio-no-wildcard-host`, `g-istio-no-envoyfilter-without-approval`, `g-envoy-admin-bind-loopback`, `g-envoy-tls-min-version-tls13`, `g-kong-no-anonymous-on-auth-routes` |
| `iac-linter` | kube-linter + Polaris + Trivy-checks + Checkov + Kubescape (all Apache 2.0) | wrapper rules that shell out to the canonical linter; SARIF-translated verdicts; treat as a multiplexer |
| `json` | RFC 8259 (IETF public); RFC 7493 I-JSON; ECMA-404 (ECMA RF) | `g-json-utf8-only`, `g-json-no-bom`, `g-json-no-duplicate-keys`, `g-json-control-char-escaped`, `g-json-integer-safe-range`, `g-ijson-no-surrogate-codepoints` |
| `jsonschema` | json-schema.org Draft 2020-12 (BSD-2-Clause); Ajv (MIT); python-jsonschema (MIT) | `g-jsonschema-pin-draft`, `g-jsonschema-format-assertion-explicit`, `g-jsonschema-no-mixed-drafts-in-bundle` |
| `iam` | AWS IAM grammar + best-practices (cite-link); GCP IAM docs; Azure RBAC docs; Checkov CKV_AWS_* (Apache 2.0) | `g-iam-no-action-star`, `g-iam-no-resource-star`, `g-iam-no-notprincipal-with-allow`, `g-iam-no-wildcard-service-action`, `g-iam-condition-require-secure-transport`, `g-gcpiam-no-allusers`, `g-gcpiam-no-allauthenticatedusers`, `g-gcpiam-no-basic-roles`, `g-azurerbac-no-actions-star`, `g-azurerbac-no-assignablescope-root` |
| `sbom` | CycloneDX 1.6 raw schemas (Apache 2.0 + ECMA RF); SPDX 2.3 raw schemas (CC-BY-3.0) | `g-cdx-bomformat-literal`, `g-cdx-specversion-supported`, `g-cdx-components-purl-present`, `g-cdx-components-license-spdx`, `g-spdx-datalicense-cc0`, `g-spdx-documentnamespace-uri`, `g-spdx-creationinfo-creators-not-empty` |
| `sarif` | OASIS SARIF 2.1.0 schema (OASIS RF) | self-conformance rules so detector output validates: `g-sarif-version-literal`, `g-sarif-schema-iri-present`, `g-sarif-runs-tool-driver-name`, `g-sarif-results-have-ruleId`, `g-sarif-utf8-only`, `g-sarif-timestamps-iso8601-utc` |
| `jwt` | RFC 7519 (IETF public); **RFC 8725 JWT BCP (the highest-leverage P0 cluster in the whole corpus)**; RFC 7515/7516/7517 | `g-jwt-no-alg-none` (P0), `g-jwt-alg-allowlist` (P0), `g-jwt-no-key-confusion` (P0), `g-jwt-validate-iss` (P0), `g-jwt-validate-aud` (P0), `g-jwt-kid-sanitize`, `g-jwt-no-password-as-hmac-key`, `g-jwt-prefer-oaep-over-pkcs1v15`, `g-jwt-explicit-typ` |
| `md` (syntactic) | CommonMark 0.31.2 (CC-BY-SA-4.0); GitHub Flavored Markdown (CC-BY-SA-4.0); markdownlint MD001..MD060 (MIT) | `g-md-fenced-code-language-declared` (wraps MD040), `g-md-required-headings` (wraps MD043 — mechanically enforces ADR/arc42 shape), `g-md-no-duplicate-headings` (MD024), `g-md-single-h1` (MD025), `g-md-link-fragments-resolve` (MD051), `g-md-no-bare-urls` (MD034) |
| `arch` (semantic projection) | MADR 4.0 (MIT/CC0); Nygard ADR template (catalog MIT); arc42 (CC-BY-SA-4.0); C4 model (CC-BY-4.0); RFC 2119 + RFC 8174 (IETF public); Diátaxis (CC-BY-SA-4.0); standard-readme (MIT); Conventional Commits (CC-BY-3.0); Keep a Changelog (MIT); SemVer 2.0.0 (CC-BY-3.0); Contributor Covenant 2.1 (CC-BY-4.0); OWASP STRIDE (CC-BY-SA-4.0); LINDDUN | `g-arch-adr-template-shape`, `g-arch-rfc2119-defined`, `g-arch-c4-vocabulary-consistent`, `g-arch-diataxis-mode-pure`, `g-arch-stride-coverage`, `g-arch-y-statement-completeness`, `g-arch-conventional-commits`, `g-arch-keep-a-changelog-shape` |

The full per-context tables (with one-paragraph rule definitions, license per source, and detector-feasibility notes per rule) follow in §6.

### CTP-D-2. Extend the rule shape with `applies_to_prose: bool` (additive, default `false`).

Add an optional field to each rule entry in `active.json`:

```json
{
  "id": "g-aws-no-unrestricted-ingress",
  "source_namespace": "aws",
  "severity": "P0",
  "detector": "cloud-guidance-rule.sh",
  "applies_to_prose": true,
  "applies_to_prose_kinds": ["architecture", "adr"],
  "provenance": [{"author": "AWS", "url": "https://docs.aws.amazon.com/...", "retrieved": "2026-06-19", "license": "AWS proprietary — cite-link", "pin": "as-of-2026-06-19"}]
}
```

When `applies_to_prose: true`, the consuming harness (GCTP) will include the rule in the `applicable_rules` of any ticket whose `file_scope.may_edit` touches `**/*.md`, and the harness will invoke the rule via `prose-judge.sh` (CTP-D-3) instead of the rule's regular code-shape detector. The flag is content-agnostic: CTP can promote any rule to prose enforcement just by flipping the bit, with no consumer-side change.

Recommended initial settings at landing:
- **`true`** for every rule whose intent can be claimed in prose: IAM least-privilege, encryption-at-rest, no-unrestricted-ingress, provenance, no-known-exploited-ingress, OAS security schemes, JWT alg discipline, K8s privileged/host-network/root-fs, secret-handling, SBOM presence. Effectively every `g-aws-*` / `g-azure-*` / `g-gcp-*` / `g-iam-*` / `g-security-governance-*` / `g-slsa-*` / `g-owasp-*` / `g-jwt-*` / security-relevant `g-k8s-*` / security-relevant `g-oas-*` rule.
- **`false`** for rules that are mechanically syntactic (`g-yaml-no-tabs-indent`, `g-md-fenced-code-language-declared`, `g-json-utf8-only`, the TS strict-flag family).

Optional second field `applies_to_prose_kinds: string[]` (default `["architecture", "adr"]`) — restricts which MD-section `kind` (from frontmatter) is judged. Lets CTP exclude README/CHANGELOG/general docs from heavyweight semantic enforcement.

### CTP-D-3. New detector: `rubric/detectors/prose-judge.sh`.

A new entry under `rubric/detectors/prose-judge.sh` that the standards pipeline references as the `detector` for every `g-arch-*` rule AND for any rule promoted with `applies_to_prose: true`. Contract:

**Input flags** (compose with the existing §2.2 detector contract — `--json`, `--paths`, `--dry-run`, `--severity`, `--max-violations`, `CLAUDE_PLUGIN_ROOT`):

- `--rule <rule-id>` — the rule body to judge against (read live from `active.json`).
- `--paths <glob>` — defaults to `**/*.md` if absent.
- `--llm-judge` (or honor `LLM_JUDGE=1` env var) — opt-in semantic mode; absence ⇒ regex-only fallback returning `not_enforced` for any prose section that contains rule-keyword hits but cannot be judged.

**Pipeline:**

1. **Tokenize each `.md`** via `remark-parse` (Node, MIT) or a yq-on-AST equivalent that ships in the plugin cache. Output: ordered list of `{section_path, heading_level, prose_body, fenced_code_by_language, frontmatter}`. Sections inherit a `kind` from frontmatter (`kind: architecture | adr | readme | changelog | ...`); when no frontmatter is present, fall back to path-based heuristics (anything under `docs/architecture/**` or `docs/adr/**` is `architecture`/`adr`).
2. **For each (section, rule) pair** where the section's `kind` is in the rule's `applies_to_prose_kinds[]`, construct a judge prompt:
   ```
   You are evaluating whether a prose section of an architecture document
   proposes a design that would violate a specific software-engineering rule.

   RULE: {rule_id}
   RULE BODY: {rule_body_verbatim_from_active_json}

   PROSE SECTION:
   {section_prose_verbatim}

   Answer with one of: YES (the prose proposes a design that violates the rule),
   NO (the prose is compatible with the rule), or ABSTAIN (insufficient signal
   in the prose to determine compatibility). Reply with the single word followed
   by one sentence of rationale.
   ```
3. **Cache** by `sha256(rule_body_verbatim) ++ sha256(section_prose_verbatim)` in a plugin-local store (`.claude-tdd-pro/cache/prose-judge/`). Re-judge only on hash change.
4. **Aggregate:** file-level `red` if any (section, rule) → YES; `yellow` if all NO + ≥1 ABSTAIN on a P0 rule; `green` otherwise.

**Output:** SARIF 2.1.0 (CTP-D-5). Each YES becomes a SARIF `result` with `ruleId`, `level: error`, `locations[].physicalLocation` pointing at the offending heading line, `message.text` = the judge's one-sentence rationale, `properties.judge_model`, `properties.judge_confidence`, `properties.rule_body_sha`, `properties.section_sha`.

**Fallback:** when the model CLI is unavailable, `prose-judge.sh` returns `not_enforced` per rule (not `pass`). The consuming harness treats `not_enforced` as `red` (no silent green).

### CTP-D-4. New Layer-1 detector wrappers under `md` / `yaml` / `json` namespaces.

Each is a thin shell-out to a canonical FOSS tool, exit-code mapped + SARIF-translated. Apache/MIT/ISC tools preferred; GPL tools used only for their config/grammar (no GPL detector code into CTP-licensed sources):

| New detector | Wraps | License of tool | Maps to rule IDs |
|---|---|---|---|
| `md-syntax.sh` | markdownlint-cli2 | MIT | MD040 → `g-md-fenced-code-language-declared`; MD043 → `g-md-required-headings`; MD024 → `g-md-no-duplicate-headings`; MD025 → `g-md-single-h1`; etc. |
| `md-prose.sh` | Vale + errata-ai/Google + errata-ai/Microsoft + errata-ai/alex packages | MIT | `g-md-prose-google-style`, `g-md-prose-microsoft-style`, `g-md-inclusive-language` |
| `md-links.sh` | lychee | Apache 2.0 OR MIT | `g-md-links-resolve` |
| `md-spell.sh` | cspell + codespell | MIT + GPL (descriptions only) | `g-md-no-misspellings` |
| `md-license.sh` | `reuse lint` | wrapper-only | `g-md-license-header` (REUSE 3.3) |
| `mermaid.sh` | mmdc --validate | MIT | `g-md-mermaid-syntax-valid` |
| `yaml-syntax.sh` | yamllint | GPLv3 (config-only mirror; rule descriptions independently authored) | the `g-yaml-*` cluster |
| `yaml-iac.sh` | multiplexer for kube-linter / trivy config / checkov / conftest / spectral / promtool / ansible-lint / cfn-lint | Apache 2.0 (most) | dispatches to the right tool by detected file class |
| `json-schema.sh` | Ajv | MIT | dispatches against SchemaStore catalog (https://www.schemastore.org/json/) for any registered JSON shape |
| `json-iam.sh` | grep+regex tier; Checkov tier | Apache 2.0 | the `g-iam-*` cluster |
| `sbom-validate.sh` | cyclonedx-cli + spdx-tools | Apache 2.0 | the `g-cdx-*` and `g-spdx-*` clusters |
| `jwt-bcp.sh` | regex/grep on serialized JWTs + JWK Sets | n/a (own code) | the `g-jwt-*` cluster |

Per-CI-platform detectors (`gha-*.sh`, `glci-*.sh`, `azdo-*.sh`, `circleci-*.sh`, `bbp-*.sh`, `jenkins-*.sh`) reuse `yaml-iac.sh` for shape + add platform-specific regex passes for the security family.

### CTP-D-5. SARIF 2.1.0 as the universal detector output bus.

Every new detector (and, on a follow-up CL, every existing one — `no-any.sh`, `naked-throw.sh`, `cloud-guidance-rule.sh`, the boundary-schema family) emits **SARIF 2.1.0** conforming to the OASIS schema:

- Schema URL: https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json
- Root: `sarifLog` with `version: "2.1.0"`, `$schema`, `runs[]` each having `tool.driver.{name, version, rules[]}` and `results[]` with `ruleId`, `level` (`error`|`warning`|`note`|`none`), `locations[]`, `message.text`.
- The plugin caches the schema and validates each emission.
- For tools that emit SARIF natively (markdownlint-cli2, Vale, Spectral, Checkov, Trivy, lychee, cspell, cfn-lint, kube-linter), the wrapper passes the output through.
- For tools that don't (yamllint, mmdc), the wrapper translates exit code + stdout into a minimal SARIF result.

This earns interoperability with the wider security-tool ecosystem (GitHub code-scanning, Azure DevOps, Sonar, Snyk) for free.

### CTP-D-6. Refresh discipline covers the new sources.

`standards/initial-refresh.sh` (the begin-on-install + first-use-of-day mechanism per §28.23) enumerates the new corpora's raw-URL seeds. The full per-source list — with refreshability and license per row — is the §6 master table below. License posture is the gating filter:

- **Mirror permitted** (raw MD, pin by commit; or static HTML, cache verbatim): Apache 2.0, MIT, CC-BY-4.0, CC-BY-SA-4.0, MPL 2.0, BSD-2-Clause, BSD-3-Clause, ISC, IETF RFC public domain, OASIS RF, ECMA RF, US Government public domain.
- **Config / grammar mirror only with prominent attribution; detector code independently authored**: GPLv3 (yamllint, ansible-lint, codespell). Do NOT lift GPL detector source into CTP-licensed code.
- **Cite-link only — no body mirror**: CIS K8s Benchmark, AWS docs, Microsoft Learn (Azure Pipelines, Azure RBAC), Snyk, CircleCI docs, Atlassian Bitbucket docs, the Norway-problem blog posts, ISO/IEC/IEEE 42010 (paywalled). Reference these by URL in the rule body's `provenance[]` only.

Two-tier cadence is recommended (the consuming harness honors whatever cadence CTP declares):
- **Daily** for raw-MD pin-by-commit seeds (Apache/MIT/CC-licensed GitHub repos).
- **Weekly** for HTML-scrape seeds (docs.aws.amazon.com, learn.microsoft.com, etc.) since they shift less and the scrape is more expensive.

### CTP-D-7. Bump `active.json` `schema_version`.

The introduction of `applies_to_prose` is an additive field with a safe default (`false`). Bump `active.json`'s `schema_version` from current → next so the consuming harness can branch on capability cleanly. The harness's handoff contract (the shape of `applicable_rules` in tickets) does NOT change — it continues to consume rule IDs as opaque strings.

---

## 5. Alternatives considered (record in the ADR)

- **Author a single mega-detector that handles all 22 new namespaces.** REJECTED — violates §2.2's per-rule detector contract; makes failure attribution opaque; precludes per-rule SARIF; breaks the existing enforce.sh loop.
- **Bundle prose-judge as an internal feature flag rather than a flag on the rule shape.** REJECTED — that hides the opt-in from the rule registry, and the consuming harness's static gates cannot then enforce the prose floor. The flag belongs in the rule body so the channel is transparent.
- **Default `applies_to_prose: true` for every rule.** REJECTED for v1 — too aggressive a default; many syntactic rules have no meaningful prose analog and would generate ABSTAIN noise. Defaulted `false`; promote per rule.
- **Skip SARIF; define a CTP-native finding format.** REJECTED — fragments the ecosystem for no benefit. SARIF is OASIS-standard; every linter in the corpora emits it.
- **Make `prose-judge.sh` eager (run on every MD, every session).** REJECTED — unbounded token cost. Cache by `(rule_body_hash, prose_section_hash)` + opt-in only via `CLAUDE_TDD_PRO_PROSE_JUDGE_EAGER=1`.
- **Reach across the contract boundary into the consuming harness.** REJECTED — the consuming harness consumes CTP as a pinned plugin; CTP must not know about its consumers. Only the contract surface (`active.json` + `rubric/detectors/`) moves.

---

## 6. Source master tables (mirror this verbatim into the CTP `docs/standards-source-manifest.md`)

These are the full source bundles the rule corpora are seeded from. Each table is the input to `standards/initial-refresh.sh` and `provenance[]` registry.

### 6.1 YAML corpus — 75 sources

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| YAML 1.2.2 spec | YAML Language Dev Team | https://yaml.org/spec/1.2.2/ | HTML (stable) | Permissive — citable with attribution |
| YAML spec (raw MD) | yaml/yaml-spec | https://raw.githubusercontent.com/yaml/yaml-spec/main/spec/1.2.2/spec.md | RAW MD, pin by commit | MIT-style (per repo LICENSE) |
| yamllint default config | adrienverge/yamllint | https://raw.githubusercontent.com/adrienverge/yamllint/master/yamllint/conf/default.yaml | RAW YAML | GPLv3 (config-only mirror) |
| yamllint rules reference | yamllint | https://yamllint.readthedocs.io/en/stable/rules.html | HTML (Sphinx) | GPLv3 docs |
| K8s Pod Security Standards | kubernetes.io | https://kubernetes.io/docs/concepts/security/pod-security-standards/ | HTML (Hugo); source github.com/kubernetes/website | CC-BY 4.0 |
| K8s Configuration Best Practices | kubernetes.io | https://kubernetes.io/docs/concepts/configuration/overview/ | HTML | CC-BY 4.0 |
| K8s Security Context | kubernetes.io | https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ | HTML | CC-BY 4.0 |
| K8s RBAC | kubernetes.io | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ | HTML | CC-BY 4.0 |
| K8s Secrets | kubernetes.io | https://kubernetes.io/docs/concepts/configuration/secret/ | HTML | CC-BY 4.0 |
| CIS Kubernetes Benchmark | CIS | https://www.cisecurity.org/benchmark/kubernetes | PDF gated | CIS EULA — cite-link only |
| kube-linter checks | stackrox/kube-linter | https://raw.githubusercontent.com/stackrox/kube-linter/main/docs/generated/checks.md | RAW MD, pin by commit | Apache 2.0 |
| kube-linter templates | stackrox/kube-linter | https://raw.githubusercontent.com/stackrox/kube-linter/main/docs/generated/templates.md | RAW MD | Apache 2.0 |
| Polaris checks | FairwindsOps/polaris | https://github.com/FairwindsOps/polaris/tree/master/checks | RAW JSON-schema, pin by commit | Apache 2.0 |
| Polaris docs | polaris.docs.fairwinds.com | https://polaris.docs.fairwinds.com/checks/ | HTML (Docusaurus) | Apache 2.0 |
| kubeconform | yannh/kubeconform | https://github.com/yannh/kubeconform | RAW (README + schemas) | Apache 2.0 |
| Kubernetes JSON Schemas | yannh/kubernetes-json-schema | https://github.com/yannh/kubernetes-json-schema | RAW JSON schemas | Apache 2.0 |
| Kubescape regolibrary controls | kubescape/regolibrary | https://raw.githubusercontent.com/kubescape/regolibrary/master/controls/ | RAW JSON+Rego | Apache 2.0 |
| Kubescape frameworks (NSA/CIS/MITRE/SSDF mappings) | kubescape/regolibrary | https://github.com/kubescape/regolibrary/tree/master/frameworks | RAW JSON | Apache 2.0 |
| Helm chart best practices | helm.sh | https://helm.sh/docs/chart_best_practices/ | HTML (Hugo); source github.com/helm/helm-www | Apache 2.0 |
| Helm values best practices | helm.sh | https://helm.sh/docs/chart_best_practices/values/ | HTML | Apache 2.0 |
| Helm values.schema.json guide | helm.sh | https://helm.sh/docs/topics/charts/#schema-files | HTML | Apache 2.0 |
| Docker Compose spec | compose-spec/compose-spec | https://raw.githubusercontent.com/compose-spec/compose-spec/main/spec.md | RAW MD | Apache 2.0 |
| Compose file reference | docs.docker.com | https://docs.docker.com/reference/compose-file/ | HTML | Apache 2.0 docs |
| GitHub Actions workflow syntax | docs.github.com | https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions | HTML; source github.com/github/docs | CC-BY 4.0 |
| GHA security hardening | docs.github.com | https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions | HTML | CC-BY 4.0 |
| GHA secure-use reference | docs.github.com | https://docs.github.com/en/actions/reference/security/secure-use | HTML | CC-BY 4.0 |
| GHA OIDC w/ AWS | docs.github.com | https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services | HTML | CC-BY 4.0 |
| GHA concurrency | docs.github.com | https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency | HTML | CC-BY 4.0 |
| GitLab CI YAML reference | docs.gitlab.com | https://docs.gitlab.com/ci/yaml/ | HTML | CC-BY-SA 4.0 |
| GitLab CI job rules | docs.gitlab.com | https://docs.gitlab.com/ci/jobs/job_rules/ | HTML | CC-BY-SA 4.0 |
| Azure Pipelines YAML schema | learn.microsoft.com | https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/ | HTML (server-rendered) | MS proprietary — cite-link |
| Azure Pipelines templates-for-security | learn.microsoft.com | https://learn.microsoft.com/en-us/azure/devops/pipelines/security/templates | HTML | MS proprietary |
| CircleCI config reference | circleci.com | https://circleci.com/docs/configuration-reference/ | HTML; source github.com/circleci/circleci-docs (Apache 2.0) | docs Apache 2.0 |
| Bitbucket Pipelines config ref | atlassian.com | https://support.atlassian.com/bitbucket-cloud/docs/bitbucket-pipelines-configuration-reference/ | HTML | Atlassian copyright — cite-link |
| Jenkins Pipeline-as-YAML | jenkins.io | https://plugins.jenkins.io/pipeline-as-yaml/ | HTML | MIT (plugin) |
| ansible-lint rules | docs.ansible.com | https://docs.ansible.com/projects/lint/rules/ | HTML (Sphinx) | GPLv3 + CC-BY |
| ansible-lint repo rules | ansible/ansible-lint | https://github.com/ansible/ansible-lint/tree/main/src/ansiblelint/rules | RAW Python+MD | GPLv3 |
| Ansible best practices | docs.ansible.com | https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html | HTML | GPLv3 + CC-BY |
| CloudFormation best practices | docs.aws.amazon.com | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html | HTML | AWS proprietary — cite-link |
| CFN template anatomy | docs.aws.amazon.com | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html | HTML | AWS proprietary |
| OpenAPI 3.1 spec | OAI/OpenAPI-Specification | https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.1.0.md | RAW MD | Apache 2.0 |
| OpenAPI 3.0.4 spec | OAI | https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.0.4.md | RAW MD | Apache 2.0 |
| Argo CD sync waves | argo-cd.readthedocs.io | https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ | HTML (Sphinx); source github.com/argoproj/argo-cd/tree/master/docs/user-guide | Apache 2.0 |
| Argo CD sync options | argo-cd.readthedocs.io | https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/ | HTML | Apache 2.0 |
| Flux Kustomize API v1 | fluxcd.io | https://fluxcd.io/flux/components/kustomize/api/v1/ | HTML (Hugo); source github.com/fluxcd/website | Apache 2.0 |
| Flux Kustomization spec | fluxcd.io | https://fluxcd.io/flux/components/kustomize/kustomizations/ | HTML | Apache 2.0 |
| Kustomize patches docs | kubernetes.io | https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/ | HTML | CC-BY 4.0 |
| Sealed Secrets | bitnami-labs/sealed-secrets | https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/main/README.md | RAW MD | Apache 2.0 |
| SOPS | getsops/sops | https://raw.githubusercontent.com/getsops/sops/main/README.rst | RAW rST | MPL 2.0 |
| Prometheus config | prometheus.io | https://prometheus.io/docs/prometheus/latest/configuration/configuration/ | HTML (Hugo); source github.com/prometheus/docs | Apache 2.0 + docs CC-BY-4.0 |
| Prometheus alerting rules | prometheus.io | https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/ | HTML | Apache 2.0 |
| OTel Collector configuration | open-telemetry/opentelemetry.io | https://raw.githubusercontent.com/open-telemetry/opentelemetry.io/main/content/en/docs/collector/configuration.md | RAW MD | CC-BY 4.0 |
| Istio VirtualService | istio.io | https://istio.io/latest/docs/reference/config/networking/virtual-service/ | HTML (Hugo); source github.com/istio/istio.io | Apache 2.0 |
| Istio DestinationRule | istio.io | https://istio.io/latest/docs/reference/config/networking/destination-rule/ | HTML | Apache 2.0 |
| Envoy config reference | envoyproxy.io | https://www.envoyproxy.io/docs/envoy/latest/configuration/configuration | HTML (Sphinx) | Apache 2.0 |
| Kong declarative config | docs.konghq.com | https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/ | HTML | Apache 2.0 docs |
| OWASP CI/CD Top 10 | OWASP | https://github.com/OWASP/www-project-top-10-ci-cd-security-risks | RAW MD + HTML | CC-BY-SA 4.0 |
| OWASP CI/CD Cheat Sheet | OWASP/CheatSheetSeries | https://raw.githubusercontent.com/OWASP/CheatSheetSeries/master/cheatsheets/CI_CD_Security_Cheat_Sheet.md | RAW MD | CC-BY-SA 4.0 |
| OWASP API Security Top 10 (2023) | OWASP/API-Security | https://github.com/OWASP/API-Security | RAW MD | CC-BY-SA 4.0 |
| OpenSSF Scorecard checks | ossf/scorecard | https://raw.githubusercontent.com/ossf/scorecard/main/docs/checks.md | RAW MD | Apache 2.0 |
| SLSA v1.0 requirements | slsa.dev | https://slsa.dev/spec/v1.0/requirements | HTML (Hugo) | CC-BY 4.0 |
| SLSA security levels | slsa.dev | https://slsa.dev/spec/v1.0/levels | HTML | CC-BY 4.0 |
| NIST SP 800-218 SSDF v1.1 | NIST | https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf | PDF | US Gov public domain |
| Checkov policy index — all | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/all.md | RAW MD | Apache 2.0 |
| Checkov K8s policies | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/kubernetes.md | RAW MD | Apache 2.0 |
| Checkov GitHub Actions policies | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/github_actions.md | RAW MD | Apache 2.0 |
| Trivy checks bundle | aquasecurity/trivy-checks | https://github.com/aquasecurity/trivy-checks | RAW Rego + MD | Apache 2.0 |
| Trivy misconfig docs | trivy.dev | https://trivy.dev/latest/docs/scanner/misconfiguration/ | HTML (MkDocs) | Apache 2.0 |
| conftest | open-policy-agent/conftest | https://raw.githubusercontent.com/open-policy-agent/conftest/master/README.md | RAW MD | Apache 2.0 |
| Snyk K8s IaC rules | snyk.io | https://snyk.io/security-rules/kubernetes/deployment | HTML (Next.js partial-SPA) | Snyk copyright — cite-link |
| OpenGitOps principles | open-gitops/documents | https://raw.githubusercontent.com/open-gitops/documents/main/PRINCIPLES.md | RAW MD | Apache 2.0 |
| Google styleguide repo | google/styleguide | https://github.com/google/styleguide | RAW + GH Pages | Apache 2.0 |
| OpenShift security hardening | docs.openshift.com | https://docs.openshift.com/container-platform/latest/security/container_security/security-hardening.html | HTML | Red Hat docs CC-BY-SA |

(Plus ~5 secondary references — bram.us Norway-problem article, InfoWorld YAML gotchas — citation-only.)

### 6.2 JSON corpus — 40+ sources

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| RFC 8259 (JSON spec) | IETF | https://datatracker.ietf.org/doc/html/rfc8259 + https://www.rfc-editor.org/rfc/rfc8259.txt | HTML / TXT (stable) | IETF Trust (public) |
| ECMA-404 (2nd ed) | ECMA International | https://ecma-international.org/wp-content/uploads/ECMA-404_2nd_edition_december_2017.pdf | PDF (stable) | ECMA RF |
| RFC 7493 (I-JSON) | IETF | https://datatracker.ietf.org/doc/html/rfc7493 | HTML / TXT | IETF Trust |
| JSON Schema 2020-12 | json-schema.org | https://json-schema.org/draft/2020-12/release-notes | HTML | BSD-2-Clause (per repo) |
| JSON Schema Draft 7 meta-schema | json-schema.org | http://json-schema.org/draft-07/schema# | JSON (stable) | BSD-2-Clause |
| Ajv (JSON Schema validator, JS) | ajv-validator/ajv | https://github.com/ajv-validator/ajv | git / raw | MIT |
| python-jsonschema | python-jsonschema/jsonschema | https://github.com/python-jsonschema/jsonschema | git / raw | MIT |
| OpenAPI 3.1 spec | OAI | https://spec.openapis.org/oas/v3.1.0.html + raw at https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.1.0.md | HTML / RAW MD | Apache 2.0 |
| JSON-LD 1.1 | W3C | https://www.w3.org/TR/json-ld11/ | HTML | W3C Document License |
| JSON:API 1.1 | jsonapi.org | https://jsonapi.org/format/ | HTML | CC0 |
| JSON-RPC 2.0 | JSON-RPC WG | https://www.jsonrpc.org/specification | HTML | Perpetual implementation grant |
| RFC 7519 (JWT) | IETF | https://datatracker.ietf.org/doc/html/rfc7519 | HTML / TXT | IETF Trust |
| RFC 7515 (JWS) | IETF | https://datatracker.ietf.org/doc/html/rfc7515 | HTML / TXT | IETF Trust |
| RFC 7516 (JWE) | IETF | https://datatracker.ietf.org/doc/html/rfc7516 | HTML / TXT | IETF Trust |
| RFC 7517 (JWK) | IETF | https://datatracker.ietf.org/doc/html/rfc7517 | HTML / TXT | IETF Trust |
| **RFC 8725 (JWT BCP)** | IETF | https://datatracker.ietf.org/doc/html/rfc8725 | HTML / TXT | IETF Trust |
| package.json reference | npm | https://docs.npmjs.com/cli/v10/configuring-npm/package-json | HTML | proprietary (de-facto spec) |
| package-lock.json reference | npm | https://docs.npmjs.com/cli/v10/configuring-npm/package-lock-json | HTML | proprietary |
| composer.lock | Composer | https://getcomposer.org/doc/01-basic-usage.md | RAW MD | MIT |
| Pipfile.lock | PyPA / Pipenv | https://pipenv.pypa.io/en/latest/pipfile.html | HTML | MIT |
| tsconfig.json | Microsoft (TypeScript) | https://www.typescriptlang.org/tsconfig | HTML | Apache 2.0 project / proprietary docs |
| VS Code settings/launch/tasks | Microsoft | https://code.visualstudio.com/docs/configure/settings | HTML | proprietary docs |
| AWS IAM Policy grammar | AWS | https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_grammar.html | HTML | proprietary — cite-link |
| AWS IAM best practices | AWS | https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html | HTML | proprietary |
| GCP IAM allow-policy | Google Cloud | https://cloud.google.com/iam/docs/policies | HTML | proprietary |
| Azure RBAC role definitions | Microsoft | https://learn.microsoft.com/en-us/azure/role-based-access-control/role-definitions | HTML; source MicrosoftDocs/azure-docs-pr | CC-BY 4.0 (docs) |
| Azure Policy definition structure | Microsoft | https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-basics | HTML | CC-BY 4.0 |
| Kubernetes JSON manifests | Kubernetes | https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/ | HTML | CC-BY 4.0 |
| Helm values.schema.json | Helm | https://helm.sh/docs/topics/charts/#schema-files | HTML | Apache 2.0 |
| devcontainer.json | containers.dev (Microsoft + community) | https://containers.dev/implementors/json_reference/ + https://github.com/devcontainers/spec/blob/main/schemas/devContainer.base.schema.json | HTML / RAW | MIT |
| Renovate config | Mend/Renovate | https://docs.renovatebot.com/configuration-options/ + https://docs.renovatebot.com/renovate-schema.json | HTML / RAW JSON | AGPL-3.0 (project) |
| CloudFormation JSON template | AWS | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html | HTML | proprietary |
| Terraform JSON syntax | HashiCorp | https://developer.hashicorp.com/terraform/language/syntax/json | HTML | MPL 2.0 project |
| Pulumi state | Pulumi | https://www.pulumi.com/docs/iac/concepts/state-and-backends/ | HTML | Apache 2.0 |
| OPA bundle manifest | OPA | https://www.openpolicyagent.org/docs/management-bundles#bundle-file-format | HTML | Apache 2.0 |
| **CycloneDX SBOM JSON** | OWASP / ECMA TC54 | https://cyclonedx.org/specification/overview/ + https://github.com/CycloneDX/specification/tree/master/schema | HTML / RAW JSON | Apache 2.0 + ECMA RF |
| **SPDX JSON 2.3** | Linux Foundation / SPDX | https://spdx.github.io/spdx-spec/v2.3/ + https://github.com/spdx/spdx-spec/blob/support/2.3.1/schemas/spdx-schema.json | HTML / RAW JSON | CC-BY-3.0 |
| **SARIF 2.1.0** | OASIS | https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html + https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json | HTML / RAW JSON | OASIS RF |
| OTel JSON (OTLP file) | OpenTelemetry | https://opentelemetry.io/docs/specs/otlp/ | HTML | Apache 2.0 |
| CloudEvents JSON 1.0.2 | CNCF | https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/formats/json-format.md | RAW MD | Apache 2.0 |
| Schema.org JSON-LD context | Schema.org | https://schema.org/docs/jsonldcontext.json | RAW JSON | CC-BY-SA 3.0 |
| Elastic Common Schema (ECS) | Elastic | https://www.elastic.co/docs/reference/ecs | HTML | Apache 2.0 |
| Spectral (OAS linter) | Stoplight | https://github.com/stoplightio/spectral | git / raw | Apache 2.0 |
| cfn-lint | AWS | https://github.com/aws-cloudformation/cfn-lint | git / raw | Apache 2.0 |
| **SchemaStore — meta-catalog of 700+ JSON Schemas** | SchemaStore.org | https://www.schemastore.org/json/ + https://github.com/SchemaStore/schemastore | git / raw | Apache 2.0 |

### 6.3 MD corpus — 40 sources, two layers

**Layer 1 — syntactic:**

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| CommonMark 0.31.2 | John MacFarlane | https://spec.commonmark.org/0.31.2/ + repo raw `spec.txt` | HTML / RAW | CC-BY-SA 4.0 |
| GitHub Flavored Markdown | GitHub | https://github.github.com/gfm/ | HTML | CC-BY-SA 4.0 |
| markdownlint rules MD001..MD060 | David Anson | https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md | RAW MD | MIT |
| remark-lint | unified collective | https://github.com/remarkjs/remark-lint | RAW MD | MIT |
| Vale | jdkato | https://vale.sh + repo | RAW + HTML | MIT |
| Vale styles (Google / Microsoft / write-good / alex / proselint) | errata-ai | https://github.com/errata-ai | RAW YAML | mixed per package |
| alex (inclusive language) | get-alex/alex | https://github.com/get-alex/alex | RAW | MIT |
| write-good | btford/write-good | https://github.com/btford/write-good | RAW | MIT |
| proselint | amperser/proselint | https://github.com/amperser/proselint | RAW | BSD-3-Clause |
| textlint | textlint | https://github.com/textlint/textlint | RAW | MIT |
| retext (equality, profanities, simplify, passive) | retextjs | https://github.com/retextjs | RAW | MIT |
| markdown-link-check | tcort | https://github.com/tcort/markdown-link-check | RAW | ISC |
| lychee link checker | lycheeverse | https://github.com/lycheeverse/lychee | RAW | Apache-2.0 OR MIT |
| Hugo front matter | Hugo | https://gohugo.io/content-management/front-matter/ | HTML | Apache-2.0 (docs) |
| Jekyll front matter | Jekyll | https://jekyllrb.com/docs/front-matter/ | HTML | MIT |
| Docusaurus markdown features | Meta | https://docusaurus.io/docs/markdown-features | HTML | MIT |
| Mermaid spec | mermaid-js | https://mermaid.js.org/intro/ | HTML + RAW | MIT |
| PlantUML | PlantUML | https://plantuml.com/ | HTML | GPL engine / docs CC |
| REUSE 3.3 spec (SPDX headers) | FSFE | https://reuse.software/spec-3.3/ | HTML | CC-BY-SA 4.0 |
| cspell | streetsidesoftware | https://github.com/streetsidesoftware/cspell | RAW | MIT |
| codespell | codespell-project | https://github.com/codespell-project/codespell | RAW | GPL-2.0 (dicts CC-BY-SA-3.0) |

**Layer 2 — semantic / prose-as-code:**

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| RFC 2119 (keyword authority) | IETF | https://www.rfc-editor.org/rfc/rfc2119 | HTML / TXT | IETF Trust |
| RFC 8174 (case-sensitivity clarification) | IETF | https://www.rfc-editor.org/rfc/rfc8174 | HTML / TXT | IETF Trust |
| MADR 4.0 ADR template | adr/madr | https://adr.github.io/madr/ + repo raw | HTML / RAW | MIT OR CC0-1.0 |
| ADR template catalog (Nygard / Y-Statements / Planguage / Alexandrian) | joelparkerhenderson | https://github.com/joelparkerhenderson/architecture-decision-record | RAW | MIT |
| Y-Statements | Olaf Zimmermann | https://medium.com/olzzio/y-statements-10eb07b5a177 (mirror in catalog above) | HTML | CC-BY (article) |
| arc42 (12-section template) | Hruschka + Starke | https://arc42.org/overview + GitHub templates | HTML / RAW | CC-BY-SA 4.0 |
| C4 model | Simon Brown | https://c4model.com/ | HTML | CC-BY 4.0 |
| ISO/IEC/IEEE 42010:2022 | ISO | https://www.iso.org/standard/74393.html | PAYWALL | proprietary — use arc42 + C4 surrogates |
| Diátaxis framework | Daniele Procida | https://diataxis.fr/ | HTML | CC-BY-SA 4.0 |
| Write the Docs guide | community | https://www.writethedocs.org/guide/ | HTML | CC-BY 4.0 |
| Google developer docs style guide | Google | https://developers.google.com/style | HTML | CC-BY 4.0 |
| Microsoft Writing Style Guide | Microsoft | https://learn.microsoft.com/en-us/style-guide/welcome/ + MicrosoftDocs/microsoft-style-guide-pr | HTML / RAW | proprietary but linkable |
| standard-readme spec | Richard Littauer | https://github.com/RichardLitt/standard-readme | RAW | MIT |
| Make a README | Danny Guo | https://www.makeareadme.com/ | HTML | MIT |
| GitHub open-source-guide | GitHub | https://opensource.guide/ + github/opensource.guide | HTML / RAW | CC-BY 4.0 |
| Conventional Commits 1.0.0 | OpenJS | https://www.conventionalcommits.org/en/v1.0.0/ | HTML | CC-BY 3.0 |
| Keep a Changelog 1.1.0 | Olivier Lacan | https://keepachangelog.com/en/1.1.0/ | HTML | MIT |
| SemVer 2.0.0 | Tom Preston-Werner | https://semver.org/spec/v2.0.0.html | HTML | CC-BY 3.0 |
| Contributor Covenant 2.1 | Org. for Ethical Source | https://www.contributor-covenant.org/version/2/1/code_of_conduct/ | HTML + RAW | CC-BY 4.0 |
| OWASP STRIDE (threat modeling) | OWASP | https://owasp.org/www-community/Threat_Modeling_Process | HTML | CC-BY-SA 4.0 |
| LINDDUN (privacy threat modeling) | KU Leuven DistriNet | https://www.linddun.org/ | HTML | CC-BY (educational) |
| GitHub Advisory Database (OSV) | GitHub | https://github.com/github/advisory-database | RAW | CC-BY 4.0 |

---

## 7. Verification (acceptance criteria for each landing wave)

The consuming harness (GCTP) re-runs an audit against an app tree of ~77 files, of which 46 are currently unenforced (33 `.md`, 11 `.json`, 2 `.gitignore`). The bar is: **after each wave lands and a pin bump is adopted, the unenforced-file count drops monotonically toward zero.**

- **Wave 1** — `yaml` + `k8s` + `md` (Layer 1 only) + `arch` (template-shape rules only, no LLM-judge yet):
  - Unit tests for each new detector wrapper (input YAML/MD → expected SARIF).
  - Acceptance: MD coverage flips from 0% → ≥ 90% of `.md` files reached by at least one detector. YAML coverage deepens; the k8s manifest fires more than the current single-rule pair.
  - The `arch` template-shape rules (MADR / arc42 / RFC 2119 keyword discipline / Conventional Commits / Keep a Changelog / SemVer) all run as regex/`markdownlint MD043` — no LLM cost.
- **Wave 2** — `json` + `jwt` + `iam` + `sbom` + `sarif`:
  - Positive tests: `"alg": "none"` red against `g-jwt-no-alg-none`; `"Action": "*"` red against `g-iam-no-action-star`; missing `bomFormat` red against `g-cdx-bomformat-literal`.
  - Negative tests: `"alg": "RS256"` green; scoped action green; valid CycloneDX 1.6 BOM green.
  - SchemaStore catalog wired into `json-schema.sh`; tsconfig + package.json + Renovate + devcontainer.json all validate.
- **Wave 3** — CI/CD/IaC family (`gha`, `glci`, `azdo`, `circleci`, `bbp`, `jenkins`, `ansible`, `cfn`, `oas`, `gitops`, `observability`, `mesh`, `iac-linter`) + `prose-judge.sh` semantic engine:
  - Unit tests for each shell-out wrapper.
  - Semantic test: flip `g-aws-no-unrestricted-ingress.applies_to_prose: true`, feed `prose-judge.sh` an ADR snippet that says *"we'll allow 0.0.0.0/0 ingress on dev"* — expect YES verdict + SARIF result.
  - Caching test: re-run with no prose change — expect cache hit; mutate one character of prose — expect re-judge.
- **Standards-refresh** — run `standards/initial-refresh.sh` in dry-run mode against the full §6 source list. Every new rule body in `active.json` carries `provenance[]` per §28.23. Cite-link-only sources MUST NOT be mirrored.
- **License audit** — manual review confirms GPL sources (yamllint, ansible-lint, codespell) ship as config-only mirrors with prominent attribution; no GPL code enters CTP-licensed detector code.

---

## 8. Boundary discipline — what CTP owns vs. what the consumer owns

**CTP owns** (this brief):
- Rule content in `standards/<ns>/` and `generated-code-quality-standards/<ns>/`.
- Detector scripts in `rubric/detectors/`.
- The `active.json` schema (including the new `applies_to_prose` flag).
- `standards/initial-refresh.sh` source enumeration.
- The SARIF emission contract for detectors.
- The `prose-judge.sh` LLM-judge engine including its cache.
- License attribution per source.
- The `SKILL.md` trio updates that mention the new namespaces + prose-as-code surface.

**Consumer (the harness) owns** (NOT this brief — happens elsewhere):
- How rules are scoped per ticket (the consumer reads `applies_to_prose` from `active.json` and wires the right MD floor).
- SARIF aggregation across rules into per-CL logs.
- Two-phase enforcement timing (design-phase before dispatch; code-phase before merge).
- Deviation discipline (operator records a row when a rule legitimately can't apply to a single-cloud project).
- Refresh-cadence scheduling (consumer-side: when to call `standards/initial-refresh.sh`).

**Neither side touches the other's repo.** When the consumer needs a behavior CTP doesn't expose, the path is a proposal back to CTP — never an in-place edit.

---

## 9. Suggested landing waves

Land in three waves, each a pin bump on its own. Each wave is independently useful:

| Wave | Scope | Estimated rule count added | What unlocks |
|---|---|---:|---|
| **1** | `yaml` + `k8s` + `md` (Layer 1) + `arch` (template-shape only) | ~50 | Closes the MD enforcement dead zone for syntactic + ADR-shape rules. The architecture decision log and all ADRs become first-class targets. No new LLM cost. |
| **2** | `json` + `jwt` + `iam` + `sbom` + `sarif` | ~60 | High-leverage P0 cluster (JWT BCP + IAM wildcards) lands. SchemaStore catalog wired in. SARIF self-conformance verifies the harness's own output. |
| **3** | All CI/CD/IaC namespaces (`gha`, `glci`, `azdo`, `circleci`, `bbp`, `jenkins`, `ansible`, `cfn`, `oas`, `gitops`, `observability`, `mesh`, `iac-linter`) + `prose-judge.sh` LLM-judge engine | ~100+ | Full corpus. Prose-as-code principle activated. The same `g-aws-*` rule that fires on Terraform now also fires on ADR prose. |

Each wave: ADR + tests + standards-refresh entry + a `SKILL.md` note. The harness adopts each wave via its own pin-bump ADR (consumer-side concern).

---

## 10. File structure inside the CTP repo (proposed)

```
claude-tdd-pro/
├── docs/
│   ├── adr/
│   │   └── 000N-yaml-json-md-corpora-and-prose-judge.md   ← this work's ADR
│   └── standards-source-manifest.md                         ← §6 tables lifted verbatim
├── standards/
│   ├── yaml/<rule-id>.md
│   ├── k8s/<rule-id>.md
│   ├── helm/<rule-id>.md
│   ├── compose/<rule-id>.md
│   ├── gha/<rule-id>.md
│   ├── glci/<rule-id>.md
│   ├── azdo/<rule-id>.md
│   ├── circleci/<rule-id>.md
│   ├── bbp/<rule-id>.md
│   ├── jenkins/<rule-id>.md
│   ├── ansible/<rule-id>.md
│   ├── cfn/<rule-id>.md
│   ├── oas/<rule-id>.md
│   ├── gitops/<rule-id>.md
│   ├── observability/<rule-id>.md
│   ├── mesh/<rule-id>.md
│   ├── iac-linter/<rule-id>.md
│   ├── json/<rule-id>.md
│   ├── jsonschema/<rule-id>.md
│   ├── iam/<rule-id>.md
│   ├── sbom/<rule-id>.md
│   ├── sarif/<rule-id>.md
│   ├── jwt/<rule-id>.md
│   ├── md/<rule-id>.md
│   ├── arch/<rule-id>.md
│   └── initial-refresh.sh                                   ← extend source enumeration
├── generated-code-quality-standards/<ns>/...                ← materialized rule bodies
├── rubric/
│   └── detectors/
│       ├── prose-judge.sh                                   ← NEW: LLM-judge engine
│       ├── md-syntax.sh                                     ← NEW: markdownlint-cli2 wrapper
│       ├── md-prose.sh                                      ← NEW: Vale wrapper
│       ├── md-links.sh                                      ← NEW: lychee wrapper
│       ├── md-spell.sh                                      ← NEW: cspell + codespell
│       ├── md-license.sh                                    ← NEW: reuse lint wrapper
│       ├── mermaid.sh                                       ← NEW: mmdc --validate
│       ├── yaml-syntax.sh                                   ← NEW: yamllint wrapper
│       ├── yaml-iac.sh                                      ← NEW: multiplexer
│       ├── json-schema.sh                                   ← NEW: Ajv + SchemaStore
│       ├── json-iam.sh                                      ← NEW: IAM wildcard scan
│       ├── sbom-validate.sh                                 ← NEW: cyclonedx + spdx
│       ├── jwt-bcp.sh                                       ← NEW: RFC 8725 rules
│       ├── gha-security.sh, glci-security.sh, ...           ← per-platform CI
│       └── (existing detectors update to emit SARIF)
└── (existing) SKILL.md trio — note the new namespaces + prose-as-code surface
```

---

## 11. The single most important takeaway

Of everything in this brief, the architecturally novel piece is **CTP-D-2 (`applies_to_prose` flag) + CTP-D-3 (`prose-judge.sh`)**. That is the mechanism by which an ADR proposing a design that would violate any rule in `active.json` red-flags **before** the implementing code is written. It generalizes the existing `LLM_JUDGE=1` pattern in `no-any.sh` / `naked-throw.sh` into a first-class detector that takes any rule body and any prose section and returns a verdict. Once it ships, the harness can enforce the operator's prose-as-code principle by construction — same rule, same gate, two surfaces.

Everything else (the 22 new namespaces, the Layer 1 wrappers, SARIF, refresh) is rule-content density. Important — but CTP already knows how to author rule content. The semantic-projection detector is the new substrate.

---

End of brief. Land as an ADR in `claude-tdd-pro/docs/adr/`, decompose into the three waves, ship.
