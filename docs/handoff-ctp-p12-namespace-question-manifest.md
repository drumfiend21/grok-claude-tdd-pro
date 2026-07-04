# P-12 supplementary — namespace × question × source manifest

**Written:** 2026-07-04 · **Companion to:** `docs/handoff-ctp-p12-full-surface-intake.md`

**Purpose.** Concrete build spec for `standards/business-intake-question-bank.yaml`. One row per proposed intake question, with activation predicate, key, type, allowed enum, prompt, and the `source_id` it grounds in. **Every `source_id` marked ✓ EXISTS in CTP catalogs at pin `0cf28fe`** (verified by grep against `standards/*.yaml`); ones marked ⊕ NEW need to be added to a catalog before this manifest can ship. Ground truth: `active.json` at pin `0cf28fe` = **118 rules across 42 namespaces** (the 43rd grounding group is `cloud-conventions`, an IaC-convention set outside `active.json`).

**Correction to the main handoff.** The handoff says "43 namespaces" throughout; ground truth is 42 active.json namespaces + 1 cloud-conventions grouping. CTP can standardize on either phrasing; treat both counts as equivalent in intent.

---

## 1. Universal probes (Stage 1) — unchanged from v1.13

The existing 9 questions in `commands/business-intake.sh`. Always active. Byte-identical to v1.13 for the backward-compat regression baseline. Rendered here only for reference — CTP does not need to modify these.

| Key | Type | Allowed | Source (existing) |
|---|---|---|---|
| `workload` | free | — | `azure-waf-business-requirements` ✓ |
| `motivation` | enum | revenue / compliance / cost-reduction / risk-reduction / innovation | `azure-waf-business-requirements` ✓ |
| `criticality` | enum | mission-critical / important / experimental | `aws-rpo-rto-targets` ✓ |
| `availability_tolerance` | enum | none / minutes / hours / days | `aws-rpo-rto-targets` ✓ |
| `data_loss_tolerance` | enum | none / seconds / minutes / hours | `aws-rpo-rto-targets` ✓ |
| `data_sensitivity` | enum | public / internal / confidential / regulated | `nist-800-53` ✓ |
| `compliance_regime` | enum | none / hipaa / pci / soc2 / fedramp / il4 / il5 / gdpr | `nist-800-53` ✓ (see §4 for proposed enum extension) |
| `scale` | enum | small / medium / large / hyperscale | `aws-wa-tool-profiles` ✓ |
| `budget_posture` | enum | cost-first / balanced / uptime-first | `aws-wa-tool-profiles` ✓ |

## 2. Workload classifier signals (Stage 0) — new

`standards/business-intake-workload-classifier.yaml` — signals detected from the `workload` free-text answer. Signals activate stage-2 probe groups. Detection is keyword-based (case-insensitive substring); operator can override any activation via `--force-signal <signal>` / `--suppress-signal <signal>`.

