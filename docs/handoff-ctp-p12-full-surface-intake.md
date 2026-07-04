# GCTP → CTP handoff — P-12: full-surface intake (extend `business-intake.sh` to consult the whole rule surface at seed time)

**Written:** 2026-07-04 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `0cf28fe`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Ask:** amend CTP's `commands/business-intake.sh` (and the two engines that consume its output) so that the workload questionnaire is grounded in **every rule namespace with a first-order business question**, not only the four business-requirements catalog sources it uses today. Ship as **v1.14 §27.16 — Full-Surface Intake**. Additive per ADR-0047. GCTP re-pins after CTP tags v1.14.

---

## Companion supplementary materials (this repo)

- **This document** — the reasoning + proposal + acceptance framing (start here).
- **`docs/handoff-ctp-p12-namespace-question-manifest.md`** — concrete namespace × question × source manifest that the question bank builds against. Marks every `source_id` as ✓ EXISTS in CTP catalogs at pin `0cf28fe` vs. ⊕ NEW (needs adding). CTP has less new source work than §3 of this doc implies — most citations are already in the catalogs.
- **`docs/handoff-ctp-p12-sample-profile-v1.1.json`** — a concrete target `business-profile.json` in the v1.1 shape (modeled on the Certifiable, Inc. kata). Useful as a schema-validation target and as an eval fixture.
- **`docs/handoff-ctp-p12-acceptance-test.sh`** — a machine-verifiable acceptance test CTP can run locally against the `dev/v1.14-full-surface-intake` branch tip before tagging. Non-normative — CTP owns the authoritative test corpus in `evals/`.

**Correction to §1 counts in this document.** Ground truth verified against `.harness/rules/active.json` at pin `0cf28fe`: **118 rules across 42 namespaces** in `active.json`; the 43rd grounding group is `cloud-conventions` (IaC-convention set outside `active.json`). The "43" phrasing in this document is idiomatic for the full grounding surface but is technically 42+1. Manifest uses the precise breakdown.

## 0. TL;DR

`commands/business-intake.sh` asks 9 questions cited to **4 catalog sources** (`azure-waf-business-requirements`, `aws-rpo-rto-targets`, `nist-800-53`, `aws-wa-tool-profiles`). At pin `0cf28fe` the aggregated rule surface is **118 rules across 43 namespaces**. So the intake — the seed moment for every downstream decision — is informed by roughly **4 of ~43 expert namespaces**. Downstream stages (`business-translate.sh`, `architect-recommend.sh`, `architect-session.sh`) DO consume the full surface at write-time via §29..§29.6, but they can only check what intake surfaced; they cannot invent a business commitment (SLO level, WCAG target, SLSA level, AI-risk-tier, threat surface, ASVS level, identity federation depth, human-oversight commitment) that was never asked for. Symmetric fix to P-11: P-11 opened the full surface to the *design engines*; P-12 opens it to the *question engine* upstream of them. **v1.14 §27.16** adds a workload classifier + per-namespace probe groups + a backward-compat schema bump (`schema_version` 1.0 → 1.1). No question is removed. No rule is relaxed. Universal 9 stay universal.

## 1. The gap (evidence, deterministic)

```bash
# Empirical, from GCTP's plugin cache at pin 0cf28fe:
CLAUDE_PLUGIN_ROOT=".harness/plugin-cache/claude-tdd-pro" \
  bash .harness/plugin-cache/claude-tdd-pro/commands/business-intake.sh --list-questions \
  | node -e '
    const q = JSON.parse(require("fs").readFileSync(0,"utf8"));
    const sources = new Set(q.map(x=>x.source_id));
    console.log("questions:", q.length, "unique_source_ids:", sources.size);
    console.log("sources:", [...sources].sort().join(", "));'
# → questions: 9  unique_source_ids: 4
# → sources: aws-rpo-rto-targets, aws-wa-tool-profiles, azure-waf-business-requirements, nist-800-53

# Compare to the aggregated rule surface at the same pin:
node -e '
  const r = JSON.parse(require("fs").readFileSync(".harness/rules/active.json","utf8"));
  const ns = new Set(r.rules.map(x=>x.source_namespace));
  console.log("active.json rules:", r.rules.length, "namespaces:", ns.size);'
# → active.json rules: 118  namespaces: 43
```

