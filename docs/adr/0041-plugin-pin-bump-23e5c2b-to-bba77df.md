# ADR-0041 — Plugin pin bump `23e5c2b` → `bba77df`: activates ADR-0040 static-context wire + declares 16 new plugin surfaces (TICKET-036)

- **Status:** Accepted
- **Date:** 2026-06-07
- **Deciders:** drumfiend21 (architect; reviewed the diff between pins via the harness's session-start `contract: 2 file(s) drifted` gate + a hand-walked check of the plugin-surface delta) + adversarial reviewer from the prior CL (confirmed activation is the next step in the static-context plan) + Claude (cloud session, implementer).
- **Second voice (per ADR-0029 pattern; 11th application):** The adversarial reviewer's prior closing position carried forward: *"The system reaches ready state for AI-assisted software development at the end of Step 2 (the pin bump)."* The pin bump IS the activation step the reviewer named; this ADR records it landing.
- **Trigger:** ADR-0040 §Out-of-scope explicitly named the pin bump as the activation CL. The wire shipped in TICKET-035 was inert pending this bump.
- **Supersedes:** the pin in `docs/claude-tdd-pro.lock.yaml` (`23e5c2b78ffe170ef875067edd14cd950c19e7b5` → `bba77dfacb5be0cb31c8bea712b98fadb8618ea0`) and the corresponding contract-surface hashes for `CLAUDE.md` and `docs/architecture-v1.9.md`.
- **Extends:** ADR-0025 (pin bump precedent — same mechanism, same `architecture-principles §15` discipline); ADR-0040 (the wire this bump activates); plugin-side ADR-0006 (the paired publication of `PROJECT_CONTEXT_FOR_PLANNER.md` consumed by this bump); ADR-0037 (plugin-surface declaration registry — extended with 16 new entries this CL).

## Context

ADR-0040 / TICKET-035 shipped the harness-side wire for static planner-context injection but deliberately deferred activation to a subsequent CL pending a contract-surface review. The current session brought that review and the bump together once the prior reconciliation noted readiness.

### Diff review (the safety gate)

Comparing `23e5c2b..bba77df` in the upstream plugin:

| Surface class | Result |
|---|---|
| **Contract-surface files** (in `docs/claude-tdd-pro.lock.yaml`) | 2 files changed: `CLAUDE.md` (1-line bullet addition pointing at `feedback-cl-build-orchestrator.md`) and `docs/architecture-v1.9.md` (101-line additive §26 v1.11 amendment block introducing R-8, R-9, R-10, O-13, Q-10, Q-11, Q-12, H-13, §2.26, §2.27). The 3 SKILL.md files in the contract surface are byte-identical (hashes unchanged). |
| **Harness-consumed scripts** (CLI contracts) | `rubric/aggregator.sh`, `rubric/runner.sh`, `compliance/aibom-emit.sh` all preserve their CLI surfaces. Same flag-name set; same exit-code contract. Safe. |
| **Top-level surfaces** | 39 → 55 entries. 16 new top-level directories/files appear (`CHANGELOG.md`, `CODEOWNERS`, `CONTRIBUTING.md`, `Dockerfile`, `LICENSE`, `MAINTAINERS.md`, `QUICKSTART.md`, `RECRUITING.md`, `package.json`, `compatibility/`, `design-tokens/`, `grok-build/`, `lsp/`, `runner-go/`, `scaffolds/`, `vscode-tdd-pro/`). The plugin-surface declaration audit (per ADR-0037) caught all of these as UNKNOWN at bump time, exactly as designed. This CL extends `docs/plugin-surface-consumption.md` with rows for each. |
| **Deletions** | 1 deletion (`evals/pending/L/L-5-two-pass-reconciler/threshold-calibration-config-present.json`). Plugin-internal eval fixture; `evals/` is DECLARED-NOT-CONSUMED. No harness-side impact. |

**Conclusion:** the bump is safe. No CLI-surface breakage; no harness-relied contract removed; new surfaces are either (a) developer-hygiene files irrelevant to the harness, (b) frontend-platform additions from the plugin's v1.11 amendment (`design-tokens/`, `scaffolds/`) inapplicable to the harness's bash+markdown substrate, or (c) integration surfaces (`grok-build/`, `lsp/`, `runner-go/`, `vscode-tdd-pro/`) the harness explicitly does not yet wire.

### Activation evidence (live, before commit)

`scripts/sync-plugin.sh --ensure` post-bump:

```
[plugin-ensure] https://github.com/drumfiend21/claude-tdd-pro @ bba77df
  status    : OK (cache materialized at bba77df)
  cursor    : .cursor/rules/*.mdc generated
  context   : PROJECT_CONTEXT_FOR_PLANNER.md injected at .harness/context/PROJECT_CONTEXT_FOR_PLANNER.md
```

The defensive deferral line from ADR-0040 has flipped to confirmation. The ADR-0040 wire is now live.

## Decision

### 1. Bump `pinned_commit` to `bba77dfacb5be0cb31c8bea712b98fadb8618ea0`

Updates `docs/claude-tdd-pro.lock.yaml`:
- `pinned_commit` → `bba77dfacb5be0cb31c8bea712b98fadb8618ea0`
- `pinned_at` → `2026-06-07T00:43:02+00:00`
- `pinned_message` → `"docs(adr-0006): correct harness-side cross-reference from ADR-0039 to ADR-0040 (TICKET-036)"`
- `contract_surface_files[CLAUDE.md].sha256` → `00e8b9c6d382941f9ef6e7ab4cb53615a08fe592ff96bae009c3c5f9ee24b649`
- `contract_surface_files[docs/architecture-v1.9.md].sha256` → `c01bb1425a6f317fce3d5c5906cd66ebdd05c672c82d89700d24a415aa87e202`
- `last_synced_at` → `2026-06-07T00:43:02Z`

The 3 SKILL.md hashes are unchanged (the inner-loop discipline didn't shift).

### 2. Extend `docs/plugin-surface-consumption.md` with 16 new entries

All 16 new top-level surfaces declared DECLARED-NOT-CONSUMED with rationale:

- **Developer-hygiene files** (9): `CHANGELOG.md`, `CODEOWNERS`, `CONTRIBUTING.md`, `Dockerfile`, `LICENSE`, `MAINTAINERS.md`, `QUICKSTART.md`, `RECRUITING.md`, `package.json` — plugin-internal; harness consumes via R-2 versioned-consumption mechanism, not via npm/Docker/etc.
- **Frontend-platform additions** (2): `design-tokens/`, `scaffolds/` — added by plugin v1.11 §26 amendment; not applicable to the harness's bash+markdown substrate. Triggers to revisit named in registry rows.
- **Integration surfaces** (5): `compatibility`, `grok-build`, `lsp`, `runner-go`, `vscode-tdd-pro` — surfaces the harness doesn't wire today; each row names the trigger to revisit.

### 3. Activate the decomposition template's `PROJECT_CONTEXT_FOR_PLANNER.md` read

The decomposition template's pre-emit checks already reference the static context (per TICKET-035). This CL adds the explicit "READ this file FIRST" instruction in the system-prompt skeleton now that the file is reliably present.

### 4. Add a small block to README.md about external planner context

Per the prior reconciliation's Step 5: a "How it works → External planner context" section explaining the static-context injection and naming ADR-0040 + ADR-0041.

## Alternatives considered

- **Skip declaring the 16 new surfaces; baseline the audit findings instead.** REJECTED. The plugin-surface registry is the durable record of "what the harness has examined and decided about each plugin surface." Baseline-suppressing the findings would defeat the registry's purpose (which was to PREVENT exactly this blindspot from recurring per ADR-0037).
- **Bump pin + activate ADR-0040 wire + ship decomposition prompt update + README block, all in one giant CL.** ACCEPTED (this CL). The prior reconciliation's Step 2 was the bump itself; Steps 3-5 are documentation lockstepped to the bump (no value in separating). Step 6 (smoke + audit chain) is the verification, not a separate concern.
- **Defer the new-surface declarations to a follow-on CL after the bump.** REJECTED. The plugin-surface audit would fail at the bump's first session-start; that's a regression by design. Better to declare in the same CL that bumps.
- **Skip the bump until the harness explicitly wires `design-tokens/` / `scaffolds/` / etc.** REJECTED. The bump is gated on contract-surface review, not on full consumption parity. Adding new surfaces and declaring them NOT-CONSUMED is the documented way to gate forward (per ADR-0037).
- **Ship a separate ADR for each new surface declaration.** REJECTED. The 16 surfaces are aggregated under this pin-bump ADR because they entered the harness's awareness together at this pin event. Individual ADRs for routine NOT-CONSUMED declarations would inflate the ADR series without adding signal.

## Consequences

### Positive

- **ADR-0040 wire is live.** Grok's planner now consumes `.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md` at session start. The static-context approach the adversarial reviewer prescribed is operationally active.
- **Plugin v1.11 §26 amendments accessible.** R-8/R-9/R-10/O-13/Q-10/Q-11/Q-12/H-13/§2.26/§2.27 IDs are now available in the consumed `docs/architecture-v1.9.md` for any future ticket that needs to cite them.
- **Plugin-surface registry stays honest.** All 55 top-level surfaces are declared (11 CONSUMED + 44 DECLARED-NOT-CONSUMED + 0 UNKNOWN). Future pin bumps that introduce more surfaces will surface the same way (the registry-audit gate is now battle-tested across two pin events).
- **Cross-repo ADR pairing reinforced.** Plugin ADR-0006 names harness ADR-0040; harness ADR-0040 names plugin ADR-0006; this ADR-0041 names both. The decision record is bidirectionally walkable.
- **11th application of the `Second voice` field per ADR-0029.** The adversarial reviewer's prior position (Step 2 IS the activation) is the second voice this CL operationalizes.
- **Smoke + test-all + audit chain remain green.** Verified before commit.

### Negative

- **The pin event surfaced a broader plugin growth** (39 → 55 top-level entries, +16 surfaces) than the prior reconciliation acknowledged. Mitigation: the registry now records all of them; the audit gate caught the gap (working as designed); this ADR documents the actual delta vs the reconciliation's simplified summary.
- **`design-tokens/` and `scaffolds/` represent inapplicable plugin growth.** Mitigation: registry rows name explicit triggers to revisit when the harness's use case shifts (e.g., scaffolding a frontend app).
- **The decomposition template's static-context instruction is now relied upon at runtime.** If the planner ignores the file, decomposition quality won't measurably improve. Mitigation: the falsification-window deferral from ADR-0040 §Out-of-scope still applies — two weeks of real use is the measurement.

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **3 SKILL.md hashes unchanged.** Inner-loop discipline didn't shift across this bump.
- **Wire-format `schema_version` unchanged.**

## Verification (executed before commit)

- `scripts/sync-plugin.sh --check` reports `pin matches HEAD`, `0 files drifted`, `status OK`.
- `scripts/sync-plugin.sh --ensure` on a clean cache emits `context: PROJECT_CONTEXT_FOR_PLANNER.md injected at .harness/context/PROJECT_CONTEXT_FOR_PLANNER.md`.
- `scripts/audit-plugin-surface.sh` reports `55 total entries, 11 CONSUMED, 44 DECLARED-NOT-CONSUMED, 0 UNKNOWN`.
- `tests/test-all.sh --quiet` passes.
- Full audit chain green.
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- ADR-0041 follows the numbered template + `Second voice` field present (11th application).

## Out of scope (named follow-ons)

- **Two-week falsification window (per ADR-0040 §Out-of-scope).** Now active; the wire is live. Trigger to revisit static-vs-dynamic context: operator reports decomposition quality after the window.
- **Wiring `design-tokens/` / `scaffolds/` / `grok-build/` / `lsp/` / `runner-go/` / `vscode-tdd-pro/`.** DEFERRED per their registry rows; each has a named trigger.
- **`docs/PROJECT_CONTEXT_FOR_PLANNER.md` content review.** Plugin-side ADR-0006 validated the content already; harness-side review fires only if decomposition quality signal warrants it.
- **Retroactive simplification review (framework-itis lens).** Still deferred per ADR-0040 §Out-of-scope; trigger unchanged (matches ADR-0033 Musk #1 pattern).

## Implementation references

- Modified: `docs/claude-tdd-pro.lock.yaml` (pin commit + contract-surface sha256 for CLAUDE.md + architecture-v1.9.md; SKILL trio unchanged)
- Modified: `docs/plugin-surface-consumption.md` (16 new entries declared NOT-CONSUMED with rationale)
- Modified: `.grok/templates/decomposition.md` (system prompt instructs planner to read the static context file FIRST; pre-emit checks pre-existed per TICKET-035)
- Modified: `README.md` (new "External planner context" block under "How it works")
- New: this ADR
- Related: ADR-0025 (pin bump precedent), ADR-0040 (the wire this bump activates), ADR-0037 (plugin-surface registry pattern), ADR-0029 (`Second voice` field — 11th application), plugin-side ADR-0006 (paired publication), plugin v1.11 §26 amendment (the new architecture content this bump introduces).