| Signal | Sample keywords / patterns | Rationale |
|---|---|---|
| `web-ui` | website, web app, dashboard, portal, UI, frontend, browser, SPA | Activates w3c, web-vitals, react, oas (public API surface) |
| `backend` | API, service, backend, microservice, worker, queue-consumer | Activates node/typescript/observability |
| `cli` | CLI, command-line, terminal tool, script utility | Activates node/typescript minimal set |
| `data-pipeline` | ETL, pipeline, ingestion, batch job, streaming, warehouse | Activates data-focused Stage-2 (already exists as `--with-data`) |
| `ml-ai` | ML, AI, model, LLM, GenAI, inference, training, RAG, embedding | Activates security-governance, us-government, eo |
| `ai-high-risk` | grading, credential, credentialing, hiring, credit-decision, medical, biometric, education-assessment | Activates EU AI Act Annex III postures (Art. 13/14/15) |
| `regulated` | HIPAA, PCI, SOC 2, FedRAMP, GDPR, regulated data, PHI, PII, sensitive | Activates owasp, iam, sbom |
| `multi-tenant` | multi-tenant, tenant, SaaS, per-customer isolation | Activates owasp, iam, arch |
| `public-facing` | public, customer-facing, unauthenticated, anonymous, on the internet | Activates owasp, w3c (accessibility), web-vitals, bbp |
| `container-first` | container, Docker, Kubernetes, K8s, Helm, EKS, GKE, AKS | Activates k8s, helm, mesh, sbom |
| `serverless-first` | Lambda, serverless, Cloud Functions, Azure Functions | Activates aws/azure/gcp namespace probes |
| `iac-heavy` | Terraform, Bicep, CloudFormation, IaC, infrastructure-as-code | Activates hashicorp, iac-linter |
| `mobile` | iOS, Android, mobile app, React Native, Flutter | Activates w3c (accessibility), web-vitals-mobile |
| `government` | government, DoD, IL4, IL5, FedRAMP, federal, agency | Activates us-government, nist-800-171 |
| `ci-heavy` | pipeline, CI/CD, GitHub Actions, Azure DevOps, Jenkins, CircleCI, GitLab CI | Activates the matching CI-provider namespace |

**Detection precedence.** A workload can carry multiple signals (typical). All matching signals activate — union, not exclusive. A workload with zero matched signals still gets the universal 9 plus the "always" stage-2 groups (see §3).

## 3. Stage-2 per-namespace probe groups

One row per namespace. `activation: always` means the group fires regardless of classifier signals (foundational commitments — SLO, testing rigor, dependency update cadence, ADR discipline, SLSA level — apply to any workload). All source_ids marked ✓ are verified present in the plugin cache at pin `0cf28fe`; ⊕ NEW = needs to be added.

### Security + governance

| Namespace | Activation | Question key | Type | Allowed | Source |
|---|---|---|---|---|---|
| `security-governance` | `ai-high-risk`, `regulated` | `provenance_commitment` | enum | none / basic / signed-attested | `slsa-framework` ✓ |
| `security-governance` | `ai-high-risk` | `ai_risk_tier` | enum | not-annex-iii / annex-iii-low / annex-iii-high | ⊕ NEW `eu-ai-act-annex-iii` |
| `us-government` | `ai-high-risk` | `human_oversight_commitment` | enum | none / review-on-request / confidence-gated / always | ⊕ NEW `eu-ai-act-art-14` |
| `us-government` | `ai-high-risk` | `explainability_commitment` | enum | none / log-decision / human-readable-rationale | ⊕ NEW `eu-ai-act-art-13` |
| `us-government` | `government` | `moderate_or_high_baseline` | enum | none / moderate / high | `nist-800-171` ✓ |
| `owasp` | `public-facing`, `multi-tenant`, `regulated` | `asvs_level` | enum | L1 / L2 / L3 | `owasp-asvs` ✓ |
| `owasp` | `public-facing`, `multi-tenant` | `threat_surface` | enum | internal-only / authenticated-only / public-with-anonymous | `owasp-top10` ✓ |
| `owasp` | `web-ui` | `secure_headers_commitment` | enum | none / baseline / hardened | `owasp-secure-headers` ✓ |
| `slsa` | always | `slsa_level_commitment` | enum | 1 / 2 / 3 / 4 | `slsa-framework` ✓ |
| `sbom` | always | `sbom_commitment` | enum | none / cyclonedx / spdx | ⊕ NEW `cyclonedx-spec` (or reuse an existing SBOM source in eng catalog) |
| `bbp` | `public-facing`, `regulated` | `bug_bounty_posture` | enum | none / private-program / public-program | ⊕ NEW `bbp-best-practices` |

### Identity + auth

