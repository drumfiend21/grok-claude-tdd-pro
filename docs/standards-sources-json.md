# Standards sources — JSON corpus

Stable in-repo mirror of the 40+ source JSON standards bundle (plus the SchemaStore meta-catalog of 700+ schemas) assembled in the 2026-06-19 GCTP research session. Cited by `docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md` and by `proposals/PROPOSAL-003-ctp-session-brief.md`.

**License posture summary:**
- **Mirror permitted**: Apache 2.0, MIT, CC-BY-4.0, BSD-2-Clause, IETF RFC public, OASIS RF, ECMA RF, W3C Document License, CC0.
- **Cite-link only**: AWS docs, Microsoft Learn (some pages), npm docs, Snyk, OpenAI/Anthropic API docs.

## Master table (40+ direct sources + SchemaStore)

| # | Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|---|
| 1 | RFC 8259 (JSON spec) | IETF | https://datatracker.ietf.org/doc/html/rfc8259 + https://www.rfc-editor.org/rfc/rfc8259.txt | HTML / TXT (stable) | IETF Trust (public) |
| 2 | ECMA-404 (2nd ed) | ECMA International | https://ecma-international.org/wp-content/uploads/ECMA-404_2nd_edition_december_2017.pdf | PDF (stable) | ECMA RF |
| 3 | RFC 7493 (I-JSON) | IETF | https://datatracker.ietf.org/doc/html/rfc7493 | HTML / TXT | IETF Trust |
| 4 | JSON Schema 2020-12 | json-schema.org | https://json-schema.org/draft/2020-12/release-notes | HTML | BSD-2-Clause |
| 5 | JSON Schema Draft 7 meta-schema | json-schema.org | http://json-schema.org/draft-07/schema# | JSON (stable) | BSD-2-Clause |
| 6 | JSON Schema Draft 2019-09 meta-schema | json-schema.org | https://json-schema.org/draft/2019-09/schema | JSON | BSD-2-Clause |
| 7 | JSON Schema Draft 6 meta-schema | json-schema.org | http://json-schema.org/draft-06/schema# | JSON | BSD-2-Clause |
| 8 | JSON Schema Draft 4 meta-schema | json-schema.org | http://json-schema.org/draft-04/schema# | JSON | BSD-2-Clause |
| 9 | Ajv (JSON Schema validator, JS) | ajv-validator/ajv | https://github.com/ajv-validator/ajv | git / raw | MIT |
| 10 | python-jsonschema | python-jsonschema/jsonschema | https://github.com/python-jsonschema/jsonschema | git / raw | MIT |
| 11 | json_schemer (Ruby) | davishmcclurg/json_schemer | https://github.com/davishmcclurg/json_schemer | git / raw | MIT |
| 12 | OpenAPI 3.1 spec | OAI | https://spec.openapis.org/oas/v3.1.0.html + https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.1.0.md | HTML / RAW MD | Apache 2.0 |
| 13 | JSON-LD 1.1 | W3C | https://www.w3.org/TR/json-ld11/ | HTML | W3C Document License |
| 14 | JSON:API 1.1 | jsonapi.org | https://jsonapi.org/format/ | HTML | CC0 |
| 15 | JSON-RPC 2.0 | JSON-RPC WG | https://www.jsonrpc.org/specification | HTML | Perpetual implementation grant |
| 16 | RFC 7519 (JWT) | IETF | https://datatracker.ietf.org/doc/html/rfc7519 | HTML / TXT | IETF Trust |
| 17 | RFC 7515 (JWS) | IETF | https://datatracker.ietf.org/doc/html/rfc7515 | HTML / TXT | IETF Trust |
| 18 | RFC 7516 (JWE) | IETF | https://datatracker.ietf.org/doc/html/rfc7516 | HTML / TXT | IETF Trust |
| 19 | RFC 7517 (JWK) | IETF | https://datatracker.ietf.org/doc/html/rfc7517 | HTML / TXT | IETF Trust |
| 20 | **RFC 8725 (JWT BCP)** | IETF | https://datatracker.ietf.org/doc/html/rfc8725 | HTML / TXT | IETF Trust |
| 21 | package.json reference | npm | https://docs.npmjs.com/cli/v10/configuring-npm/package-json | HTML | proprietary (de-facto spec) |
| 22 | package-lock.json reference | npm | https://docs.npmjs.com/cli/v10/configuring-npm/package-lock-json | HTML | proprietary |
| 23 | composer.lock | Composer | https://getcomposer.org/doc/01-basic-usage.md | RAW MD | MIT |
| 24 | Pipfile.lock | PyPA / Pipenv | https://pipenv.pypa.io/en/latest/pipfile.html | HTML | MIT |
| 25 | tsconfig.json reference | Microsoft (TypeScript) | https://www.typescriptlang.org/tsconfig | HTML | Apache 2.0 project / proprietary docs |
| 26 | VS Code settings/launch/tasks | Microsoft | https://code.visualstudio.com/docs/configure/settings | HTML | proprietary docs |
| 27 | AWS IAM Policy grammar | AWS | https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_grammar.html | HTML | proprietary — cite-link |
| 28 | AWS IAM best practices | AWS | https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html | HTML | proprietary |
| 29 | GCP IAM allow-policy | Google Cloud | https://cloud.google.com/iam/docs/policies | HTML | proprietary |
| 30 | Azure RBAC role definitions | Microsoft | https://learn.microsoft.com/en-us/azure/role-based-access-control/role-definitions | HTML; src MicrosoftDocs/azure-docs-pr | CC-BY 4.0 (docs) |
| 31 | Azure Policy definition structure | Microsoft | https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-basics | HTML | CC-BY 4.0 |
| 32 | Kubernetes JSON manifests | Kubernetes | https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/ | HTML | CC-BY 4.0 |
| 33 | Helm values.schema.json | Helm | https://helm.sh/docs/topics/charts/#schema-files | HTML | Apache 2.0 |
| 34 | devcontainer.json | containers.dev | https://containers.dev/implementors/json_reference/ + https://github.com/devcontainers/spec/blob/main/schemas/devContainer.base.schema.json | HTML / RAW | MIT |
| 35 | Renovate config | Mend/Renovate | https://docs.renovatebot.com/configuration-options/ + https://docs.renovatebot.com/renovate-schema.json | HTML / RAW JSON | AGPL-3.0 (project) |
| 36 | CloudFormation JSON template | AWS | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html | HTML | proprietary |
| 37 | Terraform JSON syntax | HashiCorp | https://developer.hashicorp.com/terraform/language/syntax/json | HTML | MPL 2.0 project |
| 38 | Pulumi state | Pulumi | https://www.pulumi.com/docs/iac/concepts/state-and-backends/ | HTML | Apache 2.0 |
| 39 | OPA bundle manifest | OPA | https://www.openpolicyagent.org/docs/management-bundles#bundle-file-format | HTML | Apache 2.0 |
| 40 | **CycloneDX SBOM JSON** | OWASP / ECMA TC54 | https://cyclonedx.org/specification/overview/ + https://github.com/CycloneDX/specification/tree/master/schema | HTML / RAW JSON | Apache 2.0 + ECMA RF |
| 41 | **SPDX JSON 2.3** | Linux Foundation / SPDX | https://spdx.github.io/spdx-spec/v2.3/ + https://github.com/spdx/spdx-spec/blob/support/2.3.1/schemas/spdx-schema.json | HTML / RAW JSON | CC-BY-3.0 |
| 42 | **SARIF 2.1.0** | OASIS | https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html + https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json | HTML / RAW JSON | OASIS RF |
| 43 | OTel JSON (OTLP file) | OpenTelemetry | https://opentelemetry.io/docs/specs/otlp/ | HTML | Apache 2.0 |
| 44 | CloudEvents JSON 1.0.2 | CNCF | https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/formats/json-format.md | RAW MD | Apache 2.0 |
| 45 | Schema.org JSON-LD context | Schema.org | https://schema.org/docs/jsonldcontext.json | RAW JSON | CC-BY-SA 3.0 |
| 46 | Elastic Common Schema (ECS) | Elastic | https://www.elastic.co/docs/reference/ecs | HTML | Apache 2.0 |
| 47 | Spectral (OAS linter) | Stoplight | https://github.com/stoplightio/spectral | git / raw | Apache 2.0 |
| 48 | cfn-lint | AWS | https://github.com/aws-cloudformation/cfn-lint | git / raw | Apache 2.0 |
| 49 | cfn-guard | AWS | https://github.com/aws-cloudformation/cloudformation-guard | git / raw | Apache 2.0 |
| 50 | Trivy (multi) | Aqua Security | https://github.com/aquasecurity/trivy | git / raw | Apache 2.0 |
| 51 | Checkov (multi) | Bridgecrew / Palo Alto | https://github.com/bridgecrewio/checkov | git / raw | Apache 2.0 |
| 52 | **SchemaStore — meta-catalog of 700+ JSON Schemas** | SchemaStore.org | https://www.schemastore.org/json/ + https://github.com/SchemaStore/schemastore | git / raw | Apache 2.0 |
| 53 | SARIF tools | Microsoft | https://github.com/microsoft/sarif-sdk | git / raw | MIT |
| 54 | cyclonedx-cli | CycloneDX | https://github.com/CycloneDX/cyclonedx-cli | git / raw | Apache 2.0 |
| 55 | spdx-tools (Python) | SPDX | https://github.com/spdx/tools-python | git / raw | Apache 2.0 |

