# CTP Work Brief — Auto-Classification + Custom-Rule Drafting Pipeline

**Audience:** the `claude-tdd-pro` (CTP) development session.
**Author:** GCTP cloud session, 2026-06-21.
**Authority:** TIER-1 process change for CTP. Land as a new ADR. Composes on PROPOSAL-003 (source refresh — adopted in CL-484..487), PROPOSAL-004 (P-8 fix — the prose-judge `--text` ↔ `--target` contract mismatch must land for this pipeline's LLM tier to be functional), and PROPOSAL-005 (composite engine + 4-axis vocabulary — provides the canonical IDs the classifier emits).

Self-contained brief.

---

## 1. The problem

Operators bring in standards from arbitrary world-class engineering organizations — Google, Microsoft, OWASP, Accenture, Walmart, NASA, internal wikis. Each source is a URL that scrapes to a blob of text containing N rules. For the catalog to be usable, every rule must be:

1. **Extracted** — segmented from the source blob into discrete entries (title + body + citation anchor).
2. **Classified** — tagged with the 4-axis canonical vocabulary (per PROPOSAL-005): `applies_to.linguist_aliases`, `applies_to.iac_dialects`, `applies_to.purl_uses`, `applies_to.k8s_gvks`.
3. **Routed** — mapped to the right FOSS tool(s) via a kind→tool routing table.
4. **Drafted** — translated from natural-language prose into the chosen tool's DSL (Semgrep YAML, ESLint plugin, Rego policy, Vale directive, etc.) by LLM-assisted authoring with explicit fidelity discipline.
5. **Reviewed** — operator confirms before commit.
6. **Committed** — lands in `.harness/operator-standards/custom-rules/<tool>/<rule-id>.<ext>` and `active.json`.

Today every step is manual. This brief proposes the automated pipeline.

## 2. The pipeline (six stages)

```
URL  →  STAGE 1: SOURCE-REFRESH        (existing — PROPOSAL-003)
                ↓ raw scraped text
       STAGE 2: RULE EXTRACTION         (NEW — per-doc-shape strategies)
                ↓ list of {title, body, citation_anchor}
       STAGE 3: 4-AXIS CLASSIFICATION   (NEW — deterministic + LLM-judge)
                ↓ applies_to.* block per rule
       STAGE 4: ROUTING-TABLE LOOKUP    (NEW — kinds → recommended tool)
                ↓ recommended enforced_by binding(s)
       STAGE 5: LLM-DRAFT DSL RULE      (NEW — fidelity-disciplined)
                ↓ tool-specific custom-rule file + coverage report + test fixtures
       STAGE 6: OPERATOR REVIEW         (NEW — review-queue workflow)
                ↓ approved → write to active.json + custom-rules dir
       
       active.json + .harness/operator-standards/custom-rules/<tool>/
```

Each stage is independently testable; deterministic where possible; LLM-tier where necessary; operator-gated at the end.

## 3. Stage 1 — source refresh (reuses PROPOSAL-003)

`scripts/standards-refresh.sh` already scrapes operator-declared source URLs on cadence and caches the raw text in `.harness/standards-cache/<source-id>.<ext>`. The pipeline starts from this cache. No new mechanism.

## 4. Stage 2 — rule extraction

Per source doc shape:

| Doc shape | Extraction strategy |
|---|---|
| Markdown with hierarchical headings | Parse heading levels; each `H2`/`H3` becomes one rule; body = content between heading and next sibling |
| HTML doc with `<section>` / structured pages | DOM walk + heading-level segmentation |
| OWASP-style numbered lists | Regex split on `^\d+\.` or `^[A-Z]\d+:` patterns |
| Free-form prose (blog post / policy doc) | LLM segmentation — pass full doc + prompt "extract individual normative rules; return JSON array of `{title, body, citation_anchor}`" |
| PDF | `pdftotext` → free-form prose → LLM segmentation |

Output: uniform shape `{rule_index, title, body, source_anchor}` regardless of input format. CTP ships extractors for the top 4-5 doc shapes; operator can plug in custom extractors.

## 5. Stage 3 — 4-axis classification (deterministic + LLM-judge)

**Tier 1 (deterministic, milliseconds).** CTP builds an inverted index from the 4 mirror files (Linguist + IaC-dialects + PURL + k8s GVKs) at session start: `{word → set of (axis, canonical_id)}`. ~5,000-10,000 entries because each canonical ID is paired with common variants (TypeScript / typescript / TS / ts all point to the same Linguist entry). For each extracted rule, tokenize the body, look up each token, aggregate the axis-identifier set with multiplicity weighting.

**Tier 2 (LLM-judge, seconds per rule).** Pass `{rule_text, tier-1 candidate set, the 4 authority registries as enumerated options}` to the LLM judge with explicit anti-overreach discipline:

```
Classify this rule against the four canonical content-kind registries.

RULE TEXT:
"""<rule body verbatim>"""

CANDIDATE KINDS (from deterministic keyword scan):
  linguist_aliases: <list>
  iac_dialects:    <list>
  purl_uses:       <list>
  k8s_gvks:        <list>

REGISTRY URLS for verification: <four authority URLs>

OUTPUT: minimal applies_to.* block — exactly the kinds where this rule is
APPLICABLE. Wildcards ("*") allowed only when truly universal. Exclude
candidates you're unsure about (false-positives are costly). For each
included kind, append one-line rationale.

confidence: high | medium | low | abstain
```

LLM output is a confidence-tagged `applies_to` block. Low-confidence → review queue (Stage 6). High-confidence → auto-commit-after-review.

**Caching.** Hash by `(rule_body_sha256, mirror_files_sha256)`. Re-judge only on change. Identical cost-control pattern to `prose-judge.sh`.

## 6. Stage 4 — routing-table lookup (kinds → recommended tools)

CTP ships a small static routing table (~50 entries):

```yaml
# composite/kind-to-tool-routing.yaml
routing:
  linguist:typescript:
    primary: [semgrep, eslint]
    secondary: [biome]
    notes: "Semgrep for cross-language patterns; ESLint for type-aware deep checks."
  linguist:python:
    primary: [semgrep, ruff, bandit]
    secondary: []
    notes: "Semgrep for patterns; ruff for style/structure; bandit for security."
  linguist:rust:
    primary: [clippy, semgrep]
    secondary: [cargo-audit]
  iac_dialects:kubernetes:
    primary: [kubescape, kube-linter]
    secondary: [checkov, kubeconform]
  iac_dialects:terraform:
    primary: [checkov, trivy]
    secondary: [tfsec, terrascan]
  iac_dialects:openapi:
    primary: [spectral]
    secondary: []
  iac_dialects:github_actions:
    primary: [zizmor, actionlint]
    secondary: [checkov]
  iac_dialects:dockerfile:
    primary: [hadolint, trivy]
    secondary: [checkov]
  purl:pkg:npm/react:
    primary: [eslint]            # with eslint-plugin-react
    secondary: [semgrep]
  # ... ~50 entries total
```

For each rule, given its `applies_to.*` set, look up each kind in the table; intersect the candidate tool sets; produce a recommended primary tool (or small list when multiple are equally good). Cross-language rules (a single rule with 8+ `linguist_aliases`) almost always recommend Semgrep because it's the only tool that enforces one rule definition across many languages.

## 7. Stage 5 — LLM-draft DSL rule (fidelity-disciplined)

For each rule + recommended tool, the LLM drafts the rule body in the tool's DSL with **four layered fidelity mechanisms** (the same four PROPOSAL-005 §10 requires):

**A. Explicit fidelity discipline in the prompt:**
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
TARGET FILE GLOBS: <derived from applies_to>
OUTPUT: <tool-specific DSL syntax with metadata + coverage_report>
```

**B. Round-trip coverage diff:** After drafting, LLM is asked to read both the original prose AND the drafted DSL and produce a coverage report — every prose clause mapped to "covered by DSL at line N" or "not covered, reason: X". Report saved alongside the rule body in `.harness/operator-standards/custom-rules/<tool>/<rule-id>.coverage.md`.

**C. Test-fixture generation:** LLM generates positive (must-flag) and negative (must-not-flag) fixture files derived from the rule's prose. Run the drafted rule against fixtures; equivalence to prose intent is demonstrated by both fixtures producing the expected verdict. Fixtures saved in `.harness/operator-standards/custom-rules/<tool>/fixtures/<rule-id>/`.

**D. Coverage-gap fallback to prose-judge:** Any clause that the coverage diff flags as un-translatable to the tool's DSL is routed to a second `enforced_by` binding using `prose-judge.sh`. The rule's `enforced_by[]` ends up with two entries: one deterministic Semgrep/Checkov/etc. binding for syntactic clauses, one `prose-judge.sh` binding for semantic-judgment clauses. The operator sees the split explicitly in the coverage report: *"5 of 7 clauses enforced deterministically by Semgrep; 2 clauses enforced semantically by prose-judge."*

**The "no language silently dropped" contract:** every clause of the original prose ends up either (a) deterministically enforced in the tool's DSL, (b) semantically enforced via `prose-judge.sh`, or (c) explicitly flagged as un-enforceable with operator acknowledgment. Never silently dropped.

## 8. Stage 6 — operator review queue

For each drafted rule:

- **Confidence: high + coverage_gaps: 0** → auto-stage for commit, operator confirms in a batched review (5-10 rules at once, fast).
- **Confidence: high + coverage_gaps: >0** → operator reviews the coverage report + the prose-judge fallback binding; confirms split.
- **Confidence: medium / low** → individual review; operator reads prose + draft side-by-side; accepts, edits, or rejects.
- **Confidence: abstain** → manual authoring; LLM provides scaffolding only.

Review queue lives in `.harness/operator-standards/review-queue/` as numbered staging files. CLI workflow:

```bash
scripts/classify-from-url.sh \
  --source-id walmart-microservices \
  --url https://walmart.example/standards/microservices.html

# → produces review queue:
# .harness/operator-standards/review-queue/
#   walmart-microservices-001.draft.yaml   # active.json entry candidate
#   walmart-microservices-001.coverage.md  # coverage diff
#   walmart-microservices-001/fixtures/    # positive + negative test files
#   ... × 47 rules

scripts/review-queue.sh --list             # show pending reviews + confidence
scripts/review-queue.sh --review walmart-microservices-001  # open in editor
scripts/review-queue.sh --accept walmart-microservices-001
scripts/review-queue.sh --reject walmart-microservices-001
scripts/review-queue.sh --batch-accept --confidence high  # bulk-accept high-confidence
```

On accept: rule entry committed to `active.json`, rule body committed to `.harness/operator-standards/custom-rules/<tool>/`, fixtures committed alongside. On reject: dropped (operator can re-run the classifier or author manually).

## 9. Decision (proposed CTP-ADR-NNNN)

**CTP-D-1.** Ship `scripts/extract-rules-from-url.sh` for Stage 2. Handles the 4-5 common doc shapes; LLM segmentation fallback for everything else.

**CTP-D-2.** Ship `scripts/classify-rule.sh` for Stage 3. Two-tier classifier (deterministic inverted index + LLM-judge). Caches by `(rule_body_sha, mirror_sha)`.

**CTP-D-3.** Ship `composite/kind-to-tool-routing.yaml` for Stage 4. Static ~50-entry routing table. Refresh discipline: operator may extend; CTP curates per CTP release.

**CTP-D-4.** Ship `scripts/draft-custom-rule.sh` for Stage 5. Per-tool DSL drafting with the four fidelity mechanisms (prompt discipline, coverage diff, test fixtures, prose-judge fallback for un-translatable clauses).

**CTP-D-5.** Ship `scripts/review-queue.sh` for Stage 6. CLI workflow for batch + individual rule review.

**CTP-D-6.** End-to-end driver: `scripts/classify-from-url.sh --source-id <id> --url <url>` runs Stages 1-5 in sequence and populates the review queue. Operator runs Stage 6 interactively.

**CTP-D-7.** Document the "no language silently dropped" contract prominently. Every drafted rule MUST emit a coverage report; any prose clause that isn't covered by the deterministic binding MUST appear in a second `prose-judge.sh` binding OR be flagged with explicit operator acknowledgment.

## 10. Alternatives considered

- **Manual authoring of every rule.** REJECTED — the catalog of operator-sourced standards is large (Google + Microsoft + OWASP + federal + Accenture + Walmart + internal teams = ~500-1000 rules in typical adoption). Manual is multi-month effort. LLM-assisted reduces to multi-week with review.
- **No fidelity verification — trust the LLM.** REJECTED — silent drops are the failure mode that breaks the "every rule enforced" contract. The four-layer fidelity mechanism is non-optional.
- **Single rule per LLM call.** ACCEPTED for Stages 3 + 5 — improves attribution + caching. Stage 2 segmentation is one LLM call per doc.
- **Skip operator review for high-confidence rules.** REJECTED for v1; opt-in via `--auto-accept-high-confidence` flag for operators with high trust. Default is human-in-the-loop.

## 11. Consequences

### Positive
- Operators ingest world-class standards at LLM speed instead of manual-authoring speed.
- Every rule arrives with provenance + coverage report + test fixtures from the start.
- The catalog grows naturally with the operator's source set; no per-rule engineering effort.
- The "no language silently dropped" contract makes the catalog audit-defensible — every clause traces to either a deterministic binding or an LLM-judge binding.

### Neutral
- LLM token cost is bounded by the hash cache + the one-time-per-rule drafting cost. Estimated <$1 per rule drafted for typical inputs.
- Operator review is the human bottleneck; bulk-accept for high-confidence reduces it.

### Negative / cost
- LLM dependency for Stages 3 + 5. Mitigation: deterministic tier-1 handles ~60-70% of classifications; LLM tier handles only the residual. Hash cache eliminates re-drafting.
- Quality of drafted DSL depends on LLM capability. Mitigation: per-tool fixture-based equivalence test catches regressions; operator review catches semantic failures.

## 12. Pairs with PROPOSAL-005

PROPOSAL-005 (composite engine + 4-axis vocabulary) provides the runtime — it routes tagged rules to tools and enforces them at write + audit time. PROPOSAL-006 (this brief) provides the upstream — it scrapes URLs, tags rules, drafts custom-rule files. Both target the same `active.json` rule registry; both compose on PROPOSAL-003's source refresh; both reuse the same canonical vocabulary.

PROPOSAL-006 **depends on** the P-8 fix from PROPOSAL-004 because the prose-judge LLM tier is required for the coverage-gap fallback (Stage 5D). P-8 should land before PROPOSAL-006 wave 2 (Stage 5 + 6).

## 13. Boundary discipline

**CTP owns** (this brief): the extraction strategies, the classifier, the routing table, the DSL drafter, the review-queue CLI.

**Consumer (GCTP) owns** (NOT this brief): operator workflow + the existing audit chain's consumption of the resulting rules.

**Operator owns**: the source URLs to scrape, the review-and-approve decision per rule, the per-tool custom-rule files committed to `.harness/operator-standards/custom-rules/`.

---

End of brief. Land as CTP-ADR-NNNN. Three waves: (1) extraction + classification + routing (Stages 1-4); (2) LLM-draft + fidelity discipline + coverage diff + fixtures (Stage 5, depends on P-8); (3) review-queue CLI (Stage 6). After full landing, operator scrape-to-enforced-rule cycle drops from days to hours, with audit-defensible provenance + fidelity per rule.
