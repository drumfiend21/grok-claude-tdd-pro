# /decompose — turn research into atomic, contract-shaped tickets

## Purpose

Drive the outer-loop decomposition phase against `.grok/templates/decomposition.md` using Cursor's chat agent. Consume the prior `/research` output (or any equivalent research-refs section the user supplies) and produce one or more atomic tickets, each in the shape a subsequent `/dispatch` can turn into a contract-valid `.req.json`.

## Inputs

- Prior research_refs (from `/research` chat history, or supplied by the user as a markdown block).
- Optionally: a scope hint (which area of the harness the decomposition should focus on).

## Steps

0. **Consult-artifact consumption (per ADR-0056, additive):** if `.harness/handoffs/FEATURE-NNN.architecture.json` exists (from `/consult`), validate it with `./scripts/consult.sh --validate <artifact>` (must exit 0), then take per-ticket `complexity` (sizing) + `applicable_rules` + grounding from its `decisions[]` — preferred over a planner estimate. Absent/invalid ⇒ static-context fallback (nothing lost).
1. Read `.grok/templates/decomposition.md` end-to-end. Note its output schema (per-ticket fields: id, title, scope, acceptance, dependencies, deferrals).
2. Walk the research_refs and propose a decomposition that:
   - Honors D-9 (simple composable patterns) — one ticket = one CL.
   - Honors D-4 (each ticket strictly harder than the previous) — sequence the decomposition.
   - Honors D-8 (deletion pass) — explicit Out-of-scope per ticket where ambiguity exists.
   - Honors R-3 (single source of truth) — no ticket duplicates an existing primitive's responsibility.
3. Produce the decomposition in the chat window. Do NOT write to disk; the operator reviews and pipes individual tickets into `/dispatch`. Each ticket's `applicable_rules` is the **union** of language-filtered `active.json` rules + **every `g-universal-*` rule** (apply-by-default, Fix A / ADR-0060) + every EO rule (non-exemptible); prefer **typed globs** so the language floor is enforceable; over-scoping is safe (`enforce.sh` → `not_applicable`). Enforced by `scripts/audit-applicable-rules.sh`.
4. For each ticket, name the existing primitives it composes on (per D-11). For any new substrate, run the D-8 deletion-pass question explicitly.

## Success criteria

- Output follows `.grok/templates/decomposition.md`'s documented per-ticket schema.
- Every ticket has a stated acceptance criterion that is exit-0-verifiable (per D-12).
- Sequencing is named — each ticket declares its dependencies on prior tickets.
- Out-of-scope items per ticket are explicit (not implicit).

## Composition (D-1 reverse per ADR-0013)

Follows `.grok/templates/decomposition.md` (TICKET-003 / ADR-0006). That template's D-1 *forward* attribution reads: *"Drawn from (per D-1): Cursor's compose mode (multi-edit plan)."* This slash command closes the loop: Cursor's chat agent drives the template originally modeled on Cursor's compose mode. D-1 symmetric reading per ADR-0013.
