# ADR-0030 — Swarm collection-contract integration test (TICKET-025)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 directive: *"Proceed through three focused, triggered, filter-disciplined CLs to secure A+"* — closure #4 per the Fowler-team regrade priority order) + Claude (cloud session, implementer)
- **Second voice (per ADR-0029 pattern):** Simulated Fowler+team regrade that named #4 as a 30-min CL with concrete trigger: *"Real swarm surfaces a defect an integration test would have caught."* The regrade IS the second voice; this CL ships exactly the named scope.
- **Trigger:** Closes Fowler critique #4 ("Operator-attested swarm Q-DEMO — no integration test") per the architect's explicit 2026-05-26 directive to secure A+ via three triggered CLs.
- **Supersedes:** ADR-0017 §Verification line 126 "Q-DEMO (operator-attested per the smoke-script + TICKET-014 pattern)" for the COLLECTION CONTRACT specifically (Step 5 of the swarm SKILL.md). The worktree spawn (Step 4) remains operator-validated by design.
- **Extends:** ADR-0017 (orchestrating-swarms SKILL.md — the contract this ADR tests); ADR-0028 (substrate-script test discipline — pattern this test follows); ADR-0019/0020/0021 (emit-manifest + audit-manifest + --regenerate — primitives this test composes on)

## Context

The simulated Fowler+team regrade (post-TICKET-024) named three open critiques with explicit effort + trigger conditions. Critique #4 was estimated at 30 minutes with the recommendation:

> *"#4 first (smallest effort, removes a visible footnote on a real claim)"*

The visible footnote: `.claude/skills/orchestrating-swarms/SKILL.md` Step 5 ("Collect worker outputs") and ADR-0017 §Verification both ended with "operator-attested" framing — meaning the swarm collection contract was not script-verified end-to-end. A load-bearing claim with no executable test is the kind of architectural risk Parsons would flag as "fitness function exists in name only."

The user's 2026-05-26 directive then triggered the closure: *"Proceed through three focused, triggered, filter-disciplined CLs to secure A+."*

Three design questions:

1. **What does the test actually cover?** End-to-end swarm including git worktree spawn, or the collection contract only?
2. **How are workers synthesized?** Real `/inner-loop` invocation per worker (slow, IDE-dependent), or fixture-based synthetic worker outputs?
3. **What's the assertion scope?** Surface-level (manifests exist) or contract-level (every documented Step 5 behavior verified)?

## Decision

### 1. Test the COLLECTION CONTRACT (Step 5) explicitly; worktree spawn (Step 4) remains out of scope

This test exercises Step 5 of `orchestrating-swarms/SKILL.md` end-to-end: per-worker manifest emission, validation, drift detection, cross-contamination absence. Step 4 (git worktree creation + sub-agent spawn) remains operator-validated because:

- **Git worktree** is git's own functionality with its own coverage; re-testing it would be R-11 violation (re-implement what already works).
- **Claude Code Task tool** sub-agent spawn is Claude Code's responsibility; testing it would require a real Claude Code session, which is fundamentally operator-attested.

The COLLECTION CONTRACT is the part the harness owns: given N worker outputs, validate them per `audit-manifest.sh` + detect tamper per `emit-manifest.sh --regenerate` + assert no cross-contamination. That's the testable substance.

Honest scope statement per ADR-0028 §Decision-6 ("100% defined honestly"): this closes Fowler #4 for **the collection contract** specifically. The worktree spawn step's "operator-attested" label is appropriate (git + Claude Code own that mechanism).

### 2. Fixture-based synthetic worker outputs (3 workers; non-overlapping `file_scope` per G-8)

The test synthesizes 3 `.req.json` + `.res.json` + trail file sets for `TICKET-SWARM-001/002/003` with non-overlapping `file_scope` paths. Each fixture is hand-crafted minimal-viable JSON matching `docs/handoff-contract.md §Grok→Claude` + `§Claude→Grok` schemas.

Rationale:

