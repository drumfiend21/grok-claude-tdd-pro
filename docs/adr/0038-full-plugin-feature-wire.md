# ADR-0038 — Full plugin-feature wire: peer reviews + formatters + compliance/AIBOM (TICKET-033)

- **Status:** Accepted
- **Date:** 2026-06-06
- **Deciders:** drumfiend21 (architect; 2026-06-06 directive: *"Listen, when I provide input to the harness of what I want built as a description of a feature, I need it built by the inner-loop according to the engineering rules I've already built (Google, owasp, federal government, etc) and all the other coding features built into Claude-TDD-pro need to be enforced as well as peer reviews. ... Is it working this way now between the two plugins?"*) + Claude (cloud session, implementer).
- **Second voice (per ADR-0029 pattern; 8th application):** The operator's 2026-06-06 follow-up directive asking the binary question — "Is it working this way now between the two plugins?" The honest answer was *partial*. The remaining gaps (peer reviews, formatters, compliance/AIBOM) became the trigger for this CL. The directive IS the second voice; this ADR closes the named gap.
- **Trigger:** Operator named three specific surfaces that TICKET-032 left as DECLARED-NOT-CONSUMED rationale-rows-with-no-actual-wire: `pr-corpus/` (peer reviews), `formatters/`, `compliance/`. This CL replaces the rationale with the wire.
- **Supersedes:** the rationale-only entries for `pr-corpus`, `formatters`, `compliance` in `docs/plugin-surface-consumption.md` (their CONSUMED markers were aspirational at v1; this CL backs them with real wires).
- **Extends:** ADR-0037 (standards pipeline consumption — this CL extends the PostToolUse hook + smoke-e2e with the named surfaces); ADR-0022 (PostToolUse review gate); ADR-0019 (provenance manifest — AIBOM joins as a sibling audit artifact); ADR-0029 (`Second voice` field — 8th application).

## Context

TICKET-032 / ADR-0037 wired the standards-rule registry (OWASP / Google / SLSA / etc.) end-to-end: 28 rules at session start, `applicable_rules` in the contract, PostToolUse runtime enforcement on app-code extensions, pre-commit conformance audit, deviation registry. After shipping, the operator asked the binary question — "Is it working this way now between the two plugins?" — and the honest answer was *partial*. Specifically:

- **Peer reviews** were explicitly named. The plugin's `pr-corpus/` extracts patterns from real-world PR feedback into the rubric — but the harness had no surface that distinguished "peer-review-pattern findings" from generic rubric findings, and no agent-review prompt for DEFERRED findings (which are the rubric's "needs peer review" signal).
- **`formatters/cli.sh`** existed in the plugin cache, unused. No auto-formatting fired after PostToolUse, so the harness's `lint_clean` sub-gate's first layer (rubric) had no formatter counterpart at write-time.
- **`compliance/aibom-emit.sh`** existed, unused. Every ticket produced a manifest + decision trail, but no AI Bill of Materials despite the plugin shipping the emitter.

The TICKET-032 plugin-surface-consumption registry marked these as "CONSUMED via … (planned Batch 6+)" — which was a forward-claim, not a real wire. This CL replaces the forward-claim with the actual wire.

## Decision

Ship three batches that each replace a planned-Batch claim with the real wire:

### Batch 6 — Peer-review surface via DEFERRED findings

The plugin's `rubric/runner.sh` emits findings with `"msg":"DEFERRED:..."` for rules that require agent review (`g-eng-001-design-belongs-here`, `g-eng-002-yagni`, `g-eng-006-no-bundled-refactor-and-feature`, `g-eng-007-no-reformat-with-logic`, `g-eng-008-document-public-changes`). These are the operationalization of the `pr-corpus/` pattern extraction: rules synthesized from real PR feedback that need a human-or-agent eye, not a pure detector.

The PostToolUse hook now surfaces up to 3 DEFERRED findings per touched file to stderr with a clear `[peer-review]` prefix:

```
[peer-review] DEFERRED findings on src/foo.ts (agent review required before ticket green):
  "rule":"g-eng-001-design-belongs-here","severity":"P0","file":"src/foo.ts"[..."msg":"DEFERRED: requires agent review-google-style"]
  ...
  Per TICKET-033 / ADR-0038: these findings do not block this write but must be addressed in the response trail before the ticket closes.
```

Non-blocking — the agent sees the signal and is contractually required to address it in the response trail before closing the ticket. This is the "peer review" surface the operator named: patterns extracted from real PR feedback (via `pr-corpus/`) flow through the rubric and surface as agent-review prompts at write-time.

### Batch 7 — Formatter auto-apply

After the rubric check (and only when no P0 violation was found for the touched file), the PostToolUse hook now invokes `formatters/cli.sh --file <REL_PATH> --apply` for app-code extensions. Defensive — non-fatal on error; the formatter is best-effort, not a gate.

### Batch 8 — AIBOM emit on green response

`scripts/smoke-e2e.sh` now invokes the plugin's `compliance/aibom-emit.sh` after the manifest is written. Every green ticket produces `.harness/audit/TICKET-NNN.aibom.json` alongside the existing manifest. Defensive — non-fatal on error per the same stance as the manifest emit (additive audit evidence, not a smoke gate).

### Registry update

`docs/plugin-surface-consumption.md` rows for `pr-corpus`, `formatters`, `compliance` replace their planned-Batch language with the real wire reference.

## Alternatives considered

