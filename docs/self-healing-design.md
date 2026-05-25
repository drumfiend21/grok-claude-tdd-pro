# Self-Healing Extension — Design (TICKET-008)

**Status:** Design only. No code in this CL — TICKET-008 spec is "Design doc; no code." Implementation lands in later CLs (named at the end of this document).

**Position in the harness:** the long-running outer-loop arm. Grok's per-ticket dispatch (covered by `.grok/templates/`, the handoff contract, and the inner-loop wiring) is the synchronous "react to a request" path. The self-healing monitor is the asynchronous "watch the codebase for debt and dispatch proactively" path. Both produce the same wire format — `.harness/handoffs/<ticket-id>.req.json` — which means the inner loop (Claude TDD Pro) does not need any changes to consume self-healing-generated tickets.

## §1 Purpose and value proposition

The harness's value is **production-grade trustability** (D-12). Per-CL gating (TICKET-007) catches debt as it lands; without self-healing, debt that lands silently — coverage decay, lint warnings accumulating below the per-CL threshold, complexity creep across many small commits — passes the gate and accumulates indefinitely. The self-healing extension closes that gap by:

1. Watching long-window debt signals.
2. When a signal crosses a threshold, generating a refactor ticket.
3. Dispatching it through the existing handoff contract.
4. Watching the response and either closing the loop (green) or escalating (red / blocked / error).

This is the canonical "self-healing agent" pattern from Anthropic's *Building Effective Agents* (founder-directives §1 Source 5) applied to the harness's specific debt definitions.

## §2 Architecture (composed from existing primitives)

```
┌──────────────────────────────────────────────────────────────────┐
│ Self-Healing Monitor (long-running, single process per repo)     │
│ ────────────────────────────────────────────────────────────     │
│ State: .harness/self-heal/state.json (gitignored, atomic write)  │
│ Config: .harness/self-heal/config.yaml (committed, ADR-gated)    │
│                                                                  │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│   │ Observer    │ ─▶ │ Evaluator   │ ─▶ │ Dispatcher  │          │
│   │ (poll)      │    │ (threshold) │    │ (handoff)   │          │
│   └─────────────┘    └─────────────┘    └─────────────┘          │
│         ▲                                       │                │
│         │                                       ▼                │
│   ┌─────┴───────┐                       ┌──────────────┐         │
│   │ Signal      │                       │ Response     │         │
│   │ sources     │                       │ watcher      │ ──┐     │
│   └─────────────┘                       └──────────────┘   │     │
└────────────────────────────────────────────────────────────┼─────┘
                                                             │
                                                             ▼
                                             ┌───────────────────────────┐
                                             │ Outcome handler           │
                                             │ - green: close ticket     │
                                             │ - red:   escalate (HITL)  │
                                             │ - blocked: root-cause     │
                                             │ - error:  pause monitor   │
                                             └───────────────────────────┘
```

All four boxes are existing primitives or thin compositions:

- **Observer.** Polls signal sources. Sources are existing: `git log` for commit cadence, `node --test` / `pytest` / etc. for test trends, the project's linter, the project's coverage tool, `cloc` or `radon` for complexity, `npm audit` / `pip-audit` for dependency staleness.
- **Evaluator.** Maps observations to debt scores against thresholds. Uses the quality-gate v1 sub-gate definitions (TICKET-007) as the **vocabulary** of debt — a "tests_must_pass" failure on the long-window aggregate is debt; same for the other three sub-gates. Adds **trend** signals on top: coverage delta over N commits, lint count drift over N days, etc.
- **Dispatcher.** Writes `.harness/handoffs/SELF-HEAL-<date>-<seq>.req.json`. Exactly the same schema as the dispatch template (`.grok/templates/dispatch.md §"Pre-emit checks"`). No new wire format.
- **Response watcher.** Polls `.harness/handoffs/SELF-HEAL-*.res.json` for completion. When a response arrives, the outcome handler routes by `status`.

