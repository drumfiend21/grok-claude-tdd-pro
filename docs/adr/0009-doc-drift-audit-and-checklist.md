# ADR-0009 — Doc-drift audit script + §4 checklist amendment

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, "ensure the same types of drift don't happen again" instruction) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0007 (whose "Implementation references" list omitted `docs/plugin-sync.md` — that omission is the proximate cause this ADR exists to prevent)

## Context

The TICKET-006.a drift audit found six P0/P1 items where operator-facing documentation lagged behind the implementation across TICKETS 003–006:

| ID | Surface | Description |
|---|---|---|
| F-1 | `README.md §Status` | "Design-only. No code yet." persisted after six tickets shipped |
| F-2 | `README.md` line 32 | "Wiring is defined in TICKET-004" persisted in future tense after TICKET-004 done |
| F-3 | `scripts/sync-plugin.sh --help` | `--ensure` mode added by ADR-0007 was implemented but absent from the help comment block |
| F-4 | `docs/plugin-sync.md` lines 19-20 | Same `--ensure` mode absent from the operator runbook; the SessionStart hook description named only `--check` |
| F-5 | `docs/skill-consumption.md` | Orphan stub "filled in by TICKET-004" persisted after TICKET-004 shipped |
| F-7 | `docs/architecture.md §"Handoff contract"` | Duplicated a stale partial copy of the handoff schema (an R-3 violation) and used future tense for TICKET-002 |

All six were closed by TICKET-006.a. But the audit revealed a uniform root cause: **every shipping CL judged completion by "does the feature work?" without ever asking "is the full operator-facing surface consistent with the new state?"** Each CL was technically green on the existing checklists (architectural §17, founder-directives §4, Grok §16, Claude TDD Pro §17) yet still shipped drift. The existing checklists ask about D-rules, R-rules, G-rules, C-rules — but no checklist asked about *downstream operator docs*.

This is **D-13's "trust-then-verify gap"** failure pattern in concrete form: the implementer trusts that their internal capture of the change (the ADR's "Updated:" list, their own working memory) is complete, without verifying by reading the actual downstream docs that describe the changed surface.

The drift rate was high: six items across roughly five CLs is ~1 per CL. At this rate, by the time TICKET-010 lands, the harness would accumulate ~10+ untracked drift items — enough to seriously corrode the "production-grade trust" value proposition (D-12).

## Decision

Three-layer prevention:

### 1. Mechanical — `scripts/audit-doc-drift.sh`

A standalone bash script that catches the four most common drift patterns automatically:

- **F-1 (stale stubs):** Grep all `*.md` files for `"stub — filled in by TICKET-NNN"` markers. For each match, parse the ticket-id and cross-reference TICKETS.md; if the ticket is `**DONE`, emit a finding.
- **F-2 (stale README framing):** Grep `README.md` for `"No code yet"` or `"Design-only"`. Emit a finding on any match.
- **F-3 (future tense for done tickets):** Grep all `*.md` files for `"lands in TICKET-NNN"`, `"will land in TICKET-NNN"`, `"will be defined in TICKET-NNN"`, etc. For each match, cross-reference TICKETS.md; if DONE, emit a finding.
- **F-4 (sync-plugin.sh mode parity):** Extract the `--FLAG` arms from `scripts/sync-plugin.sh`'s `case` block AND from its `--help` output. Diff. Emit findings on either-direction mismatches.

The script exits 0 clean / 1 on findings. It is NOT wired to the SessionStart hook (would bloat startup; doc-drift is a pre-commit concern). It runs manually from the operator/agent's pre-commit workflow.

Excluded paths: `.git/` (commit messages legitimately quote drift evidence), `docs/adr/` (ADRs are historical records; future-tense references to then-future tickets are correct), `TICKETS.md` itself (the ticket ledger is the source of truth for ticket status), and the audit script itself (it documents its own patterns).

### 2. Procedural — `docs/founder-directives.md §4` new item Q-DOC-DRIFT

A new pre-commit checklist item added under joint D-12 + D-13 authority:

> **(D-12 + D-13, Q-DOC-DRIFT) Operator-visible surface consistency.** If this CL changes any operator-visible surface — CLI flag, help text, JSON schema, hook, setting, README claim, example invariant, or any doc that describes the surface — every downstream operator-facing doc has been updated to match in this same CL. Verified by `./scripts/audit-doc-drift.sh` exiting 0 (or by inspection if the script's four pattern checks do not apply to this CL's surface).

The procedural item is what makes operators/agents actually run the audit. It is also the catch-all for drift patterns the script does not yet cover (e.g., F-5 orphan stubs that the implementer remembered to delete; F-7 schema duplication for documents other than `sync-plugin.sh`).

### 3. Structural — this ADR

Captures the lesson durably so future maintainers see the WHY when reading the script or the §4 item. Pairs with ADR-0007 (whose omission is the case study).

## Alternatives considered

