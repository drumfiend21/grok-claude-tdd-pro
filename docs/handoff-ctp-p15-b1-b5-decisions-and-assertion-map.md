# GCTP → CTP handoff — P-15: B1–B5 boundary decisions + 14-assertion map onto CTP §31 canonical shapes — the pieces CTP asked for to unblock the S-63→S-58/S-59→S-60→S-62→S-64→S-61 build

**Written:** 2026-07-10 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `11126a8`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟢 **CLOSING THE LOOP — GCTP accepts CTP's §2–§5 as authoritative + answers B1–B5 definitively + maps its 14 acceptance assertions onto CTP's (a)–(e) shapes. CTP unblocked to start S-63.**
**Prior turns:**
- CTP → GCTP: `docs/handoff-ctp-to-gctp-p15-shared-design-proposal.md` + §31.3 architecture append @ CTP `main` `a55db5f` (D1–D5 resolved; B1–B5 isolated; S-58…S-64 defined; §7 asks GCTP to map its 14 assertions).
- GCTP → CTP: `docs/handoff-ctp-p15-reconciliation-shared-design.md` (this repo, 2026-07-10) — GCTP's answers to CTP's five surfaces + four small deltas.
- GCTP → CTP (original): `docs/handoff-ctp-p15-family-umbrella-per-project-provisioning-pr-promotion.md` (this repo, 2026-07-10) — 14-assertion Tier-A/B acceptance corpus at §4.
**Ask:** CTP starts the build in the sequence CTP proposed (S-63 → S-58/S-59 → S-60 → S-62 → S-64 → S-61) using the B1–B5 answers below + the assertion map in §3. GCTP holds pre-wire until S-63 shape lands.

---

## 0. TL;DR

- **§2–§5 accepted as CTP-authoritative, as-is.** Canonical numbering settled on §31 / S-58…S-64. GCTP's §30.8–10 stay as internal labels only (P-12 §27.16 precedent). D1–D5 resolutions adopted verbatim; GCTP-side implications noted in §1.
- **B1–B5 answered definitively** (§2):
  - **B1 project-id:** GCTP assigns (`FEATURE-<NNN>` in consult, `TICKET-<NNN>` in dispatch, operator string for kata); required `--project <id>` on every CTP command touching per-project state; no implicit default.
  - **B2 working-store home:** `.harness/plugin-cache/claude-tdd-pro/_project/<project-id>/`. Inside the plugin cache (GCTP filesystem) but written by CTP-owned scripts; gitignored per CTP §31.
  - **B3 promotion-PR ADR governance:** No new §15 ADR on GCTP for the promotion PR itself — it's a CTP-side code review. GCTP §15 ADR fires on the SUBSEQUENT routine pin bump that adopts merged content, same as every other CTP CL adoption today.
  - **B4 `origin: project` awareness:** `scripts/consult.sh --validate-profile`, `scripts/audit-architecture-crosscheck.sh` invariant-4, and every GCTP grader treat `origin: project` scoped-to-matching-`project-id` as first-class. Cross-project leakage is a fail-loud test, not a silent drop.
  - **B5 growing-surface handling:** `full_surface` reveal (P-14 / §30.7) is not cardinality-hardcoded; effective surface = `official ∪ project(current-project-id)` with origin labels. P-14 acceptance corpus amended in TICKET-119.b.
- **14 GCTP assertions mapped** onto CTP's (a)–(e) shapes + §4 canonical entries (§3). Plus three fail-loud additions (§4) covering the "no silent globalization" spine that CTP restated: cross-project leakage rejection, `--project` flag required, reveal distinguishes `origin`.
- **Build order confirmed:** S-63 → S-58/S-59 → S-60 → S-62 → S-64 → S-61. GCTP pre-wire (TICKET-120.a) starts when S-63 shape is public; adoption tickets 120/121/122 file on each CL tag.
- Additive per ADR-0047. Cite-or-decline preserved. No LLM. Compact-safe.

---

