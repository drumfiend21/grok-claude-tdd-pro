# GCTP → CTP handoff — P-15 convergence ack: `umbrellas`/`families` answered, 14+4 assertions mapped onto CTP §4 S-63 shape, phase mapping confirmed — the final 5% to lock, everything else GO

**Written:** 2026-07-10 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `11126a8`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟢 **CONVERGED — GCTP acks CTP's `docs/handoff-ctp-to-gctp-p15-converged.md` (+ §31.4 append) @ CTP `main` `e4ec1a9`, resolves the held `umbrellas` vs `families` item with the actual semantic distinction, maps 14+4 assertions onto the published §4 S-63 shape, and confirms the revised phase order. Phase 1 (family-activation) startable NOW on the GCTP side; Phase 2 unblocked by §4.**
**Prior turns:**
- CTP → GCTP (this turn): `docs/handoff-ctp-to-gctp-p15-converged.md` + §31.4 append @ `e4ec1a9`. Accepted B1–B6, Deltas A + B + D; held Delta C (`umbrellas` vs `families`); published S-63 shape in §4; revised phase order (family-activation first).
- GCTP → CTP: `docs/handoff-ctp-p15-b1-b5-decisions-and-assertion-map.md` (this repo, 2026-07-10) — B1–B5 answers + 14+3 assertion map onto §31 shapes.
- GCTP → CTP: `docs/handoff-ctp-p15-reconciliation-shared-design.md` (this repo, 2026-07-10) — six boundary decisions + four small deltas.
- GCTP → CTP (original): `docs/handoff-ctp-p15-family-umbrella-per-project-provisioning-pr-promotion.md` (this repo, 2026-07-10) — 14-assertion Tier-A/B acceptance corpus at §4.

---

## 0. TL;DR

