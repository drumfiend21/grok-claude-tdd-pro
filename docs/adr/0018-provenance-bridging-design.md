# ADR-0018 — Provenance + decision-trail bridging design (TICKET-010)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Continue work" instruction + AskUserQuestion answer selecting TICKET-010 as next focus on 2026-05-26) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** `docs/handoff-contract.md` (the wire format the manifest indexes); `docs/quality-gate.md §Sub-gate 4 provenance_complete` (the RECOMMENDED-at-v1 sub-gate this design enables promotion of); `docs/self-healing-design.md` (the long-loop consumer of manifests); composes on `claude-tdd-pro/docs/architecture-v1.9.md §2.8 AI Provenance Manifest` (upstream per-commit manifest pattern)

## Context

TICKETS.md TICKET-010 is queued: *"Design: how Grok's research provenance and Claude's decision trail merge into a single audit artifact per ticket. Cross-references claude-tdd-pro's §2.2 provenance manifest. Done when: Design doc; defines the merged artifact's shape."*

Today the harness's per-ticket audit evidence is spread across three surfaces:

1. **Outer-loop provenance** — `research_refs` array inside `.harness/handoffs/TICKET-NNN.req.json` (carried per `docs/handoff-contract.md §Grok→Claude`).
2. **Inner-loop response** — `gate_results`, `changed_files`, `test_results` inside `.harness/handoffs/TICKET-NNN.res.json` (per `§Claude→Grok`).
3. **Decision trail** — markdown narrative naming the R-G-R steps (per `tdd-pro-cl-workflow/SKILL.md`) at `.harness/trails/TICKET-NNN.md`.

An auditor reconstructing the ticket's full provenance must know all three file paths and the conventions linking them. The harness's value proposition is production-grade trustability (D-12); three-surface reconstruction is fragile.

The TICKETS.md row also contained a factual error: it referenced "claude-tdd-pro's §2.2 provenance manifest" but the actual upstream contract is **§2.8 AI Provenance Manifest** (§2.2 is the unrelated "Detector contract"). This CL corrects the reference.

Four design questions had to be resolved:

1. **Does the merged artifact exist as a new file, or is it a virtual "bundle" of the existing three?**
2. **Is the new file index-only (paths + hashes) or content-merged (copies of research_refs / gate_results / trail R-G-R steps)?**
3. **Where does the manifest sit relative to upstream `claude-tdd-pro` §2.8 — duplicate / extend / reference-only?**
4. **What's the implementation scope at v1 — design + emitter, or design only with emitter deferred?**

## Decision

### 1. New file: `.harness/audit/TICKET-NNN.manifest.json`

The merged artifact is a small, per-ticket JSON file at `.harness/audit/TICKET-NNN.manifest.json`. A new `.harness/audit/` directory joins `.harness/handoffs/` and `.harness/trails/` as the third per-ticket runtime-artifact surface; the directory's role (audit-trail entry point) is structurally distinct from wire format (handoffs) and trail narrative (trails).

A virtual "bundle of three files" was rejected because no entry point exists today; an auditor still has to know all three paths. A separate index file gives one read for ticket-level audit evidence. R-3 (single source of truth) is preserved by making the index-only-no-content decision (§Decision-2).

### 2. INDEX-ONLY (paths + sha256 + size + status enum); no content duplication

The manifest contains:

- `schema_version`, `ticket_id`, `created_at`, `status` (the `green`/`red`/`blocked` enum from `.res.json`)
- `sources[]` — one entry per source file (`request`, `response`, `decision_trail`) with `kind` + `path` + `sha256` + `size_bytes`
- `upstream_provenance_manifest_ref` — `null` at v1 unless a plugin-consuming commit landed
- `manifest_generator` — tool + version of the emitter
- `signature` — reserved, `null` at v1

The manifest does NOT copy:

- `research_refs` content (lives in `.req.json`)
- `gate_results` content (lives in `.res.json`)
- `changed_files`, `test_results` (live in `.res.json`)
- R-G-R step narrative (lives in `.harness/trails/TICKET-NNN.md`)

Rationale per R-3: a content-merging manifest would either drift from sources (when sources change post-emission) or force re-emission on every change. Index-only manifests are immutable post-generation, detect tampering via sha mismatch, and stay small (200 bytes – 2 KB). The `status` enum is the ONE exception — it is a single-value enum that gives auditors an at-a-glance outcome without opening any source.

### 3. Reference upstream `claude-tdd-pro` §2.8 by path; never duplicate fields

The harness's per-ticket manifest is a lean cross-tool bridge. The upstream `§2.8 AI Provenance Manifest` is a per-commit, plugin-internal manifest carrying rubric/standards/PR-corpus/compliance/cost-telemetry fields appropriate to the plugin's quality-core role.

The harness manifest's `upstream_provenance_manifest_ref` field carries a string path (e.g., `.claude-tdd-pro/provenance/<commit-sha>.json`) when a plugin-consuming commit landed. When non-null, auditors walk BOTH manifests. No field-level copy-down — the upstream's `models_used`, `rubric_state`, `cost_telemetry`, `signature` fields are NOT duplicated in the harness manifest.

Rationale per R-3 + R-2 (versioned consumption): copying upstream §2.8 fields into the harness manifest would create vendoring (R-2) and divergence (R-3). Referencing by path is the contract-compliant bridge.

### 4. Design only at v1; implementation deferred to TICKET-010.a

Per TICKET-010's acceptance criterion ("Design doc; defines the merged artifact's shape") and per D-8 (deletion discipline): this CL ships the design + the ADR; it does NOT ship the emitter, the validator, the signing path, or the `--regenerate` CLI. Implementation deferred to:

- **TICKET-010.a** — `scripts/emit-manifest.sh` + integration with `smoke-e2e.sh` + `.cursor/commands/inner-loop.md` + `.claude/skills/orchestrating-swarms/SKILL.md` Step 5. Adds `.harness/audit/` to `.gitignore`.
- **TICKET-010.b** — `scripts/audit-manifest.sh` schema validator (Q-DOC-DRIFT cousin specific to manifest schema).
- **TICKET-010.c** — `--regenerate` CLI for audit-time re-hashing (auditor-only path; original manifest never overwritten).

The deferral mirrors the existing self-healing-design.md → TICKETS 008.a..e pattern.

## Alternatives considered

- **Virtual "bundle" — no new file; auditor learns the three-path convention.** Rejected. Three-path discovery is fragile; an explicit entry point is a D-12 production-grade-trustability requirement.
- **Content-merged manifest (copy `research_refs` + `gate_results` + R-G-R steps).** Rejected per R-3. Forces re-emission on every source change; risks drift; doesn't reduce auditor work because the auditor still must verify the copy matches the source.
- **Duplicate upstream §2.8 fields into the harness manifest.** Rejected per R-2 + R-3. Vendoring; would require upstream-pin-aware regeneration. The reference-by-path approach is the contract-compliant bridge.
- **Manifest at `.harness/handoffs/TICKET-NNN.manifest.json`** (inside the existing handoffs dir). Rejected. `.harness/handoffs/` is the wire-format directory; mixing roles violates the directory-as-role convention.
- **Markdown manifest format (`.manifest.md`) instead of JSON.** Rejected. The manifest is machine-readable index; JSON is the cross-tool standard. Markdown would force every consumer to parse human-readable structure for what is structurally index data.
- **Ship the emitter at v1.** Rejected per TICKET-010's "Design doc only" acceptance criterion and D-8 (deletion discipline). Design + ADR is the contract; implementation is the next sub-ticket.
- **Add `provenance_complete` REQUIRED promotion in this CL.** Rejected. Sub-gate promotion is a quality-gate v2 concern; depends on TICKET-010.a (emitter) landing first; lands in its own ADR with its own scope.
- **Cryptographic signing at v1.** Rejected per D-8. `signature` field reserved as `null`; future ADR if compliance demands.
- **Per-author / per-reviewer audit fields.** Rejected per D-13. Harness-internal scope is ticket-level; author/reviewer fields belong upstream in §2.8 or in commit metadata.

