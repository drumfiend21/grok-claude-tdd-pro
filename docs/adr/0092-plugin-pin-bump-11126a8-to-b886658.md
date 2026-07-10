# ADR-0092 — Plugin pin bump `11126a8` → `b886658` (adopt CTP CL-556..CL-560 §31 — P-15 family umbrella activation + per-project tech-specific rule acquisition + PR-gated promotion + technology-fitness recommender + consumer-contract reconciliation to GCTP pre-wired validator)

- **Status:** Accepted
- **Date:** 2026-07-10
- **Deciders:** operator (`drumfiend21`; 2026-07-10: four-round design consult with CTP produced a converged shape landing at CTP `e4ec1a9` (§31.4 append); CTP built and merged S-58..S-64 + CL-560 consumer-contract reconciliation at `b886658` and asked GCTP to pin) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** GCTP filed P-15 across four handoff rounds (round-1 three-layer §30.8/§30.9/§30.10 proposal; CTP shared §31/§31.1/§31.2 five-move design; round-3 GCTP reconciliation with six boundary decisions + four small deltas; round-4 GCTP convergence ack + Delta C recommendation + 14+4 assertion map). CTP locked the shape via `docs/handoff-ctp-to-gctp-p15-converged.md` + §31.4 architecture append at `e4ec1a9`, then built S-58..S-64 to spec. CTP then shipped CL-560 (consumer-contract reconciliation) aligning `full-surface-intake` output to GCTP's pre-wired validator names (`families_active`, `project_id`, `project_overlay_namespaces`) and confirmed the `_project/` store landed at the nested path `generated-code-quality-standards/_project/<project-id>/<namespace>/*.yaml`. Upstream HEAD is `b886658`.
- **Continues:** the pin chain ADR-0072 → ADR-0079 → ADR-0085 → ADR-0086 → ADR-0087 → ADR-0088 → ADR-0089 → ADR-0090 → ADR-0091 → this ADR (`11126a8 → b886658`).
- **Process:** §15-gated pin bump (upstream `docs/architecture-v1.9.md` contract hash changes — §31 + §31.1 + §31.2 + §31.3 + §31.4 appended; hash `d85a3f6e… → 8caadb14…`; other 4 contract files byte-identical). Consumer-side reconciliation on GCTP is **near-zero** by construction: CTP's CL-560 aligned the shipped runtime field names to the exact names GCTP pre-wired in TICKET-121.a (`families_active[]`, `project_id`, `project_overlay_namespaces[]`) so the four-round design convergence closed with matching schema. Only reconciliation required: `scripts/sync-plugin.sh` `_project/` preservation path corrected from top-level `$CLONE_DIR_E/_project` (pre-wire assumption) to the shipped nested path `$CLONE_DIR_E/generated-code-quality-standards/_project` (CTP answer #3).

## Compatibility verdict (verified `11126a8 → b886658`)

| Check | Result |
|---|---|
| Span | **≥5 semantic CTP commits** covering S-58 family-registry + S-59 classifier widening + S-60 acquire pipeline + S-61 technology-fitness recommender + S-62 promotion PR flow + S-63 `_project/` foundation + S-64 removal, plus CL-560 consumer-contract reconciliation (`families_active`/`project_id`/`project_overlay_namespaces` runtime field names aligned to GCTP validator) |
| upstream `docs/architecture-v1.9.md` | **CHANGED** — **purely additive**: §31 + §31.1 + §31.2 + §31.3 + §31.4 appended (+112/-0 lines, verified via `git diff 11126a8..b886658 -- docs/architecture-v1.9.md`; ADR-0047 additive-only invariant preserved) |
| `CLAUDE.md` + 3 consumed `SKILL.md` | **all byte-identical** — verified via `sync-plugin.sh --check` (0 files drifted on 4 of 5 contract files) |
| `active.json` | **118 → 118 rules byte-identical** — verified via `standards-sync.sh` regeneration; §31 adds classifier + acquisition + recommender behavior, not authored rules; matches CTP's convergence-doc promise that active.json is byte-identical without `--project` |
| GCTP pre-wired schema tolerance (TICKET-121.a) | **all field names match shipped** per CL-560 reconciliation: `families_active[]` ✓, `project_id` (string\|null) ✓, `project_overlay_namespaces[]` ✓. No fixture churn on `tests/test-consult.sh` — all 17 P-15 assertions pass against the real shipped shape unchanged. |
| GCTP pre-wired invariant-4 (TICKET-121.b) | **XC_PROJECT_ID scoping matches**: aggregator target set = `activated_probe_namespaces ∪ stack[].namespace ∪ (project_overlay_namespaces WHERE XC_PROJECT_ID == profile.project_id)`. A15 cross-project leakage rejection + A16 `--project` required both fire fail-loud as designed. |
| GCTP pre-wired `_project/` preservation (TICKET-121.c) | **path corrected from top-level to nested** per CTP answer #3. sync-plugin.sh preservation now backs up/restores `$CLONE_DIR_E/generated-code-quality-standards/_project/` (the shipped location). `test-sync-plugin.sh` stub location updated to match; 4 preservation assertions green at the corrected path. |
| Delta C ruling | CTP ruled `umbrellas:` on registry tech entry (design/config) with `families_active[]` on runtime profile (the list of active umbrellas). GCTP pre-wired for the runtime name and needs no schema change; the registry name is CTP-internal and doesn't cross the contract surface. |

