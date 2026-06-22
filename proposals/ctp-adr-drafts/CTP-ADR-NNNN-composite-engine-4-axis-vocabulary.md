# CTP-ADR-NNNN — Composite engine + 4-axis canonical vocabulary + architectural-content enforcement bundle

> **Audience:** the `claude-tdd-pro` (CTP) development session.
> **Source design:** `proposals/PROPOSAL-005-composite-engine-4-axis-vocabulary.md` (GCTP repo, drumfiend21/grok-claude-tdd-pro@main, commit `5284156`).
> **Authority:** TIER-1 architectural change for CTP. Land as a new CTP ADR (next available number).
> **Date proposed:** 2026-06-22.

- **Status:** Proposed
- **Deciders:** drumfiend21 (architect — multi-turn operator directives, June 2026: *"replace handwritten detectors with FOSS tools"* → *"adopt an industry-standard naming registry rather than inventing one"* → *"ensure all rulesets are enforced on the generated architectural content"*) + CTP dev session.
- **Pairs with:** **GCTP PROPOSAL-005 §9b** (architectural-content enforcement bundle) and **CTP-ADR-NNNN+1** (auto-classification + custom-rule drafting pipeline — separate ADR derived from `proposals/PROPOSAL-006-...`).
- **Composes on:** CTP-side prose-judge.sh + applies_to_prose flag + 22 new namespaces + SARIF emission (CTP-ADR adopted at pin `39903da` for PROPOSAL-003).
- **Depends on:** P-8 fix (prose-judge.sh tier-2 `--text` ↔ `--target` contract mismatch — see `docs/upstream-ctp-proposals.md` in GCTP repo) for the architectural-content bundle's semantic moat to be functional.

---

## Context

CTP today owns the **rule content** for the composite engine the GCTP harness consumes. After PROPOSAL-003 landed at pin `39903da`, CTP exposes 118 rules across 24 namespaces with prose-judge LLM-tier semantic projection. The detectors backing those rules are CTP-handwritten grep / awk / shell heuristics, with the following standing limitations:

1. **Brittleness.** Hand-rolled grep on TypeScript / Terraform / Kubernetes manifests produces false positives + false negatives that mature FOSS tools (Semgrep, ESLint, Checkov, Kubescape, Trivy, Spectral, hadolint, zizmor, markdownlint, Vale) handle through proper AST/IR parsing.
2. **Coverage debt.** Many file types in real operator codebases (`.yml` workflows, `.json` SBOMs, `.md` ADRs, container images, helm charts) have thin or no detector coverage because hand-rolling each one is unbounded effort.
3. **No canonical rule-to-tool join vocabulary.** Rules from arbitrary sources (Google, Microsoft, OWASP, federal/EO, Accenture, Walmart, internal wikis) need to bind to the right tool, but there is no shared key — every CTP rule today carries its own ad-hoc `language: typescript` / `language: terraform` field, with no provenance into an industry-standard registry.
4. **No first-class enforcement on architectural prose.** ADRs, design docs, RFCs, architecture notes are the primary artifact of the GCTP↔CTP consult loop (ADR-0056 in GCTP), yet the existing detectors don't fire on them. The operator's standing directive is that **nothing is written to disk — including architectural content — without first being vetted against every applicable rule by every applicable tool.**

Industry-standard naming registries already exist and are battle-tested by mature tooling — CTP must adopt them rather than invent its own. The composite engine must be **extensible to any standard from any source** (operator brings a URL → it becomes enforcement, automatically). The architectural-content enforcement story must be **first-class, not a footnote** — every ADR passes the full prose tool stack before commit.

---

## Decision

Eight numbered decisions (D-1..D-8) implementing the composite engine, the 4-axis vocabulary, and the architectural-content enforcement bundle. Each defines a contract or component. Implementation is itemized in §"Implementation CLs".

### D-1. Adopt the four industry-standard authorities as the canonical rule-binding vocabulary.

CTP MUST NOT invent a CTP-native kind vocabulary. The four authorities mirrored into CTP at session start:

| Axis | Authority | Canonical form | License |
|---|---|---|---|
| Languages | **GitHub Linguist** (`github/linguist/lib/linguist/languages.yml`) | `aliases[0]` (lowercase) — e.g. `typescript`, `python`, `rust`, ~700 entries | MIT |
| IaC dialects | **IaC-scanner consensus** (Checkov + Trivy + Kubescape) | lowercase: `kubernetes`, `terraform`, `dockerfile`, `openapi`, `helm`, `github_actions`, `cloudformation`, `compose`, etc. | Apache 2.0 |
| Package ecosystems / uses | **PURL spec** (`package-url/purl-spec`) | `pkg:<ecosystem>/<name>` — e.g. `pkg:npm/react`, `pkg:pypi/django`, `pkg:cargo/tokio`. Used by SBOM/SCA tools | MIT |
| Kubernetes object kinds | **Kubernetes Group/Version/Kind** | `apps/v1/Deployment`, `rbac.authorization.k8s.io/v1/Role` | Apache 2.0 |

