# /roadmap FEATURE-NNN — render + present the GCTP↔CTP consult roadmap

Cursor mirror of `.claude/commands/roadmap.md` (per ADR-0056 / TICKET-066). Stage 7 of the
architecture-consult loop: turn a completed consult artifact into the roadmap the user sees —
real chunks, sized, sequenced, planned.

## Steps

1. **Locate** `.harness/handoffs/FEATURE-NNN.architecture.json` (produced by `/consult`). Absent ⇒ STOP;
   run `/consult FEATURE-NNN` first.
2. **Render:** `./scripts/consult.sh --roadmap .harness/handoffs/FEATURE-NNN.architecture.json`. It
   re-validates (§Architecture-Consult-Loop), refuses an invalid artifact or a dependency cycle, and
   emits a human-readable roadmap + the §Roadmap JSON (chunks keyed by juncture, topologically sequenced
   over `depends_on`, with `applicable_rules` + grounding). Non-zero ⇒ surface the reason; never
   hand-assemble a roadmap from an invalid artifact.
3. **Translate + present:** as GCTP at the crossroads, restate the roadmap in plain business/creative
   language — what each chunk delivers, its sequence, its dependencies. `/decompose` assigns final
   `TICKET-NNN` ids; junctures are the prospective tickets.
4. **Hand off:** proceed to `/decompose` (consumes the same artifact) → `/dispatch` → `/inner-loop`.

## Composition

Stage 7 of `/consult`; feeds `/decompose`. Renders only — mutates nothing. Consumes the consult artifact
by reference (prime directive); Grok retains orchestration authority.
