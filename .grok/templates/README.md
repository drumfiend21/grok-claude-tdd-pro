# .grok/templates/ — Grok outer-loop prompt templates

This directory holds the three Grok orchestrator prompt templates that drive the outer loop of grok-claude-tdd-pro. They are headless-first (G-2) and consumed via `scripts/grok-run.sh <phase>` (TICKET-108/109), which compiles the template + inputs into one self-contained `grok -p` invocation. Each emits Structured Output (G-3); each is cache-stable byte-for-byte across runs (G-5).

## The three templates

| Template | Phase | Output consumer | Reasoning effort (G-4) |
|---|---|---|---|
| [`research.md`](./research.md) | Outer-loop research | `decomposition.md` | medium (high for ≥ 3-system scope) |
| [`decomposition.md`](./decomposition.md) | Decompose research → atomic tickets | `dispatch.md` | medium (high for architecture) |
| [`dispatch.md`](./dispatch.md) | Emit one Grok→Claude handoff doc | The inner loop (Claude TDD Pro via `.claude/`) | low |

The phases form a pipeline: **research → decomposition → dispatch**. Each template is one Grok invocation. The handoff contract (`docs/handoff-contract.md`) is the API boundary at the end of the pipeline.

## Drawn from (D-1)

Each template's "Drawn from" section names its Claude Code and/or Cursor analog and the gap it fills. Summary:

- `research.md` — Claude Code plan-mode read-only investigation; Cursor ask-mode. Difference: outer-loop, persists to disk with provenance.
- `decomposition.md` — Claude Code plan-then-implement separation; Cursor compose mode. Difference: each output is an atomic ticket, not a multi-step plan.
- `dispatch.md` — `claude -p ... --output-format json` pattern; xAI Grok Build sub-agent dispatch; ACP. Difference: one-shot, schema-validated, idempotent.

## Defaults and policy

- **Model** — Grok default per environment; G-20 (no silent escalation) applies if a faster model fails.
- **Auth** — `XAI_API_KEY` env-var (G-2). Never in templates.
- **Output format** — JSON (G-3). `--output-format json` for one-shot, `stream-json` for monitoring runs (G-15).
- **Logging** — every run emits `run-id`, `prompt-hash`, tool calls, token cost (G-15). Persisted under `.harness/runs/<run-id>.jsonl`.
- **Idempotency** — `dispatch.md` is fully idempotent (G-19). `research.md` and `decomposition.md` are best-effort (same input → equivalent output, not byte-identical).

## Not in this directory (deferred)

- `deploy.md` — deferred until a real deploy target exists (per D-5: production-grade > toy). The dispatch primitive covers what would otherwise be a deploy template; a future ADR may introduce a distinct deploy phase if and when deploy diverges.
- `monitor.md` — owned by TICKET-008 (self-healing extension design). Not part of TICKET-003's scope.
- Template-engine code (Jinja, etc.) — explicitly out. Templates are plain markdown; the runner (`scripts/grok-run.sh`, TICKET-108/109) compiles inputs into the Grok CLI invocation.

## Pre-merge audit (every template added here)

- [ ] Names its Claude Code and/or Cursor analog (D-1).
- [ ] Cites the G-rules it touches.
- [ ] Cites the corpus anchor(s) it operationalizes.
- [ ] Documents input variables (table) + output shape (JSON Schema fragment OR a reference to the canonical schema).
- [ ] Includes a system-prompt skeleton that is byte-stable (G-5).
- [ ] Includes a pre-emit checklist.
- [ ] Caps at ~80 lines of body (per corpus §3 "would removing this cause mistakes?" prune test).

## Cross-references

- API boundary: `docs/handoff-contract.md`
- G-rule definitions: `docs/grok-orchestration-principles.md §15`
- Architectural rules: `docs/architecture-principles.md §16`
- TIER-0 supreme operating directive: `docs/ai-engineering-corpus.md`
