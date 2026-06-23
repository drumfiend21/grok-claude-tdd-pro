# ADR-0070 — Plugin pin bump `39903da` → `230e99d` (adopt CTP composite engine + auto-classification pipeline; ADR-0008 + ADR-0009)

- **Status:** Accepted
- **Date:** 2026-06-23
- **Deciders:** drumfiend21 (architect; 2026-06-23 directive: *"Build the full architecture from the handoff. No rewrites."*) + Claude Opus 4.7 (cloud session).
- **Trigger:** CTP `main` advanced 10 commits `39903da → 230e99d` (CL-488..499) adopting **CTP-ADR-0008** (composite engine + 4-axis canonical vocabulary + architectural-content bundle) and **CTP-ADR-0009** (auto-classification + custom-rule drafting pipeline) + the P-8 fix. Handoff at `cad5831` (cover commit on top of `230e99d`). CTP self-suite **4510/4510 green** at the target pin.
- **Continues:** the ADR-0054 → 0058 → 0061 → 0067 pin chain.
- **Pairs with:** GCTP ADR-0068 (composite-engine wiring) + ADR-0069 (auto-classification pipeline wiring) — both currently **Proposed**; this pin bump is the activation event; their wiring lands in CL-B..CL-E.
- **Process:** §15-gated pin bump (`architecture-v1.9.md` contract hash changed); lockfile updated by hand under this ADR.

## Compatibility verdict (verified `39903da → 230e99d`)

| Check | Result |
|---|---|
| Span size | **10 commits** (4407→4510, +103 CLs net) covering §28.28–§28.39 |
| CTP's `architecture-v1.9.md` | **CHANGED** (`3e0623fa…` → `b9051de8…`) — the §28.28–§28.39 amendments adding CTP-ADR-0008 + CTP-ADR-0009 (Nygard append-only) |
| `CLAUDE.md` | **byte-identical** (`814e43c2…` unchanged) — no new TIER-0/1/2 directives |
| 3 consumed skill SKILL.md files | **all 3 byte-identical** (`82e6dc5d…`, `9a004131…`, `10d07ac9…`) — inner-loop discipline unchanged |
| `rubric/enforce.sh` | **byte-identical** — the 4-state contract (handoff §3.5 explicit) preserved |
| Files deleted / commands removed | **0** (additive only — ADR-0047 invariant preserved) |
| New runtime entrypoints | `rubric/composite-dispatch.sh`, `rubric/composite-audit.sh`, `rubric/enforce-file.sh`, `rubric/sarif-aggregate.sh`, `rubric/runners/{run-tool.sh,run-bundle.sh,install-toolchain.sh}`, `rubric/detectors/{audit-applies-to-parity.sh,audit-commercial-license.sh}`, `commands/{extract-rules-from-url,classify-rule,route-rule,draft-custom-rule,review-queue}.sh` |
| New bundled data | `vendor/canonical-vocabulary/{linguist-languages,purl-types,k8s-gvks,iac-dialects}.json` + `provenance.json` + `resolve.sh` + `refresh-vocabulary.sh`; `standards/kind-to-tool-routing.yaml`; `standards/namespace-axis-binding.yaml`; `rubric/runners/toolchain.json` |
| `active.json` rule shape | Each rule now carries (additive) `applies_to` (4-axis: `linguist_aliases[]`, `iac_dialects[]`, `purl_uses[]`, `k8s_gvks[]`) + `enforced_by[]` (entry 0 = original detector with `required: true` → parity; following entries route to FOSS tools). 112/118 rules carry `applies_to.*`; 118/118 carry `enforced_by[]`; 9/118 carry `applies_to_prose: true`. Aggregator wrapper `version: 1` unchanged (back-compat additive). Consumer-side awareness of the new shape is recorded by this ADR; consumption lands in CL-B (ADR-0068 W-A/W-B). |
| `rubric/detectors/llm-judge.sh` | Gained `--text <prose>` flag — the **P-8 fix** GCTP filed at `docs/upstream-ctp-proposals.md`. `prose-judge.sh` interface unchanged. |

