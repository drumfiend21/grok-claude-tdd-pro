# ADR-0036 — Claude Code upgrade strategy: pin range + compat audit + hook-contract tests + runbook (TICKET-031)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 directive: *"Bring it in line with best practices per the matter"* — override of the prior deferral analysis in favor of formal best practices) + Claude (cloud session, implementer)
- **Second voice (per ADR-0029 pattern; 7th application):** The prior message in this same session, which presented a deferral analysis with named triggers per the over-engineering filter. The user's response *"Bring it in line with best practices per the matter"* IS the second voice — overriding the strict-filter recommendation in favor of the symmetric-with-plugin-pin discipline. The override is principled: it elevates formal best practices when the architect explicitly directs it. This ADR records both the override and the design that ships it.
- **Trigger:** User directive 2026-05-26, overriding the filter-disciplined deferral recommended in the prior turn.
- **Supersedes:** the deferral analysis in the prior version of `docs/claude-code-upgrade-strategy.md` (the same file is now rewritten to a SHIPPED rulebook). The TICKETS.md row for TICKET-031 is updated from DEFERRED to DONE.
- **Extends:** ADR-0001 (plugin lockfile + SessionStart sync — the WARN-not-FAIL stance this CL mirrors); ADR-0025 (plugin pin bump precedent — the ADR-gated-bump pattern this CL mirrors for compat-range bumps); ADR-0028 (substrate test discipline — `tests/test-audit-claude-code-compat.sh` and `tests/test-hook-contracts.sh` participate); ADR-0029 (`Second voice` field — 7th application).

## Context

The harness already had exemplary discipline for *plugin* upgrades: SHA-pinned lockfile + drift-detect via `sync-plugin.sh --check` + ADR-gated bumps (precedent: ADR-0025) + manifest provenance with sha256. The same discipline did NOT extend to Claude Code itself — the host CLI was whatever the operator had installed, with no declared compatibility range, no SessionStart compat check, no hook-payload contract tests, no operator-facing upgrade runbook.

