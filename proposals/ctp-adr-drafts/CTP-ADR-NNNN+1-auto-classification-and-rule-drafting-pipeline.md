# CTP-ADR-NNNN+1 — Auto-classification + custom-rule drafting pipeline

> **Audience:** the `claude-tdd-pro` (CTP) development session.
> **Source design:** `proposals/PROPOSAL-006-auto-classification-and-rule-drafting-pipeline.md` (GCTP repo, drumfiend21/grok-claude-tdd-pro@main, commit `5284156`).
> **Authority:** TIER-1 process change for CTP. Land as a new CTP ADR (next available number, paired with CTP-ADR-NNNN).
> **Date proposed:** 2026-06-22.

- **Status:** Proposed
- **Deciders:** drumfiend21 (architect — multi-turn operator directives, June 2026: *"every URL I bring becomes enforcement automatically"* → *"the LLM writes the custom rule one-to-one with the original prose, no language silently dropped"* → *"ensure rulesets are enforced on the generated architectural content"*) + CTP dev session.
- **Pairs with:** **CTP-ADR-NNNN** (composite engine + 4-axis vocabulary + architectural-content bundle — separate ADR derived from `proposals/PROPOSAL-005-...`). This ADR consumes that ADR's runtime; it doesn't replace it.
- **Composes on:** CTP-side prose-judge.sh + source refresh + applies_to_prose flag (PROPOSAL-003, adopted at pin `39903da`).
- **Depends on:** P-8 fix (prose-judge.sh tier-2 `--text` ↔ `--target` contract mismatch — see `docs/upstream-ctp-proposals.md` in GCTP repo) for the coverage-gap fallback (Stage 5D) to be functional.

---

## Context

After CTP-ADR-NNNN lands the composite engine + 4-axis vocabulary + architectural-content bundle, the engine is **runtime-ready** but **catalog-empty** beyond the seeded 118 rules. Operators want to bring standards from arbitrary world-class engineering organizations — Google, Microsoft, OWASP, federal/EO, Accenture, Walmart, NASA, internal wikis. Each source is a URL that scrapes to a blob of text containing N rules.

For the catalog to scale, every rule must be:

1. **Extracted** — segmented from the source blob into discrete entries (title + body + citation anchor).
2. **Classified** — tagged with the 4-axis canonical vocabulary (per CTP-ADR-NNNN D-1): `applies_to.{linguist_aliases, iac_dialects, purl_uses, k8s_gvks}` + `applies_to_prose`.
3. **Routed** — mapped to the right FOSS tool(s) via a kind→tool routing table. When `applies_to_prose: true`, auto-attach `{ bundle: architectural-content }`.
4. **Drafted** — translated from natural-language prose into the chosen tool's DSL (Semgrep YAML, ESLint plugin, Rego policy, Vale directive, etc.) by LLM-assisted authoring with explicit fidelity discipline.
5. **Reviewed** — operator confirms before commit.
6. **Committed** — lands in `.harness/operator-standards/custom-rules/<tool>/<rule-id>.<ext>` and `active.json`.

Today every step is manual. With the typical operator adopting ~500-1000 rules across Google + Microsoft + OWASP + federal + internal sources, manual is multi-month effort. This ADR proposes the automated pipeline.

**The "no language silently dropped" contract** is the architecturally novel piece. When the LLM drafts a Semgrep rule from a Google style guide entry, every clause of the original prose must end up either (a) deterministically enforced in Semgrep's DSL, (b) semantically enforced via `prose-judge.sh`, or (c) explicitly flagged as un-enforceable with operator acknowledgment. **Never silently dropped.** The four-layer fidelity discipline (prompt + coverage diff + fixtures + prose-judge fallback) operationalizes this contract.

---

## Architecture diagrams

### Auto-classification pipeline — URL to enforcement in 6 stages

