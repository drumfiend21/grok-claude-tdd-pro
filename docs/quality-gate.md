# Quality Gate (the inner-loop "green" contract)

The harness's per-CL bar. A Claude→Grok response is allowed to claim `status: "green"` if and only if every enabled sub-gate is satisfied. This document is the single source of truth for what each sub-gate means; the wire format that carries the bar lives in [`handoff-contract.md`](handoff-contract.md).

## Purpose

`handoff-contract.md §"Grok → Claude (request)"` carries a `quality_gate` object. That object lists **which gates the requestor (Grok) wants enforced** for this ticket. This document formalizes:

- The semantics of each sub-gate.
- The defaults the dispatch template (`/.grok/templates/dispatch.md`) injects when the requestor does not override.
- The override policy (when a per-CL relaxation is acceptable, and how it must be documented).
- The reviewer checklist a human runs against any `.res.json` to decide whether "green" was earned.
- The cross-references to the plugin's cross-cutting contracts (`claude-tdd-pro/docs/architecture-v1.9.md §2.X`) the harness composes on rather than redefines.

## The four sub-gates

| Field in `quality_gate` | Status at schema_version=1 | Borrows from plugin | Per-CL override? |
|---|---|---|---|
| `tests_must_pass` | Required | (none — harness-native) | No |
| `coverage_delta_min` | Required (default `0`) | (none — harness-native) | Yes, with documented rationale |
| `lint_clean` | Required | (none — harness-native) | Yes, with documented rationale |
| `provenance_complete` | Recommended (additive); will be Required at schema_version=2 | §2.8 AI Provenance Manifest | No (when present) |

Per R-11 (tolerant reader) and R-5 (bilateral schema changes), `provenance_complete` is additive at schema_version=1: consumers that don't recognize the field MUST ignore it without erroring, and responses MAY omit it. The promotion to required-at-v2 lands via a future ADR and bumps `schema_version` in all three sites named by `dispatch.md`.

### Sub-gate 1: `tests_must_pass`

**Definition.** The project's idiomatic test command, invoked against the union of `file_scope.may_edit` and any test files transitively reachable from them, exits with status 0, has `failed == 0`, and has `passed >= 1`. The framework is named in the response's `test_results.framework`.

**Severity** (`§2.1 Rubric rule schema`-style classification): **P0**. A `status: "green"` response with `test_results.failed > 0` is malformed and MUST be rejected by Grok as `error.code: "gate_failed"`.

**Flake policy.** One automatic retry permitted per test name. Two consecutive failures of the same test counts as a real failure. Three or more retries-to-green within a single ticket attempt is itself a finding: the response should escalate via `status: "blocked"` with `error.code: "other"` and a note describing the suspected flake.

**Override policy.** None. There is no per-CL exemption for failing tests — that is what `status: "red"` is for.

**Reviewer checklist:**

- [ ] `status == "green"` implies `test_results.failed == 0`.
- [ ] `test_results.passed >= 1`.
- [ ] `test_results.framework` is named and is a real framework (not `"none"` or `"stub"`).
- [ ] The test command exercised files inside `file_scope.may_edit` (verifiable from the diff and the test paths).

### Sub-gate 2: `coverage_delta_min`

**Definition.** `(post-CL coverage) - (pre-CL coverage) >= request.quality_gate.coverage_delta_min`. "Coverage" defaults to line coverage; branch coverage is preferred when the framework supports it natively. Default threshold: `0` (no regressions).

**Severity** (per §2.1 style): **P1**. A coverage regression on a non-trivial CL is a finding; reviewers may accept it with documented rationale.

**Tooling-absent rule.** If the project does not have coverage tooling configured, the gate vacuously passes. The response's `notes` field MUST document the exemption ("coverage tooling not configured; gate exempt"). The `response.coverage_delta` field reports `0.0` in this case, not `null`.

**Override policy.** A per-CL relaxation is acceptable when the CL is a refactor or a substrate-only change (no behavior change). The response notes MUST state both (a) the relaxation request and (b) why no behavior change implies no coverage impact. Reviewers spot-check.

**Reviewer checklist:**

