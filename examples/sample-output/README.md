# examples/sample-output/

Committed sample artifacts from a real `smoke-e2e.sh` run. These are the **five files the harness produces per ticket** at green status. They are checked in so a recruiter or reviewer can inspect the actual audit-trail shape **without running anything**.

The runtime equivalents live under `.harness/handoffs/`, `.harness/trails/`, and `.harness/audit/` (gitignored). This `examples/sample-output/` directory mirrors what those gitignored runtime artifacts look like.

## What's in `TICKET-042/`

`TICKET-042` is the smoke-e2e fixture ticket — a deliberate Red test against `examples/string-utils/slugify()`. The harness runs the full outer-loop → inner-loop → audit cycle end-to-end and produces these five artifacts. The hashes in `manifest.json` are real sha256s of the real `request.json` / `response.json` / `decision-trail.md` bytes in this same directory.

| File | What it is | Schema reference |
|---|---|---|
| `request.json` | Contract-valid Grok → Claude handoff: ticket_id, acceptance_criteria, file_scope, quality_gate, applicable_rules | `docs/handoff-contract.md §Grok→Claude` |
| `response.json` | Contract-valid Claude → Grok response: status, changed_files, test_results, decision_trail_ref, rules_verified | `docs/handoff-contract.md §Claude→Grok` |
| `decision-trail.md` | Human-readable R-G-R decision trail: what went Red, what went Green, what was Refactored, what skill was invoked | `.claude/skills/tdd-pro-cl-workflow/SKILL.md` |
| `manifest.json` | Provenance index: per-source sha256 + size_bytes + status, drift-detectable via `scripts/emit-manifest.sh --regenerate` | `docs/provenance-bridging-design.md` + ADR-0018/0019/0020/0021 |
| `aibom.json` | AI Bill of Materials per ADR-0038 Batch 8: fine-tunes used + generated-at timestamp | Plugin's `compliance/aibom-emit.sh` contract |

## How to regenerate (for reviewers)

```bash
./scripts/sync-plugin.sh --ensure   # materialize the pinned plugin cache
./scripts/smoke-e2e.sh              # produces the five runtime artifacts
ls .harness/handoffs/ .harness/trails/ .harness/audit/
```

Every artifact under `examples/sample-output/TICKET-042/` was produced by running exactly those two commands on this branch (after the latest pin bump per ADR-0041).

## Why this directory exists

External reviews of the project asked for "visible evidence the system actually works." Committed sample artifacts close that loop: a reader can see the exact audit-trail shape that ships per ticket without trusting any narrative claim. Per ADR-0018, the manifest is drift-detectable; `scripts/audit-manifest.sh` re-verifies these files against schema at every commit.

Per the harness's R-3 (cite, don't duplicate) discipline, the files here are static snapshots — they are **not** consumed by any test or runtime. The runtime equivalents are gitignored under `.harness/`. This directory exists for human inspection.

## Note on freshness

These sample artifacts capture a specific point in time (the date in `created_at` / `issued_at`). They are not auto-refreshed. If the wire format or schema changes, run `./scripts/smoke-e2e.sh` and copy the new outputs over the files here. See the `## How to regenerate` block above.
