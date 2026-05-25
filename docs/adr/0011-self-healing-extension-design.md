# ADR-0011 — Self-healing extension design (TICKET-008)

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, "Proceed" instruction per the existing ticket plan) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0010 (quality-gate v1 — the vocabulary of debt the monitor watches); composes on plugin `architecture-v1.9.md §§2.8, 2.11, 2.14, 2.15, 2.17`

## Context

TICKET-008's acceptance criterion was "Design doc; no code." The deliverable is `docs/self-healing-design.md`, which specifies a long-running outer-loop monitor that watches debt thresholds and dispatches refactor tickets through the existing handoff contract.

The harness's value proposition is **production-grade trustability** (D-12). Per-CL gating (TICKET-007) catches debt at commit time; without self-healing, debt that accumulates silently — coverage decay, lint warnings creeping below the per-CL threshold, complexity creep across many small commits — passes the gate and persists. The self-healing extension closes that gap by re-spawning refactor cycles when long-window debt signals breach thresholds.

Four design questions had to be resolved before the doc could be written:

1. **What signals does the monitor watch?** The quality-gate v1 has four sub-gates; should self-heal watch only those, or also advisory signals (complexity, dependency staleness, flake rate)?
2. **What's the dispatch authority model?** Auto-dispatch everywhere, or HITL for higher-risk signals?
3. **How is the wire format extended?** Does self-heal need a new schema, or can it ride on the existing handoff contract?
4. **What are the failure modes, and which are designed-in vs. deferred?**

## Decision

### 1. Watch both sub-gate-bound signals AND advisory signals; route by severity

Seven signals at v1: four sub-gate-bound (test-pass-rate, coverage-trend, lint-warning-drift, provenance-completeness-rate) and three advisory (complexity-creep, dependency-staleness, flake-rate). Each signal has a `severity: P0 | P1 | P2` (borrowing the plugin's `§2.1` enum, consistent with quality-gate v1's classification).

- **P0** (test-pass-rate): auto-dispatch. The breach is unambiguous; the refactor is a known-good operation.
- **P1** (coverage-trend, lint-warning-drift): auto-dispatch with mandatory `provenance_complete`. HITL escalation on `red`/`blocked` response.
- **P2** (provenance-completeness-rate, complexity-creep, dependency-staleness, flake-rate): HITL-only at v1. The breach is observable but the appropriate response is ambiguous; human decides per breach.

The HITL routing for ambiguous signals is the v1 "production-grade trust" stance: the monitor errs toward asking rather than fixing.

### 2. Compose on the existing handoff contract; do NOT introduce a new wire format

Self-heal dispatches use the same `.harness/handoffs/<ticket-id>.req.json` schema as Grok's per-ticket dispatch. Ticket-id prefix `SELF-HEAL-<UTC-date>-<seq>` distinguishes them from human-spawned tickets at the audit layer, but the wire schema is unchanged.

Rationale: per R-3 (single source of truth) and R-11 (tolerant reader), a second wire format for self-heal would require two consumer paths in the inner loop. One schema, two producers (Grok-per-ticket + Self-heal-monitor) is the correct factoring.

### 3. Failure modes designed-in: seven named, each with mitigation

The §8 section names seven failure modes (monitor-loop divergence, cascading refactors, self-amplifying flake, scope creep, threshold drift, cost runaway, provenance gap). Each has at least one mitigation that is structurally enforced by the design (cooldowns, circuit breaker, gate cross-checks) rather than aspirationally documented.

The cost-runaway mitigation includes both a budget cap and a hard dispatch-count cap. Either alone is brittle — budget cap can be evaded by per-dispatch cost variation; dispatch cap can be evaded by long-running multi-step dispatches. Both together provide defense in depth.

### 4. Design is TIER 2 rulebook-level; implementation deferred to TICKET-008.a..e

The design doc joins quality-gate.md at TIER 2. The implementation sub-tickets are named in §16:

- **TICKET-008.a** — Reference implementation for ONE signal (`test-pass-rate`) end-to-end. Validates the design.
- **TICKET-008.b** — All P0/P1 signal observers.
- **TICKET-008.c** — Circuit breaker + budget cap.
- **TICKET-008.d** — HITL queue.
- **TICKET-008.e** — Observability log + query helper.

This naming structure means TICKET-008 (the design) can ship without any executable code, and each sub-ticket is independently shippable.

## Alternatives considered

- **Auto-dispatch everything, no HITL.** Rejected. The harness is positioned for enterprise contexts (D-2); auto-dispatching against an ambiguous signal (e.g., dependency-staleness with a major version bump available) risks shipping a breaking change without review.
- **HITL everything; no auto-dispatch.** Rejected. Defeats the purpose. The self-healing pattern's value is closing the loop on well-defined debt without human intervention; if every breach needs human approval, the monitor is just an alerting system.
- **New wire format for self-heal (`.req.self-heal.json`).** Rejected per R-3 / R-11. One contract, two producers.
- **Watch only the four quality-gate sub-gates.** Rejected as too narrow. Complexity creep and dependency staleness are real production-grade-trust signals; deferring them to "future work" would leave a known gap.
- **Watch dozens of signals.** Rejected per Musk's Algorithm step 2 (delete before optimize). Seven signals span the major debt classes (test, coverage, lint, provenance, complexity, dependency, flake). Adding more dilutes signal-to-noise.
- **Multi-repo correlation at v1.** Rejected. One repo is enough to validate the design. Multi-repo is a deferred future ADR.
- **Real-time signal streaming (webhooks).** Rejected at v1. Batch-poll is simpler and sufficient for the daily-to-weekly cadences the thresholds use.
- **ML-driven threshold tuning at v1.** Rejected. Static thresholds + quarterly review is the v1 baseline. ML adds operational complexity without proven need.
- **Skip the explicit failure-mode section.** Rejected. The scope statement says "Includes failure modes" — that's a hard acceptance requirement. Also: the design's credibility depends on showing the failure modes have been thought through.

