---
description: Render + present the GCTP↔CTP consult roadmap (sized, sequenced, planned) for a feature
argument-hint: FEATURE-NNN
---

Render Stage 7 of the architecture-consult loop (ADR-0056): turn a completed consult artifact
into the **roadmap** the user sees — real chunks, sized, sequenced, planned.

**1. Locate the artifact.** `.harness/handoffs/$1.architecture.json` (produced by `/consult`). If it is
absent, **STOP** — there is no completed consult to present; run `/consult $1` first.

**2. Render.** Run `./scripts/consult.sh --roadmap .harness/handoffs/$1.architecture.json`. The script
re-validates the artifact (§Architecture-Consult-Loop) and refuses to render an invalid one or a
dependency cycle. It emits a human-readable roadmap plus the `docs/handoff-contract.md` §Roadmap JSON
(chunks keyed by juncture, topologically sequenced over `depends_on`, each with `applicable_rules` +
grounding). If it exits non-zero, surface the reason — do not hand-assemble a roadmap from an invalid
artifact.

**3. Translate + present.** As GCTP at the crossroads, restate the roadmap to the user in plain,
business/creative language: what each chunk delivers, why it comes when it does, what it depends on.
Note that `/decompose` assigns the final `TICKET-NNN` ids — the junctures shown are the prospective
tickets.

**4. Hand off.** With the roadmap accepted, proceed to `/decompose` (which consumes the same artifact to
size + ticket) and then `/dispatch` + `/inner-loop` per ticket.

Composes on `/consult` (this is its Stage 7) and feeds `/decompose`. Renders only — it mutates nothing.
