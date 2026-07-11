# ADR-0094 — Plugin pin bump `16e9623` → `724fc4c` (adopt CTP CL-562 §31.9 — P-18 acquisition-sufficiency capability with tech-canonical source registry + whole-source acquisition + no cap + sufficiency signal, PLUS G-3/G-4 fix bridging `--stack-add <tech>` to the S-58 resolver, PLUS G-2 clarification recording that `full_surface_revealed=<n>` IS the shipped §30.7 Stage-0 reveal)

- **Status:** Accepted
- **Date:** 2026-07-10
- **Deciders:** operator (`drumfiend21`; 2026-07-10: after KA-2 empirical finding that Vue acquisition against a 5-line stub yielded 3 rules — insufficient — declared a hard ≥30-rule floor per stacked technology; GCTP filed P-18 at TICKET-127 with the CTP/GCTP split; CTP built + shipped all four §2 items same-day at CL-562 `724fc4c` and also fixed the G-3/G-4 `--stack-add vue` bridge and clarified G-2 as the announced §30.7 shipping — three surfaces adopted in one bump) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** After the P-15 arc adoption at ADR-0092 (pin `b886658`) and the post-adoption fetch-wrapper + `--explain` mode adoption at ADR-0093 (pin `16e9623`), KA-2 (TICKET-126, `5b64eb1`) surfaced the ≥ 30-rule quality floor requirement. GCTP filed P-18 at TICKET-127 (`0bb32fa`) with the CTP/GCTP split. CTP built the four capability items (source-registry with 16 tech-canonical URLs including `vue → vuejs.org/style-guide + guide`; whole-source acquisition when a source's `applies_to` matches the tech name; `--max-rules 500` cap raised for canonical sources; new `rule_count=<n> sufficiency=ok|below-threshold-<N>` signal on the `acquire-technology-live.sh` summary line with `--threshold` default 30) at CL-562 §31.9. CTP additionally fixed the KA-2 G-3/G-4 gap (`--stack-add <tech-name>` now bridges to the S-58 resolver and activates the tech's family — `--stack-add vue` populates `families_active: [frontend]`) and clarified that KA-2's G-2 finding (`full_surface_revealed=<n>` in classify output) IS the previously-shipped §30.7 Stage-0 reveal, not an unannounced P-14 partial ship.
- **Continues:** the pin chain ADR-0072 → ADR-0079 → ADR-0085 → ADR-0086 → ADR-0087 → ADR-0088 → ADR-0089 → ADR-0090 → ADR-0091 → ADR-0092 → ADR-0093 → this ADR (`16e9623 → 724fc4c`).
- **Process:** §15-gated pin bump (upstream `docs/architecture-v1.9.md` contract hash changes — §31.9 appended; hash `e2e0576e… → 594614b3…`; other 4 contract files byte-identical). **Consumer-side reconciliation on GCTP is zero for the P-18 capability** — the four §2 items are additive on the CTP side; GCTP consumes via the new sufficiency signal on the acquisition summary line (planned as `scripts/audit-acquisition-sufficiency.sh` at TICKET-127.a per the P-18 handoff §3, startable NOW). G-3/G-4 fix is behavior-only inside CTP's classifier — no GCTP consumer surface change. G-2 clarification is documentary — `full_surface` block on the profile is already tolerated by `scripts/consult.sh --validate-profile` as an additive-optional top-level field (pre-P-15 additive-optional discipline).

## Compatibility verdict (verified `16e9623 → 724fc4c`)

