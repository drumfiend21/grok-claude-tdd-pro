# ADR-0088 — Plugin pin bump `f060a8e` → `c23e5fe` (adopt CTP CL-547 / §30.1 — design-engine consumption of S-57 probe commitments; closes the second half of the KATA gap in the same cycle as ADR-0087)

- **Status:** Accepted
- **Date:** 2026-07-05
- **Deciders:** operator (`drumfiend21`; 2026-07-05: relayed CTP's built-close-out and its "no P-13 needed" recommendation) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** Within the same 24-hour cycle that landed ADR-0087, GCTP identified the second half of the KATA gap as still-open: the intake-side S-57 (§30) had made `probes.<namespace>` present in the v1.1 profile, but CTP's design engines (`business-translate.sh` / `architect-recommend.sh` / `architect-session.sh`) still read only the universal `answers`. This was the exact deferral CTP disclosed in §5 of the P-12 fixed handoff. Rather than round-trip it as P-13, CTP built the close-out as **CL-547 (§30.1)** and returned a handoff naming re-pin target **`c23e5fe`** (main HEAD; code SHA `62de9ec`). The close-out symmetrically completes §30: intake gathers full-surface facts AND the design engines consume them.
- **Continues:** the pin chain ADR-0072 → ADR-0079 → ADR-0085 → ADR-0086 → ADR-0087 → this ADR (`f060a8e → c23e5fe`).
- **Process:** §15-gated pin bump (upstream `architecture-v1.9.md` contract hash changes — §30.1 appended, 11 insertions / 0 deletions to the architecture doc). Consumer-side reconciliation on GCTP is **empty**: CTP wired the entire close-out inside its own engines; GCTP's `--validate-profile`, `audit-crosscheck` invariant 4, and `/consult` skill do not need reshaping because the probe consumption is entirely upstream of the GCTP consumer surface.

## Compatibility verdict (verified `f060a8e → c23e5fe`)

| Check | Result |
|---|---|
| Span | **1 CTP commit** (`62de9ec` CL-547 + merge `c23e5fe`) |
| upstream `architecture-v1.9.md` | **CHANGED** — **purely additive**: §30.1 appended (+11 insertions / 0 deletions); matches CTP's append-only discipline + ADR-0047 additive-only invariant |
| `CLAUDE.md` + 3 consumed `SKILL.md` | **all byte-identical** — prime-directive text + inner-loop discipline unchanged |
| Files changed | 12 files, 212 insertions, 8 deletions (aggregate). Arch: +11/0. Consumer engines (`commands/business-translate.sh` +56/-8, `commands/architect-recommend.sh` +14/0) — the 8 deletions are line-replacements inside CTP's own consumption wiring; the *semantic* effect is strictly additive per CTP's disclosure (consumption gated on `probes` presence, v1.0 profiles byte-identical) |
| `active.json` | expected **118 → 118 rules** (byte-identical; CL-547 adds no authored rules) |
| Changed plugin files | Modify: `commands/business-translate.sh` (S-33 probe consumption + expanded grounding catalog), `commands/architect-recommend.sh` (S-34 pick-influence), `docs/architecture-v1.9.md` (§30.1 append), `docs/design/v1.14-full-surface-intake.md` (§30.1 detail). Add: 8× `evals/specs/cl547-consume-*.json`. |

## Decision

Bump the pin `f060a8e → c23e5fe` — the main HEAD named in CTP's handoff. This closes the second half of the KATA gap (design-engine consumption of committed probe postures) that ADR-0087 knowingly left open, at the same authority tier and under the same additive discipline.

## What §30.1 delivers (the substantive change)

CTP's design engines now:

1. **S-33 `business-translate.sh` consumes `probes.<namespace>`.** For each committed posture, adds a **grounded** technical concern cited by the probe `source_id` — e.g. `owasp_threat_posture=adversarial` → threat_modeling + penetration_testing; `slsa_build_level=l3` → provenance_attestation; `react_accessibility_target=wcag-aa` → accessibility_conformance; `aws_region_strategy=multi-region` → multi_region; `k8s_multitenancy=multi-tenant` → namespace_isolation. Emits `probes_consumed=<n>` on stderr for observability. Grounding-verification catalog additively expanded (`eo-security-sources.yaml` + `sources.yaml`) so citations like `slsa-framework` / `wcag-2-2` resolve without a spurious `needs_grounding` bump.
2. **S-34 `architect-recommend.sh` consumes `probes.<namespace>`.** A decisive commitment can **modestly move the pick**: a committed multi-region posture upgrades the balanced default to the most-resilient option; a hard cost-cap pulls the pick toward cost-optimized. The influence is bounded — v1.0 profiles (no `probes`) get the identical pick they've always got.
3. **Back-compat by construction.** Both paths are gated on `probes` presence. A v1.0 profile → `probes_consumed=0` → concerns, grounding, and pick byte-for-byte unchanged (cl547-consume-06 verifies this end-to-end).

## Honest caveat: `business-translate` `needs_grounding` may decrease for a fixed v1.1 profile

CTP flagged this in its handoff: the grounding-verification catalog is additively expanded, so any GCTP audit that snapshots `needs_grounding` for a fixed profile should expect `≤` the prior value (never `>`). Verified safe on this side:

- `scripts/consult.sh --validate` requires `needs_grounding == 0` exactly. Reducing toward 0 keeps this gate green (or moves red → green; never green → red).
- `scripts/consult.sh --roadmap` same gate; same conclusion.
- `scripts/audit-architecture-crosscheck.sh` does not read `needs_grounding` at all.
- No other GCTP audit or test asserts a specific nonzero `needs_grounding` value.

Additive-only, monotone toward the passing side. No GCTP gate is exposed to a regression.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `c23e5fe`; the upstream `architecture-v1.9.md` sha256 updated (`3fec8e3a… → 66d8a3d1…`); other contract-file hashes unchanged (byte-identical). Bumped by hand under this ADR (the manual-edit-under-ADR path).
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `c23e5fe` via `sync-plugin.sh --ensure`.
- **`active.json`**: regenerated via `standards-sync.sh` — byte-identical (§30.1 adds no authored rules).
- **`docs/handoff-contract.md §Business-Intake`**: light amend to note that S-33/S-34 now consume `probes.<namespace>` at pin `c23e5fe`+ (invariants unchanged; consumer contract unchanged; observable via `probes_consumed=<n>` markers).
- **`docs/upstream-ctp-proposals.md §P-12`**: adoption note extended — "both halves closed at `c23e5fe` (§30 intake + §30.1 design-engine consumption)".
- **TICKETS.md**: **TICKET-115** added, DONE, pointing at this ADR.
- **Consumer surfaces (`--validate-profile`, invariant 4 audit, `/consult` skill)**: no changes needed. The close-out is entirely upstream of the GCTP consumer contract.

## Consequences

**Positive.**
- The operator's *"creates the seed for the project from which it will divide and grow"* is now true end-to-end: the seed is fuller (§30) AND the seed divides into design choices (§30.1). No follow-up on the CTP side; the KATA-discovered gap is fully closed.
- Every committed probe posture at intake now (a) grounds a concern in the technical requirements doc and (b) can steer the recommended option. The path from user commitment to design choice is straight-line and cited.
- The observable close-loop marker (`probes_consumed=<n>` at both S-33 and S-34) makes end-to-end wiring auditable without introducing a new contract surface.
- Back-compat preserved for v1.0 profiles by construction.

**Negative / knowingly accepted.**
- The "decisive commitment moves the pick" influence in S-34 is deliberately modest (per CTP: "modestly influence"). If a workload's committed postures are *not* decisive (mixed signals), the pick reverts to the pillar-weighted default — probes still show up as concerns, but pick doesn't move. This is the correct scope: probes STEER, they don't OVERRIDE. If a stronger influence is later wanted, that's a separate CL.
- Two pin bumps in the same day (ADR-0087 + ADR-0088) is unusual cadence. Justified by the fact that these two halves are one logical fix and CTP built the close-out inside the same 24-hour cycle.

**Neutral.**
- Historical P-13 candidate is superseded: no P-13 is filed (the close-out arrived from CTP without a round-trip). The P-12 ledger row is amended to reflect this.

## Rollback

`git revert` this commit → the lockfile snaps back to `f060a8e`; consumer engines revert to reading only the universal `answers`. The KATA gap re-opens at its second half. No downstream schema migration (v1.1 emit shape is unchanged; §30.1 changed only how S-33/S-34 CONSUME it).

## References

- CTP handoff (relayed by operator 2026-07-05, code SHA `62de9ec`, merge SHA `c23e5fe`)
- CTP §30.1 amendment: `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §30.1` @ `c23e5fe`
- CTP design detail: `.harness/plugin-cache/claude-tdd-pro/docs/design/v1.14-full-surface-intake.md` @ `c23e5fe`
- Preceding pin bump (first half of the gap): ADR-0087
- Additivity invariant: ADR-0047
- Consult loop mechanism: ADR-0056
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model"