- **Block at write-time on DEFERRED findings.** REJECTED. DEFERRED is by definition "needs agent review" — the agent IS the resolver, not the violator. Blocking would deadlock the agent on the very check that requires it. Surfacing as a stderr prompt is the correct contract.
- **Run `evals/runner.sh` after every R-G-R.** REJECTED. The plugin's evals validate the plugin's own substrate, not arbitrary application code. Running them from the harness side would be a category error.
- **Vendor a separate "harness peer-review" pattern set instead of routing through `pr-corpus`.** REJECTED per R-1/R-2 + R-3 (cite, don't duplicate). `pr-corpus/` IS the authoritative pattern source; the rubric already aggregates it.
- **Make AIBOM emit a smoke gate (fail smoke on aibom-emit failure).** REJECTED. AIBOM is additive audit evidence per the same stance as the manifest emitter (ADR-0019). Smoke gates protect the contract; AIBOM enriches the audit trail.
- **Defer `formatters/cli.sh` until a project-specific formatter config exists.** REJECTED. The plugin's `formatters/cli.sh` is config-aware — it no-ops when no formatter config is present. Wiring it now means zero behavior change on the harness's bash+markdown substrate, real auto-formatting when the harness produces app code.

## Consequences

### Positive

- **The three surfaces the operator named are no longer rationale-only.** `pr-corpus/`, `formatters/`, `compliance/` are wired with real invocations. The plugin-surface-consumption registry no longer claims forward-credit.
- **Peer-review surface materialized.** DEFERRED findings (rules synthesized from real PR feedback) reach the agent as `[peer-review]` prompts at write-time. The agent must address them in the response trail before ticket closure.
- **AIBOM as a 4th audit artifact.** Every green ticket now produces a Bill of Materials alongside the manifest + decision trail + req/res. Compliance auditors get a structured artifact, not just substrate logs.
- **Formatter auto-apply preserves code-quality gate.** When a write passes the rubric P0 check, formatter runs immediately; subsequent saves don't see unformatted code drift.
- **R-3 honored.** No duplication of plugin functionality; the harness orchestrates the plugin's existing scripts via well-defined CLI contracts.
- **8th application of the `Second voice` field per ADR-0029.** The operator's binary question is the second voice; this ADR records the honest partial answer + the wire that closes the gap.

### Negative

- **PostToolUse hook latency grows.** Each app-code edit now runs: rubric check + DEFERRED scan + formatter apply. Mitigation: rubric runs in milliseconds; formatter no-ops when no project config exists; the hook's WARN-not-FAIL stance for the formatter ensures errors don't strand a session.
- **AIBOM output is plugin-default-shaped.** The schema reflects the plugin's `compliance/aibom-emit.sh` v1 output, which may evolve. Mitigation: the harness invokes the plugin's emitter without forking it; future plugin pin bumps carry schema improvements automatically.
- **DEFERRED-findings noise floor.** Agents will see DEFERRED prompts even on otherwise-clean writes. Mitigation: capped at 3 per file per hook invocation; CLAUDE.md should be updated in a follow-on to explicitly recognize DEFERRED prompts as actionable.

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **Plugin pin unchanged** (`23e5c2b` per ADR-0025).
- **Wire-format `schema_version` unchanged** — the new fields are additive.
- **CONSUMED count in plugin-surface registry remains 11** (this CL re-grounds existing CONSUMED rows with real wires; no new CONSUMED rows added).

## Verification (executed before commit)

- `./tests/test-all.sh --quiet` shows 18/18 suites passing.
- `./scripts/smoke-e2e.sh` emits `aibom: .harness/audit/TICKET-042.aibom.json` line and the artifact exists.
- `./scripts/audit-plugin-surface.sh` exits 0; the `pr-corpus`, `formatters`, `compliance` rows now name the real wire.
- `./tests/test-post-tool-use-review-gate.sh` 8/8 passing (file-fence enforcement preserved).
- `./tests/test-hook-contracts.sh` 15/15 passing (hook payload contract preserved).
- Full audit chain green (10 audits + smoke-e2e + test-all).
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- ADR-0038 follows the numbered ADR template + `Second voice` field present (8th application).

## Out of scope (named follow-ons)

- **CLAUDE.md update to formalize DEFERRED-finding response-trail discipline.** DEFERRED to a follow-on operational CL. Trigger: first ticket where a DEFERRED finding fires.
- **AIBOM schema validation.** v1 trusts the plugin's emitter; future CL can add a `scripts/audit-aibom.sh` that validates the emitted JSON.
- **Federal Government namespace.** DEFERRED until operator pastes the URLs.
- **`evals/` consumption.** REJECTED per §Alternatives (plugin-internal validation, not appropriate for harness-side use).
- **`monitors/`, `cross-loop/`, `workflow/`, `metrics/`, `meta-eval/`, `import/`, `tui/`, etc.** Remain DECLARED-NOT-CONSUMED per `docs/plugin-surface-consumption.md` with each rationale recorded.

## Implementation references

- Modified: `.claude/hooks/post-tool-use-review-gate.sh` (Batch 6 — DEFERRED findings surfaced as `[peer-review]` prompts; Batch 7 — formatter auto-apply for app-code extensions)
- Modified: `scripts/smoke-e2e.sh` (Batch 8 — AIBOM emit on green response)
- Modified: `docs/plugin-surface-consumption.md` (rows for `pr-corpus`, `formatters`, `compliance` re-grounded with real wires)
- New: this ADR
- Related: ADR-0037 (standards pipeline consumption — this CL extends the same hook+smoke surface), ADR-0029 (`Second voice` field — 8th application), ADR-0022 (PostToolUse review gate), ADR-0019 (provenance manifest — AIBOM is a sibling audit artifact).