## Decision

Bump the pin `39903da` → `230e99d`:

- **Lockfile:** update `pinned_commit` / `pinned_at` / `pinned_message` / `last_synced_*` and re-hash `architecture-v1.9.md` (`3e0623fa…` → `b9051de8…`). `CLAUDE.md` + the 3 skill hashes unchanged. `contract_surface_files` enumeration unchanged — the new entrypoints are CLI-contract runtime tools (like `enforce.sh`), not documentary/skill contracts; they're consumed via CLI signature, not by hash.
- **Adopt read-only** — no `claude-tdd-pro` path edited from here (prime directive).
- **Re-sync** the plugin cache to `230e99d` (`sync-plugin.sh --ensure`).
- **Regenerate `.harness/rules/active.json`** from the new pin's pipeline (the aggregator emits the new `applies_to`/`enforced_by` fields additively on the per-rule body; wrapper `version: 1` stays unchanged because the change is back-compat — legacy `language: <string>` rules continue to be read via CTP's dual-read shim).
- **Activate inert**: the new runtime entrypoints (`composite-dispatch.sh`, `composite-audit.sh`, `enforce-file.sh`, `sarif-aggregate.sh`) sit available but **unwired** after this CL. The harness still consumes only `enforce.sh`'s 4-state verdict. Wiring lands in CL-B+ per ADR-0068 / ADR-0069. This makes CL-A consumer-compatible: nothing in the existing audit chain changes behavior.
- **Mark P-8 ADOPTED** in `docs/upstream-ctp-proposals.md` — fixed at this pin via `llm-judge.sh --text`.

## What changes for GCTP

- **Gained (available, not yet wired):**
  - URL-scrape → 4-axis canonical tagging → route-by-kind to the proper FOSS tool → enforce on writing AND auditing of every file. 118-rule corpus migrated with enforcement parity preserved (handoff §2).
  - FOSS toolchain provisionable at install time (`rubric/runners/install-toolchain.sh`; `--permissive-only` for zero-copyleft footprint).
  - Auto-classification + custom-rule drafting pipeline (extract → classify → route → draft → review-queue → commit; CTP-side runtime).
  - Two new harness-runnable smoke gates: `audit-applies-to-parity.sh` (enforcement parity across the 118 migrated rules) + `audit-commercial-license.sh` (sellable-with-no-conflict check on bundled data).
  - **P-8 fixed upstream** (`llm-judge.sh --text` ships) — semantic-tier `prose-judge.sh` is now functional under `LLM_JUDGE=1`.

- **Unchanged:**
  - The `enforce.sh` 4-state contract (`pass | fail | not_applicable | not_enforced`) — Fix B/C continue to work byte-identically (handoff §3.5 explicit).
  - The `schema_version` of the handoff contract (still `"1"`) — `applicable_rules` continues to consume rule IDs as opaque strings.
  - The 3 executed skills (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) — all byte-identical at the new pin.
  - `CLAUDE.md` (no new TIER-0/1/2 directives).
  - All existing namespaces — additive per ADR-0047.

- **Deferred to paired wiring CLs (NOT part of CL-A):**
  - Consumption of `applies_to.{linguist_aliases,iac_dialects,purl_uses,k8s_gvks}` in `audit-applicable-rules.sh` → CL-B (ADR-0068 W-A).
  - Per-file narrowed re-run via `enforce-file.sh` in `enforce-standards.sh` + `audit-standards-enforced.sh` → CL-B (ADR-0068 W-B).
  - Write-time hook invocation of `composite-dispatch.sh` on touched files → CL-C (ADR-0068 W-C).
  - Design-phase MD gate invoking the architectural-content bundle → CL-C (ADR-0068 W-D).
  - Operator-facing `gctp standards add` + `gctp standards review` CLI → CL-D (ADR-0069 W-F + W-G).
  - Commercial-license CI gate + operator-runbook updates → CL-E (ADR-0069 W-H + handoff §5.6).

