# ADR-0034 — Musk Engineering Leadership letter closure: onboarding + security audit (#4 + #5) (TICKET-029)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 directive: *"Address and incorporate the feedback from my previous prompt in 30 mins or less"* — closing Musk Engineering Leadership letter #5 fully + #4 partially) + Claude (cloud session, implementer)
- **Second voice (per ADR-0029 pattern; 5th application):** Simulated Musk Engineering Leadership review letter (xAI / Tesla / SpaceX lens), recorded as the §1 trigger below. Musk's literal closing prescription: *"Do These Now: 1. Benchmark Velocity. 2. Dogfood on Real Project. 3. Add Metrics. 4. Security Review — The harness has substantial code-execution surface (hooks fired on tool use; substrate scripts invoked at session start + pre-commit; Grok templates fed to LLM-driven agents). Audit it once, codify the audit as a re-runnable script, and ship a baseline. 5. Simplify Onboarding — Cut QUICKSTART to one screen: clone, sync-plugin, smoke-e2e, done. Anything else moves into 'further reading'."* The letter IS the second voice; this CL ships #4 partially + #5 fully and defers #1, #2, #3 with explicit triggers.
- **Trigger:** Per the Musk Engineering Leadership letter received 2026-05-26 (recorded in `AUTOMATION_INTEL.md`). The letter named 5 "Do These Now" actions. This CL closes #5 (onboarding) fully and #4 (security review) at v1 scope; #1, #2, #3 are explicitly deferred with named triggers per the over-engineering filter.
- **Supersedes:** N/A (additive).
- **Extends:** ADR-0029 (`Second voice` field — 5th application; Musk letter is the second voice); ADR-0032 (approval-baseline pattern — `audit-hook-security.sh` follows the same pattern as `audit-cross-references.sh`); ADR-0028 (substrate-script test discipline — `test-audit-hook-security.sh` brings substrate test coverage to 12/12 surfaces); CLAUDE.md §QUICKSTART pointer (QUICKSTART §0 is the new "fastest path" entry point).

## Context

The 2026-05-26 Musk Engineering Leadership review letter (received after the 4-team A− regrade in ADR-0033) graded the harness through xAI/Tesla/SpaceX lens. Musk's specific prescription contained 5 named "Do These Now" actions:

1. **Benchmark Velocity** — measure end-to-end time-to-green-ticket on a benchmark task.
2. **Dogfood on Real Project** — operator uses the harness daily for 2-4 weeks on a real codebase.
3. **Add Metrics** — DORA-style scoreboard with real numbers, not just principle citations.
4. **Security Review** — code-execution surface audit, codified as a re-runnable script + baseline.
5. **Simplify Onboarding** — QUICKSTART cut to one screen: clone, sync-plugin, smoke-e2e, done.

Per the over-engineering filter applied to each:

- **#1 Benchmark Velocity** — REQUIRES a benchmark task + a stopwatch + a comparable baseline. Filter: operator-bitten threshold met (Musk's voice IS the signal), but composes-on-existing-primitives is WEAK — no benchmark task exists in the repo, no comparable baseline exists. Shipping a synthetic benchmark here would be fabrication. DEFER to "first real project handoff" trigger.
- **#2 Dogfood** — REQUIRES 2-4 weeks of real-project use. Not a CL deliverable; a calendar deliverable. DEFER to "operator starts real project" trigger; AUTOMATION_INTEL.md records this as a pending operational milestone.
- **#3 Metrics** — REQUIRES real deployments and real lead-time data. The harness is pre-first-real-use; metrics would be synthetic. DEFER to "operator reports the one-liners in C-24 are insufficient" trigger.
- **#4 Security Review** — composes on existing primitives (`audit-cross-references.sh` pattern, the substrate test discipline, the baseline-tolerant exit policy). Operator-bitten threshold: not literally bitten yet but Musk's voice is the proxy signal; the hook surface IS substantial. SHIP at v1 scope (shell-pattern scan + baseline + test + doc + ADR).
- **#5 Onboarding** — composes on existing QUICKSTART. The new §0 is 5 lines. Operator-bitten threshold: every new-clone hits the 3-minute README path; cutting to <2 minutes is real ergonomic win. SHIP.

The over-engineering filter is calibrated such that #4 and #5 ship, #1/#2/#3 defer with explicit triggers. The deferrals are documented in `AUTOMATION_INTEL.md` so they cannot be forgotten.

## Decision

### 1. Ship #5 (Onboarding) — QUICKSTART §0 "Fastest path"

