# ADR-0006 — Grok orchestrator prompt templates (research / decomposition / dispatch)

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, "develop per all files" instruction) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0001 (plugin-sync mechanism); the handoff contract in `docs/handoff-contract.md` (which this ADR's templates produce documents for)

## Context

`TICKETS.md TICKET-003` calls for prompt templates populating `.grok/` for research, decomposition, sub-agent dispatch, and deploy — three named templates each with input vars + output shape documented. After ADR-0005 elevated `docs/ai-engineering-corpus.md` to TIER 0, every CL is now audited against the corpus's "explore → plan → implement → commit" workflow and Musk's Algorithm. The Plan subagent's investigation confirmed `.grok/` is a stub README and no executable substrate exists yet.

This ADR records the decisions for the substrate's first executable artifacts.

## Decision

### 1. Three templates, not four

Ship `research.md`, `decomposition.md`, `dispatch.md`. Do NOT ship a separate `deploy.md`. Rationale:

- A real deploy target does not yet exist in this repo (D-5 forbids toy-only substrate after TICKET-005). Until then, "deploy" collapses into "dispatch" — both are one-shot structured emissions of a JSON document.
- Musk's Algorithm step 2 (delete before optimize): deferring a `deploy.md` is the deletion-pass outcome. A future ADR will introduce a distinct deploy template when and if deploy semantics diverge from dispatch (e.g., when production targets, blue/green, or canary state need first-class representation).
- TICKETS.md TICKET-003 says "three named templates"; the wording supports the three-template decision.

### 2. Templates are plain markdown, not a templating engine

No Jinja / Handlebars / Liquid. Each template is a markdown doc with:

- Drawn-from attribution (D-1)
- G-rules touched (named, not enumerated)
- Corpus anchors (TIER 0 cross-reference)
- Input variables table
- Output shape (JSON Schema fragment for `research.md` and `decomposition.md`; reference-only for `dispatch.md` because the schema lives in `docs/handoff-contract.md`)
- System prompt skeleton (cache-stable per G-5)
- Pre-emit checklist (machine-checkable; satisfies D-3 terminal state)

The runner that compiles these into Grok CLI invocations is TICKET-006's responsibility. This separation honors Musk's Algorithm step 5 ("automate last"): get the substrate right before automating it.

### 3. Schema by reference, never by copy

`dispatch.md` does NOT inline the handoff-contract JSON Schema. It points at `docs/handoff-contract.md §"Grok → Claude (request)"` and lists the minimum fields a Grok run must populate. Rationale:

- R-3 / R-5: single source of truth, bilateral changes.
- R-11 tolerant reader.
- If `dispatch.md` inlined the schema, a future schema bump would require two-file synchronization that drift would silently violate.

The bump procedure is documented inline in `dispatch.md`: one CL touches the contract doc AND the template AND the consumer-side validator (the `.claude/` skill that TICKET-004 will create).

### 4. Templates cap at ~80 lines

Per corpus §3 prune test ("would removing this cause the agent to make mistakes?"). Templates are not tutorials. Operational content only. The README in `.grok/templates/` carries the cross-template index so individual files stay focused.

### 5. Reasoning-effort defaults per G-4

- `research.md` — medium (high for ≥ 3-system scope).
- `decomposition.md` — medium (high for architecture).
- `dispatch.md` — low.

Stated in each template's metadata. G-4 banding is by latency budget, not capability ceiling.

### 6. Idempotency obligation isolated to `dispatch.md`

`dispatch.md` is fully idempotent (G-19) because its output is a deterministic JSON doc that downstream tools key on. `research.md` and `decomposition.md` are "best-effort idempotent" (same input → equivalent output, not byte-identical) because reasoning steps may surface different but equivalent research refs.

### 7. Denylist hardcoded in `dispatch.md` pre-emit check

Every emitted handoff MUST include `must_not_touch: [".grok/**", ".claude/**", "claude-tdd-pro/**"]`. This enforces the prime directive (no cross-repo edits to claude-tdd-pro) and protects the orchestration substrate from inner-loop dispatch. The check is executed BEFORE the file is written.

## Consequences

### Positive

- First executable substrate exists. The repo is no longer rules-only.
- Pipeline (research → decomposition → dispatch) is named, ordered, and traceable. Future maintainers can see at a glance what each Grok invocation does.
- Handoff contract has its first producer. The contract was previously inert text; `dispatch.md` operationalizes it.
- Prime directive enforcement is now structural (in the `must_not_touch` pre-emit check), not just textual.
- Drawn-from attributions (D-1) live inside each template, so every Grok-side primitive carries its Claude Code/Cursor lineage.

### Negative

- No runtime yet. Templates are markdown that a future TICKET-006 runner will compile. Until that lands, templates are not directly executable.
- Schema-by-reference creates a coordination risk if `docs/handoff-contract.md` and `dispatch.md`'s consumer-side validator drift. The bump procedure in `dispatch.md` is the mitigation.
- The deferred `deploy.md` decision means a future ADR is required if deploy semantics diverge. That's fine — better than premature deploy abstraction now.

### Neutral

- D-rule count unchanged (still 13).
- §1 of `docs/founder-directives.md` untouched.
- TIER 0/1/2 authority hierarchy unchanged.

## Future work

- **TICKET-004** wires the consumer side (`.claude/`): the skill that reads `dispatch.md`'s output and invokes the inner loop with the right `tdd-pro-*` skills.
- **TICKET-005** ships the first toy module (`examples/string-utils`) so the end-to-end pipeline has something to operate on.
- **TICKET-006** ships the runner script that takes the three templates and a feature brief and emits a real handoff doc end-to-end.
- **TICKET-008** owns the monitor template (`monitor.md`) — not part of this CL.

## Implementation references

- New: `.grok/templates/research.md`
- New: `.grok/templates/decomposition.md`
- New: `.grok/templates/dispatch.md`
- New: `.grok/templates/README.md`
- Updated: `.grok/README.md`
- Updated: `TICKETS.md` (TICKET-003 → DONE)
- Ticket: `TICKET-003` in `TICKETS.md`
- Related: `docs/handoff-contract.md`, `docs/grok-orchestration-principles.md §15`, `docs/ai-engineering-corpus.md`
