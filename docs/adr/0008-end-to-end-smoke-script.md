# ADR-0008 — End-to-end smoke script (stub mode default; live-Claude deferred)

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, "Proceed" instruction continuing per the design-time ticket plan) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0001 (lock + sync), ADR-0006 (Grok orchestrator templates — this ADR is the *executor* of the wire format ADR-0006 defines), ADR-0007 (Claude skill consumption — this ADR proves the symlinked skills are real consumers of the contract)

## Context

TICKET-006 is the harness's first end-to-end smoke test. The acceptance criterion is "script exits 0 on the TICKET-005 toy module after one full R-G-R cycle." This is the first CL where the outer-loop (Grok templates), the contract (`docs/handoff-contract.md`), the inner-loop wiring (`.claude/skills/tdd-pro-*` symlinks from ADR-0007), and the toy (TICKET-005) all execute in a single chain that produces a verifiable exit code.

Two pressures shape the design:

1. **CI determinism.** The smoke must run in environments without API credits, without outbound network beyond what `git clone --depth=1` already needed, and without a separately-installed `claude` CLI. CI gates exist for early-warning value; if the smoke depends on live LLM credits it becomes flaky and dropped from CI within weeks.
2. **Wire-format authenticity.** The harness's value proposition is the *handoff contract*. A smoke that runs `node --test` twice (red, then green) proves nothing about the contract; it would pass even if `docs/handoff-contract.md` were deleted. The smoke must read/write real `.req.json` and `.res.json` documents that validate against the schema.

These pressures pull in opposite directions: CI determinism wants no LLM; wire authenticity wants the real inner-loop. The resolution is to separate the two responsibilities and make wire authenticity the always-on path.

## Decision

### 1. Default mode is **stub**: deterministic patch + real wire-format I/O

`scripts/smoke-e2e.sh` runs without any LLM call. The inner-loop work is replaced by a hard-coded one-line patch — insert `.trim()` after `.toLowerCase()` in `examples/string-utils/src/string-utils.mjs` — that mimics what the live `tdd-pro-cl-workflow` skill would do for this exact ticket. Everything else is real:

- **Step 1 (outer-loop emit):** Build a JSON document that conforms exactly to `docs/handoff-contract.md §"Grok → Claude (request)"`, populated from the contract's worked example (TICKET-042 slugify-trim). Write it to `.harness/handoffs/TICKET-042.req.json`. Then run the dispatch template's `§"Pre-emit checks"` against the document — `schema_version == "1"`, non-empty `acceptance_criteria`, non-empty `may_edit`, `must_not_touch` includes `.grok/**`, `.claude/**`, `claude-tdd-pro/**`, `issued_at` matches the second-precision UTC ISO-8601 regex, `context_ttl_seconds ∈ [60, 86400]`. The validator is six lines of Node and lives inline in the script.
- **Step 2 (inner-loop):** Apply the canonical Green patch.
- **Step 3 (test gate):** Invoke `node --test` on the toy and parse the TAP summary (`# pass N`, `# fail N`, `# duration_ms N`). Failure (any non-zero exit, non-zero `# fail`) aborts the smoke.
- **Step 4 (outer-loop receive):** Build a response document conforming to `§"Claude → Grok (response)"`, populated from the real test-gate output. Write it to `.harness/handoffs/TICKET-042.res.json`. Also write the decision trail at `.harness/trails/TICKET-042.md` (referenced by `res.decision_trail_ref`).

The response's `notes` field declares stub provenance explicitly: *"STUB MODE: response synthesized by scripts/smoke-e2e.sh; deterministic .trim() patch stood in for live claude -p invocation."* This makes downstream consumers (and reviewers) immediately aware that this document is a synthesized stand-in.

### 2. Live-Claude mode is **deferred**, not abandoned

A `--real-claude` flag was prototyped during design but cut from this CL per Musk's Algorithm step 2 (delete before optimize). Justifications for deferral:

- No current CI workflow invokes the smoke; gating value comes from local-developer runs and the imminent TICKET-009 demo storyboard.
- The script's stub structure leaves a single insertion point (Step 2) where the real `claude -p --skill tdd-pro-cl-workflow < $REQ_PATH > $RES_PATH` swap-in would happen.
- The live mode introduces dependencies (credentials, network, retry/timeout policy, log streaming) whose design hasn't been spec'd. Adding them now would couple TICKET-006 to undefined TICKET-007/008/009 work.

When the live mode lands, it does so as an additive ADR (not a supersede) that adds `--real-claude` flag handling, replaces Step 2 with a `claude -p` invocation, validates the returned `.res.json` against the contract (catching skill output drift), and falls back to stub mode on credential absence.