## 1. CTP-authoritative surface (§2–§5) — accepted as-is; small GCTP-side implications noted

**Adopted verbatim (no counter-proposal).**

| CTP decision | GCTP-side implication |
|---|---|
| **D1 — Registry official + PR-gated; working overlays in `_project/` promotable via same gate.** | Matches GCTP's Delta B (2026-07-10 reconciliation doc). No local overlay to reason about. `docs/handoff-contract.md §Family-Registry` (to be added) will note the registry is CTP-owned; GCTP-side additions flow through the promotion PR pattern. |
| **D2 — Reuse the existing 4 fetchers; optional `fetcher:` source field recorded in provenance.** | GCTP consumes the field but does not require it (matches P-13 additive-optional discipline). If absent, GCTP-side reveal shows "fetcher: auto-detected" per source. |
| **D3 — Search only umbrella-matched sources; `--max-sources` default 8; over-budget → `budget_exhausted` + stays `needs_source` (non-silent).** | GCTP `/consult` skill translates `budget_exhausted` into operator-visible language ("we hit N sources without finding X; try `--max-sources 12` or narrow the tech query"). No silent no-op. |
| **D4 — Deduped union of all matched umbrellas' namespaces (Next.js → frontend + backend).** | Matches GCTP's Delta C. GCTP-side reveal shows all family memberships per tech. |
| **D5 — Freshness gate for working; symmetric removal PR for official; `deprecated: true` honored.** | GCTP `applicable_rules` computation SKIPS `deprecated: true` rules by default; `--include-deprecated` for archaeology only. Removal PR flow tracked in `docs/upstream-ctp-proposals.md` alongside promotion PRs (same lifecycle, opposite direction). |

**Numbering.** GCTP accepts §31 / §31.1 / §31.2 / §31.3 as the canonical CTP architecture identifiers. GCTP's earlier §30.8/§30.9/§30.10 labels are retired from cross-repo correspondence; they remain only in GCTP's original P-15 handoff (2026-07-10) as historical context. Going forward every GCTP artifact touching this feature uses §31.x.

**S-58…S-64 registry.** GCTP treats S-58…S-64 as CTP-internal ticket IDs (opaque, referenced in provenance + companion ticket rationale but not renumbered on the GCTP side). GCTP's own TICKET numbering (120/120.a/121/121.a/122) remains independent per prime directive.

---

## 2. B1–B5 — GCTP's definitive answers

### B1 — Project identity contract

**Answer.** GCTP owns assignment of `project-id`. The ID space:

- **Consult sessions:** `FEATURE-<NNN>` — matches existing `.harness/consult-work/FEATURE-<NNN>/` layout. Assigned when the operator invokes `/consult` on a new feature.
- **Dispatch / inner-loop:** `TICKET-<NNN>` — matches existing `.harness/handoffs/TICKET-<NNN>.req.json`. Assigned when the ticket is filed in `TICKETS.md`.
- **Kata / exercise:** stable operator-supplied string; kept for the exercise's lifetime. Current O'Reilly SoftArchCert kata: `FEATURE-003`.

**Contract shape.** Every CTP command that reads or writes per-project state accepts `--project <project-id>` as a REQUIRED flag. No implicit default. Missing `--project` → exit non-zero with a human-readable "specify --project <id>" message. GCTP wraps invocations so operators rarely type the flag themselves; the skill layer injects the current context's id.

**ID format.** `[A-Z][A-Z0-9_-]{2,63}` — case-sensitive; hyphens and underscores allowed; no path separators, no whitespace. CTP schema-validates on receipt (fail-loud on malformed).

**Propagation.** The `project-id` is present in every artifact CTP writes to `_project/<project-id>/` (as `scope: project:<project-id>` on each rule) and in every provenance record (`.harness/consult-work/<project-id>/promoted-rules.log.md`, `_project/<project-id>/.acquisition-log.yaml`). GCTP-side tickets that reference acquired rules carry `project_id: <id>` in their handoff request JSON (additive-optional field on the v1.1 contract; already tolerated by GCTP validators per ADR-0089 pattern).

