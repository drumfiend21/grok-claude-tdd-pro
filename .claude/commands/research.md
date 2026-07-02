---
description: Outer-loop research — apply .grok/templates/research.md to a topic
argument-hint: <topic>
---

Run the harness outer-loop **research** phase (Claude Code mirror of `.cursor/commands/research.md`).

0. **Delegate to Grok first (G-2/G-7, TICKET-109).** Run `bash scripts/grok-run.sh research --input "topic=$ARGUMENTS"`.
   - `"stub": false` in the JSON result → real Grok ran and owns this phase: its `structured_output` IS the research result. Present it per the template's schema, cite the run log (`.harness/runs/<run-id>.jsonl`, G-15), and apply step 4's do-not-write rule. Skip inline steps 1–3.
   - `"stub": true` → the outer loop isn't wired yet (`./install.sh` wires it — CLI + one-time key). Say so in one line, then proceed inline below (Mode B fallback, unchanged behavior).

1. Read `.grok/templates/research.md` end-to-end; note its output schema.
2. Apply it to the topic: **$ARGUMENTS**
3. Draw from the authority docs in `AGENTS.md §5` (TIER 0/1/2), existing harness primitives cited by `file:line`, and prior decisions in `docs/adr/`.
4. Produce the `research_refs` markdown in the chat — do **not** write to disk; the operator pipes it into `/decompose` next.

Cite every primitive by `file:line`. Invent no authority claims.
