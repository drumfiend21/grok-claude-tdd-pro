# ADR-0022 — PostToolUse review-gate hook (TICKET-015.a)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, "Proceed to build the remaining architecture" instruction 2026-05-26 — TICKET-015.a deferral from ADR-0017) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0017 (orchestrating-swarms — TICKET-015.a deferred from there); ADR-0014 (Cursor rules — the F-5 defensive-skip pattern this hook mirrors); composes on `AGENTS.md §2` (file-edit-fences — the rules this hook operationalizes)

## Context

ADR-0017's TICKET-015.a deferral named PostToolUse hooks for review gates as a follow-on to the orchestrating-swarms ship. The 2026-05-26 Architect Automation Briefing specified the pattern: *"Use PostToolUse hooks for review gates."*

Today the harness has exactly one hook (SessionStart, configured in `.claude/settings.json`). The file-edit-fences documented in `AGENTS.md §2` (forbidden paths: `.harness/plugin-cache/`, `claude-tdd-pro/`, `.claude/skills/tdd-pro-*` symlinks, `.cursor/rules/*.mdc` generator output) are operator-visible rules but had no enforcement mechanism — an operator (or agent) could edit a forbidden file and only discover the violation at pre-commit via the audit scripts (which catch some classes — F-1..F-6 — but not all forbidden-path edits).

This ADR ships the first PostToolUse hook: a forbidden-path detector that fires immediately after `Edit | Write | MultiEdit | NotebookEdit` tool calls and surfaces violations via the hook's stderr (which Claude Code displays to the operator). Pre-emptive prevention via PreToolUse was considered but explicitly rejected per Decision-3 below.

Three design questions had to be resolved:

1. **Hook event class.** PreToolUse (prevent) or PostToolUse (surface after the fact)?
2. **Scope.** Just file-edit-fences, or broader review (syntax checks, schema validation, etc.)?
3. **Failure handling.** Block the agent from continuing, or just log + let the agent self-correct?

## Decision

### 1. PostToolUse (per Architect Automation Briefing direction)

The briefing's verbatim text was: *"Use PostToolUse hooks for review gates."* PostToolUse fires AFTER tool execution, meaning a forbidden-path edit has already been written to disk when the hook runs. The hook surfaces the violation; the agent is expected to revert + apologize + re-route to the correct surface.

Rationale for PostToolUse over PreToolUse:

- **Matches the briefing's wording.** "Review gate" semantics = after-the-fact inspection, not pre-execution block.
- **Trust the agent's self-correction loop.** Modern coding agents (Claude Code, Cursor's chat agent, Grok Build) all process hook stderr as session-visible diagnostic; they self-correct rather than ignoring.
- **PreToolUse would force a more aggressive block.** Per Claude Code's hook protocol, PreToolUse exit-non-zero blocks the tool entirely — too aggressive for a v1 advisory gate. The forbidden-path list could grow false positives (e.g., legitimate edits inside `.cursor/rules/` to fix the generator), and false-positive blocks would be more friction than false-positive after-the-fact warnings.
- **F-5 + F-6 catch any persistent violation at pre-commit.** The agent can ignore the PostToolUse warning and proceed, but `audit-doc-drift.sh` will catch the persistent state at pre-commit — defense in depth.

### 2. Scope at v1: forbidden-path detection only

The hook checks ONLY whether the edited file path matches one of four forbidden patterns from `AGENTS.md §2`:

1. `.harness/plugin-cache/*` — generator-managed; hand-edits violate R-2 (versioned consumption) and get clobbered on next `sync-plugin.sh --ensure`.
2. `claude-tdd-pro/*` — sibling plugin repo; cross-repo edits violate CLAUDE.md prime directive.
3. `.claude/skills/tdd-pro-*` — symlinks into the plugin cache; hand-edits silently leak into the unrelated upstream.
4. `.cursor/rules/*.mdc` — generator output per ADR-0014; hand-edits are also caught by F-5 at pre-commit (this hook is the earlier-surfaced signal).

