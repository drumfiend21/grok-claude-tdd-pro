---
description: Outer-loop decomposition — split a research bundle into atomic tickets
argument-hint: [decomposition brief]
---

Run the harness outer-loop **decomposition** phase (Claude Code mirror of `.cursor/commands/decompose.md`).

-1. **Delegate to Grok first (G-2/G-7, TICKET-109).** Run `bash scripts/grok-run.sh decomposition --input "brief=$ARGUMENTS"` (add `--input research=<the /research output>` when it's in hand).
   - `"stub": false` → real Grok ran and owns this phase: its `structured_output` carries the tickets. Verify each against the invariants in step 3 below (rules-union, one-CL sizing, typed globs) before presenting — the gates still apply to Grok's output. Cite the run log (`.harness/runs/<run-id>.jsonl`, G-15).
   - `"stub": true` → outer loop not wired yet (`./install.sh` wires it). Say so in one line and proceed inline below (Mode B fallback, unchanged behavior).

0. **If a consult artifact `.harness/handoffs/FEATURE-NNN.architecture.json` exists** (from `/consult`, per ADR-0056): validate it with `./scripts/consult.sh --validate <artifact>` (must exit 0), then take per-ticket `complexity` (sizing) + `applicable_rules` + grounding from its `decisions[]` — preferred over a planner estimate. If absent or validation fails, fall back to the static-context path below (additive; nothing lost).
1. Read `.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md` (static planner context), then `.grok/templates/decomposition.md`.
2. Using the prior `/research` output (and brief: **$ARGUMENTS**), emit 1..`max_tickets` atomic tickets per the template's schema.
3. Each ticket MUST: have observable `acceptance_criteria`; declare `file_scope.may_edit` (prefer **typed globs** like `…/**/*.ts`); be one-CL-sized; carry only in-bundle `research_refs`; and populate `applicable_rules` as the **union** of: language-filtered rules from `.harness/rules/active.json`; **every `g-universal-*` rule** (apply-by-default — Fix A / ADR-0060); **and** every EO-governance rule (`source_namespace: eo` OR `security-governance`) — non-exemptible (ADR-0045/0055). Over-scoping is safe (`enforce.sh` → `not_applicable`). Enforced by `scripts/audit-applicable-rules.sh`.
4. `file_scope.may_edit` globs are **relative to the app_root** (the external app tree resolved by `./scripts/app-root.sh`; per ADR-0059 / `docs/handoff-contract.md §App-Root`), not the harness tree — that is the tree Fix B/C enforce on.
5. Return JSON. Do not edit files. Do not dispatch.