The prior turn analyzed this gap and produced a filter-disciplined deferral: operator-bitten threshold not met → defer with named triggers (matches the Musk #1 / #2 deferral pattern in ADR-0034). The user override (*"Bring it in line with best practices per the matter"*) elevates formal best practices above the strict filter for this matter specifically.

The override is principled, not arbitrary:

- The cost of the discipline (one declared range + a few fixtures + a runbook + a small audit script) is tractable in a single CL.
- The benefit (symmetric protection that mirrors the plugin-pin discipline) is exactly the kind of structural protection the over-engineering filter is supposed to preserve.
- The deferral pattern (#1, #2) is for items that genuinely cannot close without real-project data; this item was always tractable, just below the strict operator-bitten threshold.

## Decision

### 1. Mirror the plugin-pin discipline for Claude Code (the host CLI)

Apply the same four-part pattern that protects the plugin to Claude Code:

| Concern | Plugin (shipped) | Claude Code (this CL) |
|---|---|---|
| Declared version | `docs/claude-tdd-pro.lock.yaml` | `docs/claude-code-compat.yaml` |
| Drift detection | `sync-plugin.sh --check` + SessionStart WARN | `audit-claude-code-compat.sh` + SessionStart WARN |
| Contract tests | F-1..F-6 audits | `tests/test-hook-contracts.sh` + golden fixtures |
| Gated bumps | ADR-0025 precedent | This ADR establishes the precedent for compat-range bumps |

### 2. WARN-not-FAIL semantics throughout

`audit-claude-code-compat.sh` exits 1 when outside the declared range, but the SessionStart hook does NOT propagate that exit — it lets the session continue, just as the plugin pin's drift exit does (per ADR-0001). The WARN is the signal; never block the operator's session on a compat mismatch. The operator decides whether to triage, rollback, or proceed.

This stance is intentional: Anthropic-side breakage that surfaces in a Claude Code upgrade is not always severe, and the operator may need to keep working even while triaging. Blocking would create false urgency where WARN preserves agency.

### 3. Golden fixtures pin the hook contract, not the hook implementation

`tests/fixtures/hook-payloads/*.json` captures Claude Code's actual hook payload shape for the currently tested CLI version. If Anthropic changes a field name or shape, the fixtures stay frozen — the contract test fails — surfacing the breakage at test time rather than at runtime.

Fixtures cover the four scenarios that exercise the `post-tool-use-review-gate.sh` hook's documented branches:
- Allowed-path Edit (exit 0, no violation).
- Allowed-path Write (exit 0, no violation).
- Forbidden-path Edit on `.cursor/rules/agent-context.mdc` per ADR-0014 (exit 2, violation).
- Non-edit tool (Read) — hook is a no-op (exit 0).

Plus a defensive test: payload missing `tool_name` → hook still exits 0 (no crash).

When the range is bumped, the operator MUST re-capture fixtures from the new CLI version per `docs/claude-code-upgrade-runbook.md §3`. Stale fixtures = stale contract = silent breakage.

### 4. Compat-range bumps require an ADR (architecture-principles §15)

Same gating as plugin-pin bumps: editing `supported_range.max` (or `min`) is a structural TIER-2 amendment requiring an ADR documenting the tested CLI version + the verification chain result + any patches that landed in the same CL. Precedent for this class of ADR starts here.

### 5. Operator runbook (`docs/claude-code-upgrade-runbook.md`) ships in this CL

The runbook is operator-facing prose covering: pre-upgrade checklist → upgrade procedure → decision tree (green / red) → rollback path → post-upgrade smoke test → what to record in AUTOMATION_INTEL.md → named anti-patterns. The runbook turns "Claude Code just upgraded — now what?" from a research task into a 5-step procedure.

## Alternatives considered

- **Defer per the filter (the prior turn's recommendation).** REJECTED by user override. The filter's analysis was correct ("operator-bitten threshold not met"); the user's response elevates formal best practices for this matter specifically.
- **FAIL-not-WARN on out-of-range CLI.** REJECTED. Blocking the session creates false urgency and removes operator agency. The WARN line is sufficient for an attentive operator; the runbook is sufficient for an inattentive one (it surfaces at every session start).
- **Auto-bump `supported_range` when `claude --version` reports a new value.** REJECTED. Bypasses the ADR gate (`architecture-principles §15`) and would silently absorb breaking changes. The whole point of the range is to surface drift that requires operator judgment.
- **Pin a specific CLI version rather than a range.** REJECTED. Anthropic ships frequent patch releases; pinning to a specific version would generate WARN noise on every minor patch. A range tolerates the patch level while still gating major-version drift.
- **Use `jq` for YAML parsing in `audit-claude-code-compat.sh`.** REJECTED per C-23 (bash 3.2 + BSD coreutils portability). `jq` is not part of the substrate dependency surface; YAML scalar extraction via `grep`+`sed` is the portable path.
- **Capture fixtures for `SessionStart`, `PreToolUse`, `Stop` events too.** REJECTED at v1. The harness only ships one hook that reads stdin (`post-tool-use-review-gate.sh`); fixturing other events would be aspirational coverage. When a future hook reads stdin, the fixtures grow at that CL.
- **Embed the version-range check directly in `sync-plugin.sh`.** REJECTED. The two checks have different domains (plugin SHA drift vs. host CLI semver drift); composing them into one script would conflate concerns. Two scripts, two exit codes, two failure modes documented separately.

## Consequences

### Positive

- **Symmetric protection.** Claude Code is now consumed with the same R-2 (versioned consumption) discipline applied to the plugin. The host CLI is no longer the silent outlier.
- **Drift detected at session start, every time.** Every new Claude Code release that drifts outside the declared range surfaces the WARN line on the next session — operator-visible by design.
- **Hook payload contracts pinned.** If Anthropic changes a `PostToolUse` field, the contract test fails immediately; the operator knows before runtime breakage compounds.
- **Upgrade path is predictable.** `docs/claude-code-upgrade-runbook.md` is a 5-step procedure with named decision points. The rollback path is explicit.
- **Substrate test coverage 13/13 → 15/15.** Two new tests: `test-audit-claude-code-compat.sh` (9 assertions) + `test-hook-contracts.sh` (15 assertions).
- **Operationalizes R-2 at the host-CLI scope.** The principle ("versioned consumption") now applies symmetrically to plugin + CLI.
- **Per ADR-0029 `Second voice` field — 7th application.** The user override IS the second voice; this ADR cites the override verbatim.
- **Sets precedent for compat-range bump ADRs.** The next time a Claude Code release ships, the operator follows the runbook, the ADR template is established, and the ADR-gating is operational.

### Negative

- **One more compat surface to maintain.** When Anthropic ships a new CLI version, the operator must run the verification chain + write an ADR. Mitigation: the runbook makes this a 30-minute task, not a research task.
- **Fixtures will need re-capture on range bumps.** Mitigation: runbook §3 names the re-capture procedure; ADR template includes a fixture-re-capture checkpoint.
- **YAML parsing via grep+sed is fragile against schema additions.** Mitigation: the compat YAML schema is documented at the top of the file; adding fields without breaking the existing parser is straightforward (the parser extracts named scalars by exact regex).

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **Plugin pin unchanged.**
- **Wire-format `schema_version` unchanged.**
- **Existing 11 hooks untouched** (only `session-start.sh` extended; `post-tool-use-review-gate.sh` byte-identical and now contract-tested).

## Verification (executed before commit)

- `./scripts/audit-claude-code-compat.sh` exits 0 against current CLI (2.1.163, in 2.0.0..3.0.0 range).
- `./scripts/audit-claude-code-compat.sh --version 4.5.0` exits 1 (out of range; WARN messaging present).
- `./tests/test-audit-claude-code-compat.sh` exits 0 with 9/9 passing (boundary tests + in/out-of-range tests).
- `./tests/test-hook-contracts.sh` exits 0 with 15/15 passing (fixture presence + JSON validity + 4 hook scenarios + defensive missing-field test).
- `./tests/test-all.sh --quiet` shows 15/15 suites passing.
- `.claude/hooks/session-start.sh` emits the `[claude-code-compat]` OK line at session start.
- Full audit chain: audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest + audit-cross-references + audit-hook-security + audit-metrics + audit-claude-code-compat all exit 0.
- `git diff docs/founder-directives.md` shows 0 lines (D-6 honored).
- ADR-0036 follows the numbered ADR template + `Second voice` field present (7th application).
- `docs/claude-code-upgrade-strategy.md` rewritten from DEFERRED to SHIPPED rulebook + listed in AGENTS.md §5.
- `docs/claude-code-upgrade-runbook.md` present + listed in AGENTS.md §5.
- `.cursor/rules/agent-context.mdc` regenerated to include both new TIER-2 docs.
- `tests/README.md` coverage table updated to 15/15 surfaces.
- `tests/cross-references-baseline.txt` cleaned: the prior deferral-CL baseline entries (paths that didn't exist) removed because the paths now exist.

## Out of scope (deferred per filter — these stay deferred)

- **Fixtures for `SessionStart`, `PreToolUse`, `Stop` hook events.** DEFERRED; trigger: harness adds a hook that reads stdin for one of those events.
- **Auto-rollback to prior CLI version on compat failure.** DEFERRED; trigger: an operator-bitten rollback scenario surfaces. Anthropic's installer history may not make this tractable in the general case.
- **CI matrix against multiple Claude Code versions.** DEFERRED; trigger: harness gains CI (currently no CI per ADR-0028 §Out-of-scope).
- **Telemetry on hook failures.** DEFERRED; trigger: operator-base grows beyond N=1.
- **Musk-letter #1 (Benchmark Velocity) and #2 (Dogfood)** — UNCHANGED deferrals from ADR-0034 §Out-of-scope. The user override here applies to the Claude Code upgrade matter specifically, not to those items.

## Implementation references

- New: `docs/claude-code-compat.yaml` (declared `supported_range` + `tested_versions` ledger)
- New: `scripts/audit-claude-code-compat.sh` (~90 lines; bash 3.2 + BSD portable; in-range/out-of-range exit-code contract)
- New: `tests/test-audit-claude-code-compat.sh` (9 assertions; boundary semver tests + override flag for testing)
- New: `tests/fixtures/hook-payloads/*.json` (4 fixture files + README.md)
- New: `tests/test-hook-contracts.sh` (15 assertions; 4 hook scenarios + defensive missing-field test)
- New: `docs/claude-code-upgrade-runbook.md` (operator procedure; 8 sections)
- New: this ADR
- Modified: `.claude/hooks/session-start.sh` (adds compat-audit invocation after plugin sync; warn-only)
- Modified: `docs/claude-code-upgrade-strategy.md` (DEFERRED → SHIPPED rulebook)
- Modified: `AGENTS.md §5` (TIER-2 enumeration adds both new docs)
- Modified: `scripts/export-cursor-rules.sh` (TIER-2 list)
- Regenerated: `.cursor/rules/agent-context.mdc`
- Modified: `AUTOMATION_INTEL.md` (2026-05-26 entry: user override + SHIPPED record + 2.1.163 captured)
- Modified: `TICKETS.md` (TICKET-031 row: DEFERRED → DONE)
- Modified: `tests/README.md` (coverage 13/13 → 15/15)
- Modified: `tests/cross-references-baseline.txt` (paths now exist; baseline cleaned)
- Related: ADR-0029 (Second voice field — 7th application), ADR-0001 (WARN-not-FAIL precedent), ADR-0025 (plugin pin bump precedent), ADR-0028 (substrate test discipline), ADR-0014 (`.cursor/rules/*.mdc` are generator output — the forbidden-path fixture exercises this fence), CLAUDE.md prime directive (R-2 versioned consumption symmetrically applied).
