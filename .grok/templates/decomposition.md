# Decomposition template — Grok outer-loop

**Purpose.** Convert a research bundle (output of `research.md`) into one or more atomic tickets (G-16). Each ticket emitted here is a candidate input to `dispatch.md`. This is the orchestrator-worker decomposition phase (G-7, corpus §4 orchestrator-workers pattern).

**Drawn from** (per D-1): Claude Code's plan-then-implement separation; Cursor's compose mode (multi-edit plan). Difference here: each output ticket is *atomic* (G-16) and must independently fit the handoff contract — not a multi-step plan but a list of one-shot dispatches.

**G-rules touched.** G-2, G-3, G-4 (effort `medium`; `high` if architectural decomposition). G-7 orchestrator-worker. G-9 bounded fan-out (≤ 8 tickets per decomposition run; if more needed, return `needs_supervisor: true`). G-16 atomic tickets. G-19 idempotent (same input → equivalent ticket set).

**Corpus anchors.** Musk's Algorithm step 1 (question every requirement): the decomposition pass *must* check whether each proposed ticket's requirements have a named source, and reject "best practice says so." Step 2 (delete before optimize): if a proposed ticket would only optimize an existing path, the decomposition rejects it unless the path is on a critical performance edge.

## Input variables

| Name | Required | Description |
|---|---|---|
| `research_output` | yes | A JSON document conforming to `research.md`'s output schema. |
| `decomposition_brief` | yes | One paragraph: what feature is being decomposed and what "done" looks like at the feature level. |
| `architecture_consult` | **DEPRECATED — optional, ignored as of ADR-0040** | The legacy per-feature *input variable* from TICKET-034 / ADR-0039. Still ignored (WARN if supplied). NOTE: this is the legacy *variable*, NOT the live consult *artifact* below — they are different things; this row is unchanged. |
| `consult_artifact` | optional (default-on if present) — **per ADR-0056** | Path to a live consult artifact `.harness/handoffs/FEATURE-NNN.architecture.json` produced by `/consult` (the GCTP↔CTP looped consult). When present, it is the **preferred** source of per-ticket `complexity` (sizing) + `applicable_rules` + grounding — see "Consult-artifact consumption" below. Distinct from the deprecated `architecture_consult` variable; this is an additive ADR-0056 path, not a revival of the ADR-0040-superseded mechanism. |
| `max_tickets` | optional, default 8 | Hard ceiling per G-9. If decomposition needs more, return `needs_supervisor: true` and decompose the decomposition itself. |

## Output shape (JSON Schema fragment)

```json
{
  "schema_version": "1",
  "feature_id": "FEATURE-NNN",
  "completed_at": "2026-05-25T...Z",
  "needs_supervisor": false,
  "tickets": [
    {
      "ticket_id": "TICKET-NNN",
      "title": "short imperative",
      "acceptance_criteria": ["<one observable behavior per entry>"],
      "file_scope": {
        "may_edit": ["path/glob/**.ext"],
        "may_read": ["path/glob/**.ext"],
        "must_not_touch": ["path/glob/**.ext"]
      },
      "depends_on": ["TICKET-MMM"],
      "research_refs": [{"kind": "url|doc-id|file", "ref": "<id>", "summary": "<one line>"}]
    }
  ],
  "reasoning_effort_used": "medium",
  "run_id": "<grok-run-uuid>"
}
```

Field semantics:

- Each `tickets[i]` is the *seed* of a Grok→Claude handoff doc. `dispatch.md` finalizes it (adds `issued_at`, `context_ttl_seconds`, `quality_gate`, fills `context.decomposition_parent` and `context.prior_decisions`).
- `acceptance_criteria` and `file_scope` already conform byte-for-byte to `docs/handoff-contract.md §Grok→Claude`. No re-shaping in `dispatch.md`.
- `depends_on` lets the dispatcher serialize tickets; an empty list means independent.
- `research_refs` per ticket is a *subset* of the input `research_output.research_refs` (G-17: provenance flows forward without re-research in the inner loop).

## System prompt skeleton (cache-stable per G-5)

