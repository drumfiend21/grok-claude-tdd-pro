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

**1a. Intake cascade — walk it in stages (schema-aware).** After the user's plain-language brief lands
and CTP's `business-intake.sh` writes the first `business-profile.json`, detect its `schema_version`
and walk accordingly:

  - **v1.0 profile** (CTP v1.13 emit — the current shape at pin `0cf28fe`). Ask the universal 9
    questions in plain business language, one at a time; feed answers back through
    `business-intake.sh --answers`. Nothing else fires at intake — the ~30 namespaces with first-order
    business expertise stay silent until write-time enforcement. Filed as P-12; docs at
    `docs/handoff-ctp-p12-full-surface-intake.md`.
  - **v1.1 profile** (CTP v1.14 §27.16, once landed via TICKET-114). Walk three stages:
    - **Stage 0 — classifier reveal.** CTP writes `workload_classification.signals_detected` +
      `activated_probe_groups`. Show them to the user in plain language ("based on what you
      described, I'm treating this as a public-facing AI-high-risk backend at large scale — is that
      right?"). Accept `--force-signal <s>` / `--suppress-signal <s>` overrides. The activated probe
      groups drive Stage 2.
    - **Stage 1 — universal 9.** Same 9 questions as v1.0. Ask them in plain business language.
      Answers land under `probes.universal` AND are mirrored under top-level `answers` (belt-and-
      suspenders backward-compat, contract invariant).
    - **Stage 2 — per-namespace probes.** For each activated probe group (e.g. `security-governance`,
      `iam`, `owasp`, `observability`, `slsa`, `w3c` if `web-ui`, etc.), walk that group's questions
      one at a time. Each question is grounded in a `source_id` — translate the technical framing
      (e.g. "OWASP ASVS Level 1/2/3", "WCAG 2.2 AA vs AAA", "SLSA level 3", "human-oversight
      commitment") into plain business language per the crossroads/translator loop. Every answered
      probe becomes a **committed posture** the downstream design layer will honor.

Validate the resulting profile with `./scripts/consult.sh --validate-profile <profile>` before
moving to Stage 2 (per-juncture loop). Exit 0 means contract-conformant; exit 1 lists what's
missing/broken; exit 2 is a usage/file error.

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
(§Architecture-Consult-Loop), `.harness/handoffs/$1.business-intake.json` (§Business-Intake — carries
schema_version 1.0 today, 1.1 once TICKET-114 lands), the cross-check record (§Architecture-Cross-Check),
and the roadmap (§Roadmap) — real tickets, sized, sequenced, planned. `applicable_rules` must resolve
in `active.json` and always include the non-exemptible EO-governance rules. For v1.1 profiles, every
activated probe group's committed posture must **propagate** into at least one decision's
`applicable_rules` (a rule whose `source_namespace` matches the group name) — invariant 4 of the
cross-check audit; a silent omission is a violation.

**4. Present the roadmap** to the user in plain language. Then `/dispatch` + `/inner-loop` per ticket.
