# ADR-0087 — Plugin pin bump `0cf28fe` → `f060a8e` (adopt CTP CL-546 / §30 / S-57 / §2.35 — full-surface requirements intake; resolves P-12; reconciles PENDING v1.1 consumer surface to shipped shape)

- **Status:** Accepted
- **Date:** 2026-07-05
- **Deciders:** operator (`drumfiend21`; 2026-07-05: *"Make it work with ctp."*) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** CTP shipped **CL-546 (§30 / S-57 / §2.35)** on `main`, adopting the P-12 full-surface **requirements-intake** proposal — the input-side mirror of §29/P-11. CTP returned a handoff (`docs/handoff-ctp-to-gctp-p12-fixed.md` at `f060a8e`) naming re-pin target **`f060a8e`** (main HEAD; includes the handoff doc + the CL-546 code SHA `829a284`). CTP's cover message flagged three coordinate corrections: (1) landed as §30, not §27.16 (which already exists as "Layered multi-cloud advisor"); (2) new command `commands/full-surface-intake.sh` composing S-32, rather than modifying `business-intake.sh` (more additive — v1.0 back-compat by construction); (3) authoritative on the exact contract keys — GCTP's PENDING `--validate-profile` reconciles.
- **Continues:** the pin chain ADR-0072 (`230e99d → 4668c2e`) → ADR-0079 (`4668c2e → 127804b`) → ADR-0085 (`127804b → a69f380`) → ADR-0086 (`a69f380 → 0cf28fe`) → this ADR (`0cf28fe → f060a8e`).
- **Process:** §15-gated pin bump (upstream `architecture-v1.9.md` contract hash changes — §30 appended, 12 insertions / 0 deletions). Consumer-side reconciliation lands *in the same CL* as the pin bump so the harness is never in a state where a v1.1 profile emitted by S-57 fails GCTP's stale validator (per `docs/handoff-contract.md §Business-Intake` self-declared reconciliation policy).

## Compatibility verdict (verified `0cf28fe → f060a8e`)

| Check | Result |
|---|---|
| Span | **1 commit** (CTP merge `f060a8e` of CL-546 + handoff doc) |
| upstream `architecture-v1.9.md` | **CHANGED** — **purely additive**: §30 appended (+12 insertions / 0 deletions); matches CTP's append-only discipline + ADR-0047 additive-only invariant |
| `CLAUDE.md` + 3 consumed `SKILL.md` (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) | **all byte-identical** — prime-directive text + inner-loop discipline unchanged |
| Files removed | **0** (ADR-0047 additive-only invariant preserved — verified by `git diff --numstat`: 19 files, 804 insertions, **0 deletions**) |
| `active.json` | expected **118 → 118 rules** across 42 namespaces (regenerated via `standards-sync.sh` — S-57 adds command + corpora + schema, not authored rules) |
| Changed plugin files | Add: `commands/full-surface-intake.sh` (S-57), `schemas/business-profile.schema.json`, `standards/business-intake-workload-classifier.yaml`, `standards/business-intake-question-bank.yaml`, `docs/design/v1.14-full-surface-intake.md`, `docs/handoff-ctp-to-gctp-p12-fixed.md`, 12× `evals/specs/cl546-fsintake-*.json`; Modify: `docs/architecture-v1.9.md` (+12/-0 — §30 append) |

## Decision

Bump the pin `0cf28fe → f060a8e` — the main HEAD named in the CTP handoff (recommended over the code-only `829a284` because it includes the durable in-repo handoff record). This resolves **P-12 upstream** and lands **§30 / S-57 / §2.35 full-surface requirements intake** — the input-side mirror of §29 — so that intake gathers facts across the whole 42-namespace / 118-rule surface rather than only the universal 9.

## What §30 / S-57 delivers (the substantive change)

CTP's requirements intake now:

1. **Classifies the founder's vision** (`--classify` / `--workload <text>`) into `workload_types` → in-scope aggregator `namespaces` → `activated_probe_namespaces`, driven by `standards/business-intake-workload-classifier.yaml`.
2. **Probes each activated namespace** with a targeted question group from `standards/business-intake-question-bank.yaml`, each question cite-or-decline grounded in an existing catalog `source_id`.
3. **Emits a v1.1 `business-profile.json`** that is a **strict additive superset** of v1.0: the universal 9 answers live in `answers` unchanged (S-57 composes S-32; universal-stays-universal), plus new top-level `workload_classification` + `probes.<namespace>` + `grounded_in_namespaces`. `grounded_in` is a strict superset of what v1.0 would have emitted.
4. **Guarantees back-compat by construction**: `business-intake.sh` is untouched, so every v1.0 caller and every v1.0 profile still validates + translates + recommends unchanged. Downstream engines (`business-translate.sh`, `architect-recommend.sh`, `architect-session.sh`) read `answers` (unchanged) — the existing chain works on a v1.1 profile without knowing about probes. Consumption of the richer `probes` block by the design engines is a deliberate CTP follow-up CL, disclosed in CTP's handoff §5.

## The coordinate correction (recorded so future readers can trace it)

GCTP filed P-12 as **§27.16 "Full-Surface Intake"**. That label already existed in CTP's architecture ("Layered multi-cloud advisor", §27.16, 2026-06-08 — an unrelated feature). CTP owns its decomposition. P-12 landed at CTP-correct coordinates:

| GCTP proposed (in the P-12 handoff) | CTP shipped (at `f060a8e`) |
|---|---|
| §27.16 | **§30** (new top-level; §27.16 taken) |
| (no feature ID) | **S-57** (next after S-56/P-11) |
| (boundary contract not enumerated) | **§2.35** (next after §2.34/P-11) |
| MODIFY `commands/business-intake.sh` | **NEW** `commands/full-surface-intake.sh` composing S-32 |
| `evals/business-intake-v1.14-eval.yaml` | per-spec `evals/specs/cl546-fsintake-01..12-*.json` (CTP spec convention) |

None of these are contract violations — they are CTP exercising its ownership of its own decomposition, exactly as the prime directive intends.

## v1.1 shape reconciliation (PENDING → authoritative)

GCTP's `--validate-profile` gate, cross-check invariant 4, `/consult` skill cascade walk, and `docs/handoff-contract.md §Business-Intake` were all prepped on `dev/kata-2026-07-03-consult` at commit `9d2cf26` against the **anticipated** shape published in this repo's outbound P-12 handoff. CTP's shipped shape differs in three key names — reconciled in this CL:

| Field | GCTP anticipated | CTP shipped (authoritative) |
|---|---|---|
| `workload_classification.signals_detected` | array of feature signals | replaced by **`workload_types`** (workload categories) + **`namespaces`** (in-scope aggregators) |
| `workload_classification.signals_forced` / `signals_suppressed` | operator override arrays | not present in the shipped shape |
| `workload_classification.activated_probe_groups` (includes literal `"universal"`) | array of group names | **`activated_probe_namespaces`** — namespace names only; no `"universal"` sentinel (universal-stays-universal in `answers`) |
| `probes.universal` (mirror of universal 9, byte-identical to `answers`) | required | **not shipped** — universal 9 live only in `answers`; `probes` is per-namespace only |
| `grounded_in_namespaces` first entry | includes `"_universal"` | shipped shape uses namespace names only; each entry must appear in `activated_probe_namespaces` and be backed by an answered probe |
| `unanswered` | absent | shipped as top-level array (activated probes still pending) |

Consumer-side changes in this CL (kept minimal, purely reconciliation):

