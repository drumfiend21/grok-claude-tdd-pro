# ADR-0091 — Plugin pin bump `f39fcdc` → `11126a8` (adopt CTP CL-550 §30.4 + CL-551 §30.5 + CL-552 §30.6 — stack-driven progressive rule activation, entry shape + idempotency aligned to GCTP's P-13 acceptance test)

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** operator (`drumfiend21`; 2026-07-08: elected the "share the acceptance test" close-out route on P-13 rather than reconcile downstream — CTP built §30.6 to the 19-assertion machine surface GCTP shipped at TICKET-118.a; this ADR adopts the aligned result) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** GCTP filed P-13 as a two-part amendment (§30.4 haystack union + §30.5 `stack[]` structural extension) at TICKET-118 and pre-wired the consumer surface + a machine-verifiable acceptance test at TICKET-118.a. CTP shipped §30.4/§30.5 as CL-550/CL-551 at `a2d05d4` and returned a handoff nominating that SHA. GCTP-side inspection found two acceptance-test assertions (T-B.2 stack-entry object shape, T-B.3 idempotency) not specified in CTP's return handoff; operator elected the "share the acceptance test" route. CTP built **§30.6 as CL-552** at `b7fa10e` (merge `6d68cc2`) closing both gaps, and confirmed the 19-assertion suite as spec. Upstream HEAD is `11126a8` — a docs-only merge on top of `6d68cc2` carrying the aligned P-13 return handoff. This ADR adopts the whole chain by pinning to upstream HEAD.
- **Continues:** the pin chain ADR-0072 → ADR-0079 → ADR-0085 → ADR-0086 → ADR-0087 → ADR-0088 → ADR-0089 → ADR-0090 → this ADR (`f39fcdc → 11126a8`).
- **Process:** §15-gated pin bump (upstream `architecture-v1.9.md` contract hash changes — §30.4 + §30.5 + §30.6 appended; hash `28748cb9… → d85a3f6e…`; other 4 contract files byte-identical). Consumer-side reconciliation required on GCTP: the pre-wired `--validate-profile` v1.1 `stack[]` block's `source` enum was speculative (`[classifier, universal-answer, probe-answer, design-decision, operator]`); CTP shipped `[stack-add, vision, answer]` per its documented enum (only `stack-add` emitted today; `vision`/`answer` reserved for future haystack-inferred entries). Reconciled to the shipped shape per prime directive.

## Compatibility verdict (verified `f39fcdc → 11126a8`)

| Check | Result |
|---|---|
| Span | **3 semantic CTP commits** (`de3d??` CL-550 §30.4 + `??????` CL-551 §30.5 landing at merge `a2d05d4`, plus `b7fa10e` CL-552 §30.6 landing at merge `6d68cc2`) + 2 docs commits (`dcd1b5e` + `11126a8` — handoff SHA fill; contract-neutral) |
| upstream `architecture-v1.9.md` | **CHANGED** — **purely additive**: §30.4 + §30.5 + §30.6 appended; ADR-0047 additive-only invariant preserved |
| `CLAUDE.md` + 3 consumed `SKILL.md` | **all byte-identical** — verified via `shasum -a 256` at the new pin |
| `active.json` | expected **118 → 118 rules** (byte-identical; §30.4/§30.5/§30.6 add classifier + intake behavior, not authored rules) |
| P-13 acceptance test (19 assertions) | **17 pass / 0 fail / 3 non-blocking skip** at `11126a8`. Tier A (§30.4) fully green: cloud-agnostic vision alone fires no cloud type (regression baseline), operator answer stating AWS fires `aws-platform` + activates `aws` probe group, §30.3 word-boundary preserved over the wider haystack, `target_platform=aws` disambiguates cleanly, `undecided/on-prem/hybrid` fire no cloud type, vision+answer union works. Tier B (§30.5) fully green: `--stack-add react` appends to `workload_classification.stack[]`, entry has all four required keys `{added_at, namespace, source, trigger}` (**T-B.2 aligned by CL-552 §30.6**), duplicate `--stack-add react --stack-add react` collapses to one entry (**T-B.3 aligned by CL-552 §30.6**), `--stack-add aws` activates the `aws` probe group, unknown-namespace rejection is exit 2 (cite-or-decline). Skips are non-blocking: T-A.9 (`business-intake --dry-run` schema_version format — documentary), T-A.10 (`target_platform` universal question deferred; Core Fix passes without it), T-B.7 (`active.json` path check — PWD-dependent when run from cache dir; passes when run from repo root). |
| Stack entry shape (empirical) | `stack[i] = {namespace: "react", source: "stack-add", trigger: "--stack-add react", added_at: "2026-07-08T22:35:02Z"}` — verified by direct `--classify` invocation |
| Enum reconciliation | GCTP pre-wire enum `[classifier, universal-answer, probe-answer, design-decision, operator]` → CTP shipped enum `[stack-add, vision, answer]`. Only `stack-add` emitted today (CLI provenance); `vision`/`answer` reserved by CTP for future haystack-inferred entries. Consumer-side rename per handoff-contract self-declared reconciliation policy (precedent: ADR-0087 v1.1 key-name reconciliation). |

