# <!-- TICKET-NNN: short imperative -->

## Summary

<!-- One paragraph: what this CL does and why. Cite the ticket + the ADR
     that authorizes the change. -->

## Relevant rules / decisions

- Ticket: TICKET-NNN
- ADR(s): docs/adr/NNNN-*.md
- TIER-2 rulebook touched (if any):

## Verification (executed before pushing)

- [ ] `./tests/test-all.sh --quiet` → 18/18 PASS
- [ ] `./scripts/audit-doc-drift.sh` → no drift
- [ ] `./scripts/audit-cross-references.sh --quiet` → exit 0
- [ ] `./scripts/audit-hook-security.sh --quiet` → exit 0
- [ ] `./scripts/audit-plugin-surface.sh --quiet` → exit 0
- [ ] `./scripts/audit-standards-conformance.sh --quiet` → exit 0
- [ ] `./scripts/audit-manifest.sh` → all manifests valid
- [ ] `./scripts/audit-metrics.sh --quiet` → exit 0
- [ ] `./scripts/audit-claude-code-compat.sh --quiet` → exit 0
- [ ] `./scripts/smoke-e2e.sh` → green; 5 audit artifacts emit
- [ ] `git diff docs/founder-directives.md` → 0 lines (D-6 honored)

## What this CL does NOT do

<!-- Named deferrals. Per the standing over-engineering filter, every
     proposed scope expansion that was rejected should be named here with
     a trigger condition that would re-open it. -->

## Out-of-scope (deferred per filter)

- ...

## Files touched

<!-- Summary by directory / surface. Flag any TIER-0/1/2 rulebook bodies,
     ADR bodies, or persisted Claude Code instructions touched (those are
     forbidden unless the PR is itself an amendment ADR). -->
