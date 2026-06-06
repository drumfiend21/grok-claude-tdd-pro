# Handoff Contract

The API boundary between Grok Build CLI (outer loop) and Claude TDD Pro (inner loop). Every code-change handoff in either direction conforms to one of the two schemas below. Anything not in these schemas is out of contract and the receiver MUST reject it.

## When handoff occurs

- **Grok → Claude**: once per ticket. Grok has finished research and decomposition for one ticket and is dispatching the inner loop to produce a passing change.
- **Claude → Grok**: once per ticket attempt. Claude returns either a green result (tests pass, change ready for deploy), a red result (could not reach green), or blocked (missing context, contract violation).

No streaming. No partial updates. One JSON document per direction per ticket.

## Wire format

- Payload is a single JSON file written to a path agreed at orchestration time. Default: `.harness/handoffs/<ticket-id>.req.json` (Grok→Claude) and `.harness/handoffs/<ticket-id>.res.json` (Claude→Grok).
- Encoding: UTF-8, no BOM.
- The receiver MUST validate the JSON against the schema before acting. Schema violation → `status: "error"` response with `error.code: "schema_invalid"`.

## Grok → Claude (request)

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-NNN",
  "title": "short imperative",
  "issued_at": "2026-05-24T17:30:00Z",
  "context_ttl_seconds": 3600,
  "acceptance_criteria": [
    "<one observable behavior per entry>"
  ],
  "file_scope": {
    "may_edit": ["path/glob/**.ext"],
    "may_read":  ["path/glob/**.ext"],
    "must_not_touch": ["path/glob/**.ext"]
  },
  "context": {
    "research_refs": [
      {"kind": "url|doc-id|file", "ref": "<id>", "summary": "<one line>"}
    ],
    "decomposition_parent": "FEATURE-NNN",
    "prior_decisions": [
      {"ticket_id": "TICKET-MMM", "decision": "<one line>"}
    ]
  },
  "quality_gate": {
    "tests_must_pass": true,
    "coverage_delta_min": 0,
    "lint_clean": true
  },
  "applicable_rules": [
    "g-react-001",
    "g-node-001",
    "g-ts-001"
  ]
}
```

Field rules:

- `schema_version` is required. Currently `"1"`. Bump on breaking changes.
- `acceptance_criteria` MUST be non-empty. Each entry is one observable behavior, not an implementation step.
- `file_scope.may_edit` is an allowlist. Claude MUST NOT edit files outside it. `must_not_touch` is a denylist that wins ties.
- `context_ttl_seconds` is how long the receiver may treat research_refs as fresh. Past TTL, Claude returns `status: "blocked"` with `error.code: "context_stale"` rather than acting on stale facts.
- `quality_gate` defines what counts as "green". The semantics of each sub-field — `tests_must_pass`, `coverage_delta_min`, `lint_clean`, and the recommended-at-v1 `provenance_complete` — are formalized in [`quality-gate.md`](quality-gate.md). This field is the contract surface; per-sub-gate definitions, defaults, override policies, and the reviewer checklist live in the formalization doc.
- `applicable_rules` (added per TICKET-032 / ADR-0037) is an array of rule IDs from `.harness/rules/active.json` (the aggregated standards registry from the plugin's `rubric/aggregator.sh`). Grok populates this by filtering the active registry against the ticket's `file_scope` + detected language(s). Claude MUST run `rubric/runner.sh` against each rule ID and report results in the response's `rules_verified` field. If the field is absent, Claude treats it as "all rules from active.json apply" — fail-closed.

## Claude → Grok (response)

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-NNN",
  "status": "green",
  "completed_at": "2026-05-24T17:42:00Z",
  "changed_files": [
    {"path": "src/foo.ts", "lines_added": 14, "lines_removed": 2}
  ],
  "test_results": {
    "framework": "<name>",
    "passed": 12,
    "failed": 0,
    "skipped": 0,
    "duration_ms": 842
  },
  "coverage_delta": 0.4,
  "decision_trail_ref": ".harness/trails/TICKET-NNN.md",
  "skills_invoked": ["tdd-pro-cl-workflow"],
  "rules_verified": {
    "g-react-001": "pass",
    "g-node-001": "pass",
    "g-ts-001": "pass"
  },
  "notes": "optional, single short paragraph",
  "error": null
}
```