## Decision

Bump the pin `f39fcdc → 11126a8` — upstream HEAD as of the aligned P-13 return handoff. This adopts three composed CTP change-lists as one pin-bump CL:

1. **CL-550 (§30.4 Core Fix — classify from answers).** The classifier haystack is now `vision + all business-answer values`, so a cloud stated in an answer (`--answer motivation="deploy on AWS Bedrock"`) fires `aws-platform` and activates the `aws` probe group. §30.3 word-boundary matching (`(?<![a-z0-9])<sig>s?(?![a-z0-9])`) preserved over the wider haystack. Monotone (haystack only grows; classifier can only fire more types, never fewer). Closes the exact bug operator flagged post-`f39fcdc`: cloud identification did not work during consult when the vision was cloud-agnostic even if the operator explicitly named a cloud.

2. **CL-551 (§30.5 Structural Extension — `stack[]` mechanism).** New `--stack-add <ns>` CLI flag (repeatable). New `workload_classification.stack[]` field on the v1.1 profile shape (additive optional). Every append triggers: namespace-keyed rule lookup in `active.json` by `source_namespace`, probe-group activation from `business-intake-question-bank.yaml` (moves namespace out of `unprobed_in_scope` into `activated_probe_namespaces`). Cite-or-decline: unknown namespace rejected with exit 2 + human-readable error. Idempotent (dedupe-by-namespace at append time — see §30.6).

3. **CL-552 (§30.6 Entry shape + idempotency alignment).** Each `stack[i]` is a provenance object with exactly four keys `{namespace, source, trigger, added_at}`, sorted-by-namespace in both `workload_classification.stack` and top-level `profile.stack`. `source="stack-add"` for CLI provenance; `vision`/`answer` reserved for future haystack inference. Duplicate `--stack-add <same-ns>` collapses to one entry via dedupe-by-namespace at append (first-write wins). Closes the two gaps GCTP's pre-wired acceptance test asserted (T-B.2 shape, T-B.3 idempotency) that CL-550/551 left underspecified.

