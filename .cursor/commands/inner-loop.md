# /inner-loop <TICKET-NNN> — run R-G-R inner loop for one ticket

## Purpose

Drive the inner-loop Red-Green-Refactor discipline as Cursor's chat agent (primary path per `docs/cursor-integration.md §4`). Read the ticket's request handoff, load the inner-loop skill, run R-G-R against the ticket's acceptance criteria, and write the response handoff + decision trail. This command IS the harness's inner loop when running inside Cursor.

The alternative path (headless `claude -p`) remains available in Cursor's terminal per `docs/cursor-integration.md §5`; it is documented but requires no new code.

## Inputs

- `<TICKET-NNN>` — the ticket id, supplied as the slash command argument. The file `.harness/handoffs/<TICKET-NNN>.req.json` must already exist (write it via `/dispatch` first).

## Steps

1. **Read the request handoff.** Open `.harness/handoffs/<TICKET-NNN>.req.json`. Capture `acceptance_criteria`, `file_scope`, `context`, `quality_gate`. If the file is missing or fails contract validation (`docs/handoff-contract.md §Grok→Claude`), stop and tell the user to run `/dispatch` first.

2. **Load the inner-loop discipline.** Read `.claude/skills/tdd-pro-cl-workflow/SKILL.md` end-to-end. This skill is the per-CL R-G-R loop (architecture-quote pre-flight → spec-write → self-audit → verify → propose commit). Do NOT skip this step; the discipline lives in the skill body, not in this command.

3. **Run R-G-R against the ticket.**
   - **Red:** write the failing test(s) that capture the acceptance criteria. Run the test suite; confirm Red.
   - **Green:** implement the minimum code change inside `file_scope` to pass the test. Run the test suite; confirm Green.
   - **Refactor:** improve the implementation without changing test behavior. Re-run the test suite after each refactor; confirm Green throughout.
   - If the change is stub-shape (per `tdd-pro-cl-workflow/SKILL.md`'s stub allowance), document the skip rationale in the decision trail rather than forcing a Red-test that doesn't exist for the substrate-only CL.

4. **Apply the quality gate.** Run the `quality_gate` sub-gates per `docs/quality-gate.md`: `tests_must_pass` (REQUIRED), `coverage_delta_min` (REQUIRED, default 0), `lint_clean` (REQUIRED), `provenance_complete` (RECOMMENDED at v1). For any per-CL override, document rationale.

5. **Write the response handoff.** Compose `.harness/handoffs/<TICKET-NNN>.res.json` per `docs/handoff-contract.md §Claude→Grok` with required fields: `schema_version: "1"`, `ticket_id`, `status` (green / red / blocked), `changed_files`, `test_results`, `decision_trail_ref`, `gate_results`.

6. **Write the decision trail.** Compose `.harness/trails/<TICKET-NNN>.md` naming the three R-G-R steps (or skip rationale). Cite the SKILL.md sections walked.

7. **Emit the provenance manifest.** Run `./scripts/emit-manifest.sh --ticket <TICKET-NNN> --driver cursor-inner-loop` to produce `.harness/audit/<TICKET-NNN>.manifest.json` per `docs/provenance-bridging-design.md` (ADR-0018). The manifest indexes the three sources (request, response, decision_trail) with sha256 + size_bytes for tamper detection. Index-only per R-3 — no content duplication. Defensive: log warning on non-zero exit, do not block.

8. **Surface artifacts to the user.** Report: status, changed_files count, test_results summary, gate_results pass/fail, the three artifact paths plus the manifest path. Tell the user `/audit` is next, then commit.

## Success criteria

- `.harness/handoffs/<TICKET-NNN>.res.json` exists, parseable, contract-valid per `§Claude→Grok`.
- `.harness/trails/<TICKET-NNN>.md` exists, names the R-G-R steps (or skip rationale).
- `status: green` (or `red`/`blocked` with documented rationale).
- All quality-gate sub-gates pass (or per-CL overrides documented).
- The diff stays within `file_scope` per the request.
- No edits to forbidden surfaces per `AGENTS.md §2` (`.harness/plugin-cache/`, `claude-tdd-pro/`, `.claude/skills/tdd-pro-*` symlinks, `docs/founder-directives.md §1`, `docs/founder-directives.md §3` D-rule bodies, `.cursor/rules/*.mdc`).

## Composition (D-1 reverse per ADR-0013)

Loads `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (upstream plugin via symlink). Composes on `docs/handoff-contract.md` (TICKET-002 — the wire format) and `docs/quality-gate.md` (TICKET-007 / ADR-0010 — the gate definitions). Grok analog: none — the inner loop is by design Claude TDD Pro's responsibility, not Grok's (per CLAUDE.md "Two harness rules"). Cursor's chat agent driving the SKILL.md replaces headless `claude -p` as the in-process driver per ADR-0016; the discipline enforced is identical regardless of which agent executes it.
