# ADR-0069 — GCTP-side auto-classification pipeline wiring

- **Status:** Proposed
- **Date:** 2026-06-22
- **Deciders:** drumfiend21 + Claude Opus 4.7 (GCTP cloud session).
- **Pairs with:** **CTP-ADR-NNNN+1** (auto-classification + custom-rule drafting pipeline — landing in `claude-tdd-pro/docs/adr/`, source design at `proposals/PROPOSAL-006-auto-classification-and-rule-drafting-pipeline.md`).
- **Composes on:** ADR-0064/0065 (standards refresh cadence), ADR-0066 (YAML/JSON/MD corpora + prose-as-code), ADR-0067 (pin bump to 39903da), ADR-0068 (this ADR's twin — composite engine wiring).

## Trigger

CTP-ADR-NNNN+1 lands the auto-classification + custom-rule drafting pipeline in the CTP plugin: 6 stages — extract → classify (4-axis + `applies_to_prose`) → route → LLM-draft DSL with 4-layer fidelity → review-queue → commit. After landing, operators can ingest arbitrary world-class standards URLs (Google, Microsoft, OWASP, federal, Accenture, Walmart, internal) at LLM speed.

This ADR governs the GCTP-side wiring for that pipeline. It is paired with CTP-ADR-NNNN+1; the harness consumes via the contract surface (operator-source URLs in `.harness/operator-standards/namespaces.yaml`; resulting rules in `active.json`).

## Context

The auto-classification pipeline produces rules into `active.json`. GCTP — as the consumer — needs to:

1. Make the pipeline reachable from the operator-facing CLI (`/audit`, `/decompose`, the consult loop).
2. Ensure the resulting rules flow through the existing applicable-rules union (ADR-0060) and audit chain (ADR-0062/0063) without harness modification.
3. Surface the LLM-cost-budget to the operator before the pipeline starts a bulk ingest.
4. Give the operator a path to review the queue, accept/reject rules, and see the coverage report.

The harness MUST NOT mirror any extraction strategies, classifier prompts, drafter prompts, or coverage-diff harness — those are CTP-owned content. The harness owns the **operator-workflow spine**; the plugin owns the **pipeline**.

## Decision

Three decisions; D-A through D-C.

### D-A. Operator-facing CLI surfaces the pipeline.

The harness gains one new operator command:

```bash
gctp standards add --source-id <id> --url <url> [--shape <doc-shape>] [--budget-usd <max>]
```

Which is a thin wrapper around CTP's `scripts/classify-from-url.sh` (CTP-ADR-NNNN+1 D-8). The harness wrapper:

1. Validates the operator has declared the source in `.harness/operator-standards/namespaces.yaml`.
2. Surfaces a cost estimate before starting (P50 token usage × rule-count estimate × current LLM pricing).
3. Confirms operator before exceeding `--budget-usd`.
4. Invokes the CTP-side pipeline.
5. Surfaces progress (per-stage TUI).
6. Hands off to `gctp standards review` after the queue populates.

A second command for review:

```bash
gctp standards review [--list | --review <id> | --accept <id> | --reject <id> | --batch-accept --confidence high]
```

Thin wrapper around CTP's `scripts/review-queue.sh`. Adds operator-friendly summary + coverage-report viewer.

### D-B. Resulting rules flow through the existing audit chain unchanged.

After operator accepts rules into `active.json`, they appear with `applies_to.*` + `applies_to_prose` populated. ADR-0068 D-A/D-B already wire the audit chain to consume the 4-axis schema. No additional harness change needed — the new rules from the auto-classification pipeline are indistinguishable from CTP-shipped rules at the consumption boundary.

This is the key elegance: **the pipeline produces standard-shaped rules, the audit chain consumes standard-shaped rules**, neither side needs to know about the other.

### D-C. Operator-facing docs update.

`docs/operator-runbook.md` gains a new section: "Adding standards from a URL" with:

1. How to declare a source in `namespaces.yaml`
2. Example `gctp standards add` invocation
3. Expected cost band per source size
4. Review-queue workflow (high-confidence batch vs. individual review)
5. How to handle rejected rules (re-extract / manual authoring / abandon)
6. Where coverage reports live (`.harness/operator-standards/custom-rules/<tool>/<rule-id>.coverage.md`)
7. How to validate a freshly-added rule before deploying it broadly (the per-rule fixture corpus CTP-ADR-NNNN+1 D-5 Layer C produces)

`docs/first-time-guide.md` extends the standards-onboarding section with a worked example: "Onboard Google TS style guide → 47 rules in 12 minutes for $4.50."

## Wiring CLs

| CL | Deliverable | Acceptance criteria |
|---|---|---|
| **W-F** | `gctp standards add` operator-facing CLI wrapper | Unit test: invoking against a mocked CTP pipeline succeeds; budget-overrun confirmation works |
| **W-G** | `gctp standards review` operator-facing CLI wrapper | Unit test: list/review/accept/reject/batch-accept exit-code conformance |
| **W-H** | `docs/operator-runbook.md` + `docs/first-time-guide.md` updates | Operator can follow the runbook end-to-end on a fresh repo without help |
| **W-I** | Source-declaration schema validation for `namespaces.yaml` | `audit-applicable-rules.sh` validates `namespaces.yaml` at session start; unknown source URLs are rejected before the pipeline runs |

## Consequences

### Positive

- Operators get a single, learnable command (`gctp standards add`) to onboard any standards URL. The pipeline's complexity is hidden.
- The harness gains capability without gaining surface area — two CLI subcommands + docs.
- Cost transparency before bulk ingest prevents surprise LLM bills.
- The resulting rules are first-class citizens in the existing audit chain — no special-casing.

### Neutral

- The pipeline is operator-initiated (manual `gctp standards add`); not automatic on source-URL change. Future iteration may add a webhook-driven refresh.
- Operator review remains the human bottleneck (mitigated by batch-accept).

### Negative / cost

- **Dependency on CTP-ADR-NNNN+1 landing.** Wraps an upstream pipeline; no value until CTP ships it. Mitigation: land proposed; advance to accepted on pin bump.
- **LLM cost is operator-borne.** ~$50 for a 500-rule catalog; ongoing prose-judge invocations bounded by hash cache. Cost surfaced in docs.

## Alternatives considered

- **Harness re-implements the pipeline.** REJECTED — violates prime directive. Pipeline is plugin-side.
- **Pipeline is automatically triggered on every source-refresh cycle.** REJECTED — risks unbounded LLM cost without operator awareness. Manual invocation with cost preview is safer.
- **Harness skips the review-queue and auto-accepts high-confidence rules silently.** REJECTED — the operator's standing directive is human-in-the-loop by default; opt-in `--auto-accept-high-confidence` flag exists at the CTP layer.
- **Bake the standards-add command into `/audit` or `/decompose`.** REJECTED — that conflates rule-onboarding with audit-driving. A distinct `gctp standards` subcommand keeps responsibility lines clean.

## Boundary discipline (recap)

- **CTP owns** (CTP-ADR-NNNN+1): the pipeline runtime — extractors, classifier, routing table, drafter, coverage-diff harness, review-queue, fidelity discipline.
- **GCTP owns** (this ADR): the operator-facing `gctp standards add` + `gctp standards review` CLI commands, source-declaration schema validation, operator-runbook documentation.
- **Operator owns**: source URLs, the per-rule accept/reject decision, the LLM cost budget, the resulting `.harness/operator-standards/custom-rules/<tool>/<rule-id>.<ext>` files.

Neither side reaches into the other. Contract surface: source-URL declarations in `namespaces.yaml`; resulting rules in `active.json` + custom-rules tree.

---

This ADR is paired with CTP-ADR-NNNN+1 in `claude-tdd-pro`. Land on adoption of CTP-ADR-NNNN+1; advance to accepted at the pin bump that activates the auto-classification pipeline in this harness.
