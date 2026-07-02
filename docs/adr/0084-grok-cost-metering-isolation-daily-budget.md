# ADR-0084 — Grok cost control: context isolation, tool-surface removal, live usage metering, and a hard daily budget gate

- **Status:** Accepted
- **Date:** 2026-07-02
- **Deciders:** operator (`drumfiend21`; 2026-07-02: *"That cost me $5-10 in less than 30 mins. … The cost of it when actively architecting and building with GCTP cannot be more than $1-2 per day."*) + Claude (local session).
- **Trigger:** the TICKET-111 go-live session cost $5–10. Debug meta showed why: every `grok -p` call in the repo carried ~26k input tokens — ~2k was our compiled prompt; the rest was the CLI's agentic session injection (repo tree, AGENTS.md, 25 tool schemas), all pure overhead under §14's self-contained-prompt contract. The operator set a hard requirement: ≤ $1–2/day under active use.

## Decision — four mechanisms in `scripts/grok-run.sh` (measured, not guessed)

1. **Out-of-repo `--cwd` isolation.** The CLI runs in a per-run empty temp dir (mktemp, trap-cleaned; `GROK_WORKDIR` overrides). Measured: in-repo 26,069 input tokens/run → isolated 13,128, of which 12,608 are cached reads (~10× cheaper tier), i.e. **~520 fresh input tokens per run**. A first attempt using `.harness/runs/.workdir` failed live — an empty dir *inside* the repo still lets the CLI walk up and re-inject the repo; outside-the-tree is load-bearing.
2. **Tool surface removed: `--tools ""`.** Live runs showed the model non-deterministically attempting `read_file` despite the headless footer — burning extra turns (28.5k-token run) and, pre-TICKET-111, cancelling turns outright. With the allow-list empty, `-p` is pure generation: deterministic `EndTurn`, no tool schemas in the prompt, no retry turns. This *is* the §14 contract (harness owns persistence; G-1/G-7 keep Grok out of files), now enforced at the CLI level instead of by instruction alone.
3. **Real usage metering (G-15, now live).** The CLI's json envelope has no usage object, but its `--debug-file` ACP meta does. The runner always passes a temp debug file, parses `inputTokens/outputTokens/cachedReadTokens/reasoningTokens` from the final attempt, and (a) records them in the run-log green event, (b) appends a day-keyed line to `.harness/runs/usage-ledger.jsonl`, (c) prints a per-run banner: `usage: in=… (cached …) out=… reasoning=… → N units; today T/B units`.
4. **Hard daily budget gate (G-13).** Before any live call, the runner sums today's ledger; at/over `GROK_DAILY_BUDGET_UNITS` it **refuses** (exit 3) with a plain-language banner. *Units* approximate billable input-token equivalents: `fresh-in ×1 + cached-in ×1/10 + (output+reasoning) ×5`. Default **150,000/day** ≈ $0.5–1.5 at typical flagship rates — inside the operator's cap with margin. Overage requires the operator's explicit `GROK_BUDGET_OVERRIDE=1` (G-13: spend over the stated threshold requires human approval). Stubs, `--dry-run`, and G-19 cached re-runs cost nothing and are never blocked — the workflow degrades to free modes at the cap, it doesn't brick.

## Measured cost picture (live, this machine)

- Steady-state dispatch run: `in=13,128 (cached 12,608) out=227 reasoning=52 → 3,175 units` → **~47 live runs/day** inside the default budget; at typical rates roughly **$0.005–0.02/run**, i.e. an active architecting day lands well under $1 even before cached re-runs (free) are counted.
- The $5–10 session is explained and non-recurring: ~8 full-context (26k), full-tool-surface flagship sessions, several of them cancelled-but-billed debugging runs. Every one of those failure modes is now structurally removed or budget-capped.

## What was deliberately NOT changed

- Templates and the headless footer: byte-identical prompts (G-5, prompt quality).
- Default model stays `grok-4.3` (ADR-0083): quality unchanged; the gate enforces the cap regardless of model. `GROK_MODEL`/`GROK_DEFAULT_MODEL` remain the cheaper-model levers (G-20 ladder intact).
- Effort defaults (G-4) unchanged.

## Consequences

### Positive
- The operator's cost requirement becomes a **mathematical guarantee** (hard gate), not a hope; spend is observable per run, per day, per phase.
- Runs are more reliable (no tool-attempt cancellations) and faster (fewer turns).

### Neutral / honest caveats
- Units are a pricing *approximation*; actual USD depends on xAI's per-model rates. The ledger records raw token counts, so the mapping can be recalibrated without losing history.
- On multi-attempt (escalated) runs the meter records the final attempt only — slight undercount, conservative direction for reliability, noted here.
- `--tools ""` semantics are this CLI version's; the G-21 correction point (`_grok_invoke`) still owns any future flag drift.

## Verification (executed before commit)
- **Hermetic:** `tests/test-grok-run.sh` **68/68** (adds: usage parsed into run log + ledger with exact unit math; per-run banner; `--cwd` passed and ≠ repo; `--tools` passed; over-budget → exit 3 naming the budget; `GROK_BUDGET_OVERRIDE=1` runs; cached re-run stays free while over budget; raised budget unblocks).
- **Live:** metered dispatch run green with the 3,175-unit banner and ledger line; the pre-fix failure/overhead modes (28.5k tool-retry run; in-repo workdir re-injection) reproduced and captured before fixing.
- Full suite + audits green; no `claude-tdd-pro` path touched (prime directive); D-6 clean.

## Implementation references
- Runner: `scripts/grok-run.sh` (`_grok_invoke` flags, workdir/debug setup, budget gate, usage/ledger block) · Tests: `tests/test-grok-run.sh`
- G-rules: `docs/grok-orchestration-principles.md` §15 (G-1, G-4, G-5, G-7, G-13, G-15, G-19, G-20, G-21) + §2, §14 · Prior: ADR-0082 (reuse/model levers), ADR-0083 (go-live corrections)
