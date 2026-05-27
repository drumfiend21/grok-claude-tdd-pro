# ADR-0027 — Wayfair / 2026 harness-engineering competitive intel: filter application (TICKET-021)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 direction: *"Branch off of main. Consider the following and extend the architecture accordingly"* + the prior session's standing directive *"Qualify and quantify over-engineering and avoid it"*) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0023 (researcher-discipline — the verification framework this ADR applies to single-source T-D paraphrased intel); ADR-0025 + ADR-0026 (the over-engineering filter precedent + the §Alternatives structural-rejection pattern this ADR follows)

## Context

On 2026-05-26 the architect provided a briefing summarizing Wayfair's AI efforts (mid-2026 state) and broader 2026 industry trends in "harness engineering" — the discipline of structuring tools, guardrails, context, and orchestration around base models to make them reliable at scale. The briefing positioned `grok-claude-tdd-pro` competitively against Wayfair's inferred internal practice, OpenAI Codex, Anthropic agent harnesses, Meta REA, Microsoft Azure SRE Agent, Google Jetski/Antigravity, and the Stripe/Shopify/Airbnb cohort. Per the architect: *"Consider the following and extend the architecture accordingly."*

The briefing identified specific gaps to close:

1. *"Add more quantifiable evals/metrics"*
2. *"Broader examples (e.g., Next.js-specific workflows)"*
3. *"Continue iterating (demos, metrics, frontend-specific extensions)"*

And surfaced these patterns from comparable enterprise harnesses:

- **OpenAI Codex** — agent-first development; 1M+ LOC product with almost no human-written code.
- **Anthropic** — long-running agent harnesses (initializer + incremental coding agents; artifacts for continuity).
- **Meta REA / Microsoft Azure SRE Agent / Google Jetski** — checkpointing, context engineering via files, human-in-the-loop, observability.
- **Stripe / Shopify / Airbnb** — custom harnesses for consistent, auditable agent output.

The briefing's source-evidence profile, evaluated per `docs/researcher-discipline.md §4-5`:

- **Single source** (the briefing text itself).
- **Numerical citations (10, 77, 41, 88, 66, 60, 64, 13, 16)** are not externally fetchable from this harness session (host network policy applies; per ADR-0023 the verification-tier model handles this case explicitly).
- **No primary-operated domain anchor** (e.g., no `wayfair.com/eng`, no `openai.com`, no `anthropic.com` direct quote with cross-attribution).
- **Verdict per researcher-discipline.md §5:** the briefing is **T-D substantive paraphrase**, NOT T-C / T-B / T-A. Insufficient for `docs/founder-directives.md §1` elevation. Acceptable as operator-pitch intel in `AUTOMATION_INTEL.md` per the append-only log convention.

The architect's standing 2026-05-26 directive ("Qualify and quantify over-engineering and avoid it") applies. Each candidate extension is filtered before commitment, per the five-criterion framework established in ADR-0025 + ADR-0026.

## Decision

### 1. Filter applied to 7 expansion candidates; 6 of 7 REJECTED (~86% cut)

The five-criterion over-engineering filter:

1. Operator-bitten? (or speculative-only)
2. Composes on existing primitives?
3. R-3 (single source of truth) risk acceptable?
4. Maintenance cost < value-add?
5. Deletion-pass survives? — would the harness be MEASURABLY worse without it?

REJECT if: speculative-only OR R-3 duplicating OR maintenance-exceeds-value OR cosmetic-completeness-only.

