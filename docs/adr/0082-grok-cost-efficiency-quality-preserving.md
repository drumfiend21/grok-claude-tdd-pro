# ADR-0082 — Quality-preserving Grok cost efficiency: G-19 result reuse, G-20 opt-in model lever, G-15 usage capture

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"Optimize without compromising the quality of Grok prompts and responses, architecture and requirements and without regressing any functionality."*) + Claude (local session).
- **Trigger:** with the outer loop live (ADR-0081) every `/research`/`/decompose`/`/dispatch` is paid. A cost analysis of the invocation surfaces found three levers that are not merely *compatible* with the G-rules — two of them are behaviors the rules already require and the runner didn't deliver: G-19's "detects an existing [equivalent handoff]" and G-15's "token cost" audit field.

## The binding constraint: quality is not a trade dial

Every mechanism below is quality-neutral **by construction**, not by tuning:

- **Prompts unchanged** — templates stay byte-identical (G-5 cache stability also depends on this); inputs remain suffixed after the stable prefix. Nothing is truncated, compressed, or summarized.
- **Responses unchanged by default** — the default model is untouched (no silent downgrade), effort defaults (G-4) are untouched, and research/decomposition run **fresh by default**.
- **Reused output is the paid output** — byte-for-byte, from a green run of the *same* phase + prompt + effort + model. An explicit quality ask (`--effort high`, `--model …`) is a different cache slot and always runs live.
- **Escalation only raises capability** — the G-20 ladder never retries downward.

## Decision (all in `scripts/grok-run.sh`; no contract surface changed)

1. **G-19 result reuse.** Every green live run records its structured output at `.harness/runs/<run-id>.<slot>.out.json` (slot = hash of effort+model; runs dir is operator-local + gitignored). On an identical invocation:
   - **dispatch** → the recorded result is returned without re-invoking Grok. This implements G-19 verbatim (*"Re-running a Grok prompt with the same context produces an equivalent handoff **or detects an existing one**. Never duplicates a dispatch."*) and the templates README's standing claim that `dispatch.md` is "fully idempotent".
   - **research / decomposition** → **fresh by default** (G-17 makes research freshness a correctness/quality property; the README classes these phases "best-effort" idempotent). Reuse happens only under an explicit `GROK_REUSE_TTL_SECONDS=<secs>` opt-in, age-checked against the recorded file's mtime.
   - Never silent: a `CACHED` stderr banner + `start/complete cached` events in the run log. Overrides: `--fresh` (per-invocation), `GROK_REUSE=0` (kill switch). Failed runs write no record — a red run can't poison the cache. The reuse check sits before the stub decision, so an already-paid result is usable even on a machine without the CLI/key.
2. **G-20 opt-in model lever + recorded escalation.** New `--model <id>` (default `GROK_MODEL` env; default **unset** → the CLI's default model, i.e. zero behavior change unless the operator opts in). When a cheaper requested model fails structured output (non-zero exit or non-JSON, the existing G-3 check), the runner escalates **once** to the CLI's default model, logging an `escalate` event with `from_model` + reason — G-20's exact shape (*"escalate to a stronger model with a recorded reason. No silent escalation."*). Without `--model` there is no ladder (nothing stronger is known) and failure remains exit 4. Bonus: a G-3 failure on a cheap model is no longer 100% wasted spend.
3. **G-15 usage capture.** The `complete green` log event now carries grok's reported `usage` object (tolerant reader — absent usage is simply omitted, G-21), plus a `model` field on every event. This closes the G-15 gap (*"token cost … persisted for the audit trail"*) and makes the savings measurable.

## What was checked and deliberately NOT done (would regress rules or quality)

- No batching of dispatches (G-6), no relaxation of JSON validation (G-3), no default model downgrade (quality + G-20 explicitness), no default reuse for research (G-17), no template compression (G-5 + prompt quality), no skipped audit logging (G-15).
- Verified zero-cost surfaces stay zero-cost: `smoke-e2e.sh` references the runner only in a comment; hooks and all test suites never invoke a live grok (tests inject fake `GROK_BIN`).
- Wall-clock note: run *identity* stays wall-clock-free (deterministic run-id, unchanged); the TTL check reads mtime at runtime only, which does not affect replayability of identity.

## Consequences

### Positive
- Duplicate dispatches (retries, resumed sessions, idempotent re-drives) cost zero. Cost becomes observable per run/phase. Operators get a sanctioned, recorded path to ~1/15th-cost models (§2) without any default quality change.

### Neutral / honest caveats
- After an escalation, the recorded result under the requested model's slot is the *stronger* model's output — reuse can only upgrade quality, never degrade it.
- `--model` flag names are passed through to the CLI verbatim; validity is the CLI's concern (isolated in `_grok_invoke`, G-21).

### Negative
- Small `.out.json` files accumulate in the gitignored runs dir (same lifecycle as the existing logs).

## Verification (executed before commit)
- `tests/test-grok-run.sh` **47/47** (adds 19: dispatch reuse [no re-invoke, byte-identical, announced]; `--fresh`; `GROK_REUSE=0`; per-effort cache slots; research fresh-by-default + TTL opt-in reuse; usage tokens in the log; `--model` passthrough; single recorded escalation on cheap-model failure; failed runs don't poison the cache).
- Full suite + cross-references + doc-drift green; hook-security baseline re-keyed for line shifts only; no `claude-tdd-pro` path touched (prime directive); D-6 clean.

## Implementation references
- Runner: `scripts/grok-run.sh` (reuse block, `_grok_invoke(model)`, `_log` model/usage fields) · Tests: `tests/test-grok-run.sh` · Doc: `.grok/templates/README.md §Defaults and policy`
- G-rules: `docs/grok-orchestration-principles.md` §15 (G-3, G-4, G-5, G-6, G-15, G-17, G-19, G-20, G-21) + §2 · Prior: ADR-0080/0081 (runner + go-live)