Mirror the four registries at session start under `vendor/canonical-vocabulary/` (read-only snapshots). Refresh cadence matches `standards-refresh.sh` (default 1d).

### D-2. Adopt the `applies_to.*` block as the rule's binding surface.

Every rule in `active.json` carries an `applies_to` block keyed by the four axes:

```yaml
- id: g-jwt-no-none-alg
  source: rfc-8725
  cite: "RFC 8725 §3.1 — algorithm 'none' MUST NOT be accepted"
  applies_to:
    linguist_aliases: [typescript, javascript, python, go, java, rust]
    iac_dialects: []
    purl_uses: [pkg:npm/jsonwebtoken, pkg:npm/jose, pkg:pypi/pyjwt]
    k8s_gvks: []
  applies_to_prose: true
  enforced_by:
    - tool: semgrep
      ruleset: composite/rulesets/semgrep/jwt-no-none-alg.yml
    - bundle: architectural-content  # auto-attached because applies_to_prose: true
```

The 4-axis tagging is the single join key between rules and tools. The existing `language: typescript` ad-hoc field is deprecated; migration is automatic via the auto-classifier (CTP-ADR-NNNN+1).

### D-3. Adopt SARIF 2.1.0 as the universal output bus.

Every FOSS tool the engine invokes either emits SARIF natively (Semgrep, ESLint, Checkov, Kubescape, Trivy, Spectral, hadolint, zizmor, markdownlint-cli2, Vale) or has a SARIF adapter (`<tool>-to-sarif.sh` thin wrappers under `composite/adapters/`). The engine aggregates SARIF results across tools via `sarif-aggregate.sh` (already shipped in GCTP CL-B) and consumes a single normalized verdict stream.

### D-4. Ship `composite/runners/<tool>/runner.sh` per-tool runner with the ordered binding contract.

Each FOSS tool gets a runner script that (a) accepts a file path + applicable rule list, (b) invokes the tool with the rule set, (c) emits SARIF, (d) returns deterministic exit codes. First-matching-binding-wins per file — the engine walks `enforced_by[]` in order and dispatches the first tool whose `applies_to` matches the file's detected kind set. The match-then-dispatch loop lives in `composite/dispatch.sh`.

### D-5. **Architectural-content enforcement bundle** (PROPOSAL-005 §9b). 

Ship `composite/bundles/architectural-content.yaml` defining a named binding that expands to the full prose tool stack invoked on every architectural file:

| Concern | Tool | Coverage |
|---|---|---|
| Markdown syntactic | `markdownlint-cli2` (MIT) | CommonMark / GFM / MD001..MD060 |
| AST-level prose checks | `remark-lint` (MIT) | heading consistency, link integrity, table shape |
| Prose style — corporate | Vale (MIT) + Google / Microsoft / write-good / proselint / alex packs | tone, passive voice, jargon, inclusivity |
| Spelling | `cspell` + `codespell` (MIT) | code-aware spelling |
| Link integrity | `lychee` (Apache 2.0) | dead-link detection |
| License headers | `reuse-tool` (REUSE 3.3) | SPDX compliance |
| Diagram rendering | `mmdc` (Mermaid CLI) + `plantuml` | diagram-as-code validation |
| Frontmatter schema | `ajv-cli` against `composite/schemas/adr-frontmatter.schema.json` | required fields, enum values |
| Token patterns in prose | Semgrep generic-mode rules under `composite/rulesets/semgrep/architectural-content/*.yml` | literal forbidden tokens (`0.0.0.0/0`, `alg":"none"`, `*:*` IAM) with deny-context affordance markers |
| RFC 2119 keyword discipline | Custom shell check `composite/runners/rfc-2119-check/runner.sh` | MUST / SHOULD / MAY usage consistency |
| **Semantic moat** | **`prose-judge.sh`** (CTP-owned, semantic projection of every `applies_to_prose: true` rule onto the prose) | catches "this ADR proposes a forbidden design" — no FOSS equivalent |
| Citation integrity | `audit-source-citations.sh` (CTP-owned) | verifies cited URLs resolve + match anchor |

The bundle is **whole-or-nothing**. Operators don't pick and choose tools — the bundle is the universal architectural enforcement floor. Implicit activation: any rule with `applies_to_prose: true` auto-attaches `{ bundle: architectural-content }` to `enforced_by[]` at engine load time (no per-rule operator effort).

