# GCTP → CTP handoff — P-13: stack-driven progressive rule activation (cloud classification from operator answers as the motivating case)

**Written:** 2026-07-07 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `f39fcdc`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Ask:** amend the intake + design cascade so **any technology committed at any stage** — Stage-0 classifier, Stage-1 universal answer, Stage-2 probe answer, design-time decision, or explicit operator injection — is captured into a persistent `workload_classification.stack[]` array, and each append **hunts for and activates** the rules keyed by that technology's namespace in `active.json`. The current classifier is a one-shot pass over the vision text; a mid-consult AWS decision is invisible to it, so cloud rules never activate. Ship as **v1.15 §30.4 (Core Fix)** + **§30.5 (Structural Extension)**. Additive per ADR-0047. GCTP re-pins after CTP tags v1.15.

**CTP maintainer's standing offer (verbatim, from the resume-kata handoff §4):** *"If you want the classifier to fire `aws-platform` when the operator states 'AWS' in a business answer, that's a small CTP-side signal addition — tell me and I'll add it; otherwise the design-stage sourcing is correct."* This proposal takes that offer and generalizes it — the small signal addition is the Core Fix; the general mechanism it implies is the Structural Extension.

---

## Companion supplementary materials (this repo)

- **This document** — reasoning + proposal + acceptance framing (start here).
- **`docs/handoff-ctp-p13-acceptance-test.sh`** — machine-verifiable acceptance test CTP can run locally against the `dev/v1.15-stack-driven` branch tip before tagging. Non-normative — CTP owns the authoritative test corpus in `evals/`.

## 0. TL;DR

The classifier at pin `f39fcdc` runs once, at Stage 0, over the vision text. Every other technology signal — universal answers, probe answers, mid-consult design decisions, operator directives — is **invisible** to the rule-activation mechanism. On a cloud-agnostic vision like the Certifiable, Inc. kata, this means the operator can explicitly state "we're deploying to AWS" in a business answer and the classifier still fires no `aws-platform`, so the `aws` / `cfn` probe groups never activate and cloud-specific rules (aws-region-strategy, cfn-stack-policy) are never applied to the architecture.