- [ ] If a coverage tool ran: `response.coverage_delta >= request.quality_gate.coverage_delta_min`.
- [ ] If no coverage tool: response notes documents the exemption verbatim.
- [ ] If override claimed: response notes states the (a)/(b) rationale.

### Sub-gate 3: `lint_clean`

**Definition.** The project-configured linter (ESLint for JS/TS, ruff for Python, golangci-lint for Go, clippy for Rust, etc.) exits 0 on at least the diff. If the linter does not support diff-mode, full-repo is acceptable and the run is recorded in the response notes.

**Severity** (per §2.1 style): **P1**. Warnings count as findings unless the response notes documents a per-warning exemption.

**Tooling-absent rule.** Identical to coverage: if no linter is configured, the gate vacuously passes and the response notes documents the exemption.

**Override policy.** A per-warning exemption is acceptable when the warning is a known false positive (logged in the project's lint-config) or when the lint rule is itself deprecated (per `§2.1 Rubric rule schema` `deprecated: true` semantics — the harness composes on the plugin's deprecation surface here).

**Reviewer checklist:**

- [ ] If a linter ran: exited 0; zero warnings, or each warning has a documented exemption.
- [ ] If no linter: response notes documents the exemption verbatim.
- [ ] Warnings exempted are listed by rule-id in the response notes.

### Sub-gate 4: `provenance_complete` (recommended at v1; required at v2)

**Definition.** The response's `decision_trail_ref` resolves to a file that exists, is readable, and names the three R-G-R steps (Red, Green, Refactor) — or, if Refactor was skipped, documents the skip with a one-line rationale. The trail file is the harness's minimum-viable provenance artifact; it composes on the plugin's `§2.8 AI Provenance Manifest` but does NOT inherit its full JSON schema (the manifest is the plugin's per-commit signature; the trail is the harness's per-ticket narrative).

**Severity** (per §2.1 style): **P0** when explicitly enabled by the requestor; **P1** when implicit. A missing trail file with `provenance_complete: true` in the request is `gate_failed`. A missing trail file when the field is absent is a warning.

**What the trail file MUST contain:**

1. The ticket id.
2. The mode (stub, real-claude, etc.).
3. A Red section naming the failing test or behavior.
4. A Green section naming the code change that closed the Red.
5. A Refactor section (or an explicit "Refactor: None — single-line change; further restructuring would be embellishment per Musk's Algorithm step 3" style skip statement).

**What the trail file MAY contain** (future-work hooks):

