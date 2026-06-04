# Security Review — grok-claude-tdd-pro

**Authority tier:** TIER 2 (operational rulebook). Composes on the TIER-0 corpus, the TIER-1 prime directive, and the founder-directives D-rules. Amendments via ADR per `docs/architecture-principles.md §19`.

**Trigger:** Per Musk Engineering Leadership letter (2026-05-26) §4 "Security Review (#4)" — *"The harness has substantial code-execution surface (hooks fired on tool use; substrate scripts invoked at session start + pre-commit; Grok templates fed to LLM-driven agents). Audit it once, codify the audit as a re-runnable script, and ship a baseline."* This doc is that codification; `scripts/audit-hook-security.sh` is the re-runnable artifact.

**Status:** v1 — initial codification of attack surface inventory + baseline-tolerant scan policy. v1 covers shell-pattern detection (S-1..S-6). Future versions can extend to MCP-server permission audits, hook input-validation patterns, and Grok template prompt-injection patterns as the surface evolves.

## 1. Threat model

The grok-claude-tdd-pro harness has three classes of code-execution surface:

1. **Claude Code hooks** (`.claude/hooks/*.sh`) — fire automatically on tool use (PreToolUse, PostToolUse, SessionStart, etc.). Untrusted tool arguments can reach these scripts; bugs become security issues at hook-execution time.
2. **Substrate scripts** (`scripts/*.sh`) — invoked at session start (`sync-plugin.sh --ensure`) and pre-commit (`smoke-e2e.sh`, `audit-doc-drift.sh`, etc.). Run with full operator shell permissions; substrate compromise propagates to operator's local environment.
3. **Grok templates** (`.grok/templates/*.md`) — consumed by LLM-driven agents that may treat template content as instructions. Prompt-injection in templates can divert downstream agent behavior.

Out-of-scope at v1:

- **MCP servers** — not yet self-hosted in this repo; the harness consumes GitHub MCP tools via Claude Code's tool-broker layer, which carries its own permission model. If the harness adopts a self-hosted MCP server in the future, the audit scope extends to that server's authentication and tool-permission policy.
- **Plugin cache** (`.harness/cache/plugin/`) — content comes from the pinned upstream commit verified by `sync-plugin.sh`'s commit-hash check; the cache is treated as a trust boundary delegated to upstream's own review process.
- **Cryptographic signing** — `signature: null` per ADR-0018 §3 deferral; sha256 manifest hashes detect drift but do not authenticate provenance.

## 2. Scan policy (S-1 .. S-6)

`scripts/audit-hook-security.sh` scans for six pattern classes across `.claude/hooks/`, `scripts/`, `tests/`, `.claude/skills/orchestrating-swarms/SKILL.md`, and `.grok/templates/`. Each class derives from an attack-vector mapped to OWASP / CWE canonical sources.

| ID | Pattern | Attack vector | Canonical reference |
|----|---------|---------------|---------------------|
| S-1 | unprotected `eval` | command injection via untrusted args reaching shell evaluator | CWE-95 (Eval Injection) |
| S-2 | `curl \| bash` / `wget \| sh` | supply-chain compromise via mid-flight HTTP MITM | CWE-494 (Download of Code Without Integrity Check) |
| S-3 | `rm -rf` | data loss when path is unbounded or operator-controlled | CWE-73 (External Control of File Name) |
| S-4a..e | hardcoded credentials | secret exposure in source tree (KEY=, TOKEN=, SECRET=, password=, api_key=) | CWE-798 (Hard-coded Credentials) |
| S-5 | `sudo` | privilege escalation; not legitimate in harness substrate | CWE-250 (Execution with Unnecessary Privileges) |
| S-6 | `bash -c` with unquoted variable | argument injection through `$@` / `$*` expansion | CWE-77 (Command Injection) |

## 3. Baseline-tolerant exit policy

Per ADR-0032 (cross-reference audit) and ADR-0034 (this doc + the audit script), the scan follows the **approval-baseline pattern** documented by Fowler in *Approval Testing*: known-accepted findings live in `tests/hook-security-baseline.txt`; the script exits 0 when current findings match the baseline, 1 when new findings appear, 2 on script error.

The baseline at v1 captures **15 entries, all in class S-3**, all bounded `rm -rf` operations:

- `trap 'rm -f -- "$findings_file"' EXIT INT TERM` — POSIX-portable temp-file cleanup in `audit-cross-references.sh`, `audit-doc-drift.sh`, `audit-manifest.sh`, `emit-manifest.sh`.
- `rm -rf -- "$OUTDIR"` inside an `EXIT` trap in `export-cursor-rules.sh` (tempdir for `--check`).
- `rm -f -- "$TEST_OUT"` in `smoke-e2e.sh` (per-test cleanup).
- `rm -rf "$CLONE_DIR"` in `sync-plugin.sh` (post-fetch plugin-cache rotation; path is constructed locally).
- `rm -f "$TMPDOC"` / `rm -f .harness/audit/TICKET-042.manifest*.json` in test files (per-test cleanup with explicit local paths).

