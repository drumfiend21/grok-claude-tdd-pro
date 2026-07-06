# ADR-0089 — Plugin pin bump `c23e5fe` → `43ea692` (adopt CTP CL-548 / §30.2 — precise cloud classification + IaC probe coverage (`azure`/`gcp`/`cfn`) + `unprobed_in_scope` coverage-transparency marker; closes the KATA-flagged silent-unprobed-namespace gap)

- **Status:** Accepted
- **Date:** 2026-07-05
- **Deciders:** operator (`drumfiend21`; 2026-07-05: relayed CTP's built-close-out of the CTP-side item #3 the operator flagged from the GCTP readiness review — *"the classifier puts IaC namespaces (azure, gcp, cfn, ansible) in scope but the question bank has no probes for them, so they're silently unprobed"*) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** GCTP's KATA-readiness review flagged that CTP's classifier put `azure/gcp/cfn/ansible` in scope on a generic Terraform signal but the question bank had **zero probe groups** for them — a silent-unprobed hole in the intake surface that undercuts §30's "full-surface intake" promise. Rather than round-trip a P-13, CTP built the close-out inline as **CL-548 (§30.2)** and returned a re-pin target **`43ea692`** (main HEAD; single merge commit ahead of `c23e5fe`). The close-out is symmetric with §30/§30.1: intake gathers the facts (§30), design engines consume them (§30.1), and now coverage is **precise + transparent** by construction (§30.2).
- **Continues:** the pin chain ADR-0072 → ADR-0079 → ADR-0085 → ADR-0086 → ADR-0087 → ADR-0088 → this ADR (`c23e5fe → 43ea692`).
- **Process:** §15-gated pin bump (upstream `architecture-v1.9.md` contract hash changes — §30.2 appended, +11 insertions / 0 deletions to the architecture doc). Consumer-side reconciliation on GCTP is **narrow and additive**: `scripts/consult.sh --validate-profile` v1.1 branch tolerates the new `workload_classification.unprobed_in_scope` field as an additive optional key (absent field ⇒ pre-§30.2 profile ⇒ pass unchanged). No reshape of any other consumer surface.

## Compatibility verdict (verified `c23e5fe → 43ea692`)

| Check | Result |
|---|---|
| Span | **1 CTP commit** (`43ea692` merge of CL-548) |
| upstream `architecture-v1.9.md` | **CHANGED** — **purely additive**: §30.2 appended (+11 insertions / 0 deletions); matches CTP's append-only discipline + ADR-0047 additive-only invariant |
| `CLAUDE.md` + 3 consumed `SKILL.md` (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) | **all byte-identical** — verified `git diff c23e5fe..43ea692 -- CLAUDE.md '.claude/skills/**/SKILL.md'` empty |
| Files changed | 14 files, 190 insertions, 6 deletions (aggregate). Arch: +11/0. Consumer engines: `commands/full-surface-intake.sh` +11/-2 (adds `unprobed_in_scope` to `--classify` + persisted block + stderr marker); `commands/business-translate.sh` +9/0 (consumes new azure/gcp/cfn probe commitments as grounded concerns). Corpora: `standards/business-intake-workload-classifier.yaml` +30/-4 (precise cloud types); `standards/business-intake-question-bank.yaml` +12/0 (azure/gcp/cfn probe groups). Design: `docs/design/v1.14-full-surface-intake.md` +26/0. Add: 8× `evals/specs/cl548-cover-*.json` |
| Classifier semantic delta | `iac-cloud` type no longer drags `aws/azure/gcp/cfn/ansible` into scope (now scopes only `hashicorp/iam/security-governance`). New dedicated types `aws-platform` / `azure-platform` / `gcp-platform` / `cloudformation` / `config-management` fire on cloud-specific signals. `relational-data` + `nosql-data` types no longer drag `aws/azure/gcp` into scope (DB signal alone doesn't imply a cloud). Net effect: an AWS-only workload is probed for `aws`+`cfn` only, not Azure/GCP. |
| Question-bank additions | Grounded probe groups added: `azure` (region_strategy → `azure-well-architected`; landing_zone → `azure-architecture-center`); `gcp` (region_strategy → `gcp-architecture-framework`; project_structure → `gcp-architecture-center`); `cfn` (stack_policy + drift_detection → `aws-cloudformation-best-practices`). `ansible` remains unprobed by design (no grounded founder source); reported explicitly via `unprobed_in_scope` |
| `active.json` | expected **118 → 118 rules** (byte-identical; CL-548 adds no authored rules — refines corpora + adds a persisted field) |

## Decision

Bump the pin `c23e5fe → 43ea692` — the main HEAD named in CTP's message. This closes the KATA-flagged coverage gap by construction: `azure/gcp/cfn` now have probe groups (were silently unprobed on generic Terraform signals); classification is precise (AWS-only kata is probed for `aws`+`cfn`, not Azure/GCP); and any remaining in-scope namespace with no probe group is **reported explicitly** via `unprobed_in_scope` — the intake mirror of "no rule silently unenforced."

## What §30.2 delivers (the substantive change)

1. **Precise cloud classification.** The generic `iac-cloud` type (Terraform / IaC / provision / deploy signals) no longer drags every cloud into scope — it scopes only provider-agnostic namespaces (`hashicorp`, `iam`, `security-governance`). Dedicated types (`aws-platform`, `azure-platform`, `gcp-platform`, `cloudformation`, `config-management`) fire on cloud-specific signals (e.g. `s3` / `ec2` → `aws`; `aks` / `blob storage` → `azure`; `bigquery` / `cloud run` → `gcp`). Same discipline extended to `relational-data` + `nosql-data`: those types no longer drag `aws/azure/gcp` into scope on a DB signal alone; the cloud signals now do that separately. Net effect on the KATA (AWS + Terraform + Kubernetes + JWT + React + SQL): probed for `aws`+`cfn`, not Azure/GCP — precision enforced, not just true by luck.
2. **IaC probe coverage.** New grounded probe groups for `azure` (2 questions), `gcp` (2 questions), `cfn` (2 questions), each cite-or-decline grounded in an `active.json`-resolvable source (`azure-well-architected`, `azure-architecture-center`, `gcp-architecture-framework`, `gcp-architecture-center`, `aws-cloudformation-best-practices`). `business-translate` additively consumes the new commitments (`azure_region_strategy=multi-region` / `gcp_region_strategy=multi-region` → multi_region concern; `cfn_stack_policy=protected` → stack_protection concern).
3. **Coverage transparency (the standing invariant).** `full-surface-intake` computes `unprobed_in_scope` (in-scope namespaces with no probe group) and reports it on `--classify` output, stderr run marker, and the persisted `workload_classification` block. Namespaces reported unprobed (e.g. `ansible`, `md`, `mesh`, `web-vitals`, CI-platform alternatives `gha`/`circleci`/`jenkins`/`glci`/`azdo`) either carry no grounded founder source (`ansible`) or no distinct founder commitment (they're grounded automatically at output time by §29). Crucially: **no in-scope namespace can ever be silently unprobed again** — a coverage gap is now visible by construction.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `43ea692`; the upstream `architecture-v1.9.md` sha256 updated (`66d8a3d1… → 62e87bc4…`); other contract-file hashes unchanged (byte-identical, verified). Bumped by hand under this ADR (the manual-edit-under-ADR path per ADR-0079/0086/0087/0088 precedent — `--update` refuses on contract drift by design).
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `43ea692` via `scripts/sync-plugin.sh --ensure` (idempotent).
- **`active.json`**: regenerated via `scripts/standards-sync.sh` — byte-identical (§30.2 adds no authored rules).
- **`scripts/consult.sh --validate-profile`**: v1.1 branch tolerates `workload_classification.unprobed_in_scope` as an additive optional key (must be an array of strings if present; absent ⇒ pre-§30.2 profile ⇒ pass unchanged). No new mandatory checks — v1.1 profiles emitted before §30.2 remain valid.
- **`docs/handoff-contract.md §Business-Intake`**: light amend to note the `unprobed_in_scope` key and the precise-classification / IaC-probe-coverage refinements at pin `43ea692`+. Contract invariants unchanged; the additive key is optional.
- **`docs/upstream-ctp-proposals.md §P-12`**: adoption note extended — "IaC-coverage close-out closed at `43ea692` (§30.2 precise cloud classification + azure/gcp/cfn probes + `unprobed_in_scope` transparency marker)".
- **TICKETS.md**: **TICKET-116** added, DONE, pointing at this ADR.
- **Consumer surfaces (`audit-crosscheck` invariant 4, `/consult` skill)**: no reshape needed — invariant 4 already keys on `activated_probe_namespaces` (the set §30.2 makes precise, not vacuous); the `/consult` skill's Stage 0 reveal can optionally surface `unprobed_in_scope` when non-empty for operator transparency (documentation-only note, no code change required for the audit-only bump).

## Consequences

**Positive.**

- **Standing invariant activated:** *no in-scope namespace is silently unprobed*. The classifier + question-bank + transparency marker jointly guarantee it. This is the intake mirror of §29's "no rule silently unenforced" and closes the last KATA-discovered coverage hole.
- **Precise classification** removes an entire class of false-positive-namespace-in-scope: an AWS-only kata no longer gets Azure/GCP dragged in on a generic Terraform signal. Downstream concerns from `business-translate` and pick influence from `architect-recommend` are now scoped precisely to the workload's real footprint.
- **Grounded IaC coverage** for Azure + GCP + CloudFormation — three namespaces previously in scope but silent at intake now surface committed postures the design engines can consume.
- **Transparency marker** makes the "we don't cover X here" fact observable for the first time. When `ansible` (or a CI-platform alternative) shows up in `unprobed_in_scope`, the operator sees it — no more silent gap.
- Back-compat preserved: v1.1 profiles emitted before §30.2 (no `unprobed_in_scope` field) still validate; v1.0 profiles unchanged.

**Negative / knowingly accepted.**

- `ansible` remains unprobed (no grounded founder source). Reported explicitly via `unprobed_in_scope`, but not covered. If a grounded Ansible source is later added upstream, that's a separate CL.
- CI-platform alternatives (`gha` / `circleci` / `jenkins` / `glci` / `azdo`) plus `md` / `mesh` / `web-vitals` / `compose` remain unprobed by design — they carry no distinct founder commitment (grounded automatically at output time by §29). This is intentional scoping, not a bug; the transparency marker records it. If any of them later gains a first-order business commitment, that's a separate CL.
- Three pin bumps in the same day (ADR-0087 + ADR-0088 + this) is unusual cadence. Justified: §30 + §30.1 + §30.2 are the three halves of one logical KATA-close-out — CTP built each within its 24-hour cycle after GCTP's readiness reviews surfaced them.
- The classifier semantic change (`relational-data` + `nosql-data` no longer scope `aws/azure/gcp`) is worth calling out: workloads that mention a DB but no cloud-specific keyword will now scope fewer namespaces than before. This is the *point* (precision), but a workload that vaguely mentions "cloud database" without a provider signal will not activate any cloud probe. That's correct behavior — the operator should say which cloud they're on, and the transparency marker makes the absence visible.

**Neutral.**

- Historical P-13 candidate is superseded: no P-13 filed (close-out arrived from CTP without a round-trip). The P-12 ledger row extends to "IaC-coverage close-out at `43ea692`".

## Rollback

`git revert` this commit → the lockfile snaps back to `c23e5fe`; classifier reverts to the over-scoping shape (generic Terraform → all clouds); question-bank loses the azure/gcp/cfn probe groups; `unprobed_in_scope` field disappears from `--classify` output. The KATA-flagged silent-unprobed gap re-opens. No downstream schema migration on GCTP side (the additive field consumption in `--validate-profile` degrades gracefully — absent field ⇒ pass).

## References

- CTP §30.2 amendment: `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §30.2` @ `43ea692`
- CTP design detail: `.harness/plugin-cache/claude-tdd-pro/docs/design/v1.14-full-surface-intake.md §30.2` @ `43ea692`
- CTP classifier: `.harness/plugin-cache/claude-tdd-pro/standards/business-intake-workload-classifier.yaml` @ `43ea692`
- CTP question-bank: `.harness/plugin-cache/claude-tdd-pro/standards/business-intake-question-bank.yaml` @ `43ea692`
- CTP intake command: `.harness/plugin-cache/claude-tdd-pro/commands/full-surface-intake.sh` @ `43ea692`
- Preceding pin bumps (§30 intake + §30.1 design-engine consumption): ADR-0087 + ADR-0088
- Additivity invariant: ADR-0047
- Consult loop mechanism: ADR-0056
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model"
