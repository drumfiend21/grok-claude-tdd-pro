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
5. Surface the path to the user; tell them `/inner-loop <TICKET-NNN>` is the next step.

## Success criteria

- File exists at `.harness/handoffs/<TICKET-NNN>.req.json`.
- JSON is parseable.
- All required fields per `docs/handoff-contract.md §Grok→Claude` are present.
- `schema_version` is `"1"`.
- `file_scope` is tightly bounded (not "*" or whole-repo) per D-13 (context-as-fundamental-constraint).
- `quality_gate` block includes the four sub-gate fields (per `docs/quality-gate.md`); `provenance_complete` is recommended at v1.

## Composition (D-1 reverse per ADR-0013)

Follows `.grok/templates/dispatch.md` (TICKET-003 / ADR-0006) and `docs/handoff-contract.md` (TICKET-002). Grok analog: the original consumer of this template was Grok CLI's headless dispatch (`grok -p <prompt>`); this slash command lets Cursor's chat agent drive the same template via the same wire format. The handoff contract is the cross-tool API boundary — `/dispatch` from Cursor and `grok -p` from a terminal produce byte-equivalent `.req.json` schemas.