All 15 baseline entries use **explicit, locally-constructed paths** — none take operator-controlled arguments. The S-3 pattern fires because the regex matches `rm -[rRf]+f?` regardless of the path; the baseline encodes operator review per Decision-3 of ADR-0034.

**Zero findings at v1 in classes S-1, S-2, S-4, S-5, S-6.** The harness substrate has no `eval`, no `curl|bash`, no hardcoded credentials, no `sudo`, no unquoted `bash -c`.

## 4. Operator procedure

Run the audit any time:

```bash
./scripts/audit-hook-security.sh           # human-readable summary
./scripts/audit-hook-security.sh --quiet   # exit code only (CI mode)
```

If `[NEW]` findings appear:

1. Inspect the finding's pattern ID + file:line + content.
2. Decide: fix the new pattern (preferred), OR add to baseline with security justification.
3. To add to baseline: append the `[NEW]` line (verbatim, with the `S-N|description|file:line:content` shape) to `tests/hook-security-baseline.txt`, re-sort, commit with a justification line in the commit body.
4. Re-run `./scripts/audit-hook-security.sh --quiet` to confirm exit 0.

To regenerate the baseline (after a substantial substrate change):

```bash
./scripts/audit-hook-security.sh 2>&1 \
  | grep '\[NEW\]' \
  | sed 's/^  \[NEW\] //' \
  | sort > tests/hook-security-baseline.txt
```

Operator must review every new baseline entry before committing. The baseline is a security artifact, not a convenience file.

## 5. Test discipline

`tests/test-audit-hook-security.sh` runs as part of `tests/test-all.sh`. Asserts:

1. `--help` exits 0.
2. Unknown flag exits 2.
3. Default mode exits 0 (baseline matched).
4. Baseline file exists + non-empty.
5. Injecting `eval "$1"` into a temp test file triggers exit 1 (new S-1 finding).
6. Post-restore, the audit returns to exit 0 (no permanent drift).
7. Injecting `API_TOKEN="abc123secret"` into a temp test file triggers exit 1 (new S-4b finding).
8. Output mentions "baseline" and "finding" terminology.

Uses the **restore-before-assert** pattern (per ADR-0028 §3) to ensure test failures cannot leave the substrate dirty.

## 6. Pre-commit integration

The audit is **NOT** wired into the default pre-commit hook at v1 per the over-engineering filter — operator-bitten threshold not yet met. The audit is run:

- **On demand** by the operator before security-sensitive changes (new hook, new substrate script).
- **In CI** via `tests/test-all.sh` (which runs all substrate tests, including `test-audit-hook-security.sh`).
- **As the first step of a future pre-commit integration** if/when the operator-bitten threshold is met (e.g., a hook bug ever ships to main).

## 7. Out of scope (named deferrals)

Per Musk's Algorithm step 2 ("delete the part"), each below is named with explicit rationale so future architects know the trigger:

- **MCP-server permission audits.** Trigger: harness adopts a self-hosted MCP server. v1 delegates to Claude Code's tool-broker permission model.
- **Hook input-validation patterns.** Trigger: an operator-reported hook bug surfaces an input-handling gap. v1's S-1 / S-6 scan catches the worst classes.
- **Grok template prompt-injection patterns.** Trigger: a downstream Grok agent ever follows template-embedded instructions in a way that diverts intent. v1's scan covers shell patterns; template content is not yet pattern-scanned because the LLM consumer is the trust boundary.
- **Cryptographic signing of substrate scripts.** Trigger: signature rotation requirements + KMS access. v1 retains `signature: null` per ADR-0018 §3.
- **Reachability analysis (which hook fires for which tool).** Trigger: hook count exceeds operator-tractable threshold. v1's 4-hook substrate is small enough for direct human review.

## 8. Authority and amendment

This doc is TIER 2. Amendments follow the ADR process in `docs/architecture-principles.md §19`. New scan patterns (S-7+) require an ADR documenting the threat model + the CWE / OWASP mapping. Baseline regeneration without an ADR is permitted when substrate changes legitimately introduce new bounded patterns; baseline additions in any other case require operator review documented in the commit body.

## 9. Verification (this doc)

| Check | Command |
|-------|---------|
| Audit script present + executable | `test -x scripts/audit-hook-security.sh` |
| Baseline present + non-empty | `test -s tests/hook-security-baseline.txt` |
| Audit passes against baseline | `./scripts/audit-hook-security.sh --quiet` exit 0 |
| Test suite passes | `./tests/test-audit-hook-security.sh --quiet` exit 0 |
| Doc grep-discoverable | `grep -q '^# Security Review' docs/security-review.md` |
| Doc in TIER-2 enumeration | `grep -q 'docs/security-review.md' AGENTS.md` |
| ADR present | `test -f docs/adr/0034-musk-letter-closure.md` |