## No-rewrites discipline (binding on CL-A and all paired wiring CLs)

This pin bump and every downstream CL-B..CL-E commit operates under an explicit **no-rewrites discipline** (operator directive 2026-06-23):

1. **`.harness/handoffs/*.req.json` and `*.res.json` are append-only historical state.** They record completed prior work. They MUST NOT be mass-modified by any CL to make a new gate go green. The data is what it is.
2. **When a new audit gate surfaces violations on legacy data, document and defer.** Add a "Known follow-up surfaced by this CL" section to the relevant ADR; commit clean with the surfaced reds documented. The operator closes deferred follow-ups naturally by re-running the inner loop when those tickets next come into scope.
3. **The handoff is explicit: additive, non-breaking** (handoff §1, post-§5 TL;DR). New gates apply to NEW data generated under the new contract. Legacy data is grandfathered as a natural consequence of additive evolution — not retrofitted by force.
4. **Audit-chain greenness and CL-substrate completeness are separable concerns.** A CL is done when its substrate (code + tests + ADR) is in place AND the audits are EITHER green OR have documented deferred reds. Conflating the two led to the prior session's mass-regen cascade (req.json regen → res.json out of sync → 249-violation second-order break → spiral). This discipline closes that failure mode.
5. **`grep + edit` for substrate is allowed; `for file in handoffs/*; do regen; done` is forbidden.** Code extensions to existing scripts/tests/docs are normal substrate work. Bulk regeneration of gitignored runtime state to satisfy a new gate is the antipattern this rule bans.

This discipline is restated at the head of ADR-0068 + ADR-0069 (paired wiring ADRs) so it travels with every CL touching the composite-engine line.

## Consequences

### Positive
- Activates the composite-engine line at the harness boundary; the engine is in-tree (cached at `230e99d`) and runnable from the operator shell, ready for CL-B+ wiring.
- Closes P-8 (the semantic-tier `prose-judge.sh` dead-code path the 2026-06-20 kata audit surfaced).
- Two new smoke gates (`audit-applies-to-parity.sh`, `audit-commercial-license.sh`) give GCTP green/red evidence of CTP's migration parity + commercial sellability at every future pin bump.
- The handoff's TL;DR is "additive, non-breaking except for the hard-require semantics which needs paired GCTP ADR-0068 before relying on routed-tool verdicts" — CL-A scopes the integration so the unwired state is *also* the consumer-compatible state. ADR-0068's hard-require paragraph lands in CL-B before any routed-tool verdict consumption.

### Neutral
- No `claude-tdd-pro` path edited from here (prime directive honored). D-6 honored. No `schema_version` change on the handoff contract.
- CTP team adopted CTP-ADR-0008 + CTP-ADR-0009 directly; the paired GCTP ADRs (0068 + 0069) were drafted in a prior session anticipating this surface. CL-A is the activation event; their wiring is the body of CL-B..CL-E.
- `contract_surface_files` enumeration unchanged — the new entrypoints are CLI-contract surfaces, not documentary/skill contracts. Future hardening (e.g., locking CLI signatures of the new entrypoints) is a separate ADR.

### Negative / cost
- The cache footprint grows (new `vendor/canonical-vocabulary/*`, `commands/*`, `rubric/runners/*`) — disk impact only; gitignored.
- LLM-judge token cost for the now-functional Layer 2 (`prose-judge.sh` under `LLM_JUDGE=1`) is operator-controlled and bounded by the hash cache. CL-A does not auto-invoke it.
- The 10 commits between pins span ~103 CL units of CTP-side work; the harness inherits the surface in one bump, which raises review surface for this single ADR. Mitigated by: (a) CTP self-suite 4510/4510 green at the target pin, (b) handoff doc enumerating the exact contract delta, (c) the paired GCTP ADRs 0068/0069 carrying explicit wiring CLs, (d) the no-rewrites discipline keeping each downstream CL surgical.

## Verification (executed before commit)