- Skills invoked (mirrors `response.skills_invoked`).
- Token / cost telemetry (forward-compatible with §2.8's `cost_telemetry`).
- Decisions referenced (forward-compatible with §2.8's `decision_provenance.adrs`).

**Override policy.** None when explicitly enabled. When implicit, a `decision_trail_ref: null` is acceptable for `status: "blocked"` or `"error"` responses (no R-G-R cycle to record).

**Reviewer checklist:**

- [ ] If `provenance_complete: true` in request: trail file exists, is non-empty, and contains Red + Green + Refactor sections (or documented skip).
- [ ] `decision_trail_ref` path is inside `.harness/trails/` (the gitignored runtime artifact location per ADR-0008).
- [ ] If trail names skills invoked: at least `tdd-pro-cl-workflow` for live-Claude mode, or "stub" for stub mode.

## Cross-cutting checks (apply regardless of which sub-gates are enabled)

These are not sub-gates per se — they are integrity checks the response must always satisfy. They live here because the reviewer applies them at the same time as the sub-gate check.

- [ ] **Scope.** `changed_files[].path` is a subset of `request.file_scope.may_edit`. None of `changed_files[].path` matches any glob in `request.file_scope.must_not_touch`.
- [ ] **Freshness.** `completed_at - issued_at <= context_ttl_seconds`. A response that took longer than the requested TTL is `status: "blocked"` with `error.code: "context_stale"`.
- [ ] **Schema.** `schema_version` in both `.req.json` and `.res.json` is the same; if not, `error.code: "schema_invalid"`.
- [ ] **Idempotency.** Re-running the inner loop with byte-identical `.req.json` produces a byte-identical `.res.json` (modulo `completed_at` timestamp). Smoke verifies this on the toy module per ADR-0008.

## Defaults injected by `dispatch.md`

When the requestor (Grok) does not specify `quality_gate` overrides, the dispatch template injects:

```json
{
  "tests_must_pass": true,
  "coverage_delta_min": 0,
  "lint_clean": true
}
```

The `provenance_complete` field is **not injected at schema_version=1** to preserve backward compatibility with consumers that pre-date this document. Requestors who want provenance enforcement add it explicitly. The v2 schema bump (future ADR) will inject it by default.

## Examples

### Example A — minimum-config project (toy module from TICKET-005)

The TICKET-005 toy has no coverage tooling, no linter. The expected `.res.json` `quality_gate` evaluation:

- `tests_must_pass`: ✓ (5/5 pass post-fix)
- `coverage_delta_min`: ✓ vacuously (no tooling; notes documents exemption)
- `lint_clean`: ✓ vacuously (no linter; notes documents exemption)
- `provenance_complete` (if requested): ✓ (the trail file exists and names R-G-R; the stub-mode smoke generates this verbatim per ADR-0008)

Result: `status: "green"`.

### Example B — minimum-config project, failing fix attempt

Same toy. The inner loop produces a patch that breaks one of the previously-passing tests (e.g., changes `.toLowerCase()` to `.toUpperCase()` by mistake):

- `tests_must_pass`: ✗ — `test_results.failed >= 1`.

Result: `status: "red"` with `error.code: "gate_failed"` and `error.details` listing the failing test names. The harness's response writer MUST NOT set `status: "green"` when this gate fails. The smoke script's step 3 enforces this for stub mode.

### Example C — full-config project (future state)

A real consumer project has Jest + nyc + ESLint. Defaults apply; `provenance_complete: true` set by requestor. All four sub-gates evaluate against real tooling output. The response includes structured `lint_run` and `coverage_run` fields (TBD via future ADR — not yet specified at schema_version=1).

## What this contract does NOT cover (deferred)

These belong to future tickets / ADRs:

- **Mutation testing.** The plugin's `claude-tdd-pro-principles.md §C-22` recommends mutation as the strongest test; the harness does not require it at the per-CL gate. Future ADR.
- **Property-based testing.** Not required. Same future-ADR path.
- **Performance regression budget.** Per-CL latency / memory budget. Not required.
- **Bundle-size budget.** JS/TS specific. Not required.
- **Type-check pass.** Indirectly covered by lint config in most projects (`tsc --noEmit` runs in pre-commit). Not a separate sub-gate.
- **Cross-CL aggregate metrics (DORA / SPACE).** Adjacent to this gate but not part of it. The plugin's `§2.11 SPACE metric schema` covers aggregate reporting. Per-CL gate is point-in-time; aggregates are time-series.
- **Threat-model gate.** Security regressions. Future ADR.
- **Compliance-control gate** (per the plugin's `§2.9 Control mapping`). Future ADR.

## Cross-references (composition, not duplication — per R-3)

This document **composes on**, never **duplicates**, the following plugin contracts:

- `§2.1 Rubric rule schema` — borrowed: `severity: P0 | P1 | P2`, `rule_state` enum (warn-only | block | disabled), and the `deprecated: true` semantics for lint-rule exemptions. The harness's quality gate uses the SAME enum labels; the plugin's authoritative file is the source.
- `§2.8 AI Provenance Manifest` — inspirational for sub-gate 4. The harness's trail file is a minimum-viable subset; the manifest itself remains the plugin's per-commit signature.
- `§2.11 SPACE metric schema` — adjacent. The per-CL gate does not duplicate the aggregate metric schema.

This document **defines** (harness-native):

- The four sub-gates' definitions, defaults, override policies, and reviewer checklists.
- The cross-cutting integrity checks (scope, freshness, schema, idempotency).
- The interaction between `quality_gate` fields and `status` / `error.code`.

## Authority and amendment

This document lives under TIER 2 (rulebook level — same tier as `architecture-principles.md`, `grok-orchestration-principles.md`, and `claude-tdd-pro-principles.md`). Amendments follow the ADR process in `architecture-principles.md §19`. Schema-version bumps that affect this contract land in the same CL as the rulebook update and as the dispatch-template / consumer-validator update, per R-5 (bilateral schema changes).

ADR-0010 records the v1 specification.
