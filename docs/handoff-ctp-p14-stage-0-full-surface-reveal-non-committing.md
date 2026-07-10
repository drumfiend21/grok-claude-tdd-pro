# GCTP → CTP handoff — P-14: Stage-0 full-surface reveal (non-committing) — expose the full plug-in expertise as an `available_menu` at intake so the operator can steer Stage-1 with visibility

**Written:** 2026-07-09 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `11126a8`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟡 **FILED — awaiting CTP consult**
**Ask:** extend `commands/full-surface-intake.sh --classify` output with an additive `workload_classification.available_menu` block that lists every namespace in `active.json` grouped by functional family (frontend / backend / IaC-vendor-neutral / cloud / CI-CD / data / supply-chain / regulatory-governance). Non-committing — reveal only. Zero `--stack-add` fires from this. The operator sees the full plug-in expertise at Stage 0 and can steer Stage-1 commitments with awareness of what's available. Ship as **v1.16 §30.7 (Stage-0 full-surface reveal)**. Additive per ADR-0047. Compact-safe.

---

## Companion supplementary materials (this repo)

- **This document** — reasoning + proposal + acceptance framing (start here).
- **`.harness/consult-work/FEATURE-003/gaps-log.md`** — the KA-1 gaps log that identified this gap (G-1). Structured per-KA record; feeds the "address and repeat" cycle.
- **`.harness/consult-work/FEATURE-003/intake/stage-0-classifier.json`** — actual classifier output at pin `11126a8` for the SoftArchCert kata vision (verbatim evidence).

## 0. TL;DR

The classifier at pin `11126a8` reveals only vision-activated namespaces plus always-on regulatory / AI-governance. For a tech-agnostic vision — such as the O'Reilly Winter 2025 SoftArchCert kata (Certifiable, Inc. wants generative AI to automate certification grading at 10x scale without losing candidate trust) — Stage-0 activates **6** namespaces (`documentation`, `european-union`, `observability`, `owasp`, `security-governance`, `us-government`) despite the plug-in shipping **43** namespaces of first-class expertise (`react`, `google`, `typescript`, `node`, `k8s`, `aws`, `slsa`, `helm`, `sbom`, `jwt`, `iam`, …) that will inevitably apply to any real web + API + platform system at production scale.

The **2026-07-04 operator directive** — *"From the very beginning, I need the entire expertise of the entire plug-in to be interfacing with the user when asking the user about what they want to build. It creates the seed for the project from which it will divide and grow."* — is **structurally satisfied** (fail-closed `applicable_rules` grades every design decision against all 118 rules regardless of activation) but **experientially not** — the operator sees only 6 namespaces at intake and cannot see, therefore cannot steer toward, the expertise available.

**The design-correct fix is not to auto-commit tech at Stage 0.** Doing that would violate §30.5's "commit-to-stack fires at commitment junctures (Stage-1, Stage-2, design-time)" model. It would also violate the agent operating compact (`docs/agent-operating-compact.md`) — the agent must not decide React-vs-Vue or AWS-vs-GCP without an explicit operator commitment.

**The design-correct fix is to REVEAL the full expertise menu at Stage 0 without committing to any of it.** Reveal ≠ commit. The `available_menu` block shows what's available; the operator commits (in Stage 1 answers, Stage 2 probes, or design-junctures) with visibility of the menu; `--stack-add` still fires only at those commitment junctures per §30.5.

Additive per ADR-0047. Monotone by construction (menu can only grow if `active.json` grows; never shrinks). Every v1.0 and v1.1 profile emitted before §30.7 continues to validate + translate + recommend unchanged (the new key is optional-additive to `workload_classification`).

---

## 1. The gap (evidence, deterministic at pin `11126a8`)

### 1.1. What the classifier reveals today

**Reproduce** on the SoftArchCert vision (verbatim from `.harness/consult-work/FEATURE-003/vision.txt`):

> *"Certifiable, Inc. certifies IT professionals. Their exam process mixes multiple-choice, short-answer, and case-study questions. Multiple-choice is auto-graded; short-answer and case-study are graded by ~300 retired subject matter experts. They want to adopt generative AI to automate grading and question generation and handle 10x growth without losing certification credibility or violating candidate trust."*

```bash
bash commands/full-surface-intake.sh --workload "$(cat certifiable-vision.txt)" --classify
```

