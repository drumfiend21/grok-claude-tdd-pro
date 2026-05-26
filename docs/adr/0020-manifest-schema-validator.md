# ADR-0020 — Manifest schema validator + F-6 audit pattern (TICKET-010.b)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed to build the remaining architecture" instruction 2026-05-26) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0018 (provenance-bridging design — this ADR ships the validator named in §12 sub-ticket 2); ADR-0019 (manifest emitter — this validator is the verification complement); ADR-0009 (audit-doc-drift mechanism — this ADR adds the F-6 pattern to its catalog)

## Context

ADR-0018 / TICKET-010 designed the per-ticket provenance manifest. ADR-0019 / TICKET-010.a shipped the emitter that writes manifests at the three call sites (`smoke-e2e.sh`, `/inner-loop`, `orchestrating-swarms` Step 5). Without a validator, an operator could hand-edit a manifest, or a future emitter bug could produce a malformed file, and no harness primitive would catch it — the audit script's F-1..F-5 catalog covers stale strings + generator-output drift, but not manifest schema correctness.

This ADR closes that gap: `scripts/audit-manifest.sh` validates every `.harness/audit/*.manifest.json` against the v1 schema documented in `docs/provenance-bridging-design.md §3`; `audit-doc-drift.sh` gains F-6 to delegate to it at pre-commit time.

Three design questions had to be resolved:

1. **JSON validation engine.** node (already a harness dependency via smoke-e2e.sh), python3 (also available), or hand-rolled bash grep/awk?
2. **Schema scope.** Validate every field exhaustively, or only the structurally-critical ones?
3. **F-6 wiring.** Inline node call inside audit-doc-drift.sh, or delegate to a separate audit-manifest.sh script?

## Decision

### 1. node for JSON parsing; bash for orchestration

The validator (`scripts/audit-manifest.sh`) is bash, walks `.harness/audit/*.manifest.json`, and shells out to `node -e` for the actual JSON parse + structural checks per manifest. Rationale:

- **node is already a harness dependency.** `scripts/smoke-e2e.sh` uses `node -e` for JSON generation (its `.req.json` + `.res.json` writers). No new dependency.
- **Hand-rolled bash grep would be fragile.** Manifest fields are well-defined types (string, number, array, null); validating types correctly via grep would re-invent JSON parsing. node's `JSON.parse` + simple property access is the right level.
- **python3 was rejected** because not every harness environment is guaranteed to have python3 in PATH; node is the established baseline.

The bash side does file walking, finding-message formatting, and findings file management (same pattern as `scripts/audit-doc-drift.sh`). The node side does one-file-at-a-time structural validation per the v1 schema.

### 2. Schema scope: every documented field + types + enums + cross-validations

The validator checks every field documented in ADR-0018 §3:

- Required top-level keys present: `schema_version`, `ticket_id`, `created_at`, `status`, `sources`, `upstream_provenance_manifest_ref`, `manifest_generator`, `signature`.
- `schema_version === "1"` (v1 is the only valid value today; future schemas increment per ADR-0018 §11).
- `ticket_id` is a non-empty string.
- `created_at` matches ISO-8601 UTC regex `^20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$`.
- `status` is one of `green | red | blocked`.
- `sources` is a non-empty array; each entry:
  - `kind` is one of `request | response | decision_trail | response_missing`.
  - `path` is a string.
  - For non-`response_missing` kinds: `sha256` is a 64-char hex string; `size_bytes` is a non-negative number.
  - For `response_missing` kind: `sha256` is `null` and `size_bytes` is `0` (per ADR-0019's emit-manifest.sh behavior on missing response).
- `upstream_provenance_manifest_ref` is `null` OR a string pointing at a file that exists.
- `manifest_generator` is an object with a non-empty `tool` field.
- `signature` is `null` (v1) OR a string (future).

Exhaustive validation is the right v1 scope because the schema is small (~10 fields), well-documented, and the cost of a passing validator that misses real corruption is higher than the cost of strict checks. R-11 tolerant-reader applies to *consumers reading manifests*; the validator is not a consumer — it's the pre-commit gate.

### 3. F-6 delegates to audit-manifest.sh; audit-doc-drift.sh does NOT re-implement parsing

The F-6 pattern in `scripts/audit-doc-drift.sh` is a thin delegation: it invokes `scripts/audit-manifest.sh --quiet`, parses the `[manifest-audit] *` output lines, and emits each as a `F-6 (manifest schema): ...` finding. Defensive — if `audit-manifest.sh` is missing or not executable, F-6 is silently skipped (matches the F-5 defensive pattern from ADR-0014).

Rationale: separation of concerns + reusability. `audit-manifest.sh` can be invoked directly by an auditor or CI (`scripts/audit-manifest.sh path/to/file.json` for one-shot validation), independently from the broader doc-drift audit. The F-6 path is one consumer of the validator; future CI manifest-rejection mode is another (deferred).

## Alternatives considered

- **Inline node call inside audit-doc-drift.sh.** Rejected per D-9 (simple composable patterns). The doc-drift script's F-1..F-5 patterns are all single-purpose; adding a multi-step manifest-walk inside it would inflate the file. Delegation is cleaner.
- **python3 for JSON parsing.** Rejected because node is already the established harness JSON tool; introducing python3 as a second JSON engine would create unnecessary parallel dependencies.
- **jq for JSON parsing.** Rejected — same reason as ADR-0019 (no jq in any existing harness script; manifest is small enough that node is sufficient).
- **Hand-rolled bash grep/awk for field-presence-only validation.** Rejected. Type validation (string vs. number vs. null vs. array) is fragile in bash; the validator would miss real corruption (e.g., `size_bytes` as a string instead of a number passes grep but breaks downstream consumers).
- **Validate only the structurally-critical fields (`schema_version`, `ticket_id`, `sources`).** Rejected. The cost of being lenient at the pre-commit gate is high: lenient gates accept malformed files that downstream consumers reject; the operator only discovers the problem later. Strict v1 is the right v1.
- **R-11 tolerant-reader stance for the validator** (accept missing optional fields silently). Rejected. R-11 governs *consumers reading wire formats over time*; the validator is the producer-side gate. R-11 still applies to future *consumers* of manifests, but the validator catches drift from the v1 contract at the gate.
- **Block the audit if `.harness/audit/` doesn't exist.** Rejected. An empty `.harness/audit/` (e.g., before any inner-loop has run) is normal pre-state; treating it as a finding would false-positive on every fresh clone.
- **Manifest-rejection mode in /inner-loop** (refuse to surface artifacts if the manifest is invalid). Rejected at v1. Per ADR-0019's defensive-call-site-handling decision, manifest emission is additive evidence at v1; gating is deferred to quality-gate v2. F-6 is the *audit* gate, not the *workflow* gate.
- **Per-source-kind validation rules in audit-manifest.sh** (e.g., decision_trail's path must end in `.md`). Rejected per D-13. The schema validates structure, not path conventions; the emitter enforces path conventions; mixing both into the validator inflates surface area.

## Consequences

### Positive

- **TICKET-010.b acceptance criterion met.** Validator ships; F-6 pattern lives in audit-doc-drift.sh; pre-commit audit now catches manifest corruption.
- **Manifest corruption is now detectable.** Hand-edit a `schema_version` value, a `sha256` string, or a `status` enum → F-6 catches it at pre-commit per the demonstrated tamper-detection pattern.
- **Defensive call-site discipline preserved.** F-6 is silently skipped if `audit-manifest.sh` is missing — matches the F-5 defensive pattern; no hard dependency.
- **One-shot validation usable by auditors.** `scripts/audit-manifest.sh path/to/file.json` validates a single manifest without walking the directory; useful for CI manifest-rejection mode (deferred but enabled).
- **D-1 reverse honored per ADR-0013.** This ADR cites ADR-0019 (the Claude-side emitter the validator pairs with) and the upstream §2.8 manifest pattern as the Grok-side analog the entire bridge composes on.
- **D-11 honored.** Composes on existing primitives: bash (orchestration), node (JSON parse), audit-doc-drift.sh (audit framework), the F-pattern catalog (extends F-5 pattern to F-6). No reinvention.
- **D-12 honored.** Every finding emitted is a specific, exit-0-verifiable claim about a specific field of a specific manifest file. Tamper detection at pre-commit is the production-grade-trust property promised by ADR-0018 now made concrete.
- **The `provenance_complete` sub-gate promotion path is now safer.** With both emitter (TICKET-010.a) AND validator (this CL) shipped, a future quality-gate v2 ADR can promote the sub-gate from RECOMMENDED to REQUIRED with confidence that the harness mechanism is complete.

### Negative

- **Validator depends on node.** A future migration to a different inner-loop driver that doesn't ship node would break the validator. Mitigation: node is already required by `scripts/smoke-e2e.sh`; removing node would require a much larger refactor that this ADR's coupling to node is the smaller dependency cost of.
- **F-6 adds runtime cost to audit-doc-drift.sh.** Each `.harness/audit/*.manifest.json` spawns a node process. Mitigation: manifests are typically 1-3 per active branch; even at 100 manifests the cost is sub-second. Future optimization (single node invocation walking all manifests) is deferred per D-8.
- **Strict v1 validation may false-positive on legitimate manifest evolution.** A future schema_version=2 manifest would fail F-6 against v1 rules. Mitigation: future ADR amending the validator handles schema_version branching; until then, only v1 manifests are valid by construction.
- **Validator surface (8+ field checks + 4 source-kind checks + 1 upstream-ref existence check) is the new audit surface area.** Mitigation: each finding is grep-detectable with a stable `:` separator; CI integration is straightforward.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **`schema_version` of the handoff contract unchanged.**
- **No new AGENTS.md or `.cursor/rules/` content** (validator is a script + audit-script integration; not a TIER-2 doc).
- **`scripts/sync-plugin.sh --help` text unchanged** (F-4 still passes).

## Verification (executed before commit)

- `bash -n scripts/audit-manifest.sh` clean.
- `bash -n scripts/audit-doc-drift.sh` clean.
- `scripts/audit-manifest.sh -h` prints usage block.
- Walk all manifests path: `./scripts/audit-manifest.sh` exits 0 on a clean tree with the smoke's TICKET-042 manifest present (or no manifests).
- One-shot path: `./scripts/audit-manifest.sh .harness/audit/TICKET-042.manifest.json` exits 0.
- Corruption detection: hand-edit `.harness/audit/TICKET-042.manifest.json` to set `"schema_version": "99"` → `./scripts/audit-manifest.sh` exits 1 with `schema_version-not-1:"99"` finding.
- F-6 integration: corrupt manifest → `./scripts/audit-doc-drift.sh` exits 1 with `F-6 (manifest schema): ...` finding; restore manifest → both audits exit 0.
- `./scripts/smoke-e2e.sh` exits 0 (full 4-artifact run including manifest emit).
- `./scripts/export-cursor-rules.sh --check` exits 0.
- ADR-0020 follows the numbered ADR template.

## Out of scope (deferred)

- **`--regenerate` CLI for audit-time re-hashing** — TICKET-010.c.
- **Single-process node walker** (one node invocation instead of one per manifest). Defer per D-8 — current cost is sub-second.
- **Schema-version branching** (validator handles both v1 and future v2 manifests). Defer to the future schema-v2 ADR.
- **CI manifest-rejection mode** (refuse PR merge on F-6 findings). Out-of-scope; the audit is currently pre-commit; future CI ADR can integrate.
- **`provenance_complete` sub-gate promotion to REQUIRED** — quality-gate v2 ADR; depends on both this ADR + ADR-0019, both now landed.
- **Manifest signing (cryptographic) validation** — out-of-scope; `signature` field remains `null` at v1 per ADR-0018 §3.
- **Per-source-kind path-suffix validation** (e.g., decision_trail must `.md`). Rejected per "Alternatives considered."
- **Inline node call** inside audit-doc-drift.sh. Rejected per "Alternatives considered."

## Implementation references

- New: `scripts/audit-manifest.sh` (bash 3.2 orchestration + `node -e` for JSON parse; ~120 lines)
- Modified: `scripts/audit-doc-drift.sh` (F-6 pattern; delegates to audit-manifest.sh; defensive skip when missing)
- Modified: `TICKETS.md` (adds TICKET-010.b row marked DONE)
- New: this ADR
- Related: ADR-0018 (provenance-bridging design — the schema this ADR validates), ADR-0019 (manifest emitter — the producer this ADR is the consumer-side verifier of), ADR-0009 (audit-doc-drift mechanism — extended with F-6 pattern), ADR-0014 (Cursor rules generator-output-only — the F-5 pattern this F-6 pattern follows the defensive shape of).
