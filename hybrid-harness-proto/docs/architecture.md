# Hybrid Harness Architecture

## Goal

Compose Grok Build CLI (outer orchestration) with Claude TDD Pro (inner Red-Green-Refactor quality core) into one harness suitable for enterprise pipelines at 1,000+ engineer scale, where:

- Pipelines need to be end-to-end automated.
- Every code change must still pass a strict TDD gate with audit-quality provenance.

## Role split (the contract)

### Grok Build CLI — outer loop

Owns:

- Research and requirements gathering (real-time external sources)
- Architecture decomposition (turning a feature request into ordered tickets)
- Ticket dispatch (handing one ticket at a time to the inner loop)
- Deployment and post-deploy verification
- Long-running monitors and self-healing triggers

Does NOT:

- Edit production code directly. All code edits inside acceptance-tested scope go through the inner loop.
- Override the inner loop's "green" gate. If Claude says tests fail, Grok does not deploy.

### Claude TDD Pro — inner loop

Owns:

- Red: write minimal failing test for the current ticket
- Green: implement minimal code to pass
- Refactor: improve while keeping tests green
- Decision-trail emission for the change (file paths, test outcomes, provenance refs)

Does NOT:

- Do its own research outside the ticket's pre-supplied context
- Decide whether a ticket should exist
- Deploy

The inner loop is invoked via `claude -p` (headless) and is driven by the three existing skills in `claude-tdd-pro/.claude/skills/`:

- `tdd-pro-cl-workflow` — pre-flight architecture quote → spec-write → audit → commit
- `tdd-pro-batch-cl` — substrate-touch CL batching decision
- `tdd-pro-bash32-portability` — bash 3.2 / BSD-tool portability checklist (relevant when the harness writes shell scripts)

## Handoff contract (defined in detail by TICKET-002)

Grok → Claude (per-ticket payload):

```json
{
  "ticket_id": "TICKET-NNN",
  "title": "...",
  "acceptance_criteria": ["...", "..."],
  "file_scope": ["path/to/touch.ext", "..."],
  "context": {
    "research_refs": ["url-or-doc-id", "..."],
    "decomposition_parent": "FEATURE-NNN",
    "prior_decisions": ["..."]
  }
}
```

Claude → Grok (per-ticket response):

```json
{
  "ticket_id": "TICKET-NNN",
  "status": "green" | "red" | "blocked",
  "changed_files": ["...", "..."],
  "test_results": {"passed": N, "failed": N, "skipped": N},
  "decision_trail_ref": "path/or/id",
  "notes": "..."
}
```

The exact JSON schema, error semantics, and freshness rules land in TICKET-002.

## Reusing the existing trio (no new SKILL.md)

The briefing's suggestion of a new `tdd-pro-core` SKILL.md is deliberately rejected. The existing trio already covers the inner loop:

- `tdd-pro-cl-workflow` IS the Red-Green-Refactor loop with the audit gate.
- `tdd-pro-batch-cl` handles the "should this be one commit or many" call.
- `tdd-pro-bash32-portability` is the portability checklist for any shell substrate the harness emits.

A new SKILL.md would either duplicate these or become a thin wrapper. Wiring (TICKET-004) achieves the same effect without a new authoring surface.

## Self-healing extension (designed in TICKET-008)

Beyond the per-feature flow, Grok runs a long-running monitor that:

- Watches debt thresholds (test flake rate, refactor backlog, coverage delta)
- Spawns Claude TDD Pro refactor cycles when thresholds breach
- Re-runs the deploy pipeline on green

This closes the loop: the harness is not just "build the feature" but "keep the codebase healthy on autopilot."

## What this architecture is NOT

- A replacement for `claude-tdd-pro/docs/architecture-v1.9.md`. That document remains the canonical architecture for the quality core. This document is the architecture for the **harness around it**.
- An invitation to invent features inside claude-tdd-pro. If the harness needs something claude-tdd-pro doesn't expose, that lands as a v1.11 amendment proposal in that repo, separately.