Output (verbatim, GCTP KA-1, 2026-07-09):

```json
{
  "workload_classification": {
    "workload_types": ["ai-governed", "baseline-quality"],
    "namespaces": [
      "documentation", "european-union", "industry-self-regulatory",
      "observability", "owasp", "security-governance", "us-government"
    ],
    "activated_probe_namespaces": [
      "documentation", "european-union", "observability",
      "owasp", "security-governance", "us-government"
    ],
    "unprobed_in_scope": ["industry-self-regulatory"],
    "stack": []
  }
}
```

### 1.2. What the plug-in ACTUALLY has expertise about (from `active.json` at the same pin)

```
frontend:     react (6) · google (6) · typescript (4) · w3c (1) · web-vitals (2)
backend:      node (6) · oas (3) · jwt (3) · iam (4) · typescript (4) · google (6)
iac-neutral:  k8s (10) · helm (3) · iac-linter (2) · mesh (2) · gitops (2)
cloud:        aws (2) · azure (2) · gcp (2) · cfn (3)
iac-tool:     hashicorp (2) · ansible (3) · compose (5)
ci-cd:        gha (5) · glci (3) · circleci (2) · jenkins (2) · azdo (2) · bbp (2)
supply-chain: slsa (1) · sbom (2) · sarif (3) · linux-foundation (2)
data-schema:  oas (3) · jsonschema (2) · json (1) · yaml (1) · md (2)
regulatory:   us-government (2) · european-union (2) · security-governance (2)
              · industry-self-regulatory · owasp (2) · observability (2)
              · documentation (2) · arch (3) · _universal (2)
```

**118 rules across 43 namespaces.** The classifier reveals 6 activated + 1 unprobed = **7 named to the operator**. The remaining **36 namespaces of expertise** are silently latent.

### 1.3. Downstream harm

1. **Operator can't steer with visibility.** The 2026-07-04 directive requires the operator to see the expertise; today they see 15% of it.
2. **Agent/operator tension around "commit vs reveal."** Mid-KA-1, the operator asked *"pull frontend/backend/IaC up."* The agent (Claude Code driving GCTP) resolved the tension incorrectly by phantom-`--stack-add`'ing 23 packs BEFORE Stage-1 — violating §30.5's commit-at-junctures design. The operator caught it; the agent reverted. Root cause: the design has no non-committing reveal mechanism, so the agent conflated "expose expertise" with "commit to it." §30.7 fixes the root cause.
3. **Stage-0 output looks wrong for tech-obvious visions.** For a certification-body AI grader that is obviously going to have a frontend + backend + platform, the 6-namespace Stage-0 reveal reads as an incomplete surface — even though the fail-closed `applicable_rules` default guarantees all 118 rules apply to any decision. The operator experience should reflect the structural guarantee.

### 1.4. Operator observation (verbatim)

> *"What about rules for frontend development (for example the rulesets from google) and also backend and IaC? Those should be pulled up and informing any architectural decision making."* — 2026-07-09, KA-1 mid-attempt

Combined with the standing 2026-07-04 and 2026-07-03 directives (see `.harness/consult-work/FEATURE-003/PROMPTS.md` and `docs/founder-directives.md §1` if elevated), this is a consistent, repeated ask across multiple sessions.

---

## 2. Proposal — v1.16 §30.7 (Stage-0 full-surface reveal, non-committing)

### 2.1. Shape (additive)

Extend the `--classify` output's `workload_classification` block with an additive `available_menu` field:

```json
{
  "workload_classification": {
    "workload_types": ["ai-governed", "baseline-quality"],
    "namespaces": [ ... current, unchanged ... ],
    "activated_probe_namespaces": [ ... current, unchanged ... ],
    "unprobed_in_scope": [ ... current, unchanged ... ],
    "stack": [ ... current, unchanged ... ],
    "available_menu": {
      "frontend":            { "namespaces": ["react","google","typescript","w3c","web-vitals"] },
      "backend":             { "namespaces": ["node","oas","jwt","iam","typescript","google"] },
      "iac_vendor_neutral":  { "namespaces": ["k8s","helm","iac-linter","mesh","gitops"] },
      "cloud":               { "namespaces": ["aws","azure","gcp","cfn"],
                               "note": "vendor pick — commit one via --stack-add at Stage-1 or design-juncture." },
      "iac_tool":            { "namespaces": ["hashicorp","ansible","compose"] },
      "ci_cd":               { "namespaces": ["gha","glci","circleci","jenkins","azdo","bbp"] },
      "supply_chain":        { "namespaces": ["slsa","sbom","sarif","linux-foundation"] },
      "data_schema":         { "namespaces": ["oas","jsonschema","json","yaml","md"] },
      "regulatory_governance": { "namespaces": ["us-government","european-union","security-governance","industry-self-regulatory","owasp","observability","documentation","arch","_universal"] }
    }
  }
}
```