## Consequences

### Positive

- **TICKET-008 acceptance criterion met.** Design doc; no code. The 18-section, ~17KB document specifies the architecture, signals, thresholds, dispatch policy, response handling, seven failure modes, HITL integration, observability, state, configuration, composition with existing contracts, authority, out-of-scope, and verification.
- **Implementation is now sequenced.** The five sub-tickets (008.a..e) are named with rough dependencies. Each is independently shippable; the architect can interleave them with TICKET-009 / TICKET-010 work.
- **The harness's "production-grade trust" claim is concretely justified.** Per-CL gating catches debt at commit time; self-healing catches debt that accumulates between commits. The combination is the actual operating model.
- **No new wire format.** The inner loop (Claude TDD Pro via the symlinked skills) consumes self-heal dispatches with zero changes.
- **The seven failure modes are designed-in, not deferred.** Cooldowns, circuit breakers, scope checks, budget caps, provenance enforcement are all part of v1.
- **README's `Pending:` bullet updated.** TICKET-007 and TICKET-008 dropped (TICKET-008 explicitly marked as design-complete with implementation deferred to sub-tickets). This proactively closes an F-2-class drift item that the audit script didn't catch on its own.

### Negative

- **The design specifies seven signals, but only four have v1 sub-gate definitions.** Complexity, dependency staleness, and flake-rate have monitor logic but no quality-gate sub-gate. They are HITL-only at v1 partly for this reason: the monitor can detect breach, but the inner loop has no automated "fix" target to aim at. Promotion to P1/P0 requires a future quality-gate amendment.
- **The seven failure modes do not include all failure modes — they include the ones the design considered.** A real production deployment will surface failure modes not predicted here (e.g., the monitor process crashes mid-cycle and `state.json` is partially written despite atomic-write claims; the budget cap is evaded by a usage-billing model change). Mitigation: §16 names "observability log + dashboard query helper" as TICKET-008.e — the log lets unknown failure modes surface for human triage.
- **Threshold tuning is a manual quarterly process at v1.** That requires operator discipline. If the operator skips a quarter, stale thresholds either over-fire (false positives → operator distrust) or under-fire (missed debt). Mitigation: each threshold tracks its own fire history; a future TICKET-008.f could automate the review prompts.
- **State file is JSON, not a real database.** Concurrent writers would corrupt it; the design assumes single-process monitor. Multi-monitor scenarios (e.g., HA failover) require a future refactor.

### Neutral

- D-rule count unchanged. §1 of `docs/founder-directives.md` untouched.
- TIER-0 corpus untouched.
- `schema_version` of the handoff contract stays at `"1"`.
- The plugin's §2.X contracts are cited; the authoritative files remain upstream.

## Verification (executed before commit)

- `docs/self-healing-design.md` exists. 18 sections present.
- Acceptance criterion (`Design doc; no code`) met — only files touched are `docs/`, `README.md`, `TICKETS.md`, and this ADR. No new scripts, no new modules, no edits to existing scripts.
- §8 Failure modes names exactly 7 distinct modes, each with structural mitigation.
- §13 Composition cites 4 existing harness contracts + 5 plugin §2.X contracts by name.
- §15 Out of scope names 7 explicit non-goals.
- §16 Future work names 5 sub-tickets (008.a..e) with sequencing + 3 future-ADR items.
- `README.md` `Pending:` line updated to drop TICKETS 007 + 008.
- `./scripts/audit-doc-drift.sh` exit 0.
- `./scripts/smoke-e2e.sh` exit 0 (toy still at Red baseline; this CL touched nothing executable).

## Out of scope (deferred, named in the design doc §15)

- Single-repo only at v1; multi-repo correlation deferred.
- Static thresholds; ML-driven tuning deferred.
- Batch-poll; real-time streaming deferred.
- Self-heal generates tickets, never fixes — and never modifies the harness substrate. Both are non-negotiable.

## Out of scope at the ADR level (deferred, not in the design doc)

- **Implementation language.** The design says "bash + node script that implements §3 Observer..." but does not commit to a specific language. The first implementation CL (008.a) chooses based on what the signal source returns (most likely bash for orchestration + node for JSON manipulation, consistent with the existing harness scripts).
- **Daemon supervision.** Whether the monitor runs under systemd / launchd / cron / `nohup` / something else. Out of v1 design; lands with 008.e.
- **HA failover.** Single-monitor assumption is documented; multi-monitor is a future refactor.

## Implementation references

- New: `docs/self-healing-design.md`
- Updated: `README.md` (Pending: line dropped TICKETS 007 + 008)
- Updated: `TICKETS.md` (TICKET-008 → DONE)
- This ADR
- Composes on: `docs/handoff-contract.md` (wire), `docs/quality-gate.md` (debt vocabulary), `claude-tdd-pro/docs/architecture-v1.9.md §§2.8, 2.11, 2.14, 2.15, 2.17` (plugin contracts)
- Related: ADR-0010 (quality-gate v1 — this design's vocabulary), ADR-0008 (smoke script — the inner-loop bridge self-heal dispatches consume)
