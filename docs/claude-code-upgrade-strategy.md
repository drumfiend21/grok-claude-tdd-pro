# Claude Code Upgrade Strategy — grok-claude-tdd-pro

**Authority tier:** TIER 2 (operational rulebook). Composes on the TIER-1 prime directive (plugin-dependency model) and the founder-directives D-rules. Amendments via ADR per `docs/architecture-principles.md §19`.

**Status:** v1 — SHIPPED. The harness now extends the same pin + drift-detect + ADR-gated-bump + contract-test discipline applied to the plugin to Claude Code itself. Per TICKET-031 / ADR-0036, the gap relative to formal best practices identified in the prior B-graded analysis is closed.

**Operational artifacts shipped in this CL:**

- `docs/claude-code-compat.yaml` — declared `supported_range` (currently `>=2.0.0, <3.0.0`) + `tested_versions` ledger + `first_known_incompatible` field. Bumping the range requires an ADR per `architecture-principles §15`.
- `scripts/audit-claude-code-compat.sh` — re-runnable host-CLI version check; reads `claude --version`, semver-compares against the declared range; exit 0 in-range / 1 out-of-range / 2 error.
- `.claude/hooks/session-start.sh` extended — fires the compat audit at session start; WARN-not-FAIL (mirrors the plugin-pin stance per ADR-0001).
- `tests/fixtures/hook-payloads/*.json` — golden JSON fixtures pinning the Claude Code hook payload contract.
- `tests/test-hook-contracts.sh` — feeds each fixture to the matching hook script; asserts documented exit codes + output shape. 15 assertions.
- `tests/test-audit-claude-code-compat.sh` — 9 assertions exercising the compat script's exit-code contract (in-range / boundary-min inclusive / boundary-max exclusive / below-min / above-max).
- `docs/claude-code-upgrade-runbook.md` — operator procedure for an upgrade: pre-upgrade checklist → upgrade → verification chain → decision tree → rollback path.
- ADR-0036 — records the design, the symmetric-with-plugin-pin rationale, alternatives rejected, named anti-patterns.

## 1. Risk surfaces (what this discipline protects against)

These are not hypothetical — each has changed in past Claude Code releases:

| Surface | What can break | Harness location | This CL's protection |
|---|---|---|---|
| Hook payload schema (`PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`) | Field renames / additions / payload shape changes silently no-op our hooks | `.claude/hooks/*.sh` | `tests/test-hook-contracts.sh` + `tests/fixtures/hook-payloads/` |
| Settings.json schema | New required fields disable hooks without warning | `.claude/settings.json` | Compat-range bump ADR documents the schema delta; runbook §3 names the symptom class |
| Skill loading semantics (SKILL.md metadata, activation rules) | Symlinked plugin trio fails to load | `.claude/skills/tdd-pro-*` | Smoke-e2e exercises skill resolution; failure surfaces in upgrade verification chain |
| Slash command discovery | `.claude/commands/` + `.cursor/commands/` format changes | `.cursor/commands/*.md` | Runbook §3 names the symptom; operator-driven detection at upgrade time |
| CLI flag surface (`claude -p`, `--quiet`, model selection) | Smoke / inner-loop wrappers break | `scripts/smoke-e2e.sh`, `.cursor/commands/inner-loop.md` | Smoke-e2e in the verification chain |
| Plugin loading model | Plugin-style consumption model assumption breaks | The prime directive itself | Range bump requires ADR per architecture-principles §15 |

## 2. The symmetric design (now implemented)

The four-part discipline that protects the plugin now also protects Claude Code:

| Concern | Plugin (shipped TICKET-001.e) | Claude Code (shipped THIS CL — TICKET-031) |
|---|---|---|
| Declared version | `docs/claude-tdd-pro.lock.yaml` pins commit SHA | `docs/claude-code-compat.yaml` declares `supported_range` + `tested_versions` ledger |
| Drift detection | `sync-plugin.sh --check` compares pin to upstream HEAD; SessionStart prints WARN | `audit-claude-code-compat.sh` compares `claude --version` to declared range; SessionStart prints WARN |
| Contract tests | F-1..F-6 audits + `audit-doc-drift.sh` | `tests/test-hook-contracts.sh` with golden fixtures |
| Gated bumps | Pin bump requires ADR (precedent: ADR-0025) | Range bump requires ADR per `architecture-principles §15` (precedent for compat-range bumps starts with the next ADR after ADR-0036) |

## 3. Operator workflow on a Claude Code upgrade

See `docs/claude-code-upgrade-runbook.md` for the full procedure. Summary:

1. **Pre-upgrade:** confirm baseline green (compat check + test-all + smoke-e2e + doc-drift). Note current version.
2. **Install candidate version.**
3. **Verify post-upgrade:** re-run the full chain. Expected SessionStart WARN until the range is bumped.
4. **Decide:** all green → bump range via ADR; any red → triage the failing surface (hook payload? settings schema? CLI flag?); rollback or patch as appropriate.
5. **Record:** AUTOMATION_INTEL.md entry under today's date with old → new + verification result.

## 4. Why this matters (filter rationale)

The previous deferral analysis used the over-engineering filter:

- Operator-bitten? Not yet.
- Composes on existing primitives? YES (mirrors the plugin pin).
- R-3 risk? Low.
- Maintenance cost? Moderate.
- Deletion-pass survives? Uncertain without an operator-bitten signal.

The user override (2026-05-26 directive: *"Bring it in line with best practices per the matter"*) resolves the uncertainty: formal best practices win over the strictest reading of the filter. The cost is one declared range + a few fixtures + a runbook; the benefit is symmetric protection that mirrors the discipline already proven for the plugin. The same audit chain + same WARN stance + same ADR-gating now protects both dependencies.

This is the principled exception to the deletion-pass: when an architect explicitly directs that best practices apply, the filter yields. The deferral pattern (Musk #1, #2) is for items that genuinely cannot be closed without real-project data; this item was always tractable, just below the operator-bitten threshold under the strict filter.

## 5. Anti-patterns (named for future readers)

- **Treating the SessionStart `[claude-code-compat]` WARN line as noise.** The WARN is the signal that the operator is running outside the tested range. Suppressing it defeats the purpose.
- **Bumping `supported_range` without re-capturing hook fixtures.** Stale fixtures = stale contract = silent breakage on the next upgrade.
- **Bumping `supported_range` without an ADR.** Violates `architecture-principles §15`. The compat file is a TIER-2 surface; range changes are structural amendments.
- **Editing existing fixtures to "fix" failing contract tests.** That hides real breakage. The fixtures are pinned; the hook is what changes.

## 6. Composition (cited, not duplicated, per R-3)

- `docs/architecture-principles.md §15` — the ADR-amendment process this discipline depends on.
- `docs/architecture-principles.md R-2` — versioned consumption; Claude Code is now consumed with the same R-2 discipline applied to the plugin.
- `docs/plugin-sync.md` — the symmetric pattern this design mirrors.
- `docs/claude-code-compat.yaml` — the declared range.
- `docs/claude-code-upgrade-runbook.md` — the operator procedure.
- `scripts/audit-claude-code-compat.sh` — the re-runnable check.
- `tests/test-hook-contracts.sh` + `tests/fixtures/hook-payloads/` — the contract pins.
- ADR-0001 (plugin lockfile + SessionStart sync) — the precedent for the WARN-not-FAIL stance applied to compat checks.
- ADR-0025 (plugin pin bump) — the precedent for an ADR-gated range bump.
- ADR-0028 (substrate-script test discipline) — the precedent for `test-audit-claude-code-compat.sh` and `test-hook-contracts.sh` being part of `tests/test-all.sh`.
- ADR-0036 — the ADR that ships this discipline.

## 7. Verification (this doc + the discipline)

| Check | Command |
|-------|---------|
| Compat YAML present | `test -f docs/claude-code-compat.yaml` |
| Compat script present + executable | `test -x scripts/audit-claude-code-compat.sh` |
| Compat audit in-range against current CLI | `./scripts/audit-claude-code-compat.sh --quiet` exit 0 |
| Compat test suite green | `./tests/test-audit-claude-code-compat.sh --quiet` exit 0 (9/9) |
| Hook contract fixtures present | `ls tests/fixtures/hook-payloads/*.json` returns ≥4 files |
| Hook contract test green | `./tests/test-hook-contracts.sh --quiet` exit 0 (15/15) |
| SessionStart hook fires compat check | `.claude/hooks/session-start.sh` emits `[claude-code-compat]` line |
| Runbook present | `test -f docs/claude-code-upgrade-runbook.md` |
| Strategy doc listed in AGENTS.md §5 | `grep -q 'docs/claude-code-upgrade-strategy.md' AGENTS.md` |
| ADR present | `test -f docs/adr/0036-claude-code-upgrade-strategy.md` |
| Cursor rule includes strategy + runbook | `grep -q 'claude-code-upgrade' .cursor/rules/agent-context.mdc` |
| Test-all 15/15 | `./tests/test-all.sh --quiet` exit 0 |
| D-6 honored | `git diff docs/founder-directives.md` returns 0 lines |
