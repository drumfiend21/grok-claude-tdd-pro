# GCTP → CTP handoff — P-15: Family umbrella activation + per-project tech-specific rule provisioning + PR-promotion path — activate already-scraped umbrellas on family membership, scrape tech-specific rules on-demand into a per-project overlay, and promote overlay → global by code-reviewed PR

**Written:** 2026-07-10 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `11126a8`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟡 **BI-DIRECTIONAL DESIGN CONSULT — GCTP has drafted; both sides align before filing as a formal P-15 ticket (or split)**
**Ask:** design consult on three composed layers extending the plug-in's already-scraped `active.json` to work correctly for every technology in a workload — not just React. GCTP presents the drafted design; CTP responds with (a) CTP-side design shape, (b) any structural corrections, (c) filing-shape decision (single umbrella P-15 vs split P-15/P-16/P-17), (d) ship order across v1.17 / v1.18, (e) answers to the five open questions in §7 below. Additive per ADR-0047. No LLM. Cite-or-decline preserved.

---

## Companion supplementary materials (this repo)

- **This document** — reasoning + drafted design + open questions (start here).
- **`.harness/consult-work/FEATURE-003/p15-design.md`** — GCTP's full v2 design (405 lines) with §30.8/§30.9/§30.10 detail, family registry sample YAML, per-project overlay loader semantics, PR-promotion mechanics, worked Vue+Bun+Elysia+Postgres example. This handoff summarizes; the design doc is the source of truth.
- **`.harness/consult-work/FEATURE-003/gaps-log.md`** — the KA-1 gaps log; G-2 (family-membership-blind classifier) is the identified gap this closes.
- **`.harness/consult-work/FEATURE-003/vision.txt`** — the O'Reilly Winter 2025 SoftArchCert kata vision used as the recurring worked example across P-14 and P-15.

---

## 0. TL;DR

At pin `11126a8` the plug-in has ~15 authoritative sources already scraped into `active.json` (118 rules, 43 namespaces). Cross-cutting frontend rules (Google TS style, OWASP, W3C, web-vitals, TypeScript handbook) live in framework-agnostic namespaces (`google`, `owasp`, `w3c`, `web-vitals`, `typescript`). React-specific rules live in `react` (6 rules, scraped from React docs).

**Problem:** if the operator names Vue, Angular, Ember, Svelte, Solid, Astro, Qwik, Bun, Deno, Elysia, Fastify, Postgres, MySQL, Redis, Prisma, Drizzle — the classifier does not fire. Neither the framework-agnostic umbrellas nor any tech-specific rules activate at Stage 0. Structurally the fail-closed `applicable_rules` default guarantees all 118 rules grade downstream decisions, but experientially the operator sees ~15% of the expertise map at intake and cannot steer with visibility — and there are ZERO tech-specific rules for anything not-React in the frontend family.

**Fix — three composed layers, additive:**

- **§30.8 — Family taxonomy + umbrella activation.** New `standards/technology-family-registry.yaml` maps every known tech to a family (`frontend`, `backend_runtime`, `backend_framework`, `database_relational`, `cache_kv`, `orm`, `cloud`, `orchestration`, `ci_cd`, …). Each family declares `umbrella_namespaces` — the already-scraped, already-in-`active.json` rules that apply cross-cuttingly at that family. Classifier catalog widens to recognize every alias in the registry as a signal for that family's `canonical_workload_type`. **When user names Vue, the frontend family fires and its umbrellas activate immediately. No scrape. Just correct activation of rules that already exist.**
- **§30.9 — Per-project tech-specific rule provisioning.** When a detected tech has no tech-specific namespace in `active.json` yet, `provision-tech-rules.sh --tech vue --project FEATURE-003` scrapes the tech's canonical docs (same pipeline the plug-in already uses for React → `react`), 4-axis-tags the extracted rules, and stores them at `.harness/consult-work/<feature>/project-rules/<namespace>/*.yaml` — **per-project only, NOT global**. The overlay loader unions `active.json` (global) ∪ `project-rules/` (per-project) into the project's effective rule set. Stage 0 re-classifies knowing Vue exists; Stage 2 asks Vue posture probes; design + write-time enforce. Operator approves before load. Reversible via `deprovision-tech-rules.sh`. **Global `active.json` is untouched by construction — GCTP has no write path to it.**
- **§30.10 — PR-promotion path.** When project-scoped rules earn their keep, `promote-project-rules.sh --tech vue --project FEATURE-003` opens a PR against CTP containing (a) rule YAMLs at `generated-code-quality-standards/vue/*.yaml`, (b) `vue` axis binding in `namespace-axis-binding.yaml`, (c) family registry flip `vue.provision_status: provisioned`, (d) source registry entry with canonical URL + fetcher + tier, (e) auto-generated acceptance test spec. **CTP maintainer code-reviews the PR — this is the ONLY channel by which a per-project rule becomes global.** On merge + next pin bump, Vue rules become part of `active.json`; the project's overlay folder becomes safely removable.

