# ADR-0019 — Manifest emitter implementation (TICKET-010.a)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed to build the remaining architecture" instruction 2026-05-26) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0018 (provenance-bridging design — this ADR ships the emitter named in §13); composes on ADR-0008 (smoke-e2e.sh — the script gains the emitter call), ADR-0016 (Cursor slash commands — `/inner-loop.md` gains a Step 7 manifest emission), ADR-0017 (orchestrating-swarms — Step 5 reads manifests as the entry point)

## Context

ADR-0018 / TICKET-010 shipped the provenance-bridging design: a per-ticket index-only manifest at `.harness/audit/TICKET-NNN.manifest.json` that bridges Grok's `research_refs` (in `.req.json`), the inner-loop response (`.res.json` `gate_results`/`changed_files`/`test_results`), and Claude's decision trail (`.harness/trails/TICKET-NNN.md`) into a single auditor entry point. The design explicitly deferred the emitter implementation to TICKET-010.a.

This ADR ships that emitter and wires it into the three call sites named in ADR-0018 §7 Composition:

1. `scripts/smoke-e2e.sh` — calls the emitter after writing the decision trail (end-to-end smoke now produces all four runtime artifacts).
2. `.cursor/commands/inner-loop.md` — adds a Step 7 manifest emission (renumbering the previous "Surface artifacts" to Step 8).
3. `.claude/skills/orchestrating-swarms/SKILL.md` — Step 5 now reads the per-worker manifest as the entry point (rather than walking `.res.json` directly), with a documented fallback for `claude -p` headless paths that didn't emit on their own.

Three design questions had to be resolved:

1. **CLI surface.** What flags? What exit-code semantics?
2. **Failure handling at call sites.** If the emitter exits non-zero, do callers fail-hard, log-and-continue, or something else?
3. **JSON generation.** jq dependency, hand-rolled `printf`, or node?

## Decision

### 1. CLI surface: `--ticket <id>` required; `--driver` + `--upstream-ref` + `--quiet` optional

```
scripts/emit-manifest.sh --ticket TICKET-NNN [--driver <name>] [--upstream-ref <path>] [--quiet]
```

- **`--ticket`** is the only required flag. Computes paths from convention (`.harness/handoffs/<id>.req.json`, etc.) per ADR-0018 §4.
- **`--driver`** defaults to `"emit-manifest.sh"`; callers override with their own identification (`smoke-e2e.sh`, `cursor-inner-loop`, `swarm-lead-synthesis`, etc.). Lands in `manifest_generator.tool` per ADR-0018 §3.
- **`--upstream-ref`** is `null` by default; when supplied, the emitter validates the file exists and either records it or warns and sets `null` (per ADR-0018 §8 failure-mode-4).
- **`--quiet`** suppresses per-source informational output; warnings to stderr still surface.

Exit codes:
- **0** — manifest written; all three sources indexed.
- **1** — manifest written **with warning**: response or trail missing (`status` set accordingly), or `--upstream-ref` pointed at a missing file. Used by smoke-e2e.sh and `/inner-loop` to log non-blocking warnings.
- **2** — hard error: `--ticket` missing, request file missing (per ADR-0018 §6 "assert exists(req_path)"), ticket-id mismatch in `.req.json` or `.res.json`, mktemp failure, atomic-rename failure.

### 2. Call-site failure handling: defensive (additive evidence, not a gate)

All three call sites (smoke-e2e.sh, `/inner-loop`, orchestrating-swarms) invoke the emitter **defensively**:

- If `scripts/emit-manifest.sh` is missing or not executable, the caller skips the step silently (preserves the harness's "manifest emitter optional at v1; lands in TICKET-010.a" deferral honored).
- If the emitter exits non-zero, the caller **logs a warning and continues**. The manifest is *additive audit evidence*, not a smoke gate or an inner-loop gate. A failed emit does not invalidate the underlying work product.

Rationale per ADR-0018's design-only stance: the emitter ships to make the design real, but the gating semantics belong to a future quality-gate v2 ADR that promotes `provenance_complete` from RECOMMENDED to REQUIRED. Until that promotion lands, emitter failures are warnings, not errors.

### 3. JSON generation: hand-rolled `printf` (no jq dependency)

The emitter produces JSON via hand-rolled `printf` statements writing to a temp file, followed by atomic `mv -f` rename. No `jq` / `yq` / `node -e` dependency, matching the existing harness convention (`scripts/sync-plugin.sh`, `scripts/smoke-e2e.sh`).

Rationale: the manifest schema is tiny (~20 lines, 200 bytes – 2 KB), entirely string-and-integer fields, with at most one optional path. Hand-rolled JSON is auditable line-by-line and adds zero runtime dependencies. The C-23 portability target (bash 3.2 + BSD coreutils) is preserved.

Atomic-rename write (temp file + `mv -f`) prevents partial writes from racing readers per ADR-0018 §8 failure-mode-3.

## Alternatives considered

- **`jq` dependency.** Rejected. Adds a runtime dependency not present in any existing harness script; the manifest is too small to justify it.
- **`node -e`** (with the manifest body as a JS object literal). Rejected. The smoke-e2e.sh already uses `node -e` for JSON generation, but that pattern depends on node being installed; the emitter should work in environments where node isn't installed (e.g., CI runners with only bash + git + sha256sum). Hand-rolled `printf` is the lowest-common-denominator.
- **Multi-mode emitter** (`--smoke`, `--inner-loop`, `--swarm`). Rejected per D-8. The driver identification belongs in `manifest_generator.tool` (a free-string field), not in mode flags.
- **Fail-hard on missing response or trail.** Rejected. The whole point of the manifest is to record what *did* happen, including incomplete tickets. Exit code 1 (warning) + `status: "blocked"` + `response_missing` source-kind is the explicit record of incompleteness.
- **No defensive call-site handling — make manifest emission a hard prerequisite of `/inner-loop` Step 8 / smoke OK.** Rejected. The quality-gate v2 promotion is a separate decision; making emission mandatory in this CL would couple two scopes.
- **Write to `.harness/handoffs/<id>.manifest.json` (inside the existing handoffs dir).** Rejected per ADR-0018 §3. Directories-as-roles convention; `.harness/audit/` is the manifest's role.
- **In-place mutation when the manifest already exists.** Rejected. The manifest is logically immutable post-emission. `--regenerate` is the auditor-only path (TICKET-010.c, deferred). The current emitter overwrites via atomic-rename; concurrent racers (G-16 discipline violation already) are last-writer-wins per ADR-0018 §8 failure-mode-3.

## Consequences

### Positive

- **TICKET-010.a acceptance criterion met.** Emitter ships; wired into three call sites; produces valid JSON for the demo ticket; the `.harness/audit/` directory is gitignored at runtime per ADR-0018 §5.
- **Smoke-e2e.sh now produces full four-artifact output** (request + response + trail + manifest). `./scripts/smoke-e2e.sh` exit 0 with the manifest visible at `.harness/audit/TICKET-042.manifest.json`.
- **Cursor's `/inner-loop` slash command now produces a manifest** per Step 7 (renumbered). Operator sees the manifest path in the final summary alongside the existing three.
- **Orchestrating-swarms SKILL.md Step 5 reads manifests as the entry point** — auditor (or lead agent) reads the per-worker manifest first, walks sources second. The §5 fallback path (lead synthesizes the manifest when a `claude -p` worker didn't emit on its own) preserves the contract for non-emitter-aware drivers.
- **No new runtime dependencies.** Hand-rolled `printf` + sha256sum/shasum + wc/tr + awk + mv. All bash 3.2 / BSD-coreutils compatible.
- **R-3 honored.** Emitter writes index-only fields per ADR-0018 §3 schema. No `research_refs` / `gate_results` / R-G-R content copied.
- **R-2 honored.** Upstream `§2.8` is referenced by path-string only when `--upstream-ref` provided; never field-level copy-down.
- **D-1 reverse honored per ADR-0013.** This ADR cites the Grok-side analog (`research_refs` in `.req.json` and the upstream `§2.8` manifest pattern) in §Context.
- **D-11 honored.** Emitter composes on existing primitives (`sha256sum`/`shasum`, `wc`, `tr`, `awk`, `mv`, `mktemp`, `date`); no reinvention of file-hashing or JSON-encoding frameworks.
- **D-12 honored.** Every emitter exit-code path is documented + exit-0-verifiable. `--quiet` enables CI-friendly invocation; warnings always go to stderr.
- **`provenance_complete` sub-gate is now CONCRETE.** The quality-gate's RECOMMENDED-at-v1 sub-gate has a tangible bar an auditor can check: manifest file exists, sha matches `gate_results`-referenced trail. Future quality-gate v2 ADR can now promote this sub-gate from RECOMMENDED to REQUIRED.

### Negative

- **Manifest emission is best-effort at call sites** — non-zero emitter exits are logged warnings, not gating failures. A bad-actor / buggy emitter could silently fail to record audit evidence. Mitigation: the future TICKET-010.b validator + TICKET-015.a PostToolUse review hook close this gap by promoting the manifest to a gate.
- **`manifest_generator.version` is `null` at v1.** No driver-version tracking. Mitigation: the field is present in the schema; future ADR can populate it (e.g., from git sha or driver semver) without schema change.
- **No upstream-ref auto-detection.** The emitter cannot infer whether a plugin-consuming commit landed; `--upstream-ref` must be explicitly supplied. Mitigation: most callers don't produce a plugin commit per CL; `null` is the correct default. A future helper could detect plugin-commit context from git metadata.
- **Hand-rolled JSON is not schema-validated at emit time.** A bug in the emitter could produce malformed JSON that downstream readers reject. Mitigation: the integration test in this CL (`./scripts/smoke-e2e.sh` + `python3 -c "import json; ..."`) verifies parseability against the demo ticket; TICKET-010.b's planned `scripts/audit-manifest.sh` validator generalizes this to all manifests.
- **F-pattern audit doesn't cover manifest correctness.** `scripts/audit-doc-drift.sh` F-1..F-5 do not validate `.harness/audit/*.manifest.json`. Mitigation: explicit TICKET-010.b deferral; the F-6 pattern lands with the validator.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-1 reverse from ADR-0013 already covers).
- **`schema_version` of the handoff contract unchanged** (the emitter consumes the existing wire format).
- **No changes to AGENTS.md or `.cursor/rules/`** (this CL ships an implementation deferred from ADR-0018; the design-level changes already landed).
- **`scripts/sync-plugin.sh --help` text unchanged** (F-4 still passes).

## Verification (executed before commit)

- `bash -n scripts/emit-manifest.sh` clean.
- `scripts/emit-manifest.sh -h` prints the documented usage block.
- `./scripts/smoke-e2e.sh` exits 0; produces `.harness/audit/TICKET-042.manifest.json`; the manifest parses as JSON (`python3 -c 'import json; json.load(open(...))'`); `status` field equals `green`; `sources[].sha256` are 64-char hex strings; `created_at` is ISO-8601 UTC.
- Hand-edit a manifest source (append a byte to `.harness/trails/TICKET-042.md`) → regenerate manifest → sha256 differs from original → tamper detection demonstrated.
- `./scripts/audit-doc-drift.sh` exits 0 (F-1..F-5 clean).
- `./scripts/export-cursor-rules.sh --check` exits 0 (`.cursor/rules/` untouched).
- `.gitignore` adds `.harness/audit/`.
- `.cursor/commands/inner-loop.md` gains Step 7 manifest emission with the renumbered Step 8 for artifact surfacing.
- `.claude/skills/orchestrating-swarms/SKILL.md` Step 5 reads manifests as the entry point, with the synthesis fallback for non-emitter-aware drivers.
- ADR-0019 follows the numbered ADR template.

## Out of scope (deferred)

- **`scripts/audit-manifest.sh` schema validator** — TICKET-010.b.
- **`--regenerate` CLI for audit-time re-hashing** — TICKET-010.c.
- **`provenance_complete` sub-gate promotion to REQUIRED** — quality-gate v2 ADR (depends on TICKET-010.a, now landed; can proceed when the architect signals).
- **Driver-version detection** — future field-population ADR.
- **Plugin-commit-aware `--upstream-ref` auto-detection** — future helper.
- **Manifest signing (cryptographic)** — `signature` field remains `null` per ADR-0018 §3.
- **Cross-ticket aggregation reports** — future ADR.
- **F-6 audit pattern for manifest correctness** — bundled with TICKET-010.b validator.
- **Manifest-rejection mode on `/inner-loop`** — defer to quality-gate v2.

## Implementation references

- New: `scripts/emit-manifest.sh` (bash 3.2 + BSD-portable; ~140 lines; hand-rolled JSON via `printf`; atomic-rename write)
- Modified: `scripts/smoke-e2e.sh` (post-trail-write emitter call + manifest path in summary log)
- Modified: `.cursor/commands/inner-loop.md` (new Step 7 manifest emission; renumbered Step 8 surface)
- Modified: `.claude/skills/orchestrating-swarms/SKILL.md` (Step 5 reads manifest as entry point + synthesis-fallback subsection)
- Modified: `.gitignore` (adds `.harness/audit/` per ADR-0018 §5)
- Modified: `TICKETS.md` (adds TICKET-010.a row marked DONE)
- New: this ADR
- Related: ADR-0018 (provenance-bridging design — this ADR's predecessor), ADR-0008 (smoke-e2e + handoff wire — emitter integrates), ADR-0016 (Cursor slash commands — `/inner-loop` integrates), ADR-0017 (orchestrating-swarms — Step 5 integrates), ADR-0010 (quality-gate v1 — `provenance_complete` sub-gate now has a concrete artifact to point at).
