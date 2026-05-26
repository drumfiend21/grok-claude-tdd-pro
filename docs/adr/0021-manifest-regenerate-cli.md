# ADR-0021 — Manifest `--regenerate` CLI (TICKET-010.c)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed to build the remaining architecture" instruction 2026-05-26) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0018 (provenance-bridging design — this ADR ships the `--regenerate` path named in §6); ADR-0019 (manifest emitter — adds the `--regenerate` flag to the existing script); ADR-0020 (manifest validator — both audit paths now compose: schema validity AND tamper detection)

## Context

ADR-0018 §6 designed the auditor-only `--regenerate` path:

> *"If an auditor needs a fresh manifest for an old ticket (e.g., to detect post-hoc tampering), they invoke `manifest-regenerate --ticket TICKET-NNN`; the script re-hashes the current source files; if the new hashes don't match the original manifest's hashes, the original sources have been tampered or legitimately edited post-ticket. The regenerated manifest is written to `.harness/audit/TICKET-NNN.manifest.regenerated.json` — never overwriting the original. No regeneration helper at v1; design only."*

TICKET-010.a (ADR-0019) shipped the emitter. TICKET-010.b (ADR-0020) shipped the schema validator. The remaining sub-ticket from ADR-0018 §12 is `--regenerate`. This ADR ships it.

Two design questions had to be resolved:

1. **Separate script (`scripts/regenerate-manifest.sh`) or flag on the existing emitter (`scripts/emit-manifest.sh --regenerate`)?**
2. **Diff output format — line-by-line or aggregated summary?**

## Decision

### 1. `--regenerate` flag on the existing `scripts/emit-manifest.sh` (one script, two modes)

`--regenerate` is a flag on `scripts/emit-manifest.sh`, not a separate script. Rationale:

- **Identical hashing logic.** Both modes compute sha256 + size_bytes per source via the same code path. A separate script would duplicate ~80 lines of bash + the node-free hashing logic for no benefit.
- **One script, two output paths.** Write-mode lands at `.harness/audit/<id>.manifest.json`; regenerate-mode lands at `.harness/audit/<id>.manifest.regenerated.json`. The path choice is one `if` branch, not a separate executable.
- **D-9 (simple composable patterns).** A separate script would introduce two binaries with overlapping responsibilities and risk drift between them. One script with a flag is the canonical pattern for "same logic, different consumer."
- **Operator discoverability.** `scripts/emit-manifest.sh -h` documents both modes; no second `--help` to learn.

### 2. Diff output: per-kind sha lines + exit-1 on drift

When `--regenerate` runs, after writing the regenerated manifest the script:

1. Reads each `sources[].sha256` from the original manifest (`.manifest.json`).
2. Reads each `sources[].sha256` from the fresh manifest (`.manifest.regenerated.json`).
3. For each kind (`request`, `response`, `decision_trail`):
   - If shas match: emits `<kind>: unchanged (<sha>)` at info-level.
   - If shas differ: emits `<kind>: DRIFT` plus `original: <orig-sha>` and `current: <new-sha>` lines.
4. Exit code:
   - **0** = all sources match the original (no tampering detected).
   - **1** = one or more sources drifted (source file modified post-ticket; tamper or legitimate edit, both worth surfacing).

Rationale per D-12 (production-grade trust): the auditor needs to see *which source drifted*, not just "something drifted." Per-kind output gives the auditor the specific evidence to investigate. Exit-1 makes drift CI-detectable.