**Why this shape is GCTP-ideal.** Matches the crossroads/translator model (ADR-0056): GCTP is the coordinator between operator, tickets, sessions, and CTP; the ID lives naturally in GCTP's coordination namespace and CTP consumes as an opaque key. No double source of truth.

### B2 — Working-store home

**Answer.** `.harness/plugin-cache/claude-tdd-pro/_project/<project-id>/`. Inside the plugin cache (GCTP filesystem) but written exclusively by CTP-owned scripts invoked by GCTP with `--project <id>`.

**Prime-directive check.** `_project/` is a DECLARED contract surface (documented in `docs/handoff-contract.md §Project-Rule-Store` and in CTP §31.3), not a private path GCTP reaches into. GCTP does not hand-author or edit rule YAMLs inside `_project/`; the write plane is uniformly CTP's. GCTP's role is `--project`-passing invoker + read-side loader consumer. This preserves the prime directive's "contract-only coupling" clause: contract-surface writes are sanctioned; private-path pokes are not.

**Gitignore.** `_project/` is gitignored per CTP §31 (working-state, not committed data). Pin-bump lifecycle handles cleanup: when a promoted-and-merged tech shows up in `active.json` via `standards-sync.sh`, `release-tech-rules.sh --replaced-by-global` (or equivalent) tidies the overlay entry for that tech.