**Invariant chain (the "no silent globalization" spine):** project-scoped write ⇒ read-only view of global CTP substrate from GCTP ⇒ PR-only promotion ⇒ code review ⇒ merge ⇒ pin bump ⇒ globalization. No auto-inclusion path exists by construction, not by policy — the prime directive already forbids GCTP from editing CTP substrate; §30.10's PR is the sanctioned channel.

Additive per ADR-0047. Cite-or-decline preserved (unreachable URL ⇒ exit 2, no phantom activation). No LLM. Compact-safe (no phantom architecture: family registry is declarative + operator-reviewed; provisioning is operator-initiated with human-in-loop approval before load).

---

## 1. The gap (evidence, deterministic at pin `11126a8`)

### 1.1. What `active.json` covers today for frontend work

Already-scraped, already-4-axis-tagged rules that would apply to *any* TS/JS frontend regardless of framework:

- `google` (6) — Google TS/JS style guide, framework-agnostic
- `typescript` (4) — TypeScript handbook, applies to TS-based Vue/Angular/Svelte
- `owasp` (2) — ASVS + Top 10, framework-agnostic web security
- `w3c` (1) — WCAG 2.2 accessibility, framework-agnostic
- `web-vitals` (2) — LCP/INP/CLS budgets, framework-agnostic
- `documentation` (2) — documentation posture, framework-agnostic

**15 umbrella rules that would apply to any TS/JS frontend TODAY if the classifier activated them for non-React frameworks.** They don't — because the classifier signal catalog only names React.

### 1.2. What's missing (the tech-specific gap)

`react` namespace has 6 tech-specific rules scraped from React docs. Vue / Angular / Ember / Svelte / Solid / Astro / Qwik / Remix — zero rules. Same for Bun / Deno / Elysia / Fastify (backend runtimes + frameworks). Same for Postgres / MySQL / Redis / Prisma / Drizzle (data layer). Their canonical docs haven't been scraped, so no `vue` / `angular` / `bun` / … namespace exists in `active.json`.

### 1.3. Downstream harm — the SoftArchCert composition case

Consider a plausible SoftArchCert follow-on: *"We want a Vue frontend with a Bun+Elysia backend on Postgres for a healthcare provider certification portal at 10x growth."*

Classifier at pin `11126a8`:
- Fires `web-frontend`? No — signal catalog for `web-frontend` names React, not Vue.
- Fires backend rest-api? No — no signal for Bun/Elysia.
- Fires data-layer? No — no signal for Postgres.
- Only regulatory + AI-governance fire (from `healthcare`).

Result: `activated_probe_namespaces` includes maybe 6 namespaces out of the 25+ that would apply. Structurally the fail-closed default still grades against all 118 rules — so the RULES apply. But the OPERATOR sees no frontend, no backend, no data posture at intake. Steering is blind, and there are still zero Vue-specific / Bun-specific / Elysia-specific / Postgres-specific rules to ground design decisions.

### 1.4. Why this is P-15 and not a P-14 extension

- **P-14 (§30.7)** made the *reveal* full-surface. It exposes the whole `active.json` menu at Stage 0 without committing. That fixes the "operator sees only 15% of expertise" symptom for whatever `active.json` already contains.
- **P-15 (§30.8/§30.9/§30.10)** extends *what `active.json` covers* — activating umbrellas correctly for every tech in a family (§30.8), and provisioning tech-specific rules on-demand for techs whose canonical docs weren't scraped yet (§30.9), with a PR-promotion path back to global (§30.10). P-14 reveals; P-15 broadens the map that gets revealed.

The two compose cleanly: P-15's §30.8 grows `activated_probe_namespaces` on family membership; P-14's `available_menu` still lists every namespace including the per-project overlay entries.

---

## 2. Shape proposal (drafted design — CTP consult welcome to reshape)

### 2.1. §30.8 — Family taxonomy + umbrella activation

**Contract surface:**
- **New file:** `standards/technology-family-registry.yaml` (CTP-owned; operator PRs additions per §30.10 pattern).
- **Modified file:** `standards/business-intake-workload-classifier.yaml` — the classifier signal catalog is widened to include every alias declared in the family registry.
- **Modified profile field (additive):** `workload_classification.families_active[]` — list of family IDs (e.g. `["frontend", "backend_runtime", "database_relational"]`) that fired.

