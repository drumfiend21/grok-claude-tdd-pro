# ADR-0032 — Cross-reference audit (Fowler #3 closure) (TICKET-027)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 directive: *"Proceed through three focused, triggered, filter-disciplined CLs to secure A+"* — closure #3 per Kua's ordering "most invasive; defer unless concrete trigger fires") + Claude (cloud session, implementer)
- **Second voice (per ADR-0029 pattern):** Simulated Fowler+team regrade explicitly named: *"Critique #3 — single short TIER-2 note (`docs/wire-vs-authority-strictness.md` or appended to existing `researcher-discipline.md`) explicitly naming the layering"* — then for #3 specifically: *"Either ship a tool that walks the cross-reference graph + catches broken links, or refactor to one canonical authority + composable references. Estimated effort: 60+ min; structurally invasive."* The regrade explicitly offered the lighter-weight alternative (cross-reference graph tool); this CL ships exactly that. Third application of the `Second voice` field.
- **Trigger:** Closes Fowler critique #3 ("TIER hierarchy strong coupling between docs") per the architect's explicit 2026-05-26 directive to secure A+. The lighter-weight closure (cross-reference audit tool) is chosen over the full TIER-hierarchy refactor per §Decision-1.
- **Supersedes:** none
- **Extends:** ADR-0028 (substrate-script test discipline — pattern this CL follows); ADR-0029 (regrade-driven closure + `Second voice` field — third application); ADR-0031 (audit-tool pattern that this CL mirrors for cross-references)

## Context

The simulated Fowler+team regrade identified critique #3 with two closure options:

> *"Either (a) ship a tool that walks the cross-reference graph + catches broken links, or (b) refactor to one canonical authority + composable references. Estimated effort: 60+ min; structurally invasive."*

The architect's 2026-05-26 directive then triggered the closure: *"Proceed through three focused, triggered, filter-disciplined CLs to secure A+."*

The full canonical-authority refactor (option b) would touch CLAUDE.md, AGENTS.md, the founder-directives §5 authority table, and likely every TIER-2 rulebook's cross-references — a structural change at TIER-1 scope. Per the over-engineering filter:

- **Operator-bitten?** Partially — Fowler's critique is real but no concrete amendment has demonstrated the cost yet.
- **Composes on existing primitives?** Refactor would create new primitives, not compose.
- **R-3 risk?** High — restructuring authority surfaces with 30+ ADRs all citing the existing structure.
- **Maintenance cost?** Real — every existing ADR/doc would need cross-reference updates.
- **Deletion-pass survives?** YES — the existing hierarchy works; refactor would be aspirational architectural improvement, not bug fix.

The audit-tool approach (option a) is the disciplined choice: closes Fowler #3 by making the coupling cost detectable (broken cross-references surface immediately), without restructuring the authority hierarchy that's actually working. If the cost ever bites concretely (an amendment requires manual graph-walking), THAT becomes the trigger for the refactor.

Three design questions:

1. **Audit-tool or full refactor?**
2. **What's the false-positive handling strategy?** (Template placeholders + runtime artifacts + §Alternatives-block refs in ADRs are operator-visible but not actionable.)
3. **What exit-code semantics?** (Pure-detect mode would always exit 1 with the existing 24 findings; approval-baseline mode exits 0 unless NEW refs break.)

## Decision

### 1. Ship the audit-tool (option a); defer the canonical-authority refactor (option b) per the filter

`scripts/audit-cross-references.sh` walks every TIER-1/TIER-2 markdown file + AGENTS.md / CLAUDE.md / QUICKSTART.md / README.md / TICKETS.md / AUTOMATION_INTEL.md / orchestrating-swarms SKILL.md + tests/README.md. Extracts path-like references via two conservative grep patterns:

- Markdown link syntax: `[label](path)` where path starts with a known directory prefix
- Inline-code paths: `` `path.ext` `` where extension is .md / .sh / .mdc / .json / .yaml / .yml

Asserts every extracted path exists on disk. Reports findings.

The full canonical-authority refactor is **explicitly deferred** with the trigger: "a future TIER amendment requires manual cross-reference walking that demonstrates the coupling cost concretely." Until that trigger fires, the audit-tool catches the cost (broken refs) without restructuring the hierarchy.