**Cache-rebuild resilience.** `standards-sync.sh` currently rebuilds `.harness/plugin-cache/claude-tdd-pro/` from the pinned commit on every sync. `_project/` is *not* part of the CTP commit; the rebuild must NOT wipe it. GCTP-side amendment: `standards-sync.sh` preserves `_project/` across rebuilds (backup → rebuild → restore), tracked in TICKET-121.a. Alternative if CTP prefers: `_project/` lives at `.harness/project-rules/<project-id>/` (parallel to plugin-cache, unaffected by rebuild) — GCTP defers to CTP's preference. **GCTP's leaning:** keep `_project/` inside the plugin cache (CTP's proposed location) with the sync-side preservation, because it keeps read-path symmetry (one loader union call, one directory tree). CTP's call.

**Boundary alternative surfaced (not preferred).** If CTP finds the sync-preservation complication load-bearing, `.harness/project-rules/<project-id>/` outside the cache is a viable fallback. Loader has to do a two-tree union instead of one; small delta. GCTP will accept either; the preferred shape is `_project/` inside the cache.

### B3 — Promotion-PR governance in GCTP's ADR machinery

**Answer.** No new GCTP-side §15 ADR requirement for the promotion PR itself. Two-step lifecycle, both steps already covered by existing governance:

1. **Step 1 — Promotion PR against CTP `main`.** GCTP invokes `promote-project-rules.sh --tech vue --project FEATURE-003` (CTP-owned). PR is reviewed and merged/declined by CTP maintainer using CTP's standard PR discipline. GCTP-side artifacts: PR URL logged in `.harness/consult-work/<project-id>/promoted-rules.log.md` + a P-15-followon row in `docs/upstream-ctp-proposals.md` with status `filed → PR open`.
2. **Step 2 — Subsequent pin bump adopts merged content.** When GCTP's next routine pin bump advances past the merge commit, the promoted rules land in `active.json` via `standards-sync.sh`. That pin bump is §15-gated per today's discipline — a new ADR captures which promoted rules are adopted (references the merged PR SHA, tech acquired, source URL). Status in `docs/upstream-ctp-proposals.md` advances to `PR merged → pin bump ADR → adopted`.

**Why no NEW gate.** Every substantive CTP change today follows this same two-step: (a) a CL merges, (b) a pin bump adopts. The promotion PR is one such CL. Adding a separate GCTP ADR requirement for the PR itself would (a) double-gate what's already gated, (b) push GCTP into architecting the promotion (compact violation — CTP owns rule content), (c) create governance drift between promotion PRs and other CTP CLs.

**Traceability.** `docs/upstream-ctp-proposals.md` grows a new section pattern `P-15-followon:<tech>` per promoted tech with status column: `filed → PR open → PR merged → pin bump ADR → adopted`. Same status-tracked lifecycle as P-1…P-15. `promoted-rules.log.md` fields: `tech`, `project-id`, `promoted-at`, `pr-url`, `pr-sha`, `pr-status`, `rule-count`, `canonical-url`, `operator`, `provenance-record-ref`.

**Rejected-PR recovery.** If CTP declines the PR, GCTP-side: `release-tech-rules.sh --tech vue --project FEATURE-003` clears the working overlay; the operator either re-invokes acquisition with fixes and opens a new PR, or leaves the tech project-scoped indefinitely. `promoted-rules.log.md` records `pr-status: declined` with the CTP-side reason; no ADR churn on GCTP side (nothing was adopted).

### B4 — `origin: project` awareness in validators

**Answer.** Every GCTP grader / validator / reveal path treats `origin: project WHERE scope: project:<matching-project-id>` as first-class enforcement, and treats `origin: project WHERE scope: project:<mismatching-project-id>` as inapplicable (fail-loud on presence).

**Touch points (five, all additive):**

1. **`scripts/consult.sh --validate-profile`.** Accepts `origin: project` + `scope: project:<id>` on rule references. Schema violation if `scope` mismatches the profile's `project-id`.
2. **`scripts/audit-architecture-crosscheck.sh` invariant-4.** Applicable-rules computation extends from `active.json` alone to `active.json ∪ _project/<project-id>/*` when a `project-id` is present in the ticket. Loader call passes `--project <id>`; result set carries `origin` + `scope` per rule.
3. **`rubric/runner.sh` (via plugin — GCTP invokes).** Grades project-scoped rules at official rigor for that project's tickets. Returns `rules_verified[]` entries with `origin` + `scope` per rule.
4. **`.claude/hooks/post-tool-use-review-gate.sh`.** Enforces the `origin: project` rules at write-time within the project's files. Cross-project write attempts (e.g., a file under FEATURE-004 that would violate a FEATURE-003-scoped rule) are NOT graded — the rule doesn't apply to that project.
5. **`/consult` skill translation.** When surfacing `applicable_rules` in plain language, distinguishes "project-acquired (scope: FEATURE-003)" from "official (scope: global)" in operator-facing text.

**Fail-loud tests (added to acceptance corpus, §4 below).**

**Why this shape is GCTP-ideal.** First-class-but-scoped is the exact intersection of two guarantees: (a) acquired rules are real enforcement (not "advisory"), (b) blast radius is bounded (no silent globalization). Silent downgrade to advisory violates (a); silent leakage to other projects or global violates (b). The scoping invariant is the load-bearing spine.

### B5 — Growing-surface handling in the reveal

**Answer.** `full_surface` reveal (P-14 / §30.7) has no hardcoded cardinality. Effective reveal per session = `origin: official` (constant per pin) ∪ `origin: project WHERE scope: project:<current-project-id>` (dynamic; grows as acquisition occurs).

**Rendering shape.**
```
[origin=official scope=global]        google, typescript, owasp, w3c, web-vitals, documentation, ...
[origin=official scope=global]        react (provisioned)
[origin=project  scope=FEATURE-003]   vue (acquired 2026-07-10 from vuejs.org/guide/)
[unprovisioned]                       angular, ember, svelte, ...  (available via /consult acquire)
```

**Non-committing property preserved.** Reveal ≠ activation. §30.7's discipline (menu shown at Stage 0; activation only via stack-add or family-fire) applies uniformly to both official and project entries. Revealing an unprovisioned tech does NOT scrape.

**P-14 acceptance-corpus amendment.** GCTP-side, tracked in TICKET-119.b (post-P-14 adoption follow-up): replace any hardcoded cardinality assertion (e.g., "reveal contains 44 namespaces") with the structural form "reveal contains ≥ N_official + N_project namespaces where N_project = `ls _project/<project-id>/ | wc -l`." Backwards-compatible when no `project-id` is present (global-only reveal).

**Budget interaction (D3 tie-in).** When acquisition hits `budget_exhausted` and the tech stays `needs_source`, the reveal marks the tech `[needs_source]` (distinct from `[unprovisioned]`) so the operator sees the state without confusion. GCTP `/consult` skill translation: "we searched 8 sources for 'vue' without finding a canonical hit; try `/consult acquire vue --max-sources 12` or supply a specific source."

---

## 3. Assertion map — GCTP's 14 acceptance assertions → CTP §31 canonical shapes

Mapping each GCTP assertion from `docs/handoff-ctp-p15-family-umbrella-per-project-provisioning-pr-promotion.md §4` onto CTP's (a)–(e) shapes + §31.3 canonical entries. Assertions renamed to §31.x nomenclature per §1 numbering settlement.

### §31 — Family umbrella activation (GCTP-original §30.8; assertions 1–4)

| GCTP # | Original text (compressed) | CTP shape target | Notes |
|---|---|---|---|
| A1 | Vision naming `vue` fires `web-frontend`; family `frontend` activates; umbrella namespaces `[google, typescript, owasp, w3c, web-vitals, documentation]` in `activated_probe_namespaces`. | CTP (a) family-registry entry + classifier catalog widening. | Verifies the D1 umbrella lookup path. Aligns with CTP §31 activate-umbrella move. |
| A2 | Vision naming `angular` fires the same umbrella set. | CTP (a). | Confirms family membership union works for a second tech; guards against React-only regression. |
| A3 | Vision naming a tech NOT in registry emits actionable note ("no family entry; add via family-registry PR"); does NOT phantom-activate. | CTP (a) + D1 registry-PR flow. | Cite-or-decline preserved at classifier layer. |
| A4 | Registry schema-validates: every family has `umbrella_namespaces`; every referenced namespace exists in `active.json`. | CTP (a) schema validation + D1 registry-PR gate. | Catches malformed PR contributions at ingest. |

### §31.1 — Per-project acquisition (GCTP-original §30.9; assertions 5–10)

| GCTP # | Original text (compressed) | CTP shape target | Notes |
|---|---|---|---|
| A5 | `acquire-tech-rules.sh --tech <unprovisioned>` with reachable URL succeeds; writes YAML to `_project/<project-id>/<namespace>/`; provenance record generated. | CTP (b) acquisition CLI + `_project/` overlay shape from §31.3. | Verifies the happy-path acquire. |
| A6 | `acquire-tech-rules.sh --tech <unprovisioned>` with unreachable URL exits 2 (cite-or-decline). | CTP (b) + D3 budget-exhaustion boundary. | Distinguish "URL unreachable" (exit 2) from `budget_exhausted` (`needs_source`); both are non-silent per D3. |
| A7 | `acquire-tech-rules.sh --tech <already-globally-provisioned>` exits 0 no-op ("already global"). | CTP (b). | Guards against double-provisioning; loader union already covers this rule via `active.json`. |
| A8 | Loader unions `active.json` (global) with `_project/<project-id>/*` (project overlay); project's effective rule set reflects both. | CTP §31.3 canonical overlay shape + loader spec. | Load-bearing for B4 (first-class enforcement). |
| A9 | Acquisition DOES NOT modify global `active.json`. Byte-identical before/after. | CTP §31.3 write-plane split (working vs official). | Load-bearing for the "no silent globalization" spine. This IS GCTP's own test of that invariant, per CTP §7. |
| A10 | `release-tech-rules.sh` reverts; classifier no longer activates the namespace. | CTP (b) release CLI + `_project/` overlay clearance. | Reversibility. |

### §31.2 — PR promotion (GCTP-original §30.10; assertions 11–14)

| GCTP # | Original text (compressed) | CTP shape target | Notes |
|---|---|---|---|
| A11 | `promote-project-rules.sh --tech vue --project FEATURE-003` assembles a PR diff containing all six artifacts (rule YAMLs + axis binding + registry flip + source registry entry + acceptance-test spec + PR body). | CTP (c) promotion CLI + PR envelope shape from §31.3. | Verifies PR content completeness. |
| A12 | PR diff includes auto-generated acceptance-test spec citing canonical URL per rule. | CTP (c) + D2 fetcher-provenance carry-forward. | The promotion PR is reviewable: extracted YAMLs + citations + tests. |
| A13 | On CTP-side merge simulation, next pin bump lifts overlay to global; the project overlay folder is safely removable. | CTP (c) + B3 pin-bump adoption path. | End-to-end lifecycle test; GCTP-side pin-bump adoption tested in TICKET-121.a. |
| A14 | Promotion writes provenance record with operator + timestamp + canonical URL + rule count + rule-extraction version. | CTP (c) + D2 fetcher-provenance record shape. | Long-term traceability for the community-facing rule set. |

**Cross-cut with CTP's build order.** A1–A4 exercise S-58 (family registry) + S-59 (classifier widening). A5–A10 exercise S-63 (`_project/` foundation) + S-60 (acquisition pipeline). A11–A14 exercise S-62 (promotion) + S-64 (recovery/removal). S-61 (technology-fitness recommender) is exercised by three additional assertions GCTP proposes below (§4.4).

---

## 4. Three additional fail-loud assertions (added to the acceptance corpus)

Restating and formalizing the additions from GCTP's 2026-07-10 reconciliation doc §6, plus one S-61-specific assertion.

### A15 — Cross-project leakage rejected (fail-loud)

**Assertion.** A rule with `origin: project scope: project:FEATURE-003` graded against a `project: FEATURE-004` ticket → invariant-4 REJECTS. The rule does not appear in FEATURE-004's `applicable_rules`; the grader emits a diagnostic ("scope mismatch: rule scoped to FEATURE-003, ticket in FEATURE-004") and continues. Silent drop is a failure mode; the diagnostic is the tell.

**Why load-bearing.** This IS the mechanized "no silent globalization" test on the cross-project axis (§31.3 addresses the cross-repo axis via the byte-identical `active.json` assertion A9; A15 addresses the intra-repo cross-project axis).

### A16 — `--project` flag required (fail-loud without)

**Assertion.** Invoking any CTP command touching per-project state (`acquire-tech-rules.sh`, `release-tech-rules.sh`, `promote-project-rules.sh`, per-project reveal) WITHOUT `--project <id>` → exit non-zero with a human-readable message. No implicit default; no ambient current-project.

**Why load-bearing.** Prevents accidental cross-project contamination via omission. Matches D3's non-silent-no-op discipline.

### A17 — Reveal distinguishes `origin: official` from `origin: project`

**Assertion.** `full_surface` reveal at Stage 0 emits `available_menu[]` entries with `origin` + `scope` fields set correctly per source. Machine assertion: `jq '.available_menu[] | select(.namespace == "vue") | .origin' == "project"` when Vue is acquired for the current `project-id`; `== "official"` when `active.json` contains Vue globally.

**Why load-bearing.** Confirms B5's growing-surface handling emits distinguishing metadata; downstream `/consult` translation and operator-facing labeling depend on it.

### A18 — S-61 tech-fitness recommender surfaces alternatives with rationale

**Assertion.** When the S-61 recommender fires (e.g., "for the SoftArchCert kata Vue frontend at scale X with regulatory constraint Y, would React be a better fit?"), the recommendation includes: (a) the recommended alternative, (b) the rationale citing at least one authoritative source from the umbrella-matched sources, (c) confidence bounded to the source corpus, (d) opt-out path ("stay with Vue; acquisition unchanged"). No LLM in the recommendation path — the rationale is drawn from scraped source content.

**Why included now.** CTP identified S-61 as the "Angular over React when warranted" piece; GCTP wants an assertion on the recommender's shape so the boundary between "acquired-rules-active" (§31.1) and "acquired-rules-recommended-instead" is testable. The recommender output must be transparent (source-cited) and operator-overridable, per compact discipline.

---

## 5. Build order + GCTP companion tickets

**CTP build order confirmed.** S-63 → S-58 / S-59 → S-60 → S-62 → S-64 → S-61.

**GCTP companion tickets (filed in `TICKETS.md` on CTP confirmation of this doc):**

| GCTP ticket | Scope | Depends on |
|---|---|---|
| **TICKET-120.a** | Pre-wire: contract-test tolerance for `origin: project` + `scope: project:<id>`; `--project` flag propagation in `scripts/consult.sh` + `scripts/dispatch.sh`; `docs/handoff-contract.md §Project-Rule-Store` doc; `standards-sync.sh` `_project/` preservation-across-rebuild logic; machine acceptance test scaffolding (A1–A18 skeletons). | S-63 shape public |
| **TICKET-120** | Pin bump adopting S-58 + S-59 (family umbrella activation). §15 ADR references CTP CL SHAs; `docs/handoff-contract.md §Family-Registry` doc; `/consult` skill translation of umbrella activation to plain language. | CTP S-58 + S-59 tagged |
| **TICKET-121.a** | Pre-wire: invariant-4 grader extension to project-scoped rules (fail-loud on cross-project leakage — A15); `--project`-required enforcement (A16); reveal origin distinction (A17); assertion suite green-locked against CTP staging. | S-60 shape public |
| **TICKET-121** | Pin bump adopting S-60 + S-63 (per-project acquisition + `_project/` foundation). §15 ADR; `.harness/consult-work/<id>/promoted-rules.log.md` scaffolding; kata runbook updated with acquisition flow for FEATURE-003. | CTP S-60 + S-63 tagged |
| **TICKET-122.a** | Pre-wire: promotion-PR envelope validation (A11–A14 skeletons); `docs/upstream-ctp-proposals.md` `P-15-followon:<tech>` status pattern; rejection-recovery handling. | S-62 shape public |
| **TICKET-122** | Pin bump adopting S-62 + S-64 (promotion + removal). §15 ADR; `/consult` skill translation of promotion flow; deprecation-honoring in `applicable_rules` (D5). | CTP S-62 + S-64 tagged |
| **TICKET-123** | Pin bump adopting S-61 (tech-fitness recommender). §15 ADR; `/consult` skill translation of recommendation output; A18 assertion greened; kata runbook updated to exercise the recommender. | CTP S-61 tagged |

**GCTP pre-wire discipline.** No pre-wire ticket starts before the corresponding CTP ticket has a public shape (matches TICKET-118.a → §30.4/§30.5 pattern from P-13). Pin-bump tickets file only after CTP tags the containing CL. §15 ADR required on every pin bump per today's discipline.

**Cross-reference.** GCTP will append a P-15-status row to `docs/upstream-ctp-proposals.md` on this doc's confirmation (initial status: `RECONCILED — CTP building`, advancing per CTP CL tags to `S-63 landed`, `S-58/S-59 landed`, etc., through `all adopted`).

---

## 6. Summary — what CTP can proceed with

1. **Accept §2–§5 as canonical** (already CTP-decided; GCTP explicitly confirms).
2. **Consume B1–B5 answers** in §2 above; all five decided.
3. **Consume the 14-assertion map** in §3 as inputs to the S-58/S-59/S-60/S-62/S-64 acceptance corpora.
4. **Consume three added fail-loud assertions** in §4 (A15 cross-project leakage, A16 `--project` required, A17 reveal origin distinction) plus S-61-specific A18 (recommender shape).
5. **Proceed on the build order** S-63 → S-58/S-59 → S-60 → S-62 → S-64 → S-61 as CTP proposed. GCTP pre-wires per §5 on each shape publication.
6. **Nothing else blocking on GCTP.** Every open surface CTP flagged is decided; every assertion GCTP originally filed is mapped; every companion GCTP ticket is scoped and sequenced.

CTP is unblocked. GCTP holds pre-wire on S-63 shape.

Ready when you are.
