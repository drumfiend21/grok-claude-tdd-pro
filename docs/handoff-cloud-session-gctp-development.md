# GCTP cloud-session handoff — continue harness development in a fresh session

**Written:** 2026-07-11 · **From:** local Claude Code session that ran the CL-564 joint-design work + KA-5 iteration.
**Purpose:** everything a NEW cloud Claude Code session (GitHub + shell + git) needs to continue developing the GCTP harness (`drumfiend21/grok-claude-tdd-pro`) without dropping this repo's discipline.
**Pairs with:** `drumfiend21/claude-tdd-pro:main:docs/handoff-cloud-session-ctp-development.md` (commit `f4b365a`) — the CTP-side handoff. Both docs are needed if the session will touch both plugins (joint-design regime, see §5).

## 0. First actions in the new session (do these before touching anything)

1. `git fetch origin && git status` in BOTH repos:
   - `/Users/siddharthjoshi/Code/Test-GCTP-June-Seventeeth/` (GCTP)
   - `/Users/siddharthjoshi/Code/claude-tdd-pro/` (CTP sibling)
2. **Read these, every session, before writing anything** (they are LAW here):
   - `CLAUDE.md` (root) — TIER-0 corpus + TIER-1 prime-directive + founder-directives + R/G/C-rule authorities; overrides default behavior.
   - `AGENTS.md` — non-Claude agents' binding surface; composes with CLAUDE.md.
   - `docs/agent-operating-compact.md` — TIER-1 behavioral contract on the agent (must be accepted via `scripts/accept-compact.sh`; hooks refuse sanctioned workflow otherwise per ADR-0057).
   - `docs/founder-directives.md` §3 D-rules + §4 D-checklist.
   - `docs/architecture-principles.md` R-rules + self-audit.
   - `docs/grok-orchestration-principles.md` G-rules + self-audit.
   - `docs/claude-tdd-pro-principles.md` §16 C-rules + §17 inner-loop self-audit.
   - `TICKETS.md` — ordered backlog, ~1 CL each.
3. **Verify test suite green** — `bash tests/test-all.sh`. Currently **44/44** at HEAD `72eaa46`. This is the analogue of CTP's `bash evals/runner.sh`.
4. **Check compact acceptance** — `bash scripts/audit-agent-compact.sh` must exit 0. If it fails, run `bash scripts/accept-compact.sh` before doing any sanctioned workflow (`/consult`, `/roadmap`, `/decompose`, `/dispatch`, `/inner-loop`, `/audit`).

## 1. Current state (durable facts)

