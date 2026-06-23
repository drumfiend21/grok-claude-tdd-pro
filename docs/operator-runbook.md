# GCTP Operator Runbook

Operator-facing reference for the harness's operator command surface.

This runbook is **task-focused**: each section walks one operator workflow end-to-end with the exact commands to run and the expected outputs. For architectural context, see the linked ADRs.

---

## Adding standards from a URL (per ADR-0069 W-H)

GCTP wraps CTP's auto-classification pipeline (CTP-ADR-0009) behind two operator commands. The pipeline ingests an authoritative standards URL (Google style guide, OWASP ASVS, NIST control, internal corporate guidance, …), classifies each clause along the 4-axis canonical vocabulary (Linguist + IaC dialect + PURL + K8s GVK), routes each clause to the right FOSS tool (Semgrep, Checkov, Kubescape, …), drafts custom rule files, and lands them in `active.json` for enforcement.

Wrapped from the operator side by:

- `scripts/gctp-standards-add.sh` (W-F) — ingest a new source
- `scripts/gctp-standards-review.sh` (W-G) — review the drafted rules before they go live

### 1. Declare the source in `namespaces.yaml`

Before any ingest, declare the source. This is a **W-I back-stop**: `gctp standards add` rejects undeclared URLs before any LLM cost is incurred.

```bash
mkdir -p .harness/operator-standards
cat >> .harness/operator-standards/namespaces.yaml <<'YAML'
sources:
  - id: google-ts
    url: https://google.github.io/styleguide/tsguide.html
    namespace: google
YAML
```

Required fields per entry: `id`, `url`, `namespace`. The `id` is the operator-chosen identifier (lowercase, hyphenated). `namespace` becomes the `source_namespace` field on every drafted rule.

Validate the shape:

```bash
bash scripts/audit-applicable-rules.sh
# → [applicable-rules] namespaces.yaml: 1 sources declared.
```

If malformed (missing url, missing namespace, missing `sources:` block), the audit exits 1 with per-issue diagnostics.

### 2. Estimate cost + run the pipeline

```bash
bash scripts/gctp-standards-add.sh \
    --source-id google-ts \
    --url https://google.github.io/styleguide/tsguide.html \
    --shape markdown-headings \
    --budget-usd 10
```

The wrapper:

1. Validates the source is declared (per step 1).
2. Runs **extract** stage — segments the source into candidate rules.
3. Surfaces a cost estimate (`extracted N rules × $0.10/rule = $est-cost`).
4. Prompts confirmation if cost exceeds `--budget-usd`.
5. Runs **classify → route → draft → review-queue** stages end-to-end.
6. Caches per-stage outputs to `.harness/operator-standards/.cache/<source-id>.*.json`.

### 3. Expected cost band

The default estimate is conservative (`$0.10 / rule`). Realistic ranges by source size:

| Source class | Typical rule count | Estimated cost |
|---|---|---|
| Single style guide (Google TS, OWASP Top 10) | 10–80 | $1–$8 |
| Mid-size spec (OWASP ASVS Level 1+2, AWS WA Security pillar) | 80–250 | $8–$25 |
| Large spec (full ASVS, NIST 800-53 catalog) | 250–500 | $25–$50 |

Override `--budget-usd` for confidence; the wrapper prompts before exceeding it.

### 4. Review the queue

After the pipeline lands, review the drafted rules:

```bash
bash scripts/gctp-standards-review.sh --list
```

Output is a per-rule table:

```
SOURCE               RULE       QUEUE        CONFIDC  PATH
google-ts            r-no-any   auto_stage   high     .harness/operator-standards/.cache/google-ts.queue.json
google-ts            r-strict   side_by_side medium   .harness/operator-standards/.cache/google-ts.queue.json
```

**Queues** (CTP-ADR-0009 routing):

- `auto_stage` — high-confidence + zero-gap rules; safe to batch-accept
- `coverage_review` — high-confidence + gaps in clause coverage; operator reviews the coverage report
- `side_by_side` — low/medium confidence; full operator review of prose-vs-draft

### 5. Inspect a specific rule

```bash
bash scripts/gctp-standards-review.sh --review r-strict
```

Shows queue, confidence, source clause, draft preview, and coverage-report pointer.

### 6. Batch-accept high-confidence rules

```bash
bash scripts/gctp-standards-review.sh --batch-accept --confidence high
```

Wraps CTP's `review-queue.sh --auto-accept` (zero-gap high-confidence rules only). The accepted rules are staged for the next active.json regeneration.

### 7. Reject (or hand-edit) a rule

```bash
bash scripts/gctp-standards-review.sh --reject r-strict
```

Outputs a manual-workflow pointer to `.harness/operator-standards/custom-rules/<tool>/<rule-id>.*`. The operator either deletes the rule file or rewrites its DSL.

### 8. Coverage reports

Each drafted rule produces a coverage report at `.harness/operator-standards/custom-rules/<tool>/<rule-id>.coverage.md`. This documents:

- Which clauses of the source the rule's DSL covers
- Which clauses are flagged unenforceable (need operator sign-off)
- Per-clause fixture corpus the rule was validated against (CTP-ADR-0009 D-5 Layer C)

Read the coverage report before accepting a `coverage_review`-queue rule.

### 9. Validate a freshly-added rule before broad deployment

```bash
# Regenerate active.json to pick up the new rule
bash scripts/standards-sync.sh

# Run the new rule against your app tree to see it fire
bash scripts/enforce-standards.sh --ticket TICKET-EXAMPLE --json | jq '.rules_verified["g-google-no-any"]'
```

If the rule fires `pass` / `not_applicable` consistently, it's ready. If it reds on code you consider correct, hand-edit `custom-rules/<tool>/<rule-id>.*` to refine, then re-validate.

### 10. Handle a rejected rule

If the operator decides a draft isn't worth keeping, delete its `custom-rules/<tool>/<rule-id>.*` files and re-run `standards-sync.sh`. The active.json regeneration excludes any rule without a corresponding custom-rule file.

To re-extract from a refreshed source URL, just re-run `gctp standards add` with the same `source-id` — the wrapper overwrites the cache.

---

## Related ADRs

- **ADR-0070** — pin bump 39903da→230e99d (activation event for the composite engine line)
- **ADR-0068** — composite engine consumer wiring (W-A through W-E)
- **ADR-0069** — auto-classification pipeline wiring (W-F through W-I; **this section**)
- **CTP-ADR-0008** — composite engine + 4-axis canonical vocabulary (upstream)
- **CTP-ADR-0009** — auto-classification + custom-rule drafting pipeline (upstream)

## No-rewrites discipline (ADR-0070)

This runbook documents commands that CREATE state in operator-owned trees (`.harness/operator-standards/`). They do NOT modify pre-existing `.harness/handoffs/*` runtime state. Per the ADR-0070 no-rewrites discipline: new gates apply to new data; legacy handoffs are grandfathered, never mass-rewritten to satisfy new floors.
