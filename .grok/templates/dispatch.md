# Dispatch template — Grok → Claude handoff

**Purpose.** Emit the exact `.harness/handoffs/<ticket-id>.req.json` document defined in `docs/handoff-contract.md §Grok→Claude`. One call per ticket (G-6, R-1). This is the only template whose output is consumed by another system rather than by another Grok template.

**Drawn from** (per D-1): Claude Code's `claude -p "..." --output-format json` pattern; xAI's Grok Build CLI sub-agent dispatch surface; ACP (G-11) for agent-to-agent boundaries. Difference here: dispatch is *one-shot* (G-6 no streaming, handoff-contract.md §Wire format) — no partial updates, no batch.

**G-rules touched.** G-2 headless. G-3 structured output (this template MUST validate against the handoff contract schema before writing). G-5 cache-stable. G-6 one ticket = one doc. G-7 orchestrator (Grok writes; never edits inside acceptance-tested scope). G-15 observability. G-19 idempotent — re-running with the same input either writes nothing new or overwrites with a byte-identical doc.

**Corpus anchors.** Verification = highest leverage — this template runs a schema-validation step before emit. Production-grade trust (D-12) — every field traces to either the decomposition output or a named policy default.

## Input variables

| Name | Required | Description |
|---|---|---|
| `ticket_seed` | yes | One element from `decomposition.md`'s `tickets[]` output. |
| `context_ttl_seconds` | optional, default 3600 | Per handoff-contract §Freshness. Use 1800 for fast-moving research, 86400 for stable specs. |
| `quality_gate` | optional, default `{tests_must_pass: true, coverage_delta_min: 0, lint_clean: true}` | Per handoff-contract §quality_gate. TICKET-007 will replace these defaults. |
| `prior_decisions` | optional | Array of `{ticket_id, decision}` extracted from prior decision trails. |

## Output shape

This template's output is **the handoff document itself**, persisted to `.harness/handoffs/<ticket_id>.req.json`. The shape is defined entirely by `docs/handoff-contract.md §"Grok → Claude (request)"`. The template MUST embed that schema by reference, not by copy — see R-5 (no schema duplication) and R-11 (tolerant reader). To minimize drift:

- The handoff schema lives in **one place**: `docs/handoff-contract.md §Grok→Claude`.
- This template's emitter validates against that schema at run time.
- Schema bumps follow R-5: bilateral, explicit, `schema_version` is incremented in `docs/handoff-contract.md` AND in this template's pre-emit check AND in the consumer's validator (the `.claude/` skill that reads the doc) — one CL touching all three sites.

The minimum fields a Grok run MUST populate (cross-reference, not duplicate, the contract):

- `schema_version` — currently `"1"`. Source: this template's compiled-in constant; must match handoff-contract §wire format.
- `ticket_id`, `title`, `acceptance_criteria`, `file_scope` — copied from `ticket_seed`.
- `issued_at` — emitter-supplied (UTC ISO-8601, second precision).
- `context_ttl_seconds` — from input variable or default.
- `context.research_refs` — copied from `ticket_seed.research_refs`.
- `context.decomposition_parent` — copied from `ticket_seed.feature_id` (or from `decomposition.md` output's `feature_id`).
- `context.prior_decisions` — from input variable or `[]`.
- `quality_gate` — from input variable or default.

## System prompt skeleton (cache-stable per G-5)

> You are Grok, dispatching one ticket. Given a `ticket_seed` and policy defaults, you produce the EXACT JSON document specified in `docs/handoff-contract.md §"Grok → Claude (request)"`. You do not edit files. You do not invent acceptance criteria not present in the seed. You do not widen `file_scope`. You validate the document against the handoff-contract schema before emitting; if validation fails, you return `status: "error", error.code: "schema_invalid"` instead of writing the file.

## Pre-emit checks (executed BEFORE writing to disk)

- [ ] Document validates against `docs/handoff-contract.md §Grok→Claude` JSON Schema.
- [ ] `schema_version: "1"`. (Bump procedure documented above.)
- [ ] `acceptance_criteria` length ≥ 1.
- [ ] `file_scope.may_edit` length ≥ 1.
- [ ] `must_not_touch` includes `.grok/**` and `.claude/**` and `claude-tdd-pro/**` (the harness-prime-directive denylist — never let an inner-loop dispatch edit the orchestration substrate or the plugin).
- [ ] `issued_at` is now-UTC, second precision.
- [ ] `context_ttl_seconds` in `[60, 86400]`.
- [ ] If `ticket_id` already exists at `.harness/handoffs/<ticket_id>.req.json` AND the existing doc is byte-identical, exit success without write (G-19 idempotency). Otherwise refuse with `error.code: "dispatch_collision"` and require explicit human approval to overwrite.

## Failure modes

- **Schema invalid** → `error.code: "schema_invalid"`, no file written.
- **Ticket-id collision with non-identical content** → `error.code: "dispatch_collision"`, no file overwritten. Requires HITL approval (G-13).
- **`must_not_touch` denylist not respected** → `error.code: "scope_violation"`, no file written.