- **Fixture-based is fast** (sub-second per worker; total test runs in ~3 seconds).
- **Synthetic worker outputs are deterministic** — no flakiness from real `/inner-loop` invocations that depend on AI model variance.
- **3 workers** is the smallest N that demonstrates the collection contract operates on multiple workers (1 worker = trivially equivalent to single-ticket flow; 2 workers = pair; 3 workers = swarm in the proper sense, and crosses the threshold where cross-contamination becomes possible to test).
- **Non-overlapping `file_scope`** matches the G-8 "decomposition along file/feature boundaries" rule; testing with overlapping scope would be testing the wrong thing (overlap should serialize per Step 2, not enter collection).

### 3. 19 assertions across 6 contract sub-steps

The test verifies:

- **5a — per-worker manifest emission** (3 workers × 2 assertions each = 6 assertions: exit 0 + file exists)
- **5b — batch validation via audit-manifest.sh** (1 assertion: walk-all passes)
- **5c — `--regenerate` clean drift check per worker** (3 assertions: each worker's regenerate exits 0)
- **5d — status correctness per worker** (3 assertions: each manifest shows `status: green` matching `.res.json`)
- **5e — tamper detection with cross-contamination absence** (3 assertions: tamper worker 2; assert worker 1 still clean, worker 2 drifts, worker 3 still clean)
- **5f — sources[] array structure per worker** (3 assertions: each manifest has exactly 3 sources = request + response + decision_trail)

19 total assertions; the test runs in ~3 seconds; restore-before-assert pattern via `trap cleanup EXIT INT TERM` removes all fixture artifacts regardless of test outcome.

## Alternatives considered

- **Use real git worktree + real `/inner-loop` per worker.** REJECTED. Real worktree creation adds OS-level latency (~1-2 seconds per worker on macOS); `/inner-loop` requires a live Cursor/Claude Code session, making the test fundamentally operator-attested (the very thing this CL is closing). Synthetic fixtures preserve speed + determinism while testing the same collection contract.
- **Test only 1 worker.** REJECTED. Critique #4 was about the SWARM specifically (multi-worker fan-out); a single-worker test would not demonstrate the cross-contamination assertion (Step 5e) that is the most contract-load-bearing assertion in the suite.
- **Test 8 workers** (per G-9 max fan-out). REJECTED per D-13. 3 workers is sufficient to demonstrate the contract; 8 would inflate fixture size without proportional value.
- **Test the worktree spawn step too** (via `git worktree add` + clean up). REJECTED per Decision-1 scope. Worktree is git's responsibility; testing it would re-implement git's own coverage. Plus the test fixtures would need to handle git's own state (uncommitted changes, branch tracking, etc.), expanding scope without contract-test value.
- **Add a `tests/fixtures/swarm/` directory with the JSON files.** REJECTED. The fixtures are programmatically generated inline via heredoc; externalizing them adds a second filesystem location to maintain without simplifying the test.
- **Run via `bats` or `shellspec`.** REJECTED per ADR-0028 §Decision-2. Native bash assertions are the established pattern; this test follows the same.
- **Defer this test until a real swarm invocation surfaces a defect** (per the regrade's trigger condition wording). REJECTED. The architect's 2026-05-26 directive explicitly directed proceeding to A+; the trigger has fired by directive.

## Consequences

### Positive

- **Fowler critique #4 closed.** The collection contract is now script-verified end-to-end; the "operator-attested" footnote for Step 5 is superseded by ADR-0030.
- **Cross-contamination is now an explicitly-tested property.** Tampering with one worker's trail does NOT contaminate other workers' drift detection. This was implicit in the design but never asserted; now it is.
- **Coverage: 9/8 → 9/8 surfaces tested.** The `orchestrating-swarms` SKILL.md was not previously enumerated as a substrate "script" (it's markdown). The new test brings the SKILL.md collection contract under test discipline; `tests/README.md` updated accordingly with honest scope.
- **Test runs in ~3 seconds.** Fits within `tests/test-all.sh --quiet` total runtime; CI-ready when the CI integration trigger fires (per ADR-0028).
- **Restore-before-assert pattern preserved.** `trap cleanup EXIT INT TERM` removes all fixture artifacts on test exit (success or failure or interruption). Audit chain remains green post-test.
- **D-12 honored.** Honest scope: "this closes the COLLECTION CONTRACT side; worktree spawn remains operator-attested by design because git owns it." No overclaiming.
- **D-8 honored.** 7 alternatives rejected with rationale (real worktree, single worker, 8 workers, worktree-spawn-in-scope, externalized fixtures, bats/shellspec, defer-until-bitten).

### Negative

- **The worktree spawn step (Step 4) is still operator-validated.** Mitigation: ADR-0030 names this explicitly; git owns the worktree mechanism with its own coverage; "operator-validated" for the SUB-AGENT SPAWN inside the worktree is the honest scope (Claude Code's Task tool is the spawn mechanism, and it has its own coverage).
- **Synthetic fixtures don't exercise real AI model output variance.** Mitigation: this test verifies the CONTRACT, not the AI's adherence to it; AI-quality is tested by the existing R-G-R discipline + quality-gate per CL. Different layer of the testing pyramid.
- **`tests/test-orchestrating-swarms.sh` is the 9th test suite.** Adds ~3 seconds to `tests/test-all.sh --quiet` runtime; total now ~18 seconds. Mitigation: still fast feedback per Humble's fast-feedback bar; CI-ready.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **AGENTS.md / CLAUDE.md / QUICKSTART untouched.**
- **`.cursor/rules/` untouched.**
- **Wire-format `schema_version` unchanged.**
- **No new D-rules; no new TIER-2 docs; only one new test file + one ADR + minor SKILL.md update.**

## Verification (executed before commit)

- `bash -n tests/test-orchestrating-swarms.sh` clean.
- `./tests/test-orchestrating-swarms.sh` exits 0 with 19/19 assertions passing.
- `./tests/test-all.sh --quiet` shows 9/9 suites now passing (was 8/8 pre-CL).
- Full audit chain: audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest all exit 0.
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- `.claude/skills/orchestrating-swarms/SKILL.md` updated with the "Step 5 contract is tested" paragraph citing this ADR.
- `tests/README.md` coverage table updated; 9/9 testable surfaces; SKILL.md COLLECTION CONTRACT enumerated honestly.
- ADR-0030 follows the numbered ADR template + uses the `Second voice` field established by ADR-0029.

## Out of scope (deferred per filter)

- **`tests/test-orchestrating-swarms-worktree.sh`** — testing git worktree creation + cleanup mechanics. REJECTED. Git owns this; testing it re-implements git's own coverage.
- **`tests/test-orchestrating-swarms-spawn.sh`** — testing Claude Code Task tool sub-agent spawn. REJECTED. Claude Code owns this; would require a live Claude Code session which is operator-attested by nature.
- **Integration test with N=8 workers** (G-9 max fan-out). REJECTED per D-13; 3 is sufficient to demonstrate the multi-worker collection contract.
- **`tests/test-orchestrating-swarms-overlap.sh`** — testing that overlapping file_scope is correctly serialized vs. paralleled per Step 2. Deferred; trigger: a future operator hits a file-scope overlap and the serialization path needs verification.
- **Property-based / fuzz testing** of worker count. REJECTED per ADR-0028 §Out-of-scope precedent.

## Implementation references

- New: `tests/test-orchestrating-swarms.sh` (19 assertions across 6 contract sub-steps; ~110 lines; bash 3.2 + BSD portable; restore-before-assert via trap)
- Modified: `.claude/skills/orchestrating-swarms/SKILL.md` (Step 5 gains "contract is tested" paragraph citing TICKET-025 / ADR-0030)
- Modified: `tests/README.md` (coverage table extended to include the SKILL.md collection contract)
- Modified: `TICKETS.md` (TICKET-025 row marked DONE)
- New: this ADR
- Related: ADR-0017 (orchestrating-swarms — the SKILL.md this ADR tests), ADR-0028 (substrate-script test discipline — pattern this test follows), ADR-0019/0020/0021 (emit-manifest + audit-manifest + --regenerate — primitives this test composes on), ADR-0029 (regrade-driven closure pattern + `Second voice` field; this ADR is the second application of that field).