## Consequences

### Positive

- **TICKET-010 acceptance criterion met.** Design doc ships; defines the merged artifact's shape (§3 schema + §4 source-of-truth map + §5 storage); no code.
- **One entry point per ticket for audit.** Auditor reads `.harness/audit/TICKET-NNN.manifest.json` once and knows what to walk. Three-surface fragility resolved structurally, not aspirationally.
- **Tamper detection via sha256.** Source files modified post-ticket are detected when the manifest is regenerated and shas diverge. No detection at v1 (no `--regenerate` CLI yet), but the field is in the schema; the future TICKET-010.c CLI plugs in without schema change.
- **R-3 honored.** Manifest is index-only; no content copy from sources. Sources remain canonical.
- **R-2 honored.** Upstream §2.8 is referenced by path, not vendored.
- **D-1 reverse honored per ADR-0013.** This design doc + ADR-0018 cite the Grok-side analog (the `research_refs` field already in `.req.json` per dispatch.md) and explain the bridge.
- **Quality-gate v2 promotion path named.** Sub-gate 4 (`provenance_complete`) can promote from RECOMMENDED to REQUIRED in a future ADR once the emitter ships (TICKET-010.a); the design names the path.
- **Swarm-compatible by design.** Each parallel worker in an `orchestrating-swarms` SKILL.md fanout produces its own `.res.json` + trail, hence its own manifest. The swarm lead (Step 5 of the skill) calls the emitter per worker; no special swarm-aggregation manifest needed at v1.
- **TICKETS.md §2.2 → §2.8 ticket-text correction.** A factual error in the original TICKET-010 row is fixed in the same CL that ships the design.

### Negative

- **Manifest is not auto-emitted at v1.** Until TICKET-010.a lands, manifests are unwritten; the design is contract-only. Mitigation: TICKETS.md adds TICKET-010.a explicitly; the deferral is named, not silent.
- **`signature: null` at v1 leaves the manifest unforgeable but unverifiable.** A bad actor could hand-write a manifest; sha mismatches catch tampering of sources but not of the manifest itself. Mitigation: future signing ADR; for now, manifests live alongside the same git-tree audit-trail (commits) that any auditor can cross-reference. Manifests are gitignored at runtime but produced by trusted operator paths.
- **`upstream_provenance_manifest_ref` requires the inner-loop driver to know if it landed a plugin-consuming commit.** Mitigation: at v1, the field is `null` by default; the emitter populates only when invoked from a context with the upstream-commit-sha available (e.g., via env-var, CLI flag, or commit metadata). Drivers that don't know set `null`; auditors see the gap explicitly.
- **`.harness/audit/` is a new gitignored directory** — adds one line of harness runtime convention. Mitigation: matches the existing `.harness/handoffs/` + `.harness/trails/` pattern; documented in `.gitignore` (added in TICKET-010.a).
- **Concurrent emission for the same ticket-id is last-writer-wins.** Mitigation: concurrent emission is itself a discipline violation (G-16 atomic-ticket rule); §8 failure-mode-3 names the structural mitigation (atomic-rename write) without papering over the upstream discipline gap.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance, §3 D-rule bodies, §4 D-checklist untouched** (D-1 reverse from ADR-0013 already covers).
- **`schema_version` of the handoff contract unchanged** (the manifest references handoffs by path; does not modify the wire format).
- **`AGENTS.md §5` gains one TIER-2 enumeration entry** (`docs/provenance-bridging-design.md`); no section restructure.
- **`.cursor/rules/agent-context.mdc` generator gains one TIER-2 enumeration entry** (mirroring the AGENTS.md update); regenerated in this CL; F-5 audit passes.
- **No new scripts in this CL** (the design names TICKET-010.a / .b / .c as the deferred implementation sub-tickets).