```mermaid
flowchart TD
  URL["Operator URL<br/>(Google TS guide, OWASP ASVS,<br/>Walmart microservices doc, etc.)"] -->|Stage 1| S1["standards-refresh.sh<br/>scrape + cache"]
  S1 -->|raw text| S2["Stage 2: extract-rules-from-url.sh<br/>segment per doc shape"]
  S2 -->|"list of {title, body, anchor}"| S3["Stage 3: classify-rule.sh<br/>tier-1 deterministic + tier-2 LLM"]
  S3 -->|"applies_to.* + applies_to_prose"| S4[Stage 4: routing-table lookup]
  S4 --> AB{applies_to_prose?}
  AB -->|yes| AUTO["Auto-append<br/>bundle: architectural-content"]
  AB -->|no| LANG[Per-language binding only]
  AUTO --> S5["Stage 5: draft-custom-rule.sh<br/>(4-layer fidelity discipline)"]
  LANG --> S5
  S5 -->|drafted DSL + coverage report + fixtures| S6[Stage 6: review-queue.sh]
  S6 -->|operator approves| AJ[(active.json +<br/>custom-rules/&lt;tool&gt;/)]
```

### Auto-binding decision tree

```mermaid
flowchart TD
  R[Drafted rule] --> Q1{applies_to_prose: true?}
  Q1 -->|no| BIND_LANG["enforced_by:<br/>per-language tool<br/>(semgrep / eslint / checkov)"]
  Q1 -->|yes| Q2{any per-language kinds detected?}
  Q2 -->|yes — cross-applicability| BIND_BOTH["enforced_by:<br/>1. per-language tool<br/>2. bundle: architectural-content"]
  Q2 -->|no — ADR-only rule| BIND_BUNDLE["enforced_by:<br/>{ bundle: architectural-content }<br/>ONLY"]
  BIND_LANG --> AJ[(active.json)]
  BIND_BOTH --> AJ
  BIND_BUNDLE --> AJ
```

### Four-layer fidelity discipline — no language silently dropped

```mermaid
flowchart TD
  P["Original prose<br/>(e.g., RFC 8725 §3.1)"] --> L1["Layer A: prompt discipline<br/>'translate every clause; emit coverage_gap<br/>for un-translatable clauses'"]
  L1 --> DSL[Drafted DSL<br/>e.g., Semgrep rule YAML]
  DSL --> L2["Layer B: round-trip coverage diff<br/>LLM re-reads prose + DSL,<br/>emits per-clause coverage report"]
  L2 --> CR["Coverage report<br/>clause 1: covered by DSL line 15<br/>clause 2: NOT COVERED, reason: X<br/>clause 3: covered by DSL line 22"]
  CR --> L3[Layer C: test-fixture generation<br/>positive + negative fixtures<br/>verify DSL ≡ prose intent]
  L3 --> L4{any clause uncovered?}
  L4 -->|yes| LD[Layer D: bind clause to prose-judge.sh<br/>second enforced_by entry]
  L4 -->|no| DONE[Single deterministic binding]
  LD --> DONE2["Dual binding:<br/>1. Semgrep for syntactic clauses<br/>2. prose-judge.sh for semantic clauses"]
  DONE --> AJ[(active.json)]
  DONE2 --> AJ
```

### Review-queue confidence routing

```mermaid
flowchart TD
  DR[Drafted rule + coverage report] --> C{confidence?}
  C -->|high + 0 gaps| AUTO[Auto-stage for batched commit<br/>--batch-accept --confidence high]
  C -->|high + gaps| REV1[Operator reviews coverage split:<br/>deterministic + prose-judge fallback]
  C -->|medium / low| REV2[Individual review:<br/>prose + draft side-by-side]
  C -->|abstain| MAN[Manual authoring<br/>LLM provides scaffolding only]
  AUTO --> CMT[Commit to active.json + custom-rules/]
  REV1 -->|accept| CMT
  REV2 -->|accept| CMT
  MAN --> CMT
  REV1 -->|reject| DROP[Dropped — re-run or manual]
  REV2 -->|reject| DROP
```

---

## Decision

Eight numbered decisions (D-1..D-8) implementing the six-stage pipeline + the fidelity discipline + the architectural-content auto-binding. Each defines a component or contract. Implementation is itemized in §"Implementation waves".

### D-1. Ship `scripts/extract-rules-from-url.sh` for Stage 2 (rule extraction).

Per source-doc shape:

| Doc shape | Extraction strategy |
|---|---|
| Markdown with hierarchical headings | Parse heading levels; each `H2`/`H3` becomes one rule; body = content between heading and next sibling |
| HTML doc with `<section>` / structured pages | DOM walk + heading-level segmentation |
| OWASP-style numbered lists | Regex split on `^\d+\.` or `^[A-Z]\d+:` patterns |
| Free-form prose (blog post / policy doc) | LLM segmentation — pass full doc + prompt "extract individual normative rules; return JSON array of `{title, body, citation_anchor}`" |
| PDF | `pdftotext` → free-form prose → LLM segmentation |