### 3. Idempotency via revert-on-exit trap

After Step 4, a bash `EXIT` trap restores the toy source from a `mktemp`-backed snapshot. This preserves TICKET-005's invariant ("ships at 4 pass / 1 fail") across smoke runs. The trap fires on normal exit, on `set -e` failure, and on SIGINT/SIGTERM. Without it, the first smoke run leaves the toy green, breaking both the next smoke run and the standalone `node --test` baseline.

The handoff/response/trail artifacts are NOT cleaned up. They live in `.harness/handoffs/` and `.harness/trails/` (now gitignored) after a run, available for inspection. This is intentional — operators inspecting the harness's wire format want to see real artifacts, not phantoms.

### 4. Validation is hand-rolled, not via a JSON Schema library

The pre-emit checks in `.grok/templates/dispatch.md` list eight discrete rules. Each is one or two lines of Node. Pulling in `ajv` or `jsonschema` would add a `package.json`, `node_modules/`, and 200kB of dependency to validate a document that is ~30 fields. Per D-9 (simple composable patterns) and D-11 (design FOR primitives), inline validation wins.

If/when the harness grows additional schemas (Grok→Grok intermediate documents, claude-tdd-pro internal manifests, etc.) and validation logic crosses ~5 schemas or ~50 rules, **then** a schema library is justified. Not before.

### 5. The smoke covers exactly *one* canonical example, not many

