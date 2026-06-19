---
description: Run Red-Green-Refactor for one ticket via the tdd-pro-cl-workflow skill
argument-hint: TICKET-NNN
---

Run the **inner loop** for ticket **$ARGUMENTS** (Claude Code mirror of `.cursor/commands/inner-loop.md`).

0. Resolve the external app working tree: `app_root=$(./scripts/app-root.sh)` (per ADR-0059, "Fix D"; `docs/handoff-contract.md §App-Root`). Exit 1 ⇒ no app configured (`.harness/app.json`); exit 2 ⇒ refuse (app_root missing/empty — never enforce on an empty tree). Red→Green→Refactor edits land in `app_root`; the enforcement step (Fix B) runs `enforce.sh --root "$app_root"`.
1. Read `.harness/handoffs/$ARGUMENTS.req.json` (the dispatched request).
2. Load and follow `.claude/skills/tdd-pro-cl-workflow/SKILL.md` — Red → Green → Refactor, strictly inside the ticket's `file_scope.may_edit`.
3. Honor the quality gate + every rule in `applicable_rules` (incl. the non-exemptible EO-governance rules); the PostToolUse hook enforces P0 rules at write-time.
4. On green, write `.harness/handoffs/$ARGUMENTS.res.json` + `.harness/trails/$ARGUMENTS.md` per `docs/handoff-contract.md §Claude→Grok`. A green response MUST carry `rules_verified` and a non-empty `eo_design_conformance` (two-phase, ADR-0046).
