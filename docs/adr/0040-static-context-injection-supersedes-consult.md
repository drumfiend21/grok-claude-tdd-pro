# ADR-0040 — Static context injection for the planner; SUPERSEDES ADR-0039 (TICKET-035)

- **Status:** Accepted
- **Date:** 2026-06-06
- **Deciders:** drumfiend21 (architect; brought in a second-opinion review of TICKET-034 immediately after merge) + adversarial reviewer (the second voice, recorded below) + Claude (cloud session, implementer).
- **Second voice (per ADR-0029 pattern; 10th application):** A separate review of ADR-0039 / TICKET-034 the operator commissioned after the consult mechanism merged. The reviewer's literal closing position: *"Right diagnosis, wrong prescription. Static context injection at session start solves the same problem with no new orchestration, no new schema, no round-trip cost, no coupling increase. Draft that instead."* The reviewer named the project's recurring failure mode as "framework-itis" and argued that TICKET-034 added orchestration, coupling, and complexity tax to solve a problem addressable with static context. The plugin upstream subsequently shipped `docs/PROJECT_CONTEXT_FOR_PLANNER.md` (at `b3e17c0`) and ADR-0006 — confirming the static-context approach as the upstream-blessed mechanism.
- **Trigger:** Two-step. (1) The same-session adversarial review of TICKET-034 named four substantive problems with the consult mechanism (framework-itis, static-vs-dynamic data mismatch, coupling cost, unfalsifiable success criterion). (2) The plugin upstream landed the static-context publication contract (`docs/PROJECT_CONTEXT_FOR_PLANNER.md` + plugin-side ADR-0006) at `b3e17c0`, making the simpler mechanism real rather than hypothetical.
- **Supersedes:** ADR-0039 (architecture-consult phase). The consult template, schema, and decomposition-input requirement are deprecated as of this CL; the artifacts remain in the tree per Nygard append-only convention but carry SUPERSEDED markers pointing here.
- **Extends:** ADR-0007 (sync-plugin / R-2 versioned consumption — the static context is consumed via the same pin mechanism); ADR-0025 (pin bump precedent — activating this work requires bumping `23e5c2b` → a commit that includes `PROJECT_CONTEXT_FOR_PLANNER.md`); ADR-0029 (`Second voice` field — 10th application).

## Context

ADR-0039 / TICKET-034 shipped a per-feature `architecture-consult.md` round-trip from Grok → Claude-TDD-Pro to close the "blind decomposition" gap (the outer-loop planner was sizing tickets without consulting the inner-loop's test-shape / refactor-sequencing / portability knowledge). The mechanism was correct in diagnosis: Grok WAS decomposing blind.

The adversarial review surfaced four substantive issues:

1. **Framework-itis.** TICKET-034 added a new template, new handoff type, new schema, new mandatory step, new ADR, new evals — eight artifacts and a per-feature round-trip to solve a knowledge-gap problem. This is the opposite direction of every prior review's "simplify ruthlessly" guidance.
2. **Static vs dynamic data mismatch.** Test-shape discipline, refactoring sequencing, mutation seams, ADR triggers, Bash 3.2 portability — these are static properties of `claude-tdd-pro`, not properties of any given feature. They change roughly once per quarter when the architecture evolves. A per-feature consult is dynamic dispatch for static data.
3. **Coupling cost.** The consult schema locks the two repos in step. Every contract change becomes a cross-repo CL. Sam Newman's bounded-context guidance specifically warns against this.
4. **Unfalsifiable success criterion.** "Evals confirm improved ticket quality (fewer mid-ticket expansions)" — measured how, against what baseline? Without a controlled comparison this self-reinforces.

The plugin upstream then made the simpler approach concrete by publishing `docs/PROJECT_CONTEXT_FOR_PLANNER.md` (the static knowledge surface) + ADR-0006 (the upstream decision to publish it). The harness side now has a real artifact to consume rather than a hypothetical proposal.

## Decision

### 1. Replace the per-feature consult with static context injection

`scripts/sync-plugin.sh --ensure` copies `docs/PROJECT_CONTEXT_FOR_PLANNER.md` from the pinned plugin cache into `.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md` (gitignored runtime artifact). The injection runs once per session (alongside the cursor-rules generation and the existing skill symlinks). Grok reads the file from its known location when planning; no per-feature round-trip.

### 2. Defensive activation pending pin bump

The current pin (`23e5c2b`) predates `PROJECT_CONTEXT_FOR_PLANNER.md`. The injection step is defensive: copies if present, logs `not present at this pin (defer to pin bump per ADR-0040)` otherwise. This lets the harness side ship the wire NOW without waiting for the pin bump.

The pin bump itself is a separate CL (precedent: ADR-0025) requiring its own ADR documenting the tested upgrade. Trigger: this CL merging → next planning session → operator-bitten signal that the wire is real-but-inert → bump.

### 3. Supersede ADR-0039 artifacts (Nygard append-only)

The consult template (`.grok/templates/architecture-consult.md`), the handoff-contract section (`docs/handoff-contract.md §Architecture-Consult`), and the decomposition input variable that required the consult — all carry SUPERSEDED markers pointing here, but the bodies remain in the tree. Nygard's append-only ADR convention extends to design artifacts: deletion would erase the decision trail.

The decomposition template's REQUIRED input variable for `architecture_consult` becomes OPTIONAL with a note that the static context is the primary planning input.

### 4. No new orchestration; no new schema; no per-feature round-trip

The reviewer's recommendation is honored exactly: this CL removes orchestration rather than adding it. The two-tier separation between Grok (planning) and Claude (execution) stays clean. Knowledge flows as static context, not as inter-system protocol. The two repos remain loosely coupled (Sam Newman's bounded-context discipline preserved).