- `scripts/sync-plugin.sh --ensure` → cache materialized at `230e99d` (verified by `git rev-parse HEAD` in the cache).
- `scripts/standards-sync.sh` → `active.json` rebuilt from the new pin's pipeline (118 rules; 112 carry `applies_to`, 118 carry `enforced_by`, 9 carry `applies_to_prose`).
- `bash .harness/plugin-cache/claude-tdd-pro/rubric/detectors/audit-applies-to-parity.sh` → `status=green rules=118 parity_fail=0 unrouted=0` (handoff §6 smoke 1).
- `bash .harness/plugin-cache/claude-tdd-pro/rubric/detectors/audit-commercial-license.sh` → `status=green bundled=4 tools=16 violations=0` (handoff §6 smoke 2).
- `git diff docs/founder-directives.md` == 0 (D-6 honored — no §1 provenance edit).
- No `.harness/plugin-cache/claude-tdd-pro/**` path edited (prime directive honored — only re-materialized by `--ensure`).
- **No `.harness/handoffs/*` rewrites** (no-rewrites discipline §1).
- Full audit chain re-run after the 2 housekeeping edits (plugin-surface rows for `COMMERCIAL-USE.md` + `vendor/`; P-8 ADOPTED mark). Any audit reds surfaced by the pin bump are documented under "Known follow-up surfaced by this CL" below — not mass-fixed by rewriting handoffs.

## Known follow-up surfaced by this CL (closes via operator inner-loop re-runs or CL-B's wiring)

Documented per the no-rewrites discipline above. Each entry closes naturally without mass-rewriting handoff state. **11 of 14 audits green at CL-A close; 3 surfaced reds documented below.**

### 1. `audit-applicable-rules.sh` — 205 under-scoping violations on TICKETS 001..014

**Cause:** The pre-existing `.harness/handoffs/TICKET-{001..014}.req.json` files were issued under the pre-pin-bump rule catalog. The new pin's regenerated `active.json` carries 9 rules with `applies_to_prose: true` (Layer-2 semantic projection per ADR-0066 D-B); the pre-pin tickets predate that projection and don't include those rules in their `applicable_rules`. Manifests as 205 "file_scope .md glob projects applies_to_prose rule" violations across 14 tickets × ~9 rules per ticket × varied .md scopes.

**Why it's NOT a CL-A regression:** the under-scoping is correct by the **prior** standard and surfaced only because the new catalog declares richer applicability. The handoff is explicit: "additive, non-breaking." Existing tickets that have already been completed cannot retroactively pick up new floors without re-running through `/decompose`.

