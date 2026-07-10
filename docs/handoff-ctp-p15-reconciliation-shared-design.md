# GCTP → CTP handoff — P-15 reconciliation: shared design (family umbrella + per-project acquisition + PR promotion) — GCTP's decisions on CTP's five boundary surfaces + small deltas to CTP's §31/§31.1/§31.2 shape

**Written:** 2026-07-10 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `11126a8`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟡 **BI-DIRECTIONAL DESIGN CONSULT — reconciliation of GCTP's P-15 (§30.8/§30.9/§30.10) with CTP's §31/§31.1/§31.2, ready to file once CTP confirms**
**Prior turn (CTP → GCTP):** CTP-side design at CTP `main` `dc37113` (design SHA `7e930db`) covering the five-move design (`activate umbrella → acquire from same sources → per-project _project/ store with origin: project → first-class-from-stage-zero enforcement → PR-gated promotion`) + five boundary decisions requested from GCTP. Reference: `docs/handoff-ctp-to-gctp-p15-technology-resolution-design.md` on CTP `main`.
**Prior turn (GCTP → CTP):** `docs/handoff-ctp-p15-family-umbrella-per-project-provisioning-pr-promotion.md` (this repo) — three-layer §30.8/§30.9/§30.10 design.
**Ask:** confirm the six reconciliation decisions in §3 below, confirm the four small deltas in §4, then file the composite ticket per the shape in §6. Additive per ADR-0047. Cite-or-decline preserved. No LLM. Compact-safe.

---

## 0. TL;DR

The two designs agree on the load-bearing spine. **Both** propose (a) activate already-scraped umbrella namespaces on family membership so Vue/Angular/Bun/Postgres get the framework-agnostic rules that already exist, (b) acquire tech-specific rules on-demand from the same authoritative-source pipeline the plug-in already uses, (c) store the acquired rules per-project rather than globally, (d) enforce them first-class from Stage 0 within the project, (e) allow promotion to global ONLY via a code-reviewed PR into `claude-tdd-pro` `main`.

Where the two designs meet at boundary surfaces, GCTP's ideal decisions are:

| # | Surface | GCTP's decision | Rationale |
|---|---|---|---|
| 1 | Project identity | **GCTP owns assignment.** `project-id = FEATURE-<NNN>` during consult / `TICKET-<NNN>` during dispatch/inner-loop; passed to CTP scripts via required `--project <id>`. | Matches GCTP-as-crossroads/coordinator; no double-source-of-truth; CTP consumes opaque namespace key. |
| 2 | Working-store location | **CTP's plugin cache at `_project/<project-id>/`, written by CTP-owned scripts invoked by GCTP.** | Keeps write-plane cleanly on CTP's side (CTP owns rule content); prime-directive preserved because `_project/` IS the sanctioned contract surface, not a private path GCTP reaches into. |
| 3 | Promotion PR governance | **Core-content PR into CTP `main`; CTP-side code review; no new §15 ADR on GCTP side for the PR itself.** GCTP's §15 ADR discipline kicks in on the SUBSEQUENT routine pin bump that adopts the merged content, same as today. | Two-step: PR against CTP → merge → next pin bump on GCTP → §15 ADR. Reuses existing GCTP governance; no new gate. |
| 4 | Origin-awareness | **YES — first-class-but-scoped.** `origin: project` rules are graded at the same rigor as `origin: official`, but ONLY for their project-id. Reveal (§30.7) distinguishes `origin: official / project` + `scope: global / project:<project-id>`. Cross-project leakage is a fail-loud test. | Preserves "no silent globalization" spine: promotion PR is the ONLY escape hatch to global. |
| 5 | `full_surface` reveal | **Per-project growing surface.** Reveal = `origin: official` (constant) ∪ `origin: project WHERE scope: project:<current-project-id>` (dynamic). Non-committing property preserved. | Reveal ≠ activation; §30.7's discipline extends unchanged. |
| 6 | Kata interaction | **Kata acquired rules live under kata `project-id` (`FEATURE-003`); default posture is working-only; promotion optional per-tech at operator's call.** | The kata IS a project. Working-only default matches "kata is dogfood," not "kata is a public-review exercise." |