**Sample entry (frontend family):**

```yaml
families:
  frontend:
    umbrella_namespaces: [google, typescript, owasp, w3c, web-vitals, documentation]
    canonical_workload_type: web-frontend
    technologies:
      - name: react
        aliases: [react, react.js, reactjs, jsx, tsx]
        namespace: react
        canonical_docs_url: "https://react.dev/learn"
        provision_status: provisioned      # rules already in active.json globally
      - name: vue
        aliases: [vue, vue.js, vuejs, nuxt, nuxt.js]
        namespace: vue
        canonical_docs_url: "https://vuejs.org/guide/"
        provision_status: unprovisioned    # scrape on-demand into project overlay
      # ... angular, ember, svelte, solid, astro, qwik, remix, gatsby
```

**Cite-or-decline check:** every namespace referenced in `umbrella_namespaces` MUST exist in `active.json`. Registry schema validation fails loudly if not — no phantom activation.

**Semantics:** classifier catalog widens on load; when any alias fires, the family's `umbrella_namespaces` join `activated_probe_namespaces` at Stage 0. `families_active` records which families fired.

Full sample YAML across all 10+ families is in the design doc §2.

### 2.2. §30.9 — Per-project tech-specific rule provisioning

**Contract surface:**
- **New script:** `provision-tech-rules.sh --tech <name> --project <feature-id>` — resolves family registry entry, fetches canonical URL (cite-or-decline: 200 or exit 2), scrapes via the existing fetcher pipeline, 4-axis-tags per family inference, stores at `.harness/consult-work/<feature>/project-rules/<namespace>/*.yaml` + `.axis-binding.yaml`.
- **New script:** `deprovision-tech-rules.sh --tech <name> --project <feature-id>` — reverses.
- **Modified loader:** GCTP's rule-loading logic unions `active.json` (global) with `project-rules/` (per-project overlay). CTP's engines also see the overlay when consulted for that project.
- **Modified profile field (additive):** `workload_classification.project_overlay_namespaces[]` — namespaces served from the project overlay (visible to the operator as such).

**Discipline (from the design doc §3):**
- Provisioning is operator-initiated; human-in-loop approval before rules load (unless `--auto-approve`).
- Rate-limited (`CTP_PROVISION_RATE_LIMIT`, default 10/hour/project).
- Provenance record per provisioning: `.harness/consult-work/<feature>/provisioning-log.md` — timestamp, operator, canonical URL, fetcher, rule count, per-rule citations.
- Reversible; auditable.
- **Global `active.json` is NEVER modified** — the loader treats it as read-only. The prime directive already enforces this at the file-system boundary (GCTP has no write path to CTP substrate).

**Trade-offs surfaced honestly (design doc §8):**
- Fetcher fidelity risk — mitigated by operator preview + PR review before promotion + reversibility.
- Source-authority risk — mitigated by tier declaration + operator review.
- No auto-scrape — deliberate; provisioning is always operator-initiated.

### 2.3. §30.10 — PR-promotion path (per-project → global)

**Contract surface:**
- **New script:** `promote-project-rules.sh --tech <name> --project <feature-id>` — assembles a PR against CTP with:
  1. Rule YAMLs copied to `generated-code-quality-standards/<namespace>/*.yaml`.
  2. Axis binding added to `namespace-axis-binding.yaml`.
  3. Family registry flip: `provision_status: provisioned`.
  4. Source registry entry (canonical URL + fetcher + tier) added to the appropriate `standards/*-sources.yaml`.
  5. Auto-generated acceptance test spec at `evals/specs/<namespace>-*.json` — must cite the canonical URL for every rule.
  6. PR body citing the provenance record from the project.
- **On merge + next pin bump:** rules become global; `deprovision-tech-rules.sh --replaced-by-global` cleans up the project overlay.

**Discipline (the "no silent globalization" invariant):**
- PR promotion is EXPLICIT — never auto. Operator decides.
- The PR is reviewable code, not opaque config — reviewers see extracted YAMLs + citations + acceptance test + canonical URL.
- Optional SLSA signing on the promotion provenance record.
- **Every rule that becomes global has been read by a human on the CTP side.** This is the point of §30.10.

---

## 3. Compat + rollout