Output: uniform shape `{rule_index, title, body, source_anchor}` regardless of input format. CTP ships extractors for the top 4-5 doc shapes; operator can plug in custom extractors under `composite/extractors/`.

### D-2. Ship `scripts/classify-rule.sh` for Stage 3 (4-axis classification).

**Tier 1 (deterministic, milliseconds).** Build an inverted index from the 4 canonical vocabulary mirrors (per CTP-ADR-NNNN D-1) at session start: `{word → set of (axis, canonical_id)}`. ~5,000-10,000 entries because each canonical ID is paired with common variants (TypeScript / typescript / TS / ts all point to the same Linguist entry). For each extracted rule, tokenize the body, look up each token, aggregate the axis-identifier set with multiplicity weighting.

**Tier 2 (LLM-judge, seconds per rule).** Pass `{rule_text, tier-1 candidate set, the 4 authority registries as enumerated options}` to the LLM judge with explicit anti-overreach discipline. Output is a confidence-tagged `applies_to` block. Low-confidence → review queue (Stage 6). High-confidence → auto-commit-after-review.

**Critical extension — `applies_to_prose` field.** Tier-2 LLM-judge ALSO emits `applies_to_prose: true | false`, derived from whether the rule's body expresses a constraint that can be projected semantically onto natural-language architectural prose. E.g.:

- *"JWT alg MUST NOT be `none`"* — applies to TypeScript code AND any ADR proposing a token design → `applies_to_prose: true`.
- *"Use 2-space indentation"* — applies only to code, not to ADRs → `applies_to_prose: false`.

**Caching.** Hash by `(rule_body_sha256, mirror_files_sha256)`. Re-judge only on change. Identical cost-control pattern to `prose-judge.sh`.

### D-3. Ship `composite/kind-to-tool-routing.yaml` for Stage 4 (routing).

Static ~50-entry routing table maps each canonical kind to recommended FOSS tools:

```yaml
routing:
  linguist:typescript:
    primary: [semgrep, eslint]
    secondary: [biome]
  linguist:python:
    primary: [semgrep, ruff, bandit]
  iac_dialects:kubernetes:
    primary: [kubescape, kube-linter]
    secondary: [checkov, kubeconform]
  iac_dialects:terraform:
    primary: [checkov, trivy]
    secondary: [tfsec, terrascan]
  # ... ~50 entries total
  # Plus one synthetic entry for the prose dimension:
  prose:architectural-content:
    primary: [bundle:architectural-content]
    notes: "Auto-attached when applies_to_prose: true. Fires the full PROPOSAL-005 §9b stack."
```

For each rule, given its `applies_to.*` set, look up each kind; intersect candidate tool sets; produce recommended primary tool(s). Cross-language rules (8+ `linguist_aliases`) almost always recommend Semgrep — the only tool that enforces one rule across many languages.

Refresh discipline: operator may extend; CTP curates the canonical table per CTP release.

### D-4. **Architectural-content auto-binding** (pairs with CTP-ADR-NNNN D-5).

When Stage 3 emits `applies_to_prose: true`, the Stage-4 router unconditionally appends `{ bundle: architectural-content }` to the rule's `enforced_by[]` list AFTER the per-language tool binding. The bundle expansion happens at engine load time (CTP-ADR-NNNN D-5 — the engine reads the bundle name and dispatches the full prose stack on every architectural .md). The drafter (Stage 5) does NOT enumerate the bundle tools individually.

**Inverted lookup for ADR-only rules.** When `applies_to_prose: true` AND the deterministic 4-axis tagging produces no per-language kinds (i.e., the rule is purely about architectural prose — RFC 2119 keyword usage, mandatory ADR sections, citation discipline, prose-style requirements), the router omits the per-language binding entirely and binds ONLY `{ bundle: architectural-content }`. The bundle is sufficient on its own for ADR-only rules.

The operator never has to manually attach the bundle. Every rule the classifier flags as projectable onto prose gets the full architectural enforcement stack automatically.