## Decision

Bump the pin `11126a8 → b886658` — upstream HEAD carrying the full P-15 implementation (S-58 through S-64 + CL-560 reconciliation). This adopts CTP's shipped answer to the four-round convergence:

1. **S-58 family registry.** `technology-umbrella-registry.yaml` maps each technology to its family membership (`umbrellas:` on the tech entry; e.g. Vue lists `[frontend]`, Next.js lists `[frontend, backend_runtime]` for polyglot union). Family entries carry the umbrella namespace payload (Google TS, TypeScript handbook, OWASP, W3C, web-vitals, documentation for `frontend`).

2. **S-59 classifier widening.** Naming any technology in the registry fires the umbrella namespaces at Stage 0, activating the framework-agnostic rules that already exist in `active.json` — Vue, Angular, Ember, Svelte, Solid, Astro, Qwik, Bun, Deno, Elysia, Fastify, Postgres, MySQL, Redis, Prisma, Drizzle all now activate the appropriate umbrellas immediately. `workload_classification.families_active[]` records which families fired.

3. **S-60 acquire pipeline.** `commands/acquire-technology-rules.sh --tech <name> --project <id>` searches the same authoritative sources CTP already uses (D2 `fetcher:` hint optional), extracts the tech-specific rules, and stores them at `generated-code-quality-standards/_project/<project-id>/<namespace>/*.yaml` with `origin: project`, `project_id`, 4-axis tags, and provenance. D3 budget (`--max-sources 8` default; over-budget → `budget_exhausted` + `needs_source` non-silent).

4. **S-61 technology-fitness recommender.** When the operator asks what to use, the recommender doesn't just accept the suggestion — it can propose alternatives (Angular over React for an enterprise project, etc.) with rationale drawn from the umbrella-matched sources. No LLM in the recommendation path.

5. **S-62 promotion PR flow.** `commands/promote-project-rule.sh --tech <name> --project <id>` assembles the six-artifact PR against CTP `main` (rule YAMLs + axis binding + registry flip + source registry entry + acceptance-test spec + PR body). Merge is the ONLY channel by which a per-project rule becomes global — the no-silent-globalization spine (convergence doc B4).

6. **S-63 `_project/` foundation.** Working store at `generated-code-quality-standards/_project/<project-id>/<namespace>/*.yaml` inside the plugin cache. Aggregator `--project <id>` scopes the effective rule set to `active.json ∪ _project/<id>/`. Without `--project` the aggregator returns byte-identical `active.json` — the A9 no-silent-globalization spine formalized.

7. **S-64 removal.** `promote-project-rule.sh --release --tech <name> --project <id>` reverses acquisition; symmetric removal PR handles deprecation on the promoted-then-EOL path (D5). `deprecated: true` rules skip default enforcement.

8. **CL-560 consumer-contract reconciliation.** CTP aligned the shipped runtime field names on `full-surface-intake` output to exactly match GCTP's pre-wired validator: `families_active[]`, `project_id` (string|null), `project_overlay_namespaces[]`, and `--project` propagated onto the consult itself. This is the reciprocal of ADR-0087's key-name reconciliation, but done on CTP's side this time so GCTP's pre-wire schema tolerance lands unchanged.

## What §31 + §31.1 + §31.2 + §31.3 + §31.4 deliver (the substantive change)