- **§30.8 first.** Deterministic, no scrape, no new rules. Immediate delta for Vue/Angular/Ember/Svelte/Solid/Astro/Qwik/Bun/Deno/Elysia/Fastify/Postgres/MySQL/Redis/Prisma/Drizzle at Stage 0. Ship-alone is meaningful.
- **§30.9 next.** Requires the fetcher pipeline routing + project-overlay loader + operator-approval prompt. GCTP-side prep: `.harness/rules/active.json` loader extended to overlay project-scoped rules; contract in `docs/handoff-contract.md §Project-Rule-Overlay`.
- **§30.10 last.** Optional; §30.9 is useful without §30.10 (per-project rules work without promotion). §30.10 unlocks community-wide reuse.
- **Additive.** No existing profile field is removed or reshaped. New optional keys on `workload_classification`: `families_active[]`, `project_overlay_namespaces[]`.
- **v1.0 + v1.1 profiles unaffected.**
- **Prime-directive preserving.** GCTP consumes CTP via pin bump; per-project rules live in GCTP's kata workspace, never in CTP. Promotion PR is the sanctioned channel for CTP-side changes. No cross-repo edits.
- **Compact-safe.** Family registry is declarative + code-reviewed. Provisioning is operator-initiated + human-in-loop-approved before load. Promotion is PR-gated. The agent originates no architecture; it executes and translates.
- **No LLM anywhere.**

---

## 4. Acceptance-test outline (Tier A, ~14 assertions — CTP owns the authoritative corpus)

**§30.8:**
1. Vision naming `vue` fires `web-frontend`; family `frontend` activates; umbrella namespaces `[google, typescript, owasp, w3c, web-vitals, documentation]` are in `activated_probe_namespaces`.
2. Vision naming `angular` fires the same umbrella set.
3. Vision naming a tech NOT in `technology-family-registry.yaml` emits an actionable note ("detected 'X' — no family entry; add via family-registry PR"), does NOT phantom-activate.
4. `technology-family-registry.yaml` schema-validates: every family has `umbrella_namespaces`; every namespace referenced exists in `active.json` (cite-or-decline).

**§30.9:**
5. `provision-tech-rules.sh --tech <known-unprovisioned>` with reachable URL succeeds; writes YAML to `project-rules/<namespace>/`; provenance record generated.
6. `provision-tech-rules.sh --tech <known-unprovisioned>` with unreachable URL exits 2 (cite-or-decline).
7. `provision-tech-rules.sh --tech <already-globally-provisioned>` exits 0 no-op ("already global").
8. Loader unions `active.json` (global) with `project-rules/` (project-overlay); FEATURE-003's effective rule set reflects both.
9. Provisioning DOES NOT modify global `active.json`. Assert byte-identical `active.json` before and after.
10. `deprovision-tech-rules.sh` reverts; classifier no longer activates the namespace.

**§30.10:**
11. `promote-project-rules.sh --tech vue --project FEATURE-003` assembles a PR diff containing all six artifacts (rule YAMLs + axis binding + registry flip + source registry entry + acceptance test spec + PR body).
12. PR diff includes auto-generated acceptance test spec citing the canonical URL for every rule.
13. On CTP-side merge simulation, next pin bump lifts the project-overlay to global; the project's overlay folder is safely removable.
14. Promotion writes a provenance record with operator identity + timestamp + canonical URL + rule count + rule-extraction version.

---

## 5. P-series arc placement

- **P-12 (§30)** — v1.1 profile shape (full-surface intake baseline).
- **P-13 (§30.4/§30.5/§30.6)** — stack-driven progressive rule activation across commitment junctures. **ADOPTED at pin `11126a8`.**
- **P-14 (§30.7)** — Stage-0 full-surface *reveal* (non-committing `available_menu`). **FILED, awaiting CTP consult.**
- **P-15 (§30.8/§30.9/§30.10)** — this proposal. Broadens what `active.json` covers (family umbrellas activate for every tech in a family; on-demand per-project scrape for tech-specific rules; PR-promotion path back to global). Composes cleanly on P-14 (menu now includes overlay entries) and P-13 (stack commitments still fire only at junctures; overlay namespaces flow through §30.5 unchanged).

**Precedent for filing shape:** P-13 filed as one umbrella covering §30.4 + §30.5 + §30.6 (three halves). GCTP's default proposal is the same shape for P-15 — one umbrella covering §30.8 + §30.9 + §30.10 — with §30.8 shipping first as a small green CL, §30.9 + §30.10 following inside the same P-15 arc. CTP is welcome to split into P-15/P-16/P-17 if that fits CTP-side cadence better.

---

## 6. GCTP-side follow-up coordination

Once CTP tags (v1.17 or wherever this lands), GCTP will:

1. §15-gate a pin bump ADR (`architecture-principles.md` §15 requires an ADR for any pin bump touching the contract surface).
2. Pre-wire the consumer surface **before** the pin bump lands, so the contract test in `tests/test-consult.sh` + `tests/test-standards-sync.sh` covers the new `families_active[]` + `project_overlay_namespaces[]` fields at both the pre-bump (empty/optional) and post-bump (populated) states — same pattern as TICKET-118.a for P-13.
3. Extend `.harness/rules/active.json` loader to overlay project-scoped rules from `.harness/consult-work/<feature>/project-rules/`.
4. Extend `standards-sync.sh` to schema-validate `technology-family-registry.yaml` on ingest.
5. Extend `/consult` skill + kata-runbook to pick up §30.8's new family activation + §30.9's provisioning path (same pattern as TICKET-119.a for P-13's §30.4/§30.5/§30.6).
6. Cross-reference this handoff from `docs/upstream-ctp-proposals.md` P-15 row.

---

## 7. Open questions — GCTP asks CTP

1. **Family registry ownership.** CTP-maintained seed with operator PR additions (matches P-15's own §30.10 pattern) — or CTP-maintained + `family-registry.local.yaml` overlay per operator/company? GCTP leans CTP-only for the seed, with §30.10-style PRs for additions; CTP's call.
2. **Fetcher classification per technology.** Should `technology-family-registry.yaml` declare a `fetcher_hint:` (`html-anchor.sh` / `md-fetcher.sh` / `sphinx-fetcher.sh`) per technology, or should the fetcher be auto-detected at scrape time? GCTP's design defers to CTP's fetcher pipeline; a hint field would help but adds registry-maintenance burden.
3. **Rule-count budget warning threshold.** Should `standards-audit.sh` warn when a project overlay adds > N rules? What N? (Concern: a project overlay growing to 300 rules silently slows every consult for that project.)
4. **Cross-family umbrella union.** Next.js is BOTH frontend and backend. Should the family registry allow a tech to declare multiple families, with `umbrella_namespaces` unioning? Or pick a primary + `secondary_families:` list? GCTP leans "multiple families with union" for correctness; CTP's call on schema shape.
5. **Deprecation flow.** When a tech is provisioned, promoted globally, then EOL'd (React 19 → React 21 breaking changes), how do we deprecate rules cleanly? Version tags on rule YAMLs? A `deprecated_at:` field? A separate `deprecated-rules/` archive namespace? This is a P-16+ concern but flagging now so §30.9's YAML shape is deprecation-friendly from day one.

---

## 8. Filing-shape decision (deferred to CTP, then to operator)

- **Shape.** Single umbrella P-15 covering §30.8 + §30.9 + §30.10 (P-13 precedent, three halves) — GCTP's default proposal. OR split into P-15 (§30.8 umbrella activation), P-16 (§30.9 per-project provisioning), P-17 (§30.10 PR promotion) if CTP prefers three separately-tagged CLs.
- **Ship order.** §30.8 ship-alone acceptable (immediate delta, no scrape) with §30.9 + §30.10 as follow-ons — GCTP's default proposal. OR all three in one v1.17 tag.
- **v1.17 vs v1.18.** If P-14 (§30.7) is v1.16, does P-15 go v1.17 (all three §30.8/§30.9/§30.10 together) or does §30.8 slip into a v1.16.1 with §30.9/§30.10 in v1.17? CTP's cadence decides.

GCTP will accept whatever shape/order CTP proposes on consult; the design content is what matters.

---

## 9. What GCTP is asking of CTP (summary)

1. **Read** this handoff and the design doc at `.harness/consult-work/FEATURE-003/p15-design.md`.
2. **Consult on the design shape** — is the three-layer §30.8/§30.9/§30.10 decomposition right? Any structural correction from the CTP-side view of the fetcher pipeline / active.json ingest / evals corpus that GCTP is missing?
3. **Answer the five §7 open questions** — especially Q1 (registry ownership), Q2 (fetcher hint), and Q4 (cross-family union) which affect the schema shape.
4. **Decide filing shape + ship order** — single umbrella vs three tickets; §30.8-first vs all-three-together.
5. **Confirm the "no silent globalization" invariant chain** reads correctly from the CTP side — GCTP writes only to `.harness/consult-work/`, CTP substrate is read-only from GCTP, PR is the ONLY channel for promotion, code review is the gate.
6. **Return with a shaped proposal** — either "file as P-15 with §30.8/§30.9/§30.10 in v1.17, ship §30.8 first" or a counter-shape. GCTP files the ticket(s) on CTP's proposed shape.

Ready when you are.
