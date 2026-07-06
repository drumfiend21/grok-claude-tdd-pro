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
and CTP writes the first `business-profile.json`, detect its `schema_version` and walk accordingly:

  - **v1.0 profile** (CTP `commands/business-intake.sh` — S-32 emit). Ask the universal 9 questions
    in plain business language, one at a time; feed answers back through `business-intake.sh --answers`.
    Nothing else fires at intake — the ~30 namespaces with first-order business expertise stay silent
    until write-time enforcement.
  - **v1.1 profile** (CTP `commands/full-surface-intake.sh` — S-57 / §2.35 / §30, resolved at pin
    `f060a8e` per ADR-0087; historical proposal `docs/handoff-ctp-p12-full-surface-intake.md`).
    Walk three stages:
    - **Stage 0 — classifier reveal.** Run `full-surface-intake.sh --workload "<vision>" --classify`;
      CTP writes `workload_classification.{workload_types, namespaces, activated_probe_namespaces}`.
      Show them to the user in plain language ("based on what you described, I'm treating this as a
      web-frontend + REST-API + Kubernetes workload at large scale — is that right?"). The activated
      probe namespaces drive Stage 2.
    - **Stage 1 — universal 9.** Same 9 questions as v1.0. Ask them in plain business language.
      Forward answers to S-32 via `--answer key=value` / `--answers <json>` (S-57 composes S-32);
      they land under top-level `answers` unchanged (universal-stays-universal — S-57 does NOT
      introduce a `probes.universal` block).
    - **Stage 2 — per-namespace probes.** For each activated probe namespace (e.g. `react`, `jwt`,
      `k8s`, `owasp`, `iam`, `observability`, `slsa`, `w3c` if `web-ui`, etc.), walk that
      namespace's probe questions one at a time. Each question is grounded in a `source_id` —
      translate the technical framing (e.g. "OWASP ASVS Level 1/2/3", "WCAG 2.2 AA vs AAA", "SLSA
      level 3", "JWT token lifetime", "K8s multi-tenancy posture") into plain business language per
      the crossroads/translator loop. Feed answers back via `--probe-answer ns:key=value`. Every
      answered probe becomes a **committed posture** the downstream design layer will honor and
      lands the namespace in `grounded_in_namespaces`.

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
(§Architecture-Consult-Loop), `.harness/handoffs/$1.business-intake.json` (§Business-Intake —
`schema_version` 1.0 from S-32, 1.1 from S-57 at pin `f060a8e`+), the cross-check record
(§Architecture-Cross-Check), and the roadmap (§Roadmap) — real tickets, sized, sequenced, planned.
`applicable_rules` must resolve in `active.json` and always include the non-exemptible
EO-governance rules. For v1.1 profiles, every entry in
`workload_classification.activated_probe_namespaces` must **propagate** into at least one decision's
`applicable_rules` (a rule whose `source_namespace` matches the namespace) — invariant 4 of the
cross-check audit; a silent omission is a violation.

**4. Present the roadmap** to the user in plain language. Then `/dispatch` + `/inner-loop` per ticket.