| Namespace | Activation | Question key | Type | Allowed | Source |
|---|---|---|---|---|---|
| `iam` | always | `identity_federation` | enum | none / sso-basic / oidc-federated | `oauth2-oidc` ✓ |
| `iam` | always | `mfa_scope` | enum | none / admin-only / all-users / risk-based | `nist-800-53` ✓ |
| `iam` | `regulated`, `government` | `zero_trust_posture` | enum | none / gradual / mature | `nist-zero-trust` ✓ |
| `jwt` | `public-facing`, `backend` | `token_lifetime_posture` | enum | long-lived / short-lived-with-refresh / short-lived-only | `oauth2-oidc` ✓ |

### UI + accessibility + performance

| Namespace | Activation | Question key | Type | Allowed | Source |
|---|---|---|---|---|---|
| `w3c` | `web-ui`, `mobile`, `public-facing` | `wcag_commitment` | enum | none / wcag-2.2-a / wcag-2.2-aa / wcag-2.2-aaa | `wcag-2-2` ✓ |
| `web-vitals` | `web-ui`, `public-facing` | `cwv_commitment` | enum | none / good-lcp-cls-inp / aspirational | `web-vitals` ✓ |
| `react` | `web-ui` + react-signal | `ssr_hydration_posture` | enum | none / partial / full-rsc | `react-rsc-rfc` ✓ |
| `react` | `web-ui` + react-signal | `strict_mode_commitment` | enum | disabled / enabled | `react-docs` ✓ |

### Language + runtime

| Namespace | Activation | Question key | Type | Allowed | Source |
|---|---|---|---|---|---|
| `typescript` | ts-signal | `strict_mode_commitment` | enum | disabled / strict / strict-plus-no-any | `typescript-handbook` ✓ |
| `typescript` | ts-signal | `target_runtime` | enum | node-lts / browser-current / both | `typescript-handbook` ✓ |
| `node` | node-signal | `lts_target` | enum | current-lts / next-lts / latest | `node-docs` ✓ |
| `node` | node-signal | `dependency_isolation_posture` | enum | none / lockfile / lockfile-plus-audit | `node-best-practices` ✓ |

### Platform + infra

| Namespace | Activation | Question key | Type | Allowed | Source |
|---|---|---|---|---|---|
| `k8s` | `container-first` | `resource_limits_posture` | enum | none / requests-only / requests-and-limits | `cncf-cloud-native` ✓ |
| `k8s` | `container-first` | `probe_posture` | enum | none / liveness-only / liveness-readiness | `cncf-cloud-native` ✓ |
| `helm` | `container-first` | `chart_versioning_posture` | enum | none / semver / semver-plus-appversion | `cncf-cloud-native` ✓ |
| `mesh` | `container-first` + multi-service | `service_mesh_commitment` | enum | none / istio / linkerd / other | `cncf-cloud-native` ✓ |
| `hashicorp` | `iac-heavy` | `pin_posture` | enum | floating / required-version / exact-pin | `hashicorp-terraform-style-guide` ✓ |
| `iac-linter` | `iac-heavy` | `linter_commitment` | enum | none / tflint / tfsec-checkov | `terraform-recommended-practices` ✓ |
| `ansible` | `iac-heavy` + ansible-signal | `role_structure_posture` | enum | ad-hoc / roles / collections | ⊕ NEW `ansible-best-practices` |
| `compose` | `container-first` + compose-signal | `compose_env_isolation` | enum | shared / per-env-files / vault-integrated | ⊕ NEW `docker-compose-best-practices` |
| `cfn` | `iac-heavy` + aws-signal | `stack_isolation_posture` | enum | monolithic / per-service / nested-stacks | `aws-cloudformation-best-practices` ✓ |
| `aws` / `azure` / `gcp` | matching cloud signal | `preferred_region_posture` | enum | single / multi-region-active-passive / multi-region-active-active | `aws-architecture-center` ✓ / `azure-architecture-center` ✓ / `gcp-architecture-center` ✓ |

### Cross-cutting foundational (always active)