**Closure path (operator-driven, no data rewrite):**
- For tickets still in active development, the operator re-runs `/decompose` on each ticket — the post-CL-A `/decompose` (when CL-B's W-A lands) will populate the full 4-axis-aware `applicable_rules`, regenerating req.json with the new floor satisfied.
- For tickets that are completed historical state (TICKETS 001..014 are all in this category — all .res.json files at `status: green` predate the pin bump), the under-scoping is acceptable historical state. The audit's `[VIOLATION]` here is the gate doing its job — flagging "this ticket would be under-scoped if re-issued today" — not a code defect.
- **NOT addressed by mass-regenerating req.json files** (the prior session's mistake; see no-rewrites discipline §1).

### 2. `audit-cross-references.sh` — 57 NEW broken cross-references; 35 baseline entries no longer broken

**Cause:** The pin bump re-materializes the plugin cache at a new commit; some doc references shift accordingly. Of the 57 NEW: (a) several ADR-0068/0069 references point to scripts in CTP's tree (`scripts/classify-from-url.sh`, `scripts/review-queue.sh`) that the harness wraps but doesn't carry directly — these are correct references, just to plugin-internal paths; (b) several `docs/eo-2026-ai-innovation-security-alignment.md` refs to deferred docs (`docs/compliance-profiles/eo-2026.md`, `docs/frontier-model-readiness.md`) that the EO compliance ADR-0045 line is yet to land; (c) several ADR-0066 refs to `docs/architecture/adr/**/*.md` etc. that are example/fixture paths from the prose-as-code ADR; (d) ~35 baseline entries are now "no longer broken" because the new plugin cache provides paths the prior baseline assumed missing.

**Why it's NOT a CL-A regression:** the new findings are pre-existing structural artifacts of cross-repo references and to-be-built docs. Per ADR-0032, the cross-references baseline is operator-maintained, not auto-derived; mass-updating it from one pin bump's surface is the kind of rewrite this discipline rejects.

**Closure path (operator-driven baseline-maintenance ADR, separate from CL-A):** the operator may land a follow-up ADR that catalogs each NEW broken reference, classifies it (real fix vs. acknowledged-deferred vs. plugin-internal), and either fixes refs or adds rows to the baseline with justification. Until then, the audit's red is the truth-table reflecting actual broken cross-references in the doc tree as it stands.

### 3. `audit-standards-enforced.sh` — TICKET-042 (2 divergences)

**Cause:** The smoke-e2e fixture (`scripts/smoke-e2e.sh`) generates TICKET-042 as a STUB: the inner-loop response asserts `pass` on every applicable rule without actually running detectors (documented stub-mode design in `smoke-e2e.sh:230-235`). The dynamic re-run gate (`audit-standards-enforced.sh`, ADR-0063) re-runs detectors against the global `app_root` (`../softarchcert-win25`, the contaminated O'Reilly kata tree by design). The stub's `pass` claim diverges from the kata's actual content, which contains hardcoded secrets and debug output by design.

**Closure path (CL-B substrate, no data rewrite):** ADR-0068 W-B adds `--changed-files` narrowing to `enforce-standards.sh`, so the live re-run targets the clean toy file (`examples/string-utils/src/string-utils.mjs`) instead of the contaminated kata tree. Live verdict then matches the stub's `pass` claim, divergence closes — purely via code extension; the TICKET-042 fixture itself is unchanged.

## Implementation references

- **Modified:** `docs/claude-tdd-pro.lock.yaml` (pin + `architecture-v1.9.md` hash + `pinned_at` + `pinned_message` + `last_synced_*`), `.harness/plugin-cache/claude-tdd-pro/**` (regenerated by `sync-plugin.sh --ensure` from the new pin), `.harness/rules/active.json` (regenerated by `standards-sync.sh`), `docs/plugin-surface-consumption.md` (+2 DECLARED-NOT-CONSUMED rows: `COMMERCIAL-USE.md`, `vendor/`), `docs/upstream-ctp-proposals.md` (P-8 → ADOPTED).
- **NOT modified:** `.harness/handoffs/*` (no-rewrites discipline §1). Any audit reds against legacy handoffs are documented in this ADR as deferred follow-ups, not fixed by regen.
- **New:** this ADR.
- **Adopts (CTP-side, not edited here):** §28.28–§28.39 (CL-488..499) covering CTP-ADR-0008 (composite engine + 4-axis canonical vocabulary + architectural-content bundle + write/audit-time enforcement; Waves 1–3) and CTP-ADR-0009 (auto-classification + rule-drafting pipeline; Waves 1–3) plus the end-to-end integration suite (CL-499) and the commercial-license gate (CL-497) and install-time license-footprint prompt (CL-498) and the P-8 fix.
- **Activates (harness-side, deferred to CL-B+):** ADR-0068 wiring W-A..W-E (composite-engine consumer) and ADR-0069 wiring W-F..W-I (auto-classification operator CLI).
- **Related:** ADR-0058 (`enforce.sh` `not_applicable` neutral), ADR-0067 (prior pin bump `7a7f74d`→`39903da`), ADR-0068 (composite-engine wiring), ADR-0069 (auto-classification pipeline wiring).
- **Provenance:** Handoff doc at CTP commit `cad5831` (on top of `230e99d`); CL-A integration scope per operator directive. The no-rewrites discipline lifts a key lesson from the prior session that mass-regenerated `.harness/handoffs/*` runtime state and triggered a 249-violation second-order cascade; this CL inherits the constraint by design.
