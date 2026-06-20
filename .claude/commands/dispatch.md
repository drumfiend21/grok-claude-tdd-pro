---
description: Emit a contract-valid handoff request for a ticket
argument-hint: TICKET-NNN
---

Run the harness **dispatch** phase (Claude Code mirror of `.cursor/commands/dispatch.md`).

1. Read `.grok/templates/dispatch.md` and `docs/handoff-contract.md §Grok→Claude`.
2. For ticket **$ARGUMENTS**, write `.harness/handoffs/$ARGUMENTS.req.json` populated per the contract (`schema_version: "1"`, `acceptance_criteria`, `file_scope` incl. the `must_not_touch` deny-list, `context`, `quality_gate`, and `applicable_rules`).
3. `applicable_rules` MUST include every EO-governance rule (`source_namespace: eo` OR `security-governance`) — non-exemptible (ADR-0045/0055), verified by `scripts/audit-eo-governance.sh`.
4. Validate the emitted JSON against the template's pre-emit checks before finishing.
5. **Design-phase MD gate (ADR-0066 D-D / TICKET-079).** If `file_scope.may_edit` includes any `.md` glob that resolves to an architectural document (path matching `docs/architecture/**`, `docs/adr/**`, or `docs/decisions/**`, OR a `.md` whose YAML frontmatter declares `kind: architecture | adr | decision`), invoke `bash scripts/audit-design-phase-md.sh --quiet` BEFORE finalizing the request. Exit 1 means an architectural ADR/design doc proposes a design that violates an `applies_to_prose: true` rule with no matching deviation row; in that case, do NOT write the `req.json`. The operator's two paths: (a) rewrite the prose to remove the violation, or (b) add a `## Deviation — <RULE-ID> on <TICKET-ID>` row to `<app_root>/docs/deviations.md` per `docs/deviations-template.md`. Vacuous-pass when no `applies_to_prose: true` rules exist in `active.json` (i.e. before PROPOSAL-003 lands).