### D-5. Ship `scripts/draft-custom-rule.sh` for Stage 5 (LLM-draft DSL rule) with four-layer fidelity discipline.

**Layer A — Explicit fidelity discipline in the prompt:**

```
Translate this rule into <TOOL>'s rule DSL. You MUST:
1. Translate every clause, including exceptions, edge cases, conditional
   phrasing, and severity hedges (RFC 2119 MUST vs SHOULD vs MAY).
2. If a clause CANNOT be expressed in <TOOL>'s DSL, do NOT silently drop it.
   Instead, emit a `coverage_gap:` entry naming the clause and the reason.
3. Include cited source URL + page/section anchor in the rule metadata block.

RULE TEXT: <verbatim>
TARGET TOOL: <tool>
TARGET LANGUAGES: <linguist_aliases>
OUTPUT: <tool-specific DSL syntax with metadata + coverage_report>
```

**Layer B — Round-trip coverage diff:** After drafting, LLM reads both original prose AND drafted DSL, produces a coverage report — every prose clause mapped to "covered by DSL at line N" or "not covered, reason: X". Saved alongside rule body at `.harness/operator-standards/custom-rules/<tool>/<rule-id>.coverage.md`.

**Layer C — Test-fixture generation:** LLM generates positive (must-flag) and negative (must-not-flag) fixture files derived from the rule's prose. Run the drafted rule against fixtures; equivalence to prose intent demonstrated by both fixtures producing expected verdict. Saved in `.harness/operator-standards/custom-rules/<tool>/fixtures/<rule-id>/`.

**Layer D — Coverage-gap fallback to prose-judge:** Any clause flagged un-translatable to the tool's DSL is routed to a second `enforced_by` binding using `prose-judge.sh`. Rule's `enforced_by[]` ends up with two entries: one deterministic Semgrep/Checkov/etc. binding for syntactic clauses, one `prose-judge.sh` binding for semantic-judgment clauses. Operator sees the split explicitly in the coverage report.

**The "no language silently dropped" contract:** every clause of the original prose ends up either (a) deterministically enforced in the tool's DSL, (b) semantically enforced via `prose-judge.sh`, or (c) explicitly flagged as un-enforceable with operator acknowledgment.

### D-6. Drafting for architectural-prose rules.

When Stage 4 attaches `bundle: architectural-content` (i.e., `applies_to_prose: true`), the Stage-5 drafter generates ONLY:

1. **The `prose-judge.sh` binding metadata** — a structured directive for the LLM-judge tier containing rule's verbatim prose, rule ID, source citation, confidence threshold, deny-context affordance markers.
2. **Optional Semgrep generic-mode rule** — only when the rule contains literal forbidden tokens (`0.0.0.0/0`, `alg":"none"`, `*:*` IAM). Emit as `composite/rulesets/semgrep/architectural-content/<rule-id>.yml`; bundle picks it up automatically.
3. **Coverage report** against the bundle's combined capability — "Clause 1 covered deterministically by bundle's markdownlint MD025; clause 2 covered semantically by prose-judge.sh with rule body; clause 3 covered by bundle's Vale Microsoft rule write-good.E-Prime."

**Per-tool custom files for the bundle's structural tools (markdownlint, Vale, textlint, etc.) are NOT generated per rule.** The bundle's tools already enforce universal architectural-prose hygiene via default rule packs; per-rule custom Vale / markdownlint files would be redundant maintenance debt. One prose-judge directive per architectural-prose rule; bundle does the structural work.

**Cross-applicability rules.** When a rule applies to BOTH code and prose (typical case — e.g., JWT-none applies to TypeScript code AND ADRs proposing JWT designs), drafter emits TWO bindings: per-language DSL rule (Semgrep / ESLint / etc.) for code targets, AND prose-judge directive for ADR targets. Coverage report sums combined coverage.

### D-7. Ship `scripts/review-queue.sh` for Stage 6 (operator review).

For each drafted rule:

- **Confidence: high + coverage_gaps: 0** → auto-stage for batched commit (5-10 rules at once).
- **Confidence: high + coverage_gaps: >0** → operator reviews coverage report + prose-judge fallback binding; confirms split.
- **Confidence: medium / low** → individual review; operator reads prose + draft side-by-side; accepts, edits, or rejects.
- **Confidence: abstain** → manual authoring; LLM provides scaffolding only.

