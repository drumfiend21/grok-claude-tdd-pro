---
name: orchestrating-swarms
description: Worker-fanout coordinator for the harness's orchestrator-worker pattern. Use AFTER `/decompose` produces ≥2 atomic tickets that touch non-overlapping `file_scope`. Spawns one worker sub-agent per ticket, each on its own git worktree per G-8, each running the existing `tdd-pro-cl-workflow` R-G-R discipline. The lead agent collects worker outputs and runs the quality gate per ticket. Composes on (does NOT replace) Grok's outer-loop decomposition per G-7.
---

# Orchestrating swarms — worker-fanout coordinator

The Claude-Code / Cursor-side materialization of the orchestrator-worker pattern named in `docs/grok-orchestration-principles.md §§4, 9, 10` and binding G-rules G-7, G-8, G-9, G-16. This skill does NOT decompose work — Grok still owns decomposition per G-7. This skill fans out *already-decomposed* atomic tickets into parallel workers on isolated git worktrees, then collects and gates their outputs.

If you are reading this and the decomposition has not yet been produced, stop and invoke `/research` then `/decompose` first.

## Step 0 — Pre-flight authority extraction (NON-NEGOTIABLE)

Quote, literally, before proceeding:

- **G-7** — *"Orchestrator-Worker. Grok is the orchestrator; Claude TDD Pro instances are workers. Synthesis happens in Grok."* (`docs/grok-orchestration-principles.md §15`)
- **G-8** — *"Parallel via git worktrees. Sub-agents dispatched in parallel each get their own git worktree, branch, and PR. Decomposition is along file/feature boundaries to minimize file overlap."*
- **G-9** — *"Bounded fan-out. No supervisor manages more than 8 active workers at once."*
- **G-16** — *"Atomic tickets. Every ticket Grok dispatches is sized to one CL, with concrete acceptance criteria and a `file_scope`."*

Then read `docs/grok-orchestration-principles.md §§4, 9, 10` (orchestrator-worker canonical form; task decomposition strategies; parallel sub-agents in git worktrees). Never proceed from memory; the rulebook is the source of truth.

## Step 1 — Decomposition acceptance

Read the Grok-produced decomposition. Typical surface: N `.harness/handoffs/TICKET-NNN.req.json` files written by `.cursor/commands/dispatch.md` (or by direct Grok `-p` invocation against `.grok/templates/dispatch.md`).

For each request file:

1. Validate contract-compliance per `docs/handoff-contract.md §Grok→Claude`. Required fields: `schema_version: "1"`, `ticket_id`, `acceptance_criteria`, `file_scope`, `context`, `quality_gate`.
2. Confirm atomicity per G-16: `acceptance_criteria` is a single concrete bar; `file_scope` is tightly bounded (no `*`, no whole-repo).
3. Reject composite tickets back to Grok for further decomposition — do NOT silently fan out a composite ticket.

If any request file fails validation, stop and surface the failure to the operator. Do not proceed to Step 2.

## Step 2 — File-scope conflict check (G-8 pre-decomposition discipline)

Build the file-scope conflict map BEFORE spawning any worker:

1. Collect each ticket's `file_scope` into a flat list.
2. Compute pairwise overlap: any two tickets that touch the same file (or the same directory + glob) overlap.
3. Partition the ticket set into:
   - **Parallel-eligible** — no `file_scope` overlap with any other ticket in the partition.
   - **Serialize** — overlap detected; these tickets run sequentially (in the order Grok produced them), not in parallel.

Per G-8: *"Decomposition is along file/feature boundaries to minimize file overlap."* Overlap is reworked into a serial schedule, not papered over. Document the partition decision in the lead-agent's session log.

## Step 3 — Bounded fan-out (G-9 ≤ 8 workers)

Apply the G-9 cap: at most 8 parallel-eligible workers run concurrently per supervisor. If `|parallel-eligible| > 8`:

- Run the first 8 as parallel workers.
- Queue the surplus; spawn each as a parallel-eligible slot frees.
- Do NOT introduce a mid-level supervisor at v1 (G-rules §5 hierarchical pattern is deferred per ADR-0017 Out-of-scope).

If `|parallel-eligible| ≤ 8`, all run concurrently.

## Step 4 — Per-worker spawn (one worker = one worktree = one branch = one PR per G-8)

