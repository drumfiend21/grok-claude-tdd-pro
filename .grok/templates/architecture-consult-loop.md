# Template — GCTP↔CTP live architecture-consult **loop**

> **STATUS: ACTIVE (per ADR-0056).** This is the live, looped consult mechanism. It is a
> *new, distinct* mechanism — it does not edit or un-supersede `.grok/templates/architecture-consult.md`
> (the v1 single-shot consult, left as history under ADR-0040). Static planner context
> (`.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md`) remains valid as background, not as a
> substitute for architecting an external project.

## Purpose

GCTP stands at the **crossroads** between CTP (technical architecture + development, standards-
enforced) and the **user** (often non-technical, speaking business/creative language). This
template defines the **per-juncture loop** GCTP runs to translate between the two and produce a
world-class, sized, sequenced roadmap — world-class because CTP architects under enforcement
**and** GCTP independently checks/enforces on top (ADR-0056 D-C).

## Preconditions

- **Ruby ≥ 3.0** on PATH (CTP's engine is Ruby-backed). Absent ⇒ **stop-and-remediate** with a
  clear message (ADR-0056 D-D). Do not silently fall back to static context for external-project design.
- CTP plugin materialized at the pinned commit (`scripts/sync-plugin.sh --ensure`).

## The loop (repeats at every question/juncture until the design is complete)

```
[intake]  GCTP elicits, in plain language, what the user wants to build.
   │
   ▼  ── per-juncture loop ──────────────────────────────────────────────────────
  a. CONSULT CTP for grounded technical direction at THIS juncture:
       commands/architect-session.sh (S-32 intake → S-33 translate → S-34 recommend
       → S-35 explain) + commands/well-architected-review.sh (S-26), driven from the
       user's answers-so-far. CTP enforces its standards/sources (google/owasp/
       government/eo/slsa/…); require needs_grounding = 0 (cite-or-decline).
  b. TRANSLATE CTP's technical reality → non-technical, business/creative terms:
       what the choice means, why it matters, the trade-offs — as clarification + guidance.
  c. PROMPT the user with the next clarifying question / decision (sourced from CTP's
       business-intake `next_question`, phrased for a non-technical user).
  d. USER DECIDES (in their own language).
  e. TRANSLATE the decision back into technical input for CTP (map to intake enums).
  f. SIZE + TICKET the decided chunk via a CTP consult on its technical reality
       (build-requirements + per-concern complexity → small/medium/large + depends_on),
       then CROSS-CHECK it against GCTP's own rules (active.json + R/D/EO/citation/corpus).
       Cross-check failure ⇒ bounded re-consult with the violation as a constraint;
       if still unsatisfiable, surface to the operator as a deviation (ADR-0056 D-E).
   └────────────────────────────────────────────────────────────────────────────
   ▼  (next juncture CTP surfaces → loop again)
[roadmap] GCTP presents the accreted roadmap: real tickets, sized, sequenced, planned.
```

## Outputs (schemas in `docs/handoff-contract.md`)

- `.harness/handoffs/FEATURE-NNN.architecture.json` — the consult artifact (§Architecture-Consult-Loop):
  grounded options, recommended option, build requirements, and per-decision `complexity` +
  `applicable_rules` (resolved against `active.json`), accreted across the loop.
- The cross-check record (§Architecture-Cross-Check): per GCTP-rule `pass`/`deviated`/`reconsulted`.
- The roadmap (§Roadmap): sized, sequenced, planned tickets presented to the user.

## Caching (cost control, ADR-0056)

`cache_key = sha256(research_bundle + feature_brief + decisions_so_far)`. A juncture whose key is
unchanged reuses the prior consult. Trivial tickets may opt out of the loop.

## Composition

Composes on (does not replace): `.grok/templates/research.md` (upstream), `.grok/templates/decomposition.md`
(downstream — consumes this artifact, wired in a later CL), `docs/handoff-contract.md` (the schemas),
and CTP's architecture engine (consumed by reference at the pinned commit; prime directive).
