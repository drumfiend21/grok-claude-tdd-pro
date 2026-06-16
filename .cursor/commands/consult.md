# /consult FEATURE-NNN [what the user wants to build] — GCTP↔CTP architecture-consult loop

Cursor mirror of `.claude/commands/consult.md` (per ADR-0056 / TICKET-063). Drives the
architecture-consult **loop** defined in `.grok/templates/architecture-consult-loop.md`.

GCTP is the **crossroads** between CTP (technical architect, standards-enforced) and the user
(non-technical). Translate both directions, at every juncture.

## Steps

0. **Preflight (hard prerequisite, ADR-0056 D-D):** run `./scripts/consult.sh --preflight`. Non-zero ⇒
   STOP with its remediation message; do not fall back to static context for an external project.
1. **Intake:** elicit, in plain language, what the user wants to build.
2. **Per-juncture loop (repeat until the design is complete):** consult CTP's engine for grounded
   technical direction (locate via `./scripts/consult.sh --engine-path <script>`; require
   `needs_grounding = 0`) → translate it into business/creative terms (clarification + guidance) →
   prompt the user → on decision, map back to CTP, size + ticket that chunk via a CTP consult, and
   cross-check against `.harness/rules/active.json` + the R/D/EO/citation/corpus governance (failure ⇒
   bounded re-consult, else an operator-approved deviation in `docs/deviations.md`).
3. **Write artifacts** per `docs/handoff-contract.md` §Architecture-Consult-Loop / §Architecture-Cross-Check /
   §Roadmap into `.harness/handoffs/FEATURE-NNN.architecture.json` (+ cross-check + roadmap).
4. **Present the roadmap** (sized, sequenced, planned tickets) to the user; then `/dispatch` + `/inner-loop`.

## Composition

Runs between `/research` and `/decompose`. Consumes CTP's architecture engine by reference at the pinned
commit (prime directive). The consult is advisory to decomposition — Grok retains orchestration authority.
