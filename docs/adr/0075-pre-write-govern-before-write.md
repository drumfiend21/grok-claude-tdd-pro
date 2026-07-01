# ADR-0075 — Pre-write govern-before-write governor (adopt §28.60/§28.68; the operator §4 tools→pre-write decision)

- **Status:** Accepted
- **Date:** 2026-06-30
- **Deciders:** operator (`drumfiend21`; §4 decision recorded in ADR-0072 — *"move tool-based enforcement to pre-write"*; 2026-06-30: *"proceed … build + land CL-C"* and *"wire the §4 tools half forward-ready now (inert until P-10)"*) + Claude Opus 4.8 (local session).
- **Trigger:** **CL-C** of the ADR-0072 "Known follow-up" #2 wiring backlog — the headline of the `4668c2e` adoption. Adopts CTP **§28.60** (govern-before-write) + **§28.68** (both-paths pre-write). Depends on ADR-0074 (development-path tagging) for the eventual partition.

## Decision

Register a harness **PreToolUse** hook — `.claude/hooks/pre-tool-use-govern.sh` (wired in `.claude/settings.json`, matcher `Edit|Write|MultiEdit`) — that governs the **proposed content in memory before it is written**:

1. **Native gate (§28.60):** delegates to the plugin's `hooks/scripts/enforce-standards-pre-write.sh`, which reconstructs the proposed content (Write→content; Edit/MultiEdit→current file with the replacement(s) applied) and runs `rubric/enforce-file.sh`. A P0/P1 violation **denies the write (exit 2)**.
2. **§4 tools half (operator decision):** the wrapper ALSO reconstructs the content and runs `rubric/composite-dispatch.sh` (routed FOSS tools) with **parse-then-block** (the ADR-0068 W-C discipline) — deny only on an authoritative `composite-dispatch … status=red` line. This honors the §4 "move tools to pre-write" decision. It is **forward-ready but INERT on bash 3.2** until upstream **P-10** (the `composite-dispatch` `ra[@]` crash) is fixed — a crash exits 1 with no authoritative line, which parse-then-block correctly ignores.

### Scope — app_root only (agent-operating-compact)

The governor fires **only on writes under the `app_root`** (the external product tree, resolved via `scripts/app-root.sh`). **Harness self-maintenance writes** (this repo's own docs/scripts) are **EXEMPT** and pass through — the compact confines app-architecture enforcement to the product GCTP builds, not the harness itself. With no `.harness/app.json` configured, the hook is a **vacuous no-op** (resolves no app_root → exit 0), so registering it does not change behavior in this harness repo; it activates only when an operator points GCTP at a real product.

### Fail-open

Any missing dependency, unparseable hook input, or defense-trip → **exit 0** (allow). A hook bug must never block the session. Prime directive: the plugin scripts are consumed by reference from the pinned cache, never edited.

## Consequences

### Positive
- Content is governed **as it is generated to memory** — a violating product file is never persisted (native today; native + routed tools once P-10 lands).
- The §4 decision is wired, not just recorded; the tools half activates automatically when P-10 is fixed.

### Neutral
- Vacuous + inert in this harness repo (no app_root; P-10 on the tools half). The PostToolUse `enforce-standards-on-save.sh` backstop (CL-D, forthcoming) remains the complementary after-write path.

### Negative / cost
- One more hook on the write path (fast-exits out-of-scope). The tools half spawns `composite-dispatch` (which currently crashes and is ignored) — a small wasted spawn until P-10.
- **Depends on P-10** for the tools half to produce verdicts on bash 3.2.

## Verification (executed before commit)
- `tests/test-pre-tool-use-govern.sh` — 8/8 hermetic (non-edit→allow; no app_root→vacuous; outside app_root→exempt; inside+native-deny→2; §4 authoritative status=red→2; §4 crash→allow [P-10 inert]; native+composite-green→allow; unparseable→fail-open).
- Live in this repo: the hook is **vacuous** (no `.harness/app.json`) — confirmed exit 0 on a sample Write; does not govern harness self-maintenance.
- `.claude/settings.json` valid JSON; `audit-hook-security` refreshed for the new hook's bounded `rm` (reviewed).
- No `claude-tdd-pro` path touched (prime directive). D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- Hook: `.claude/hooks/pre-tool-use-govern.sh` · Registration: `.claude/settings.json` · Tests: `tests/test-pre-tool-use-govern.sh`
- Consumed entrypoints: `hooks/scripts/enforce-standards-pre-write.sh` (§28.60), `rubric/composite-dispatch.sh` · Partition: ADR-0074 (`classify-path.sh`)
- Discipline reused: ADR-0068 W-C parse-then-block · Upstream dependency: `docs/upstream-ctp-proposals.md` §P-10 · Backlog: ADR-0072 KFU #2