Only **4 of 43** namespaces contribute expertise at the seed moment. The 39 missing namespaces include (non-exhaustive): `security-governance`, `us-government`, `owasp`, `slsa`, `iam`, `jwt`, `oas`, `k8s`, `helm`, `mesh`, `hashicorp`, `ansible`, `cfn`, `aws`, `azure`, `gcp`, `gitops`, `w3c`, `web-vitals`, `react`, `typescript`, `node`, `observability`, `arch`, `documentation`, `linux-foundation`, `sbom`, `sarif`, `bbp`, `gha`, `azdo`, `circleci`, `glci`, `jenkins`, `md`, `yaml`, `json`, `jsonschema`. Some (leaf-lint namespaces like `md`, `yaml`, `json`, `jsonschema`, `sarif`) have no first-order business question and can legitimately stay out of intake — write-time enforcement handles them. But roughly **30 of 43** carry a first-order business question that today is never asked.

**Impact on consumers (like P-11).** Every unasked question becomes an *implicit assumption* by the design engine — usually a permissive default. Consumers only discover the mismatch later, at write-time enforcement, and pay it back as **architectural rework loops** at code time. P-11 removed exactly this class of rework at design stage; P-12 removes it one stage earlier, at intake.

**Operator observation (verbatim, 2026-07-04):**
> "From the very beginning, I need the entire expertise of the entire plug-in to be interfacing with the user when asking the user about what they want to build. It creates the seed for the project from which it will divide and grow."

## 2. Proposal — v1.14 §27.16 Full-Surface Intake

Extend `commands/business-intake.sh` from a **fixed 9-question set grounded in 4 sources** to a **conditional cascade grounded across the full expert surface**. Two additive stages on top of the current one:

| Stage | What runs | Always active? | New in v1.14 |
|---|---|---|---|
| **0. Classifier** | Reads workload free-text; emits `workload-classification.json` with detected signals (`web-ui`, `backend`, `cli`, `data-pipeline`, `ml-ai`, `regulated`, `multi-tenant`, `public-facing`, `container-first`, `serverless-first`, `iac-heavy`, `mobile`, `government`, `ai-high-risk`). | yes | ✅ new |
| **1. Universal probes** | The existing 9 questions (workload, motivation, criticality, RTO, RPO, sensitivity, compliance, scale, budget). Answers land under `probes.universal`. | yes | unchanged |
| **2. Per-namespace probes** | Namespace-scoped question groups; only groups matching classifier signals fire. Each question grounded in a `source_id`. Answers land under `probes.<namespace>`. | conditional | ✅ new |

**Additivity invariant (ADR-0047 compliance).** No universal question is removed. No question is downgraded. Every stage-2 question is an *addition*; every activation predicate can only turn a group ON. `grounded_in` is monotonically increasing vs. v1.0 for the same profile: strict superset. Cite-or-decline holds — every stage-2 question sourced to a `source_id` that resolves in one of the five catalogs.

**Backward compatibility.** `schema_version: "1.0"` profiles continue to validate + translate + recommend unchanged. `schema_version: "1.1"` adds classifier + `probes` object; downstream stages MUST accept both shapes.

**Sample per-namespace groups (skeleton — full list in `standards/business-intake-question-bank.yaml`):**

| Namespace | Activation signals | Sample question keys | `source_id`(s) |
|---|---|---|---|
| `security-governance` / `eo` / `us-government` | `ai-high-risk`, `regulated`, `government` | `ai_risk_tier`, `human_oversight_commitment`, `explainability_commitment`, `provenance_commitment` | `eu-ai-act-annex-iii`, `eu-ai-act-art-13`, `eu-ai-act-art-14`, `nist-ai-rmf-1.0`, `eo-2026-4-ai-security` |
| `owasp` | `public-facing`, `multi-tenant`, `regulated` | `asvs_level`, `threat_surface` | `owasp-asvs`, `owasp-top-10` |
| `slsa` | always | `slsa_level_commitment` | `slsa-spec` |
| `iam` | always | `identity_federation`, `mfa_scope` | `oauth2-oidc`, `nist-800-63b` |
| `observability` | always | `slo_commitment`, `telemetry_posture` | `google-sre-book`, `opentelemetry-docs` |
| `w3c` | `web-ui` | `wcag_commitment` | `wcag-2.2` |
| `web-vitals` | `web-ui`, `public-facing` | `cwv_commitment` | `web-vitals-thresholds` |
| `react` | `web-ui` + react-signal | `ssr_hydration_posture`, `strict_mode_commitment` | `react-best-practices` |
| `typescript` / `node` | ts/node signal | `runtime_target`, `strict_mode_commitment` | `typescript-handbook`, `node-best-practices` |
| `k8s` / `helm` / `mesh` | `container-first` | `resource_limits_posture`, `probe_posture` | `k8s-production-best-practices` |
| `hashicorp` / `iac-linter` | `iac-heavy` | `pin_posture`, `provider_lock_posture` | `hashicorp-terraform-best-practices` |
| `arch` | always | `contract_first_commitment`, `boundary_style` | `nygard-adr`, `newman-microservices` |
| `testing` | always | `test_rigor`, `mutation_commitment` | `fowler-test-pyramid` |
| `dependencies` | always | `dependency_update_cadence` | `renovate-best-practices`, `google-eng-practices` |
| `documentation` | always | `adr_discipline`, `architecture_doc_commitment` | `nygard-adr` |
| `sbom` | always | `sbom_commitment` | `cyclonedx-spec` |
| `bbp` | `public-facing`, `regulated` | `bug-bounty_posture` | `bbp-best-practices` |
| `gha` / `azdo` / `circleci` / `glci` / `jenkins` | ci-signal | `ci_provider`, `runner_isolation_posture` | provider-specific |

