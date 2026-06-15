# tests/ — substrate-script unit tests

Born of Fowler critique #2 (closed in TICKET-023 / ADR-0028): *"You preach TDD without practicing it on your own substrate."* Extended to **100% substrate-surface coverage** per the 2026-05-26 user directive ("Also report code coverage by unit tests. It should be 100% unit test coverage").

## Discipline

Every harness substrate script + Claude Code hook has a `tests/test-<base>.sh` unit test suite. Tests are:

- **Bash 3.2 + BSD coreutils portable** (matches the C-23 portability target the harness already enforces for substrate scripts).
- **Native assertions** (no `bats` / `shellspec` / `pytest` / external test-framework dependency).
- **Exit-code-contract focused** — each test asserts a documented exit code per the script's `-h`/`--help` block + originating ADR.
- **Self-cleaning** — setup creates needed artifacts; teardown restores baseline so the test is idempotent across runs.
- **Restore-before-assert** — for any test that mutates state (lockfile, manifest, generator output), restoration happens BEFORE the assertion so a failing test still leaves the tree clean.

## Run

```bash
./tests/test-all.sh              # verbose; per-suite output
./tests/test-all.sh --quiet      # one line per suite (PASS/FAIL)

# Individual suites:
./tests/test-emit-manifest.sh
./tests/test-emit-manifest.sh --quiet
```

`tests/test-all.sh` exits 0 only when every suite exits 0.

## Coverage (100% substrate surfaces)

| Substrate surface | Test suite | Assertions |
|---|---|---|
| `scripts/sync-plugin.sh` | `tests/test-sync-plugin.sh` | 6 |
| `scripts/audit-doc-drift.sh` | `tests/test-audit-doc-drift.sh` | 8 |
| `scripts/audit-manifest.sh` | `tests/test-audit-manifest.sh` | 8 |
| `scripts/emit-manifest.sh` | `tests/test-emit-manifest.sh` | 21 |
| `scripts/export-cursor-rules.sh` | `tests/test-export-cursor-rules.sh` | 7 |
| `scripts/smoke-e2e.sh` | `tests/test-smoke-e2e.sh` | 7 |
| `.claude/hooks/post-tool-use-review-gate.sh` | `tests/test-post-tool-use-review-gate.sh` | 8 |
| `.claude/hooks/session-start.sh` | `tests/test-session-start.sh` | 7 |
| `.claude/skills/orchestrating-swarms/SKILL.md` (Step 5 collection contract) | `tests/test-orchestrating-swarms.sh` | 19 (per TICKET-025 / ADR-0030; Step 4 worktree spawn remains operator-attested by design) |
| `scripts/audit-rulebook-coverage.sh` | `tests/test-audit-rulebook-coverage.sh` | 12 (per TICKET-026 / ADR-0031; Fowler #1 closure) |
| `scripts/audit-cross-references.sh` | `tests/test-audit-cross-references.sh` | 8 (per TICKET-027 / ADR-0032; Fowler #3 closure via approval-baseline pattern; `tests/cross-references-baseline.txt` is the technical-debt registry) |
| `scripts/audit-hook-security.sh` | `tests/test-audit-hook-security.sh` | 9 (per TICKET-029 / ADR-0034; Musk Engineering Leadership letter #4 closure via S-1..S-6 shell-pattern scan + `tests/hook-security-baseline.txt` approval-baseline) |
| `scripts/audit-metrics.sh` | `tests/test-audit-metrics.sh` | 17 (per TICKET-030 / ADR-0035; Musk Engineering Leadership letter #3 closure via DORA Four Keys computed from `.harness/audit/*.manifest.json` corpus; fixture corpus exercised) |
| `scripts/audit-claude-code-compat.sh` | `tests/test-audit-claude-code-compat.sh` | 9 (per TICKET-031 / ADR-0036; host-CLI version-range check; semver boundary tests) |
| `.claude/hooks/post-tool-use-review-gate.sh` (payload contract) | `tests/test-hook-contracts.sh` | 15 (per TICKET-031 / ADR-0036; golden fixtures at `tests/fixtures/hook-payloads/` pin the Claude Code hook payload contract; 4 scenarios + defensive missing-field test) |
| `scripts/audit-plugin-surface.sh` | `tests/test-audit-plugin-surface.sh` | 9 (per TICKET-032 / ADR-0037; injected-unknown-surface; declaration registry contract) |
| `scripts/standards-sync.sh` | `tests/test-standards-sync.sh` | 16 (per TICKET-032 / ADR-0037; aggregator wrapper; freshness `--check` contract; rule-count + namespace assertions) |
| `scripts/audit-standards-conformance.sh` | `tests/test-audit-standards-conformance.sh` | 17 (per TICKET-032 / ADR-0037; pre-commit conformance gate; deviation registry contract; +registry breadth + 8-namespace fullstack/cloud coverage per TICKET-051 / ADR-0049) |
| `scripts/audit-eo-governance.sh` | `tests/test-audit-eo-governance.sh` | 12 (per TICKET-050 / ADR-0048; EO non-exemptibility + two-phase `eo_design_conformance` attestation; +green-only-bite + `deviated`-tolerance edge cases per TICKET-051 / ADR-0049) |
| `scripts/audit-source-citations.sh` | `tests/test-source-citations.sh` | 17 (per TICKET-051 / ADR-0049; authoritative-source citation-integrity gate — PART A registry provenance/namespace coverage incl. fullstack+cloud, PART B source-doc integrity incl. the TIER-0 corpus) |
| **Total** | **20/20 testable surfaces** | **~235 assertions** |

**100% surface coverage** = every executable substrate file has at least one test suite asserting its documented exit-code contract. Each test suite covers the script's:

- Documented exit codes (0 / 1 / 2 per script's `--help` block + originating ADR)
- Documented failure modes named in the ADR
- Key invariants (e.g., `emit-manifest.sh --regenerate` NEVER overwriting the original)
- Output-format assertions where the format is contract (JSON parseable; required fields present)

**What "100% surface coverage" does NOT claim:**

- Not measured by `kcov` / `bashcov` line coverage. No bash coverage tool is installed in this environment; coverage is exit-code-branch-enumeration per ADR-0028 §Decision-3.
- Not mutation coverage. The assertions verify contracts, not implementation details.
- Not exhaustive input-space coverage. Edge cases like disk-full / mktemp failure / fork-bomb are not exercised (un-triggerable without breaking the environment).

This is the pragmatic 100% Fowler / Beck would advocate for: behavior coverage, not vanity metrics. Honest reporting of what IS and IS NOT tested.

## Convention for new test suites

When you ship a new substrate script:

1. Ship `tests/test-<base>.sh` in the same CL as the script.
2. Mirror the existing template: `set -u`, `assert_eq` + `assert_file_exists` helpers, `--quiet` flag, restore-before-assert pattern.
3. Cover the script's documented exit-code contract (0/1/2) + documented failure modes per the ADR.
4. Update the coverage table above with the row for the new script.
5. NO `bats` / `shellspec` / `pytest` / external framework — keep bash 3.2 + BSD portable.
6. Run `./tests/test-all.sh` pre-commit to ensure all suites still pass.

## CI integration (deferred)

`tests/test-all.sh` is designed to be a CI entry point (single command; exits 0 on all-pass). A GitHub Actions workflow that runs `tests/test-all.sh` + `scripts/audit-doc-drift.sh` + `scripts/smoke-e2e.sh` on every push is deferred per ADR-0028 §Out-of-scope (trigger: first PR-driven external contribution). Until then, pre-commit local runs are the gate.