Review queue lives in `.harness/operator-standards/review-queue/`. CLI workflow:

```bash
scripts/classify-from-url.sh \
  --source-id walmart-microservices \
  --url https://walmart.example/standards/microservices.html

scripts/review-queue.sh --list                                  # show pending + confidence
scripts/review-queue.sh --review walmart-microservices-001      # open in editor
scripts/review-queue.sh --accept walmart-microservices-001
scripts/review-queue.sh --batch-accept --confidence high
```

On accept: rule committed to `active.json`, rule body to `.harness/operator-standards/custom-rules/<tool>/`, fixtures alongside.

### D-8. End-to-end driver + the "no language silently dropped" contract documentation.

Ship `scripts/classify-from-url.sh --source-id <id> --url <url>` — runs Stages 1-5 in sequence, populates review queue. Operator runs Stage 6 interactively.

Document the "no language silently dropped" contract prominently in `claude-tdd-pro/docs/composite-engine.md` §"Fidelity discipline". Every drafted rule MUST emit a coverage report; any prose clause not covered by deterministic binding MUST appear in a `prose-judge.sh` binding OR be flagged with explicit operator acknowledgment.

---

## Implementation waves

| Wave | Deliverable | Acceptance criteria |
|---|---|---|
| **Wave 1** | Stages 1-4: source-refresh adapter + `extract-rules-from-url.sh` + `classify-rule.sh` (with `applies_to_prose`) + `kind-to-tool-routing.yaml` + auto-binding logic | End-to-end: Google TS style guide URL → 47 rules in review-queue with populated `applies_to.*` + `applies_to_prose` + routed tool; OWASP ASVS URL → 286 rules with same |
| **Wave 2** | Stage 5: `draft-custom-rule.sh` with four-layer fidelity discipline + drafting-for-architectural-prose logic + coverage-diff generation + fixture generation | Per-rule: rule body + coverage report + positive/negative fixtures emitted; LLM token cost <$1/rule on typical inputs; bundle-auto-attach verified on `applies_to_prose: true` rules |
| **Wave 3** | Stage 6: `review-queue.sh` CLI + `classify-from-url.sh` end-to-end driver | Operator can ingest a URL → review queue → batch-accept → rules live in `active.json` + commits in `composite/rulesets/` and `.harness/operator-standards/custom-rules/`; scrape-to-enforced-rule cycle drops from days to hours |

---

## Consequences

### Positive

- **Catalog scaling.** Operators ingest world-class standards at LLM speed instead of manual-authoring speed. Typical adoption of ~500-1000 rules across Google + Microsoft + OWASP + federal + Accenture + Walmart + internal sources drops from multi-month to multi-week.
- **Provenance + audit-defensibility per rule.** Every rule arrives with provenance (source URL + anchor), coverage report (which clauses covered by which tool + which by prose-judge), and test fixtures (positive + negative). The catalog is audit-defensible — every clause traces to either a deterministic binding or an LLM-judge binding, with operator acknowledgment for un-enforceable clauses.
- **Architectural-prose enforcement at scale.** Every classifier-flagged prose-applicable rule (from any source) auto-attaches the architectural-content bundle without operator effort. The semantic moat (`prose-judge.sh`) fires on every ADR for every `applies_to_prose: true` rule. The operator's guarantee — "nothing is written to architectural files that has not been vetted against every applicable rule" — is now achievable at the catalog scale operators actually want.
- **The catalog grows naturally** with the operator's source set; no per-rule engineering effort beyond review-queue approval.

### Neutral

- LLM token cost bounded by hash cache + one-time-per-rule drafting cost. Estimated <$1 per rule drafted for typical inputs.
- Operator review is the human bottleneck; bulk-accept for high-confidence reduces it. Default is human-in-the-loop; opt-in `--auto-accept-high-confidence` flag for operators with high trust.

### Negative / cost

- **LLM dependency for Stages 3 + 5.** Mitigation: deterministic tier-1 handles ~60-70% of classifications; LLM tier handles only the residual. Hash cache eliminates re-drafting.
- **Quality of drafted DSL depends on LLM capability.** Mitigation: per-tool fixture-based equivalence test catches regressions; operator review catches semantic failures.
- **Depends on P-8 fix.** Stage 5D (coverage-gap fallback to prose-judge.sh) cannot land until the `--text` ↔ `--target` contract mismatch is fixed. Mitigation: Waves 1 + 3 can ship with Wave 2 deferred until P-8.