### D-6. Architectural-content detection.

`composite/detect-architectural-content.sh` returns `is_architectural_content: true` for a file when ANY of:

1. Path matches one of: `docs/architecture/**`, `docs/adr/**`, `docs/decisions/**`, `docs/rfc/**`, `**/SUBMISSION.md`, `**/ARCHITECTURE.md`, `**/DESIGN.md`, `**/README.md` for the root architecture readme.
2. Frontmatter contains `kind: adr | architecture | decision | design | rfc`.
3. Operator-declared per-repo extension in `.harness/operator-standards/architectural-content-paths.yaml`.

Engine invokes the architectural-content bundle on all matching files.

### D-7. Two-phase enforcement (write-time + audit-time).

The composite engine fires through two seams:

- **Write-time (post-tool-use):** the existing `post-tool-use-review-gate.sh` (GCTP CL-E, already shipped) extends to invoke `composite/dispatch.sh` for the touched file. For architectural .md, the architectural-content bundle fires.
- **Audit-time (whole-tree scope):** `enforce-standards.sh` (Fix B) extends to drive the composite engine across the entire app tree. `audit-design-phase-md.sh` (GCTP CL-C, already shipped) drives the bundle at whole-tree scope on every architectural file.

A future strict variant — PreToolUse hook — is deferred to CTP-D-7a (see §"Open questions" below) for the operator's "never on disk in violating form" guarantee.

### D-8. Three-wave delivery (CL-A..H).

Implementation is itemized in §"Implementation CLs". Three waves so the engine is incrementally adoptable:

- **Wave 1 (CL-A..C):** vocabulary mirror + 4-axis schema migration + SARIF bus. Existing detectors keep working; nothing regresses.
- **Wave 2 (CL-D..F):** per-tool runners (Semgrep, ESLint, Checkov, Kubescape, Trivy, Spectral, hadolint, zizmor) + dispatch loop. Hand-rolled detectors swapped one-by-one; per-CL coverage diff demonstrates parity.
- **Wave 3 (CL-G..H):** architectural-content bundle + detection + two-phase wiring. Depends on P-8 fix for semantic moat.

---

## Implementation CLs

| CL | Deliverable | Acceptance criteria |
|---|---|---|
| **CL-A** | `vendor/canonical-vocabulary/{linguist,iac-dialects,purl-spec,k8s-gvks}/` mirrors + refresh script | Mirrors present + refreshable; new namespace `vocabulary` added to `active.json` index |
| **CL-B** | `applies_to.*` schema migration in `active.json` builder; existing `language:` field auto-migrated | All 118 existing rules have `applies_to` blocks; no regression in audit verdicts |
| **CL-C** | `sarif-aggregate.sh` adoption + adapter scaffolding under `composite/adapters/` | All adapters emit SARIF 2.1.0; aggregator produces single verdict stream |
| **CL-D** | Per-tool runners: Semgrep, ESLint, Checkov, Kubescape, Trivy, Spectral, hadolint, zizmor + `composite/dispatch.sh` | Each runner accepts `--rules` + `--file` + emits SARIF; dispatch walks `enforced_by[]` in order |
| **CL-E** | Coverage-diff demonstrates parity for swapped detectors | Old detector → new tool: same verdicts on a curated fixture set (`composite/fixtures/parity/`) |
| **CL-F** | First operator-source ingest end-to-end: Google TS style guide URL → 47 rules in `active.json` with `applies_to.*` populated, bound to Semgrep + ESLint | E2E test in `test/composite/e2e/google-ts-style/` green |
| **CL-G** | `composite/bundles/architectural-content.yaml` + `composite/detect-architectural-content.sh` + bundle invocation in dispatch | Bundle fires on every architectural .md; SARIF aggregated; `prose-judge.sh` invoked per `applies_to_prose: true` rule |
| **CL-H** | Two-phase wiring: dispatch invoked from post-tool-use hook + audit-time driver | Both seams fire the same engine; identical verdicts on identical inputs |

---

## Consequences

### Positive