### 2. Filter template-placeholders + runtime-artifacts; preserve §Alternatives-block refs via approval-testing baseline

Template patterns filtered (these are documentation tokens, not broken references):

- `<...>` placeholders (e.g., `<ticket-id>`, `<name>`)
- `{...}` brace expansions (e.g., `{req,res}.json`, `{research,decomposition,dispatch}.md`)
- `...` ellipsis placeholders
- `TICKET-NNN`, `TICKET-DEMO`, `NNN-<slug>` token placeholders
- `.harness/` paths (gitignored runtime artifacts; exist transiently)

References inside ADR §Alternatives + §Out-of-scope blocks (naming REJECTED or DEFERRED targets) are NOT filtered at the regex level because they're path-shaped and indistinguishable from legitimate references. They're handled via the approval-testing baseline (§Decision-3).

### 3. Approval-testing baseline pattern (`tests/cross-references-baseline.txt`)

Per Fowler's published guidance on approval testing: the audit's first run captures the current state as a baseline; subsequent runs detect only NEW broken refs (regressions). Existing baseline entries acknowledge legacy known-broken refs (mostly ADR §Alternatives entries documenting REJECTED items, plus future-dated placeholder filenames).

Exit code:

- **0** — no broken refs OR all broken refs accounted for in baseline.
- **1** — NEW broken refs introduced since baseline (regression).
- **2** — script invocation error.

Approval-testing pattern means the audit is **non-blocking for legacy debt** but **strict for regressions**. New PRs can't introduce new broken references; existing legacy entries can be cleaned up in future CLs that shrink the baseline (the audit's output explicitly suggests baseline shrinkage when findings reduce).

Baseline file:

- 24 entries captured at TICKET-027 / 2026-05-26.
- Each entry is `path/to/source.md references missing path: target/path`.
- Sorted; one per line.
- Tracked in git as part of the test infrastructure.
- Maintained by hand (no `--update-baseline` mode at v1 per D-8; future TICKET if operationally bitten).

## Alternatives considered (over-engineering filter applied to each)

- **Option b — Full canonical-authority refactor.** REJECTED per Decision-1. High R-3 risk; 30+ ADR cross-references need updates; structurally invasive at TIER-1 scope. Trigger to un-defer: a TIER amendment requires manual graph-walking that demonstrates coupling cost.
- **Pure-detect mode (exit 1 on any broken ref).** REJECTED. Would always fail on the 24 legacy entries; would require fixing 24 unrelated items in this CL or pre-committing to fix them; both violate the filter.
- **Auto-fix mode** (rewrite broken refs to nearest match). REJECTED per D-12. Auto-rewriting authority-surface references would be reckless.
- **Skip the test for the audit script.** REJECTED per ADR-0028 substrate-test-discipline precedent.
- **Aggressive false-positive filter** that also excludes ADR §Alternatives blocks structurally. REJECTED. Markdown headings don't reliably indicate semantic block boundaries; baseline pattern is more honest.
- **Cross-reference DIRECTED GRAPH analysis** (find cycles, deepest dependencies, etc.). REJECTED per D-13. The minimum-viable closure is broken-link detection; graph-theoretic analysis is over-engineering.
- **`--update-baseline` mode** to mechanically regenerate the baseline file. REJECTED per D-8. Manual baseline maintenance keeps the operator in the loop; mechanical update would let regressions slip in silently.
- **Re-running this audit on every CI push (when CI exists).** ACCEPTED as future scope; today the audit is in `tests/test-all.sh --quiet` so the test discipline picks it up via the existing pre-commit honor system.

## Consequences

### Positive

- **Fowler critique #3 closed via the lighter-weight option.** Coupling cost is now detectable; regression-prevention is structural.
- **Approval-testing baseline pattern documented.** Future audit scripts can adopt the same pattern when legacy debt is non-zero.
- **24 legacy known-broken refs are visible in `tests/cross-references-baseline.txt`.** Future CLs can shrink the baseline; the file IS the technical-debt registry for cross-reference hygiene.
- **`scripts/audit-cross-references.sh` is reusable.** Re-runnable on any commit; the baseline-vs-current diff is computed every run.
- **Coverage table extended to 11/11 surfaces.** `tests/test-audit-cross-references.sh` (8 assertions) follows ADR-0028 + ADR-0031 pattern.
- **Canonical-authority refactor is NOT shipped.** Per filter discipline — would be aspirational refactor without operationally-bitten trigger. Deferred with named trigger.
- **D-12 honored.** Honest: 24 known-broken refs; baseline records them; future cleanup is incremental.
- **D-8 honored.** 8 alternatives REJECTED with rationale.
- **All three A+ CLs (TICKET-025, TICKET-026, TICKET-027) ship without architectural drift.** §1 byte-identical across all three; D-rule count unchanged.