`rules_verified` field rules (added per TICKET-032 / ADR-0037):

- Keys are rule IDs from `applicable_rules` in the matching request.
- Values are `"pass"`, `"fail"`, or `"deviated"` (= violation justified by a row in `docs/deviations.md`).
- A `green` status requires every applicable rule to be `pass` OR `deviated`. Any `fail` forces `status: "red"` with `error.code: "gate_failed"`.
- Missing keys (request named a rule but response omits it) force `status: "red"` with `error.code: "gate_failed"`.

`status` enum:

- `"green"` — tests pass, gate satisfied, deploy may proceed.
- `"red"` — change attempted, tests do not pass, gate not satisfied. Grok decides retry/escalate.
- `"blocked"` — Claude refused to act. `error` populated. Grok must resolve before retry.
- `"error"` — internal failure (schema invalid, skill missing, etc.). `error` populated.

When `status != "green"`, `error` MUST be populated:

```json
"error": {
  "code": "context_stale|scope_violation|gate_failed|schema_invalid|skill_missing|other",
  "message": "<human-readable>",
  "details": { }
}
```

## Freshness rules

- A request older than `issued_at + context_ttl_seconds` MUST be rejected as `context_stale`.
- A response older than 24 hours MAY be discarded by Grok without action; the orchestrator should reissue the request rather than trust a stale response.

## Example: happy path

Request (`.harness/handoffs/TICKET-042.req.json`):

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-042",
  "title": "trim whitespace in slugify()",
  "issued_at": "2026-05-24T17:30:00Z",
  "context_ttl_seconds": 1800,
  "acceptance_criteria": [
    "slugify('  hello world  ') returns 'hello-world'",
    "slugify('') returns ''"
  ],
  "file_scope": {
    "may_edit": ["src/string-utils.*", "test/string-utils.*"],
    "may_read":  ["src/**"],
    "must_not_touch": [".grok/**", ".claude/**"]
  },
  "context": {
    "research_refs": [],
    "decomposition_parent": "FEATURE-007",
    "prior_decisions": []
  },
  "quality_gate": {
    "tests_must_pass": true,
    "coverage_delta_min": 0,
    "lint_clean": true
  }
}
```

Response (`.harness/handoffs/TICKET-042.res.json`):

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-042",
  "status": "green",
  "completed_at": "2026-05-24T17:38:14Z",
  "changed_files": [
    {"path": "src/string-utils.ts", "lines_added": 1, "lines_removed": 0},
    {"path": "test/string-utils.test.ts", "lines_added": 8, "lines_removed": 0}
  ],
  "test_results": {"framework": "vitest", "passed": 6, "failed": 0, "skipped": 0, "duration_ms": 312},
  "coverage_delta": 0.0,
  "decision_trail_ref": ".harness/trails/TICKET-042.md",
  "skills_invoked": ["tdd-pro-cl-workflow"],
  "notes": null,
  "error": null
}
```

## Example: blocked path

Response when Grok asked Claude to edit a denied path:

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-051",
  "status": "blocked",
  "completed_at": "2026-05-24T17:33:02Z",
  "changed_files": [],
  "test_results": null,
  "coverage_delta": null,
  "decision_trail_ref": null,
  "skills_invoked": [],
  "notes": null,
  "error": {
    "code": "scope_violation",
    "message": "Acceptance criteria require editing .grok/templates/research.md, which is in must_not_touch.",
    "details": {"requested_path": ".grok/templates/research.md"}
  }
}
```

## Out of scope (deferred)

- Authentication / signing of payloads (assumes co-located filesystem).
- Multi-ticket batched handoffs (out-of-contract; one ticket per file).
- Streaming progress (deliberately disallowed — one-shot only).
- Concrete quality-gate definitions (lives in TICKET-007).