- **Detector quality.** FOSS tools (Semgrep, ESLint, Checkov, Kubescape, Trivy, Spectral, hadolint, zizmor) are battle-tested by the entire industry; they catch what hand-rolled grep misses and don't false-positive on the cases hand-rolled grep does.
- **Coverage.** Every file type that has a major FOSS tool gets first-class enforcement automatically. The current coverage gap (`.yaml` workflows, `.json` SBOMs, container images, helm charts) closes without per-type hand-rolling.
- **Extensibility.** Any operator-brought standard from any source becomes enforcement automatically through the auto-classification pipeline (CTP-ADR-NNNN+1). The catalog scales sublinearly with operator effort.
- **Canonical join vocabulary.** Adopting Linguist + IaC-dialects + PURL + GVK eliminates the rule-binding ambiguity. Cross-language rules (one rule covers 8 languages via Semgrep) become first-class.
- **Architectural content first-class.** Every ADR, design doc, RFC passes the full prose tool stack — markdownlint + Vale + textlint + cspell + codespell + lychee + reuse + diagrams + frontmatter + RFC 2119 + Semgrep + `prose-judge.sh` + citation integrity — before commit. Eliminates the historical gap where ADRs proposed designs that violated the very rules CTP enforces on code.
- **SARIF as bus** means future tooling (security dashboards, GitHub code-scanning, IDE integrations) gets a single normalized verdict feed.

### Neutral

- The plugin grows a `vendor/canonical-vocabulary/` directory (~10-20 MB of mirrored YAML + JSON). Refresh on cadence; no runtime cost.
- Per-tool runners are thin shell wrappers; total LOC added is bounded (~150 LOC per runner × 8 runners = ~1200 LOC core).
- The architectural-content bundle invokes ~16 tools per .md. On a 33-file architecture corpus, wall-clock is bounded by the slowest tool (typically Vale or prose-judge.sh) — observed under 90s in GCTP CL-C audit runs.

### Negative / cost

- **External tool dependency.** Operators must have Semgrep, ESLint, Checkov, etc. installed. Mitigation: containerized runner under `composite/docker/` for hermetic execution.
- **prose-judge.sh blocker (P-8).** The semantic moat is the highest-leverage component of the architectural-content bundle. The existing `--text` ↔ `--target` contract mismatch means tier-2 returns `not_enforced` until fixed. This ADR depends on the P-8 fix landing first.
- **Migration of existing 118 rules** to `applies_to.*` is mechanical but must be verified per-rule for no regression. Mitigation: CL-E coverage diff is the gate.
- **prose tool DSL drift.** Vale styles + markdownlint config + remark plugins evolve. Mitigation: pin versions in `composite/bundles/architectural-content.yaml`, refresh on cadence with explicit operator review.

---

## Alternatives considered

- **Keep hand-rolled detectors; just add more.** REJECTED — does not scale; coverage gap grows with new file types; no canonical join vocabulary; architectural-content stays unenforced.
- **Invent a CTP-native canonical naming registry.** REJECTED — duplicates work already done by Linguist + IaC consensus + PURL + GVK; would diverge from industry tooling; operator pushback explicitly forbade.
- **Per-tool wrappers with no bus.** REJECTED — engine cannot aggregate verdicts across tools; ADR-spec quality gate cannot say "all tools must pass" without a normalized stream.
- **Architectural-content enforcement as opt-in per rule.** REJECTED — operator's standing directive is that the bundle fires on every ADR; opt-in invites per-rule oversights. The bundle is the universal floor.

---

## Open questions

- **CTP-D-7a (strict write-time enforcement):** a PreToolUse variant that blocks the Write tool BEFORE the file is on disk when the composite engine returns `red`. Today the post-tool-use hook fires after the write; this is "soft" enforcement. Tracked as a future ADR.
- **Composite engine version skew:** when an operator's pin lags behind CTP's current tool-runner contracts, what's the graceful degradation? Initial answer: per-runner version check in `dispatch.sh`; if a runner is missing, the rule is marked `not_enforced` rather than failing the run. To be finalized in CL-D.
- **Auto-classification handoff:** the next ADR (CTP-ADR-NNNN+1, derived from `proposals/PROPOSAL-006-...`) feeds rules into `active.json` with `applies_to.*` + `applies_to_prose` populated automatically. This ADR consumes that output; CTP-ADR-NNNN+1 produces it.

---

## Boundary discipline (per prime directive)

- **CTP owns** (this ADR): the composite engine runtime, the per-tool runners, the SARIF bus, the architectural-content bundle definition, the canonical vocabulary mirrors.
- **GCTP owns** (separate, paired ADR): the harness-side wiring — `enforce-standards.sh` invocation, `audit-design-phase-md.sh` invocation, the post-tool-use hook extension, the static gate alignment, operator-facing CLI workflow.
- **Operator owns**: the source URLs that feed the catalog, the per-rule deviation approval, the operator-extension paths for architectural-content detection.

Neither side reaches into the other. The only contract surface is `active.json` + the canonical vocabulary mirrors + SARIF.

---

End of CTP-ADR-NNNN draft. Land in `claude-tdd-pro/docs/adr/` at the next available number; close `proposals/PROPOSAL-005-composite-engine-4-axis-vocabulary.md` as adopted on landing.
