# /audit — run pre-commit doc-drift audit

## Purpose

Run the pre-commit doc-drift audit (`scripts/audit-doc-drift.sh`) and report findings. Catches five drift patterns observed in earlier audits (F-1 stale stubs, F-2 stale README framing, F-3 future-tense for DONE tickets, F-4 `sync-plugin.sh` impl-vs-help drift, F-5 `.cursor/rules/*.mdc` hand-edits or stale generator output). Exit 0 is required before every commit per the Q-DOC-DRIFT checklist item in `docs/founder-directives.md §4`.

## Inputs

None.

## Steps

1. Run `./scripts/audit-doc-drift.sh` in the terminal.
2. Capture stdout.
3. If exit 0: report `[doc-drift] OK — no drift detected.` and remind the user this is the pre-commit gate per Q-DOC-DRIFT.
4. If exit 1: list each `[doc-drift]` finding by category (F-1..F-5) and propose the fix (regenerate `.cursor/rules/*.mdc` via `/sync` for F-5; update the stale doc for F-1..F-4).

## Success criteria

- Script exits 0 before the commit lands.
- All findings (if any on initial run) are addressed in the same CL that introduces them, per Q-DOC-DRIFT.

## Composition (D-1 reverse per ADR-0013)

Wraps the existing `scripts/audit-doc-drift.sh` (TICKET-006.b / ADR-0009; F-5 added in TICKET-013 / ADR-0014). Grok analog: none — the audit is a harness-native pre-commit primitive consumed equally by Claude Code sessions and Cursor sessions.
