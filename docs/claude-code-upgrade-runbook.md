# Claude Code Upgrade Runbook — grok-claude-tdd-pro

**Authority tier:** TIER 2 (operational rulebook). Composes on `docs/claude-code-upgrade-strategy.md` (analysis + risk surfaces), `docs/claude-code-compat.yaml` (declared range), and `scripts/audit-claude-code-compat.sh` (re-runnable compat check). Amendments via ADR per `docs/architecture-principles.md §19`.

**Audience:** the operator (or any future external operator) about to install a new Claude Code version.

**Purpose:** make the upgrade path predictable, auditable, and rollback-safe. Mirror the discipline applied to plugin-pin bumps (ADR-0025 precedent) for the host CLI.

## 1. Pre-upgrade checklist

Before installing a candidate Claude Code version:

1. **Confirm current state is green.**
   ```bash
   ./scripts/audit-claude-code-compat.sh  # OK — current version in range
   ./tests/test-all.sh --quiet            # 15/15 PASS
   ./scripts/smoke-e2e.sh                 # OK
   ./scripts/audit-doc-drift.sh           # OK
   ```
   If any of these are RED before upgrading, fix that first. Never start an upgrade from a broken baseline.

2. **Note the current version.**
   ```bash
   claude --version  # capture for the post-upgrade comparison
   ```

3. **Commit any in-progress work.** The upgrade itself touches no harness files, but you want a clean tree to bisect from if breakage surfaces.

## 2. Upgrade procedure

1. **Install the candidate Claude Code version** per Anthropic's documented installer.

2. **Re-run the full verification suite.** Do NOT trust silent success:
   ```bash
   claude --version                          # confirm the new version is active
   ./scripts/audit-claude-code-compat.sh     # expected: WARN (out of declared range)
   ./tests/test-hook-contracts.sh            # expected: 15/15 PASS
   ./tests/test-all.sh --quiet               # expected: 15/15 PASS
   ./scripts/smoke-e2e.sh                    # expected: OK
   ./scripts/audit-doc-drift.sh              # expected: OK
   ```

3. **Run a real session.** Open Claude Code in this repo. The SessionStart hook will print the WARN line (expected — your version is outside the declared range until you bump it). Pick a small ticket. Drive one R-G-R cycle. If the inner-loop discipline works end-to-end, the substrate is compatible with the new CLI.

## 3. Decision tree

### If everything is green

The candidate version is compatible. Bump the supported range:

1. Edit `docs/claude-code-compat.yaml`:
   - Add a new entry to `tested_versions:` with the new version + capture date + result `green`.
   - Update `supported_range.max` if the new version moves into a new major.
   - Leave `first_known_incompatible` unchanged unless evidence dictates.
2. Write an ADR (`docs/adr/0NNN-claude-code-range-bump-to-Y.Z.md`) per `architecture-principles §15`:
   - Cite the tested version + capture date.
   - Cite the verification chain (smoke-e2e + test-all + audit-hook-contracts).
   - Link to this runbook.
3. Re-run `./scripts/audit-claude-code-compat.sh` — expect OK (in range).
4. Commit.

### If any verification step is RED

The candidate version has a real incompatibility. Triage:

1. **Identify the failing surface.** Common breakage classes (per `docs/claude-code-upgrade-strategy.md §2`):
   - Hook payload field renamed/removed → `test-hook-contracts.sh` fails on field-extraction asserts.
   - Settings.json schema change → hook stops firing entirely (no log lines).
   - Skill loading semantics → `.claude/skills/` symlinks fail to resolve at session start.
   - Slash command discovery → `.cursor/commands/*.md` no longer surfaced.
   - CLI flag surface → `smoke-e2e.sh` or `inner-loop.md` invocations exit non-zero.

2. **Decide:**
   - **Minor fix (hook patches a renamed field):** patch the hook + add a regression fixture; bump range in same ADR documenting the patch.
   - **Major break (settings schema redesign, plugin loading model change):** stay on the prior CLI version. File an issue with Anthropic. Update `docs/claude-code-compat.yaml` `first_known_incompatible:` field. Do NOT bump `supported_range.max`.

3. **Rollback if needed.** Reinstall the prior Claude Code version. Re-run the verification chain to confirm green.

## 4. Post-upgrade smoke test (mandatory)

After ANY successful range bump, run the smoke test in a fresh session:

```bash
./scripts/smoke-e2e.sh
```

Expected: TICKET-042 fixture goes green end-to-end. Generates fresh `.harness/audit/TICKET-042.manifest.json`. If the manifest has different fields than the prior version, the schema may have shifted — investigate before signing off.

## 5. What to record in AUTOMATION_INTEL.md

For every Claude Code range bump, append an entry under today's date with:

- Old version → new version.
- Verification chain result (15/15 + audit chain green).
- Any patches that landed in the same CL.
- The ADR number.

This builds a per-version compatibility ledger that pays compounding dividends — future Anthropic releases get easier to triage when you can see the prior delta.

## 6. Anti-patterns

- **Skipping the verification chain "because it's a minor version bump."** Anthropic has shipped breaking changes in minor versions. Run the chain every time.
- **Bumping `supported_range.max` without an ADR.** Violates `architecture-principles §15`. The compat file is a TIER-2 surface; range changes are structural amendments.
- **Bumping the range without re-capturing hook fixtures.** Stale fixtures = stale contract = silent breakage on the next upgrade.
- **Treating the SessionStart WARN as noise.** The WARN line IS the signal that the operator is outside the tested range. Suppressing it (`scripts/audit-claude-code-compat.sh --quiet` from the hook) defeats the purpose.

## 7. Composition (cited, not duplicated, per R-3)

- `docs/claude-code-upgrade-strategy.md` — risk-surface inventory + best-practices mapping.
- `docs/claude-code-compat.yaml` — declared range + tested versions ledger.
- `scripts/audit-claude-code-compat.sh` — the re-runnable check this runbook drives.
- `tests/test-hook-contracts.sh` + `tests/fixtures/hook-payloads/` — the contract pins protecting the hooks.
- ADR-0025 — the precedent ADR for a similar bump (plugin pin); model for compat-range bump ADRs.
- ADR-0036 — the ADR that ships the discipline this runbook operationalizes.

## 8. Verification (this doc)

| Check | Command |
|-------|---------|
| Runbook present + grep-discoverable | `grep -q '^# Claude Code Upgrade Runbook' docs/claude-code-upgrade-runbook.md` |
| Listed in AGENTS.md §5 | `grep -q 'docs/claude-code-upgrade-runbook.md' AGENTS.md` |
| Cited from ADR-0036 | `grep -q 'claude-code-upgrade-runbook.md' docs/adr/0036-*.md` |