For each parallel-eligible ticket:

1. **Create the worktree.** From the repo root:
   ```sh
   git worktree add .harness/worktrees/TICKET-NNN claude/branch-TICKET-NNN
   ```
   The branch name pattern `claude/branch-TICKET-NNN` is the swarm convention; adjust if the repo uses a different prefix.

2. **Spawn the worker.** In Claude Code: use the Task tool to spawn a sub-agent rooted in the worktree directory. In Cursor or other AGENTS.md consumers that lack an equivalent: drive each worktree serially as a separate session (the swarm degrades to serial; the worktree-per-ticket discipline is preserved). See "Driver compatibility" below.

3. **Hand off to the inner loop.** Each worker:
   - Reads its `.harness/handoffs/TICKET-NNN.req.json`.
   - Reads `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (the existing per-CL R-G-R discipline; do NOT re-implement R-G-R here).
   - Runs the R-G-R sequence against the ticket's `acceptance_criteria` within its `file_scope`. The Architect / Builder / Validator naming from the originating briefing maps to R-G-R phases SEQUENTIALLY within one worker:
     - **Architect** = Red (write the failing test capturing the acceptance criteria).
     - **Builder** = Green (implement the minimum change to pass).
     - **Validator** = Refactor + quality-gate pre-review (cleanup; verify sub-gates per `docs/quality-gate.md`).
   - Writes `.harness/handoffs/TICKET-NNN.res.json` per `docs/handoff-contract.md §Claude→Grok`.
   - Writes `.harness/trails/TICKET-NNN.md` naming the R-G-R steps (or skip rationale per `tdd-pro-cl-workflow/SKILL.md`'s stub allowance).

4. **Do not cross worktree boundaries.** A worker's edits live in its worktree. The lead agent does not write to a worker's worktree; the worker does not write outside its declared `file_scope`. The existing `tdd-pro-cl-workflow/SKILL.md` enforces file-scope discipline at the inner loop; the swarm composes on that enforcement.

## Step 5 — Collect worker outputs

After workers complete (or time out):

1. Gather each worker's `.res.json` from its worktree's `.harness/handoffs/TICKET-NNN.res.json`.
2. Validate contract-compliance per `docs/handoff-contract.md §Claude→Grok`. Required fields: `schema_version: "1"`, `ticket_id`, `status`, `changed_files`, `test_results`, `decision_trail_ref`, `gate_results`.
3. Run the per-ticket quality gate per `docs/quality-gate.md` against each `gate_results` block. Four sub-gates: `tests_must_pass` (REQUIRED), `coverage_delta_min` (REQUIRED, default 0), `lint_clean` (REQUIRED), `provenance_complete` (RECOMMENDED at v1).
4. Log PASS / FAIL per ticket. If any sub-gate fails with no documented per-CL override rationale, mark the worker `red`.

## Step 6 — Synthesis (per G-7 — synthesis happens in the orchestrator)

Per G-7: *"Synthesis happens in Grok. The orchestrator does not drift into worker territory."* The lead agent's synthesis is operator-facing only at v1:

1. Report per-ticket status (green / red / blocked) + the artifact paths.
2. Surface gate failures explicitly; do NOT auto-retry — auto-retry is `docs/self-healing-design.md` territory (deferred per ADR-0011).
3. If invoked from a Grok-orchestrated outer loop, return a summary suitable for Grok to consume as a swarm result (a list of ticket-status pairs, one per worker, plus aggregate metrics).

The lead agent does NOT decide which `red` workers to re-dispatch; that decision belongs to Grok (or the operator via HITL per G-12 / G-13).

## Step 7 — Worktree cleanup

For each completed worker (PR merged or abandoned):

```sh
git worktree remove .harness/worktrees/TICKET-NNN
git branch -d claude/branch-TICKET-NNN     # or -D if force-needed
```

Per G-8: one worktree = one branch = one PR; the worktree is ephemeral. Do not leave orphan worktrees — they consume disk and create state-management hazards. If the lead agent crashes mid-fanout, the operator runs `git worktree list` and removes stragglers manually (no daemon supervision at v1 per ADR-0017 Out-of-scope).

## Driver compatibility

| Driver | Capability |
|---|---|
| Claude Code | Native Task tool spawns sub-agents per worktree; full parallel fan-out per G-9. |
| Cursor's chat agent | Drives each worktree serially (no equivalent of Claude Code's Task tool at v1). The worktree-per-ticket discipline is preserved; the parallelism degrades to sequence. Functionally equivalent for ≤2-3 tickets; loses throughput on larger swarms. |
| Headless `grok -p` / `claude -p` | Either can drive the worker side per worktree if invoked from inside the worktree directory. Lead-agent role typically stays in Claude Code or Cursor's chat. |
| Other AGENTS.md consumers (Codex, Amp, Jules, Factory, Grok Build) | Read this skill; drive serially or per native sub-agent capability. The worktree + handoff contract are the cross-tool primitives; the spawn mechanism is tool-specific. |

## Failure modes (5 named, each with structural mitigation)

1. **Worktree collision.** Mitigation: worktree paths follow `TICKET-NNN` pattern; before `git worktree add`, the skill checks for an existing `.harness/worktrees/TICKET-NNN` and surfaces an operator-visible error rather than silently overwriting.
2. **Worker exceeds context budget mid-R-G-R.** Mitigation: each worker runs the existing `tdd-pro-cl-workflow/SKILL.md` which enforces atomic-ticket discipline (G-16 — one CL per worker). If a worker reports `blocked` because the ticket was misjudged atomic, the lead surfaces it for Grok re-decomposition; no auto-retry.
3. **Quality-gate fails for one worker; lead must still surface ALL results.** Mitigation: Step 5 collects ALL `.res.json` files regardless of per-ticket status. The lead never short-circuits on the first failure.
4. **Lead crashes mid-fanout, leaves orphan worktrees.** Mitigation: worktree paths are predictable (`TICKET-NNN`); operator recovery via `git worktree list` + `git worktree remove` is documented in Step 7. No daemon at v1; future TICKET-015.b could add automatic orphan-cleanup.
5. **Sub-agent writes outside its declared `file_scope` (e.g., touches repo root from inside the worktree).** Mitigation: the existing `tdd-pro-cl-workflow/SKILL.md` enforces file-scope discipline; pre-commit audit catches escape via existing F-1..F-5 patterns + the worker's own `.res.json` `changed_files` block (mismatch with `file_scope` is a contract violation surfaced at validation in Step 5).

## Composition + provenance

This skill composes on:

- `docs/grok-orchestration-principles.md §§4, 9, 10` — orchestrator-worker canonical form, task decomposition, parallel sub-agents in worktrees.
- `docs/grok-orchestration-principles.md §15 G-7, G-8, G-9, G-16` — the binding rules this skill operationalizes.
- `docs/handoff-contract.md` — `.req.json` / `.res.json` schemas each worker consumes / produces. One schema, two producers (Grok-per-ticket + lead-agent-per-worker); same factoring as self-heal dispatch per ADR-0011.
- `.claude/skills/tdd-pro-cl-workflow/SKILL.md` — the R-G-R discipline each worker runs. The Architect / Builder / Validator naming maps to R-G-R phases sequentially within one worker.
- `docs/quality-gate.md` — the per-worker output gate enforced in Step 5.
- `.grok/templates/decomposition.md` — the Grok-side producer of the input the swarm consumes. (D-1 reverse attribution per ADR-0013.)
- Anthropic, *Building Effective Agents* (Schluntz & Zhang; `docs/founder-directives.md §1 Source 5`) — the orchestrator-worker pattern literature.
- xAI, *Introducing Grok Build* (Source 4) — the "up to 8 parallel sub-agents per launch, each in its own worktree" operational baseline.

This skill does NOT duplicate the content it composes on (R-3). It is the materialization of an already-defined pattern, not a re-statement of the pattern's principles.

D-1 reverse attribution per ADR-0013: this Claude-Code-side worker-fanout primitive cites its Grok-side analog explicitly — Grok produces the decomposition (`.grok/templates/decomposition.md`); the Grok-orchestration rulebook owns the pattern (G-7 / G-8 / G-9 / §§4, 9, 10); this skill is the Claude / Cursor consumer surface. The two surfaces compose without duplication.

History: introduced in TICKET-015 (ADR-0017 — orchestrating-swarms skill; worker-fanout mode; MVP scope).
