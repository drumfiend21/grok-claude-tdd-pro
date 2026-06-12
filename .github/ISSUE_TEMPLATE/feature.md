---
name: Feature / amendment proposal
about: Propose a new ticket, an ADR amendment, or a rulebook change
title: '[FEATURE] '
labels: enhancement
---

## What you want changed

<!-- One paragraph describing the proposed change. -->

## Why

<!-- The operator-bitten signal, the architectural gap, or the rule-precedence
     question this addresses. Avoid speculative "would be nice" proposals;
     name the trigger. -->

## Authority tier touched

- [ ] TIER 0 (`docs/ai-engineering-corpus.md` — requires highest-bar ADR)
- [ ] TIER 1 (`CLAUDE.md` or `docs/founder-directives.md` D-rule body — requires ADR; §1 provenance is immutable per D-6)
- [ ] TIER 2 (one of the operational rulebooks under `docs/`)
- [ ] No tier change (substrate / cleanup / documentation only)

## Filter check (the over-engineering gate)

Answer each:

- **Operator-bitten?** <!-- Is there an actual operator-experienced symptom this closes, or is it speculative? -->
- **Composes on existing primitives?** <!-- Reuses existing hooks/audits/contracts, or invents new orchestration? -->
- **R-3 risk?** <!-- New content paths that duplicate existing docs? -->
- **Maintenance cost?** <!-- Low / moderate / high? -->
- **Deletion-pass survives?** <!-- Would the harness be worse without this in 6 months? -->

If three or more answers point toward speculation, framework-itis, or duplication, recommend rejection.

## Proposed change

<!-- Concrete: which files, which sections, which audits get extended. -->

## Out-of-scope (named deferrals)

<!-- What this proposal explicitly does NOT do, with named triggers for each
     deferred item. Matches the pattern in `docs/adr/0034-*.md` §Out-of-scope. -->

## Related ADRs / tickets

- ADRs touched or superseded:
- Ticket(s) opened or closed:
