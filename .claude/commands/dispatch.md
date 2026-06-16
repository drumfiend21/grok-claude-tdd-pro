---
description: Emit a contract-valid handoff request for a ticket
argument-hint: TICKET-NNN
---

Run the harness **dispatch** phase (Claude Code mirror of `.cursor/commands/dispatch.md`).

1. Read `.grok/templates/dispatch.md` and `docs/handoff-contract.md §Grok→Claude`.
2. For ticket **$ARGUMENTS**, write `.harness/handoffs/$ARGUMENTS.req.json` populated per the contract (`schema_version: "1"`, `acceptance_criteria`, `file_scope` incl. the `must_not_touch` deny-list, `context`, `quality_gate`, and `applicable_rules`).
3. `applicable_rules` MUST include every EO-governance rule (`source_namespace: eo` OR `security-governance`) — non-exemptible (ADR-0045/0055), verified by `scripts/audit-eo-governance.sh`.
4. Validate the emitted JSON against the template's pre-emit checks before finishing.