- **Add as a SessionStart hook check.** Rejected: bloats every session start with a doc-audit that is not a session-aliveness concern. The plugin-sync check belongs in SessionStart (cache must exist for skills to load); doc-drift does not.
- **Add as a git pre-commit hook in `.git/hooks/pre-commit`.** Rejected: `.git/hooks/` is not portable across clones, is not respected by cloud sessions, and is enabled per-machine. The procedural §4 item achieves the same outcome with broader reach.
- **Add as a new D-rule (D-14).** Rejected: D-rules require formal §1 provenance from a named external source. This corrective is process refinement derived from this repo's own audit history, not from a new founder source. It belongs as a §4 checklist item under the existing D-12 + D-13 authority, not as a standalone D-rule.
- **More aggressive patterns** (e.g., generic schema-duplication detection across all docs, all-files cross-reference). Rejected: high false-positive rate (e.g., illustrative JSON snippets in tutorials would trigger), low marginal value over the four targeted patterns. The four patterns ship here cover all six TICKET-006.a findings.
- **Adopt to architecture-principles §17 instead of founder-directives §4.** Rejected: §17 items are R-rule referenced; this corrective is not R-rule scoped. §4 is TIER 1 and reaches every author of every CL.
- **Author the patterns as a generic linter.** Rejected: Musk's Algorithm step 2 (delete before optimize). A 140-line bash script with four specific checks beats a generic linter that requires configuration files, plugin architecture, and a dependency.

## Consequences

### Positive

- **Drift rate should drop.** All four patterns observed in the TICKET-006.a audit are now mechanically caught.
- **Pre-commit checklist explicitly asks the right question.** The Q-DOC-DRIFT item is the procedural equivalent of "did you read your own README after this CL?"
- **Audit runs in <100ms.** No latency cost worth measuring; can be wired to any pre-commit hook a future operator wants.
- **Script lives at the same layer as `sync-plugin.sh`.** Operator-facing CLI surface for both drift detection (plugin pin) and drift detection (doc consistency) is uniform: `scripts/<verb>.sh [--check|--ensure|--quiet]` and `scripts/audit-doc-drift.sh [--quiet]`.
- **F-1/F-2/F-3/F-4 regressions are now exit-1 errors.** A future CL that re-introduces any of these patterns fails the audit when the author/agent runs it.

### Negative

- **Check #4 (sync-plugin.sh parity) is specific to one script.** If other scripts gain `--flag/--help` surfaces, the check needs duplication (or generalization). Acceptable for now — sync-plugin.sh is the only such script in the harness. When `smoke-e2e.sh` gains its `--real-claude` flag per ADR-0008's deferred-work list, the check should generalize.
- **TICKETS.md parsing is brittle to format changes.** The script greps for `^| TICKET-` and `\*\*DONE`. If the ledger format changes (e.g., to YAML), the script breaks. Mitigation: the ledger format has been stable across six CLs; any reformat would itself be a substantive CL that updates the audit script.
- **The script catches the patterns we already saw, not patterns we haven't seen.** New drift classes won't be caught until they are added. Mitigation: Q-DOC-DRIFT's "or by inspection" clause covers anything outside the script's scope; future drift classes get added to the script when observed.
- **False-negative on stub-status pattern.** If a future doc says `"will be filled in by TICKET-NNN"` without using the exact phrase `"stub — filled in by"`, F-1 won't catch it. Mitigation: the canonical stub-marker phrase has been consistent in this repo; F-1's regex could be loosened if a variant appears.

### Neutral

- D-rule count unchanged. §1 of `docs/founder-directives.md` untouched.
- TIER-0 corpus is unaffected (corpus operates at procedural-playbook level; this is concrete-check level).
- Bash 3.2 + BSD-tool portability validated against all nine `tdd-pro-bash32-portability` gotchas + the bonus help-to-stderr rule.

## Verification (executed before commit)

- `bash -n scripts/audit-doc-drift.sh` passes.
- `./scripts/audit-doc-drift.sh` exits 0 on the post-TICKET-006.a clean state.
- Re-introducing F-1 (adding a "stub — filled in by TICKET-004" line in `docs/`): exit 1, F-1 finding emitted.
- Re-introducing F-2 (appending "No code yet" to `README.md`): exit 1, F-2 finding emitted.
- Re-introducing F-4 (adding an undocumented `--fake` mode to `sync-plugin.sh`): exit 1, F-4 finding emitted.
- All three patterns revert cleanly; baseline returns to exit 0.
- `tdd-pro-bash32-portability` 9-gotcha audit: clean. Bonus help-to-stderr rule: pass.

## Out of scope (deferred, named)

- **Generalize F-4 to any script with a `--help` derived from its own comments.** Defer until a second such script (likely `smoke-e2e.sh` with `--real-claude` per ADR-0008) exists.
- **Detect schema duplication generically (R-3 violations beyond F-7).** Hard to mechanize without false positives. Q-DOC-DRIFT's "by inspection" clause covers this manually.
- **Schema-version cross-check (handoff-contract.md `schema_version` matches what `smoke-e2e.sh` writes).** A specific R-12 backward-compat check. Defer until `schema_version` actually bumps.
- **Wire the audit into a CI workflow.** The broader CI design depends on TICKET-008 (self-healing extension); not pre-empting that here.

## Implementation references

- New: `scripts/audit-doc-drift.sh`
- Updated: `docs/founder-directives.md §4` (added Q-DOC-DRIFT item under D-12 + D-13)
- Updated: `TICKETS.md` (TICKET-006.b → DONE)
- Ticket: `TICKET-006.b` in `TICKETS.md`
- Companion ADR: `ADR-0007` (whose omission of `docs/plugin-sync.md` from "Updated:" is the case study this ADR exists to prevent)
- Related: ADR-0001 (sync-plugin.sh, the script whose mode surface the audit polices)