**The proposed mechanism (operator's framing):** carry a persistent `stack[]` on the profile. Any decision at any stage that commits a technology appends to `stack`. Each append triggers a lookup in `active.json` by `source_namespace` — pulling in every rule for that technology — plus activation of the corresponding probe group. The classifier becomes ONE of many stack-append sources, not the only source. Rule activation becomes **progressive and iterative**, not fixed at intake.

Ship as two composed changes:
- **§30.4 Core Fix** — the classifier haystack unions in universal-answer values, so an AWS mention in an answer *does* fire `aws-platform` (unblocks the immediate bug). This is a one-line edit.
- **§30.5 Structural Extension** — the general stack-driven mechanism: `stack[]` on the profile, append hook, namespace-keyed rule/probe lookup, invocable from all downstream stages.

Additive per ADR-0047. Monotone by construction (stack only grows during a consult; classifier can only fire MORE types, never fewer). Every v1.0 and v1.1 profile emitted before §30.4 continues to validate + translate + recommend unchanged.

## 1. The gap (evidence, deterministic at pin `f39fcdc`)

### 1.1. Vision-only classifier haystack

The classifier haystack is constructed as `hay = wl.downcase` where `wl` is the vision text (or `answers.workload` as fallback). Every other universal answer key (`motivation`, `criticality`, `rto_target`, `rpo_target`, `sensitivity`, `compliance`, `scale`, `budget`) is invisible to the classifier. Probe answers and design decisions are also invisible.

**Reproduce:** on the real Certifiable, Inc. kata vision (correctly cloud-agnostic — the AWS choice is an engineering decision, not a vision fact):

```bash
# Vision-only classification — no cloud fires (correct given the input)
bash commands/full-surface-intake.sh --workload "$(cat certifiable-vision.txt)" --classify
# → workload_types=ai-governed,baseline-quality
# → NO aws / azure / gcp / cfn activated

# Vision + operator explicitly stating AWS in a universal answer — STILL no cloud fires (bug)
bash commands/full-surface-intake.sh \
  --workload "$(cat certifiable-vision.txt)" \
  --answer motivation="reduce grading burden using AWS Bedrock" \
  --classify
# → workload_types=ai-governed,baseline-quality (UNCHANGED)
# → aws-platform DID NOT fire despite explicit AWS mention.
```

### 1.2. No stack of committed technologies

`business-profile.json` v1.1 at pin `f39fcdc` carries `workload_classification.{workload_types, namespaces, activated_probe_namespaces, unprobed_in_scope}`. It does NOT carry a first-class record of the specific technologies that end up in the actual stack. The classifier's derived namespaces are the closest thing, but they're computed once at Stage 0 and never updated when a downstream decision commits a technology the vision didn't imply.

**Consequence:** an emergent stack decision (e.g., `architect-recommend` picks "React SPA + Node.js API + Redis + Kubernetes" mid-cascade) doesn't propagate back to rule activation. The design engines assume the rule floor computed at Stage 0 is complete — but it isn't, because Stage 0 didn't know what would emerge.

### 1.3. Operator observation (verbatim, 2026-07-07)

> "Cloud identification and classification needs to work during consult... it should just have like an array or something called stack, and then it should just have the keywords which represent every technology that's being used in the architecture. And if anything gets added to it at any time, then it should go hunting for that rules... look up by the kind keyword to find all rules that apply to that particular technology and then start enforcing those rules as the architecture is developed or designed considering and concerning and around that particular technology and how it interacts with the rest of the stack."

The operator's model matches the `active.json` schema exactly. Every rule at pin `f39fcdc` carries `source_namespace: <kind>` — that IS the four-axis namespace registry the operator is describing. The lookup is trivial:

```javascript
// Given a namespace committed to the stack, find its rules:
const rules_for_ns = active_json.rules.filter(r => r.source_namespace === ns);
```

## 2. Proposal — v1.15 §30.4 (Core Fix) + §30.5 (Structural Extension)

Two composed changes. §30.4 delivers the immediate bug closure with a one-line edit. §30.5 delivers the general mechanism the operator described. CTP can ship §30.4 quickly and iterate to §30.5, or ship both in one v1.15 tag — GCTP can adopt either sequencing.

### 2.1. §30.4 Core Fix — haystack unions in universal-answer values

Change the haystack construction in `commands/full-surface-intake.sh` from vision-only to vision + universal-answer values:

```ruby
# Current (§30.3, pin f39fcdc):
wl = ENV["WORKLOAD"].to_s.strip
wl = u_answers["workload"].to_s if wl.empty?
hay = wl.downcase

# Proposed §30.4:
wl = ENV["WORKLOAD"].to_s.strip
wl = u_answers["workload"].to_s if wl.empty?
# §30.4: include operator-stated universal answers in the classifier haystack so a
# cloud-agnostic vision + an explicit "target=aws" business answer activates aws-platform.
# Values only, not keys — a key like "target_platform" is not a signal; the value "aws" is.
answer_hay = u_answers.values.map { |v| v.to_s }.join(" ")
hay = "#{wl} #{answer_hay}".downcase
```

Word-boundary matching from §30.3 applies unchanged — `aws` in `answers.target_platform="aws"` fires `aws-platform` cleanly without collateral matches.

**This is the minimum to close the immediate bug.** But it doesn't yet address the general "any technology at any stage" case — that's §30.5.

### 2.2. §30.5 Structural Extension — stack-driven progressive rule activation

**Add `workload_classification.stack[]` to the v1.1 profile shape** (additive optional). Each entry captures one committed technology:

```json
{
  "workload_classification": {
    "workload_types": [...],
    "namespaces": [...],
    "activated_probe_namespaces": [...],
    "unprobed_in_scope": [...],
    "stack": [
      {
        "namespace": "aws",
        "source": "universal-answer",
        "trigger": "answers.motivation contains 'AWS Bedrock'",
        "added_at": "2026-07-07T14:32:11Z"
      },
      {
        "namespace": "react",
        "source": "design-decision",
        "trigger": "architect-recommend selected 'React SPA'",
        "added_at": "2026-07-07T14:41:07Z"
      }
    ]
  }
}
```

**Every technology-committing stage becomes an append source:**

| Stage | Trigger to append | Source tag |
|---|---|---|
| Stage 0 classifier | Vision signal fires a workload_type → its namespaces are appended | `classifier` |
| Stage 1 universal answer | Answer text signal fires a workload_type (via §30.4 haystack) OR an answer explicitly names a technology (via §30.5 free-text detection) | `universal-answer` |
| Stage 2 probe answer | Probe commitment names a technology (e.g., `iam_provider=okta` → `oauth2-oidc` grounding namespace) | `probe-answer` |
| Design (`architect-recommend`) | Recommended option's `implementation_hints` name concrete technologies (e.g., "React SPA + Node.js API + Redis") | `design-decision` |
| Operator injection (CLI) | Explicit `--stack-add <ns>` flag | `operator` |

**On every append, the mechanism runs:**

```ruby
def append_to_stack(ns, source, trigger)
  return if stack.any? { |e| e["namespace"] == ns }  # idempotent
  stack << { "namespace" => ns, "source" => source, "trigger" => trigger, "added_at" => now_iso }

  # 1. Activate the probe group for this namespace (if it has one and isn't already active)
  probe_group = question_bank["probes"][ns]
  if probe_group && !activated_probe_namespaces.include?(ns)
    activated_probe_namespaces << ns
    unprobed_in_scope.delete(ns)  # was unprobed; now activated
  end

  # 2. Pull in every active.json rule with this source_namespace
  # (No new persistence needed here — downstream enforcement engines already read
  # active.json and filter by namespace. §30.5 just ensures 'ns' is in the effective
  # applicable_rules set for every subsequent decision.)
end
```

The rule lookup is a filter on `active.json`; nothing new needs to be built. What's new is the **guarantee** that a namespace committed at ANY stage propagates into the applicable_rules set for every subsequent decision. Today only Stage 0's derived namespaces have that guarantee.

**Enforcement wire.** Invariant 4 in the audit-crosscheck (probe-group propagation into `decisions[].applicable_rules`) generalizes: every namespace in `stack[]` — not just `activated_probe_namespaces` — must be considered by at least one decision. This is the enforcement teeth for the operator's model: "if it's in the stack, its rules WILL be enforced."

### 2.3. Additivity + monotonicity invariants

- **Additive per ADR-0047.** `stack[]` is a new optional field; absent ⇒ pre-§30.5 profile ⇒ validate + translate + recommend unchanged. v1.0 profiles never have `stack[]`.
- **Monotone during a consult.** Stack only grows; never shrinks. If the operator changes their mind mid-consult ("actually let's go GCP not AWS"), that's a separate mechanism outside this proposal — perhaps `--stack-remove` with explicit invalidation of downstream decisions, or a `stack[].superseded_by` field. Out of scope for §30.5 core.
- **Idempotent.** Same namespace can only be in stack once. Re-append is a no-op; `source` + `trigger` + `added_at` record the FIRST appearance.
- **Precise, not loose.** Only namespaces that resolve in `active.json` can be added. An operator saying "we're using Redis" doesn't auto-add if Redis has no canonical namespace; it stays as a probe-answer commitment without a rule floor. This preserves cite-or-decline discipline — no phantom rule activation.

## 3. Boundary contract (what crosses to GCTP)

- **`business-profile.json` schema:** v1.1 shape stable; `workload_classification.stack[]` is a new additive optional field. `--validate-profile` MUST NOT require `stack[]` on v1.1 profiles missing it (additive-optional discipline, already GCTP's default per ADR-0089 precedent).
- **`--list-questions` JSON output:** unchanged.
- **`--classify` JSON output:** shape unchanged; the derived namespace set can grow via stack-append (never shrink) for the same inputs.
- **`decisions[].applicable_rules` propagation:** invariant 4 generalizes from `activated_probe_namespaces` to `stack[]` (which is a superset). GCTP-side reconciliation: one line of `audit-architecture-crosscheck.sh` to use `stack[]` when present, falling back to `activated_probe_namespaces` when absent.

Prime-directive-preserving. Nothing else crosses.

## 4. Coordination back to GCTP (post-adoption)

At the new pin (v1.15):

1. **§15-gated pin bump** via new ADR (pattern per ADR-0087 / ADR-0089 / ADR-0090); contract drift check permits only additive changes.
2. **`docs/handoff-contract.md §Business-Intake`:** append a "Stack-driven progressive rule activation (§30.4 / §30.5)" bullet noting the haystack expansion and the `stack[]` field; contract invariants unchanged.
3. **`scripts/consult.sh --validate-profile`:** MUST tolerate `stack[]` as an additive optional field on v1.1 profiles (must be an array of `{namespace, source, trigger, added_at}` objects if present; every `namespace` ⊆ `namespaces` for consistency; absent ⇒ pre-§30.5 profile ⇒ pass unchanged).
4. **`scripts/audit-architecture-crosscheck.sh` invariant 4:** generalize the key from `activated_probe_namespaces` to `stack[].namespace` when `stack[]` is present (fallback to `activated_probe_namespaces` otherwise).
5. **`/consult` skill:** the crossroads/translator loop gains an explicit "commit-to-stack" action at each Stage-1, Stage-2, and design-time juncture. When the operator commits (e.g., picks AWS), the skill emits `--stack-add aws` (or the equivalent shape via the answer) and translates the resulting new probe activation back to plain English ("adding AWS to the stack — this activates 12 AWS rules and 2 AWS-specific questions we'll ask next").
6. **Flip P-13 status** in `docs/upstream-ctp-proposals.md` 📋 FILED → ✅ ADOPTED.

## 5. Acceptance test (machine-verifiable)

See `docs/handoff-ctp-p13-acceptance-test.sh`. The test is structured in two tiers:

**Tier A — §30.4 Core Fix (haystack expansion).** Twelve assertions covering: baseline (vision-alone → no cloud), Core Fix (operator answer with AWS → aws-platform fires), aws probe activation, monotonicity (types fired at §30.3 still fire at §30.4), §30.3 word-boundary preservation over the new haystack (`leaks` in an answer must NOT fire azure-platform; `certification` must NOT fire ci-cd), multi-cloud precision (`target_platform=aws` fires only aws-platform), undecided/on-prem/hybrid (no cloud), vision + answer union (both fire), v1.0 back-compat, Extension shape (target_platform universal question if shipped).

**Tier B — §30.5 Structural Extension (stack + progressive activation).** Additional assertions covering: `stack[]` field present in v1.1 profile when `--stack-add` used; append is idempotent (same namespace can't appear twice); each entry has `{namespace, source, trigger, added_at}` shape; namespace ⊆ `namespaces` (namespaces set updated on append); appending an unprobed-in-scope namespace moves it to `activated_probe_namespaces` and out of `unprobed_in_scope`; appending a namespace with no probe group leaves the probe activation unchanged but still records the stack entry (rule floor still activated); v1.1 profile without `stack[]` still validates (additive-optional); every namespace in `stack[]` resolves to at least one rule in `active.json` (cite-or-decline enforcement).

## 6. Precedent

P-12 → CL-546 → ADR-0087 (§30 intake). CL-547 → ADR-0088 (§30.1 design consumption). CL-548 → ADR-0089 (§30.2 precise cloud types + IaC probes + transparency). CL-549 → ADR-0090 (§30.3 word-boundary matching). P-13 → §30.4 (haystack union) + §30.5 (stack-driven progressive activation). Same class, same discipline; P-13 unifies the rule-activation mechanism across all stages of the cascade, closing the last "activate rules only from Stage 0" limitation.

## 7. Boundary (unchanged)

CTP owns the classifier + question bank + stack-mechanism content; GCTP owns the consumer surface. This proposal is one small edit inside `commands/full-surface-intake.sh` (§30.4 haystack line), one new field on the v1.1 profile schema (§30.5 `stack[]`), and stack-append hooks in the downstream engines (`business-translate`, `architect-recommend`). Consumer-side reconciliation on GCTP is one line in `--validate-profile` (tolerate `stack[]` as additive optional) and one line in `audit-crosscheck` (invariant 4 uses `stack[]` when present). Additive per ADR-0047, zero deletions. Prime-directive-preserving.