---

## Alternatives considered

- **Manual authoring of every rule.** REJECTED — catalog size makes this multi-month; doesn't scale with operator source set.
- **No fidelity verification — trust the LLM.** REJECTED — silent drops are the failure mode that breaks the "every rule enforced" contract. Four-layer fidelity mechanism is non-optional.
- **Single rule per LLM call.** ACCEPTED for Stages 3 + 5 — improves attribution + caching. Stage 2 segmentation is one LLM call per doc.
- **Skip operator review for high-confidence rules.** REJECTED for v1; opt-in via flag for high-trust operators. Default is human-in-the-loop.
- **Hand-attach architectural-content bundle per rule.** REJECTED — invites per-rule oversights; the auto-binding when `applies_to_prose: true` is the universal contract.

---

## Boundary discipline (per prime directive)

- **CTP owns** (this ADR): extraction strategies, classifier, routing table, DSL drafter, review-queue CLI, fidelity discipline, architectural-content auto-binding logic.
- **GCTP owns** (NOT this ADR): operator workflow + the audit chain's consumption of resulting rules + the GCTP-side post-tool-use + audit-time invocation of the composite engine.
- **Operator owns**: the source URLs to scrape, the per-rule accept/reject decision, the per-tool custom-rule files committed to `.harness/operator-standards/custom-rules/`.

---

---

## Supplementary GCTP files to fetch (the CTP session has no access to the GCTP repo, so fetch via raw URL)

GCTP repo: `https://github.com/drumfiend21/grok-claude-tdd-pro` — branch `main` at HEAD or any specific commit. Fetch the following with WebFetch / `curl` / `gh api`:

| Purpose | Raw URL (replace `main` with a pinned commit if reproducibility matters) |
|---|---|
| **The full source design** for this ADR | `https://raw.githubusercontent.com/drumfiend21/grok-claude-tdd-pro/main/proposals/PROPOSAL-006-auto-classification-and-rule-drafting-pipeline.md` |
| The paired composite-engine ADR draft (this ADR consumes its runtime) | `https://raw.githubusercontent.com/drumfiend21/grok-claude-tdd-pro/main/proposals/ctp-adr-drafts/CTP-ADR-NNNN-composite-engine-4-axis-vocabulary.md` |
| The composite-engine source design | `https://raw.githubusercontent.com/drumfiend21/grok-claude-tdd-pro/main/proposals/PROPOSAL-005-composite-engine-4-axis-vocabulary.md` |
| P-8 upstream blocker (prose-judge.sh `--text` ↔ `--target`) — needed for D-5 Layer D (coverage-gap fallback) | `https://raw.githubusercontent.com/drumfiend21/grok-claude-tdd-pro/main/docs/upstream-ctp-proposals.md` |
| Prior CTP-side ADR for PROPOSAL-003 (already adopted at pin `39903da`) — establishes the source refresh + prose-judge.sh surface this ADR composes on | `https://raw.githubusercontent.com/drumfiend21/grok-claude-tdd-pro/main/proposals/PROPOSAL-003-ctp-session-brief.md` |
| YAML / JSON / MD source corpora (worked examples of operator-sourced standards the pipeline will ingest) | `https://raw.githubusercontent.com/drumfiend21/grok-claude-tdd-pro/main/docs/standards-sources-yaml.md`, `.../standards-sources-json.md`, `.../standards-sources-md.md` |
| Complete-architecture cover doc (single entry point with all context) | `https://raw.githubusercontent.com/drumfiend21/grok-claude-tdd-pro/main/proposals/ctp-adr-drafts/COMPLETE-ARCHITECTURE-FOR-CTP.md` |

**Pinned-commit canonicalization (recommended):** swap `main` for commit `<HEAD-at-handoff>` in every URL above. The handoff cover doc records the canonical pin.

---

End of CTP-ADR-NNNN+1 draft. Land in `claude-tdd-pro/docs/adr/` at the next available number (paired with CTP-ADR-NNNN). On landing, close `proposals/PROPOSAL-006-auto-classification-and-rule-drafting-pipeline.md` as adopted, and pin-bump in GCTP to mark the auto-classification pipeline live.
