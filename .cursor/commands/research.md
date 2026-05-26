# /research <topic> — run outer-loop research template

## Purpose

Drive the outer-loop research phase against `.grok/templates/research.md` using Cursor's chat agent (in place of Grok CLI). Produce a structured `research_refs` markdown section that captures the topic landscape (existing primitives, prior decisions, applicable D-rules) the subsequent `/decompose` step will consume.

## Inputs

- `<topic>` — the research question, supplied as the slash command argument. Example: `/research enterprise IDE session-start ritual asymmetry`.

## Steps

1. Read `.grok/templates/research.md` end-to-end. Note its output schema (sections, fields).
2. Apply the template to the user-supplied topic, drawing from:
   - Authority docs enumerated in `AGENTS.md §5` (TIER 0/1/2).
   - Existing harness primitives (scripts, templates, contracts) cited by path.
   - Prior decisions in `docs/adr/`.
   - Founder-directives §1 sources for any T-A/T-B/T-C/T-D citation.
3. Produce the `research_refs` markdown in the chat window. Do NOT write to disk; the operator pipes the output into `/decompose` next.
4. Cite every primitive by file:line where possible (per D-12 production-grade trustability).

## Success criteria

- Output follows `.grok/templates/research.md`'s documented schema (intro / refs / open questions, per the template's structure).
- Every cited primitive resolves to a real file in this repo.
- No new authority claims invented; everything pointed at exists in TIER 0/1/2 surfaces.
- Output is structurally consumable by `/decompose` (i.e., readable by an agent walking the same template chain).

## Composition (D-1 reverse per ADR-0013)

Follows `.grok/templates/research.md` (TICKET-003 / ADR-0006). That template's D-1 *forward* attribution reads: *"Drawn from (per D-1): Cursor's ask-mode context gather."* This slash command closes the loop: Cursor's chat agent drives the template that was originally modeled on Cursor's own ask-mode context-gather pattern. The cycle is intentional — D-1 symmetric reading per ADR-0013.
