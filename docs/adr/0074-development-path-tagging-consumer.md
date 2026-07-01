# ADR-0074 — Adopt development-path tagging (§28.63) — validation gate + partition foundation for both-paths pre-write

- **Status:** Accepted
- **Date:** 2026-06-30
- **Deciders:** operator (`drumfiend21`; 2026-06-30: *"proceed with the architecture as planned in the handoff"*) + Claude Opus 4.8 (local session).
- **Trigger:** the CL-C..N wiring backlog registered in ADR-0072 "Known follow-up" #2. This is **CL-I** — the first genuinely-new-surface wiring after CL-B's bugfix. It adopts CTP **§28.63 development-path tagging** (`commands/classify-path.sh`), which lands unwired at pin `4668c2e`.
- **Feeds:** CL-C (the pre-write governor). §28.68 both-paths pre-write enforcement partitions rules by development path — a codesigned project's **IaC** artifacts are governed by the `iac`+`both` sets, its **application code** by the `fullstack`+`both` sets. That partition presupposes **every** rule resolves to ≥1 path.

## Decision

Wire `classify-path.sh` as a **consumed** plugin entrypoint via a new harness audit, `scripts/audit-development-paths.sh`:
- Runs `classify-path.sh --audit` (which classifies every corpus rule via the deterministic §28.63 derivation) and asserts the summary reports **`unpathed=0`**. An unpathed rule is a partition gap (it would fall through both-paths enforcement) → **red**.
- **Vacuous pass** when `classify-path.sh` is absent (pre-§28.63 cache compat) or produces no parseable summary (e.g. the Ruby prerequisite is missing) — the audit must not crash the WARN chain on an environment gap; Ruby ≥ 3.0 remains the repo-level prerequisite for the consult engine.
- Wired into `session-start.sh` (WARN) + `test-all.sh`. Sources the shared epoch library for uniformity (ADR-0071).

The path-tag **consumption** — resolving, per file, whether it is governed by the `iac`/`fullstack`/`both` set — is **deferred to CL-C** (the pre-write governor), which calls `classify-path.sh --rule-id … --applies-to …` per applicable rule to partition enforcement. This ADR delivers the *validation* that the partition is total; CL-C delivers the *partition*.

Prime directive: `classify-path.sh` is consumed by reference from the pinned cache and never edited here.

## Consequences

### Positive
- The both-paths partition's precondition (every rule pathed) is now gated, so a future CTP change that introduces an unpathed rule is caught before it silently escapes pre-write enforcement.
- Establishes the foundation CL-C builds the pre-write partition on.

### Neutral
- Vacuous when Ruby is absent (the audit degrades to a skip-with-note rather than a hard failure). At the current pin the corpus is **118 rules, all pathed** (42 `iac` / 30 `fullstack` / 46 `both`, `unpathed=0`).

### Negative
- Adds one more audit + Ruby dependency to the WARN chain (already a repo prerequisite).

## Verification (executed before commit)
- `tests/test-audit-development-paths.sh` — 7/7 hermetic (help/unknown-flag; classify-path absent → vacuous; `unpathed=0` → green; `unpathed>0` → red; no-summary/Ruby-missing → vacuous; multi-digit unpathed).
- Live run against the `4668c2e` cache: green, `classify-path total=118 … unpathed=0`.
- No `claude-tdd-pro` path touched (prime directive). D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- Audit: `scripts/audit-development-paths.sh` · Tests: `tests/test-audit-development-paths.sh`
- Consumed entrypoint: `commands/classify-path.sh` (CTP §28.63) · Consumer of the partition: CL-C (forthcoming)
- Wiring backlog: ADR-0072 "Known follow-up" #2 · Related: ADR-0071 (epoch lib), the applies-to-parity smoke gate (ADR-0070)
