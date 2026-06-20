# /dispatch <TICKET-NNN> — write contract-valid request handoff

## Purpose

Drive the outer-loop dispatch phase against `.grok/templates/dispatch.md` and `docs/handoff-contract.md §Grok→Claude` using Cursor's chat agent. Produce one contract-valid `.harness/handoffs/<TICKET-NNN>.req.json` file ready for the inner loop to consume via `/inner-loop`.

## Inputs

- `<TICKET-NNN>` — the ticket id, supplied as the slash command argument. Example: `/dispatch TICKET-042`.
- Prior decomposition output (from `/decompose` chat history, or supplied by the user).

## Steps

1. Read `.grok/templates/dispatch.md` and `docs/handoff-contract.md §Grok→Claude` end-to-end. Note the request schema's required fields: `schema_version`, `ticket_id`, `acceptance_criteria`, `file_scope`, `context`, `quality_gate`.
2. Look up the ticket (from chat history or `TICKETS.md`) to capture acceptance criteria + file_scope + relevant context.
3. Compose the request JSON in chat first (for human review), then write to `.harness/handoffs/<TICKET-NNN>.req.json`.
4. Validate by reading back the file and confirming all required fields are present and `schema_version` is `"1"`.
5. **Design-phase MD gate (ADR-0066 D-D / TICKET-079).** If `file_scope.may_edit` includes any `.md` glob that resolves to an architectural document (path matching `docs/architecture/**`, `docs/adr/**`, or `docs/decisions/**`, OR a `.md` with YAML frontmatter `kind: architecture | adr | decision`), invoke `bash scripts/audit-design-phase-md.sh --quiet` BEFORE finalizing the request. Exit 1 means an architectural design proposes a violation of an `applies_to_prose: true` rule with no matching deviation; do NOT write the `req.json`. Operator paths: (a) rewrite the prose; (b) add a `## Deviation — <RULE-ID> on <TICKET-ID>` row to `<app_root>/docs/deviations.md` per `docs/deviations-template.md`. Vacuous-pass before PROPOSAL-003 lands.
6. Surface the path to the user; tell them `/inner-loop <TICKET-NNN>` is the next step.

## Success criteria

- File exists at `.harness/handoffs/<TICKET-NNN>.req.json`.
- JSON is parseable.
- All required fields per `docs/handoff-contract.md §Grok→Claude` are present.
- `schema_version` is `"1"`.
- `file_scope` is tightly bounded (not "*" or whole-repo) per D-13 (context-as-fundamental-constraint).
- `quality_gate` block includes the four sub-gate fields (per `docs/quality-gate.md`); `provenance_complete` is recommended at v1.

## Composition (D-1 reverse per ADR-0013)

Follows `.grok/templates/dispatch.md` (TICKET-003 / ADR-0006) and `docs/handoff-contract.md` (TICKET-002). Grok analog: the original consumer of this template was Grok CLI's headless dispatch (`grok -p <prompt>`); this slash command lets Cursor's chat agent drive the same template via the same wire format. The handoff contract is the cross-tool API boundary — `/dispatch` from Cursor and `grok -p` from a terminal produce byte-equivalent `.req.json` schemas.
