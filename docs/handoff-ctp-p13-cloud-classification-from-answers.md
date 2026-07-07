# GCTP → CTP handoff — P-13: cloud identification + classification from operator answers (not only vision text)

**Written:** 2026-07-07 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `f39fcdc`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Ask:** amend `commands/full-surface-intake.sh` (S-57) so that operator-stated cloud in a business answer activates the corresponding cloud `workload_type` (`aws-platform` / `azure-platform` / `gcp-platform` / `cloudformation`) and its probe group. Today the classifier haystack is *only* the vision text; a cloud-agnostic vision (like the Certifiable, Inc. kata) never fires a cloud type even when the operator explicitly names one. Ship as **v1.15 §30.4 — Classifier over vision + answers**. Additive per ADR-0047. GCTP re-pins after CTP tags v1.15.

**CTP maintainer's standing offer (verbatim, from the resume-kata handoff §4):** *"If you want the classifier to fire `aws-platform` when the operator states 'AWS' in a business answer, that's a small CTP-side signal addition — tell me and I'll add it; otherwise the design-stage sourcing is correct."* This is the take-you-up on that offer, filed with a concrete design + acceptance test so it can land inline like CL-547 / CL-548 / CL-549.

---

## Companion supplementary materials (this repo)

- **This document** — reasoning + proposal + acceptance framing (start here).
- **`docs/handoff-ctp-p13-acceptance-test.sh`** — machine-verifiable acceptance test CTP can run locally against the `dev/v1.15-cloud-classify-from-answers` branch tip before tagging. Non-normative — CTP owns the authoritative test corpus in `evals/`.

## 0. TL;DR

At pin `f39fcdc` the S-57 classifier haystack is **only** the workload/vision text (falls back to `answers.workload` if `--workload` is empty). Universal answers, `--answer key=value` inputs, and probe answers are NOT in the haystack. Consequence: on a cloud-agnostic vision like the Certifiable, Inc. kata (which never says "AWS"), the classifier fires NO cloud platform type — so Stage 2 never asks the AWS-specific probes (aws region strategy, cfn stack policy, etc.), even when the operator explicitly states "we're deploying to AWS" at Stage 1. Cloud is a **design decision, not a vision fact**, and the operator's clearest signal is often *the answer they give*, not the free-text vision. **v1.15 §30.4** extends the classifier haystack to include universal-answer values (Core Fix, small + safe), and optionally seeds a `target_platform` universal question for explicit sourcing (Extension). Both are strict supersets of §30.3 behavior — the classifier can only fire MORE types, never fewer, so no v1.0 or v1.1 profile regresses.

## 1. The gap (evidence, deterministic at pin `f39fcdc`)

The current haystack construction, from `.harness/plugin-cache/claude-tdd-pro/commands/full-surface-intake.sh @ f39fcdc`:

```ruby
# lines 109–114 (approx)
u_answers = universal["answers"] || {}
# Workload text: --workload else answers.workload.
wl = ENV["WORKLOAD"].to_s.strip
wl = u_answers["workload"].to_s if wl.empty?
hay = wl.downcase
```

The classifier reads `--workload` (or `answers.workload` as fallback), lowercases it, and matches signals against that single string. Every other universal answer key (`motivation`, `criticality`, `rto_target`, `rpo_target`, `sensitivity`, `compliance`, `scale`, `budget`) is invisible to the classifier. Probe answers (which come later anyway) are also invisible.

**Reproduce:** on the real Certifiable, Inc. kata vision (which the CTP resume-kata handoff §3 confirms is cloud-agnostic):

```bash
# Vision-only classification — no cloud fires (correct, but incomplete)
CLAUDE_PLUGIN_ROOT=.harness/plugin-cache/claude-tdd-pro \
bash .harness/plugin-cache/claude-tdd-pro/commands/full-surface-intake.sh \
  --workload "$(cat certifiable-vision.txt)" \
  --classify
# → workload_types=ai-governed,baseline-quality
# → activated_probes=6 (documentation, european-union, observability, owasp, security-governance, us-government)
# → NO aws / azure / gcp / cfn activated

# Same vision + operator explicitly stating "target=AWS" — STILL no cloud fires (bug)
CLAUDE_PLUGIN_ROOT=.harness/plugin-cache/claude-tdd-pro \
bash .harness/plugin-cache/claude-tdd-pro/commands/full-surface-intake.sh \
  --workload "$(cat certifiable-vision.txt)" \
  --answer motivation="reduce grading burden on AWS Bedrock" \
  --classify
# → workload_types=ai-governed,baseline-quality (UNCHANGED)
# → aws-platform DID NOT FIRE despite "AWS" appearing in a universal answer.
```

