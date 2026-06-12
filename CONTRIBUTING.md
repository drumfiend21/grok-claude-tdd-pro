# Contributing to `grok-claude-tdd-pro`

This repo has a strict workflow discipline. Read this before opening a PR.

## The two non-negotiable rules

1. **No cross-repo edits.** `grok-claude-tdd-pro` consumes `claude-tdd-pro` as a versioned plugin (per architectural rule R-2). A change here MUST NOT require editing inside `claude-tdd-pro`. If a harness need surfaces that the plugin doesn't satisfy, file a separate amendment proposal in the plugin repo.
2. **One ticket per CL.** Ticket IDs come from `TICKETS.md`. Commit messages reference the ticket: `TICKET-NNN: <verb> <object>`.

See [`CLAUDE.md`](CLAUDE.md) for the full prime directive and [`AGENTS.md`](AGENTS.md) for the cross-tool agent-binding surface.

## Authority hierarchy

Before making any change, know which tier of authority your work touches:

- **TIER 0** — `docs/ai-engineering-corpus.md` (supreme operating directive)
- **TIER 1** — `CLAUDE.md` + `docs/founder-directives.md` (D-1..D-13)
- **TIER 2** — `docs/architecture-principles.md` (R-1..R-20), `docs/grok-orchestration-principles.md` (G-1..G-21), `docs/claude-tdd-pro-principles.md` (active C-rules), `docs/handoff-contract.md`, `docs/quality-gate.md`, and the other design docs enumerated in `AGENTS.md §5`.

When this README or any other doc conflicts with a TIER-0/1/2 source, the higher-tier source wins.

## Workflow for any non-trivial change

1. **Open or claim a ticket** in `TICKETS.md`. New tickets get the next available `TICKET-NNN` ID.
2. **Read the binding context.** At minimum: `CLAUDE.md`, the inner-loop SKILL.md trio (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`), and the relevant TIER-2 rulebook for the surface you're touching.
3. **Run the session-start ritual.** `./scripts/sync-plugin.sh --ensure` — materializes the pinned plugin cache and verifies the symlinks.
4. **Write the change under Red-Green-Refactor discipline.** Tests come first. Implementation second. Refactor third.
5. **If your change is structural** (touches the wire format, a TIER-2 rulebook body, the plugin contract surface, the pin), write an ADR per `docs/architecture-principles.md §15`. ADRs are append-only (Nygard convention) — never edit a previously-landed ADR; supersede it with a new one.
6. **Run the full audit chain pre-commit.**
   ```bash
   ./tests/test-all.sh --quiet                       # 18/18 substrate test suites
   ./scripts/audit-doc-drift.sh                      # F-1..F-6 pre-commit drift
   ./scripts/audit-cross-references.sh --quiet       # broken-ref detection
   ./scripts/audit-hook-security.sh --quiet          # S-1..S-6 CWE-mapped shell patterns
   ./scripts/audit-plugin-surface.sh --quiet         # 55 plugin surfaces declared
   ./scripts/audit-standards-conformance.sh --quiet  # rubric runner against diff
   ./scripts/audit-manifest.sh                       # provenance schema valid
   ./scripts/audit-metrics.sh --quiet                # DORA Four Keys honest reporting
   ./scripts/audit-claude-code-compat.sh --quiet     # host-CLI version in supported_range
   ./scripts/smoke-e2e.sh                            # green; 5 audit artifacts emit
   ```
   All ten must exit 0.
7. **Verify D-6** if your change touches anything under `docs/founder-directives.md`: `git diff docs/founder-directives.md` must return 0 lines. The §1 provenance entries and the §3 D-rule bodies are immutable.

## What to NOT touch

The `.claude/hooks/post-tool-use-review-gate.sh` hook blocks edits to these paths at write-time and will be enforced again at pre-commit by `audit-doc-drift.sh` F-5:

- `.harness/plugin-cache/` — generator-managed by `sync-plugin.sh`; clobbered on every ensure.
- `claude-tdd-pro/` — sibling plugin repo (R-1 cross-repo edit ban).
- `.claude/skills/tdd-pro-*` — symlinks into the pinned plugin cache.
- `.cursor/rules/*.mdc` — generator output from `scripts/export-cursor-rules.sh`; edit the generator and re-run.
- `docs/founder-directives.md §1` (provenance) and §3 (D-rule bodies) — immutable per D-6.

## Commit message format

```
TICKET-NNN: <short imperative title>

<one-paragraph rationale referencing the relevant ADR / rulebook>

Verification:
  ./tests/test-all.sh --quiet → 18/18 PASS
  All 10 audits exit 0
  git diff docs/founder-directives.md → 0 lines (D-6 honored)
```

For pure documentation cleanup or recruiter-facing polish (this branch's pattern), use the prefix `cleanup:` instead of `TICKET-NNN:`.

## Reviewing a PR

When reviewing someone else's work, walk the [`docs/founder-directives.md §4`](docs/founder-directives.md) pre-commit checklist and the [`docs/architecture-principles.md §17`](docs/architecture-principles.md) self-audit checklist. Comment on any rule the PR doesn't honor.

## Where decisions live

- `docs/adr/` — 41 numbered architecture decision records. Append-only; supersession via new ADR with explicit `SUPERSEDES:` field.
- `AUTOMATION_INTEL.md` — append-only intel log; dated entries that are immutable once landed.
- `CHANGELOG.md` — milestone summary; references TICKETS and ADRs.
- `TICKETS.md` — backlog and DONE log.

## Questions or unclear cases

Open an issue using `.github/ISSUE_TEMPLATE/feature.md` (proposed change) or `.github/ISSUE_TEMPLATE/bug.md` (regression suspected). For security concerns, see [`SECURITY.md`](SECURITY.md).