1. **Non-React frontends now activate umbrellas.** At pin `11126a8`, naming `vue` in a vision produced zero probe activation; at `b886658`, Vue fires `frontend` family umbrellas — Google TS style, TypeScript handbook, OWASP ASVS + Top 10, WCAG 2.2, web-vitals, documentation — instantly, without any new scraping. Same for Angular, Ember, Svelte, Solid, Astro, Qwik.
2. **On-demand tech-specific rules with a bounded write plane.** Acquired rules for Vue land at `_project/FEATURE-003/vue/` (per-project), not at `generated-code-quality-standards/vue/` (global). Gitignored on CTP's side. The `origin: project` scoping enforces first-class-but-scoped rigor — the acquired rules grade decisions for their project at official-rule rigor, but never leak into a different project or into global.
3. **PR-only promotion path.** No auto-promotion. When a project-scoped ruleset earns its keep, the operator opens a PR against CTP main via `promote-project-rule.sh`; CTP maintainer reviews under CTP's standard PR discipline; on merge + next GCTP pin bump the rules become global. Two-step lifecycle uses the SAME governance GCTP already applies to every CTP CL adoption.
4. **Recommender rounds it out.** S-61 handles the "you named Vue but for THIS regulatory context maybe Angular is a better fit" case, with rationale cited to umbrella-matched sources.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `b886658`; `docs/architecture-v1.9.md` sha256 updated (`d85a3f6e… → 8caadb14…`); other 4 contract-file hashes unchanged (byte-identical, verified via `sync-plugin.sh --check`). Bumped by hand under this ADR (the manual-edit-under-ADR path per ADR-0079/0086/0087/0088/0089/0090/0091 precedent — `--update` refuses on contract drift by design).
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `b886658` via `scripts/sync-plugin.sh --ensure` (verified 0 drift at the new pin).
- **`scripts/sync-plugin.sh`**: `_project/` preservation path corrected from the pre-wire top-level `$CLONE_DIR_E/_project` (TICKET-121.c speculative) to the shipped nested path `$CLONE_DIR_E/generated-code-quality-standards/_project` (CTP answer #3). Backup/restore around the rm-rf + clone works identically; only the path prefix changed.
- **`tests/test-sync-plugin.sh`**: stub `_project/` location updated to match the shipped path. Test 8 (baseline: absent → 0), Test 9 (`--ensure` re-clone → 0), preservation assertion, and byte-identical sha assertion all pass at the corrected path. 12/12 green.
- **`scripts/consult.sh --validate-profile`**: **no reconciliation required**. CTP's CL-560 shipped the runtime fields under exactly the names GCTP pre-wired at TICKET-121.a (`families_active[]`, `project_id`, `project_overlay_namespaces[]`). All 17 P-15 assertions in `tests/test-consult.sh` pass against the shipped shape unchanged.
- **`scripts/audit-architecture-crosscheck.sh`**: **no reconciliation required**. TICKET-121.b's invariant-4 extension already keys on `project_id` + `project_overlay_namespaces` + `XC_PROJECT_ID` env var. All 11 P-15 assertions in `tests/test-audit-architecture-crosscheck.sh` pass unchanged.
- **`.harness/rules/active.json`**: 118 → 118 rules byte-identical (§31 adds behavior, not authored rules). Regenerated via `standards-sync.sh` at the new pin.
- **`docs/upstream-ctp-proposals.md §P-15`**: flipped **CONVERGED (locked; CTP building) → ✅ ADOPTED** — all seven S-tickets closed at `b886658`.
- **TICKETS.md**: TICKET-122 row added (this pin bump), DONE, pointing at this ADR.
- **Consumer surfaces**: `/consult` skill plain-language translation of umbrella activation + acquisition + promotion + recommender is DEFERRED to a follow-up ticket (translation is user-facing narrative work; the enforcement spine + pre-wire suffices for adoption).

## Consequences

**Positive.**

- **Non-React frontends now get the framework-agnostic rules that already exist.** Vue, Angular, Svelte, Solid, Astro, Qwik, and any polyglot union (Next.js = frontend + backend_runtime) all fire the appropriate umbrella set at Stage 0. Before: only React did. The `active.json` corpus (118 rules) is now reachable for any technology CTP knows.
- **Per-project tech-specific rules work without polluting global.** The acquired Vue rules for FEATURE-003 sit in `_project/FEATURE-003/vue/` — first-class enforcement inside FEATURE-003 (matched via `XC_PROJECT_ID`), invisible to FEATURE-004. The no-silent-globalization spine holds: byte-identical `active.json` without `--project` is verifiable via A9.
- **PR-only promotion is the sanctioned globalization path.** Operator-controlled, reviewer-gated, no automatic path. Symmetric removal PR for deprecation. Traceability via `docs/upstream-ctp-proposals.md §P-15-followon:<tech>` status rows.
- **Recommender adds architectural judgment.** S-61 lets CTP recommend Angular over React (or vice versa) when the operator-supplied criteria warrant, with rationale cited to authoritative sources. No LLM.
- **Consumer-side reconciliation is a near-no-op.** CTP built CL-560 to GCTP's pre-wired field names on purpose (converged doc). GCTP's TICKET-121.a schema tolerance + TICKET-121.b invariant-4 land unchanged; only TICKET-121.c preservation path required a one-word correction.
- Back-compat preserved: v1.1 profiles without `families_active[]`/`project_id`/`project_overlay_namespaces[]` still validate. v1.0 profiles unchanged. Unscoped runs (no `--project`) see byte-identical `active.json`.

**Negative / knowingly accepted.**

- The TICKET-121.c preservation path was pre-wired against top-level `_project/` (a plausible-but-speculative location). Reality is nested under `generated-code-quality-standards/`. Reconciliation is a one-line prefix change + test path update; small cost relative to full parity readiness on adoption day.
- The pin span is largest of the KATA cycle so far — seven S-tickets in one bump. This is a deliberate consequence of CTP's revised phase order (family-activation first as Phase 1, all subsequent phases building on the same infrastructure): CTP shipped all seven together rather than phase-by-phase. Single-CL adoption keeps the ADR chain clean but concentrates the review surface.
- P-15's promotion PR mechanism is new to the harness. The first real promotion PR (a `P-15-followon:<tech>` entry in `docs/upstream-ctp-proposals.md`) will exercise the two-step lifecycle end-to-end; until that happens the flow is exercised only by GCTP's dry-run assertions (A11–A14).

**Neutral.**

- `active.json` unchanged (118 → 118 byte-identical). This is the ideal spine-preservation outcome per convergence doc A9.
- Deferred: `/consult` skill plain-language translation of the new S-58..S-64 surfaces (umbrella activation reveal, acquisition flow, promotion + removal, recommender explanation). Enforcement path is complete; user-facing narrative is a follow-up per the convergence-ack doc §5.
- Pin chain now runs eight-deep in the KATA cycle (ADR-0086 → ADR-0092). Each pin closes a distinct KATA-discovered defect, operator-articulated extension, or convergence-locked feature bundle.

## Rollback

`git revert` this commit → lockfile snaps back to `11126a8`; classifier reverts to pre-P-15 behavior (Vue/Angular/etc. no longer fire umbrellas); `acquire-technology-rules.sh` / `promote-project-rule.sh --release` / `promote-project-rule.sh` disappear from the cache; `_project/` overlay stops loading in the aggregator; the recommender is gone. GCTP's schema tolerance and invariant-4 scoping remain active (they're additive-optional — they degrade gracefully when the shipped fields are absent). `sync-plugin.sh` preservation path stays at the corrected nested location (harmless when `_project/` doesn't exist). No downstream schema migration required — nothing outside classification + acquisition + enforcement changed.

## References

- CTP §31 (family umbrella activation): `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §31` @ `b886658`
- CTP §31.1 (per-project acquisition): `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §31.1` @ `b886658`
- CTP §31.2 (PR-gated promotion): `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §31.2` @ `b886658`
- CTP §31.3 (canonical shapes: `_project/` layout, `origin: project`, aggregator `--project` scoping): `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §31.3` @ `b886658`
- CTP §31.4 (convergence-locked decisions): `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §31.4` @ `b886658`
- CTP S-58/S-59/S-60/S-61/S-62/S-63/S-64 commands: `.harness/plugin-cache/claude-tdd-pro/commands/{acquire,release,promote}-tech-rules.sh` @ `b886658`
- CTP CL-560 consumer-contract reconciliation: aligns `families_active`/`project_id`/`project_overlay_namespaces` runtime field names to GCTP pre-wired validator
- GCTP four-round handoff triad: `docs/handoff-ctp-p15-family-umbrella-per-project-provisioning-pr-promotion.md` (round 1) + `docs/handoff-ctp-p15-reconciliation-shared-design.md` (round 3) + `docs/handoff-ctp-p15-b1-b5-decisions-and-assertion-map.md` (round 4a) + `docs/handoff-ctp-p15-convergence-ack-and-final-shapes.md` (round 4b)
- CTP convergence lock: `.harness/plugin-cache/claude-tdd-pro/docs/handoff-ctp-to-gctp-p15-converged.md` @ `e4ec1a9` (§31.4 append)
- GCTP pre-wire (schema tolerance): TICKET-121.a @ `e096a73`
- GCTP pre-wire (invariant-4 enforcement): TICKET-121.b @ `f5ab0a4`
- GCTP pre-wire (preservation): TICKET-121.c @ `825a8f0`; corrected path in this ADR/commit
- Preceding pin bumps: ADR-0086 → ADR-0087 → ADR-0088 → ADR-0089 → ADR-0090 → ADR-0091
- Additivity invariant: ADR-0047
- Consult loop mechanism: ADR-0056
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model"
