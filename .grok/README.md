# .grok/

Grok orchestrator config and prompt templates for the outer loop of grok-claude-tdd-pro.

Contents:

- [`templates/`](./templates/) — the three named prompt templates: `research.md`, `decomposition.md`, `dispatch.md` (per TICKET-003). Headless-first (G-2), Structured Output (G-3), cache-stable (G-5).

The pipeline is **research → decomposition → dispatch**, ending at the `docs/handoff-contract.md` API boundary, where the inner loop (`claude-tdd-pro`, consumed via `.claude/`) takes over.

See `.grok/templates/README.md` for the index, defaults, and pre-merge audit checklist.

Authority:

- TIER 0 supreme: `docs/ai-engineering-corpus.md` (procedural playbook for all engineering)
- TIER 1: `CLAUDE.md` prime directive + `docs/founder-directives.md` (D-1..D-13)
- TIER 2 for Grok-facing surfaces: `docs/grok-orchestration-principles.md` (G-1..G-21)
