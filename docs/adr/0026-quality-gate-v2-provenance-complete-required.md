# ADR-0026 — Promote `provenance_complete` to REQUIRED (TICKET-019)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 direction: *"Qualify and quantify over-engineering and avoid it. ... proceed to expand upon anything that is still worth it. And then complete."*) + Claude (cloud session, implementer)
- **Supersedes:** the "will be Required at schema_version=2" promotion language in `docs/quality-gate.md` §"The four sub-gates" — superseded BUT NOT replaced wholesale; the original language is preserved as historical record in the table footnote.
- **Extends:** ADR-0010 (quality-gate v1 — this ADR is the v2-equivalent promotion); ADR-0018 (provenance-bridging design — provides the manifest as the structural enforcement bar); ADR-0019 (manifest emitter); ADR-0020 (manifest schema validator); ADR-0021 (`--regenerate` audit-time re-hash)

## Context

`docs/quality-gate.md` shipped four sub-gates in v1 (per TICKET-007 / ADR-0010). Three were REQUIRED from day one (`tests_must_pass`, `coverage_delta_min`, `lint_clean`); the fourth — `provenance_complete` — was **RECOMMENDED (additive) at `schema_version=1`** with the documented promotion path: *"The promotion to required-at-v2 lands via a future ADR and bumps `schema_version` in all three sites named by `dispatch.md`."*

Why RECOMMENDED at v1: at the time ADR-0010 landed, the harness lacked a structural enforcement bar for provenance. The `decision_trail_ref` could point at any file shape; there was no schema-validated artifact, no tamper-detection mechanism, no audit-time re-verification. Promoting to REQUIRED before the enforcement infrastructure existed would have been aspirational, not structural — D-12 violation.

The TICKET-010 trilogy resolved that:

- **ADR-0018 (TICKET-010 — design)** — defined the per-ticket manifest at `.harness/audit/TICKET-NNN.manifest.json` as the index-only audit-trail entry point.
- **ADR-0019 (TICKET-010.a — emitter)** — shipped `scripts/emit-manifest.sh`; wired into smoke-e2e + `/inner-loop` + orchestrating-swarms Step 5.
- **ADR-0020 (TICKET-010.b — validator)** — shipped `scripts/audit-manifest.sh`; wired as F-6 audit pattern.
- **ADR-0021 (TICKET-010.c — `--regenerate`)** — shipped audit-time sha re-verification; never overwrites original.

With the trilogy shipped, the structural enforcement bar EXISTS. The promotion is now a documented gate-policy decision, not a wire-format change.

Two design questions had to be resolved:

1. **Does the promotion bump `schema_version` to 2** (per ADR-0010's original language) or **stay at `schema_version=1`** (treating the promotion as gate-policy, not wire-format)?
2. **What's the override policy** for `status: "red"` / `"blocked"` responses where no R-G-R cycle ran?

The over-engineering filter was also applied to this ticket BEFORE acting: 3 prior expansion candidates (provenance_complete promotion + 2 new sub-gates) → 1 (only the promotion). The new sub-gates were rejected as duplicate enforcement (covered below in §Alternatives).

## Decision

### 1. Stay at `schema_version=1`; promote via gate-policy, not wire-format

`schema_version` governs WIRE-FORMAT compatibility (R-5 bilateral schema changes; R-11 tolerant reader). The `provenance_complete` field's presence/absence in `.req.json` does not change at this ADR — `.req.json` schema is byte-stable. What changes is the GATE RUNNER's evaluation policy: a `status: "green"` response without a contract-valid manifest now `gate_failed`s, even if the request omitted the `provenance_complete` field.

Per R-11 (tolerant reader): consumers reading `.req.json` continue to tolerate the field's absence. The gate runner treats absence as `true` for `status: "green"` responses.

Per R-5 (bilateral schema changes): bumping `schema_version` would force every existing `.req.json` / `.res.json` consumer to update simultaneously — too aggressive for a policy-level change that the wire format already supports.

The original ADR-0010 language *"will be Required at schema_version=2"* was design-time intent BEFORE the trilogy was scoped. The corrected mechanism: trilogy provides the enforcement bar; ADR-0026 promotes the gate policy without touching the wire-format version.

### 2. Override policy: none for `green`; `response_missing` source-kind acceptable for `red`/`blocked`/`error`

- `status: "green"` → manifest MUST exist + validate (audit-manifest.sh exit 0) + `--regenerate` shows no source-sha drift. No override.
- `status: "red"` / `"blocked"` / `"error"` → manifest MUST exist, but the response source-entry MAY be `response_missing` kind (per emit-manifest.sh behavior when `.res.json` is absent). Trail file MAY be omitted. This is the documented fail-safe for inner-loop sessions that crashed mid-R-G-R.

Rationale: the `green` case is the audit-load-bearing case (a passing CL must have full provenance). The non-green cases are themselves diagnostic signals; demanding full provenance for crashed sessions would block the diagnostic path. The `response_missing` source-kind preserves the manifest's existence as the audit-trail entry point without demanding content that doesn't exist.

### 3. Sub-gate 4 reviewer checklist gains 2 new structural items

The pre-existing checklist had 3 items (trail file existence + path location + skills naming). The promotion adds:

- Manifest file existence at `.harness/audit/TICKET-NNN.manifest.json`.
- `scripts/audit-manifest.sh` exit 0 against the manifest.
- `scripts/emit-manifest.sh --regenerate --quiet` exit 0 (no source-sha drift since emission).

The first item is presence; the second is schema validity; the third is tamper detection. Together they fully verify the manifest as the structural enforcement bar. None require new infrastructure — all three scripts already shipped in TICKETS 010.a / 010.b / 010.c.

## Alternatives considered (over-engineering filter applied to each)

- **Bump `schema_version` to 2 per ADR-0010's original language.** REJECTED. Wire-format compatibility (R-11) is more valuable than the cosmetic clarity of "v1 had Recommended, v2 has Required." The gate-policy mechanism achieves the same enforcement without the breaking-change cascade across `.req.json` + `.res.json` + `dispatch.md`.
- **Add new sub-gate `manifest_validates`.** REJECTED per filter: duplicates F-6 audit-doc-drift pattern + audit-manifest.sh. Promoting `provenance_complete` to REQUIRED already requires the manifest to validate (per Decision-3 checklist); a separate sub-gate would force two evaluation paths for the same invariant. R-3 violation + maintenance cost.
- **Add new sub-gate `manifest_freshness`.** REJECTED per filter: duplicates `--regenerate` audit-time re-hash. Promoting `provenance_complete` to REQUIRED already requires `--regenerate` clean (per Decision-3 checklist); a separate sub-gate would force per-CL tamper-check on every CL (not just audit-time). Over-enforcement at the wrong cadence.
- **Add new sub-gate `swarm_outcomes_aggregated`** for the orchestrating-swarms case. REJECTED per filter: the swarm SKILL.md Step 5 (per ADR-0017) already requires reading each worker's manifest as the entry point; the swarm-level aggregation is a within-skill concern, not a per-CL gate-runner concern. Wrong layer.
- **Add a per-CL override audit item** that walks pending `coverage_delta_min` / `lint_clean` overrides at PR-merge time. REJECTED per filter: the existing per-CL override rationale documentation IS the audit signal; a separate audit item would duplicate the documentation pattern. Q-DOC-DRIFT already covers operator-visible surface drift.
- **Promote AND add the 3 sub-gates as one mega-CL.** REJECTED per D-9 (simple composable patterns) + the over-engineering filter applied earlier in this session: the promotion is 1 CL; the (potential) sub-gate additions would each be separate CLs IF they ever pass the filter (which they don't today). Mixing scopes = harder review + higher revert cost.
- **Defer the promotion indefinitely.** REJECTED. The trilogy shipped specifically to unblock this promotion; not promoting now leaves the trilogy's value-add unrealized. The over-engineering filter says "deletion-pass survives? — NO, the unlock value goes unrealized" — that's the trigger to act.

## Consequences

### Positive

- **TICKET-019 acceptance criterion met.** `provenance_complete` is REQUIRED in `docs/quality-gate.md`; reviewer checklist gained 3 new structural items leveraging the existing trilogy scripts.
- **The trilogy's value-add is realized.** TICKETS 010.a/.b/.c shipped specifically for this promotion; the promotion now lands without bumping schema_version (wire-format remains compatible).
- **Q-DOC-DRIFT discipline preserved.** Both `docs/quality-gate.md` AND the generator's mirror (`scripts/export-cursor-rules.sh gen_quality_gate`) updated in the same CL; `.cursor/rules/quality-gate.mdc` regenerated; F-5 audit clean.
- **R-3 (single source of truth) honored.** No new sub-gate definitions; the manifest infrastructure is referenced by path; the checklist items cite the trilogy scripts.
- **R-5 (bilateral schema changes) honored.** No wire-format change; existing `.req.json` / `.res.json` consumers continue to work; the gate runner's evaluation policy changed, not the wire format.
- **R-11 (tolerant reader) honored.** `provenance_complete` field absence in `.req.json` continues to be tolerated; gate runner treats absence as implicit-true for `green`.
- **D-12 (production-grade trust) strengthened.** The promotion takes provenance from "operator opt-in" to "always enforced for green"; the manifest infrastructure makes the enforcement structural rather than aspirational.
- **Over-engineering filter applied.** 3 prior expansion candidates → 1 actually shipped (67% cut). Rejected candidates documented with rationale.

### Negative

- **`status: "green"` responses without a contract-valid manifest will now fail the gate.** Existing test artifacts (e.g., `.harness/handoffs/TICKET-042.res.json` from older sessions) that don't have a matching manifest would fail audit if re-evaluated. Mitigation: `scripts/smoke-e2e.sh` already emits the manifest as of TICKET-010.a; runtime artifacts are gitignored so the "old artifacts without manifests" case is ephemeral and self-corrects on the next smoke run.
- **The original "will be Required at schema_version=2" language in ADR-0010 is now superseded.** Future readers may be confused. Mitigation: `docs/quality-gate.md` table footnote explicitly says "the original language is superseded; the schema bump is no longer the trigger; the trilogy is." ADR-0026 records the supersession.
- **Checklist gained 3 new items; reviewer cost increases marginally.** Mitigation: all 3 items are exit-0-grep-verifiable (run the script; check exit code); reviewer cost is sub-minute per CL.
- **Tight coupling between quality-gate.md sub-gate text and `scripts/export-cursor-rules.sh` mirror.** Q-DOC-DRIFT cost. Mitigation: this CL updates both in the same commit; F-5 catches future drift.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **`schema_version` of handoff contract unchanged at `"1"`** (KEY decision per §Decision-1).
- **AGENTS.md unchanged** (the quality-gate.md is already enumerated in AGENTS.md §5 TIER-2 list).
- **`scripts/sync-plugin.sh --help` unchanged** (F-4 still passes).
- **No new scripts.** All 3 enforcement scripts already exist (emit-manifest.sh, audit-manifest.sh, emit-manifest.sh --regenerate).

## Verification (executed before commit)

- `docs/quality-gate.md` sub-gate 4 promoted to REQUIRED in:
  - The §"The four sub-gates" table row.
  - The footnote paragraph below the table (supersedes "will be Required at schema_version=2").
  - The §"Sub-gate 4" section heading + Severity + Override policy + Reviewer checklist.
  - The §"Defaults injected by `dispatch.md`" paragraph.
- `scripts/export-cursor-rules.sh gen_quality_gate` body updated to match.
- `.cursor/rules/quality-gate.mdc` regenerated.
- `./scripts/export-cursor-rules.sh --check` exits 0.
- `./scripts/audit-doc-drift.sh` exits 0 (F-1..F-6 clean).
- `./scripts/smoke-e2e.sh` exits 0 (manifest emission already in place per ADR-0019; full 4-artifact run unchanged).
- `./scripts/audit-manifest.sh` exits 0 (validates the TICKET-042 manifest produced by smoke).
- ADR-0026 follows the numbered ADR template.
- TICKETS.md gains TICKET-019 row marked DONE.
- No `schema_version` references modified anywhere (wire format stable per Decision-1).

## Out of scope (deferred / rejected per over-engineering filter)

- **`manifest_validates` sub-gate.** REJECTED per §Alternatives.
- **`manifest_freshness` sub-gate.** REJECTED per §Alternatives.
- **`swarm_outcomes_aggregated` sub-gate.** REJECTED per §Alternatives (wrong layer; within-skill concern).
- **Per-CL override audit item.** REJECTED per §Alternatives (duplicates existing per-CL override documentation pattern).
- **Schema bump to v2.** REJECTED per §Decision-1 (wire-format compatibility > cosmetic clarity).
- **Backfill manifests for older `.harness/handoffs/*.json` from pre-ADR-0019 sessions.** Out of scope: runtime artifacts are gitignored; ephemeral; self-corrects on next smoke / inner-loop run.
- **Cryptographic signing on the manifest** (`signature: null` at v1 per ADR-0018 §3). Deferred.
- **CI integration of `--regenerate` at PR-merge.** Future ADR.

## Implementation references

- Modified: `docs/quality-gate.md` (4 sections updated: table row, table footnote, Sub-gate 4 §, Defaults paragraph)
- Modified: `scripts/export-cursor-rules.sh` (`gen_quality_gate` Sub-gate 4 mirror updated)
- Regenerated: `.cursor/rules/quality-gate.mdc`
- Modified: `TICKETS.md` (TICKET-019 row marked DONE)
- New: this ADR
- Related: ADR-0010 (quality-gate v1 — this ADR's predecessor; superseded "will be Required at v2" language), ADR-0018 (provenance-bridging design — provides the manifest contract), ADR-0019 (manifest emitter — provides the structural enforcement primitive), ADR-0020 (manifest validator — referenced in reviewer checklist), ADR-0021 (`--regenerate` — referenced in reviewer checklist), ADR-0014 (Cursor rules generator-output — F-5 enforces quality-gate.mdc consistency with `docs/quality-gate.md`).