## Verification (executed before commit)

- `test -f docs/provenance-bridging-design.md` exits 0.
- §1–§13 section markers grep-detectable.
- Every cited primitive resolves: `docs/handoff-contract.md`, `docs/quality-gate.md`, `docs/self-healing-design.md`, `.claude/skills/tdd-pro-cl-workflow/SKILL.md`, `.claude/skills/orchestrating-swarms/SKILL.md`, `.grok/templates/research.md`, `scripts/smoke-e2e.sh`, upstream `claude-tdd-pro/docs/architecture-v1.9.md §2.8` (via plugin cache).
- `AGENTS.md §5` lists `docs/provenance-bridging-design.md` in the TIER-2 enumeration.
- `scripts/export-cursor-rules.sh` updated to include the new TIER-2 doc; `.cursor/rules/agent-context.mdc` regenerated.
- `./scripts/export-cursor-rules.sh --check` exit 0.
- `./scripts/audit-doc-drift.sh` exit 0 (F-1..F-5 clean).
- `./scripts/smoke-e2e.sh` exit 0 (toy at Red baseline; this CL touched no executable beyond docs / AGENTS.md / generator output).
- `bash -n scripts/export-cursor-rules.sh` clean.
- ADR-0018 follows numbered ADR template.
- TICKETS.md row for TICKET-010 corrected (§2.2 → §2.8) and marked DONE; TICKET-015 housekeeping (DONE marker) folded in.

## Out of scope (deferred)

- **Manifest emitter implementation** (`scripts/emit-manifest.sh`). TICKET-010.a.
- **Manifest schema validator** (`scripts/audit-manifest.sh`). TICKET-010.b.
- **`--regenerate` CLI for audit-time re-hashing.** TICKET-010.c.
- **Cryptographic signing of manifests.** Future ADR.
- **`provenance_complete` sub-gate promotion to REQUIRED.** Quality-gate v2 ADR.
- **Cross-ticket aggregation reports.** Future ADR.
- **Swarm-aggregated outcome manifests** (one manifest indexing N worker manifests). Future swarm-audit ADR.
- **Upstream `§2.8` field-level copy-down.** Permanently rejected unless R-3 is amended.
- **Per-author / per-reviewer audit fields.** Out-of-scope per D-13.
- **`.harness/audit/` `.gitignore` entry.** Lands with TICKET-010.a alongside the emitter — adding the gitignore without an emitter would be an empty-directory cosmetic change.

## Implementation references

- New: `docs/provenance-bridging-design.md`
- New: this ADR
- Modified: `AGENTS.md` (§5 TIER-2 enumeration adds the new doc)
- Modified: `scripts/export-cursor-rules.sh` (`gen_agent_context` TIER-2 list adds the new doc)
- Regenerated: `.cursor/rules/agent-context.mdc` (`export-cursor-rules.sh` re-emit)
- Modified: `TICKETS.md` (TICKET-010 row corrected §2.2 → §2.8 + marked DONE; TICKET-015 marked DONE)
- Related: ADR-0010 (quality-gate v1 — the source of the `provenance_complete` sub-gate this design enables promotion of), ADR-0011 (self-healing-design — consumer of the manifest for long-loop monitoring), ADR-0017 (orchestrating-swarms — produces N manifests per swarm, one per worker), ADR-0008 (smoke-e2e + handoff wire — the schemas the manifest indexes), ADR-0013 (D-1 bidirectional — the attribution policy followed in the design doc's trailer), upstream `claude-tdd-pro/docs/architecture-v1.9.md §2.8` (AI Provenance Manifest — the per-commit upstream pattern the harness manifest references by path).