### Negative

- **24 legacy broken refs persist.** The baseline acknowledges them but doesn't fix them. Most are §Alternatives-block refs in ADRs naming REJECTED items (per Nygard append-only, those ADRs can't be amended). Some are real cleanup opportunities (e.g., `scripts/audit-metrics.sh` references in AUTOMATION_INTEL + TICKETS).
- **Baseline file requires manual maintenance.** Operator must update when refs get fixed. Mitigation: the audit explicitly suggests baseline shrinkage when findings reduce.
- **Audit relies on conservative regex patterns; may miss some path-like references.** Specifically: only `[label](path)` markdown link syntax + `` `path.ext` `` inline-code patterns are scanned. References inside prose ("see scripts/foo.sh") without markdown wrapping are not detected. Mitigation: acceptable v1 scope; broader detection is deferred-future-ADR.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **R-/G-/C-rule bodies untouched.**
- **TIER hierarchy itself unchanged** (Decision-1: no refactor).
- **AGENTS.md / CLAUDE.md / QUICKSTART untouched in this CL** (the audit is substrate; doesn't touch entry-point routing).
- **`.cursor/rules/` untouched** (no new authority surface).
- **Wire-format `schema_version` unchanged.**

## Verification (executed before commit)

- `bash -n scripts/audit-cross-references.sh` clean.
- `bash -n tests/test-audit-cross-references.sh` clean.
- `./scripts/audit-cross-references.sh --quiet` exits 0 (baseline matched).
- `./scripts/audit-cross-references.sh` shows "0 new vs baseline" + "OK — all 24 finding(s) accounted for in baseline."
- Injecting a new broken ref triggers exit 1 with "[NEW]" prefix (test 5 of `tests/test-audit-cross-references.sh`).
- `./tests/test-audit-cross-references.sh` exits 0 with 8/8 passing.
- `./tests/test-all.sh --quiet` shows 11/11 suites now passing (was 10/10 pre-CL).
- Full audit chain: audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest all exit 0.
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- `tests/cross-references-baseline.txt` exists with 24 entries.
- ADR-0032 follows numbered ADR template + `Second voice` field present (third application).

## Out of scope (deferred per filter)

- **Canonical-authority refactor** (option b). Trigger to un-defer: a TIER amendment requires manual cross-reference graph-walking that demonstrates coupling cost concretely.
- **`--update-baseline` mode.** Trigger: manual baseline maintenance proves too error-prone in practice.
- **Cross-reference directed-graph analysis** (cycles, depth, etc.). Trigger: a real graph-pattern bug surfaces.
- **Broader detection** (prose references, comment references, code-string references). Trigger: a real broken ref slips past the conservative patterns.
- **CI integration** (runs on every push). Same trigger as the broader CI deferral per ADR-0028 §Out-of-scope.
- **Shrinking the 24-entry baseline.** Each entry has different deferral rationale; future per-entry-class CLs (e.g., "clean up §Alternatives refs in shipped ADRs via supersession"; "remove scripts/audit-metrics.sh references in operator-visible surfaces") shrink the baseline.

## Implementation references

- New: `scripts/audit-cross-references.sh` (bash 3.2 + BSD portable; conservative regex patterns; approval-baseline pattern; ~120 lines)
- New: `tests/cross-references-baseline.txt` (24 entries; tracked in git as test infrastructure)
- New: `tests/test-audit-cross-references.sh` (8 assertions; ADR-0028 pattern)
- Modified: `tests/README.md` (coverage table 11/11 surfaces)
- Modified: `TICKETS.md` (TICKET-027 row marked DONE)
- New: this ADR
- Related: ADR-0028 (substrate-test discipline — pattern), ADR-0029 (Second voice field — third application), ADR-0030/0031 (preceding A+ CLs), `docs/architecture-principles.md §19` (ADR amendment process this audit catches the cost of).