## Alternatives considered

- **Keep TICKET-034 + add static context as a complement.** REJECTED. The reviewer's point about framework-itis applies: keeping the consult around alongside the simpler mechanism preserves the complexity tax. SUPERSEDED markers + Nygard append-only is the right factoring.
- **Hard-delete the consult artifacts.** REJECTED per Nygard append-only convention. The decision trail (and the reviewer's argument for why) becomes invisible if the artifacts are gone.
- **Embed the static context in `CLAUDE.md` directly (no plugin file).** REJECTED. The static context is plugin-owned knowledge (claude-tdd-pro's design discipline), not harness-owned. R-2 versioned consumption requires the source-of-truth lives in the plugin.
- **Vendor `PROJECT_CONTEXT_FOR_PLANNER.md` into the harness tree.** REJECTED per R-2 (no vendoring). The harness consumes via the pinned cache.
- **Wait for the pin bump before shipping the harness-side wire.** REJECTED. The wire is defensive; shipping it now means the pin bump is a smaller follow-on CL (just the pin change), not a big mechanism-shipping CL.
- **Combine the supersession + pin bump in one CL.** REJECTED for clarity. The supersession is a structural decision; the pin bump is a contract-surface decision. Separating them keeps each CL focused on one concern.
- **Run with both mechanisms in parallel for two weeks to compare** (the reviewer's "after two weeks ... if still weak ... revisit"). REJECTED. The cost of running the consult mechanism (orchestration + token + maintenance) exceeds the value of the comparison data. The reviewer's argument already provides the rationale; no need to A/B test it.

## Consequences

### Positive

- **Framework-itis closed.** No new template invocation per feature; no new schema to maintain; no per-feature round-trip to cache; no new ADR-shaped contract.
- **Coupling reduced.** The two repos communicate via the existing pin mechanism + a single static file; no consult schema lock-step.
- **Operator experience cleaner.** Decomposition runs the same way it did pre-TICKET-034 (research → decomposition → dispatch); the planner now has static context as a known input but is no longer blocked on a consult artifact.
- **Token / latency cost is zero per feature.** The static context is loaded once per session; subsequent decompositions reference it without round-trips.
- **R-2 versioned consumption honored.** The static context is plugin-owned, consumed via the pinned cache, refreshed on `sync-plugin.sh --ensure`. The harness doesn't duplicate the content.
- **10th application of the `Second voice` field per ADR-0029.** The adversarial reviewer IS the second voice; this ADR quotes the reviewer's closing position verbatim.
- **Falsifiable.** If the static context doesn't measurably improve decomposition (per the reviewer's two-week trial), the file is deleted and we're back where we started in one CL. No protocol to roll back.
- **Cross-repo ADR pairing.** Plugin-side ADR-0006 (publish static context for external planners) + harness-side ADR-0040 (consume the contract) together record the same decision at the two repos' boundaries.

### Negative

- **TICKET-034's work is partially deprecated.** Mitigation: Nygard append-only preserves the artifacts + the ADR; the supersession trail is the decision record. The dispatch template's `applicable_rules` improvement from TICKET-033.a is retained (that work is orthogonal to the consult mechanism).
- **Activation requires a pin bump.** Mitigation: the wire ships now defensively; the pin bump is a smaller follow-on CL. The defensive log line is operator-visible so the lag is not silent.
- **Static context can only capture what is stable.** Truly feature-specific architectural decisions still belong in the research bundle. Mitigation: the reviewer explicitly named this; the static context is for static knowledge, the research bundle for dynamic data.
- **The reviewer's "framework-itis" framing now applies retroactively to multiple prior CLs.** Mitigation: this ADR's SUPERSEDES + the §Out-of-scope section flag candidates for future simplification review. Not a regression-blocker; a backlog signal.

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **Plugin pin unchanged in this CL** (pin bump is the follow-on CL).
- **Wire-format `schema_version` unchanged.**
- **The 28-rule standards-pipeline wire (TICKETS 032 + 033 + 033.a) is unaffected.** The supersession is scoped to the planning-layer consult; the standards / rubric / formatters / AIBOM stay shipped.

## Verification (executed before commit)

- `./scripts/sync-plugin.sh --ensure` emits `context : PROJECT_CONTEXT_FOR_PLANNER.md not present at this pin (defer to pin bump per ADR-0040)` — confirms defensive wire works.
- `./tests/test-all.sh --quiet` passes (no test changes; the wire is additive).
- Full audit chain green.
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- SUPERSEDED markers at the top of:
  - `.grok/templates/architecture-consult.md`
  - `docs/handoff-contract.md §Architecture-Consult`
  - `.grok/templates/decomposition.md` (the `architecture_consult` input variable note).
- ADR-0040 follows the numbered template + `Second voice` field present (10th application).

## Out of scope (named follow-ons)

- **Pin bump CL.** TRIGGER FIRED at this CL's merge; next CL bumps `23e5c2b` → a commit including `PROJECT_CONTEXT_FOR_PLANNER.md`. Separate ADR per architecture-principles §15 (precedent: ADR-0025).
- **Decomposition template hardening to actually READ the static context.** DEFERRED to the pin-bump CL. The wire writes the file; the template needs to instruct Grok to consult it. This is a documentation/prompt change, not substrate.
- **Retroactive simplification review of prior CLs** flagged by the reviewer's framework-itis lens. DEFERRED to a future "deletion pass" CL. Trigger: operator signals readiness for that pass (matches the ADR-0033 Musk #1 trigger pattern).
- **Two-week trial measurement** the reviewer proposed (controlled comparison of decomposition quality). DEFERRED to operator-initiated. Trigger: operator decides to instrument decomposition output for the measurement.

## Implementation references

- Modified: `scripts/sync-plugin.sh` (defensive copy of `PROJECT_CONTEXT_FOR_PLANNER.md` into `.harness/context/`)
- Modified: `.gitignore` (excludes `.harness/context/`; updates `.harness/cache/` comment to reflect supersession)
- Modified: `.grok/templates/architecture-consult.md` (SUPERSEDED marker at top)
- Modified: `.grok/templates/decomposition.md` (`architecture_consult` input variable demoted from REQUIRED to OPTIONAL; SUPERSEDED note)
- Modified: `docs/handoff-contract.md` (§Architecture-Consult carries SUPERSEDED marker)
- Modified: `AGENTS.md §6` (template enumeration update)
- Modified: `scripts/export-cursor-rules.sh` (template list update)
- Modified: `.cursor/rules/*.mdc` (regenerated)
- Modified: `AUTOMATION_INTEL.md` (2026-06-06 reversal entry)
- Modified: `TICKETS.md` (TICKET-035 row marked DONE; TICKET-034 retroactively marked SUPERSEDED)
- New: this ADR
- Related: ADR-0007 (sync-plugin / R-2 versioned consumption), ADR-0025 (pin bump precedent — pin bump CL is the follow-on), ADR-0029 (`Second voice` field — 10th application; adversarial reviewer IS the second voice), ADR-0039 (the SUPERSEDED architecture-consult phase), claude-tdd-pro upstream ADR-0006 (the paired upstream decision; published `PROJECT_CONTEXT_FOR_PLANNER.md`).
