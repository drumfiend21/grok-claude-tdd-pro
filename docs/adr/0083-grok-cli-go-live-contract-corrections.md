# ADR-0083 — Go-live contract corrections against the real Grok CLI (grok 0.2.81): argv prompt, reasoning default model, headless transport footer, envelope extraction

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"Test that GCTP is properly utilizing Grok for the outer-loop"*) + Claude (local session).
- **Trigger:** ADR-0080 built `_grok_invoke` against the **documented** `-p` contract and explicitly deferred flag verification to first live run (G-21). With credits live, the first real runs surfaced four gaps between the documented contract and the shipped CLI (`grok 0.2.81`). Each fix below was **derived from live evidence** (debug logs, API errors), applied at the single designated correction point, and locked in hermetically.

## The four corrections (evidence → fix)

1. **Prompt is argv, not stdin.** `grok --help`: `-p, --single <PROMPT>` takes the prompt as its value. → `_grok_invoke` reads the runner's internal stdin contract into a variable and passes it as the `-p` argument. (Runner-internal stdin interface unchanged; tests unaffected.)
2. **The CLI's default model rejects G-4's effort tuning.** Live error: `Model grok-4.20-0309-non-reasoning does not support parameter reasoningEffort` (HTTP 400). G-4 *mandates* tuned reasoning effort, so a non-reasoning default is out of contract. → The runner pins a standing default **reasoning** model: `GROK_DEFAULT_MODEL` (default `grok-4.3` — §2's named pick for "general agentic reasoning"; confirmed available to the key via `/v1/models`). `--model`/`GROK_MODEL` still request a cheaper model; the G-20 ladder now escalates cheap-model → `DEFAULT_MODEL`. Cache slots and the run log use the *effective* model.
3. **Headless turns were PermissionCancelled.** Debug log: `cancellationCategory=PermissionCancelled` — the CLI is an agentic session runner; the templates (written for an agent that persists artifacts) made the model attempt file-write tools, which headless mode cancels. `--permission-mode plan|dontAsk` did NOT fix it (still cancelled). → The compile step (§14: the runner owns compiling templates into one self-contained prompt) appends a **byte-stable headless transport footer** (G-5): emit the phase document as reply text; no tools; the harness owns persistence. Live result flipped `Cancelled/empty` → `EndTurn` + a contract-shaped handoff JSON. Templates themselves are untouched (prompt quality preserved; the footer is transport, not content).
4. **The reply is wrapped in a CLI envelope.** Live output shape: `{text, stopReason, sessionId, requestId, thought}` — the phase JSON lives in `.text`. → New `_extract` step (G-21 tolerant): envelope with `stopReason != EndTurn` OR non-JSON `.text` ⇒ **failure, exit 4, never cached** (a cancelled turn had previously passed the naive JSON check and poisoned the G-19 cache — now impossible); envelope with `EndTurn` ⇒ stdout is the **inner** phase JSON; output with no `.text` field passes through unchanged (covers direct-JSON emitters and future CLI shapes).

## Consequences

### Positive
- **The outer loop is verified live end-to-end:** real `grok -p` run on `grok-4.3` at `effort=low` produced a contract-shaped dispatch document (`schema_version "1"`, `file_scope` incl. the prime-directive `must_not_touch` denylist, `quality_gate`, `applicable_rules`); the identical re-run returned it from the G-19 cache with zero API cost; the audit log carries `running→green` then `cached→cached` under one deterministic run-id.
- G-5 prompt caching confirmed working in production (ACP `_meta`: 22,720 of 26,069 input tokens were cached reads on the very first templated run).
- Downstream consumers now receive the phase JSON directly — no envelope-digging.

### Neutral / honest caveats
- The go-live CLI's json envelope exposes **no usage object**, so ADR-0082's G-15 usage capture is dormant at this CLI version (the extraction is tolerant and activates if a future CLI adds it; usage IS visible in `--debug-file` ACP meta if ever needed).
- The footer adds ~90 stable tokens per prompt (cache-friendly, G-5).
- `grok-4-fast` is not in this key's `/v1/models` list; the G-20 cheap-model lever currently targets whatever cheaper reasoning models the account exposes.

### Negative
- Prompt now rides argv (visible in local `ps`) — prompts are not secrets (the key stays env-only, G-2); noted for completeness.

## Verification (executed before commit)
- **Live:** `scripts/grok-run.sh dispatch …` → exit 0, contract-shaped JSON, `stopReason=EndTurn` path; identical re-run → `CACHED`, no API call; run log green+cached events. Pre-fix failure modes reproduced and captured (400 reasoningEffort; PermissionCancelled).
- **Hermetic:** `tests/test-grok-run.sh` **55/55** (adds: EndTurn envelope unwraps to inner JSON; Cancelled envelope → exit 4 and never cached; post-cancel run goes live; compiled prompt carries the footer; plain runs pass `--model grok-4.3`; `GROK_DEFAULT_MODEL` override honored).
- Full suite + audits green; no `claude-tdd-pro` path touched (prime directive); D-6 clean.

## Implementation references
- Runner: `scripts/grok-run.sh` (`_grok_invoke`, `HEADLESS_FOOTER`, `_extract`, `DEFAULT_MODEL`) · Tests: `tests/test-grok-run.sh`
- G-rules: `docs/grok-orchestration-principles.md` §15 (G-2, G-4, G-5, G-15, G-19, G-20, G-21) + §2, §14 · Prior: ADR-0080 (deferred flag verification), ADR-0081 (go-live), ADR-0082 (reuse/model/usage levers)