- **All accepted items confirmed on the GCTP side.** B1–B6 as CTP restated them; Deltas A (`acquire`/`promote`/`release` verbs — final trio), B (registry CTP-owned + PR-only, no per-project overlay; supersedes CTP D1), D (family-activation ships first — Phase 1 has zero boundary dependency).
- **Delta C (`umbrellas` vs `families`) — GCTP recommends BOTH.** The two words name different things: `families:` is a *tech's category membership* (Vue is a `frontend`); `umbrellas:` is a *family's namespace payload* (the `frontend` family's umbrellas are `[google, typescript, owasp, w3c, web-vitals, documentation]`). Renaming `umbrella_namespaces:` → `umbrellas:` inside the family entry is pure cosmetic and adopts CTP's operator vocabulary. **Recommendation: keep `families:` on the tech, rename `umbrella_namespaces:` → `umbrellas:` on the family.** Full rationale + schema examples in §3. GCTP defers to CTP for the final word.
- **14+4 acceptance assertions mapped onto CTP §4 S-63 shape** (§4). The 14 originals now target `_project/<id>/<ns>/<rule>.yaml`, `origin: project` + `project_id` + provenance, the aggregator's `--project` scoping, and the byte-identical-`active.json`-without-`--project` guarantee. Plus A15 cross-project leakage (B4 hard invariant), A16 `--project` required, A17 reveal origin distinction, A18 S-61 recommender source-cited shape.
- **Phase mapping acked with a correction:** GCTP Phase 1 pre-wire (TICKET-120.a) **starts NOW** — CTP's revised Phase 1 has no `_project/` dependency, so the family-activation contract tests + classifier tolerance work is unblocked by CTP's already-shipped `--stack-add` mechanism plus the §4 published shape. Phase 2 pre-wire (TICKET-121.a) begins immediately on `umbrellas` decision.
- **Final 5%:** (1) CTP's ruling on `umbrellas` vs `families` per §3; (2) GCTP files companion tickets 120/120.a/121/121.a/122/122.a/123 in `TICKETS.md` on that ruling; (3) CTP starts S-58/S-59 build.
- Additive per ADR-0047. Cite-or-decline preserved. No LLM. Compact-safe.

---

## 1. Full acceptance table

| CTP-locked item | GCTP status | Note |
|---|---|---|
| **B1** — GCTP-owned `project-id`; required `--project <id>` on CTP commands touching per-project state | ✅ accepted | ID regex `[A-Z][A-Z0-9_-]{2,63}` from GCTP prior; CTP schema-validates on receipt. |
| **B2** — `.harness/plugin-cache/claude-tdd-pro/_project/<id>/`, CTP-owned scripts write | ✅ accepted | `standards-sync.sh` preserve-across-rebuild logic tracked in TICKET-121.a. |
| **B3** — Two-step promotion (CTP PR review + GCTP §15 ADR on subsequent pin bump) | ✅ accepted | `docs/upstream-ctp-proposals.md` `P-15-followon:<tech>` status pattern (`filed → PR open → PR merged → pin bump ADR → adopted`). |
| **B4** — `origin: project scope: project:<id>` first-class-but-scoped; cross-project surfacing is fail-loud | ✅ accepted (**hard invariant, per CTP**) | This is the "no silent globalization" spine on the intra-repo cross-project axis. A15 test formalizes. |
| **B5** — Reveal = official-constant ∪ project-dynamic; **kata** = a project, working-only default | ✅ accepted | No hardcoded 44; TICKET-119.b amends P-14 corpus to structural form. |
| **Delta A** — Verbs `acquire` / `promote` / `release` (final trio) | ✅ accepted | GCTP `/consult` skill translation aligns on the trio; older "provision" language retired. |
| **Delta B** — Registry CTP-owned + PR-only; NO per-project overlay (supersedes CTP D1) | ✅ accepted | Per-project customization lives at the rule level via `_project/<id>/<ns>/*.yaml`, not at the taxonomy level. Simpler mental model. |
| **Delta C** — Field naming (`umbrellas` vs `families`) | 🟡 GCTP recommendation in §3 | Semantic distinction exists; recommendation is to keep BOTH words for their distinct roles. |
| **Delta D** — Family-activation ships first (Phase 1) | ✅ accepted (**thank CTP for the corrected phase order**) | Phase 1 has zero `_project/` dependency; GCTP TICKET-120.a startable NOW per §5. |
| **D1** (superseded by Delta B) | ✅ superseded per CTP | Registry stays official + PR-gated only. |
| **D2** — Optional `fetcher:` source field carried in provenance | ✅ accepted | GCTP consumes as optional (additive-optional per ADR-0089 pattern); reveal shows `fetcher: auto-detected` if absent. |
| **D3** — Umbrella-matched source search; `--max-sources` default 8; over-budget → `budget_exhausted` + `needs_source` non-silent | ✅ accepted | `/consult` skill translates `budget_exhausted` into operator-visible language ("we hit N sources without finding X; try `--max-sources 12` or narrow the tech query"). |
| **D4** — Deduped union of all matched umbrellas' namespaces (polyglot: Next.js → frontend + backend) | ✅ accepted | Matches Delta C's shape whichever field name lands. |
| **D5** — Freshness gate for working; symmetric removal PR for official; `deprecated: true` honored | ✅ accepted | `applicable_rules` computation skips `deprecated: true` by default; `--include-deprecated` for archaeology only; removal PRs tracked in `docs/upstream-ctp-proposals.md` alongside promotion PRs (same lifecycle, opposite direction). |
| **§4** — Published S-63 shape (`_project/<id>/<ns>/<rule>.yaml` + `origin` + `project_id` + 4-axis + provenance; aggregator `--project` scoping; byte-identical `active.json` without `--project`) | ✅ accepted | Unblocks GCTP TICKET-121.a pre-wire. Assertion map in §4 below targets this shape. |

**Net acceptance state.** Every item is locked except Delta C. GCTP's recommendation on Delta C is in §3; whichever way CTP rules, GCTP builds accordingly with no further round-trip needed.

---

## 2. Numbering: `families` and `umbrellas` are naming two different things

Before recommending, state the two distinct things being named:

- **`families:`** — the *tech's category membership*. Vue IS a member of `frontend`. Angular IS a member of `frontend`. Next.js IS a member of `[frontend, backend_runtime]`. This is a property of the TECH ENTRY and lives in the tech's row in `technology-family-registry.yaml`. Cardinality-per-tech is small (1 or 2). Membership drives the classifier's `canonical_workload_type` signal (Vue → `frontend` → `web-frontend` workload type fires).
- **`umbrella_namespaces:`** (GCTP's word) / **`umbrellas:`** (CTP's word) — the *family's namespace payload*. The `frontend` family's payload is `[google, typescript, owasp, w3c, web-vitals, documentation]`. This is a property of the FAMILY ENTRY and lives in the family's row (referenced by every tech in that family). Cardinality-per-family is 4–8.

Under either word choice, the resolution flow is the same:

```
operator names "vue"
  → classifier finds vue in registry
    → vue.families = [frontend]
      → registry lookup: family[frontend].{umbrella_namespaces | umbrellas} = [google, typescript, owasp, w3c, web-vitals, documentation]
        → all six activate at Stage 0
        → family[frontend].canonical_workload_type = web-frontend also fires
```

The polyglot case (Next.js):

```
operator names "next.js"
  → nextjs.families = [frontend, backend_runtime]
    → union(family[frontend].umbrellas, family[backend_runtime].umbrellas) = deduped-set
      → all activate
```

The two words are naming *different rows in the schema*, not the same row. `families:` lives on the tech; `umbrellas:` (renaming from `umbrella_namespaces:`) lives on the family. They coexist naturally.

---

## 3. GCTP recommendation on Delta C: keep BOTH, each on its own row

**Recommendation.** Retain `families:` as the field name on tech entries (tech's category membership). Rename `umbrella_namespaces:` to `umbrellas:` on family entries (adopting CTP's operator vocabulary for the namespace payload). Both sides get their preferred word for its natural referent; no schema flattening; classifier signal (`canonical_workload_type`) stays clean on the family layer.

**Schema example (proposed):**

```yaml
families:
  frontend:
    umbrellas: [google, typescript, owasp, w3c, web-vitals, documentation]   # was `umbrella_namespaces:`, CTP's word wins
    canonical_workload_type: web-frontend
    technologies:
      - name: vue
        aliases: [vue, vue.js, vuejs, nuxt, nuxt.js]
        namespace: vue
        families: [frontend]                                                  # tech's category membership, plural for polyglot
        canonical_docs_url: "https://vuejs.org/guide/"
        provision_status: unprovisioned
        fetcher: html-anchor.sh                                               # D2 optional field
      - name: angular
        families: [frontend]
        # ...
  backend_runtime:
    umbrellas: [google, typescript, owasp, documentation, node]
    canonical_workload_type: backend-runtime
    technologies:
      - name: next.js
        families: [frontend, backend_runtime]                                 # polyglot — D4 union fires both umbrella sets
        namespace: nextjs
        canonical_docs_url: "https://nextjs.org/docs"
        provision_status: unprovisioned
```

**Why keep the family layer at all.** Three loads it carries that a flat `umbrellas:` on tech would leave stranded:

1. **Classifier signal.** `canonical_workload_type` is a family property, not a per-tech property. `web-frontend` fires whether the operator names Vue, Angular, Ember, or Svelte — because they're all in the `frontend` family with a single canonical workload type. Flattening umbrellas onto tech leaves this signal needing a parallel field (`classifier_workload_type:` on every tech), which is either redundant (all frontend techs repeat `web-frontend`) or divergent (some drift over time).
2. **DRY-ness for adding same-family techs.** Adding Solid or Qwik to the frontend family is one row (`name: solid, families: [frontend]`) — the umbrella set is inherited. Flattening umbrellas onto tech makes each addition an explicit list of six or seven namespaces, which drifts over time (someone adds Solid but forgets `web-vitals`).
3. **Family membership queries.** "What other techs share Vue's family?" is a meaningful operator question (for the S-61 tech-fitness recommender: "you named Vue for a small greenfield; other members of Vue's family include Svelte and Solid, which have <X> characteristics"). Flat `umbrellas:` on tech loses this query natively.

**Alternative if CTP wants strict cosmetic replacement.** If CTP prefers `umbrellas:` as the single word for both the field-on-family and the resolved-set-per-tech (with the family layer purely structural, no per-tech `families:` field), GCTP will accept it and derive tech's family membership by reverse-lookup ("what family contains this tech's entry?"). Slightly less ergonomic in schema and query, still workable. GCTP's leaning is the recommendation above (`families:` on tech, `umbrellas:` on family), but this is not a hill GCTP dies on.

**Impact if held longer.** None on Phase 1 build — the family entry's field-name is settled either way (`umbrellas:`), so S-58 can start. The `families:` question only affects the tech-entry schema. Recommend CTP rule quickly to avoid schema churn on S-58 completion.

---

## 4. 14+4 acceptance assertions mapped onto §4 S-63 shape

Restated from GCTP's prior 14+3 map onto CTP's PUBLISHED §4 canonical shape:
- Rule path: `.harness/plugin-cache/claude-tdd-pro/_project/<project-id>/<namespace>/<rule-id>.yaml`
- Per-rule frontmatter: `origin: project`, `project_id: <id>`, 4-axis tags, provenance (`source_url`, `fetcher`, `acquired_at`, `rule_extraction_version`, `operator`)
- Aggregator: `--project <id>` scopes the effective set to `active.json ∪ _project/<id>/`
- Byte-identical-`active.json` guarantee: aggregation without `--project` returns identical bytes before and after any acquisition

### Phase 1 targets (S-58 family registry + S-59 classifier widening) — assertions A1–A4

| # | Assertion | Machine form |
|---|---|---|
| **A1** | Vision naming `vue` → classifier fires `web-frontend` → `family[frontend].umbrellas` = `[google, typescript, owasp, w3c, web-vitals, documentation]` all appear in `activated_probe_namespaces`. | `jq '.activated_probe_namespaces \| contains(["google","typescript","owasp","w3c","web-vitals","documentation"])'` on classify output for `--workload "vue frontend"`. |
| **A2** | Same for Angular (guards against React-only regression). | Same jq shape with `--workload "angular frontend"`. |
| **A3** | Tech NOT in registry → classifier emits actionable note ("detected 'X' — no family entry; add via family-registry PR"), does NOT phantom-activate. | Exit 0, stderr contains "no family entry"; `activated_probe_namespaces` unchanged from baseline. |
| **A4** | Registry schema-validates: every family has `umbrellas:`; every namespace referenced exists in `active.json` (cite-or-decline). | Registry validator exits 2 on malformed input (missing `umbrellas`, or referenced namespace not in `active.json`). |

### Phase 2 targets (S-63 `_project/` foundation + S-60 acquisition pipeline) — assertions A5–A10

| # | Assertion | Machine form (targets §4 published shape) |
|---|---|---|
| **A5** | `acquire-tech-rules.sh --tech <unprovisioned> --project FEATURE-003 --url <reachable>` succeeds; writes `_project/FEATURE-003/<namespace>/<rule-id>.yaml` with `origin: project`, `project_id: FEATURE-003`, provenance fields populated. | Exit 0; `test -f .harness/plugin-cache/claude-tdd-pro/_project/FEATURE-003/vue/*.yaml`; `yq '.origin' == "project"` on any acquired rule; `yq '.project_id' == "FEATURE-003"`. |
| **A6** | `acquire ... --url <unreachable>` → exit 2 (cite-or-decline); D3 `budget_exhausted` case emits `needs_source` state distinctly from the exit-2 case. | Two-arm assertion: unreachable URL → exit 2 + stderr contains "cannot reach"; budget-exhausted → exit 0 + `_project/<id>/<ns>/.state.yaml` field `state: needs_source`. |
| **A7** | `acquire --tech <already-in-active.json>` → exit 0 no-op ("already global"). | Exit 0; stderr contains "already global"; no new file written under `_project/<id>/`. |
| **A8** | Aggregator with `--project FEATURE-003` returns effective set = `active.json ∪ _project/FEATURE-003/*`; each rule carries `origin` + `project_id` (or `origin: official scope: global` for `active.json` entries). | `aggregate --project FEATURE-003 \| jq 'group_by(.origin)'` returns both groups; count matches `_project/FEATURE-003/*/*.yaml` + `active.json` rule count. |
| **A9** (byte-identical spine test) | Aggregator WITHOUT `--project` returns identical bytes before and after any acquisition — global `active.json` untouched. | Snapshot `sha256sum active.json` at pre-acquisition and post-acquisition; MUST be equal. Formalization of §4 "byte-identical-`active.json`-without-`--project`" guarantee. |
| **A10** | `release-tech-rules.sh --tech vue --project FEATURE-003` reverts: `_project/FEATURE-003/vue/` gone; aggregator no longer returns Vue rules with `--project FEATURE-003`. | Post-release: `test ! -d .harness/plugin-cache/claude-tdd-pro/_project/FEATURE-003/vue`; aggregate `--project FEATURE-003 \| jq '.[] \| .namespace == "vue"'` returns empty. |

### Phase 3 targets (S-62 promotion + S-64 removal) — assertions A11–A14

| # | Assertion | Machine form |
|---|---|---|
| **A11** | `promote-project-rule.sh --tech vue --project FEATURE-003` assembles PR diff with all six artifacts (rule YAMLs at `generated-code-quality-standards/vue/*.yaml` + axis binding + registry `provision_status: provisioned` flip + source-registry entry + acceptance-test spec + PR body). | Dry-run mode prints diff; assert six file paths present; assert PR-body template variables populated. |
| **A12** | PR diff includes auto-generated acceptance-test spec citing canonical URL per rule (D2 fetcher-provenance carry-forward). | Each rule in the acceptance-test spec has `source_url` field matching the acquired rule's `source_url`. |
| **A13** | Merge simulation → next pin bump lifts overlay to global; `_project/FEATURE-003/vue/` becomes safely removable via `release --replaced-by-global`. | Simulated merge: bump pin; sync repopulates cache with vue in `active.json`; release-mode "replaced-by-global" exits 0 without warnings. |
| **A14** | Promotion writes provenance record with `operator`, `promoted_at`, `pr_url`, `pr_sha`, `rule_count`, `canonical_url`, `rule_extraction_version`. | `test -f .harness/consult-work/FEATURE-003/promoted-rules.log.md`; grep each field label; assert non-empty values. |

### Additional (B4/B5 hard-invariant + `--project` + S-61) — assertions A15–A18

| # | Assertion | Machine form |
|---|---|---|
| **A15** (B4 leakage test) | Rule with `origin: project scope: project:FEATURE-003` graded against a `project: FEATURE-004` ticket → invariant-4 REJECTS with diagnostic "scope mismatch: rule scoped to FEATURE-003, ticket in FEATURE-004"; rule does NOT appear in FEATURE-004's `applicable_rules`. | Aggregate `--project FEATURE-004` on a repo state where FEATURE-003 has acquired vue; FEATURE-004's `applicable_rules \| jq 'contains(vue rule ids)' == false`; stderr contains "scope mismatch". |
| **A16** | Invoking `acquire`/`release`/`promote`/reveal WITHOUT `--project <id>` → exit non-zero, human-readable "specify --project <id>". | Bare invocation exits ≠ 0; stderr contains "specify --project". |
| **A17** (B5 no-hardcoded-44 + origin distinction) | `full_surface` reveal emits `available_menu[]` with `origin` + `scope` per entry; reveal WITHOUT `--project` returns official-only; reveal WITH `--project FEATURE-003` returns official ∪ FEATURE-003-scoped. Cardinality NEVER hardcoded — structural form `count(official) + count(_project/<id>/*)`. | `jq '.available_menu[] \| select(.namespace == "vue") \| .origin'` returns `"project"` when Vue acquired for FEATURE-003; returns `"official"` when Vue promoted globally; missing (no entry) when neither. Reveal without `--project` omits project entries entirely. |
| **A18** (S-61 recommender shape) | Tech-fitness recommender output includes: `recommended_alternative`, `rationale_source_urls[]` (≥1 from umbrella-matched sources), `confidence` (bounded to source corpus), `opt_out_path`. No LLM in the recommendation path — rationale text drawn from scraped source content. | Recommender output schema-validated: four required fields present + non-empty. `rationale_source_urls` ⊆ umbrella-matched source registry. |

**Total assertion count: 18.** The 14 originals cover the CTP-authoritative surface; A15/A16/A17 lock the B4/B5/`--project` spine; A18 covers S-61.

---

## 5. Phase mapping — GCTP companion tickets keyed to CTP phase order

Restated against CTP's revised phase order (family-activation first — thank you for the correction):

| CTP Phase | CTP tickets | GCTP pre-wire | GCTP adoption | Startable |
|---|---|---|---|---|
| **Phase 1** — Family-activation | S-58 (registry) + S-59 (classifier widening) | **TICKET-120.a** — `standards-sync.sh` schema-validates `technology-family-registry.yaml`; `scripts/consult.sh --validate-profile` tolerates `families_active[]`; `/consult` skill translates umbrella activation to plain language; A1–A4 assertion scaffolding. | **TICKET-120** — pin bump adopting S-58 + S-59; §15 ADR. | **NOW** — no `_project/` dependency; already-shipped §30.5 `--stack-add` + `stack[]` mechanism carries the plumbing; only the registry contract-test needs writing. |
| **Phase 2** — Acquisition | S-63 (`_project/` foundation) + S-60 (acquisition pipeline) | **TICKET-121.a** — `standards-sync.sh` preserve-`_project/`-across-rebuild; aggregator `--project` propagation in `scripts/audit-architecture-crosscheck.sh` invariant-4; A15 fail-loud cross-project leakage tests; A16 `--project`-required tests; assertion scaffolding for A5–A10. | **TICKET-121** — pin bump adopting S-60 + S-63; §15 ADR; kata runbook updated with acquisition flow for FEATURE-003. | **NOW** — CTP's §4 published S-63 shape unblocks this; no further shape wait. |
| **Phase 3a** — Promotion | S-62 | **TICKET-122.a** — promotion-PR envelope validation; `docs/upstream-ctp-proposals.md` `P-15-followon:<tech>` status pattern scaffolding; rejection-recovery flow; A11–A14 scaffolding. | **TICKET-122** — pin bump adopting S-62; §15 ADR; `/consult` skill promotion translation. | On S-62 shape publication. |
| **Phase 3b** — Removal | S-64 | Folded into TICKET-122.a — removal PR is D5's symmetric surface. | Folded into TICKET-122 or split if CTP prefers. | On S-64 shape publication (may co-land with S-62). |
| **Phase 3c** — Recommender | S-61 | **TICKET-123.a** — recommender output schema validation; A18 scaffolding; kata runbook updated to exercise the recommender. | **TICKET-123** — pin bump adopting S-61; §15 ADR; `/consult` skill recommendation translation. | On S-61 shape publication (per CTP, S-61 is last). |

**GCTP-side files these will file/create:**
- `TICKETS.md`: rows for 120/120.a/121/121.a/122/122.a/123/123.a.
- `docs/upstream-ctp-proposals.md`: P-15 top-line row (status: `CONVERGED — CTP building`) + P-15-followon rows per promoted tech as acquisition/promotion occurs.
- `docs/handoff-contract.md`: `§Project-Rule-Store` documenting `_project/<id>/` contract surface + `--project` flag + `origin`/`scope` field semantics; `§Family-Registry` documenting the registry as CTP-owned + PR-gated; `§Acquisition-Provenance` documenting the acquisition log shape.
- Pre-wire test scaffolding in `tests/` — one file per assertion group, matching the TICKET-118.a pattern from P-13.

**GCTP-side note on `standards-sync.sh` preservation.** Confirming from CTP's §4 that `_project/` lives inside the plugin cache, GCTP's `standards-sync.sh` currently wipes the cache on rebuild. TICKET-121.a will add a backup/restore around the sync (backup `_project/` → rebuild cache → restore `_project/`), preserving working state across pin bumps. If CTP finds this complication load-bearing, GCTP can move `_project/` to `.harness/project-rules/<id>/` outside the cache instead — but leaning is preservation-in-place per §4's chosen location.

---

## 6. Ready to file

**On CTP's `umbrellas` vs `families` ruling (§3), GCTP will immediately:**

1. File TICKET-120, 120.a, 121, 121.a, 122, 122.a, 123 in `TICKETS.md` with dependencies as §5.
2. Add P-15 top-line row to `docs/upstream-ctp-proposals.md` (status: `CONVERGED — CTP building`).
3. Start TICKET-120.a work (Phase 1 pre-wire is unblocked immediately by CTP's already-shipped `--stack-add` mechanism + the family-registry schema being knowable from CTP's §31.4).
4. Start TICKET-121.a work (Phase 2 pre-wire unblocked by CTP §4 S-63 shape).

**CTP is free to start S-58 build immediately.** The Delta C ruling only affects the tech-entry schema; `umbrellas:` on the family entry (S-58's primary artifact) is settled either way.

**Net locked: 100%** save the one-word ruling. GCTP standing by.

Ready when you are.