Per **D-11 (design FOR primitives)**: nothing in this diagram re-implements an existing primitive. Polling, JSON I/O, threshold comparison, ticket-id generation are all base-level operations. The state file is JSON. The config file is YAML (matches `docs/claude-tdd-pro.lock.yaml`'s format).

## §3 Signals (what the Observer watches)

| Signal | Source | Frequency | Quality-gate sub-gate it maps to | Trend window |
|---|---|---|---|---|
| `test-pass-rate` | last N runs of `node --test` (or framework equiv.) | per commit + nightly | `tests_must_pass` | 14 days |
| `coverage-trend` | coverage tool (when present) | per commit | `coverage_delta_min` | 30 days |
| `lint-warning-drift` | linter (when present), warning-count over time | per commit | `lint_clean` (warning-exempted side) | 30 days |
| `provenance-completeness-rate` | `.harness/trails/` count vs commit count | nightly | `provenance_complete` | 30 days |
| `complexity-creep` | `cloc` / `radon` / `eslintcc` per-file cyclomatic | weekly | (no direct sub-gate; advisory) | 90 days |
| `dependency-staleness` | `npm audit` / `pip-audit` / Renovate equivalent | daily | (no direct sub-gate; advisory) | 7 days |
| `flake-rate` | test-name re-pass rate (one-retry counts) | per commit | `tests_must_pass` (flake side) | 14 days |

**Two classes of signal:**

1. **Sub-gate-bound** (first four rows): these have direct quality-gate definitions. Their thresholds extend the sub-gate's per-CL definition to a long-window aggregate. Example: per-CL `coverage_delta_min: 0` means "no regression at commit time." The self-heal signal `coverage-trend` adds "no monotonic decline over 30 days even if every individual CL was at delta=0" (because tiny rounding losses or test-removal-without-source-removal compound silently).

2. **Advisory** (last three): complexity, dependency staleness, flake-rate. The quality-gate v1 doesn't enforce these per-CL; the self-healer can flag them. Until they have v2 sub-gate definitions, breaches are **HITL-only** (queued for human review, not auto-dispatched).

Signals consume the plugin's `§2.11 SPACE metric schema` shape: each signal is a SPACE entry in the `performance` dimension with `privacy: local-only` and `opt_in: true`. The monitor IS a SPACE producer.

## §4 Thresholds (what triggers a refactor dispatch)

Thresholds live in `.harness/self-heal/config.yaml`. The v1 ship default:

```yaml
schema_version: "1"
thresholds:
  test-pass-rate:
    window_days: 14
    minimum: 0.98              # 98% of test runs must be green
    hysteresis: 0.01           # don't re-trigger between 98% and 99%
    cooldown_hours: 24         # one dispatch per (file_scope, signal) per day
    severity: P0               # auto-dispatch, no HITL
  coverage-trend:
    window_days: 30
    max_decline: 0.02          # 2 absolute coverage points
    hysteresis: 0.005
    cooldown_hours: 72
    severity: P1               # auto-dispatch, no HITL
  lint-warning-drift:
    window_days: 30
    max_increase: 5            # warning count
    hysteresis: 2
    cooldown_hours: 72
    severity: P1
  provenance-completeness-rate:
    window_days: 30
    minimum: 0.95              # ≥95% of commits have trail files
    hysteresis: 0.02
    cooldown_hours: 168        # weekly
    severity: P2               # HITL-only
  complexity-creep:
    window_days: 90
    max_delta_per_file: 5      # cyclomatic
    cooldown_hours: 168
    severity: P2               # HITL-only
  dependency-staleness:
    window_days: 7
    max_critical_advisories: 0
    max_high_advisories: 2
    cooldown_hours: 24
    severity: P2               # HITL-only
  flake-rate:
    window_days: 14
    max_per_test: 0.02         # 2% of runs require retry
    cooldown_hours: 168
    severity: P2               # HITL-only

rate_limits:
  max_dispatches_per_day_global: 5
  max_dispatches_per_day_per_file: 1
  max_open_self_heal_tickets: 10
  monthly_llm_budget_usd: 50

circuit_breaker:
  consecutive_red_responses_to_open: 3
  consecutive_error_responses_to_open: 2
  pause_minutes_on_open: 1440  # 24 hours

provenance:
  signature_method: sha256
  state_file: .harness/self-heal/state.json
```

**Severity → action mapping:**

- **P0** — auto-dispatch when threshold breaches. No HITL.
- **P1** — auto-dispatch when threshold breaches, but the request must declare `quality_gate.provenance_complete: true` and the response must populate a full trail. HITL escalation if response is `red` or `blocked`.
- **P2** — HITL-only at v1. The monitor queues an approval request; only on approval does dispatch run. Promotion to P1 / P0 lands via future ADR after enough HITL approvals validate the threshold.

## §5 Ticket-generation policy

When a threshold breaches and no cooldown is active:

```
ticket_id        := SELF-HEAL-<UTC-YYYYMMDD>-<NN>
title            := "<signal>: <breach summary>"  (e.g., "coverage-trend: 30-day delta -0.024, threshold -0.02")
acceptance_criteria := [
                      "Move <signal> back inside threshold (<threshold-value>)",
                      "Do not regress any other quality-gate sub-gate",
                      "Trail file documents the refactor's Red-Green-Refactor cycle"
                    ]
file_scope.may_edit := <files implicated by the signal — algorithmic per signal>
file_scope.may_read := <project source tree under may_edit's parent>
file_scope.must_not_touch := [".grok/**", ".claude/**", "claude-tdd-pro/**", "docs/adr/**"]
context.research_refs := [
                      {"kind": "self-heal-signal", "ref": "<signal-id>", "summary": "<breach summary>"},
                      {"kind": "trend-window", "ref": "<window-start>..<window-end>", "summary": "<observation>"}
                    ]
context.decomposition_parent := "SELF-HEAL-<UTC-YYYYMMDD>"   (one parent per day; bundles same-day dispatches)
context.prior_decisions := [<adr ids that were referenced by the breached signal's history>]
quality_gate := {
                      "tests_must_pass": true,
                      "coverage_delta_min": 0,
                      "lint_clean": true,
                      "provenance_complete": true        # always set for self-heal (per P1/P0 rules)
                    }
```

**Algorithmic file_scope derivation per signal:**

- `test-pass-rate` → the failing test files + their `import`/`require` graph one hop.
- `coverage-trend` → files with the largest coverage delta in the window.
- `lint-warning-drift` → files with the most warnings (top N by count).
- `complexity-creep` → files with the largest cyclomatic delta.
- `dependency-staleness` → only `package.json` / `requirements.txt` / equivalent + lockfile.
- `flake-rate` → flaky-test file + the source files it tests.

`must_not_touch` always includes the harness substrate. This is non-negotiable: the self-healer NEVER edits `.grok/`, `.claude/`, the plugin cache, or ADRs.

## §6 Dispatch policy

- **One dispatch per breach.** If two signals breach in the same evaluator cycle, two dispatches go out (one ticket each). Multi-signal bundling is deferred to future work (named below).
- **Cooldown enforced.** Per `(file_scope-fingerprint, signal)` pair, only one dispatch per `cooldown_hours`. The fingerprint is `sha256(sorted(may_edit))`.
- **Rate limit enforced.** Global per-day + per-file per-day caps. If a dispatch is rate-limited, the breach is **logged but not dispatched** and the next cycle re-evaluates (the breach naturally persists if real).
- **Budget enforced.** Monthly LLM budget tracked. Exceeding the cap → pause auto-dispatch; HITL-only until next month or operator reset.

## §7 Response handling

The Response Watcher polls `.harness/handoffs/SELF-HEAL-*.res.json` (the inner-loop's drop location, per ADR-0008). On arrival, the Outcome Handler routes by `status`:

- **`green`** → record success; mark cooldown active; close the ticket. The breach should clear on the next evaluator cycle (if not, the cooldown prevents re-dispatch and the next cycle's re-evaluation surfaces the persistence as a different signal — the persistent breach is itself a meta-signal).
- **`red`** → record the failure; mark cooldown active (don't re-dispatch immediately); escalate to HITL queue with the full `.res.json` and the breach context. Human decides: accept (mark threshold too tight), refactor manually, or re-dispatch with broader scope.
- **`blocked`** → root-cause the block reason (`error.code`). If `scope_violation` or `schema_invalid` — the dispatcher has a bug; pause monitor and alert. If `context_stale` — re-dispatch with fresh `issued_at` if the breach persists. If `other` — HITL.
- **`error`** → pause monitor; alert operator. Likely a plumbing failure (skill missing, plugin cache corrupted).

## §8 Failure modes (the meat of the design)

Seven named failure modes. Each ships with a mitigation that's already designed-in or explicitly deferred.

### §8.1 Monitor loop divergence

**Failure.** The refactor ticket changes the file in a way that re-trips the same threshold immediately, causing the monitor to dispatch again, the inner loop to refactor again, and so on.

**Mitigation (designed-in).** Cooldown per `(file_scope-fingerprint, signal)` pair prevents re-dispatch within `cooldown_hours`. Default 24h for P0, 72h for P1, 168h for P2.

**Mitigation (additional).** Circuit breaker on consecutive same-fingerprint dispatches. If the same `(file_scope-fingerprint, signal)` re-trips within one cooldown window after green, open the circuit for that pair — HITL only until reset.

### §8.2 Cascading refactors

**Failure.** One refactor cycle fixes signal A but introduces drift that trips signal B. The next cycle dispatches a B-refactor, which trips C, etc. The monitor enters a thrashing state.

**Mitigation (designed-in).** Every refactor response is gated by `quality_gate.provenance_complete: true` AND the four-sub-gate checklist (TICKET-007). A response that fixes A but regresses any of `tests_must_pass`, `coverage_delta_min`, `lint_clean` is `status: red`. The cascade requires ALL gates green simultaneously — refactors that solve A-by-breaking-B never close.

**Mitigation (additional).** Global rate limit (5 dispatches/day default) caps the maximum cascade depth.

### §8.3 Self-amplifying flake

**Failure.** A flaky test produces false-positive `test-pass-rate` signal. The monitor dispatches a refactor, which doesn't fix the flake (it's not deterministic), the flake fires again, the monitor dispatches again.

**Mitigation (designed-in).** The `flake-rate` signal exists explicitly. When a test is detected as flaky (one-retry counts above 2% per test), the monitor routes its breaches to the `flake-rate` signal (P2, HITL-only) rather than to `test-pass-rate` (P0, auto). Test flakiness is a human triage problem at v1, not a refactor problem.

**Mitigation (additional).** Per-test cooldown for `test-pass-rate` dispatches: if the same test name keeps failing, dispatch escalates to `flake-rate` signal after two cycles.

### §8.4 Scope creep on refactor response

**Failure.** Claude's inner-loop response edits files outside `file_scope.may_edit`. The dispatcher accepts a response that touches the harness substrate (or worse, deletes tests).

**Mitigation (designed-in).** The cross-cutting integrity check in `quality-gate.md` (scope check: `changed_files[].path ⊆ may_edit`, none in `must_not_touch`) is mandatory. The outcome handler runs this check before accepting `status: green`. A response that fails the scope check is treated as `status: blocked` with `error.code: scope_violation`, regardless of what the response says.

### §8.5 Threshold drift / metric drift

**Failure.** The monitor's thresholds become stale. As the codebase matures, "98% test pass rate" might be too lax (mature codebase) or too strict (early-stage with intentional churn). Either way, the threshold no longer reflects intent.

**Mitigation (procedural).** Quarterly threshold review by the architect, documented in a calendar reminder external to the harness. Each threshold change lands via ADR (per `architecture-principles.md §19`).

**Mitigation (additional).** Each threshold tracks its own breach history. If a threshold has fired ≥10 times in a quarter, the next-quarter review explicitly considers loosening it. If it has fired 0 times in a quarter, the review considers tightening it (the threshold isn't earning its keep at the current value).

### §8.6 Cost runaway

**Failure.** Every threshold breach generates an LLM call (the inner loop runs Claude TDD Pro). At high breach rates, the LLM cost compounds beyond budget.

**Mitigation (designed-in).** `monthly_llm_budget_usd` cap with monitor pause on exceedance. The monitor estimates cost per dispatch (from `cost_telemetry` in the response, if present per the plugin's §2.8 manifest forward-compat). When the running total hits 80% of cap, an alert fires; at 100%, auto-dispatch pauses until next month.

**Mitigation (additional).** `max_dispatches_per_day_global` provides a coarse cap. Even at default 5/day, the monthly ceiling is 150 dispatches — well below the budget for any reasonable per-dispatch cost (~$0.30/dispatch ≈ $45/month at the cap).

### §8.7 Provenance gap

**Failure.** A refactor cycle closes one threshold but the trail file doesn't document the decision chain. Future audits can't trace why the change was made.

**Mitigation (designed-in).** Self-heal dispatches ALWAYS set `quality_gate.provenance_complete: true`. The response is rejected (`status: red` with `error.code: gate_failed`) if the trail file is missing or incomplete. The trail names the breach signal, the threshold value, and the closing condition.

**Mitigation (additional).** The monitor's own state file (`state.json`) cross-references each dispatched ticket id to the signal + threshold + breach observation. This is independent of the trail file; the cross-reference IS the audit log.

## §9 Human-in-the-loop integration

Per `grok-orchestration-principles.md §G-13` (HITL approval gates):

**Auto-dispatched (no HITL):** P0 + P1 signals. The breach is real per the quality-gate v1 definitions; the refactor is a known-good operation (run the inner loop on a bounded `file_scope`).

**HITL-required:** P2 signals (complexity-creep, dependency-staleness, flake-rate, provenance-completeness-rate). The threshold breach has been observed but the *appropriate response* is ambiguous (does a complexity creep need refactor, or is the new complexity inherent? is a stale dependency safe to bump, or does it have known breaking changes?). Human decides.

**HITL queue format:**

```json
{
  "queue_entry_id": "HITL-<uuid>",
  "queued_at": "<iso8601>",
  "signal": "<signal-id>",
  "breach": { "value": <observed>, "threshold": <configured>, "window": "<period>" },
  "proposed_dispatch": { "ticket_id": "SELF-HEAL-...", "file_scope": {...}, "acceptance_criteria": [...] },
  "expires_at": "<queued_at + 7 days>",
  "operator_decision": null,
  "operator_rationale": null,
  "operator_at": null
}
```

Queue lives at `.harness/self-heal/hitl-queue/<queue_entry_id>.json`. An expired entry (operator did not decide within 7 days) drops with a log entry; the underlying breach is re-evaluated on the next cycle.

## §10 Observability

Per `grok-orchestration-principles.md §G-15`:

- **Every monitor cycle** emits a structured event (`.harness/self-heal/log/<utc-date>.jsonl`, one JSON object per line): cycle id, signals evaluated, thresholds checked, breaches found, dispatches made, response outcomes recorded.
- **Every dispatch** is logged with the resulting ticket id + the full request JSON pointer.
- **Every response** is correlated back to the originating signal via the ticket id in the state file.
- **Per-file refactor history** is queryable: `state.json` indexes by file path → list of self-heal tickets that touched it.
- **Budget consumption** is logged per dispatch + summarized weekly.

## §11 State management

State file: `.harness/self-heal/state.json`. Gitignored. Atomic write (write to temp + `mv`). Schema:

```json
{
  "schema_version": "1",
  "last_evaluated_at": "<iso8601>",
  "signals": {
    "<signal-id>": {
      "last_value": <number>,
      "last_evaluated_at": "<iso8601>",
      "trend_window_start": "<iso8601>"
    }
  },
  "cooldowns": {
    "<file_scope_fingerprint>:<signal-id>": "<cooldown_expires_at iso8601>"
  },
  "open_tickets": {
    "<ticket_id>": {
      "dispatched_at": "<iso8601>",
      "signal": "<signal-id>",
      "file_scope_fingerprint": "<sha256>",
      "response_status": null | "green" | "red" | "blocked" | "error"
    }
  },
  "budget": {
    "month": "<YYYY-MM>",
    "consumed_usd": <number>,
    "consumed_dispatches": <int>
  },
  "circuit_breakers": {
    "<file_scope_fingerprint>:<signal-id>": {
      "consecutive_red": <int>,
      "consecutive_error": <int>,
      "open_until": null | "<iso8601>"
    }
  }
}
```

Modeled after the plugin's `§2.15 Workflow state contract` shape (`session_id`, `current_phase`, `_resumable`). The self-heal state is not session-scoped because the monitor is the session — it runs continuously. But the resumability principle carries: any monitor restart reads `state.json` and resumes mid-cycle without re-firing already-handled events.

## §12 Configuration

Config file: `.harness/self-heal/config.yaml`. **Committed**, not gitignored — config changes are reviewable. Config bumps follow ADR per `architecture-principles.md §19`.

Hot reload: the monitor SIGHUPs to re-read config. No restart needed.

Default config = the YAML shown in §4. Operators override per-repo by editing the file + landing an ADR.

## §13 Composition with existing contracts

This design **composes on** (cites by name, never duplicates) the following:

- **`handoff-contract.md`** — dispatches use the existing schema verbatim. Self-heal tickets are just tickets.
- **`quality-gate.md`** — quality-gate v1 is the vocabulary of debt. Self-heal signals extend the sub-gate definitions to long-window aggregates.
- **`.grok/templates/dispatch.md` §"Pre-emit checks"** — every dispatched request passes the same eight pre-emit checks before write.
- **Plugin `§2.11 SPACE metric schema`** — signals are SPACE-compatible.
- **Plugin `§2.14 Dry-run contract`** — every dispatch supports a dry-run mode (`--dry-run` flag) that emits the would-be request to a `<ticket-id>.req.dry.json` file without actually triggering the inner loop. Used for threshold tuning.
- **Plugin `§2.15 Workflow state contract`** — `state.json` schema is modeled after the workflow-state envelope.
- **Plugin `§2.17 Live freshness contract`** — signals are timestamped with `last_evaluated_at`; stale signals (> freshness threshold) get re-evaluated before any threshold check.
- **Plugin `§2.8 AI Provenance Manifest`** — refactor responses populate `cost_telemetry`, `decision_provenance.adrs`, and `rubric_state` when present (forward-compatible).

## §14 Authority and amendment

TIER 2 (rulebook-level). Amendments via ADR per `architecture-principles.md §19`. The default-config YAML in §4 is part of this document — any threshold change requires an ADR amendment.

## §15 Out of scope (deferred / explicit non-goals)

- **The monitor generates tickets, not fixes.** All code change comes from the inner loop. No exceptions.
- **The monitor does NOT modify the harness substrate.** `.grok/`, `.claude/`, the plugin cache, and `docs/adr/` are in every dispatched ticket's `must_not_touch`.
- **No deployment / release path.** Self-heal closes the loop at "green response received"; deployment is a different concern (named in TICKET-009 demo storyboard? — deferred).
- **Single-repo only at v1.** Multi-repo correlation is deferred.
- **Static thresholds at v1.** ML-driven threshold tuning is deferred.
- **No real-time signal streaming.** v1 is batch-poll. Real-time (webhooks, file-watch) is deferred.
- **No cross-CL aggregate dashboards.** The data exists in `state.json` + log; a dashboard is a separate concern.

## §16 Future work (named, with rough sequencing)

- **TICKET-008.a — Reference implementation skeleton.** Bash + Node script that implements §3 Observer + §4 Evaluator + §5 Dispatcher for ONE signal (`test-pass-rate`) end-to-end. Validates the design before extending.
- **TICKET-008.b — All P0/P1 signal observers.** Add `coverage-trend`, `lint-warning-drift`, `provenance-completeness-rate`.
- **TICKET-008.c — Circuit breaker + budget cap.** The safety-net features.
- **TICKET-008.d — HITL queue.** The P2 / approval path.
- **TICKET-008.e — Observability log + dashboard query helper.** The `state.json` query CLI.
- **Future ADR — promote P2 signals to P1/P0 after HITL validation.**
- **Future ADR — multi-repo correlation.**
- **Future ADR — ML-driven threshold tuning.**

These are NOT scoped in TICKET-008 itself (per the "Design doc; no code" acceptance criterion). They land as separate CLs after this design is approved.

## §17 Verification (this CL)

- This document exists at `docs/self-healing-design.md`.
- Acceptance criterion (`Design doc; no code`) met — the only files touched are docs + TICKETS.md.
- Failure modes section names 7 distinct failure modes with both designed-in and additional mitigations.
- Composition section cites 8 existing contracts (4 in this repo + 4 plugin §2.X) by name, no duplication.
- Out-of-scope section names ≥ 6 explicit non-goals.
- Future-work section names ≥ 5 deferred sub-tickets with sequencing.
- README.md `Pending:` line updated to drop TICKET-008.
- `./scripts/audit-doc-drift.sh` exit 0.

## §18 Cross-references

- `docs/handoff-contract.md` — wire format
- `docs/quality-gate.md` — debt vocabulary
- `docs/architecture-principles.md` — TIER 2 rule (R-19 observability, R-20 ADR)
- `docs/grok-orchestration-principles.md` — G-13 (HITL), G-15 (observability)
- `docs/founder-directives.md` — D-11 (design FOR primitives), D-12 (production-grade trust)
- ADR-0008 — smoke script (the inner-loop bridge the monitor's dispatches consume)
- ADR-0010 — quality-gate v1 (the vocabulary)
- ADR-0011 — this design (records the v1 decisions)
- Plugin `architecture-v1.9.md §§2.11, 2.14, 2.15, 2.17, 2.8` — composed-on contracts
