---
description: Run the GCTP↔CTP architecture-consult loop (crossroads/translator) for a feature
argument-hint: FEATURE-NNN [what the user wants to build]
---

Drive the **architecture-consult loop** (ADR-0056; template `.grok/templates/architecture-consult-loop.md`).
You are GCTP, standing at the **crossroads** between CTP (technical architect, standards-enforced) and
the **user** (non-technical, business/creative language). Translate both directions.

**0. Preflight (hard prerequisite — ADR-0056 D-D).** Run `./scripts/consult.sh --preflight`. If it exits
non-zero, **STOP** and show its remediation message — do NOT silently fall back to static context for an
external project.

**1. Intake.** In plain language, elicit what the user wants to build (use `$ARGUMENTS`; ask if thin).

**2. Per-juncture loop — repeat at every decision until the design is complete:**
   - **Consult CTP** for grounded technical direction at this juncture: locate the engine with
     `./scripts/consult.sh --engine-path architect-session.sh` (and `well-architected-review.sh`,
     `business-intake.sh`), run it against the answers-so-far. CTP enforces its standards (google/owasp/
     government/EO/SLSA/…) with cite-or-decline — require `needs_grounding = 0`.
   - **Translate** CTP's technical reality into non-technical, business/creative terms: what the choice
     means, why it matters, the trade-offs — as clarification + guidance.
   - **Prompt** the user with the next clarifying question / decision (source it from the engine's
     `next_question`, phrased for a layperson).
   - On the user's decision, **map it back** to CTP's intake, then **size + ticket** that chunk via a CTP
     consult on its technical reality, and **cross-check** it against GCTP's own rules (`.harness/rules/active.json`
     + the R/D/EO/citation/corpus governance). Cross-check failure ⇒ bounded re-consult with the violation
     as a constraint; if still unsatisfiable, surface a deviation (`docs/deviations.md`) for operator approval.

**3. Write artifacts** per `docs/handoff-contract.md`: `.harness/handoffs/$1.architecture.json`
(§Architecture-Consult-Loop), the cross-check record (§Architecture-Cross-Check), and the roadmap
(§Roadmap) — real tickets, sized, sequenced, planned. `applicable_rules` must resolve in `active.json`
and always include the non-exemptible EO-governance rules.

**4. Present the roadmap** to the user in plain language. Then `/dispatch` + `/inner-loop` per ticket.