Add §0 above the existing §1 Prerequisites in `QUICKSTART.md`. Five lines: clone, ensure plugin, run smoke. The full §1+ content stays (it's the operator's depth path); §0 is the impatient-operator entry. Time budget per Musk: <2 minutes from cold clone to first green ticket.

```bash
git clone https://github.com/drumfiend21/grok-claude-tdd-pro.git && cd grok-claude-tdd-pro
./scripts/sync-plugin.sh --ensure       # ~20 seconds
./scripts/smoke-e2e.sh                  # ~5 seconds
```

If both commands exit 0, the harness is contract-valid against a pinned plugin. Operator can then proceed to TICKETS.md and pick up TICKET-029 (or the next open ticket).

### 2. Ship #4 (Security) at v1 — shell-pattern scan + baseline + test + doc + ADR

Six pattern classes (S-1..S-6) mapped to canonical CWE / OWASP attack vectors. Approval-baseline pattern matches ADR-0032 (cross-reference audit) precedent. Baseline starts at 15 entries (all S-3 bounded `rm -rf` cleanup operations); 0 findings in S-1, S-2, S-4, S-5, S-6.

`scripts/audit-hook-security.sh` exits 0 (baseline matched), 1 (new findings), 2 (script error). `tests/test-audit-hook-security.sh` has 9 assertions including state-mutating tests that use restore-before-assert.

`docs/security-review.md` is the TIER-2 codification (threat model, scan policy, baseline rationale, operator procedure, named deferrals, authority + amendment process). Not wired into pre-commit at v1 per the over-engineering filter — operator-bitten threshold not yet met.

### 3. Defer #1 #2 #3 with explicit named triggers (NOT silent deferral)

Each deferral is recorded in `AUTOMATION_INTEL.md` 2026-05-26 entry with the trigger condition:

- **#1 Benchmark Velocity** — trigger: first real-project handoff produces a measurable end-to-end time figure.
- **#2 Dogfood** — trigger: operator commits to a 2-4 week real-project window.
- **#3 Metrics** — trigger: operator reports that C-24's principle-only DORA framing is insufficient (i.e., the one-liners need numbers).

Per Musk's Algorithm step 1 ("question every requirement"), each deferral cites the specific reason: synthetic benchmark = fabrication; dogfood = calendar item not CL item; synthetic metrics = drift from C-24's "scoreboard with real numbers" stance.

## Alternatives considered

- **Ship all 5 items in one CL.** REJECTED. #1, #2, #3 require real-project data that does not exist; shipping synthetic versions would be drift from the C-24 "real numbers" principle and the founder-directives §1 immutability stance against fabrication.
- **Defer #4 too (only ship #5).** REJECTED. The security audit composes on existing primitives (`audit-cross-references.sh` pattern); the substrate is small enough to audit comprehensively at v1; Musk's named ask deserves more than a one-line onboarding fix.
- **Wire the audit into pre-commit at v1.** REJECTED. Operator-bitten threshold not yet met; the audit is on-demand + CI-via-test-all per the existing test discipline. Wiring into pre-commit can ship in a follow-on CL if a hook bug ever surfaces.
- **Ship cryptographic signing for substrate scripts at v1.** REJECTED per ADR-0018 §3 deferral (`signature: null`); KMS access + rotation requirements not in scope for v1 security audit.
- **Restructure QUICKSTART entirely to one screen.** REJECTED. The existing §1+ content is the operator's depth path; cutting it would orphan content. §0 is the impatient-operator entry; §1+ stays for depth.

## Consequences

### Positive

- **Musk #5 closed.** QUICKSTART §0 is the <2-minute path; operator can verify a green harness in under 30 seconds of actual command time (most of which is the plugin clone).
- **Musk #4 closed at v1.** Security audit shipped + baseline shipped + test shipped + TIER-2 doc shipped + ADR shipped. The substrate's shell-pattern attack surface is now inventoried, scanned re-runnably, and operator-reviewable.
- **Substrate test coverage 12/12.** Adding `test-audit-hook-security.sh` brings the test surface from 11/11 to 12/12.
- **Approval-baseline pattern applied a 3rd time.** Precedent: ADR-0032 (cross-reference audit), ADR-0033 (rulebook coverage audit), now ADR-0034 (hook security audit). The pattern is now demonstrably a harness convention.
- **Per ADR-0029 `Second voice` field demonstrated for the 5th time.** The Musk Engineering Leadership letter is the second voice; this ADR's `Second voice` field quotes it explicitly.
- **AUTOMATION_INTEL.md gains 2026-05-26 entry** documenting the letter receipt + the deferred triggers for #1, #2, #3 so they cannot be forgotten.
- **R-3 honored.** No new content paths duplicate existing docs; the security doc cross-references existing patterns (audit-cross-references precedent, ADR-0028 test discipline, ADR-0018 signature deferral) instead of restating them.