- **`docs/handoff-contract.md §Business-Intake`** — status flipped **PENDING → AUTHORITATIVE at pin `f060a8e`**. v1.1 schema block rewritten to CTP's shipped keys. Contract invariants extended (universal-stays-universal + namespace-grounding traceability). Historical proposal docs (`docs/handoff-ctp-p12-*.md/json/sh`) retained as the P-12 trail; authoritative reference now points to `schemas/business-profile.schema.json` + `commands/full-surface-intake.sh` + `docs/architecture-v1.9.md §30` in the plugin cache.
- **`scripts/consult.sh --validate-profile`** — v1.1 branch rewritten to check `workload_classification.{workload_types,namespaces,activated_probe_namespaces}`; drops the `probes.universal` mirror check (universal 9 already validated via the v1.0 baseline against `answers`); `grounded_in_namespaces` invariant tightened to "every entry ∈ activated_probe_namespaces AND backed by an answered probe" (matches CTP schema requirement).
- **`scripts/audit-architecture-crosscheck.sh`** — invariant 4 rewritten to key on `activated_probe_namespaces`; drops the `"universal"` skip (no longer in the activated set).
- **`.claude/commands/consult.md`** — Stage 0 wording keys on `workload_types` + `activated_probe_namespaces`; Stage 1 clarifies universal 9 forwarded to S-32 and landing under `answers` (not `probes.universal`); Stage 2 lists namespace-scoped examples (`react`, `jwt`, `k8s`); `--probe-answer ns:key=value` documented.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `f060a8e`; the upstream `architecture-v1.9.md` sha256 updated (§30 append); other contract-surface hashes unchanged (verified byte-identical). Bumped by hand under this ADR (the manual-edit-under-ADR path, per the ADR-0079/0086 precedent — `--update` refuses on contract drift by design).
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `f060a8e` via `sync-plugin.sh --ensure` (idempotent).
- **`active.json`**: regenerated via `standards-sync.sh` — expected byte-identical (S-57 adds no new authored rules; the workload-classifier + question-bank corpora are inputs to the intake command, not entries in the aggregated `active.json`). Any drift here is a signal, not intended.
- **P-12 filed as ✅ ADOPTED** in `docs/upstream-ctp-proposals.md` at pin `f060a8e` (this ADR is the adoption record).
- **TICKET-114 closed** in `TICKETS.md` with a DONE row pointing at this ADR.
- **No handoff regeneration** (no-rewrites discipline, ADR-0070 §1); no `applicable_rules` change on any open ticket.

## Consequences

**Positive.**
- `/consult` on v1.1-emitting workloads now walks the Stage 0 → Stage 1 → Stage 2 cascade against the authoritative shape, translating each namespace probe into plain business language per the crossroads/translator loop (ADR-0056).
- The seed for every downstream design decision is grounded in stated facts across ~13 namespaces per typical workload (vs. the universal 4 sources at v1.0), directly reducing the class of downstream architectural rework loops P-11 removed at design time and P-12 now removes one stage earlier.
- Invariant 4 (v1.1 probe-namespace propagation) now audit-checkable end-to-end against real profiles.
- Additivity preserved by construction: v1.0 profiles still validate, still translate, still recommend, byte-identical to before.

**Negative / knowingly accepted.**
- CTP's design-engine chain does not yet consume `probes.<namespace>` for richer grounding (deliberate follow-up CL in CTP, disclosed in the handoff §5). Until that lands, the v1.1 richer facts sit in the profile without deepening the downstream reasoning — the seed is fuller, but the design layer still reads the (unchanged) universal `answers`. This is the trade-off that guarantees v1.0 back-compat.
- One PENDING → AUTHORITATIVE surface is being flipped in a single CL, which loses the audit trail of "what GCTP thought vs. what CTP shipped." That trail is retained in the anticipated-shape section of this ADR + the P-12 handoff docs in this repo. Acceptable because the reconciliation is small and local.

**Neutral.**
- Historical P-12 supplementary materials (`docs/handoff-ctp-p12-*.md/json/sh`) retained as the proposal trail; not deleted (per no-rewrites). Their embedded key names now differ from the shipped shape — but they are marked "proposal" throughout, and this ADR is the authoritative reconciliation record.

## Rollback

`git revert` this commit → the lockfile snaps back to `0cf28fe` and the four consumer files return to their PENDING-anticipated shape. No plugin-cache mutations to undo (idempotent re-sync). No downstream schemas to migrate (v1.1 emit is CTP-side only; GCTP consumes).

## References

- CTP handoff: `.harness/plugin-cache/claude-tdd-pro/docs/handoff-ctp-to-gctp-p12-fixed.md` @ `f060a8e`
- CTP §30 amendment: `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §30` @ `f060a8e`
- CTP design detail: `.harness/plugin-cache/claude-tdd-pro/docs/design/v1.14-full-surface-intake.md` @ `f060a8e`
- CTP schema: `.harness/plugin-cache/claude-tdd-pro/schemas/business-profile.schema.json` @ `f060a8e`
- GCTP outbound P-12 handoff: `docs/handoff-ctp-p12-full-surface-intake.md` (proposal)
- GCTP prep commit: `9d2cf26` (`dev/kata-2026-07-03-consult`) — `--validate-profile` gate + invariant 4 + skill cascade against anticipated shape
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model" — pinned reference, no cross-repo edits, contract-only coupling
- Additivity invariant: ADR-0047
- Consult loop mechanism: ADR-0056
- Preceding pin bump: ADR-0086