| Candidate | Filter result | Rationale |
|---|---|---|
| **C1: Add Next.js / React demo target** (`examples/nextjs-design-tokens/` or similar) | **REJECT** | Speculative — the operator has not been bitten by lacking a Next.js demo. `examples/string-utils/` satisfies the Q-DEMO acceptance criterion. Frontend-platform-specific demos are pitch material, not architecture-bitten. Deletion-pass survives: the demo storyboard (`docs/demo-storyboard.md`) can append a "Next.js variant deferred" note without shipping the demo. |
| **C2: Add `scripts/audit-metrics.sh` for evals/metrics aggregation** | **REJECT as new script** | Borderline-bitten (the operator may want roll-up stats across sessions). FAILS the "composes on existing primitives" test in a strict reading: an operator can derive identical info via `find .harness/audit/*.manifest.json` + `grep`/`awk` one-liners. Maintenance cost = real (new script + audit pattern + ADR boilerplate). Documented one-liners in AUTOMATION_INTEL capture the value at zero substrate cost. **Accepted as documented one-liners**, not as substrate. |
| **C3: TIER-2 doc `docs/initializer-incremental-agents-design.md`** (Anthropic-pattern adaptation) | **REJECT** | Not operationally bitten — no observed need for multi-session continuity beyond what `.harness/trails/` + manifests already provide. Speculative design = same failure mode as the prior session's rejected `docs/self-healing-implementation-design.md` candidate. Defer until operationally bitten. |
| **C4: Cross-session observability surface** (Meta REA / Microsoft Azure SRE pattern) | **REJECT** | Not operationally bitten — no operator complaint about session bridging. The `.harness/audit/*.manifest.json` set IS the cross-session log; aggregation is C2 (also rejected). |
| **C5: TIER-2 doc `docs/competitive-positioning.md`** (Wayfair / industry comparison) | **REJECT** | `AUTOMATION_INTEL.md` already carries the enterprise pitch-hook surface (per its 2026-05-24 + 2026-05-25 + 2026-05-26 entries). A TIER-2 doc would be R-3 violation (duplicates AUTOMATION_INTEL content). The append-only log convention is the right home for evolving competitive intel. |
| **C6: Elevate the briefing as `docs/founder-directives.md §1` Source 10** | **REJECT** | Per `docs/researcher-discipline.md §5` acceptance bar: ≥ 3 secondary sources required for T-C; this briefing is **single-source T-D paraphrase** with no primary-operated domain anchor. §1 elevation would violate the cross-source acceptance bar; AUTOMATION_INTEL append is the correct tier per the established researcher discipline. |
| **C7: This ADR (ADR-0027 capturing the filter application)** | **ACCEPT** | Operator-bitten: the over-engineering-filter decisions must persist for future readers, OR the same candidates resurface every time someone reads the briefing. Composes on existing primitives: ADR template established by ADRs 0001-0026; §Alternatives-with-rationale pattern established by ADR-0025 / ADR-0026. R-3 risk low: each rejection cites a different rationale; no duplication. Maintenance cost: trivial (single doc; immutable post-acceptance). Deletion pass: does NOT survive — without the ADR, the rejection rationale is session-ephemeral and re-litigated on every re-read of the briefing. |

### 2. ACCEPTED extension: `AUTOMATION_INTEL.md` append entry

A single append entry to `AUTOMATION_INTEL.md` per its established 2026-05-24 / 2026-05-25 / 2026-05-26 pattern:

- Captures the 2026-05-26 competitive-positioning signal as **T-D paraphrase** with explicit tier tag.
- Documents the **metric-derivation one-liners** an operator can run today against existing manifests + trails (closing C2's gap at zero substrate cost).
- Names the **6 rejected expansion candidates** with one-line rationale each (pointer-only; full rationale in this ADR).
- Surfaces the **harness's competitive positioning** vs. the named comparables — enforceability + tamper-evident audit + cross-IDE composition are the documented edges.
- Append-only per the AUTOMATION_INTEL convention; existing entries untouched.

### 3. NO new substrate, NO new tooling, NO new TIER-2 docs

Zero new scripts. Zero new `.cursor/` content. Zero new `.claude/` content. Zero new TIER-2 design docs. Zero new D-rules. Zero §1 amendments.

This is the disciplined extension: capture the intel; record the rejections; defer the bait. Per D-8 (delete the part) and D-13 (kitchen-sink resistance) applied with the strictest reading.

## Alternatives considered (per §Decision-1 above; expanded here for completeness)

- **Adopt the briefing literally** (ship Next.js demo + metrics script + initializer-incremental TIER-2 + cross-session observability + competitive-positioning TIER-2 + §1 Source 10 elevation). REJECTED per the filter — 6 of 7 candidates fail one or more criteria.
- **Treat the briefing as actionable as-is** without filtering. REJECTED — directly contradicts the architect's standing 2026-05-26 "qualify and quantify over-engineering" directive.
- **Ship the AUTOMATION_INTEL append WITHOUT this ADR.** REJECTED — without the ADR, the rejection rationale is session-ephemeral; the same expansion candidates re-surface on any re-read of the briefing.
- **Ship `scripts/audit-metrics.sh` as a 30-line script** (`find` + `grep` + `awk` over `.harness/audit/`). REJECTED per Decision-1 C2 — the one-liners in AUTOMATION_INTEL capture the value at zero substrate cost; the script's marginal value is presentation, not capability.
- **Defer indefinitely (no extension at all).** REJECTED — the architect explicitly said "extend the architecture accordingly"; capturing the intel + recording the rejections IS the disciplined extension. Zero extension would silently drop the briefing.
- **Elevate the briefing to TIER-2 as a separate competitive-intel rulebook.** REJECTED per Decision-1 C5 — R-3 vs. AUTOMATION_INTEL.

## Consequences

### Positive

- **TICKET-021 acceptance criterion met.** Architecture extended per the filter; ADR + AUTOMATION_INTEL append shipped; 6 of 7 candidates rejected with documented rationale.
- **Over-engineering-filter precedent reinforced.** ADR-0025 + ADR-0026 established the filter; ADR-0027 applies it for the third time. The pattern is now durable.
- **AUTOMATION_INTEL.md gains a 2026-05-26 entry** with competitive-positioning signal + metric-derivation one-liners + named deferrals. Operator gets pitch material; harness gets zero substrate inflation.
- **D-12 (production-grade trust) reinforced.** The briefing's T-D tier is explicitly recorded; no claim is upgraded beyond its evidence. Auditors see exactly what evidence backs each claim.
- **R-3 (single source of truth) honored.** Each rejected TIER-2 candidate would have duplicated content already discoverable elsewhere; the rejections preserve the existing source-of-truth tree.
- **D-8 (delete the part)** applied with the strictest reading: 86% of proposed expansions cut; documented rationale per rejection.
- **Researcher-discipline tier model exercised.** Per ADR-0023, single-source T-D paraphrase fails the §5 cross-source acceptance bar for T-C; §1 elevation correctly refused.

### Negative

- **The briefing's "pitch optimization" candidates are deferred.** A future operator who wants Next.js demo material or a competitive-positioning doc will not find them in this CL. Mitigation: the AUTOMATION_INTEL entry names the deferrals; future-self-or-collaborator knows where to look + what's missing.
- **The metric-derivation one-liners are operator-runnable but not automated.** A `scripts/audit-metrics.sh` would be more polished. Mitigation: filter rejection rationale (C2) is documented; the trigger for un-rejection is "operator-bitten signal that one-liners are insufficient." That trigger has not fired.
- **Single-source T-D intel inflates AUTOMATION_INTEL by ~30 lines.** Mitigation: AUTOMATION_INTEL is append-only by design; the entry is dated + tagged with T-D explicitly so future readers calibrate weight correctly.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.**
- **`schema_version` of the handoff contract unchanged.**
- **AGENTS.md untouched** (no new TIER-2 surfaces; no enumeration changes needed).
- **`.cursor/rules/` untouched** (no new authority docs).
- **`scripts/sync-plugin.sh --help` unchanged** (F-4 still passes).
- **No new scripts.** No new `.claude/` content. No new `.grok/` content. No new `examples/` targets.

## Verification (executed before commit)

- AUTOMATION_INTEL.md gains the 2026-05-26 entry tagged "T-D paraphrase per ADR-0023 / ADR-0027."
- ADR-0027 follows the numbered ADR template.
- `./scripts/audit-doc-drift.sh` exits 0 (F-1..F-6 clean; new ADR + append text don't trip any pattern).
- `./scripts/smoke-e2e.sh` exits 0.
- `./scripts/export-cursor-rules.sh --check` exits 0 (no `.cursor/rules/` changes in this CL).
- `./scripts/audit-manifest.sh` exits 0.
- TICKETS.md gains TICKET-021 row marked DONE.
- Sources 1-9 of `docs/founder-directives.md §1` byte-identical (no §1 elevation per §Decision-1 C6).

## Out of scope (deferred per filter; documented for future re-triage when triggered)

Each deferral has a named trigger condition; when the trigger fires, that candidate can be re-evaluated:

- **C1: Next.js demo target** — Trigger: an actual prospective enterprise (Wayfair, etc.) commits to evaluating the harness against a Next.js codebase and asks for a working demo. Until then, `examples/string-utils/` is sufficient.
- **C2: `scripts/audit-metrics.sh`** — Trigger: operator reports the one-liners (documented in AUTOMATION_INTEL) are insufficient for cross-session visibility. Until then, derive metrics via shell.
- **C3: Initializer + incremental agent TIER-2 doc** — Trigger: a real multi-session continuity gap surfaces (e.g., the agent loses critical context across sessions and the trail + manifest set is insufficient to recover). Until then, defer.
- **C4: Cross-session observability surface** — Trigger: same as C2 (the manifest aggregation case) at higher fidelity. Until then, defer.
- **C5: TIER-2 competitive-positioning doc** — Trigger: AUTOMATION_INTEL grows beyond what an append-only log can manage (likely > 50 entries; today: 4). Until then, the log is the right home.
- **C6: §1 Source 10 elevation of the briefing** — Trigger: an independent primary-operated-domain source corroborates the briefing's specific claims (e.g., Wayfair Engineering blog post; OpenAI Codex public-data release with verifiable LOC claims). Until then, T-D paraphrase only.
- **Future re-triage cadence:** revisit on the next major intel signal (estimated 1-3 months) or on operator-explicit re-evaluation request.

## Implementation references

- Modified: `AUTOMATION_INTEL.md` (append 2026-05-26 entry; ~30 lines)
- New: this ADR
- Modified: `TICKETS.md` (TICKET-021 row marked DONE)
- Related: ADR-0023 (researcher-discipline — T-A/T-B/T-C/T-D model; cross-source acceptance bar; this ADR applies the framework), ADR-0024 (Source 9 elevation — the T-C precedent this ADR explicitly does NOT meet, hence the AUTOMATION_INTEL routing), ADR-0025 (plugin pin bump — over-engineering-filter precedent: 60% cut, 2 sub-expansions rejected), ADR-0026 (quality-gate v2 — over-engineering-filter precedent: 67% cut, 5 alternatives + 2 mega-CL/defer rejected), AUTOMATION_INTEL.md (the canonical home for evolving enterprise pitch / competitive intel per the established append-only convention).