(Not every namespace needs a probe. Leaf-lint namespaces — `md`, `yaml`, `json`, `jsonschema`, `sarif` — have no first-order business question; write-time enforcement suffices.)

## 3. File locations (repo-relative, in `claude-tdd-pro`)

```
Repo:     drumfiend21/claude-tdd-pro
Branch:   dev/v1.14-full-surface-intake   (base: main)
Tag:      v1.14 (on release)

MODIFY  commands/business-intake.sh
        · Add --classify stage (workload text → signals JSON).
        · Extend --list-questions JSON: probe_group + activation per Q.
        · Bump schema_version "1.0" → "1.1" (backward-compat on read).
        · grounded_in aggregates source_ids across ALL answered probes.

MODIFY  commands/business-translate.sh
        · Accept schema_version 1.0 AND 1.1 profiles.
        · Map new namespace-scoped committed postures to their
          pillar/concern (asvs_level → security rigor; slo_commitment
          → op-excellence SLO; slsa_level_commitment → security
          supply-chain; wcag_commitment → performance/UX access;
          human_oversight_commitment → EO governance; etc.).
        · needs_grounding=0 discipline preserved.

MODIFY  commands/architect-recommend.sh
        · Use committed postures when scoring options (weights).
        · Grounded_in accumulates per-namespace source_ids.

MODIFY  commands/architect-session.sh
        · Orchestration: call --classify BEFORE intake so the correct
          probe groups activate when the agent walks the questionnaire.
        · Session bundle includes workload-classification.json.

NEW     standards/business-intake-workload-classifier.yaml
        Signals → activation rules (keywords / regex on workload text).

NEW     standards/business-intake-question-bank.yaml
        Per-namespace probe groups (structure per §2 table above).

NEW     schemas/business-profile.schema.json
        JSON Schema for business-profile.json (v1.0 AND v1.1).
        Referenced by CTP's existing schema-validate machinery.

EXTEND  standards/eo-security-sources.yaml
        Add: eu-ai-act-annex-iii, eu-ai-act-art-13, eu-ai-act-art-14,
        eu-ai-act-art-15, nist-ai-rmf-1.0, eo-2026-4-ai-security.

EXTEND  standards/cloud-architecture-sources.yaml
        Add any missing: nist-800-63b, slsa-spec, wcag-2.2,
        web-vitals-thresholds, owasp-asvs, owasp-top-10,
        fowler-test-pyramid, nygard-adr, renovate-best-practices,
        k8s-production-best-practices, hashicorp-terraform-best-
        practices, cyclonedx-spec, react-best-practices, node-best-
        practices, typescript-handbook, newman-microservices.
        (Dedupe against existing standards/*.yaml.)

MODIFY  docs/architecture-v1.9.md (or current architecture doc)
        Append §27.16 "Full-Surface Intake" — motivation (seed argument),
        mechanics, boundary (contract surface), additivity invariant.

NEW     evals/business-intake-v1.14-eval.yaml
        (or wherever CTP places eval fixtures — mirror existing pattern)
        Cases:
          · web-ui + public-facing workload activates w3c, web-vitals,
            react, owasp, iam, observability, slsa, testing,
            dependencies, documentation, universal.
          · ai-high-risk workload (grading, credentialing) activates
            security-governance, us-government, eo, iam, observability,
            testing, dependencies, documentation, universal.
          · schema_version 1.0 profile still validates + translates.
          · grounded_in monotonicity: v1.1 grounded_in ⊇ v1.0
            grounded_in for the same workload.
          · Every stage-2 source_id resolves in a standards/*.yaml
            catalog AND to at least one active.json rule namespace.
```

## 4. Backward compatibility

Guaranteed by construction:

- `schema_version: "1.0"` profiles continue to validate + translate + recommend unchanged; downstream MUST accept both shapes (mirrors §29's additive discipline).
- The universal-9 question keys keep their existing key names, enums, and `source_id`s.
- `business-profile.json` v1.1 is a **strict superset** of v1.0: same top-level `answers` block remains (deprecated but supported); new content lives under `workload_classification` + `probes.<namespace>`.
- `grounded_in` in v1.1 is a superset of what v1.0 would emit for the same workload (never a subset).
- No existing consumer command is renamed or removed.
- No existing rule is relaxed. Every new activation predicate can only turn a group ON.

## 5. Acceptance (CTP-side, before tagging v1.14)

1. `--list-questions` for a workload matching multiple classifier signals returns > 9 questions with correct `probe_group` tagging.
2. A completed v1.1 profile has `grounded_in` with `source_id`s from **≥ 10 namespaces** (up from today's 4).
3. Every new `source_id` resolves in a `standards/*.yaml` catalog AND to at least one namespace in `active.json`.
4. Every v1.0 profile in the existing eval corpus still validates + translates + recommends **identically to today** (regression baseline).
5. New v1.14 eval fixtures pass; CTP's existing SKILL trio (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) tests still pass.
6. Bash 3.2 portability preserved for `business-intake.sh` per `tdd-pro-bash32-portability` (empty-array guards, no associative arrays, `set -u` clean).

## 6. Coordination back to GCTP (after v1.14 tags)

1. CTP tags `v1.14` and pushes; notify GCTP with the commit SHA.
2. GCTP re-pins `docs/claude-tdd-pro.lock.yaml` `0cf28fe → <v1.14>` via an **ADR-gated pin bump** (the ADR-0086 procedure, contract-drift-checked).
3. GCTP updates `docs/handoff-contract.md` with the extended `§Business-Intake` schema section (schema_version 1.1 shape + classifier + probes).
4. GCTP extends `scripts/consult.sh --validate` to check for `workload_classification` + activated `probes.<namespace>` presence when `schema_version ≥ 1.1`.
5. GCTP extends `scripts/audit-architecture-crosscheck.sh` to verify every activated probe group's committed posture propagates into at least one `decisions[]` juncture's `applicable_rules`.
6. GCTP updates the `/consult` skill to walk Stage 0 → Stage 1 → Stage 2 cascade (classifier reveal, universal, activated per-namespace groups).
7. GCTP flips `docs/upstream-ctp-proposals.md` §P-12 📋 FILED → ✅ ADOPTED at that pin.

All GCTP-side follow-up scoped as **TICKET-114** in this repo's `TICKETS.md` (queued, blocked on CTP release).

## 7. Boundary contract (what crosses)

The interface surfaces between the two repos for this amendment are exactly three:

1. **`business-profile.json` schema.** CTP owns; GCTP consumes. v1.1 backward-compat.
2. **`business-intake.sh --list-questions` JSON output.** CTP owns; GCTP walks. Extended with `probe_group` + `activation` per question.
3. **Question `source_id` ↔ `active.json` rule namespace mapping.** Traceability invariant: every question sourced to a `source_id` resolvable in one of the five catalogs AND resolving to at least one `active.json` namespace.

Nothing else crosses. Prime-directive-preserving.

## 8. Context / cross-refs

- **Supplementary materials in this repo (bundled with this handoff):**
  - `docs/handoff-ctp-p12-namespace-question-manifest.md` (build spec, ~30 namespaces × questions × sources, with catalog-existence markers).
  - `docs/handoff-ctp-p12-sample-profile-v1.1.json` (target on-disk shape).
  - `docs/handoff-ctp-p12-acceptance-test.sh` (runnable local acceptance check).
- **GCTP-side prep (already landed in this repo before v1.14 tag):** `docs/handoff-contract.md §Business-Intake — SHAPE PENDING CTP v1.14` documents the anticipated consumer contract so `/consult` and the audit spine can be wired against a known target.
- **GCTP proposal index:** `docs/upstream-ctp-proposals.md` §P-12 (📋 FILED, this handoff).
- **Precedent — same class, one stage downstream:** P-11 → CL-541..CL-545 (§29..§29.6) → ADR-0086 at pin `0cf28fe`. P-11 opened the full 118-rule / 43-namespace surface to CTP's *design* engines. P-12 opens it to the *question* engine upstream of them. Symmetric fix.
- **Additivity discipline:** ADR-0047 (additive/never-subtractive EO layer principle) — this proposal generalizes ADR-0047 from "EO layer" to "every namespace with a first-order business question."
- **Related design principle:** the seed argument. Downstream stages enforce; only intake can *shape*. Rework loops surface at the earliest stage that could have prevented them — that is intake, not design.
- **GCTP current pin:** `0cf28fe`. Prime directive: GCTP consumes CTP by pinned reference only and does not edit the plugin — hence this handoff rather than a cross-repo patch.
- **Ruby ≥ 3.0 dependency:** the consult loop already hard-stops without ruby (ADR-0056 D-D). v1.14 does not change this contract.