| Check | Result |
|---|---|
| Span | **1 semantic CTP CL** (CL-562 §31.9 shipping four capability items: `standards/technology-source-registry.yaml` with 16 tech-canonical URLs, `acquire-technology-live.sh` whole-source acquisition when source's `applies_to` matches tech + `--max-rules 500` cap on canonical + `rule_count=<n> sufficiency=ok\|below-threshold-<N>` signal with `--threshold` default 30, PLUS G-3/G-4 fix in `full-surface-intake.sh` bridging `--stack-add <tech-name>` to the S-58 resolver) plus the aligned §31.9 architecture record |
| upstream `docs/architecture-v1.9.md` | **CHANGED** — **purely additive**: §31.9 BUILT record appended (+9/-0 lines; verified `git -C cache diff 16e9623..724fc4c -- docs/architecture-v1.9.md \| grep -cE '^-[^-]'` returns 0; ADR-0047 additive-only invariant preserved) |
| `CLAUDE.md` + 3 consumed `SKILL.md` | **all byte-identical** — verified via `sync-plugin.sh --check` (0 files drifted on 4 of 5 at new pin) |
| `active.json` | **118 → 118 rules byte-identical** — verified via `standards-sync.sh` regeneration; §31.9 adds new capability (canonical source list + whole-source semantics + sufficiency signal) but no authored global rules; the source-registry entries live at `standards/technology-source-registry.yaml` (a new NON-active-json artifact) |
| GCTP schema tolerance (TICKET-121.a) | **unchanged** — §31.9 touches acquisition + intake command surfaces, not the workload_classification profile shape; 17 P-15 assertions in `tests/test-consult.sh` pass unchanged |
| GCTP invariant-4 enforcement (TICKET-121.b) | **unchanged** — XC_PROJECT_ID scoping not touched by §31.9; 11 P-15 assertions in `tests/test-audit-architecture-crosscheck.sh` pass unchanged |
| GCTP preservation (TICKET-121.c/TICKET-122) | **unchanged** — nested `generated-code-quality-standards/_project/` path preserved across the pin bump per the corrected preservation logic |
| GCTP Phase 1 E2E (TICKET-123.a) | **unchanged** — `resolve-technology.sh` terse-marker output preserved as default at new pin; 41 A1–A4 assertions in `tests/test-p15-family-activation.sh` pass unchanged |
| P-18 live verification at new pin | `acquire-technology-live.sh --technology vue --project FEATURE-003 --cache <34-line-canonical-stub>` returned `sources_matched=6 sources_fetched=1 acquired_total=34 rule_count=34 sufficiency=ok technology=vue project=FEATURE-003` — the ≥ 30-rule floor is met by canonical whole-source acquisition against a realistic canonical stub |
| G-3/G-4 fix live at new pin | `full-surface-intake.sh --classify --stack-add vue` no longer emits `unknown-namespace`; instead activates the frontend family (`activated_probes` grows to 5 for a bare vision + vue add) |
| Full suite | `test-all.sh --no-cache` **43/43** green |

## G-1 diagnosis (recorded here for durability — CTP's specific ask)

CTP requested the exact SoftArchCert vision text to definitively diagnose whether KA-2's G-1 finding was a regression or a precision-tightening. GCTP ran the classifier at BOTH pins `11126a8` (KA-1 baseline) and `724fc4c` (this new pin) on the exact vision:

```
Certifiable, Inc. certifies IT professionals. Their exam process mixes
multiple-choice, short-answer, and case-study questions. Multiple-choice
is auto-graded; short-answer and case-study are graded by ~300 retired
subject matter experts. They want to adopt generative AI to automate
grading and question generation and handle 10x growth without losing
certification credibility or violating candidate trust.
```

**Result: identical output at both pins.**

| Pin | workload_types | activated_probe_namespaces |
|---|---|---|
| `11126a8` (KA-1 baseline) | `['baseline-quality']` | `['documentation', 'observability', 'owasp']` |
| `724fc4c` (this new pin) | `['baseline-quality']` | `['documentation', 'observability', 'owasp']` |

**Diagnosis: G-1 is a FALSE ALARM absorbed.** No classifier regression between pins. KA-1's persisted `intake/stage-0-classifier.json` recorded 6 activated probes (`documentation, european-union, observability, owasp, security-governance, us-government`) plus workload_type `ai-governed` — but that persisted artifact was captured through a different code path (likely `kata.sh` injecting additional context from Stage-1 answers, or a multi-pass invocation) rather than from `WORKLOAD=<vision-only>` to the classifier. When run classifier-on-pure-vision at either pin, the output is deterministic and identical. KA-2 gaps-log is updated to reflect G-1 ABSORBED (false alarm) — the classifier behavior CTP shipped at §31 + §30.4/§30.5 (family-activation adds namespaces, never removes; word-boundary matcher precedes 11126a8) is consistent with this finding.

## Decision

Bump the pin `16e9623 → 724fc4c` — upstream HEAD carrying CL-562 §31.9. This adopts three composed CTP surfaces:

1. **P-18 acquisition-sufficiency capability (CTP's four §2 items).**
   - **2.1 tech-canonical source registry** (`standards/technology-source-registry.yaml`) with 16 technologies including `vue → vuejs.org/style-guide + guide`, `angular → angular.io/docs`, etc. OFFICIAL and PR-only.
   - **2.2 whole-source acquisition semantics** — when a source's `applies_to` matches the technology name (single-tech applies_to), `acquire-technology-live.sh` acquires the whole source without the `--only-mentioning` filter, since the entire source IS the tech's canonical documentation.
   - **2.3 no artificial cap** — canonical acquire uses `--max-rules 500`.
   - **2.4 sufficiency signal** — `rule_count=<n> sufficiency=ok|below-threshold-<N>` on the `acquire-technology-live.sh` summary line, with `--threshold` (default 30) matching the operator-declared floor.

2. **G-3/G-4 fix — `--stack-add <tech-name>` bridges to the S-58 resolver.** A technology token committed via `--stack-add` now activates its family (populating `family_activated` + `families_active`) instead of failing cite-or-decline with `unknown-namespace`. Real namespaces (`k8s`, `owasp`) still take the namespace route; unknown tokens still get rejected. This closes the KA-2 G-3 and G-4 gaps in one fix — the S-58 resolver was the missing bridge, now wired in.

3. **G-2 clarification — `full_surface_revealed=<n>` IS the shipped §30.7 reveal.** Not an unannounced P-14 partial ship. The marker was announced at §30.7's shipping. GCTP-side impact: `scripts/consult.sh --validate-profile` already tolerated the `full_surface` top-level field additively; no schema change needed. TICKET-119.b (P-14 corpus amendment) DROPPED — P-14 is de-facto adopted at the moment §30.7 landed in CTP.

## What §31.9 delivers (the substantive change)

1. **≥ 30-rule floor is achievable by construction.** Canonical whole-source acquisition against real canonical docs (vuejs.org/guide, angular.io/docs, etc.) will produce dozens to hundreds of rules per technology. Verified live at this pin with a 34-line stub: `acquired_total=34 sufficiency=ok`.
2. **Sufficiency signal is honest.** Below-threshold acquisitions report the shortfall (e.g., `sufficiency=below-threshold-27`), never silently pass. Fail-loud on quality-floor.
3. **`--stack-add vue` operator UX works as intended.** The whole point of §31 family-activation — that naming Vue at Stage 0 fires the frontend umbrella — now works from the `--stack-add` operator surface, not only from the JSON output of the standalone S-58 resolver.
4. **G-1 laid to rest empirically.** The KA-2 diagnostic ("classifier probes dropped 6→3") turned out to be a mismatch between fresh-classifier-output and a KA-1 persisted artifact captured through a different code path — not a regression.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `724fc4c`; `docs/architecture-v1.9.md` sha256 updated (`e2e0576e… → 594614b3…`); other 4 contract-file hashes unchanged.
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `724fc4c` via `sync-plugin.sh --ensure` (0 drift at new pin); nested `_project/` preservation logic unchanged.
- **`.harness/rules/active.json`**: 118 → 118 rules byte-identical (§31.9 adds capability + registry, not authored global rules).
- **`docs/upstream-ctp-proposals.md §P-18`**: flipped **FILED → ✅ ADOPTED** at `724fc4c`.
- **KA-2 gaps-log** (`.harness/consult-work/FEATURE-003/gaps-log.md`): G-1 status flipped **DISCOVERED → ABSORBED (false alarm)** with the diagnosis recorded; G-2 flipped **DISCOVERED → ABSORBED (§30.7 shipped as announced)**; G-3 + G-4 flipped **DISCOVERED → CLOSED** (fixed at CTP-side CL-562 §31.9). Remaining KA-2 open gaps: G-5 ABSORBED (timestamp), G-6 GCTP-owned (TICKET-125.a fetch orchestrator).
- **`docs/handoff-ctp-post-adoption-pending-items.md`**: item 3 (P-14 §30.7) flipped to note it was announced at §30.7 shipping per CTP's G-2 clarification; no longer a genuinely pending item.
- **TICKETS.md**: TICKET-128 row added (this pin bump), DONE, pointing at this ADR.
- **Follow-up GCTP-side tickets startable NOW**: TICKET-127.a (`scripts/audit-acquisition-sufficiency.sh` per P-18 §3), TICKET-125.a (fetch orchestrator), TICKET-124 (kata.sh P-15+P-18 awareness including the new `--stack-add <tech>` bridge), TICKET-124.a (`/consult` skill `--explain` consumption), TICKET-129 (KA-3 kata attempt).

## Consequences

**Positive.**

- **Operator's ≥ 30-rule floor is now achievable end-to-end** by canonical whole-source acquisition against real tech-canonical docs. The pipeline capability + the source coverage + the honest sufficiency signal complete the P-18 CTP-side story.
- **`--stack-add <tech>` operator UX now matches P-15 §31's design intent** — the family-activation surface finally works from the intake command, not only via the standalone resolver.
- **Three KA-2 gaps closed in one bump** (G-1 diagnosed as false alarm, G-2 clarified as design intent, G-3/G-4 fixed). Only G-6 (GCTP-side fetch orchestrator) remains open post-adoption — and it was always GCTP-owned per the boundary CTP established at CL-561.
- **Consumer-side reconciliation stays zero** for the fifth pin bump in a row. All 43 test suites pass unchanged.
- **Additive per ADR-0047 by construction.** Source-registry entries added (never subtracted); whole-source semantics gated on positive match (never over-includes); sufficiency signal is optional-additive.

**Negative / knowingly accepted.**

- **Fetch orchestrator gap remains genuinely on GCTP** (TICKET-125.a). Without it, KA-3's real Vue acquisition still needs manual URL→cache population. CTP's honest boundary reminder in the CL-562 handoff (network fetch stays with the harness) applies here too.
- **KA-2 gaps-log entry for G-1 was in error.** The KA-2 attempt's "regression" claim was based on a mis-comparison between a persisted artifact and a fresh-classifier-run. Meta-lesson: any kata gaps-log entry comparing against KA-N persisted artifacts must first reproduce the artifact from scratch at both pins.

**Neutral.**

- `active.json` unchanged (118 → 118 byte-identical). §31.9 adds capability + registry, not authored rules.
- P-14 (§30.7) reveal was shipped at some earlier point per CTP's G-2 clarification. GCTP historical records treated it as still-pending; this ADR corrects the record.
- Pin chain now runs nine-deep in the KATA cycle (ADR-0086 → ADR-0094). Each pin closes a distinct KATA-discovered issue or shipped feature.

## Rollback

`git revert` this commit → lockfile snaps back to `16e9623`; `technology-source-registry.yaml` disappears; canonical whole-source acquisition reverts to `--only-mentioning`-only; `rule_count`/`sufficiency` signals disappear from `acquire-technology-live.sh` summary; `--stack-add vue` reverts to cite-or-decline `unknown-namespace` rejection. GCTP's schema tolerance + invariant-4 enforcement + preservation logic + E2E family-activation tests all continue to pass (additive-optional; degrade gracefully). No downstream schema migration required.

## References

- CTP §31.9 (BUILT record): `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §31.9` @ `724fc4c`
- CTP CL-562 (P-18 §2 items + G-3/G-4 fix): `.harness/plugin-cache/claude-tdd-pro/standards/technology-source-registry.yaml` + `commands/acquire-technology-live.sh` (whole-source + `--threshold` + sufficiency signal) + `commands/full-surface-intake.sh` (`--stack-add <tech>` bridge) @ `724fc4c`
- CTP acceptance surface: `.harness/plugin-cache/claude-tdd-pro/evals/specs/cl562-*.json` (9 specs)
- GCTP P-18 filing: `docs/handoff-ctp-p18-acquisition-sufficiency-threshold.md` @ `0bb32fa`
- KA-2 gaps-log: `.harness/consult-work/FEATURE-003/gaps-log.md` (KA-2 section; G-1 flipped to ABSORBED with diagnosis)
- Preceding pin bumps: ADR-0092 (P-15 §31/§31.1/§31.2/§31.3/§31.4) → ADR-0093 (§31.8 wrapper + `--explain`)
- Additivity invariant: ADR-0047
- Operator-declared-standards regime: ADR-0037 (P-18's ≥ 30-rule floor is a TIER-1 member; GCTP-side gate landing at TICKET-127.a)
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model"