Broader scope (syntax checks on `.sh` files, schema validation on `.json` files, content-hash verification of generated files) was rejected per D-8 (delete the part). Each broader check is a separate concern and warrants its own ticket; bundling them all into a single hook would inflate v1 complexity and create false-positive risk that this hook v1 can avoid.

### 3. Failure handling: exit-2 surfaces error to operator; does NOT block agent

The hook exits with code 2 + stderr message on a forbidden-path violation. Per Claude Code's hook protocol, exit code 2 displays the stderr message to the operator inline with the session. The agent is expected to:

1. See the error message.
2. Recognize the violation against `AGENTS.md §2`.
3. Revert the edit using its own tools (Edit / Write with restored content).
4. Re-route to the correct surface (e.g., edit the generator instead of the generator output).

The hook does NOT use exit code that would cause Claude Code to terminate the session — it's a review gate, not a kill switch. Non-edit tools and edits to non-forbidden paths exit 0 (no-op for the hook).

## Alternatives considered

- **PreToolUse instead of PostToolUse.** Rejected per Decision-1. Briefing direction + false-positive risk at v1.
- **Broader scope** (syntax checks on `.sh` / schema validation on `.json` / content-hash verification of generators). Rejected per D-8. Each is a separate ticket worth shipping in isolation.
- **No hook; rely entirely on pre-commit audit (F-1..F-6).** Rejected. PostToolUse gives operators an immediate signal; pre-commit audit only fires at commit time, leaving multi-tool-call sessions with persistent forbidden-path damage uncorrected for many turns.
- **Hard-block via exit code that terminates the session.** Rejected per Decision-3. Review gate, not kill switch.
- **Path-pattern config externalized to `.claude/settings.json`.** Rejected per D-13. The four forbidden patterns are stable (codified in AGENTS.md §2); externalization would invite drift between AGENTS.md and the config; the hook script's case-statement is the simpler source of truth and the AGENTS.md citation in each rule message keeps the two synchronized.
- **JSON output from the hook instead of stderr text.** Rejected. Stderr text is Claude Code's standard display path for hook violations; JSON would require operator parsing.

## Consequences

### Positive

- **TICKET-015.a acceptance criterion met.** PostToolUse hook ships; the orchestrating-swarms briefing's review-gate direction is operationalized.
- **AGENTS.md §2 file-edit-fences now have enforcement.** Previously operator-visible rules were soft (operator might violate them and only discover at pre-commit audit). Now the violation is surfaced immediately to the agent's session.
- **Defense in depth.** The hook + F-5 (cursor rules) + F-6 (manifest schema) form three layers of forbidden-path / drift detection. Hook fires immediately; F-5 + F-6 catch persistent state at pre-commit.
- **Defensive pattern preserved.** Per ADR-0014's F-5 pattern: the hook is silently absent (returns no-op exit 0) when its prerequisites (e.g., `CLAUDE_PROJECT_DIR` env var) aren't set. No hard dependency on hook presence; harness still works if the hook script is removed.
- **D-1 reverse honored (ADR-0013).** This Claude-Code-specific hook composes on Cursor's chat-agent equivalent of session-time rule enforcement (`.cursor/rules/agent-context.mdc`) and Grok Build's equivalent (planned per Source 9 — `/hooks` modal). Documented in AGENTS.md §2 cross-references.
- **D-12 honored.** Hook violation message is exit-0-verifiable + cites the specific rule (R-2 / prime directive / ADR-0014) + cites the source of the rule (AGENTS.md §2). Auditor can trace from violation back to the canonical authority.

### Negative

- **PostToolUse fires AFTER the edit lands on disk.** A bad-actor agent could write forbidden content, see the warning, and ignore it — the file is already modified. Mitigation: F-5 + F-6 catch persistent state at pre-commit; operator running `git status` between turns sees the unexpected modification.
- **Adds one tool-call latency per Edit/Write/MultiEdit/NotebookEdit.** Mitigation: the hook is bash + a small `node -e` invocation; sub-100ms per call. Negligible in practice.
- **Hook depends on node for JSON parsing.** Mitigation: node is already a harness dependency (per ADR-0008 smoke-e2e.sh, ADR-0020 audit-manifest.sh); the hook is consistent with that established baseline.
- **Forbidden-path list is hard-coded in the hook script.** Mitigation: case-statement is easy to extend; AGENTS.md §2 citation in each rule message ensures discoverability. A future TICKET-015.b could externalize to config IF and only IF the pattern set proves volatile.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **`schema_version` of the handoff contract unchanged.**
- **No new AGENTS.md or `.cursor/rules/` content** (the hook operationalizes existing AGENTS.md §2 rules; no new rules added).
- **`scripts/sync-plugin.sh --help` unchanged** (F-4 still passes).

## Verification (executed before commit)

- `bash -n .claude/hooks/post-tool-use-review-gate.sh` clean.
- `chmod +x .claude/hooks/post-tool-use-review-gate.sh` applied.
- `.claude/settings.json` parses; `PostToolUse` array added alongside existing `SessionStart`; matcher `Edit|Write|MultiEdit|NotebookEdit`.
- Positive test (allowed path): `echo '{"tool_name":"Edit","tool_input":{"file_path":"docs/quality-gate.md"}}' | .claude/hooks/post-tool-use-review-gate.sh` → exit 0.
- Negative test 1 (`.harness/plugin-cache/`): exits 2 + ADR-0007 / R-2 violation message.
- Negative test 2 (`.cursor/rules/*.mdc`): exits 2 + ADR-0014 violation message.
- Negative test 3 (`claude-tdd-pro/`): exits 2 + prime-directive violation message.
- Non-edit tool (`Bash`): exits 0 (no-op).
- `./scripts/audit-doc-drift.sh` exit 0 (F-1..F-6 clean).
- `./scripts/smoke-e2e.sh` exit 0 (full 4-artifact run).
- `./scripts/export-cursor-rules.sh --check` exit 0.
- ADR-0022 follows the numbered ADR template.

## Out of scope (deferred)

- **PreToolUse hook to BLOCK forbidden-path edits.** Future ADR if PostToolUse advisory proves insufficient.
- **Broader syntax / schema checks** in the hook (bash -n on .sh edits, JSON validity on .json edits). Each is a separate future ticket.
- **Externalized forbidden-path config** in `.claude/settings.json`. Defer per D-13 unless the pattern set proves volatile.
- **Cursor-side equivalent of PostToolUse review gate.** Cursor's chat agent currently uses `.cursor/rules/*.mdc` for session-level rule enforcement; per-tool-call hooks would be a Cursor extension API concern (deferred per TICKETS 011-014 Out-of-scope).
- **Hook telemetry** (count of fires per session, false-positive rate). Defer per D-8.
- **Hardened hook with PID isolation / SELinux contexts.** Out of scope for a v1 advisory gate.

## Implementation references

- New: `.claude/hooks/post-tool-use-review-gate.sh` (bash 3.2 + `node -e` for JSON parsing; ~80 lines)
- Modified: `.claude/settings.json` (adds PostToolUse hook alongside existing SessionStart)
- Modified: `TICKETS.md` (adds TICKET-015.a row marked DONE)
- New: this ADR
- Related: ADR-0017 (orchestrating-swarms — this ADR closes the TICKET-015.a deferral), ADR-0014 (Cursor rules generator-output-only — F-5 defensive pattern this hook mirrors), ADR-0009 (audit-doc-drift mechanism — pre-commit gate that catches persistent state if the hook is ignored), `AGENTS.md §2` (file-edit-fences — the rule set this hook operationalizes).
