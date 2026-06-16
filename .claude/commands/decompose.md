---
description: Outer-loop decomposition — split a research bundle into atomic tickets
argument-hint: [decomposition brief]
---

Run the harness outer-loop **decomposition** phase (Claude Code mirror of `.cursor/commands/decompose.md`).

0. **If a consult artifact `.harness/handoffs/FEATURE-NNN.architecture.json` exists** (from `/consult`, per ADR-0056): validate it with `./scripts/consult.sh --validate <artifact>` (must exit 0), then take per-ticket `complexity` (sizing) + `applicable_rules` + grounding from its `decisions[]` — preferred over a planner estimate. If absent or validation fails, fall back to the static-context path below (additive; nothing lost).
1. Read `.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md` (static planner context), then `.grok/templates/decomposition.md`.
2. Using the prior `/research` output (and brief: **$ARGUMENTS**), emit 1..`max_tickets` atomic tickets per the template's schema.
3. Each ticket MUST: have observable `acceptance_criteria`; declare `file_scope.may_edit`; be one-CL-sized; carry only in-bundle `research_refs`; and populate `applicable_rules` by filtering `.harness/rules/active.json` by detected language **AND always including every EO-governance rule** (`source_namespace: eo` OR `security-governance`) — non-exemptible (ADR-0045/0055).
4. Return JSON. Do not edit files. Do not dispatch.