| Namespace | Activation | Question key | Type | Allowed | Source |
|---|---|---|---|---|---|
| `observability` | always | `slo_commitment` | enum | none / informal / formal-99.0 / formal-99.9 / formal-99.95 / formal-99.99 | `google-sre-book` ✓ |
| `observability` | always | `telemetry_posture` | enum | logs-only / logs-metrics / logs-metrics-traces | `opentelemetry-docs` ✓ |
| `arch` | always | `contract_first_commitment` | enum | none / partial / all-boundaries | `microsoft-rest-api-guidelines` ✓ |
| `arch` | always | `boundary_style` | enum | monolith / modular-monolith / service-based / microservices | `twelve-factor-app` ✓ |
| `documentation` | always | `adr_discipline` | enum | none / decisions-only / all-architectural-changes | ⊕ NEW `nygard-adr` (or reuse `google-eng-practices` ✓) |
| `documentation` | always | `architecture_doc_commitment` | enum | none / brief / arc42-or-c4-full | `google-eng-practices` ✓ |
| `linux-foundation` | `container-first`, `regulated`, `government` | `openssf_scorecard_commitment` | enum | none / advisory / gate | `openssf-scorecard` ✓ |

### Delivery + supply-chain + CI

| Namespace | Activation | Question key | Type | Allowed | Source |
|---|---|---|---|---|---|
| — testing (as pillar) | always | `test_rigor` | enum | smoke-only / unit-integration / unit-integration-mutation / unit-integration-mutation-property | `fowler-test-pyramid` ✓ |
| — dependencies (as pillar) | always | `dependency_update_cadence` | enum | ad-hoc / monthly / weekly / continuous | ⊕ NEW `renovate-best-practices` (or reuse `google-eng-practices` ✓) |
| — dependencies | always | `dependency_versioning_posture` | enum | wildcard / caret / exact | `semver` ✓ |
| `gha` / `azdo` / `circleci` / `glci` / `jenkins` | matching ci-signal | `ci_provider` | enum | (namespace-specific) | provider-specific — all ✓ EXIST in CTP catalogs |
| `gha` / etc. | matching ci-signal | `runner_isolation_posture` | enum | shared / per-job-ephemeral / per-job-ephemeral-plus-oidc | provider-specific ✓ |
| `gitops` | `iac-heavy` + git-driven | `gitops_commitment` | enum | none / argocd / flux | `argocd-gitops` ✓ |
| `oas` | `web-ui` + `backend` + public API | `oas_commitment` | enum | none / oas-3.0 / oas-3.1 | `microsoft-rest-api-guidelines` ✓ |

### Leaf-lint (deliberately NOT in intake)

`md`, `yaml`, `json`, `jsonschema`, `sarif` — these are lint namespaces with no first-order business question. Write-time enforcement is sufficient. No intake probe needed.

## 4. Enum extension proposals

Two universal-question enums should widen to reflect the new intake surface (backward-compat: existing enum values preserved):

- **`compliance_regime`** — add `eu-ai-act`, `nist-ai-rmf`, `eo-2026`, `ccpa`. Existing values kept.
- **`data_sensitivity`** — add `phi-hipaa`, `pci-cardholder`, `regulated-ai-training-data`. Existing values kept.

## 5. Sources: what needs adding vs. reusing

**Reuse (already in CTP catalogs at `0cf28fe`):** `owasp-asvs`, `owasp-top10`, `owasp-secure-headers`, `slsa-framework`, `nist-ai-rmf`, `nist-800-53`, `nist-800-171`, `nist-zero-trust`, `wcag-2-2`, `web-vitals`, `oauth2-oidc`, `node-docs`, `node-best-practices`, `typescript-handbook`, `react-docs`, `react-rsc-rfc`, `google-sre-book`, `google-eng-practices`, `fowler-test-pyramid`, `semver`, `opentelemetry-docs`, `hashicorp-terraform-style-guide`, `terraform-recommended-practices`, `cncf-cloud-native`, `openssf-scorecard`, `aws-architecture-center`, `aws-cloudformation-best-practices`, `azure-architecture-center`, `gcp-architecture-center`, `microsoft-rest-api-guidelines`, `twelve-factor-app`, `argocd-gitops`.

