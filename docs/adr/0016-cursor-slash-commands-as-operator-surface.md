# ADR-0016 — Cursor slash commands as the operator surface (TICKET-014)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed" instruction on the reconciled TICKETS-011-014 plan) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0012 (AGENTS.md cross-tool surface — the eight-section schema this ADR's commands surface), ADR-0014 (Cursor rules as generator output — the rule files this ADR's commands operate alongside), ADR-0015 (Cursor as host IDE — the operator-stack framing this ADR materializes); composes on ADR-0006 (Grok templates — the .grok/templates/ files three of the seven slash commands drive), ADR-0008 (smoke script — the script `/smoke` wraps), ADR-0009 (audit-doc-drift — the script `/audit` wraps), ADR-0007 (sync-plugin — the script `/sync` wraps)

## Context

TICKETS 011-013 shipped the cross-tool entry point (AGENTS.md), the Cursor-specific operational rulebook (`docs/cursor-integration.md`), and the always-loaded `.cursor/rules/*.mdc` files. What remained: the developer's operator surface — *what does a developer actually type in Cursor chat to drive the harness?*

The plan named seven slash commands in three classes:

- **Class A — terminal wrappers** (`/sync`, `/smoke`, `/audit`): shell out to existing scripts (`scripts/sync-plugin.sh --ensure`, `scripts/smoke-e2e.sh`, `scripts/audit-doc-drift.sh`).
- **Class B — outer-loop drivers** (`/research`, `/decompose`, `/dispatch <TICKET-NNN>`): Cursor's chat agent reads `.grok/templates/{research,decomposition,dispatch}.md` and follows the structured-output schema. `/dispatch` writes a contract-valid `.harness/handoffs/<TICKET-NNN>.req.json`.
- **Class C — inner-loop driver** (`/inner-loop <TICKET-NNN>`): Cursor's chat agent reads the request handoff, loads `.claude/skills/tdd-pro-cl-workflow/SKILL.md`, runs R-G-R, writes the response handoff + decision trail.

Three design questions had to be resolved:

1. **Inner-loop driver default.** Inside Cursor, is the inner-loop driver Cursor's chat agent (in-process), headless `claude -p` (separate process), or operator choice?
2. **Slash command format.** Cursor's `.cursor/commands/*.md` is a markdown prompt template; what structural conventions should every command file follow?
3. **MCP exposure timing.** Should the harness expose its scripts and templates as MCP tools at v1 (Cursor would call them as first-class tools rather than via slash commands), or defer?

## Decision

### 1. Cursor's chat agent is the default inner-loop driver inside Cursor

The `/inner-loop <TICKET-NNN>` command instructs Cursor's chat agent itself to drive R-G-R: read the request handoff, load `tdd-pro-cl-workflow/SKILL.md`, run Red-Green-Refactor against the ticket's acceptance criteria, write the response handoff + trail. This is the **primary** path inside Cursor. The headless `claude -p` path remains fully available (see §2 below) but is the **alternative**, not the default.

Rationale:

- **No new code required.** Cursor's chat agent already runs in-process; the slash command is a prompt template the agent reads. Headless `claude -p` would require either spawning a Claude Code process from within the chat agent's tool-use surface (out of scope for a slash command) or asking the developer to switch to the terminal pane (breaks the in-IDE workflow).
- **Discipline is in the skill, not the model.** `tdd-pro-cl-workflow/SKILL.md` enforces the R-G-R sequence; whichever agent reads the skill follows the discipline. The agent's underlying model (Sonnet, GPT, Grok-in-Cursor, etc.) affects execution quality, not protocol compliance.
- **Quality gate catches model failures.** If the chat agent's selected model produces a change that fails `tests_must_pass`, the audit catches it before commit — same as if headless Claude Code had produced it.
- **Fallback path is documented**, not designed away. `docs/cursor-integration.md §5` and the `/inner-loop` command body both name headless `claude -p` as the alternative.

### 2. Slash command structural template: Purpose / Inputs / Steps / Success criteria / Composition

Every `.cursor/commands/*.md` file follows the same five-section structure:

- **Purpose** — one-paragraph statement of what the command does and why.
- **Inputs** — what the developer provides (typically a TICKET-NNN argument or none).
- **Steps** — numbered procedure the agent walks.
- **Success criteria** — exit-0-verifiable conditions per D-12 (operator can confirm without trusting the agent's self-report).
- **Composition (D-1 reverse per ADR-0013)** — citation of the primitives the command wraps + the Grok/Claude analog (or rationale for absence per ADR-0013's symmetric reading).

Rationale: a uniform template makes the command set discoverable (developer who learns one command knows the structure of all seven) and makes review tractable (each command's success criteria is the audit point). The five-section template is the same shape used in `.grok/templates/*.md` (Purpose / Schema / Examples / Composition) and `.claude/skills/*/SKILL.md` (front-matter + body + Steps + Verification) — D-9 (simple composable patterns) honored across surfaces.

### 3. No MCP server exposure at v1; slash commands are the operator surface

MCP (Model Context Protocol) servers expose tools to Cursor's chat agent as first-class function calls — the agent invokes `harness.smoke()` or `harness.emit_handoff()` programmatically rather than via slash commands. This is a strict superset of the slash-command surface in capability terms.

Deferred at v1 per D-8 (delete the part) and the plan's Out-of-scope section:

- Slash commands cover the operator surface today. The developer-typed `/smoke` and the MCP-tool-call `harness.smoke()` produce equivalent outcomes for the developer-driven workflow that is the v1 target.
- An MCP server would add a new mechanism class (server lifecycle, tool-schema versioning, MCP-client compatibility matrix) without a v1 use case beyond the slash commands already deliver.
- The audit's F-5 pattern (TICKET-013) generalizes to "generator output vs source-of-truth parity" and would extend to an MCP-tool manifest, so the foundation for a future TICKET-017 / ADR-0017 MCP-server is laid.

The seven slash commands close the "Cursor is usable for software development inside the IDE" gap. MCP exposure is a future amplifier, not a v1 prerequisite.

## Alternatives considered

- **Headless `claude -p` as the default inner-loop driver (no `/inner-loop` slash command needed).** Rejected. Requires the developer to switch to Cursor's terminal pane for every inner-loop invocation; breaks the in-IDE workflow that is the founder's "Cursor inside Marcohard" directive. Headless `claude -p` is preserved as the alternative path, not the default.
- **Operator chooses inner-loop driver per invocation** (`/inner-loop --headless TICKET-NNN`). Rejected per D-8. Adds a flag for an alternative that has no measured demand at v1; defer until evidence justifies.
- **MCP server at v1.** Rejected per D-8 + D-13 + plan Out-of-scope. New mechanism class, no v1 use case beyond the slash commands.
- **Six commands (drop `/sync` because `.cursor/rules/agent-context.mdc` already instructs the agent to run `sync-plugin.sh --ensure`).** Rejected. The rule instructs the agent to run the script automatically on session open; `/sync` is the manual re-trigger when the developer wants to refresh mid-session (e.g., after a `git pull`). Both surfaces cover different lifecycle points.
- **Single mega-command `/harness <subcommand>` with seven subcommands.** Rejected per D-9 (simple composable patterns). Seven small command files at one path each is more discoverable than one mega-file with seven branches; the slash command palette in Cursor lists commands directly.
- **Hand-curated long-form command bodies** (each command file >300 lines). Rejected per D-13 (context-as-fundamental-constraint). Each command is a prompt template the agent reads on every invocation; large bodies waste agent context. The five-section template keeps each command under ~50 lines while documenting the contract.
- **Skip the `Composition (D-1 reverse)` trailer.** Rejected. Per ADR-0013, every new Cursor-side primitive must cite its Grok/Claude analog or rationale for absence; the trailer is the structural enforcement point.

## Consequences

### Positive

- **The "Cursor is usable for software development inside the IDE" gap is closed.** A developer who clones the repo, opens it in Cursor, and follows the always-loaded rule's session-start ritual can drive every harness feature without leaving Cursor.
- **Inner-loop driver decision is explicit.** ADR-0016 §Decision-1 records that Cursor's chat agent is the default; future contributors asking "should we headless `claude -p` everything?" have a canonical answer.
- **Uniform command structure makes the surface discoverable and reviewable.** All seven commands follow the same template; reviewer audits scale.
- **D-1 reverse honored.** Every command file cites its Grok/Claude analog (or rationale for "no analog — harness-native"); the bidirectional reading from ADR-0013 is now consistently applied across TICKETS 011-014.
- **MCP path is not closed — just deferred.** The audit's F-5 pattern + the existing handoff-contract wire format would support an MCP-tool manifest with minimal refactor. TICKET-017 / ADR-0017 are the deferred path.
- **`docs/cursor-integration.md §3` surfaces table is updated to surface the seven slash commands explicitly.** The forward references in TICKETS 011-013 are now materialized.
- **`AUTOMATION_INTEL.md` appends "Hybrid Harness v0.2 reconciliation complete" entry.** The user-provided v0.2 spec's directive (§5) is honored as part of TICKET-014 acceptance.

### Negative

- **Cursor's chat agent's selected model affects inner-loop execution quality.** A developer running Cursor against a weak model and invoking `/inner-loop` may produce changes that fail the quality gate. Mitigation: the quality gate's `tests_must_pass` and `lint_clean` sub-gates catch the failure visibly; the audit's `/audit` slash command surfaces it pre-commit; the fallback `claude -p` path is documented for developers who want guaranteed-Claude inner-loop discipline.
- **The Q-DEMO acceptance step is operator-attested, not script-verifiable.** TICKET-014's "did `/dispatch` + `/inner-loop` actually produce contract-valid artifacts in a real Cursor session?" check requires a developer to run it inside Cursor and confirm. Mitigation: same pattern as `smoke-e2e.sh`'s original Q-DEMO (operator-attested per ADR-0008); the slash-command file bodies are exit-0-grep-verifiable in this CL (file presence, required-sections present); the live integration check rides with the first developer who opens the repo in Cursor.
- **MCP exposure deferred.** A future Cursor user who prefers MCP-tool invocation over slash commands has no path at v1. Mitigation: documented as the deferred future TICKET-017 / ADR-0017 with the foundation (F-5 generator-output audit, handoff-contract wire format) already in place.
- **Seven command files grow the operator surface.** Mitigation: each is <60 lines, follows the uniform template, lives under one directory `.cursor/commands/`; the discoverability cost is offset by Cursor's own slash-command palette UX.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance, §3 D-rule bodies untouched.**
- **§4 D-checklist untouched** (D-1 reverse item from ADR-0013 already applies to TICKET-014's new primitives without further amendment).
- **`schema_version` of the handoff contract unchanged.**
- **AGENTS.md untouched in this CL** (the §6 outer-loop pointer and §4 skill enumeration already cover the surfaces these commands drive; no new pointer needed).

## Verification (executed before commit)

- All seven `.cursor/commands/*.md` files exist: `sync.md`, `smoke.md`, `audit.md`, `research.md`, `decompose.md`, `dispatch.md`, `inner-loop.md`.
- Every command file contains the five required sections: `## Purpose`, `## Inputs`, `## Steps`, `## Success criteria`, `## Composition`.
- Every command file cites either the script it wraps (Class A: `scripts/sync-plugin.sh --ensure`, `scripts/smoke-e2e.sh`, `scripts/audit-doc-drift.sh`) or the template/skill it drives (Class B: `.grok/templates/*.md`; Class C: `.claude/skills/tdd-pro-cl-workflow/SKILL.md`).
- Every command file's "Composition (D-1 reverse per ADR-0013)" trailer either names the Grok/Claude analog or explains why none exists.
- `docs/cursor-integration.md §3` surfaces table updated: every "Once shipped: developer types `/...`" entry now reads in present tense; the table-overview paragraph notes the seven commands are live.
- `AUTOMATION_INTEL.md` gains an append entry "Hybrid Harness v0.2 reconciliation complete" dated 2026-05-26 per the v0.2 spec's §5 directive.
- `./scripts/audit-doc-drift.sh` exit 0 (no stale stubs, no stale framing, no future-tense to DONE tickets, no sync-plugin drift, no `.cursor/rules/` drift — F-1..F-5 all clean).
- `./scripts/smoke-e2e.sh` exit 0 (toy at Red baseline; this CL touched no executable beyond adding `.cursor/commands/` content and the AUTOMATION_INTEL append).
- `./scripts/export-cursor-rules.sh --check` exit 0 (`.cursor/rules/` still matches generator output).
- Q-DEMO step (operator-attested): the first Cursor session after this CL lands runs `/dispatch TICKET-DEMO` and `/inner-loop TICKET-DEMO` against `examples/string-utils/` and confirms `.req.json` + `.res.json` are contract-valid and tests pass. Same operator-attestation pattern as ADR-0008's smoke-e2e Q-DEMO step.

## Out of scope (deferred)

- **MCP server exposing harness operations as tools.** Future TICKET-017 / ADR-0017.
- **Devcontainer (`.devcontainer/devcontainer.json`).** Deferred per D-8 / plan Out-of-scope.
- **Cursor extension (custom integration).** Deferred per D-11 / plan Out-of-scope.
- **Per-Cursor-model command-prompt tuning.** Deferred per D-8 — don't optimize before the un-tuned version is in use.
- **`--driver` flag on `/inner-loop` for headless `claude -p` invocation from chat.** Deferred per D-8 — single default path; headless fallback documented in `docs/cursor-integration.md §5`.
- **Cursor handoff via ACP** (`docs/grok-orchestration-principles.md §7`). Deferred per plan Out-of-scope.
- **Slash commands for self-healing dispatch / monitor invocation.** Deferred — self-healing is design-only at v1 per ADR-0011.

## Implementation references

- New: `.cursor/commands/sync.md`
- New: `.cursor/commands/smoke.md`
- New: `.cursor/commands/audit.md`
- New: `.cursor/commands/research.md`
- New: `.cursor/commands/decompose.md`
- New: `.cursor/commands/dispatch.md`
- New: `.cursor/commands/inner-loop.md`
- Modified: `docs/cursor-integration.md` (§3 surfaces-table entries now read as live, not "Once shipped"; §9 sequencing notes TICKET-014 DONE)
- Modified: `AUTOMATION_INTEL.md` (append "Hybrid Harness v0.2 reconciliation complete" entry per v0.2 §5)
- Modified: `TICKETS.md` (TICKET-014 row + TICKET-013 marked DONE)
- New: this ADR
- Related: ADR-0012 (AGENTS.md — cross-tool surface), ADR-0014 (Cursor rules — the always-loaded sibling to these commands), ADR-0015 (Cursor as host IDE — operator-stack framing), ADR-0006 (Grok templates — three commands drive them), ADR-0008 (smoke script — `/smoke` wraps it), ADR-0009 (audit-doc-drift — `/audit` wraps it), ADR-0007 (sync-plugin — `/sync` wraps it).