**Operator observation (verbatim, 2026-07-07):**
> "Cloud identification and classification needs to work during consult."

**Symmetric to P-12's discovery pattern.** P-12 opened the intake from 4 to 43 namespaces (full-surface probe activation). P-13 opens the *classification input* itself from vision-only to vision + operator answers — otherwise the full-surface probes for cloud namespaces can never activate on cloud-agnostic visions, no matter how explicit the operator later becomes.

## 2. Proposal — v1.15 §30.4 Classifier over vision + answers

Two changes, one MUST-HAVE (Core) and one RECOMMENDED (Extension). Both strict supersets of §30.3 behavior.

### 2.1. Core Fix — extend the haystack to include universal-answer values

Change the haystack construction in `commands/full-surface-intake.sh` from vision-only to vision + universal-answer values:

```ruby
# Current (§30.3, pin f39fcdc):
wl = ENV["WORKLOAD"].to_s.strip
wl = u_answers["workload"].to_s if wl.empty?
hay = wl.downcase

# Proposed (§30.4):
wl = ENV["WORKLOAD"].to_s.strip
wl = u_answers["workload"].to_s if wl.empty?
# §30.4: include operator-stated universal answers in the classifier haystack so a
# cloud-agnostic vision + an explicit "target=aws" business answer activates aws-platform.
# Values only, not keys — a key like "target_platform" is not a signal; the value "aws" is.
answer_hay = u_answers.values.map { |v| v.to_s }.join(" ")
hay = "#{wl} #{answer_hay}".downcase
```

That is the entire semantic change. Word-boundary matching (§30.3) still applies, so `aws` in `answers.target_platform="aws"` fires `aws-platform` cleanly without also matching inside larger words in some other answer.

**Additivity invariant.** Monotone by construction — the haystack can only grow (never shrink), so the classifier can only fire MORE types, never fewer. Every v1.0 and v1.1 profile emitted before §30.4 continues to validate + translate + recommend unchanged (their `workload_types` set is a subset of the §30.4 result for the same inputs).

