---
description: Outer-loop research — apply .grok/templates/research.md to a topic
argument-hint: <topic>
---

Run the harness outer-loop **research** phase (Claude Code mirror of `.cursor/commands/research.md`).

1. Read `.grok/templates/research.md` end-to-end; note its output schema.
2. Apply it to the topic: **$ARGUMENTS**
3. Draw from the authority docs in `AGENTS.md §5` (TIER 0/1/2), existing harness primitives cited by `file:line`, and prior decisions in `docs/adr/`.
4. Produce the `research_refs` markdown in the chat — do **not** write to disk; the operator pipes it into `/decompose` next.

Cite every primitive by `file:line`. Invent no authority claims.