### Negative

- **#1 #2 #3 remain open.** Mitigation: each is named with trigger in this ADR + AUTOMATION_INTEL.md; trigger conditions are observable (real-project handoff; calendar commitment; operator one-liner-insufficient report).
- **Security audit covers shell patterns only at v1.** MCP-server audits, hook input-validation analysis, Grok template prompt-injection patterns all DEFERRED (named in `docs/security-review.md §7`). Mitigation: trigger conditions named per deferral.
- **No pre-commit integration of the security audit at v1.** Mitigation: audit runs in `tests/test-all.sh`; trigger for pre-commit wiring is the first operator-reported hook bug.

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **Plugin pin unchanged** (`23e5c2b` per ADR-0025).
- **Wire-format `schema_version` unchanged.**

## Verification (executed before commit)

- `./tests/test-audit-hook-security.sh` exits 0 with 9/9 passing.
- `./scripts/audit-hook-security.sh --quiet` exits 0 (baseline matched).
- `./tests/test-all.sh --quiet` shows 12/12 suites passing.
- Full audit chain: audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest + audit-cross-references + audit-hook-security all exit 0.
- `git diff docs/founder-directives.md` shows 0 lines (D-6 honored; no §1 or §3 changes).
- ADR-0034 follows the numbered ADR template + `Second voice` field present (5th application).
- `docs/security-review.md` present + grep-discoverable + listed in AGENTS.md §5.
- `.cursor/rules/agent-context.mdc` regenerated to include the new TIER-2 doc.
- QUICKSTART.md §0 present + grep-discoverable.
- `tests/README.md` coverage table updated to 12/12 surfaces.

## Out of scope (deferred per filter)

- **#1 Benchmark Velocity** — DEFERRED; trigger: first real-project handoff produces a measurable end-to-end time figure.
- **#2 Dogfood** — DEFERRED; trigger: operator commits to a 2-4 week real-project window.
- **#3 Metrics with real numbers** — DEFERRED; trigger: operator reports C-24's principle-only DORA framing insufficient.
- **Cryptographic substrate signing.** DEFERRED per ADR-0018 §3.
- **Pre-commit wiring of `audit-hook-security.sh`.** DEFERRED; trigger: first operator-reported hook bug.
- **Reachability analysis** (which hook fires for which tool). DEFERRED per `docs/security-review.md §7`.
- **MCP-server permission audits.** DEFERRED; trigger: harness adopts a self-hosted MCP server.
- **Hook input-validation pattern coverage** (beyond S-1 / S-6). DEFERRED; trigger: operator-reported hook bug.
- **Grok template prompt-injection scanner.** DEFERRED; trigger: downstream agent ever follows template-embedded instructions.

## Implementation references

- New: `scripts/audit-hook-security.sh` (~120 lines, bash 3.2 + BSD portable)
- New: `tests/hook-security-baseline.txt` (15 entries; all S-3 bounded `rm -rf` cleanup)
- New: `tests/test-audit-hook-security.sh` (9 assertions; restore-before-assert pattern)
- New: `docs/security-review.md` (TIER-2 operational rulebook; 9 sections)
- New: this ADR
- Modified: `QUICKSTART.md` (new §0 "Fastest path — your first green ticket in <2 minutes")
- Modified: `AGENTS.md §5` (TIER-2 enumeration adds `docs/security-review.md`)
- Modified: `scripts/export-cursor-rules.sh` (`gen_agent_context` TIER-2 list adds the new doc)
- Regenerated: `.cursor/rules/agent-context.mdc`
- Modified: `AUTOMATION_INTEL.md` (2026-05-26 entry: Musk-letter receipt + deferred triggers for #1, #2, #3)
- Modified: `TICKETS.md` (TICKET-029 row marked DONE)
- Modified: `tests/test-all.sh` (registers `test-audit-hook-security.sh` in the suite)
- Modified: `tests/README.md` (coverage table 11/11 → 12/12 surfaces)
- Related: ADR-0029 (Second voice field — 5th application), ADR-0028 (substrate-script test discipline this CL extends), ADR-0032 (cross-reference audit — approval-baseline precedent), ADR-0018 (`signature: null` deferral that this CL honors).