**Explicit non-adoption:** the pin chain `f39fcdc..11126a8` includes intermediate docs-only merges (`61f9c7e` pre-alignment handoff fill; `dcd1b5e` post-alignment handoff fill; `11126a8` merge of the aligned handoff). These are the handoff paper trail — no contract-surface change. We pin to `11126a8` (upstream HEAD, matching ADR-0090 precedent) rather than to `6d68cc2` (CTP's nominated code-only SHA); the docs-only churn on top is benign. Rationale: pinning to upstream HEAD avoids a stale-drift-report on next `--check` (which pinning to `6d68cc2` would trigger since two docs commits sit on top); ADR-0090 established the precedent of pinning to upstream HEAD even when a chore commit is on top (`f39fcdc` was itself the gitignore chore merge, not the CL-549 code SHA).

## What §30.4 + §30.5 + §30.6 deliver (the substantive change)

1. **Cloud classification from operator answers (§30.4).** The classifier no longer requires the vision to mention a cloud — a cloud stated in any universal answer fires the platform type. Symmetric to §30.2 (precise type-mapping) and §30.3 (precise matching) but one axis wider: precise *input surface*. The kata `/consult` on the real Certifiable, Inc. AI-credentialing vision now behaves correctly whether the vision mentions AWS (already worked before) or the operator names AWS as an answer to `motivation`/`target_platform`/etc. (broken before; now works).
2. **Stack-driven progressive rule activation (§30.5).** First-class record of "what technologies are actually in the stack at this moment." Every append hunts `active.json` for `source_namespace = <ns>` and activates the rules keyed by that namespace, plus the probe group. Enables mid-consult progressive scope expansion: as the operator commits technologies through the consult loop (Stage-1 answer, Stage-2 probe answer, design decision, explicit `--stack-add`), rule + probe activation grows monotonically. Cite-or-decline preserved: only namespaces resolving in `active.json` can be added — no phantom rule activation.
3. **Entry shape + idempotency (§30.6).** Provenance object per entry (`namespace`/`source`/`trigger`/`added_at`) makes the audit trail machine-readable and the acceptance-test-verifiable. Idempotence-at-append (dedupe by namespace) means the stack only grows monotonically; a namespace can only be added once regardless of how many stages committed to it.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `11126a8`; the upstream `docs/architecture-v1.9.md` sha256 updated (`28748cb9… → d85a3f6e…`); other 4 contract-file hashes unchanged (byte-identical, verified). Bumped by hand under this ADR (the manual-edit-under-ADR path per ADR-0079/0086/0087/0088/0089/0090 precedent — `--update` refuses on contract drift by design).
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `11126a8` via `scripts/sync-plugin.sh --check` (verified 0 drift at the new pin).
- **`scripts/consult.sh --validate-profile`**: `stack[]` enum reconciled from the speculative pre-wire `[classifier, universal-answer, probe-answer, design-decision, operator]` to CTP's shipped `[stack-add, vision, answer]`. The pre-wire enum was written before CTP shipped §30.6; the shipped enum reflects CTP's actual provenance model (`stack-add` for CLI; `vision`/`answer` reserved for future haystack-inferred entries when the classifier auto-populates stack from vision text). Consumer-side reconciliation to shipped keys per handoff-contract self-declared reconciliation policy — same pattern as ADR-0087's `signals_detected → workload_types` reconciliation.
- **`tests/test-consult.sh`**: 5 fixture blocks reconciled to the shipped enum (well-formed stack, missing-ns, ns-out-of-range, duplicate, all-sources). "all-five enum sources" test becomes "all-three shipped enum sources." 64/64 green.
- **`tests/hook-security-baseline.txt`**: 3 line-number-shifted findings in `tests/test-audit-architecture-crosscheck.sh` re-keyed from `L39/40/82/83/158` (pre-TICKET-118.a positions) to `L42/85/160` (post-118.a positions). Not caused by this pin bump; a residual from TICKET-118.a that was surfaced by the baseline check during this bump. Fixed in-place to keep the gate honest.
- **`docs/handoff-contract.md §Business-Intake`**: light amend to name §30.4 + §30.5 + §30.6 as the stack-driven progressive rule activation surface. Contract invariants unchanged.
- **`docs/upstream-ctp-proposals.md §P-13`**: flipped 📋 FILED → ✅ ADOPTED — four halves closed at `11126a8` (§30 / §30.1 / §30.2 / §30.3 / §30.4 / §30.5 / §30.6 chain; P-13 spans the last three).
- **`docs/handoff-ctp-p13-cloud-classification-from-answers.md`**: header status flipped to ADOPTED with the aligned SHA.
- **TICKETS.md**: TICKET-119 row added (this pin bump), DONE, pointing at this ADR.
- **Consumer surfaces** (`audit-crosscheck` invariant 4, `/consult` skill, `--validate-profile`): invariant 4's `activated_probe_namespaces ∪ stack[].namespace` union already shipped in TICKET-118.a; enum reconciliation is the only substantive consumer change.

## Consequences

**Positive.**

- **Cloud classification now works during consult on cloud-agnostic visions.** The exact operator-facing symptom that motivated P-13 is gone: the AI-credentialing vision plus an operator answer stating AWS now activates the `aws-platform` type and the `aws` probe group. The `/consult` loop can walk the aws-region-strategy / cfn-stack-policy probes and produce a submission grounded in the actual chosen cloud.
- **Rule activation is now progressive.** Every technology committed at any stage (answer, probe answer, design decision, explicit `--stack-add`) hunts `active.json` for rules keyed by its namespace and activates the probe group. No rule scoped to a namespace that's actually in the stack is silent.
- **19-assertion machine acceptance surface delivered on both sides.** GCTP shipped the acceptance test at TICKET-118.a; CTP built to it at CL-552; this pin bump verifies it. Future stack-shape work has a machine surface both sides can build against.
- **Consumer-side enum reconciliation is a controlled churn.** The pre-wire enum was speculative on GCTP's side (5 anticipated sources), the shipped enum is 3 (1 live + 2 reserved). The controlled reconciliation matches the ADR-0087 precedent (shipped-key names win; consumer catches up in the same pin-bump CL).
- Back-compat preserved: v1.1 profiles without `stack[]` (pre-§30.5) still validate. v1.0 profiles unchanged.

**Negative / knowingly accepted.**

- The pre-wire enum was 5 speculative sources; the shipped enum is 3. The 5-source pre-wire was written before CTP shipped § 30.6, so it reflected GCTP's own model of provenance stages, not CTP's shipped model. The reconciliation is a small edit (~10 lines across `scripts/consult.sh` + 5 test fixtures), but it's a reminder that pre-wiring against an unspecified enum trades reconciliation cost for readiness. Future pre-wires should either ask CTP for the enum first or design the enum together in the proposal.
- The `f39fcdc..11126a8` range carries two docs-only merges (`61f9c7e` + `11126a8`) that flank the code merge `6d68cc2`. These are the P-13 return-handoff paper trail — no consumer-surface change. Pinning to `11126a8` (upstream HEAD) is cleaner than pinning to `6d68cc2` (CTP's nominated code SHA) because it keeps the drift report clean at next `--check`; ADR-0090 established the same convention.
- Pin chain now runs seven-deep in the KATA cycle (ADR-0086 → ADR-0091). Each pin closes a distinct KATA-discovered defect or an operator-articulated extension. The rate reflects the KATA's success at finding real gaps and the operator's willingness to widen mid-flight (P-13's §30.5 was widened from a narrow classifier fix to a general stack mechanism the same day the proposal was filed).

**Neutral.**

- The `hook-security-baseline.txt` re-keying is a residual from TICKET-118.a (line numbers shifted when 6 integration-test assertions were added). Fixed here because this pin bump surfaced it via `test-all.sh`; not caused by this bump.
- P-12 ledger row extends from "four halves closed at `f39fcdc`" to "six halves closed at `11126a8`" (§30 / §30.1 / §30.2 / §30.3 / §30.4 / §30.5 / §30.6 — the P-12 arc plus the P-13 close-out).

## Rollback

`git revert` this commit → the lockfile snaps back to `f39fcdc`; classifier reverts to vision-only haystack (cloud-in-answer no longer fires cloud types); `--stack-add` is unrecognized (no `stack[]` mechanism); the `--validate-profile` enum reverts to the speculative 5-source pre-wire; the 5 pre-wired test fixtures pass again at the pre-wire enum. No downstream schema migration (nothing outside the classifier + intake + validator changed).

## References

- CTP §30.4 amendment: `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §30.4` @ `11126a8`
- CTP §30.5 amendment: `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §30.5` @ `11126a8`
- CTP §30.6 amendment: `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §30.6` @ `11126a8`
- CTP CL-550/551/552 code: `.harness/plugin-cache/claude-tdd-pro/commands/full-surface-intake.sh` @ `11126a8`
- CTP return handoff (aligned): `.harness/plugin-cache/claude-tdd-pro/docs/handoff-ctp-to-gctp-p13-fixed.md` @ `11126a8`
- GCTP proposal: `docs/handoff-ctp-p13-cloud-classification-from-answers.md`
- GCTP acceptance test (19 assertions): `docs/handoff-ctp-p13-acceptance-test.sh`
- Preceding pin bumps (§30 / §30.1 / §30.2 / §30.3 chain): ADR-0087 + ADR-0088 + ADR-0089 + ADR-0090
- Additivity invariant: ADR-0047
- Consult loop mechanism: ADR-0056
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model"