## Highest-leverage seeds (start order)

1. **SchemaStore** (#52) — Apache 2.0 meta-catalog of 700+ JSON Schemas at `json.schemastore.org/<name>.json`. Largest density per ingest hour by an order of magnitude.
2. **RFC 8725 JWT BCP** (#20) — IETF public; the highest-leverage P0 cluster in the whole corpus (`alg:none`, alg-allowlist, key-confusion, iss/aud validation, kid sanitization).
3. **CycloneDX 1.6 + SPDX 2.3 raw JSON schemas** (#40, #41) — feed SBOM-conformance detectors directly into the SLSA / EO layer.
4. **OASIS SARIF 2.1.0 schema** (#42) — the harness's own output format; emit-only, don't reinvent.
5. **AWS IAM grammar page** (#27) — cite-link, but the regex P0s (`"Action": "*"`, `"Resource": "*"`) are trivially extracted.

## JSONC tolerance — meta-rule

tsconfig (#25), Renovate (#35), .vscode/* (#26), devcontainer.json (#34) all allow JSONC (JSON with comments). Detectors targeting these MUST use a JSONC-tolerant parser (e.g., `jsonc-parser` MIT) before applying JSON-strict rules. Surface a class of `g-jsonc-comments-allowed-only-in-jsonc-contexts` P1 rule.

## Excluded / superseded

- **Snyk K8s rules page** — substantially overlaps Trivy. Pick Trivy (Apache 2.0 + scrapeable Rego).
- **AsyncAPI 2/3** — separate context not in current scope; flag for follow-up.
- **yarn.lock / pnpm-lock.yaml** — not JSON. yarn.lock is YAML-ish; pnpm-lock is YAML (covered in YAML manifest).
- **poetry.lock / Cargo.lock** — TOML, not JSON.

## Anthropic / OpenAI API JSON shapes — citation only

- **Anthropic Messages API**: https://docs.anthropic.com/en/api/messages — proprietary; cite only.
- **OpenAI Chat Completions**: docs page is SPA + 403 to scrapers. Recommended raw source: https://github.com/openai/openai-openapi/blob/master/openapi.yaml — MIT-licensed OpenAPI 3.x spec with full request/response JSON Schemas.

Tool-use-schema safety rules apply to both as JSON Schema instances: `g-llm-tool-input-schema-strict` (P1), `g-llm-no-secrets-in-tool-description` (P0), etc.
