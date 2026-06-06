# Standards Deviation Registry

**Authority tier:** TIER 2 (operational registry). Per TICKET-032 / ADR-0037, this append-only registry records each accepted deviation from the operator-declared standards in `.harness/rules/active.json`. Mirrors the `docs/founder-directives.md §1` immutability pattern: rows are append-only; corrections land as new rows superseding old, never as in-place edits.

**Why this exists:** The plugin's `standards/sources.yaml` declares 17 authoritative sources (OWASP, Google, SLSA, etc.) which produce 28 active rules at the time of this CL. Operator-declared rules must be enforced everywhere by default. When a genuine engineering exception applies (legacy compatibility, performance trade-off, language-feature constraint, etc.), the deviation gets recorded here with:

- Rule ID + path scope
- Specific justification
- ADR ref documenting the decision
- Expiry trigger (when the deviation should be re-evaluated)

The PostToolUse hook + the pre-commit `audit-standards-conformance.sh` block writes that violate a rule unless a matching row exists here.

## Registry format

| Rule ID | File scope (glob) | Justification | ADR | Expiry trigger |
|---|---|---|---|---|

(No deviations registered at TICKET-032 ship time. Future rows append below this line.)

## Anti-patterns

- **Adding a deviation row to silence a failing test without engineering justification.** The trail is reviewed; unjustified entries are reverted.
- **Editing an existing row.** Rows are append-only per §1 immutability convention. To correct: add a new row with explicit `Supersedes: <old-row-anchor>` note.
- **Wildcard scopes that disable a rule globally.** Deviations should be specific; a global disable means the rule isn't really declared. Open an ADR to remove the rule from `standards/sources.yaml` instead.
- **Deviations without expiry triggers.** Open-ended deviations rot. Every row has a trigger condition that re-opens the question (e.g., "when dependency X removes its eval usage", "when language version Y lands").

## Composition

- `.harness/rules/active.json` — the rule registry the deviations apply against.
- `scripts/audit-standards-conformance.sh` — the pre-commit audit that consults this registry.
- `.claude/hooks/post-tool-use-review-gate.sh` — the runtime enforcement that consults this registry.
- ADR-0037 — the design that established this registry.
