# Architecture-consult template — Grok → Claude-TDD-Pro

**Purpose.** Close the technical-approach feedback loop **before** decomposition. Grok calls Claude-TDD-Pro with the feature brief + research bundle and asks the six architecture questions. The structured output (`.harness/handoffs/FEATURE-NNN.architecture.json`) becomes a required input to `decomposition.md` so atomic tickets are sized against the real test-shape, real refactor sequencing, and real applicable rules — not Grok's blind guess.

Per TICKET-034 / ADR-0039. Operator-visible only on cache-miss; cached otherwise.

**Drawn from** (per D-1): Claude Code's plan-then-implement separation; Anthropic's "Building Effective Agents" reviewer-pattern; the existing handoff contract round-trip pattern; Musk Algorithm step 1 ("question every requirement"). Difference here: the consult is *advisory input to decomposition*, not a hard contract — Grok retains decomposition authority but is no longer blind.

**G-rules touched.** G-2 headless (no stream; one-shot consult). G-3 structured output (schema below; pre-emit validated). G-5 cache-stable (cache key = sha256(research_bundle + brief)). G-7 orchestrator (Grok still owns outer loop; this is a planning round-trip to the inner loop, not a delegation of orchestration). G-15 observability (consult is recorded in the provenance manifest as a `kind: architecture_consult` source). G-19 idempotent (same input → byte-identical consult).

**Corpus anchors.** Step 1 (question every requirement) — the consult IS the question. Step 2 (delete before optimize) — the consult may reject proposed tickets that don't justify their existence. Step 5 (deletion-pass) — the consult's `prior_decisions` array may include "delete this scope" entries.

## Input variables

| Name | Required | Description |
|---|---|---|
| `feature_id` | yes | The `FEATURE-NNN` identifier — matches downstream `decomposition.md` output. |
| `research_output` | yes | A JSON document conforming to `research.md`'s output schema. |
| `decomposition_brief` | yes | One paragraph: what feature is being decomposed and what "done" looks like at the feature level. Identical to the brief that would otherwise feed `decomposition.md` directly. |
| `consult_toggle` | optional, default `on` | When `off`, skip the consult and emit a stub architecture document with `consult_skipped: true` + rationale. Default-on per ADR-0039; the toggle exists for trivial / single-line tickets where the round-trip cost exceeds the benefit. |

## The six questions (the consult prompt's content)

The consult template is constructed so Claude-TDD-Pro answers exactly these:

1. **Test-shape.** What's the test structure that drives this feature's design? Unit + integration + property-based + contract? What's at each layer?
2. **Decomposition.** What's the natural decomposition into atomic tickets such that each is one Red-Green-Refactor cycle? List with titles + observable acceptance criteria.
3. **Sequencing.** What's the `depends_on` graph? Which tickets must land before which others? Identify any "green path lands BEFORE refactor it enables" sequencing.
4. **Scope per ticket.** What `file_scope.may_edit` + `may_read` does each ticket need? Are there extract-to-value-object opportunities that warrant their own ticket?
5. **Applicable rules.** Which rules from `.harness/rules/active.json` apply to each ticket (filter by language + concern)? Identify any rule that materially shapes the design (e.g., OWASP V5.1 schema validation at boundary).
6. **Complexity.** Estimated complexity per ticket: `small` (<2 hr), `medium` (2-6 hr), `large` (>6 hr — should it split further?). Flag any ticket that requires an ADR before implementation per `architecture-principles §15`.

## Output shape (the artifact persisted to `.harness/handoffs/FEATURE-NNN.architecture.json`)

