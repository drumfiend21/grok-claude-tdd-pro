# CTP Work Brief — Composite Engine + 4-Axis Canonical Vocabulary

**Audience:** the `claude-tdd-pro` (CTP) development session.
**Author:** GCTP cloud session, 2026-06-21.
**Authority:** TIER-1 process change for CTP. Land as a new ADR in `claude-tdd-pro/docs/adr/`. Composes on PROPOSAL-003 (already adopted in CL-484..487), PROPOSAL-004 (detector quality uplift — partially supersedes once this lands), and the existing `enforce.sh` / `enforce-file.sh` contract.

Self-contained brief. The CTP team can consume it directly without GCTP context.

---

## 1. The architectural primitive — content-kind routing on a canonical join vocabulary

The composite engine routes rule enforcement to off-the-shelf FOSS tools (Semgrep, ESLint, Checkov, Kubescape, Trivy, Spectral, stylelint, markdownlint, Vale, lychee, hadolint, zizmor, gitleaks, OpenSSF Scorecard, per-language native linters, plus CTP's own `prose-judge.sh`). The join key between a **rule** and the **tool that enforces it** is the **content kind** the rule applies to (TypeScript file, Kubernetes Pod manifest, OpenAPI 3.1 spec, React component, etc.). For rules to bind cleanly across tools and across rule sources (Google, Microsoft, OWASP, Accenture, Walmart, NASA — anyone the operator scrapes from), they must use the **same canonical vocabulary** the FOSS tooling ecosystem already speaks.

**No CTP-invented vocabulary.** The industry has converged on a small set of authorities, each owning one dimension. CTP composes them.

## 2. The four authorities (mirror-only; CTP refreshes, does not author)

| Axis | Authority | URL | Convention | License |
|---|---|---|---|---|
| **Languages** (source-text grammar) | GitHub Linguist `aliases[0]` (lowercase form) | https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml | lowercase: `python`, `typescript`, `rust`, `go`, `kotlin`, ~700 entries | MIT |
| **Structured-config dialects** | IaC-scanner consensus (Checkov + Trivy + Spectral converge) | (no single URL; CTP curates `composite/iac-dialects.yaml` from Checkov, Trivy, Spectral docs) | lowercase snake_case: `kubernetes`, `terraform`, `dockerfile`, `openapi`, `helm`, `github_actions`, `gitlab_ci`, `cloudformation`, `bicep`, `arm`, `kustomize`, `ansible`, `argo_workflows`, ~15 entries | per-source (Apache 2.0 / MIT) |
| **Frameworks / libraries** | Package URL (PURL) spec + the per-ecosystem package registries it indexes | https://github.com/package-url/purl-spec | `pkg:<ecosystem>/<name>[@<version>]` — `pkg:npm/react`, `pkg:pypi/django`, `pkg:maven/org.springframework/spring-boot`, `pkg:cargo/axum`, `pkg:rubygems/rails` | MIT |
| **Kubernetes sub-kinds** (optional fine-grained for k8s) | Kubernetes API `apiVersion/kind` (GVK) | https://kubernetes.io/docs/reference/using-api/ | `<group>/<version>/<Kind>` — `apps/v1/Deployment`, `networking.k8s.io/v1/Ingress`, `argoproj.io/v1alpha1/Workflow` | Apache 2.0 |

CTP ships mirror files refreshed on cadence (reuses PROPOSAL-003 standards-refresh): `composite/linguist-mirror.json`, `composite/iac-dialects.yaml`, `composite/purl-types.yaml`, `composite/k8s-gvks.json`. CTP does not author identifiers — it tracks upstream.

## 3. Rule schema — `applies_to.*` + ordered `enforced_by[]` + `provenance`

Every rule in `active.json` declares its targeting + enforcement in this canonical shape:

```yaml
- id: g-walmart-microservices-rest-endpoints-must-be-versioned
  source_namespace: walmart
  origin: operator                            # plugin | operator | community
  intent: "REST endpoints MUST be versioned via path prefix /v{N}/ for backward-compat."

  applies_to:
    linguist_aliases:                         # Linguist canonical IDs (lowercase)
      [typescript, javascript, python, go, java, kotlin, ruby, php, rust, csharp]
    iac_dialects: [openapi]                   # IaC-scanner consensus IDs
    purl_uses:                                # PURL identifiers
      - pkg:npm/express
      - pkg:npm/fastify
      - pkg:pypi/fastapi
      - pkg:rubygems/rails
      - pkg:maven/org.springframework/spring-boot
    k8s_gvks: []                              # k8s GVK strings (empty here — rule isn't k8s-specific)

  provenance:
    - source: "Walmart Engineering Standards — Microservices Playbook §3.2"
      url: "https://walmart.example/engineering/standards/microservices.html"
      section_anchor: "#rest-endpoints-must-be-versioned"
      retrieved: "2026-06-21T15:42:08Z"
      pin_hash: "sha256:a3f9b8e7..."
      license: "operator-supplied (internal use only)"
      classification_confidence: high
      classified_by: "PROPOSAL-006 auto-classifier 2026-06-21; operator-reviewed 2026-06-21"

  enforced_by:                                # ordered; first matching binding per file wins
    - kinds:
        linguist_aliases: [typescript, javascript]
        purl_uses: [pkg:npm/express, pkg:npm/fastify, pkg:npm/@nestjs/core]
      tool: semgrep
      ruleset: ".harness/operator-standards/custom-rules/semgrep/walmart-rest-versioning-ts.yml"
    - kinds:
        linguist_aliases: [python]
        purl_uses: [pkg:pypi/fastapi, pkg:pypi/django, pkg:pypi/flask]
      tool: semgrep
      ruleset: ".harness/operator-standards/custom-rules/semgrep/walmart-rest-versioning-py.yml"
    - kinds:
        iac_dialects: [openapi]
      tool: spectral
      ruleset: ".harness/operator-standards/custom-rules/spectral/walmart-openapi-versioned-paths.yml"

  severity: P0
  applies_to_prose: false                     # not an architectural-prose rule
```

The fields:
- **`applies_to.*`** — the MATCH half. Set intersection on canonical IDs decides whether the rule fires on a file. Validated against the mirrors at session start; unresolvable IDs fail-fast with did-you-mean suggestions.
- **`enforced_by[]`** — ordered tool bindings. Each binding names a tool, the ruleset to use, and the kinds it covers. First matching binding per file wins. No tool lock-in: swap Semgrep for CodeQL = swap the binding; rule identity, intent, provenance, and applies_to all survive.
- **`provenance`** — citation block. Source doc, URL, retrieval timestamp, license, classification confidence. Read by refresh + audit; not used for match logic.

## 4. File classification — by the tools themselves, not by CTP

The composite engine does NOT pre-classify files. Every tool in the stack already detects the content it can process: ESLint reads `.ts/.tsx/.js/.jsx`, stylelint detects `.css/.scss/.less`, Checkov auto-detects Terraform vs CloudFormation vs Kubernetes vs Helm by file shape and content, Kubescape reads `apiVersion + kind` natively, Spectral knows OpenAPI from AsyncAPI by the document's self-identifier, the per-language native linters silently skip files outside their language. Files don't need a separate classifier layer; the engine invokes each tool with the right ruleset on the right file glob (or whole repo) and lets the tool handle scope-of-applicability internally.

**The rule's `applies_to.*` tags drive WHICH tools to invoke, not WHICH files match.** The tools handle file matching themselves with detection logic that's more accurate than anything we'd write.

## 5. The composite engine — two enforcement phases, one mechanism

### 5.1 Generative time (write-time) — every file write is vetted

When any Edit/Write/MultiEdit/NotebookEdit tool runs, the GCTP `.claude/hooks/post-tool-use-review-gate.sh` hook fires (already exists from CL-E). The hook:

1. Receives `{tool_name, file_path}` from Claude Code's hook protocol.
2. Looks up the file's extension/path against `active.json` rules whose `applies_to.*` matches.
3. For each matching rule, walks `enforced_by[]` in order and picks the first binding.
4. Invokes the named tool with the named ruleset against the just-written file via a thin wrapper in `rubric/detectors/composite-tools/<tool>.sh`.
5. Tool emits SARIF.
6. Aggregates SARIF via `scripts/sarif-aggregate.sh` (already exists from CL-B).
7. If any P0 violation → exit 2 → Claude Code displays the violation inline and effectively blocks the write from being accepted.

**Strict pre-write enforcement adder (NEW):** add a paired `.claude/hooks/pre-tool-use-review-gate.sh` for the PreToolUse hook event. Receives the *proposed* file content (Claude Code's hook protocol exposes it in the payload), writes to a tempfile, runs the same tool stack against the tempfile, exits non-zero to block the tool from completing if violations fire. This gives the strict "nothing ever lands on disk in violating form" guarantee. Roughly a few hours of new work; reuses 90% of the post-tool-use logic.

### 5.2 Audit time — whole-tree verification, same mechanism

When `/audit` runs or the dispatch gate (`scripts/audit-design-phase-md.sh` from CL-C) fires before a request is emitted, `scripts/enforce-standards.sh` (Fix B / ADR-0062, already exists) drives the same tool stack at higher scope. It reads the ticket's `applicable_rules`, walks each rule's `enforced_by[]`, invokes the right tool wrappers across the whole `app_root`, aggregates SARIF, and writes the `rules_verified` block straight from the actual detector verdicts. The audit chain (`audit-rules-verified.sh` per Fix C, `audit-applicable-rules.sh` per Fix A, the deviation-row mechanism per ADR-0066 D-F) consumes the aggregated SARIF and gates `/dispatch` and commits.

## 6. The tool stack — what each binding can route to

| Tier | Tool | License | Domain | SARIF |
|---|---|---|---|---|
| Universal | **Semgrep** community | LGPL-2.1 engine, Apache-2.0 rules | Multi-language SAST (~30 languages, ~5000 community rules: OWASP/CWE/MITRE/SANS/JWT BCP) | yes |
| Universal | **Trivy** | Apache-2.0 | CVE scanning + secrets + IaC misconfig + SBOM (CycloneDX + SPDX) | yes |
| Universal | **OSV-Scanner** | Apache-2.0 | Google's vuln scanner against OSV.dev database (complements Trivy) | yes |
| Universal | **syft + grype** | Apache-2.0 | Anchore SBOM generator + vulnerability scanner (cross-checks Trivy results) | yes |
| Universal | **gitleaks** | MIT | Secrets in source (any text) | yes |
| Universal | **detect-secrets** | Apache-2.0 | Yelp's secrets scanner with baseline support (complements gitleaks) | yes (via formatter) |
| Universal | **trufflehog** | AGPL-3.0 | Live-credential verification beyond pattern match | yes (via formatter) |
| Universal | **conftest** | Apache-2.0 | Rego policies over YAML/JSON/TOML/HCL/Dockerfile/Cue | yes (via SARIF wrapper) |
| Universal | **OPA** + **regal** | Apache-2.0 | Open Policy Agent runtime + Rego linter (for authoring policies) | yes |
| Universal | **OpenSSF Scorecard** | Apache-2.0 | Repo-level supply-chain posture | yes |
| Universal | **cosign + slsa-verifier** | Apache-2.0 | SLSA build provenance + signing | n/a (attestations) |
| Universal | **in-toto** + **slsa-github-generator** | Apache-2.0 | Supply-chain attestations + SLSA build-level provenance generation | n/a (attestations) |
| JS/TS | **ESLint** + plugin family: `gts`, `@typescript-eslint`, `@microsoft/eslint-plugin-sdl`, `eslint-plugin-n`, `eslint-plugin-react`, `eslint-config-next`, `eslint-plugin-jsx-a11y`, `@angular-eslint/eslint-plugin`, `eslint-plugin-security` | MIT/Apache-2.0 | Google TS/JS style, Microsoft SDL, Node best practices, React/Next/Angular, a11y, Node security | yes (via formatter) |
| JS/TS | **Biome** + **oxlint** | MIT | Rust-based fast JS/TS linter+formatter (10-100x ESLint+Prettier); oxlint is a complementary fast linter | yes (via formatter) |
| JS/TS | **Prettier** | MIT | Opinionated formatter for JS/TS/CSS/HTML/Markdown/YAML/JSON — runs alongside ESLint when Biome not adopted | n/a (format-only) |
| CSS | **stylelint** + `stylelint-config-recommended-scss` + `stylelint-config-recommended-less` + `stylelint-config-tailwindcss` + `stylelint-config-standard` | MIT | CSS/SCSS/Less/PostCSS/Tailwind | yes (via formatter) |
| HTML | **htmlhint** + `html-validate` | MIT | HTML lint + W3C validator | yes (via formatter) |
| Accessibility | **axe-core** + **pa11y** + **pa11y-ci** | MPL-2.0/MIT | WCAG 2.2 a11y auditing — runs against rendered HTML or via headless-Chrome | yes (via formatter) |
| Web Vitals | **Lighthouse** + **lighthouse-ci** | Apache-2.0 | Core Web Vitals (LCP/CLS/INP), PWA, SEO, performance budgets | yes (via formatter) |
| IaC | **Checkov** | Apache-2.0 | 1000+ policies for Terraform/CFN/k8s/Helm/Dockerfile/ARM/Bicep/Compose/GHA/GitLab CI/Azure Pipelines/Ansible/CircleCI/Bitbucket/Argo — with NIST 800-53/FedRAMP/SOC2/PCI/HIPAA/CIS framework mappings | yes |
| IaC | **tfsec** + **terrascan** + **tflint** | MIT/Apache-2.0 | Terraform-specific SAST + linting (complementary alternatives to Checkov/Trivy) | yes |
| K8s | **Kubescape** | Apache-2.0 | 260+ controls (NSA-CISA + CIS + MITRE ATT&CK + NIST SSDF + FedRAMP) | yes |
| K8s | **kube-linter** + **kubeconform** + **polaris** | Apache-2.0 | K8s manifest lint + JSON-schema validation + best-practice analysis | yes |
| K8s | **kyverno** + **kyverno-cli** | Apache-2.0 | K8s-native policy engine (alternative to OPA/conftest for cluster-side enforcement) | yes |
| OpenAPI | **Spectral** + `@stoplight/spectral-owasp-ruleset` | Apache-2.0 | OpenAPI 3.x + AsyncAPI + OWASP API Top 10 | yes |
| OpenAPI | **vacuum** + **redocly-cli** | Apache-2.0/MIT | Fast Go-based OpenAPI linter + Redocly's CI suite (alternatives to Spectral) | yes |
| GHA | **zizmor** + `actionlint` + `pinact` | Apache-2.0 / MIT | GitHub Actions security + correctness | yes (zizmor) |
| Dockerfile | **hadolint** | GPL-3.0 | Dockerfile lint | yes |
| YAML | **yamllint** | GPL-3.0 | General YAML lint (complements IaC-specific tools for plain YAML) | yes (via formatter) |
| JSON | **ajv-cli** + **jq** | MIT | JSON schema validation (700+ schemas via SchemaStore) + structural query | n/a |
| Markdown | **markdownlint-cli2** | MIT | Structural Markdown (MD001-MD060) | yes |
| Prose | **Vale** with `errata-ai/Google` + `vale-cli/Microsoft` + `errata-ai/alex` style packs | MIT | Tone/style/inclusive-language prose | yes |
| Links | **lychee** | Apache-2.0 OR MIT | Link integrity | yes |
| Spell | **cspell** + **codespell** | MIT / GPL-2.0 | Spell-check (code-aware + dictionary) | yes (cspell) |
| Languages — Rust | `rustfmt` + `clippy` + `cargo-audit` + `cargo-deny` | Apache-2.0/MIT | Rust formatter + linter + CVE + license | partial |
| Languages — Go | `golangci-lint` (wraps ~50 linters) + `govulncheck` | MIT | Go linter aggregator + CVE | yes |
| Languages — Python | **ruff** + `bandit` + `mypy` + `pip-audit` | MIT/Apache-2.0 | Python linter/security/types/CVE | yes |
| Languages — Java | Spotless + ErrorProne + SpotBugs + PMD + `dependency-check` | Apache-2.0 | JVM lint + bug-finder + CVE | yes |
| Languages — Kotlin | `ktlint` + Detekt | Apache-2.0/MIT | Kotlin lint/security | yes |
| Languages — Swift | SwiftLint + SwiftFormat | MIT | Swift lint/format | yes |
| Languages — C# | Roslyn analyzers + SonarAnalyzer.CSharp + SecurityCodeScan | LGPL/MIT | .NET lint/security | yes |
| Languages — Ruby | RuboCop + brakeman + bundler-audit | MIT | Ruby lint/security/CVE | yes |
| Languages — Elixir | credo + dialyxir + sobelow | MIT | Elixir lint/types/security | yes (via wrapper) |
| Languages — Scala | Scalafix + Scalafmt + scapegoat | Apache-2.0 | Scala lint/format | yes (via wrapper) |
| Languages — PHP | PHPStan + psalm + phpcs-security-audit | MIT | PHP types/lint/security | yes |
| Languages — Solidity | Slither + solhint + Mythril | AGPL/MIT | Smart-contract security | yes |
| Shell | ShellCheck + shfmt | GPL/MIT | Bash lint/format | yes (ShellCheck via SARIF formatter) |
| SQL | SQLFluff + sqlfmt + sqlcheck | MIT | SQL lint/format/anti-pattern | partial |
| GraphQL | `graphql-eslint` + `graphql-schema-linter` | MIT | GraphQL schema lint | yes (via ESLint) |
| Protobuf | `buf lint` + protolint | Apache-2.0 | Protobuf lint | yes |
| **The CTP moat** | **`prose-judge.sh`** | CTP-shipped | Semantic projection of code rules onto architectural prose (no FOSS equivalent) | yes |

## 7. Tool wrappers — `composite/tools/<name>.sh`

Each tool gets a tiny shell wrapper (10-30 lines) that knows how to invoke the tool with `--sarif --output-file -` (or its equivalent) and translate exit codes into the CTP 4-state contract (`pass | fail | not_applicable | not_enforced`). Example:

```bash
#!/usr/bin/env bash
# composite/tools/checkov.sh — wrapper that invokes Checkov with SARIF output.
# Per the §2.2 detector contract: --paths / --root / --rule / --json.

set -uo pipefail
RULESET=""; PATHS=""; ROOT="."; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ruleset) RULESET="$2"; shift 2 ;;
    --paths) PATHS="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) shift ;;
  esac
done

checkov -d "$ROOT" --external-checks-dir "$RULESET" --output sarif --output-file-path - 2>/dev/null
case $? in
  0) exit 0 ;;   # pass
  1) exit 1 ;;   # fail
  *) exit 3 ;;   # not_enforced
esac
```

Wrappers are mechanical. ~30 of them total cover the stack above. They sit under `rubric/detectors/composite-tools/` so the existing `enforce.sh` / `enforce-file.sh` dispatch logic finds them via the same `detector` field in `active.json`.

## 8. Auto-fix paths — which tools support `--fix` and how the gap closes

| Tool | `--fix` mode | Coverage |
|---|---|---|
| ESLint | yes (`--fix`) | Many rules auto-fixable; type-aware rules typically not |
| stylelint | yes (`--fix`) | Most rules |
| Prettier / Biome | format-on-save | Pure formatting |
| ruff | yes (`--fix`) | Very capable Python auto-fix |
| rustfmt / gofmt / shfmt | format-only | Formatting only |
| markdownlint-cli2 | yes (`--fix`) | Subset of MD rules |
| Semgrep | partial (`--autofix` when rule defines `fix:`) | Rule-defined fixes only |
| Checkov / Trivy / Kubescape / Spectral / hadolint / zizmor / gitleaks / OpenSSF Scorecard | **NO auto-fix** | Security tools deliberately don't rewrite security-critical config |

For tools without `--fix`, the architecture uses **LLM-mediated remediation**: the SARIF finding + file + rule prose are handed to Claude Code (or any code-aware agent), which proposes the fix; the proposed fix re-runs through the same write-time hook to verify the fix is itself conformant. Same pattern PR-review tools like CodeRabbit and Greptile use today. CTP's `prose-judge.sh` LLM primitive can be reused for this remediation step too — operator-mediated, audit-attestable, low marginal cost.

## 9. Decision (proposed CTP-ADR-NNNN)

**CTP-D-1.** Adopt the 4-axis canonical vocabulary as the rule-binding primitive. Ship `composite/linguist-mirror.json`, `composite/iac-dialects.yaml`, `composite/purl-types.yaml`, `composite/k8s-gvks.json` as refreshed mirrors. Add `applies_to.{linguist_aliases,iac_dialects,purl_uses,k8s_gvks}` to the rule schema. Backward-compatible — old `applies_to` semantics deprecated but readable.

**CTP-D-2.** Adopt `enforced_by[]` as an ordered list of tool bindings with per-binding `kinds:` selectors. First matching binding per file wins. Replaces the per-rule `detector:` field (deprecated, dual-read for one release cycle for migration).

**CTP-D-3.** Ship `rubric/detectors/composite-tools/<tool>.sh` wrappers for every tool in the stack (Section 6). Each wrapper invokes the tool with SARIF output and translates exit codes to the §2.2 contract.

**CTP-D-4.** Provide `scripts/install-composite.sh` as the bootstrap installer — invokes `brew install` / `npm install -g` / `pip install` / `docker pull` for each tool the operator's rule catalog references via `enforced_by`. Operator runs once per project.

**CTP-D-5.** Add PreToolUse hook variant (`.claude/hooks/pre-tool-use-review-gate.sh`) alongside the existing PostToolUse hook (CL-E). PreToolUse intercepts the write *before* it hits disk, runs the tool stack against the proposed content, exits non-zero to block. Together with PostToolUse, this gives operators a choice: strict (PreToolUse, no violating bytes ever on disk) or pragmatic (PostToolUse, immediate flag + agent self-correction).

**CTP-D-6.** Validation: `scripts/kinds.sh validate` runs at session start and asserts every rule's `applies_to.*` resolves against the mirrors. Unresolvable → RED with did-you-mean suggestions. Wired into the existing audit chain alongside `audit-applicable-rules.sh`.

**CTP-D-7.** Operator-supplied custom rules live under `.harness/operator-standards/custom-rules/<tool>/`. Per-tool subdirectories. Operator extension to the rule catalog is additive — no engine change required.

**CTP-D-8.** Per-tool positive + negative test fixtures shipped alongside each wrapper. CTP's own CI runs them to catch detector quality regressions. Operator-supplied rule files must also ship fixtures for inclusion in the registry.

## 9b. The architectural-content enforcement bundle (NEW — clarifying section)

Every `.md` file the harness or its agents generate during the architectural design phase — ADRs, decision logs, C4 diagrams, sequence diagrams, traceability matrices, cost-benefit analyses, RFCs, design proposals, SUBMISSION docs, presentation outlines — gets the **full prose enforcement stack** applied at both write time and audit time. This is not implicit in the per-tool listing above; it's a named, first-class bundle the composite engine activates automatically whenever a file is classified as architectural content. The bundle's purpose is the user's explicit requirement: *nothing is written to the repo as architectural content that has not first been vetted against every applicable rule*.

### 9b.1 Defining "architectural content"

A file is classified as architectural content if it satisfies any of:

- **Path-pattern match** — file path matches `docs/architecture/**/*.md`, `docs/adr/**/*.md`, `docs/decisions/**/*.md`, `docs/rfcs/**/*.md`, `docs/design/**/*.md`, `SUBMISSION.md`, `**/c4-*.md`, `**/seq-*.md`, `**/traceability*.md`, `**/cost-benefit*.md`, `**/presentation*.md`
- **Frontmatter match** — file's YAML frontmatter declares `kind: adr | architecture | decision | design | rfc`
- **Operator extension** — operator-supplied paths in `.harness/operator-standards/architectural-paths.yaml` are added to the classifier

The classifier emits the boolean tag `is_architectural_content: true` on any matching file, which the routing logic uses to activate the bundle below.

### 9b.2 The bundle — every tool that fires on architectural content

The composite engine treats `bundle:architectural-content` as a named binding that maps to **all** of these tools, invoked in parallel on every architectural file:

| Layer | Tool | Role |
|---|---|---|
| **Template / structural** | `markdownlint-cli2` with custom config | MD001-MD060: heading hierarchy, single H1, code-fence languages declared, link-fragments resolve, no inline HTML where forbidden, no duplicate headings, etc. MD043 (`required-headings`) enforces MADR / arc42 template shape mechanically |
| **Template / structural** | `remark-lint` with `remark-preset-lint-recommended` + `remark-preset-lint-markdown-style-guide` | AST-based markdown lint complementing markdownlint where AST precision matters |
| **Prose style (Google)** | Vale + `errata-ai/Google` style pack | Active voice, sentence-case headings, present tense, inclusive language, Google developer-docs style guide |
| **Prose style (Microsoft)** | Vale + `vale-cli/Microsoft` style pack | Microsoft Writing Style Guide — bias-free communication, global communications, grammar, punctuation, formatting |
| **Prose style (general)** | Vale + `errata-ai/write-good` + `errata-ai/proselint` | Passive voice, weasel words, cliches, hedging, redundancy, typography, archaism, jargon, mixed metaphors |
| **Inclusive language** | Vale + `errata-ai/alex` (Vale wrapper) AND `alex` (standalone CLI) | Gendered language, ableist phrasing, intolerant terminology (master/slave → primary/replica), condescending words |
| **Additional prose** | `textlint` with `textlint-rule-no-todo` + `textlint-rule-common-misspellings` + `textlint-rule-max-number-of-lines` | Catches additional anti-patterns that Vale doesn't cover |
| **Spell-check** | `cspell` (code-aware) + `codespell` (dictionary) | Both — cspell is code-aware (skips identifiers, supports many config formats), codespell catches common typos against a curated misspellings dictionary |
| **Link integrity** | `lychee` | Internal + external link resolution, anchor fragment validation, dead-link detection |
| **License headers** | `reuse-tool` | REUSE 3.3 / SPDX header presence on every architectural doc, per FSFE spec |
| **Diagram validation** | `mmdc --validate` (mermaid-cli) | Validate every `mermaid` fenced code block in architectural docs (C4 diagrams, sequence diagrams, flowcharts) |
| **Diagram validation** | `plantuml -checkonly` | Same for PlantUML diagrams if present |
| **Frontmatter schema** | `ajv-cli` against MADR / arc42 / RFC frontmatter schemas | Validate frontmatter shape — required fields (status, kind, date, deciders), enumerated values (status ∈ {proposed, accepted, rejected, deprecated, superseded}), field types |
| **Token-pattern checks** | Semgrep with generic-mode rules under `composite/rulesets/semgrep/architectural-content/*.yml` | Catches literal forbidden tokens in prose (e.g., `0.0.0.0/0`, `alg":"none"`, `*:*` for IAM) AND the deny-context affordance markers that distinguish "forbid X" from "propose X" |
| **RFC 2119 keyword discipline** | Custom Vale rule or Semgrep pattern | When uppercase MUST / SHOULD / MAY appear in the prose, the BCP 14 invocation sentence must be present elsewhere in the doc |
| **Semantic (the moat)** | **`prose-judge.sh`** | The LLM-judge tier — semantic projection of every rule with `applies_to_prose: true` onto the architectural prose. Catches the "this ADR proposes a forbidden design" class that no other tool can catch |
| **Citation integrity** | `audit-source-citations.sh` (existing GCTP script) | Every claim in an ADR that cites a standard or rule must trace to a real entry in `active.json`'s provenance |
| **ADR lifecycle** | `adr-tools` (Nat Pryce, MIT) + `log4brains` (Apache-2.0) + `adr-log` (Apache-2.0) + `adr-manager` (Apache-2.0) | Validate ADR file-naming convention (`NNNN-kebab-title.md`), monotonic numbering with no gaps, status transitions (proposed → accepted → deprecated → superseded), supersession chains resolve, and that each ADR has a corresponding entry in the ADR log/index |
| **TOC integrity** | `doctoc` + `markdown-toc` + `markdown-it-toc-done-right` | Auto-generated and verified table-of-contents for ADRs that span multiple sections; fails if the rendered TOC drifts from the heading structure |
| **Additional prose CLIs** | `write-good` (MIT, standalone) + `mdformat` (Python, MIT) + `vale-ls` (Vale language server for IDE integration) | Belt-and-braces prose checks beyond the Vale packs; consistent MD formatting; IDE-time feedback for authors |
| **Link checker (alt)** | `markdown-link-check` (MIT) | Lychee's complement — different traversal strategy catches different edge cases (relative path resolution + anchor parsing) |
| **Commit message hygiene** | `commitlint` + `@commitlint/config-conventional` | Conventional Commits enforcement on the commit that lands an ADR; ties ADR ID → commit → PR for traceability |
| **Inline-table validation** | `markdown-table-formatter` + `prettier --parser markdown` | Renders the ADR's tables consistently; catches malformed pipe alignment that breaks rendering on GitHub vs editor |
| **Style for kata/competition deliverables** | `gh markdown-render` + `markdownlint-cli2 --fix` dry-run | Renders the ADR exactly as GitHub/GitLab will see it so author can detect drift before commit |

### 9b.3 Schema: how rules reference the bundle

A rule entry can target architectural content explicitly in either of two equivalent ways:

```yaml
# Explicit bundle binding — operator says "fire the architectural-content bundle on this rule"
- id: g-madr-template-conformance
  source_namespace: madr
  origin: plugin
  applies_to:
    is_architectural_content: true
  enforced_by:
    - bundle: architectural-content      # ← named bundle reference; expands to ALL tools in §9b.2
  severity: P1
  applies_to_prose: true

# Implicit bundle activation — any rule with applies_to_prose: true auto-attaches the bundle
- id: g-aws-no-unrestricted-ingress
  applies_to:
    linguist_aliases: [terraform]        # primary target = .tf files
  applies_to_prose: true                 # ← auto-activates architectural-content bundle as secondary binding
  enforced_by:
    - kinds: { linguist_aliases: [terraform] }
      tool: checkov
      ruleset: ".../aws-no-ingress.yaml"
    # bundle: architectural-content is appended automatically by the engine because applies_to_prose: true
  severity: P0
```

The expansion of `bundle: architectural-content` is canonical and central: every tool listed in §9b.2 fires on every architectural file matched by the rule's `applies_to_prose_kinds`. Operators don't pick and choose; the bundle is whole-or-nothing so the architectural enforcement floor is uniform across all rules and all source-namespaces.

### 9b.4 Write-time hook wiring

`.claude/hooks/post-tool-use-review-gate.sh` (existing CL-E) extends its file-extension case statement: when a `.md` file is written, the hook additionally checks the classifier's `is_architectural_content` flag (via `scripts/classify-file.sh --file <path>` → returns `architectural | non-architectural`). If architectural, the hook invokes the architectural-content bundle in parallel and aggregates SARIF before exit. The PreToolUse variant (CTP-D-5 from §9) does the same on proposed content before disk write. Net result: **no architectural .md file lands in the repo without every tool in §9b.2 having vetted it.**

### 9b.5 Audit-chain wiring

`scripts/audit-design-phase-md.sh` (existing CL-C) drives the same bundle at dispatch time across the whole `app_root`'s architectural surface. For every ticket whose `file_scope.may_edit` touches an architectural path (or any file with the `is_architectural_content` flag), the gate runs the full bundle, aggregates SARIF via `sarif-aggregate.sh`, treats deviation rows in `<app_root>/docs/deviations.md` as `deviated`-as-green per ADR-0066 D-F, and blocks `/dispatch` from emitting if any P0 fires without a deviation. Same bundle, same tools, same SARIF output bus — the only difference vs write-time is scope (whole tree vs single file).

### 9b.6 The contract — what this guarantees operationally

After the bundle lands and is wired:

1. **Every architectural .md file passes the full structural + style + spell + link + diagram + frontmatter + semantic stack before commit.** Single-tool-omission is structurally impossible because the bundle is referenced by name.
2. **Every rule with `applies_to_prose: true` automatically applies to all architectural files** without per-rule manual binding. The bundle is the universal floor for prose-as-code.
3. **The semantic moat fires on every ADR.** Any rule from any source — Google, Microsoft, OWASP, Walmart, Accenture — that's marked `applies_to_prose: true` gets `prose-judge.sh` evaluation against every ADR's prose, in addition to the deterministic FOSS tools.
4. **The 5 (or 6, with `is_architectural_content`) classification axes** still drive routing: a rule scoped to TypeScript prose ALSO targets `.ts` files via Semgrep/ESLint; the architectural-content bundle is the additional dimension, not a replacement.

This section closes the gap that PROPOSAL-005 §6 implied but didn't name: the full prose tool stack is now a named, first-class enforcement target activated automatically on architectural content, satisfying the operator's requirement that *every rule applies to every generated architectural artifact through every tool that can enforce it*.

## 10. Alternatives considered

- **Keep CTP-hand-written grep detectors as primary; use FOSS tools only as fallback.** REJECTED — produces the low-confidence verdict landscape PROPOSAL-004 documents. FOSS tools are deeper, faster, and more accurate at the domains they cover.
- **Single mega-tool (Semgrep alone, or CodeQL alone).** REJECTED — no single tool covers every kind. Semgrep is the closest but doesn't deeply cover IaC (Checkov is better), k8s (Kubescape is better), Markdown (markdownlint is better), OpenAPI (Spectral is better). Composition is the right move.
- **Hide the 4-axis vocabulary behind a CTP-invented abstraction.** REJECTED — the ecosystem has already standardized; re-naming creates the 15th competing taxonomy. The right play is to adopt + mirror.
- **PostToolUse only; skip PreToolUse.** REJECTED for operators who want strict "never on disk" enforcement; supported as the pragmatic default but PreToolUse is the addition for strict mode.

## 11. Verification

Per landing wave:
- **Wave 1:** ship mirrors + `applies_to.*` schema + `enforced_by[]` schema + `scripts/kinds.sh validate`. CTP suite green; backward-compatible with existing rules.
- **Wave 2:** ship the ~30 tool wrappers + `scripts/install-composite.sh`. Smoke test on the harness's own audit + the kata audit; expect coverage parity with the prior CTP-detector-based audit.
- **Wave 3:** ship the PreToolUse hook variant; per-detector test fixtures; SARIF self-conformance.
- **Wave 4:** deprecate the old per-rule `detector:` field; migrate every rule in active.json to the new schema.

## 12. Boundary discipline

**CTP owns** (this brief): the 4-axis mirrors, the rule schema extensions, the tool wrappers, the install bootstrap, the hook variants, the per-detector test fixtures.

**Consumer (GCTP) owns** (NOT this brief): pin bump to adopt; operator-side configuration of `.harness/operator-standards/`; the existing audit chain consumption.

Neither side touches the other's repo. Same contract surface as PROPOSAL-003.

## 13. Pairs with PROPOSAL-006

The auto-classification + custom-rule drafting pipeline (PROPOSAL-006) provides the upstream — it scrapes URLs, tags rules with `applies_to.*`, and drafts custom-rule files in the right tool's DSL. PROPOSAL-005 (this brief) provides the runtime — it routes the tagged rules to the right tool. Both compose on the same canonical vocabulary; both reuse PROPOSAL-003's source-refresh mechanism; both target the same `active.json` rule registry.

---

End of brief. Land as CTP-ADR-NNNN. Wave-by-wave landing; final state converges to ≥90% high-confidence verdict landscape across all enforced rules, write-time + audit-time symmetry, deterministic enforcement for FOSS-DSL-expressible rules + LLM-judge tier for semantic prose, zero CTP-invented vocabulary.