The smoke runs against TICKET-042 (the slugify-trim case from the contract's worked example) — that and only that. It does NOT iterate over every contract scenario, does NOT exercise the blocked/error response paths, does NOT test the `dispatch_collision` rejection case.

Rationale: a smoke proves "the harness is alive end-to-end." Coverage of error paths is a *test suite* concern, deferred until the harness has actual error paths worth testing (most current error paths are pre-emit validation that the smoke implicitly exercises by passing them). When TICKET-007 lands and the quality-gate contract introduces non-trivial branching, a test suite alongside this smoke becomes justified.

## Alternatives considered

- **Live-Claude mode as the default.** Rejected per the CI determinism pressure above. Even if API credits were free, the test-suite latency would balloon from ~200ms to ~30–90s per run, and the test could fail non-deterministically due to model-output variance (a live model might choose `.trimStart().trimEnd()` instead of `.trim()` — semantically equivalent but textually different from what a downstream diff would expect).
- **Two scripts: `smoke-stub.sh` and `smoke-live.sh`.** Rejected: duplicates the wire-format I/O across two files and creates a maintenance drift risk. One script, one mode flag is the better factoring once `--real-claude` lands.
- **Pure shell, no Node for JSON manipulation.** Tempting (no language-mix), but bash 3.2 + BSD tools without `jq` cannot reliably build well-formed JSON. `jq` itself is not universally available. Node is already a harness dependency (TICKET-005), so using it for JSON is the principled choice per D-11.
- **`jq` for JSON.** Would work, but adds a non-default dependency (macOS users would need `brew install jq`). Node is already required by TICKET-005's toy and is universally pre-installed on modern dev/CI environments at v18+.
- **Skip the decision trail.** Rejected: the contract's response schema has `decision_trail_ref` as a path, and the file at that path is expected to exist. Emitting a response whose trail-ref points at nothing makes the smoke a lie about the wire.
- **Validate via Ajv with `docs/handoff-contract.md` extracted as JSON Schema.** Future work. The contract is currently expressed as a worked example in prose, not as JSON Schema. Extraction is justified work but doesn't block TICKET-006.
- **Keep the patch applied so subsequent smoke runs are no-ops.** Rejected: violates TICKET-005's Red-baseline invariant. The smoke proves the cycle *closes*; the next operator must be able to inspect the toy at its baseline (4 pass / 1 fail) the moment the smoke finishes. Idempotency means "produces the same outcome each time," not "leaves the world identical to itself" — that's what the trap implements.

## Consequences

### Positive

- **TICKET-006 acceptance criterion met deterministically.** `./scripts/smoke-e2e.sh; echo $?` → `0`, every run, every machine with bash+node, no credentials needed.
- **Wire format is real, not mocked.** Operators inspecting `.harness/handoffs/TICKET-042.req.json` see a document that validates against the contract — bit-for-bit what a live Grok would emit. Same for the response. Same for the trail.
- **Three skills wired in ADR-0007 have one real consumer.** The skill loading mechanism now has a downstream artifact (this smoke), giving it a reason to exist beyond "Claude Code surfaced them."
- **Audit trail is preserved across runs.** Each smoke run overwrites `.harness/handoffs/TICKET-042.{req,res}.json` and the trail file. They sit gitignored, available for inspection without polluting the repo.
- **Failure modes are loud and labeled by step.** Each `fail "..."` message names the failed step ("test gate failed (node --test exit=$TEST_EXIT)", "request schema validation failed (see dispatch.md pre-emit checks)"). A maintainer diagnosing breakage gets the exact next-action without re-reading the script.
- **D-13 (avoid five failure patterns) honored:** no kitchen-sink (script does ONE smoke), no shotgun (cleanup is one trap), no infinite loop (no retries), no correction-loop (single deterministic patch), no context-bloat (the script reads zero context beyond its own input files).

### Negative

- **Stub mode doesn't exercise the LLM reasoning surface.** The harness's most expensive part (live Claude TDD Pro running R-G-R against a real ticket) is not in this smoke. A breakage in the skill's reasoning would not be caught here. Mitigation: live-Claude mode lands additively when its dependencies (credentials, retry, log streaming) are designed.
- **Hand-rolled validators can drift from the contract.** If `docs/handoff-contract.md` adds a rule, this script's inline validator must be updated by hand. Mitigation: ADR-0008 itself documents the rules being validated; future contract amendments will reference both the contract and this script in their checklists.
- **The script knows the toy's exact contents.** The `.trim()` patch is hard-coded for the slugify case; the smoke can't be reused for other modules without editing. This is intentional — the smoke proves ONE canonical cycle. Other modules would need their own smoke (or, more likely, real live-Claude tests after that mode lands).
- **`.harness/handoffs/` and `.harness/trails/` accumulate cruft.** Each smoke run overwrites the TICKET-042 files, but if a future flow uses different ticket IDs, old files pile up. Acceptable for now; if it grows, add a `--clean` flag.

### Neutral

- D-rule count unchanged. §1 of `docs/founder-directives.md` untouched.
- TIER-0 corpus pre-commit checklist applies as usual (no exception).
- Bash 3.2 + BSD-tool portability validated against all nine `tdd-pro-bash32-portability` gotchas + the bonus help-to-stderr rule. Audit log in commit body.

## Verification (executed before commit)

- `bash -n scripts/smoke-e2e.sh` passes.
- `./scripts/smoke-e2e.sh` exits 0 from clean state.
- `./scripts/smoke-e2e.sh` exits 0 on a second back-to-back run (idempotency).
- After both runs, `node --test examples/string-utils/test/string-utils.test.mjs` returns `# pass 4 # fail 1` (Red baseline preserved by trap).
- `.harness/handoffs/TICKET-042.req.json` validates against `docs/handoff-contract.md §Grok→Claude` (manually inspected; all required fields present; `must_not_touch` denylist includes the three harness paths).
- `.harness/handoffs/TICKET-042.res.json` validates against `§Claude→Grok` (status=green, test_results populated, decision_trail_ref points at a file that exists).
- `.harness/trails/TICKET-042.md` exists and references the R-G-R steps narratively.
- `tdd-pro-bash32-portability` 9-gotcha audit: clean. Bonus help-to-stderr rule: pass.

## Future work (already named, deferred to subsequent CLs)

- **Live-Claude mode (`--real-claude`).** Adds inner-loop work via `claude -p --skill tdd-pro-cl-workflow < $REQ_PATH > $RES_PATH`. Lands as an additive ADR; falls back to stub on credential absence.
- **Extract handoff contract to JSON Schema.** Currently the contract is expressed as a worked example; extracting to JSON Schema enables Ajv-based validation in both this script and the skill consumer side. Lands when a second schema (Grok intermediate doc, or quality-gate spec) is needed.
- **Negative-path coverage.** Tests for `scope_violation`, `context_stale`, `dispatch_collision`, `schema_invalid`, `gate_failed` response paths. Lands as a test suite alongside the smoke once TICKET-007 introduces non-trivial gate branching.
- **CI integration.** A GitHub Actions workflow (or equivalent) that runs the smoke on every PR. Defers to the broader CI design which depends on TICKET-008 (self-healing extension).

## Implementation references

- New: `scripts/smoke-e2e.sh`
- Updated: `.gitignore` (added `.harness/handoffs/`, `.harness/trails/`)
- Updated: `TICKETS.md` (TICKET-006 → DONE)
- Ticket: `TICKET-006` in `TICKETS.md`
- Wire format: `docs/handoff-contract.md §"Grok → Claude"` and `§"Claude → Grok"`
- Outer-loop spec: `.grok/templates/dispatch.md §"Pre-emit checks"`
- Inner-loop skill (target of live mode when added): `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (symlink → cache, per ADR-0007)
- Related: ADR-0006 (template specs), ADR-0007 (skill consumption)