Hand-rolled bash + awk for sha extraction (matches ADR-0019's hand-rolled JSON generation; no jq dependency). The awk pattern parses the manifest's stable `{"kind": "X", "sha256": "Y"}` shape per ADR-0018 §3.

### 3. Original manifest is NEVER overwritten

Per ADR-0018 §6: `--regenerate` writes to `<id>.manifest.regenerated.json`; the original `<id>.manifest.json` is untouched. The script enforces this by computing two distinct output paths upfront and refusing to start if `--regenerate` is set but the original doesn't exist (exit 2 with an explicit error).

This preserves the audit-trail integrity property: an auditor running `--regenerate` six months later can still compare the regenerated output against the original-as-of-ticket-time. Without this invariant, the regeneration would overwrite the historical record and tamper detection would be meaningless.

## Alternatives considered

- **Separate script `scripts/regenerate-manifest.sh`.** Rejected per Decision-1. Same hashing logic; D-9 prefers one composable script with a flag.
- **`--regenerate` overwrites the original (no `.regenerated.json` file).** Rejected. Destroys audit-trail integrity; once overwritten, post-hoc tampering becomes undetectable.
- **`--regenerate` requires `--driver auditor` (force operator identification).** Rejected per D-8. The `--driver` field already accepts any string; auditor-specific identification is operator-policy, not script-enforced.
- **JSON-diff output (aggregated `{ kind: { orig, current } }` blob).** Rejected. Human-readable per-line output is the audit consumer's preferred shape; CI can grep the `DRIFT` token from the line-based output as easily as from JSON.
- **Exit 0 on drift (informational only).** Rejected per D-12. Drift IS the audit signal; exit-1 makes it CI-detectable. The 0/1/2 ladder mirrors `audit-doc-drift.sh`: clean = 0, findings = 1, script-error = 2.
- **Implicit `--regenerate` mode** (no flag — detect by output-file existence). Rejected. Implicit behavior is a D-12 trustability gap; the flag is the explicit, auditable signal of intent.
- **Validator integration** (have `audit-manifest.sh` automatically run `--regenerate` per file). Rejected per D-13. `audit-manifest.sh` validates schema, not freshness; freshness is a separate audit concern with a separate CLI.

## Consequences

### Positive

- **TICKET-010.c acceptance criterion met.** `--regenerate` ships; closes the third and final ADR-0018 sub-ticket. The provenance-bridging trilogy (design → emitter → validator → regenerate) is operationally complete.
- **Post-hoc tampering is now detectable.** A six-months-later auditor runs `scripts/emit-manifest.sh --ticket TICKET-NNN --regenerate`; if any source file has changed since the original manifest, the script surfaces which source, the original sha, and the current sha. Exit-1 makes it CI-pickup-able.
- **Audit-trail integrity preserved structurally.** The original manifest is never overwritten; the regenerated version lives alongside, allowing comparison.
- **D-9 honored.** One script, two modes. No script-count inflation; no logic duplication.
- **D-11 honored.** Composes on existing primitives (sha256sum/shasum, awk, file-read, atomic-rename, mv) — no reinvention.
- **D-12 honored.** Per-kind drift visibility; original sha + current sha lines in the output; exit-1 on drift.
- **Three-way audit composition.** `audit-doc-drift.sh` F-1..F-6 catches structural drift; `audit-manifest.sh` catches schema drift; `--regenerate` catches source-content drift relative to historical manifest. Each addresses a distinct failure mode; no overlap.

### Negative

- **No automated cadence for `--regenerate`.** The auditor must remember to run it; the harness doesn't schedule audits. Mitigation: future quality-gate v2 ADR could add a `provenance_freshness` sub-gate that runs `--regenerate` on each ticket's manifest at CI time; deferred per D-8 until evidence justifies.
- **The diff is per-kind, not per-byte.** A trail with a one-byte change shows the same DRIFT signal as a complete rewrite. Mitigation: per ADR-0018 §3 the manifest is index-only; byte-level diff is the auditor's next step (open the source file directly). The manifest's job is to surface "look here," not to display the diff itself.
- **`upstream_provenance_manifest_ref` is not re-validated on `--regenerate`.** A pinned upstream manifest could legitimately move; the regeneration doesn't compare upstream shas. Mitigation: upstream manifest validation is the upstream's own concern per ADR-0018 §3; the harness manifest references by path, not by content.
- **No `--regenerate-all`** (walk every ticket and regenerate). Mitigation: trivial shell loop; the CLI is per-ticket by design (one ticket = one audit unit). A future helper could batch.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies untouched.**
- **`schema_version` unchanged** (regenerate produces v1 manifests, same schema).
- **No new files in this CL** other than this ADR (the `--regenerate` flag is an edit to the existing `scripts/emit-manifest.sh`).
- **AGENTS.md untouched** (the new flag composes within the existing emitter; no top-level surface change).
- **`scripts/sync-plugin.sh --help` unchanged** (F-4 still passes).

## Verification (executed before commit)

- `bash -n scripts/emit-manifest.sh` clean.
- `scripts/emit-manifest.sh -h` documents `--regenerate` in the usage block.
- `./scripts/smoke-e2e.sh` produces a clean manifest.
- `./scripts/emit-manifest.sh --ticket TICKET-042 --regenerate` on the clean tree: exit 0; emits `<kind>: unchanged (<sha>)` per source; writes `.harness/audit/TICKET-042.manifest.regenerated.json` (original untouched).
- Tamper test: append `# AUDIT TAMPER TEST` to `.harness/trails/TICKET-042.md`; re-run `--regenerate`: exit 1; emits `decision_trail: DRIFT` + original/current sha lines; original `.manifest.json` still untouched.
- Restore via `./scripts/smoke-e2e.sh`; rerun `--regenerate`: exit 0 (clean again).
- `--regenerate` without an existing original manifest: exit 2 with explicit error.
- `./scripts/audit-doc-drift.sh` exit 0 on the clean tree (F-1..F-6 all clean).
- `./scripts/export-cursor-rules.sh --check` exit 0.
- ADR-0021 follows the numbered ADR template.

## Out of scope (deferred)

- **`--regenerate-all` batch mode.** Defer per D-8; trivial shell loop available.
- **Automated CI cadence** running `--regenerate` per manifest at PR-merge time. Defer to future quality-gate v2 ADR `provenance_freshness` sub-gate.
- **Byte-level diff output.** Out of scope per Consequences/Negative; auditor opens the source file for byte-level investigation.
- **Schema-version branching on `--regenerate`.** Out of scope per ADR-0020's deferred scope (validator handles schema-version branching; regenerate composes on validator output).
- **`upstream_provenance_manifest_ref` content-hash validation.** Out of scope per ADR-0018 §3.
- **Cryptographic signing on regenerated manifest.** Same `signature: null` deferral as ADR-0018.

## Implementation references

- Modified: `scripts/emit-manifest.sh` (adds `--regenerate` flag; one branch for output path; ~25-line per-kind diff block at the end; updated usage comment block)
- Modified: `docs/provenance-bridging-design.md §6` (`--regenerate` path updated from "design only" to "shipped in TICKET-010.c / ADR-0021")
- Modified: `TICKETS.md` (adds TICKET-010.c row marked DONE)
- New: this ADR
- Related: ADR-0018 (provenance-bridging design — this ADR's predecessor design), ADR-0019 (manifest emitter — same script, complementary mode), ADR-0020 (manifest validator — complementary audit lens for schema correctness), ADR-0009 (audit-doc-drift mechanism — peer audit framework; `--regenerate` is the third audit lens alongside F-1..F-6 + schema validator).