**Precedence stays natural.** Vision text remains first in the haystack (word-boundary matching means position doesn't affect matching, but keeping vision first keeps operator diagnostics readable — the vision remains the primary source of truth for "what are we building").

### 2.2. Extension (RECOMMENDED) — universal `target_platform` question

Even with Core Fix, the operator only signals cloud if they happen to name it in a business answer. For deterministic sourcing, add ONE universal question:

```yaml
# In standards/business-intake-question-bank.yaml, universal section:
- key: target_platform
  source_id: aws-wa-tool-profiles   # (or nist-800-53, or a new business-platform-sourcing source_id)
  cite_or_decline: true
  prompt: >
    Which target platform will host this workload? Choose the primary compute/data plane.
  enum: [aws, azure, gcp, on-prem, hybrid, undecided]
  optional: false
```

The value goes into `answers.target_platform`, which Core Fix (2.1) then feeds into the classifier haystack. `undecided` fires nothing (correct — no committed posture yet); `on-prem` and `hybrid` fire nothing new but are captured for downstream engines; `aws` / `azure` / `gcp` each fire their respective platform type.

**Additivity invariant.** Adds ONE universal question; universal-9 becomes universal-10. Strict superset of the current schema. v1.0/v1.1 profiles emitted before §30.4 remain valid — the additive question is optional-in-effect for pre-§30.4 profiles (schema check MUST NOT require `target_platform` on profiles missing it). If CTP prefers to keep universal-9 sacred, ship Core Fix only — Extension can land as a follow-on §30.5 or be part of v1.16.

**Grounding.** `aws-wa-tool-profiles` is a natural fit (the AWS Well-Architected profile-selection prompt itself asks "which workload" — same construct); or use `nist-800-53 CM-2` (baseline configuration → target platform is a baseline dimension); or a new `source_id` if CTP prefers first-order sourcing. Either way, cite-or-decline holds.

## 3. Boundary contract (what crosses to GCTP)

- **`business-profile.json` schema:** unchanged (v1.1 shape stable). If Extension ships, the profile carries `answers.target_platform` as an additive optional key — but that's just a new entry in the existing `answers` object, not a schema shape change.
- **`--list-questions` JSON output:** if Extension ships, one additional universal question appears in the array.
- **`--classify` JSON output:** shape unchanged; the `workload_types` set can grow (never shrink) for the same inputs.

Nothing else crosses. Prime-directive-preserving.

## 4. Coordination back to GCTP (post-adoption)

At the new pin (v1.15):

1. **§15-gated pin bump** via new ADR (pattern per ADR-0087 / ADR-0089 / ADR-0090); contract drift check permits only additive changes (`architecture-v1.9.md` §30.4 append; `full-surface-intake.sh` haystack edit; question bank +1 optional entry if Extension shipped).
2. **`docs/handoff-contract.md §Business-Intake`:** append a bullet noting the classifier-over-answers refinement; contract invariants unchanged.
3. **`scripts/consult.sh --validate-profile`:** no change if Core Fix only. If Extension ships, the check MUST NOT require `answers.target_platform` on v1.1 profiles missing it (additive-optional discipline).
4. **`scripts/audit-architecture-crosscheck.sh` invariant 4:** no change (keys on `activated_probe_namespaces`, which §30.4 makes more precise — never less).
5. **`/consult` skill:** Stage 0 walk unchanged; Stage 1 gains the `target_platform` question if Extension ships, which the skill translates plainly to the operator ("which cloud will host this workload — AWS, Azure, GCP, on-prem, hybrid, or undecided?").
6. **Flip P-13 status** in `docs/upstream-ctp-proposals.md` 📋 FILED → ✅ ADOPTED.

## 5. Acceptance test (machine-verifiable)

See `docs/handoff-ctp-p13-acceptance-test.sh`. Twelve assertions covering:

- **Core Fix regression baseline (pre-§30.4):** cloud-agnostic vision + `--answer motivation="on AWS"` does NOT fire `aws-platform` (documents the bug this closes).
- **Core Fix core assertion:** same input at v1.15 DOES fire `aws-platform` and activates the `aws` probe group.
- **Core Fix monotonicity:** every workload_type fired at §30.3 for a given input is still fired at §30.4 (subset preservation).
- **Word-boundary preservation:** operator answer `motivation="reduce leaks"` does NOT fire `azure-platform` (regression check for §30.3 word-boundary matching over the new haystack).
- **Multi-cloud disambiguation:** `--answer target_platform=aws` fires `aws-platform` only; `azure`/`gcp` do NOT fire (precise classification, per §30.2 discipline).
- **Undecided/on-prem/hybrid:** no cloud platform type fires (correct — no committed cloud posture).
- **Vision-priority ordering:** for an operator answer that contradicts the vision (e.g., vision explicitly says AWS but operator answer says GCP), both fire (union — the classifier is a signal detector, not a preference selector; downstream engines resolve conflicts).
- **v1.0 back-compat:** v1.0 profile emitted before §30.4 validates unchanged.
- **v1.1 back-compat:** v1.1 profile emitted at §30.3 validates unchanged at §30.4.
- **Extension shape:** if `target_platform` question ships, `--list-questions` returns 10 universal questions and the new entry has `cite_or_decline: true`.
- **Extension optional-in-effect:** a v1.1 profile missing `answers.target_platform` still validates.
- **Grounding-integrity:** every activated cloud probe group's `source_id` resolves in `active.json` (namespace + rule floor still traceable).

## 6. Precedent

P-12 → CL-546 → ADR-0087 (§30 intake). CL-547 → ADR-0088 (§30.1 design consumption). CL-548 → ADR-0089 (§30.2 precise cloud types + IaC probes + transparency). CL-549 → ADR-0090 (§30.3 word-boundary matching). Same class, same discipline; P-13 extends the *input surface* of the classifier from vision-only to vision + answers — closes the last cloud-agnostic-vision loophole for the kata cycle. Named "§30.4" because it's the natural fourth close-out of the same intake-precision arc.

## 7. Boundary (unchanged)

CTP owns the classifier + question bank content; GCTP owns the consumer surface. This proposal is one small edit inside `commands/full-surface-intake.sh` (the haystack line) plus, optionally, one small addition to `standards/business-intake-question-bank.yaml`. No consumer-side reconciliation required for Core Fix; Extension needs one line of `--validate-profile` tolerance (already the discipline — additive keys are optional). Additive per ADR-0047, zero deletions.
