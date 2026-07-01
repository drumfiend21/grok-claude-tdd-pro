# ADR-0080 — Grok headless outer-loop runner (`scripts/grok-run.sh`) — the G-2 contract surface, stub-first

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"Let's wire Grok up. Guide me through it. Consider where this plugin is meant to run from its documentation"* → *"What does the architectural design say?"*) + Claude Opus 4.8 (local session).
- **Trigger:** the harness's outer loop is documented as Grok-driven, but Grok had **never actually run** — every "Grok" step was done inline by the driving agent (Claude Code) or stubbed. `scripts/smoke-e2e.sh:113` literally read *"in a live run this would be `grok -p …`"*; `.grok/templates/README` references "the runner (TICKET-006)", but TICKET-006 shipped only the smoke stub (*"stub mode default; live mode deferred per ADR-0008"*). No real `grok -p` invocation path existed.

## What the architecture dictates (the decision was derived, not chosen)

Per the operator's instruction to let the design decide:

- **G-2 (Headless-first):** *"Every Grok invocation MUST work in `-p` mode with `XAI_API_KEY` env-var auth … the headless path **is the contract**."* → a headless `-p` runner is **mandatory**, the contract surface — not optional.
- **§14:** *"The headless invocation is **the contract surface for automation**."* Meaningful exit codes; structured output; hooks emit the audit trail.
- **G-3 / G-4 / G-15 / G-19** fully specify the runner's *shape*: Structured Output (JSON), reasoning effort tuned per phase (research/decompose = medium, dispatch = low), an observability record per run (`run-id` / `prompt-hash` / cost), and idempotent dispatch.
- **G-7 + §1** (Grok orchestrates; Grok Build auto-detects `AGENTS.md` and drives — *"headless-capable"*) → Grok-as-session-driver (**Mode A**) is the end-state, and it **composes on** the same headless `-p` contract (§14: TUI-only behavior is "out of contract"). So the runner is the foundation; the driver rides on it.
- **Stub-first pattern:** TICKET-006 / ADR-0008 established building the contract-valid wiring in **stub mode**, activating live when the runtime arrives. G-21 (tolerant reader) covers CLI-flag drift.

→ The design says: **build the headless runner now, stub-first, as the foundation for both modes.**

## Decision

Add `scripts/grok-run.sh <phase> [--input k=v]… [--effort …] [--dry-run]` (phase ∈ research | decomposition | dispatch → `.grok/templates/<phase>.md`):
- Compiles the template + inputs into ONE self-contained, stateless prompt (§14) and invokes it as `grok -p` with **Structured Output** (G-3) at the phase's tuned **effort** (G-4).
- Emits the **audit record** to `.harness/runs/<run-id>.jsonl` (G-15) — `run-id`, `phase`, `prompt_hash`, `effort`, `status`, stub flag, exit. `run-id` = `<phase>-<prompt-hash[:12]>`, deterministic → **idempotent** re-runs (G-19).
- **STUB-first:** a contract-valid stub result (no network) whenever `--dry-run`, or the `grok` CLI is absent, or `XAI_API_KEY` is unset — never a *silent* success (log + banner say `stub`, and the banner names the missing prerequisite + `x.ai/cli`). Mirrors TICKET-006.
- **Isolated invocation** — `_grok_invoke()` is the single point holding the exact CLI flags (`grok -p --output-format json --effort …` per the documented contract); if the real CLI differs, that one function is the only thing to correct.
- **Auth (G-2):** `XAI_API_KEY` is read from the env only — never printed, never written to disk, never in the templates.
- `scripts/smoke-e2e.sh` now points its dispatch step at this runner (still stub-default, per its own contract).

## Scope — what is and isn't now live

- **Wired (this ADR):** the headless `-p` **contract surface** (Mode B) — tested both stub and live (via a fake `grok` on `$PATH`). This is the foundation the docs mandate.
- **NOT yet live (operator-gated):** an *actual* Grok run. Two prerequisites only the operator can supply: (1) install the **Grok Build CLI** from `x.ai/cli`; (2) export `XAI_API_KEY`. Until then every invocation returns the contract-valid stub.
- **Mode A (Grok as the session driver):** the operator runs the repo in `grok` (not `claude`); Grok auto-detects `AGENTS.md` (G-10) and drives the outer loop, using this runner's contract underneath. That is an operating choice, not code — this ADR makes it possible; it does not force it. **As long as the session is driven by Claude Code, Grok is invoked only when this runner shells out.**

## Consequences

### Positive
- The outer loop finally has a real, contract-valid invocation path — the harness is no longer "Grok on paper" at the contract layer. The moment the operator supplies the CLI + key, `grok-run.sh` (and `smoke-e2e`) invoke Grok for real, no code change.
- Every run is observable (G-15) and idempotent (G-19); auth stays in the env (G-2); output is structured (G-3).

### Neutral / honest caveats
- Built against the **documented** `-p` contract; the real CLI's flags are verified at go-live (isolated in `_grok_invoke`, G-21). Stub-first means CI stays green without a key.
- This wires the *contract*, not a running Grok. Full Grok-owns-the-outer-loop operation additionally requires the operator to (a) install the CLI, (b) provide the key, and (c) choose to drive with `grok` (Mode A) rather than Claude Code.

### Negative
- A gitignored `.harness/runs/` audit dir; a small per-invocation hashing/logging cost.

## Verification (executed before commit)
- `tests/test-grok-run.sh` — 18/18 hermetic (usage; `--dry-run` stub; grok-absent → stub; grok-present-no-key → stub [G-2]; **live path via a fake `grok`** passes structured output through and is NOT stubbed; non-JSON → G-3 fail (4); grok failure → 4; G-15 log written; G-4 effort defaults).
- `smoke-e2e.sh` dispatch step re-pointed at the runner (stub-default preserved).
- `.harness/runs/` gitignored; no `claude-tdd-pro` path touched (prime directive); D-6: `docs/founder-directives.md` unchanged.

## Operator go-live (the guide)
1. Install the Grok Build CLI — `x.ai/cli` (`grok`).
2. `export XAI_API_KEY=…` (from the xAI console). Never commit it (G-2).
3. `scripts/grok-run.sh research "<topic>"` → it now invokes `grok -p` live (verify `_grok_invoke`'s flags against the real CLI once; adjust if needed).
4. Run the pipeline research → decomposition → dispatch → a real handoff → Claude inner loop.
5. (Mode A) open the repo in `grok`; confirm it auto-detects `AGENTS.md` and drives.

## Implementation references
- Runner: `scripts/grok-run.sh` · Tests: `tests/test-grok-run.sh` · Templates: `.grok/templates/{research,decomposition,dispatch}.md`
- G-rules: `docs/grok-orchestration-principles.md` §15 (G-2, G-3, G-4, G-7, G-15, G-19, G-21) + §1, §14 · Binding surface: `AGENTS.md` (G-10) · Prior stub: TICKET-006 / ADR-0008