**Add (⊕ NEW to `standards/*.yaml`):**
- `eu-ai-act-annex-iii` — EU AI Act, Annex III (high-risk categories). URL: `https://artificialintelligenceact.eu/annex/3/`. Extend `standards/eo-security-sources.yaml`.
- `eu-ai-act-art-13` — Art. 13 transparency requirements. URL: `https://artificialintelligenceact.eu/article/13/`. Same catalog.
- `eu-ai-act-art-14` — Art. 14 human oversight requirements. URL: `https://artificialintelligenceact.eu/article/14/`. Same catalog.
- `eu-ai-act-art-15` — Art. 15 accuracy/robustness/cybersecurity. Same catalog.
- `eo-2026-4-ai-security` — Executive Order (2026-06-02) §4 AI-security thrust. Extend `standards/eo-security-sources.yaml`.
- `nygard-adr` — Michael Nygard "Documenting Architecture Decisions" (2011). URL: `https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions`. Extend `standards/cloud-architecture-sources.yaml`.
- `cyclonedx-spec` — CycloneDX SBOM specification. URL: `https://cyclonedx.org/specification/overview/`. Extend `standards/cloud-engineering-sources.yaml`.
- `bbp-best-practices` — Bug-bounty program best practices. Suggested: OWASP Vulnerability Disclosure Cheat Sheet + BBP guidance from HackerOne/Bugcrowd. Extend `standards/cloud-engineering-sources.yaml`.
- `ansible-best-practices` — Red Hat / community "Ansible Best Practices" guide. URL: `https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html`. Extend `standards/cloud-engineering-sources.yaml`.
- `docker-compose-best-practices` — Docker Compose recommended file structure. Extend `standards/cloud-engineering-sources.yaml`.
- `renovate-best-practices` — Renovate documentation recommended presets. Alternative: reuse `google-eng-practices` if CTP prefers to avoid a new source.

**Reuse if CTP prefers to avoid new sources:** `nygard-adr` can be folded under `google-eng-practices` (which already covers ADR discipline in the Google guides); `renovate-best-practices` folds under the same. Only the 5 EU AI Act / EO-2026 sources are strictly new — the others are convenience additions.

## 6. Activation summary — which namespaces fire for the Certifiable kata

For the Certifiable, Inc. workload (grading credentials, 5–10× surge, EU candidates likely), the classifier detects: `backend`, `ml-ai`, `ai-high-risk`, `regulated`, `public-facing`, `multi-tenant` (candidates + graders + accreditors), `data-pipeline` (submission → grading queue).

Activated stage-2 probe groups: `security-governance`, `us-government`, `owasp`, `slsa`, `sbom`, `iam`, `jwt`, `observability`, `arch`, `documentation`, `linux-foundation`, `hashicorp` (if IaC-heavy signal added), `oas`, and testing/dependencies. Roughly **~13 namespaces** — up from `active.json`'s 4 today — for a workload of this complexity.

Universal 9 (Stage 1) plus ~13 stage-2 groups × ~1-2 questions per group = ~22-30 total questions. That's the ceiling for this workload class. Question count scales down for simpler workloads (a CLI tool: universal 9 + `testing` + `dependencies` + `documentation` + `arch` = ~13 total).

## 7. What this manifest is NOT

- Not a spec CTP is bound to verbatim — it's a build-time reference. CTP's architectural discretion (naming, structure, activation subtleties, source authority tiering) governs the actual `standards/business-intake-question-bank.yaml` shape.
- Not exhaustive — additional first-order business questions may exist in each namespace; this manifest is the minimum viable set to demonstrate the pattern.
- Not authoritative on source citations — some URLs need CTP-side verification against the fetcher discipline (`html-anchor.sh` etc.). CTP owns the fetch/authority-tier assignment.