### 2.2. Sourcing (single source of truth)

The menu content is DERIVED from `active.json` (cite-or-decline preserved: only namespaces present in `active.json` appear). The **family grouping** is a small YAML table that CTP maintains — proposed location `commands/available-menu-families.yaml`:

```yaml
# available-menu-families.yaml — maps namespaces to functional families for Stage-0 reveal.
# When active.json grows with a new namespace, add it to the appropriate family here.
# Unfamilied namespaces surface under "other" with an explicit note.
families:
  frontend:            [react, google, typescript, w3c, web-vitals]
  backend:             [node, oas, jwt, iam, typescript, google]
  iac_vendor_neutral:  [k8s, helm, iac-linter, mesh, gitops]
  cloud:               [aws, azure, gcp, cfn]
  iac_tool:            [hashicorp, ansible, compose]
  ci_cd:               [gha, glci, circleci, jenkins, azdo, bbp]
  supply_chain:        [slsa, sbom, sarif, linux-foundation]
  data_schema:         [oas, jsonschema, json, yaml, md]
  regulatory_governance:
    [us-government, european-union, security-governance, industry-self-regulatory,
     owasp, observability, documentation, arch, _universal]
```

Namespaces can appear in multiple families (e.g. `typescript` in both `frontend` and `backend`) — that's correct, not a bug.

### 2.3. Semantics — reveal ≠ commit

**Namespaces in `available_menu` DO NOT enter `stack[]` or `activated_probe_namespaces`.** They are purely informational — a reveal of expertise available for later commitment. The `--stack-add` verb still fires only at commitment junctures per §30.5. No changes to §30.5, §30.6, or the probe-activation machinery.

### 2.4. Optional annotation — "activated" flag

Each namespace in the menu MAY be annotated with an `activated` boolean, mirroring whether it's already in `activated_probe_namespaces`, so the operator sees at a glance what's live vs. latent:

```json
"regulatory_governance": {
  "namespaces": [
    { "ns": "us-government", "activated": true },
    { "ns": "european-union", "activated": true },
    { "ns": "security-governance", "activated": true },
    { "ns": "industry-self-regulatory", "activated": false, "note": "in-scope, no probe pack" }
  ]
}
```

This annotation is a UX affordance; it doesn't change semantics.

---

## 3. Compat + rollout