> You are Grok, the outer-loop orchestrator. Your job in this run is decomposition only.
>
> **BEFORE proposing any tickets, read `.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md`** (per TICKET-036 / ADR-0041, activated by the pin bump to `bba77df`). This file is the static planner context published by `claude-tdd-pro` — it captures test-shape discipline, one-ticket-equals-one-R-G-R-cycle sizing, refactoring sequencing, architecture-fidelity invariants (quote feature IDs verbatim from `docs/architecture-v1.9.md`), ADR triggers, the six CLAUDE.md drift mechanisms, and the seven bash 3.2 portability gotchas. Respect all of it when proposing ticket boundaries, `depends_on`, `file_scope`, and acceptance criteria. Surface any tension with these rules explicitly in the decomposition output. Per ADR-0040 this static context replaces the per-feature consult mechanism originally proposed in ADR-0039 (SUPERSEDED); the legacy `architecture_consult` input variable is ignored even if supplied.
>
> Given a research bundle, a decomposition brief, and the static planner context, you emit between 1 and `max_tickets` atomic tickets. Each ticket MUST: (a) have non-empty `acceptance_criteria` (observable behaviors, not implementation steps); (b) declare `file_scope` with at least one `may_edit` glob; (c) be reachable in one CL by Claude TDD Pro; (d) carry only `research_refs` that appear in the input research bundle; (e) populate `applicable_rules` as the **union** of: the rules filtered from `.harness/rules/active.json` by detected language (per the `file_scope.may_edit` extensions); any rule IDs the static context / consult artifact surfaces as materially shaping the design; **every `g-universal-*` rule** (apply-by-default to all generated software regardless of language — CTP §28.21 / ADR-0060; the authority on the withheld set is CTP's `audit-universality-coverage.sh`, currently empty); AND every EO-governance rule (`source_namespace: eo` OR `security-governance`) regardless of language/file_scope — EO rules are non-exemptible (TICKET-050 / ADR-0045; `security-governance` is the live EO namespace at pin 6d2fe13+ per ADR-0055). Prefer **typed globs** (`…/**/*.ts`) over bare directory globs so the language floor is machine-enforceable (`scripts/audit-applicable-rules.sh`); **over-scoping is safe** — `enforce.sh` returns `not_applicable` (neutral) for a rule matching no files, so when in doubt include the rule. If the decomposition would exceed `max_tickets`, return `needs_supervisor: true` and a smaller decomposition that points to the supervisor split. You do not edit files. You do not dispatch. You return JSON.

## Consult-artifact consumption (per ADR-0056 — additive; static context remains the fallback)

When a live consult artifact `.harness/handoffs/FEATURE-NNN.architecture.json` is present (produced
by `/consult`, the GCTP↔CTP looped consult):

1. **Validate it first:** `scripts/consult.sh --validate <artifact>` (must exit 0 — schema_version,
   `needs_grounding == 0`, every decision sized + carrying `applicable_rules`). If validation fails,
   do NOT consume it; fall back to the static-context path and surface the failure.
2. **Derive, don't guess:** take per-ticket `complexity` (sizing), `applicable_rules`, and grounding
   from the artifact's `decisions[]` — these came from CTP under standards enforcement, not a planner
   estimate. Map each decision/chunk to a ticket.
3. **Sequence** tickets from the decisions' `depends_on`.

This is **additive**: when no artifact exists (or `--validate` fails, or Ruby is absent), decomposition
uses the static-context path exactly as before (ADR-0040). The artifact, when valid, is preferred
because it carries CTP's grounded technical reality. The consult remains *advisory* — Grok retains
decomposition authority (ADR-0039 framing).

## Pre-emit checks

- [ ] `tickets[*].acceptance_criteria` non-empty AND each entry reads as an observable behavior (not "implement X" / "refactor Y").
- [ ] `tickets[*].file_scope.may_edit` non-empty.
- [ ] `tickets[*].applicable_rules` populated (filter `.harness/rules/active.json` by detected language; supplement with rule IDs surfaced by the static context at `.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md`).
- [ ] `tickets[*].applicable_rules` includes EVERY EO-governance rule (`source_namespace: eo` OR `security-governance`) in `active.json` — non-exemptible (TICKET-050 / ADR-0045/0055). Live at pin 6d2fe13+ (`security-governance`: provenance + known-exploited-ingress rules).
- [ ] `tickets[*].applicable_rules` includes EVERY `g-universal-*` rule in `active.json` — apply-by-default to all generated software (Fix A / ADR-0060; enforced by `scripts/audit-applicable-rules.sh`). Typed `may_edit` globs additionally require their language floor (`.ts`→`g-ts-*`+`g-node-*`, `.tsx`→…+`g-react-*`, `.md`→`g-doc-*`, `.tf`→`g-hashicorp-*`, `.yaml`→`g-linux-foundation-*`).
- [ ] No `tickets[*].research_refs[i].ref` outside the input `research_output.research_refs`.
- [ ] `tickets.length ≤ max_tickets` OR `needs_supervisor: true`.
- [ ] Per ticket: dependencies in `depends_on` either exist in this output or are already-DONE tickets in `TICKETS.md`.
- [ ] Per D-1 deletion pass: every ticket that's "polish" or "refactor for its own sake" is dropped with a reason recorded in `run_id`'s observability log (G-15).
- [ ] Per ADR-0040: the static planner context at `.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md` (if present) is consulted for test-shape patterns, refactor sequencing, mutation seams, ADR triggers, and Bash 3.2 portability gotchas. The legacy `architecture_consult` input variable is ignored even if supplied.
- [ ] Per ADR-0056: if a consult artifact `.harness/handoffs/FEATURE-NNN.architecture.json` is present, it was validated with `scripts/consult.sh --validate` and its `decisions[]` drove per-ticket `complexity` + `applicable_rules` (preferred over a planner estimate). Absent/invalid ⇒ static-context fallback used (additive; no behavior lost).
