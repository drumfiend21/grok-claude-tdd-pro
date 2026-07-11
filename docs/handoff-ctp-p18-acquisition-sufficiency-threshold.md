# GCTP → CTP handoff — P-18: acquisition-sufficiency threshold — every stacked technology in a project's effective rule set MUST carry ≥ 30 rules acquired from existing trusted sources; the CTP-side capability + GCTP-side enforcement split respects the pre-existing prime-directive and plugin-consumer roles

**Written:** 2026-07-10 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `16e9623`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟡 **QUALITY-FLOOR HANDOFF** — empirical finding from KA-2 (TICKET-126, 2026-07-10) surfaced that Vue acquisition against a 5-line stub cache produced 3 rules — insufficient to design an architecture or develop a codebase on Vue. Operator has declared **≥ 30 rules per stacked technology** as the hard quality floor. This handoff splits the work: **CTP owns the capability** (source coverage + extraction depth + tech-specific whole-source handling + sufficiency signal per acquisition); **GCTP owns the enforcement** (quality-gate invariant refusing design cross-check when any stacked tech has fewer than 30 rules in its effective rule set). Both changes are additive per ADR-0047 and preserve the prime-directive plugin-consumer split (CTP delivers rule content/extraction; GCTP enforces operator-declared standards regime per ADR-0037 TIER-1).
**Prior turns:**
- KA-2 (TICKET-126 `5b64eb1`, 2026-07-10): `acquire-technology-live.sh --technology vue --project FEATURE-003 --cache <5-line-stub>` returned `sources_matched=4 sources_fetched=1 acquired_total=3`. Pipeline mechanics correct; volume insufficient.
- Operator directive (this turn): *"three rules is not substantial to design an architecture or develop a codebase with Vue. Consider the design that I described, which is to utilize existing trusted sources to get a substantial set of such rules. This will be defined by me as at least 30 rules for any particular technology utilized in a stack, found in the way I have already described."*

---

## 0. TL;DR

- **The 30-rule minimum is an operator-declared TIER-1 standard** per the operator-declared-standards regime (ADR-0037): a non-negotiable, always-on quality gate. Both agents MUST refuse to proceed to design cross-check (`/consult` cascade, `/roadmap` render, `/decompose` output consumption) if any technology committed to the stack — via `--stack-add`, `families_active`, or S-58 resolver — carries fewer than 30 rules in its effective rule set (`active.json ∪ _project/<project-id>/`).
- **Root cause is a two-part gap** empirically observed in KA-2: (a) the umbrella-matched general sources (typescript-handbook / google-tsguide / node-best-practices / node-docs for Vue) filtered by `--only-mentioning <tech>` yield only a handful of rules per source; (b) tech-specific canonical sources (e.g. `vuejs.org/guide` for Vue, `angular.io/docs` for Angular) are missing from the source registry, so the acquisition pipeline has no path to the substantial per-tech rule surface those canonical docs contain.
- **The split honors existing contract + roles**: CTP owns rule content, source registry, and acquisition-pipeline extraction depth (§P-18/CTP items below); GCTP owns operator-declared quality-gate enforcement (§P-18/GCTP items below). Neither side reaches into the other; the contract-surface change is a new optional `sufficiency:` signal per-acquisition that CTP emits and GCTP consumes.
- **Additive per ADR-0047**: source-registry entries added (never subtracted); extraction depth increased (never decreased); GCTP-side gate is a NEW audit that adds to the enforcement chain (never relaxes an existing check). Cite-or-decline preserved; no LLM; compact-safe (agent still originates no architecture — GCTP's gate is a declarative threshold check, not a synthesis step).

---

## 1. The empirical finding (KA-2, verbatim)

At CTP pin `16e9623`, on the SoftArchCert kata's FEATURE-003 project, I ran:

```
$ acquire-technology-live.sh --technology vue --project FEATURE-003 --cache <5-line-stub>
sources_matched=4 sources_fetched=1 acquired_total=3
```

The 4 sources matched Vue's umbrella (`frontend`): `google-tsguide`, `typescript-handbook`, `node-docs`, `node-best-practices`. My hand-populated cache seeded ONE of them (typescript-handbook) with 5 lines of realistic Vue-mentioning content:

```
Use TypeScript with Vue Single File Components for type safety in templates.
Vue 3 Composition API provides better type inference than Options API.
Prefer explicit function return types in composable functions.
Use `defineProps` and `defineEmits` in Vue script setup for type-safe props.
Avoid `any` in general — use `unknown` and narrow via type guards.
```

The `--only-mentioning vue` filter correctly dropped the last line (no Vue mention) and acquired 3 rules from the remaining 4 lines (line 3 doesn't mention Vue explicitly but was retained — worth confirming with CTP that the filter matches by tech name + reasonable synonyms/context).

**The empirical extrapolation to real sources**: if a 5-line Vue-mentioning stub yields 3 rules, and the actual `typescript-handbook` has (rough estimate) 50-200 statements mentioning Vue across its introduction / Vue-interop / component-typing / template-typing sections, then whole-source acquisition MIGHT yield 10-40 Vue rules from typescript-handbook alone. Similar for the other 3 general sources — perhaps 5-20 rules each. Realistic per-Vue total from JUST umbrella-general sources: 30-100 rules.

**But the operator's directive is stronger than "MIGHT hit 30"**: the design must **guarantee** ≥ 30 rules per stacked tech by construction. That means (a) the source registry must include tech-specific canonical sources (`vuejs.org/guide` for Vue), (b) whole-source acquisition (skip `--only-mentioning`) applies when a source IS the tech's canonical documentation, (c) extraction depth per source is not artificially limited, and (d) the acquisition surface reports a sufficiency signal so downstream can gate on it.

---

## 2. What CTP owns (capability)

Four composed additive changes, all inside CTP:

### 2.1. Source-registry sufficiency — tech-specific canonical sources per registered technology

**Ask.** For every technology in `standards/technology-umbrella-registry.yaml` where `specific_namespace: null` (i.e., no rules-of-its-own shipped globally), add at least one **tech-specific canonical source** to `standards/sources.yaml` (or an appropriate catalog file). Examples:

| Technology | Umbrella-general sources (already shipped) | Tech-specific canonical source (to add) |
|---|---|---|
| `vue` | google-tsguide, typescript-handbook, node-docs, node-best-practices | `https://vuejs.org/guide/` (`applies_to: [vue]`, fetcher: `html-anchor.sh`) |
| `angular` | google-tsguide, typescript-handbook, node-docs, node-best-practices | `https://angular.io/docs` (`applies_to: [angular]`, fetcher: `html-anchor.sh`) |
| `svelte` | google-tsguide, typescript-handbook, node-docs, node-best-practices | `https://svelte.dev/docs` (`applies_to: [svelte]`, fetcher: `html-anchor.sh`) |
| `postgresql` (if added) | owasp-asvs, aws-reliability, google-sre-book | `https://www.postgresql.org/docs/` (`applies_to: [postgresql]`, fetcher: `html-anchor.sh`) |
| `elysia` (if added) | google-tsguide, typescript-handbook, node-best-practices | `https://elysiajs.com/introduction.html` (`applies_to: [elysia]`, fetcher: `html-anchor.sh`) |

**Discipline.** Every added source carries the full CTP source-entry schema (`id`, `name`, `url`, `tier`, `applies_to: [<tech-name>]`, `fetch_frequency`, `fetcher`, `authority_tier`, `fragility_tier`, `license_note`). Tier: typically `1` for the tech's own canonical docs. Applies-to is `[<tech-name>]` — a single-tech source, distinct from the multi-tech umbrella sources.

**Why CTP owns this.** Source content is CTP's domain (per §31 shipped design: "we search the same authoritative-source pipeline the plug-in already uses for React"). GCTP filing a source-registry PR is the standard §31.2 promotion path — but for a canonical seed of every registered technology, CTP-authored is more efficient than operator-PR-per-tech.

### 2.2. Whole-source acquisition when a source IS tech-specific

**Ask.** When `acquire-technology-live.sh` evaluates a matched source and the source's `applies_to` is exactly `[<tech-name>]` (or `[<tech-name>]` plus umbrella tokens like `frontend`), the acquisition SHOULD acquire the whole source without the `--only-mentioning <tech>` filter — because the entire source IS about the technology, and every statement in it is a rule candidate.

**Contract shape.** Extend `acquire-technology-live.sh`'s per-source decision:

```
if source.applies_to == [tech] OR source.applies_to.include?(tech):
    A_ARGS += --only-mentioning <tech>   # filter to Vue-mentioning lines in a general source
else if source.applies_to.include?(tech-canonical-marker):
    # whole source — no filter (or equivalent for whole-source ingest)
    A_ARGS -= --only-mentioning
```

Or, simpler: add a `whole_source: true` field on the source entry, and `acquire-technology-live.sh` skips `--only-mentioning` for those entries. Either shape works; CTP's call on which is cleaner.

**Why CTP owns this.** Extraction discipline is CTP's domain. The filter's job is precision: keep only the tech-mentioning lines from a general source, and take everything from a tech-specific source. GCTP has no visibility into what's in a source file — CTP owns the extraction.

### 2.3. Extraction depth per source — no artificial limit

**Ask.** Audit `acquire-technology-rules.sh` (and any intermediate rule-extraction step) to confirm no artificial rule-count cap per source. If a source has 200 acquirable statements, acquisition should yield 200 rules (subject to normal deduplication and validity checks), not a truncated subset.

**Verification approach.** CTP's own test suite should include an assertion: `acquire-technology-rules.sh --source-file <long-source> --technology <tech>` yields a rule count within an expected range for a known-large source. If a cap exists intentionally (e.g., budget/performance), surface it as an operator-visible signal (`truncated=true source_had=200 acquired=100`).

**Why CTP owns this.** Same as 2.2 — extraction is CTP's domain.

### 2.4. Sufficiency signal per acquisition

**Ask.** Every `acquire-technology-live.sh` invocation emits (in the existing stderr summary line) a `rule_count=<n>` field naming the total rules acquired across all fetched sources for this technology. Optionally: a `sufficiency=ok|below-threshold-<n>|insufficient` marker with a CTP-recommended threshold (default matching operator's 30-rule floor, overridable via env).

**Contract shape (proposal).**

```
sources_matched=4 sources_fetched=4 acquired_total=47 rule_count=47 sufficiency=ok technology=vue project=FEATURE-003
```

vs.

```
sources_matched=4 sources_fetched=1 acquired_total=3 rule_count=3 sufficiency=below-threshold-27 technology=vue project=FEATURE-003
```

**Why CTP owns emission** (and GCTP owns enforcement): CTP knows the count truthfully at the point of acquisition; GCTP reads the count from the acquired `_project/` overlay and enforces the threshold at gate time (see §3 below). Neither side reaches into the other; they meet at the sufficiency signal on the shared contract surface.

---

## 3. What GCTP owns (enforcement)

Three composed additive changes, all inside GCTP, mirroring the ADR-0037 operator-declared-standards discipline.

### 3.1. New quality-gate audit: `scripts/audit-acquisition-sufficiency.sh`

**Ask.** New audit script that, given a `--project <id>`, walks `_project/<id>/*/` counting rules per namespace (per YAML file's `rules[]` array). For every technology committed to the project's stack (from the profile's `stack[]` or `families_active[]` or `project_overlay_namespaces[]`), assert `count(_project/<id>/<ns>/*/rules[]) + count(active.json.rules WHERE source_namespace == <ns>) >= 30`. If any tech is below threshold, exit 1 with a fail-loud diagnostic naming the tech and the count.

**Environment overrides (testability).**
- `AS_THRESHOLD` — default `30`. Operator can bump higher (e.g. `50`) for high-stakes projects.
- `AS_RULES_FILE` — default `.harness/rules/active.json`.
- `AS_PROJECT_STORE` — default `.harness/plugin-cache/claude-tdd-pro/generated-code-quality-standards/_project`.

**Exit codes.**
- `0` — every stacked tech meets threshold (or no stacked techs — vacuous pass).
- `1` — one or more techs below threshold; diagnostic lists each with count.
- `2` — usage error / missing project store.

**Wire-up.** Compose into `scripts/audit-doc-drift.sh` chain (or the pre-commit / pre-consult chain wherever the operator-declared-standards audits run today per ADR-0037's post-tool-use enforcement pattern). Runs at:
- Pre-`/consult` cascade — refuses to proceed to Stage 2 probe-answers if Stage 1 committed a tech below threshold.
- Pre-`/roadmap` render — refuses to render a roadmap for a project whose stacked techs are insufficient.
- Pre-`/decompose` output consumption — TICKET-NNN emission blocked until threshold met.

### 3.2. Wire the invariant into invariant-4 grader

**Ask.** Extend `scripts/audit-architecture-crosscheck.sh` invariant-4 (TICKET-121.b) so that when computing the applicable-rules-per-decision target set, it ALSO enforces that every stacked namespace has ≥ 30 rules available. Absent from `_project/<id>/*` AND absent from `active.json.rules[where source_namespace==<ns>]` with rule count < 30 → fail-loud with a scope-aware diagnostic.

**Test scaffolding.** Add assertions to `tests/test-audit-architecture-crosscheck.sh`:
- `insufficient acquisition for stacked tech vue (count=3) → violation (1)`
- `sufficient acquisition (count=35) → pass`
- `sufficient globally-provisioned tech (react in active.json count=6 + _project overlay count=30) → pass`
- `mixed: react OK, vue below → violation names vue only`

### 3.3. Document as TIER-1 operator-declared standard

**Ask.** Amend `docs/quality-gate.md` (§Sub-gates or add a new §Acquisition-Sufficiency) documenting the ≥ 30-rule floor as a non-negotiable member of the operator-declared standards regime per ADR-0037. Cite the operator directive (this turn's message). Amend `docs/architecture-principles.md` §16 (R-rules) if a new R-rule is warranted (e.g., R-21: "any technology committed to a project's stack MUST carry ≥ 30 rules in its effective rule set"). Land as a new ADR.

**Cross-reference.** Update `.harness/rules/active.json` regeneration to include acquisition-sufficiency as an audited invariant (metadata only — the count is enforced at gate time, not baked into the rule surface itself).

---

## 4. What "substantial" looks like empirically (expected shapes)

For KA-3 (post-P-18 CTP-side + GCTP-side work landing), running `acquire-technology-live.sh --technology vue --project FEATURE-003 --cache <live-fetched-dir>` should yield something like:

| Source | applies_to | `--only-mentioning` filter | Expected Vue rules |
|---|---|---|---|
| google-tsguide | [typescript, react] | yes | 3-10 (only lines mentioning Vue) |
| typescript-handbook | [typescript] | yes | 5-15 (Vue-interop + Vue-typing sections) |
| node-docs | [node] | yes | 0-2 (Vue rarely mentioned in Node core docs) |
| node-best-practices | [node] | yes | 2-8 (some Vue-mentioning practices) |
| **vuejs-guide (NEW per §2.1)** | **[vue]** | **no (whole-source per §2.2)** | **30-100** (entire canonical docs) |
| **vuejs-api-ref (optional)** | **[vue]** | **no** | **20-60** |

Realistic total: **60-195 Vue rules**, comfortably above the 30-rule floor.

Same shape for Angular (angular.io/docs whole-source ~40-100), Svelte (svelte.dev/docs whole-source ~30-80), Postgres (postgresql.org/docs whole-source ~50-200), etc.

Sufficiency signal example after P-18:

```
sources_matched=6 sources_fetched=6 acquired_total=87 rule_count=87 sufficiency=ok technology=vue project=FEATURE-003
```

---

## 5. Prime-directive compliance + role split

- **CTP owns rule content, source registry, extraction pipeline** — §P-18/CTP items 2.1–2.4 are entirely on the CTP side; no GCTP edits.
- **GCTP owns operator-declared-standards enforcement** (per ADR-0037 TIER-1) — §P-18/GCTP items 3.1–3.3 are entirely on the GCTP side; no CTP edits.
- **They meet at the sufficiency signal** on the acquisition summary line + the shared `_project/<id>/*` directory shape — same clean seam the P-15 convergence established.
- **No cross-repo edits.** GCTP files this as P-18 upstream; CTP builds; GCTP pin-bumps per §15 ADR following ADR-0092/0093 precedent; GCTP-side audit ships in the same or subsequent CL under its own ticket.
- **Additive per ADR-0047.** Source registry entries added (never subtracted); extraction depth increased (never decreased); GCTP audit is NEW (never relaxes an existing check).
- **Cite-or-decline preserved.** A tech with fewer than 30 rules → fail-loud "insufficient acquisition; canonical sources not yet available in registry OR acquisition truncated" (not silent, not fabricated).
- **Compact-safe.** GCTP's threshold check is a declarative comparison (`count >= 30`), not a synthesis step. Agent still originates no architecture.

---

## 6. What GCTP is asking of CTP (summary)

1. **Build the four §2 CTP-side items** (source-registry canonical sources per registered tech + whole-source acquisition semantics + extraction-depth audit + sufficiency signal on the summary line). Priority: **highest** — this is the last piece to make P-15 acquisition produce a substantial rule set, which is the whole point of the feature.
2. **Ship as a §31.9 amendment** (or wherever CTP prefers in the §31 arc) plus companion CL landing the source-registry additions. GCTP re-pins per §15 ADR following ADR-0092/0093 precedent.
3. **Return with a shaped proposal** — either "file as P-18 with §31.9 in v1.27, ship canonical-sources-first" or a counter-shape. GCTP files the ticket(s) on CTP's proposed shape.

## 7. What GCTP will do in parallel (startable NOW without CTP shape)

1. **Build `scripts/audit-acquisition-sufficiency.sh`** at fail-loud pre-CTP-ship level: even before CTP adds the sufficiency signal, GCTP can count rules per `_project/<id>/<ns>/*/rules[]` from the `_project/` overlay directly + `active.json.rules WHERE source_namespace == <ns>` and enforce ≥ 30. Once CTP ships the sufficiency signal, GCTP consumes it (redundant belt-and-suspenders check).
2. **Add tests** to `tests/test-audit-acquisition-sufficiency.sh` (new) covering: no stacked techs → vacuous pass; sufficient count → pass; insufficient count → fail-loud with tech name; mixed sufficient/insufficient → violation lists only insufficient; XC_PROJECT_ID scoping.
3. **Amend `docs/quality-gate.md`** documenting the 30-rule floor as TIER-1 operator-declared standard per ADR-0037.
4. **Land as GCTP ticket TICKET-127** with a matching ADR (likely ADR-0094) for the new quality-gate invariant.

Filed as **P-18** in `docs/upstream-ctp-proposals.md`. Awaiting CTP consult on the §2 items.

Ready when you are.