- **Schema:** additive to `workload_classification` on the v1.1 profile. v1.0 profiles unaffected (they don't emit `workload_classification` at all). Consumers that don't know about `available_menu` ignore it — no breakage.
- **`--validate-profile`:** MUST NOT require `available_menu` on v1.1 profiles missing it (additive-optional discipline, per ADR-0089 precedent). Presence is checked shape-only (object with family keys → namespace lists); absence is silently accepted for backward compat.
- **Cite-or-decline preservation:** menu contents are filtered against `active.json`. A namespace listed in `available-menu-families.yaml` but absent from `active.json` MUST NOT appear in the emitted menu (silent drop, not error — matches existing behavior for absent probe groups).
- **Monotone:** menu grows if `active.json` grows; never shrinks silently. If a namespace is removed from `active.json`, it drops from the menu (correct — the expertise is gone).
- **Prime-directive-preserving:** no cross-repo edits from GCTP required. GCTP's `--validate-profile` gains a shape check for `available_menu` (one line of node) but does not require it.
- **Compact-safe (docs/agent-operating-compact.md):** reveal ≠ commit is explicitly enforced by the semantics — the agent cannot phantom-commit tech because the menu is separate from `stack[]` and `activated_probe_namespaces`. The compact's "no architecting without user commitment" invariant is strengthened, not weakened.

---

## 4. Acceptance test outline (Tier A, ~6 assertions)

Non-normative; CTP owns the authoritative test corpus in `evals/`.

1. **A.1 baseline emit:** `--classify` on the SoftArchCert vision emits `available_menu` with all 9 expected family keys.
2. **A.2 cite-or-decline:** every namespace surfaced in `available_menu` is present in `active.json` (`.rules[].source_namespace`).
3. **A.3 reveal ≠ commit:** none of the menu-only namespaces (those NOT in `activated_probe_namespaces`) appear in `stack[]` or `activated_probe_namespaces`.
4. **A.4 activated annotation coherent:** every entry marked `activated: true` in the menu IS in `activated_probe_namespaces`; every `activated: false` is NOT.
5. **A.5 back-compat v1.0:** running the legacy `business-intake.sh --list-questions` path does not emit `available_menu` (v1.0 unchanged).
6. **A.6 monotone:** identical vision + identical `active.json` → identical `available_menu` (deterministic); adding a namespace to `active.json` grows the menu on re-classify; removing shrinks.

---

## 5. Precedent + placement in the P-series arc

- **P-12 (§30 full-surface intake, adopted at pin `f060a8e` per ADR-0087)** established the v1.1 profile shape and moved intake from universal-only (v1.0) to universal + per-namespace probes.
- **P-13 (§30.4 core fix + §30.5 stack-driven progressive activation + §30.6 stack entry shape, adopted at pin `11126a8` per ADR-0091)** made rule activation progressive across all commitment junctures.
- **P-14 (this proposal, §30.7 non-committing full-surface reveal)** closes the last "expertise interfacing" gap in the intake experience: the operator now sees the full plug-in expertise at Stage 0 while §30.5's commit-at-junctures discipline remains intact.

Same class, same discipline: additive per ADR-0047, zero deletions, monotone, prime-directive-preserving, compact-safe. Extends the P-12/P-13 arc from "progressive commitment" to "informed progressive commitment."

---

## 6. Coordination back to GCTP (post-adoption)

Once CTP tags v1.16 with §30.7:

1. **§15-gated pin bump** via new ADR (path: `docs/adr/0092-plugin-pin-bump-11126a8-to-<new>.md`).
2. `scripts/consult.sh --validate-profile` — additive shape check for `available_menu` (already tolerant of missing; add one-line check that when present, the shape is `{family: {namespaces: [ns|obj]}}`).
3. `.claude/commands/consult.md §1a` — Stage-0 language updated to reflect the new reveal ("Show the classifier output *and* the available_menu — 'here is the full expertise available; you'll commit to families in Stage 1 and design-junctures'").
4. `.harness/consult-work/_tools/kata.sh gap-check` — heuristic can now READ `available_menu` and only flag genuinely-missing family namespaces (avoids the current false-positive of flagging `arch`/`observability` when they're already in the always-on activated set).
5. GCTP-side follow-up TICKET filed against `TICKETS.md` at post-adoption time.

---

## 7. References

- Kata gaps log (this filing's origin): [`.harness/consult-work/FEATURE-003/gaps-log.md`](../.harness/consult-work/FEATURE-003/gaps-log.md) §G-1
- Verbatim operator directives (preserved): [`.harness/consult-work/FEATURE-003/PROMPTS.md`](../.harness/consult-work/FEATURE-003/PROMPTS.md)
- Agent operating compact (compact-safety framing): [`docs/agent-operating-compact.md`](agent-operating-compact.md)
- ADR-0047 (additive-never-subtractive standards): [`docs/adr/0047-eo-standards-are-additive-never-subtractive.md`](adr/0047-eo-additive-never-subtractive.md) *(if numbered differently, see ADRs referencing "additive per ADR-0047" in P-13)*
- P-12 handoff: [`docs/handoff-ctp-p12-full-surface-intake.md`](handoff-ctp-p12-full-surface-intake.md)
- P-13 handoff: [`docs/handoff-ctp-p13-cloud-classification-from-answers.md`](handoff-ctp-p13-cloud-classification-from-answers.md)
- ADR-0087 (P-12 adoption): [`docs/adr/0087-plugin-pin-bump-<sha>-<sha>.md`](adr/) — exact filename per pin bump doc
- ADR-0091 (P-13 adoption): [`docs/adr/0091-plugin-pin-bump-f39fcdc-to-11126a8.md`](adr/0091-plugin-pin-bump-f39fcdc-to-11126a8.md)
- Handoff contract (schema hosting §Business-Intake): [`docs/handoff-contract.md`](handoff-contract.md)