```json
{
  "schema_version": "1",
  "feature_id": "FEATURE-NNN",
  "consult_timestamp": "2026-06-06T...Z",
  "consult_skipped": false,
  "consult_skip_rationale": null,
  "cache_key": "sha256(research_bundle + brief)",
  "test_shape_summary": "Vitest + Testing Library for components; Playwright contract tests for HTTP boundary; property-based for value objects.",
  "recommended_tickets": [
    {
      "ticket_id": "TICKET-XXX",
      "title": "Imperative short title",
      "test_shape": "Unit tests around the parse function; integration test through the route handler.",
      "file_scope": {
        "may_edit": ["src/parsers/foo.ts", "tests/parsers/foo.test.ts"],
        "may_read": ["src/types/**.ts"],
        "must_not_touch": [".grok/**", ".claude/**", "claude-tdd-pro/**"]
      },
      "depends_on": ["TICKET-YYY"],
      "applicable_rules": ["g-ts-001", "g-ts-003", "g-node-001"],
      "complexity": "small",
      "rationale": "One R-G-R cycle around the parse function. Tests drive the shape; no architectural decisions needed."
    }
  ],
  "prior_decisions": [
    {"kind": "adr_required", "ref": "ADR-00XX", "summary": "Schema validation at boundary requires an ADR — touches §5 immutability."},
    {"kind": "extract", "summary": "Value object `ParsedFoo` warrants its own ticket; sized 'small'."},
    {"kind": "delete", "summary": "Proposed ticket 'add metrics dashboard' rejected; covered by C-24 + audit-metrics.sh."}
  ],
  "grok_notes": "Optional — Grok's own high-level observations on the consult output."
}
```

## Cache contract (per G-5)

- **Cache key:** `sha256(json.canonicalize(research_bundle) + "\n" + decomposition_brief)`.
- **Cache location:** `.harness/cache/architecture-consult/<cache_key>.json` (gitignored runtime artifact).
- **Hit policy:** byte-identical input → byte-identical output read from cache; no Claude round-trip.
- **Miss policy:** invoke Claude TDD Pro via the dispatch wrapper; persist result to cache; emit visible `[architecture-consult] cache miss` line.
- **Invalidation:** plugin pin bump invalidates the cache (the underlying skill + rules may have shifted). Cache directory cleared by `scripts/sync-plugin.sh --ensure` when the pin commit changes.

## System prompt skeleton (cache-stable per G-5)

> You are Claude TDD Pro acting as an architecture reviewer for Grok's planning phase. You have been called BEFORE any code is written. Read the `feature_id`, `research_output`, and `decomposition_brief`. Read `.harness/rules/active.json` and the inner-loop SKILL.md trio (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`). Answer the six numbered questions in the structured output format defined in `architecture-consult.md`. Your output is advisory — Grok retains decomposition authority. You do NOT edit files; you do NOT write code; you produce the `architecture.json` document and exit.

## Pre-emit checks (executed BEFORE writing to disk)

- [ ] Document validates against the architecture.json schema in `docs/handoff-contract.md §Architecture-Consult`.
- [ ] `schema_version: "1"`.
- [ ] `feature_id` matches the input variable.
- [ ] `cache_key` matches the computed sha256 of input.
- [ ] If `consult_skipped: true`, then `consult_skip_rationale` is non-empty AND `recommended_tickets` is empty.
- [ ] If `consult_skipped: false`, then `recommended_tickets` length ≥ 1.
- [ ] Every `recommended_tickets[].applicable_rules` ID exists in `.harness/rules/active.json`.
- [ ] Every `recommended_tickets[].file_scope.must_not_touch` includes the prime-directive denylist (`.grok/**`, `.claude/**`, `claude-tdd-pro/**`).

## Failure modes

- **Schema invalid** → `error.code: "schema_invalid"`, no file written.
- **Cache directory unwriteable** → emit consult anyway (cache is best-effort); WARN to stderr.
- **`active.json` references a rule the consult can't validate** → `error.code: "unknown_rule"`, no file written. Operator re-runs `standards-sync.sh`.

## Operator-visible surfaces

Default: silent on cache hit; `[architecture-consult] cache miss → consulting Claude TDD Pro for FEATURE-NNN` on miss, followed by `[architecture-consult] N tickets recommended` on success. Decomposition consumes the artifact transparently.

## Composition (cited, not duplicated)

- `docs/handoff-contract.md §Architecture-Consult` — schema.
- `.harness/rules/active.json` — rule source for `applicable_rules` validation.
- `.harness/cache/architecture-consult/` — cache directory.
- `.grok/templates/decomposition.md` — required consumer of this output.
- ADR-0039 — the decision record for this consult phase.