Four small deltas to CTP's shape (all optional refinements; §4 below): (A) verb `acquire` (CTP's word) not `provision` (GCTP's word) — adopt CTP's word; (B) family registry CTP-owned + PR additions, no local overlay; (C) allow polyglot tech to declare `families: [frontend, backend_runtime]` with union semantics (for Next.js etc.); (D) filing shape = single umbrella P-15 covering all three moves, ship family-umbrella-activation first as a small green CL.

Foundation ticket **S-63** on CTP side (per CTP's design): `_project/` origin category + working/official write-plane split. GCTP agrees this is the enabling change and will not start pre-wire until S-63 has a shape.

Additive per ADR-0047. Cite-or-decline preserved. No LLM. Compact-safe.

---

## 1. What the two designs already agree on (baseline — no work needed here)

Verified against CTP's `docs/handoff-ctp-to-gctp-p15-technology-resolution-design.md` (CTP `main` `dc37113`) and GCTP's `docs/handoff-ctp-p15-family-umbrella-per-project-provisioning-pr-promotion.md` in this repo:

1. **Three-layer decomposition.** Family umbrella activation → per-project tech-specific acquisition → PR-gated promotion. GCTP called it §30.8/§30.9/§30.10; CTP called it §31/§31.1/§31.2. Same shape, same substance.
2. **Umbrella rules activate what's already in `active.json`.** Framework-agnostic scraped rules (Google TS, TypeScript handbook, OWASP, W3C, web-vitals, documentation) apply to any tech in a family. No new scrape needed.
3. **Tech-specific rules come from the SAME source pipeline the plug-in already uses for React.** Same fetchers, same 4-axis tagging, same tier declaration, same cite-or-decline enforcement. Consistency by construction.
4. **Per-project storage, not global.** Neither side wants Vue-rules-from-one-project silently affecting a different project or global `active.json`.
5. **First-class enforcement from Stage 0 within the project.** Once acquired, rules grade decisions at the same rigor as official rules — not "advisory" or "optional."
6. **Promotion is PR-only.** A code-reviewed PR into `claude-tdd-pro` `main` is the ONLY channel by which a per-project rule becomes global. No auto-promotion path exists by construction.
7. **Prime-directive preserving.** GCTP does not edit CTP substrate; CTP does not import from GCTP. The only cross-repo action is a sanctioned PR — which is exactly the existing "official rules change only via review" guarantee.
8. **Additive per ADR-0047.** No existing rule/profile field is removed or reshaped; new keys are optional; v1.0 + v1.1 profiles unaffected.
9. **Cite-or-decline.** Unreachable canonical URL ⇒ exit 2, no phantom activation. Every rule cites its canonical source.
10. **No LLM in the enforcement path.**

The reconciliation work is entirely in the **boundary surfaces** where the two designs must interlock precisely, and in **small verb/shape deltas** that pick one word over the other. Nothing about the spine is contested.

---

## 2. Where the two designs diverge (the reconciliation work)

Verified pairwise:

| Surface | GCTP's original (§30.9) | CTP's shared design (§31.1) | Reconciliation direction |
|---|---|---|---|
| Working-store path | `.harness/consult-work/<feature>/project-rules/<namespace>/*.yaml` (GCTP tree, GCTP writes) | `_project/<project-id>/` in CTP's plugin cache (`origin: project`) | **Adopt CTP's location + CTP writes.** GCTP-ideal because (a) rule content is CTP's domain — GCTP writing rule YAMLs is a prime-directive smell, (b) `_project/` becomes a declared contract surface, not GCTP reaching into internals, (c) unified read path (loader consults one directory tree). |
| Verb | `provision-tech-rules.sh` / `deprovision-tech-rules.sh` | `acquire` (from CTP's summary) | **Adopt `acquire` / `release`.** "Provision" is overloaded in infra-speak. |
| Origin field | `project_overlay_namespaces[]` on profile | `origin: project` on each rule/namespace | **Adopt CTP's `origin`.** Per-rule attribution is more precise than a profile-side namespace list, and it makes cross-project leakage trivially detectable. GCTP surfaces the derived `project_overlay_namespaces[]` for reveal convenience but the source-of-truth is `origin`. |
| Project identity | Implicit `<feature-id>` from GCTP directory | Explicit `project-id` passed to CTP command | **Adopt CTP's explicit `--project` flag.** GCTP still assigns the ID (owner: coordinator); CTP consumes as opaque key. |
| Reveal shape | `available_menu[].scope` implicit-global | Growing/project-scoped surface | **Adopt CTP's growing surface.** Reveal shows both `origin: official` (constant) and `origin: project` (dynamic) side by side with origin labels. |
| Kata handling | Not specified | CTP asked: kata-under-project-id? working-only vs promote? | **Kata IS a project; default working-only; promotion optional.** |

Everywhere GCTP's original shape yields, it yields to the *more precise* CTP shape. Everywhere CTP's shape asks GCTP a question, GCTP has an opinionated answer that keeps GCTP as coordinator and CTP as content owner.

---

## 3. The six reconciliation decisions (GCTP's answers to CTP's five boundary questions + the kata question)

### 3.1. Project identity — GCTP owns assignment

**Decision.** GCTP assigns `project-id`. It is `FEATURE-<NNN>` for consult-work sessions (matches `.harness/consult-work/FEATURE-<NNN>/`), `TICKET-<NNN>` for handoff-driven feature work (matches `.harness/handoffs/TICKET-<NNN>.req.json`), or a stable operator-supplied string for kata/exercise scenarios. Never generated inside CTP.

**Contract.** Every CTP acquire/release/promote/reveal command that touches per-project state accepts `--project <project-id>` as a REQUIRED flag. No implicit default (fail-loud if missing) — this rules out silent cross-project mixing.

**Why this shape.** Matches the crossroads/translator model (ADR-0056): GCTP is the coordinator between operator, tickets, feature sessions, and CTP consultations. The project-id lives naturally in GCTP's coordination namespace. CTP consumes it as an opaque key.

**Cross-check.** `scripts/consult.sh` already keys on `FEATURE-<NNN>` for consult-work; `scripts/dispatch.sh` on `TICKET-<NNN>` for handoffs. Kata IDs (`FEATURE-003` for O'Reilly SoftArchCert) are stable per exercise. No new ID space required.

### 3.2. Working-store location — CTP's plugin cache, CTP writes

**Decision.** Per-project acquired rules live at `.harness/plugin-cache/claude-tdd-pro/_project/<project-id>/` — inside the plugin cache directory tree (GCTP's filesystem) but populated by CTP-owned scripts (CTP's write plane). Directory layout mirrors global: `_project/<project-id>/<namespace>/*.yaml` + `<namespace>/.axis-binding.yaml`.

**Write path.**
- Operator issues `/consult` or equivalent; GCTP invokes `bash .harness/plugin-cache/claude-tdd-pro/commands/acquire-tech-rules.sh --tech vue --project FEATURE-003` (CTP-owned script).
- CTP's script resolves family registry, fetches canonical URL (cite-or-decline: 200 or exit 2), scrapes via existing fetcher pipeline, tags per family inference, writes to `_project/<project-id>/vue/*.yaml`.
- GCTP never writes rule YAMLs itself.

**Read path.**
- Loader is CTP-owned: `standards-sync.sh` (GCTP) unpacks CTP's cache; CTP's loader inside the cache exposes the effective rule set = `active.json` (global) ∪ `_project/<project-id>/*` (project-scoped), returning per-rule `origin`.
- Consumer surface unchanged: GCTP still reads `.harness/rules/active.json` as the primary; the effective set for a project comes from a loader call passing `--project <id>`, returning `active.json ∪ _project/<project-id>/` with origin tags.

**Gitignore.** `_project/` is gitignored per CTP's design. This makes it "working state," not committed data. Cache lifecycle handles cleanup on pin bump.

**Prime-directive check.**
- CTP is the writer of rule content — no prime-directive violation. GCTP does NOT reach into `_project/` to hand-author or edit YAMLs.
- `_project/` is a DECLARED contract surface (documented in `docs/handoff-contract.md §Project-Rule-Store`), not a private path GCTP is reaching into. This distinction is exactly the prime-directive threshold: contract-surface writes are sanctioned; private-path pokes are not.
- GCTP's role is invoker + reader. CTP's role is writer + content owner. The boundary is a named command surface with a required `--project` flag.

**Why this shape is GCTP-ideal.** Earlier GCTP draft put the store under `.harness/consult-work/<feature>/project-rules/`. That mixed rule content (CTP's domain) with consult session artifacts (GCTP's domain), and it made the loader union asymmetric (`active.json` in one tree, project-rules in another). CTP's `_project/` inside the cache is cleaner: rule content lives with rule content, loader is symmetric, write plane is uniformly CTP's.

### 3.3. Promotion PR governance — core-content PR, GCTP §15 ADR on the subsequent pin bump

**Decision.** Promotion is a **two-step** flow:

1. **Step 1 (immediate — CTP-side review).** GCTP invokes `bash .harness/plugin-cache/claude-tdd-pro/commands/promote-project-rules.sh --tech vue --project FEATURE-003` (CTP-owned). Script assembles a **core-content PR** against `drumfiend21/claude-tdd-pro` `main` containing (a) rule YAMLs at `generated-code-quality-standards/vue/*.yaml`, (b) axis binding in `namespace-axis-binding.yaml`, (c) family registry entry flipped to `provision_status: provisioned`, (d) source registry entry with canonical URL + fetcher + tier, (e) auto-generated acceptance-test spec citing canonical URL per rule, (f) PR body linking the project's provenance record. CTP maintainer code-reviews the PR using CTP's standard `docs/PULL-REQUEST-REVIEW.md` (or equivalent) discipline. Merge or request-changes is CTP's call.

2. **Step 2 (delayed — GCTP-side pin bump).** Once the PR merges into CTP `main`, the promoted rules are picked up by the next GCTP routine pin bump via `standards-sync.sh`. That pin bump is §15-gated per today's discipline: a new ADR captures which promoted rules are being adopted (references the merged PR SHA + the tech acquired). This is the SAME governance GCTP applies to every CTP pin bump today — no new gate.

**No new GCTP-side gate for the promotion PR itself.** The promotion PR is CTP's PR review territory. GCTP's §15 ADR requirement is orthogonal — it fires on the pin bump, not on the promotion.

**Traceability.**
- GCTP records the promotion PR URL in `.harness/consult-work/<project-id>/promoted-rules.log.md` at the moment of invocation. Fields: `tech`, `project-id`, `promoted-at`, `pr-url`, `rule-count`, `canonical-url`, `operator`.
- `docs/upstream-ctp-proposals.md` gets a `P-15-followon:<tech>` row per promoted tech: `filed → PR open → PR merged → pin bump ADR → adopted`. Same status-tracked lifecycle as every other upstream proposal.

**Reversibility.** If CTP declines the PR, `release-tech-rules.sh --tech vue --project FEATURE-003` reverts the working store; the acquired rules stay project-scoped until either re-promoted (with fixes) or abandoned.

**Cross-check.** This is the SAME two-step lifecycle GCTP already runs for every substantive CTP change today: (1) a CTP CL merges, (2) a GCTP pin bump adopts. The P-15 promotion PR is one such CL. No governance rewrite.

### 3.4. Origin-awareness — YES, first-class-but-scoped

**Decision.** `origin: project` rules are **first-class-but-scoped** across every downstream check:

- **`applicable_rules` propagation.** Per invariant-4, `applicable_rules` for a project's tickets is computed as `active.json ∪ _project/<project-id>/`, with each rule carrying its `origin` and `scope`. The invariant graders (`audit-architecture-crosscheck.sh`, `rubric/runner.sh`, `rubric/enforce.sh`) treat `origin: project` rules identically to `origin: official` — same pass/fail/deviated logic, same gate teeth — but ONLY for tickets tagged with that `project-id`.
- **`--validate-profile`.** Accepts `origin: project` namespaces as valid IFF the profile's `project-id` matches. A profile referencing a `project-id`-scoped namespace under a different `project-id` is a schema violation (fail-loud).
- **`/consult` cascade.** Stage-0 reveal (P-14/§30.7) shows project-scoped namespaces distinctly (§3.5 below). Stack-add lookup (`--stack-add vue --project FEATURE-003`) resolves in the project overlay. Design-time invariant-4 grading grades project-scoped rules at official rigor for that project's decisions.
- **`rules_verified`.** Every rule graded returns `{rule_id, origin, scope, status: pass|fail|deviated}`. Consumers (audit chain, DORA scoreboard, deviations register) can filter or aggregate by origin.

**Scoping invariant (critical — this is the "no silent globalization" spine).** A `origin: project` rule is applicable ONLY to work keyed to its `scope: project:<project-id>`. It never grades a different project's decisions, never flows into a global rule set, never appears in another project's reveal. The ONLY way it escapes its project is the §31.2/§3.3 PR-promotion path.

**Fail-loud tests (add to the P-15 acceptance-test corpus).**
- Assertion: `origin: project scope: project:FEATURE-003` rule graded against a `project: FEATURE-004` ticket → invariant-4 rejects, no grading. Fail-loud, not silently dropped.
- Assertion: `--validate-profile` on FEATURE-004's profile referencing a FEATURE-003-scoped namespace → schema violation.
- Assertion: `/consult` in FEATURE-004 does not reveal FEATURE-003's project-scoped namespaces.

**Why this shape is GCTP-ideal.** The whole point of per-project acquisition is that the acquired rule is real enforcement (first-class), but its blast radius is bounded (scoped). Silently upgrading a project rule to global would violate the spine; silently downgrading it to "advisory" within the project would violate the enforcement guarantee. First-class-but-scoped is the exact intersection.

### 3.5. `full_surface` reveal — growing/project-scoped

**Decision.** The Stage-0 reveal (P-14 / §30.7) surfaces two things distinctly:

- **Global surface (constant).** Every `origin: official` namespace from `active.json`. Ordered stable, cardinality bounded by pin.
- **Project surface (dynamic).** Every `origin: project WHERE scope: project:<current-project-id>` namespace from `_project/<current-project-id>/`. Grows as tech is acquired.

**Rendering.** Reveal displays `available_menu[]` entries with:
```
[origin=official scope=global]        google, typescript, owasp, w3c, web-vitals, ...
[origin=official scope=global]        react (provisioned)
[origin=project  scope=FEATURE-003]   vue (acquired 2026-07-10 from vuejs.org/guide/)
[unprovisioned]                       angular, ember, svelte, ...  (available via /consult acquire)
```

**Non-committing property preserved.** Reveal ≠ activation. §30.7's discipline (menu shown at Stage 0, activation gated to stack-add/family-fire) applies uniformly to both official and project entries. Revealing an unprovisioned tech does NOT scrape it.

**Cardinality note.** `full_surface` in P-14 acceptance tests should NOT hardcode 44 (or any fixed number) — the surface is growing per project. Assertion form: "reveal includes ≥ N_official + N_project namespaces where N_project = count of `_project/<project-id>/*/`."

**Cross-check with P-14.** GCTP's P-14 handoff (filed 2026-07-09, in-flight) needs one small amendment: the acceptance-test corpus refers to `full_surface` cardinality per pin; extend to `full_surface_effective = official + project(project-id)` when a `project-id` is supplied. Backwards-compatible when no project-id (reveal is global-only). GCTP-side work in TICKET-119.b (post-P-14 adoption).

### 3.6. Kata interaction — kata IS a project; working-only default; promotion optional

**Decision.**
- **Kata acquired rules live under the kata's `project-id`.** For the current O'Reilly SoftArchCert kata, `project-id = FEATURE-003` (stable across the kata's lifetime). All Vue/Bun/Elysia/Postgres rules acquired during the kata land in `_project/FEATURE-003/`.
- **Default posture: working-only.** The kata is dogfood — an exercise for shaking out the pipeline. Rules acquired during the kata do NOT auto-promote. The kata's success criterion is "the pipeline works end-to-end," not "we grew the global rule set."
- **Promotion optional, per-tech, operator-driven.** If a kata-acquired ruleset is clearly reusable (e.g., Vue-rules that turn out to be canonically-sourced, well-tagged, and passing the acceptance-test spec cleanly), the operator can invoke `promote-project-rules.sh --tech vue --project FEATURE-003` and go through the standard PR flow. This is a manual, deliberate step — never automatic on kata completion.

**Why this shape.** Conflating "the kata ran" with "the kata's rules should ship" would (a) make kata iteration too heavy (every kata run triggers CTP-side PR review), (b) muddle the promotion signal (community-facing rule content should be operator-vetted, not exercise-vetted), (c) risk silently expanding the global rule set through routine dogfood — which violates the "no silent globalization" spine even if governance is technically PR-gated.

**Cross-check.** Matches ADR-0057 (agent operating compact): the agent drives sanctioned commands but the operator makes architecture-shape decisions. Kata promotion is an architecture-shape decision (should this rule set become community-authoritative?), so it stays with the operator.

---

## 4. Small deltas to CTP's shape (four; all optional refinements)

### 4.1. Delta A — verb: `acquire` / `release`, not `provision` / `deprovision`

**Ask.** CTP's design already uses `acquire` in its summary. GCTP adopts CTP's word across scripts (`acquire-tech-rules.sh` / `release-tech-rules.sh`), docs, contract surface, and reveal labels. GCTP's earlier "provision" language is a relict of the initial P-15 draft and yields to CTP's clearer verb.

**Why.** "Provision" is overloaded in infra vocabulary (VM provisioning, DB provisioning, resource provisioning). "Acquire" is unambiguous: obtain a rule set from its canonical source and store it locally. "Release" is the clean antonym for reversal. Adopting one word across both sides eliminates the current cross-doc mismatch.

### 4.2. Delta B — family registry: CTP-owned seed + PR-gated additions; NO local overlay

**Ask.** `standards/technology-family-registry.yaml` is CTP-owned. Operator additions flow via the same §31.2 PR pattern (a `family-registry-add` PR that's smaller than a rule-content PR — just registry entries + optional acquisition). NO `family-registry.local.yaml` per-operator overlay.

**Why.** A local overlay creates two ambiguous states ("is this family known globally, or just to me?") and duplicates the PR-promotion problem for what's essentially a small YAML file. The whole `active.json` catalogue is PR-gated; family registry should follow suit. Simpler mental model.

**Corresponds to GCTP §7 Q1** — this is GCTP's answer to CTP.

### 4.3. Delta C — polyglot tech: `families: [...]` union

**Ask.** Technology entries in `technology-family-registry.yaml` allow `families:` (plural, list) as an alternative to `family:` (singular). When plural, umbrella activation unions the `umbrella_namespaces` of every listed family. Example: Next.js declares `families: [frontend, backend_runtime]` — activating frontend's umbrellas (Google TS, TypeScript, OWASP, W3C, web-vitals, documentation) AND backend runtime's umbrellas.

**Schema.** Either `family: frontend` (single) or `families: [frontend, backend_runtime]` (plural). Schema-validate exactly one form present.

**Why.** Next.js / Nuxt / SvelteKit / Remix are structurally polyglot — they run TS on the client and Node/edge on the server, and both apply. A primary+secondary shape is needless ceremony; plural-list with union semantics is the direct expression.

**Corresponds to GCTP §7 Q4** — this is GCTP's answer to CTP.

### 4.4. Delta D — filing shape: single umbrella P-15, ship family-umbrella-activation first

**Ask.** File the composite as **one** P-15 covering all three moves (family umbrella activation + per-project acquisition + PR promotion). Ship order:

- **v1.17 phase 1 — family umbrella activation only.** Deterministic, no scrape, no new rules, immediate delta for Vue/Angular/Bun/Postgres etc. at Stage 0. Ship-alone is meaningful (matches GCTP's original preference and CTP's five-move ordering).
- **v1.17 phase 2 — per-project acquisition (with `_project/` store).** Requires S-63 landed. Requires fetcher pipeline routing + operator-approval prompt + gitignore + loader union.
- **v1.17 phase 3 — PR promotion path.** Requires phase 2 landed + a first promotion smoke test.

Each phase is a separate CL under one umbrella ticket. Precedent: P-13 (§30.4/§30.5/§30.6, three halves inside one CTP ticket). GCTP will accept if CTP prefers three separate tickets (P-15/P-16/P-17), but the umbrella shape matches P-13 precedent and reads more naturally as one arc.

**Corresponds to GCTP §8** — this is GCTP's default proposal.

---

## 5. Foundation ticket S-63 (CTP-side, agreed)

CTP identified **S-63** as the foundation ticket: introduce the `_project/` origin category + working/official write-plane split. GCTP agrees this is the enabling change.

**GCTP will not start pre-wire until S-63 has a shape** (matches GCTP's discipline for P-13: TICKET-118.a pre-wire only after CTP articulated §30.4/§30.5 sufficiently to acceptance-test).

**Once S-63 shape is public, GCTP pre-wire (TICKET-120.a or similar) covers:**
- `scripts/consult.sh --validate-profile` tolerates `origin: project` + `scope: project:<id>` on rule references.
- `scripts/audit-architecture-crosscheck.sh` invariant-4 keys on `active.json ∪ _project/<project-id>/` when a `project-id` is present in the ticket.
- `docs/handoff-contract.md §Project-Rule-Store` documents the `_project/<project-id>/` contract surface + the required `--project` flag on acquire/release/promote/reveal commands.
- Machine acceptance test (Tier A + B) matching CTP's shipped acceptance corpus, extending GCTP's TICKET-118.a pattern.
- Placeholder ADR draft ready for the pin bump (per §15 discipline).

---

## 6. Ready-to-file shape (agreed with CTP once §3 + §4 confirmed)

**Ticket:** P-15 (umbrella covering §31/§31.1/§31.2 in CTP nomenclature, equivalent to §30.8/§30.9/§30.10 in GCTP's earlier draft — align on CTP's §31 numbering to match the canonical CTP architecture doc).

**Foundation:** S-63 (`_project/` origin category + working/official write-plane split).

**Composed CLs under P-15:**

| CL | Scope | Contract surface added | Ships |
|---|---|---|---|
| P-15 phase 1 | Family umbrella activation | `standards/technology-family-registry.yaml`; classifier catalog widening; `workload_classification.families_active[]` | v1.17 CL a |
| P-15 phase 2 | Per-project acquisition | `commands/acquire-tech-rules.sh`, `commands/release-tech-rules.sh`; `_project/<project-id>/` store; loader union; `workload_classification.project_overlay_namespaces[]` (derived from `_project/` origin) | v1.17 CL b |
| P-15 phase 3 | PR promotion | `commands/promote-project-rules.sh`; auto-generated PR body + acceptance-test spec; provenance record | v1.17 CL c |

**GCTP-side companion tickets:**

| Ticket | Scope | Depends on |
|---|---|---|
| TICKET-120 | Pin bump adopting P-15 phase 1 (family umbrella activation) with §15 ADR | CTP v1.17 CL a tagged |
| TICKET-120.a | GCTP pre-wire for P-15 phase 1 (contract test tolerance + `/consult` skill translation) | S-63 shape public |
| TICKET-121 | Pin bump adopting P-15 phase 2 + `.harness/consult-work/<id>/promoted-rules.log.md` scaffolding | CTP v1.17 CL b tagged |
| TICKET-121.a | GCTP pre-wire for P-15 phase 2 (project-scoped invariant-4, `--project` flag propagation, fail-loud tests for cross-project leakage) | P-15 phase 2 spec public |
| TICKET-122 | Pin bump adopting P-15 phase 3 (promotion PR flow surfaced in `/consult` skill + kata runbook) | CTP v1.17 CL c tagged |

**Acceptance-test coverage (delta from GCTP's original §4).** Add three assertions:
- Cross-project leakage fail-loud (§3.4).
- `--project` flag required on acquire/release/promote/reveal (fail-loud without).
- Reveal (§30.7 / P-14) surfaces `origin: project` distinctly from `origin: official`.

---

## 7. What GCTP is asking of CTP (summary)

1. **Read** this reconciliation doc + confirm the six decisions in §3.
2. **Confirm the four small deltas** in §4 (verb `acquire`; registry no-local-overlay; polyglot `families: [...]`; single-umbrella filing).
3. **Publish S-63 shape** so GCTP can start pre-wire (TICKET-120.a).
4. **File P-15 as the umbrella** covering §31/§31.1/§31.2 with the three-phase ship order in §6.
5. **Confirm the two-step promotion governance** in §3.3 works from CTP's side (PR review is CTP's; GCTP's §15 ADR fires on the subsequent pin bump).

GCTP will file TICKETS-120/120.a/121/121.a/122 in `TICKETS.md` and append the P-15 reconciliation row to `docs/upstream-ctp-proposals.md` on CTP confirmation.

Ready when you are.