| | |
|---|---|
| Repo | `drumfiend21/grok-claude-tdd-pro` |
| Working branch | `main` (this repo is a small harness; direct-to-main is the convention for TICKET rows and pin bumps) |
| Local `main` HEAD | `72eaa46` — 20 commits ahead of `origin/main` (all this session's TICKET-120..132 work) |
| Suite | **44/44** — `bash tests/test-all.sh` |
| CTP pin | `724fc4c` at `.harness/plugin-cache/claude-tdd-pro/` (see `.harness/plugin-lock.json`) |
| Latest kata attempt | KA-5 (FEATURE-003 SoftArchCert vision, depth 9); see `.harness/consult-work/FEATURE-003/gaps-log.md` (gitignored) |

## 2. What the joint-design regime (TICKET-132) means for you

The operator invoked a **joint-design regime** on 2026-07-11 (amendment to `CLAUDE.md` prime-directive §Joint-design regime). Under this regime:

- Boundary-contract design + cross-plugin fixes may span both GCTP and CTP within one session for coherent design.
- Prime-directive invariant 1 ("no cross-repo edits") is scope-carved: cross-plugin work is permitted.
- Invariants 2 / 3 / 4 remain fully in force:
  - GCTP still consumes CTP by PINNED reference (`.harness/plugin-cache/claude-tdd-pro/` remains read-only pinned artifact).
  - Contract-only coupling still holds (no reaching into plugin internals from GCTP scripts).
  - Independent release cadence still holds.
- **Working directories separate.** GCTP at `/Users/siddharthjoshi/Code/Test-GCTP-June-Seventeeth/`; CTP at `/Users/siddharthjoshi/Code/claude-tdd-pro/`. Never stage a CTP file in a GCTP commit; never stage a GCTP file in a CTP commit.
- Pin-bump discipline (per ADR-0092/0093/0094 precedent) NOT bypassed. CTP change lands in CTP → CTP tags a CL → GCTP §15-gated pin bump ADR → GCTP re-materializes cache.
- Rescissible — operator can revert to strict prime-directive-only mode by stating so.

## 3. What's actively in flight — CL-564 on CTP branch `cl-564-standards-refresh-orchestrator`

The joint-design work this session landed the **CL-564 registry-walker orchestrator** on CTP. Branch is at CTP HEAD `5d32889`. Two commits over that branch's original: `1e8fd07` (CL-564 v2 Option 3 hybrid) + `5d32889` (CL-564.a namespace-inference fix + 5 integration specs). All 15 specs pass manually. Fidelity gate clean. Not yet merged to CTP main. Preserves the earlier discarded work behind a revert commit (`537a498`) so history is transparent (operator directive: no remote branch deletion, no force-push).

**What CL-564 built (empirically verified, 618 rules extracted from 17 real URLs at 4-axis-tagged + FOSS-routed):**

- **`commands/standards-refresh.sh`** — the ADR-0009 line 50 registry-walker orchestrator (Option 3 hybrid). Walks a `*URLS.yaml` or `*sources*.yaml` registry, freshness-skip per `<registry>-last-fetch/<source-id>.txt` vs entry `fetch_frequency`, dispatches through `standards/fetcher.sh` (S-2) with `standards/fetchers/http-get.sh` (new generic upstream stub) honoring fragility-tier + strategy, extracts via Stage 1 with shape inferred from entry `fetcher:` field, runs Stages 2+3+4 (classify + route + architectural-content bundle auto-attach on `applies_to_prose:true`), assembles YAML with §28.40 `introduced_in` epoch tag on every rule, merges idempotently by `content_hash` (existing rules grandfathered; new rules appended; removed rules marked `deprecated:true` + `deprecated_at` + `deprecated_reason: removed-upstream`), namespace resolution per §17 G-9 (jurisdiction / source_class → target_namespace, or `applies_to[0]` for standards entries, or `_universal` fallback).
- **`commands/extract-rules-from-url.sh`** extended to all 5 ADR-0009 line 51 shapes: adds `html-sections`, `free-prose`, `pdf-sections` alongside pre-existing `markdown-headings` + `numbered-list`. Existing shapes byte-identical.
- **`standards/fetchers/http-get.sh`** — generic upstream stub activating the previously-unwired S-2 dispatch layer.
- **`docs/design/v1.26-standards-refresh-registry-walker.md`** + `docs/architecture-v1.9.md §33` (append-only per §19, 19 additions, 0 deletions).
- **15 specs at `evals/specs/cl564-refresh-01..15.json`** — unit + integration (5 shapes + http-get + orchestrator walks + freshness-skip + `--force` + content_hash idempotency + deprecated_at on removal + 4-axis tag + FOSS routing + aggregator picks up + write-time enforcement applies + many-rules-per-URL).

## 4. Extension roadmap agreed with operator (Option 3 hybrid follow-ons)

Ordered. Items 1–4 are wire-through of existing infrastructure (per the 7-week architecture already built) — no new decisions needed. Items 5–6 need operator input.

1. **Wire Stage 5** (`draft-custom-rule.sh`) into `commands/standards-refresh.sh` per emitted rule. Four-layer fidelity contract runs; capture `clauses_total / covered / fallback / unenforceable / no_clause_dropped` per rule; refuse to write file if any rule violates the `no_clause_dropped` invariant.
2. **Wire Stage 6** (`review-queue.sh`) as `--gate review-queue` opt-in. Rules stage in `_project/<crawl-id>/` first, promote to official namespace after review. Default behavior unchanged (auto-write). Human-in-the-loop stays default per §28.36.
3. **Set `applies_to_prose:true`** on rules from prose-shape sources (entry `fetcher:` ∈ `{html-anchor.sh, markdown-headers.sh, rfc-style.sh}`). Activates §28.30 architectural-content bundle auto-attach so rules fire on ADRs at design time (§29.4).
4. **Emit `rule_count=<n> sufficiency=ok|below-threshold-30` per source** (§31.9 A9 pattern). Refuse to write a source's file if 0 usable rules.
5. **Domain-crawl** — extend Stage 1 with `scope: {strategy: single-page|path-prefix|sitemap|link-follow, max_pages, max_depth, respect_robots, same_host_only, include_patterns, exclude_patterns}` per-entry field + 8 universal guards (same-host, max_pages 200, max_depth 3, robots.txt, content-type filter, content_hash dedupe, rate limit, URL length ≤2KB) + refuse-on-root-path + 6 quality guards (empty-content-density gate, low-yield skip, default exclude_patterns, confidence-density audit, follow-301/302-same-host, per-refresh crawl manifest at `.claude-tdd-pro/crawls/<sid>-<ts>.jsonl`). **PENDING OPERATOR YES/NO**: build now with proposed defaults, or wait for their explicit review of the design doc first?
6. **Node.js entry** in `standards/technology-source-registry.yaml` (currently missing; §31.9-registered techs are Vue/Angular/Svelte/Ember/Solid/Express/NestJS/Django/Rails/Spring/Go/Rust/Python). **PENDING OPERATOR CHOICE**: (a) single seed URL `nodejs.org/api/` with domain-crawl path-prefix (depends on item 5), (b) enumerate ~20 specific Node module URLs (child_process, fs, http, net, cluster, worker_threads, stream, events, crypto, dgram, dns, http2, os, path, process, readline, tls, url, vm, zlib), (c) both.

## 5. Guardrails (do not violate without explicit ask)

- **Never destructive.** No `git push --force`, no `git reset --hard`, no `git branch -D`, no `git push --delete origin`, no `rm -rf` outside `/tmp`. If you hit one you need, stop and ask.
- **Never touch `main` in CTP** — only `cl-564-standards-refresh-orchestrator` for the in-flight CL-564 arc; new arcs get their own branch (see the CTP-side handoff for CTP branching conventions).
- **Never bump the GCTP pin** at `.harness/plugin-cache/claude-tdd-pro/` — §15-gated ADR territory, operator's schedule.
- **Never file upstream proposals** in `docs/upstream-ctp-proposals.md` without operator direction — new proposals require operator go-ahead.
- **Never enable `--auto-accept` by default on review-queue.** Human-in-the-loop stays default per §28.36.
- **One commit per item with full audit body.** Follow CTP Step 0→0.5→1→2→3→4 discipline on every CTP change; follow GCTP TDD + audit-chain discipline on every GCTP change.
- **No surprises.** If a spec fails, if you hit a design ambiguity that materially changes course, if you need to touch a file the handoff hasn't named — stop and ask.
- **The agent-operating-compact governs application architecture built THROUGH GCTP for the user; NOT harness self-maintenance.** Harness self-maintenance (editing GCTP's own docs/scripts/governance) runs on the ADR + founder-directives + R/G/C-rule + per-CL TDD plane, under operator review. Conflating the two is itself a violation.

## 6. Key architecture references (do not re-derive)

- CTP `docs/adr/0007-yaml-json-md-corpora-and-prose-judge.md` — `applies_to_prose` flag; universal semantic detector.
- CTP `docs/adr/0008-composite-engine-and-4-axis-canonical-vocabulary.md` — 4-axis binding.
- CTP `docs/adr/0009-auto-classification-and-rule-drafting-pipeline.md` — six-stage pipeline; four-layer fidelity; "no clause silently dropped" contract.
- CTP §28.30 (Stage 1-3 commands), §28.33 (namespace-axis-binding), §28.34 (four-layer fidelity), §28.36 (review-queue), §28.40 (Consumer Compatibility Contract `introduced_in`), §28.48 (universal `ctp.config.yaml` ESLint-style config surface), §28.57 (universal native enforcer), §29.6 (byte-identical design/write-time enforcement), §31.9 (acquisition sufficiency), §33 (standards-refresh orchestrator — added this session).
- CTP §12 Phase L (L-1..L-24) — Public Engineering Corpus Learning. `jpmorganchase-mosaic` Tier-1 already registered.
- CTP `docs/design/v1.26-standards-refresh-registry-walker.md` — CL-564 design doc.
- GCTP `docs/upstream-ctp-proposals.md` — P-15 (§31 tech resolution) / P-18 (§31.9 sufficiency floor) / P-19 (probe-answer key mismatch) / P-20 (options→decisions transform) / P-21 (compliance URLs sync gap) ledger.
- GCTP `docs/handoff-contract.md` — Grok→Claude payload schema + Claude→Grok response schema; §Architecture-Consult-Loop + §Architecture-Cross-Check + §Roadmap.
- GCTP `docs/self-healing-design.md` — TICKET-008 self-healing design (7 signals, severity-based dispatch, HITL integration for P2 signals). Closest existing self-improvement scaffolding.

## 7. Session gotchas (learned tonight — avoid re-hitting)

- **Bash 3.2 tab-collapse.** `while IFS=$'\t' read -r ...` COLLAPSES consecutive empty tab-separated fields on macOS bash 3.2. Fix: use `|` delimiter instead. Cost me a debug loop tonight in `commands/standards-refresh.sh`. See commit `1e8fd07`.
- **`extract-rules-from-url.sh --shape html-sections`** takes end-position, not start-position, of the NEXT heading when slicing body prose. Original attempt used tail of the next-heading match → empty body. Fixed to `start:` position. See commit `1e8fd07`.
- **Runner sandbox blocks eval outputs.** `bash evals/runner.sh` in the CTP sandbox returns `0 passed, 0 failed` for known-good specs because OUTDIR writes are refused. Fallback: run specs manually via `for spec in evals/specs/cl564-*.json; do <run>; done`. All 15 CL-564 specs pass manually.
- **Ruby apostrophe in `-e`.** Do not put `'` inside a `ruby -e '...'` block on the outer quote layer — you'll get syntax errors. Use `<<'PY'` heredocs or escape carefully.
- **Registry parser field-shift.** When adding new fields to the registry-parser output, ALSO update the bash `read` positional-arg list AND the `process_entry` positional-arg list — 3 places to keep in sync.
- **Provenance.json churn.** When committing CTP work, `provenance/*.json` files are auto-regenerated with fresh timestamps; either `.gitignore` them or accept the churn. See CTP handoff §gotchas.
- **`applies_to` list vs `source_namespace` scalar.** Standards `*sources*.yaml` entries declare `applies_to: [tech, tech]` (list). My orchestrator now reads `applies_to[0]` as namespace hint when `source_namespace:` absent. Without this fix, all rules land in `_universal/` — see commit `5d32889` for the fix.

## 8. How to run the important things

### GCTP-side
- **Test suite:** `bash tests/test-all.sh` (44/44 green at HEAD `72eaa46`).
- **Compact accept:** `bash scripts/accept-compact.sh` (once per compact-content-hash).
- **Compact audit:** `bash scripts/audit-agent-compact.sh` (must exit 0).
- **Plugin sync:** `bash scripts/sync-plugin.sh --check` (drift check, no writes) or `--ensure` (materialize cache).
- **Kata iteration:** `bash .harness/consult-work/_tools/kata.sh <verb> --project FEATURE-003` (verbs: `reset-project`, `intake`, `fetch`, `acquire`, `sufficiency`, `commit`, `cross-check`).
- **Full audit chain:** the tests + audit scripts are all under `tests/` and `scripts/audit-*.sh`.

### CTP-side (via joint-design regime, working directory `/Users/siddharthjoshi/Code/claude-tdd-pro/`)
- **Test suite:** `bash evals/runner.sh` (see CTP-side handoff `f4b365a:docs/handoff-cloud-session-ctp-development.md §3` for full workflow).
- **Fidelity gate on pending specs:** `bash rubric/detectors/audit-pending-spec-fidelity.sh --pending <dir> --arch docs/architecture-v1.9.md --section "<§NN>"`.
- **Manual smoke test the orchestrator:** see this doc §3 above for the empirical 17-URLs → 618-rules command.

## 9. Open items pending operator input

- **CL-564 domain-crawl (item 5 of §4 roadmap)** — proposed design has 4 strategies + 8 universal guards + 6 quality guards. Design proposal in this session's transcript. Awaits operator yes/no to build.
- **Node.js registry entry (item 6 of §4 roadmap)** — awaits operator a/b/c choice.
- **`origin/cl-564-standards-refresh-orchestrator` and `origin/cl-563-jurisdictional-compliance-rule-authorship`** remote branches on CTP — operator explicitly said NO to deletion of both. Preserve.
- **Real-world-runtime-feedback loop as a distinct backlog ticket** — discussed with operator; existing TICKET-008 self-healing (debt signals) + CTP §12 Phase L (external PR learning) partially cover, but neither closes the loop from the plugin's own deployed apps back to rule refinement. Operator did not explicitly direct a new ticket; if you determine one is warranted after your first read, ask before creating.

## 10. Aspirational north star

Kata (FEATURE-003 SoftArchCert Winter 2025) submission validated by other AIs as competitive with 2025 competition finalists. Path runs through: close extraction-quality gaps (items 1–5 of §4), populate tech-source-registry with Node.js and others (item 6 + more), iterate katas at the accelerated ~3-second-per-loop cadence enabled by TICKET-124/125.a + TICKET-127.a + TICKET-129 + TICKET-130.

Every piece needed for the ADR-0009 six-stage discipline + §29 grounding invariant + §29.6 byte-identical enforcement is already architected. The remaining work is wiring, verification, and expansion of authoritative sources.
