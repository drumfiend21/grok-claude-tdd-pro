# ADR-0056 — GCTP↔CTP live architecture-consult loop (the crossroads/translator model)

- **Status:** Accepted
- **Date:** 2026-06-16
- **Deciders:** drumfiend21 (architect; 2026-06-16 directive specifying the loop + crossroads model, refined across several messages, with the standing constraint *"Make sure, as much as possible, it's additive and not destructive or mutating … rollbacks are easy"*) + Claude (cloud session).
- **Second voice (ADR-0029 pattern; 20th application):** the operator's "GCTP exists at the crossroads … it translates between [CTP and the user] … a guided experience of world-class software engineering" is the second voice — it asserts GCTP's defining role is bidirectional translation, not just orchestration.
- **Supersedes (additively, Nygard):** ADR-0040's *mechanism choice* (static-context-only planning). ADR-0040 and ADR-0039 are left byte-for-byte intact; this ADR adds a new, distinct mechanism (a **looped live consult**) and demotes static context to a **fallback**. Nothing is deleted.
- **Relation to PROPOSAL-001 (operator RFC, 2026-06-16):** realizes Proposal A (live consult) as a per-juncture loop, plus the operator's added cross-check + roadmap + crossroads-translator semantics. (Proposal B — code-time detector enforcement — is a later CL.)

## Context

GCTP consumes CTP by pinned reference (`6d2fe13`). CTP ships a real architecture engine (`architect-session.sh`, `architect-recommend.sh`, `well-architected-review.sh`, `business-intake.sh`) that designs under enforcement of its standards/sources (google, owasp, government, EO, SLSA, …) with cite-or-decline (`needs_grounding = 0`). Running a real architecture problem end-to-end (PROPOSAL-001) showed GCTP never invokes that engine: the per-feature consult was `SUPERSEDED by ADR-0040` in favor of a static planner context that is **CTP-self-referential** (it describes CTP's own internals) and therefore cannot size an *external* project a user is designing.

The operator specified, precisely, how it should work (this ADR records it):

1. **GCTP intakes** what the user wants to build, in business/creative language.
2. **A per-juncture loop** runs between intake and decomposition: at *each* question/decision, GCTP **consults CTP** for grounded technical direction; **translates** CTP's technical reality into non-technical/business/creative terms as clarification + guidance; **prompts** the user; the user **decides**; GCTP translates the decision back to CTP.
3. **As decisions are made, GCTP sizes and tickets** each chunk via a CTP consult on its technical reality (incremental, not end-of-run).
4. **GCTP independently cross-checks** all of CTP's proposed architecture/design/development against GCTP's *own* rules (the `active.json` registry — itself synced from CTP — **plus** GCTP-native governance: R-rules, D-rules, the EO spine, citation-integrity, the TIER-0 corpus).
5. **GCTP presents a roadmap** — real tickets, sized, sequenced, planned — to the user.

GCTP is the **crossroads**: the bidirectional translator between CTP (technical architecture/development) and the user (often non-technical). The whole loop is a *guided experience of world-class software engineering* — world-class because CTP architects under enforcement **and** GCTP checks/enforces on top.

## Decision

Adopt the **looped live consult** as the active GCTP↔CTP architecture mechanism, defined by the model above. Recorded now as governance + contract; wired in later CLs (kept additive).

**Decisions locked (operator defaults, unobjected):**

- **D-A. Loop, not single call.** The consult fires at every juncture; the roadmap accretes through the conversation.
- **D-B. GCTP is the translator.** Each turn translates both directions (user business/creative ⇄ CTP technical). This is a first-class responsibility, not a side effect.
- **D-C. Dual enforcement.** GCTP re-runs its own rule set against CTP's output. The `active.json` overlap is a consistency check (same registry, applied independently); the GCTP-native R/D/EO/citation/corpus layer is the genuine second key.
- **D-D. Ruby ≥ 3.0 is a hard prerequisite** for the consult loop (CTP's engine is Ruby-backed). Absent ⇒ stop-and-remediate with a clear message; **no** silent fallback to the self-referential static context for *external-project* design. (Static context remains valid only as planner background, not as an architecture substitute.)
- **D-E. Cross-check failure ⇒ bounded re-consult.** A GCTP-rule violation in CTP's output is fed back to CTP as an added constraint (bounded retries); if still unsatisfiable, it surfaces to the operator as a deviation requiring explicit approval (`docs/deviations.md`) — never silently accepted.

**Additivity (operator constraint).** Everything lands additively: a new ADR (this one); a **new** template `.grok/templates/architecture-consult-loop.md` (the old `architecture-consult.md` is left untouched as history); **appended** handoff-contract sections (`§Architecture-Consult-Loop`, `§Architecture-Cross-Check`, `§Roadmap`) leaving the existing SUPERSEDED section intact; an **appended** CLAUDE.md subsection composing on the two harness rules (not rewriting them). Rollback = delete the new file/section.

## Alternatives considered

- **Un-supersede ADR-0040 by editing it / flipping the template header.** REJECTED — mutating/destructive; violates the operator's additivity constraint and Nygard append-only. Introduce a new mechanism additively instead.
- **Keep static-context-only (do nothing).** REJECTED — it cannot architect or size an external project; the kata proved the gap.
- **Let CTP's `business-intake.sh` face the user directly.** REJECTED — the operator's model puts GCTP at the crossroads as translator; CTP's question catalog is the *source*, GCTP is the *interviewer*.
- **Compute the roadmap once at the end.** REJECTED — operator specified incremental sizing/ticketing "as decisions are made."

## Consequences

### Positive
- GCTP actually uses CTP's architecture engine, under enforcement, with a second independent GCTP check — a real world-class-SE guided experience for a non-technical user.
- Fully additive; trivially reversible per CL.

### Negative / cost
- Per-juncture consults add latency; mitigated by caching (`cache_key = sha256(research + brief + decisions-so-far)`) and an opt-out for trivial tickets.
- Hard Ruby dependency for the loop (D-D); honest and surfaced rather than silently degraded.

### Neutral
- No `claude-tdd-pro` path edited (prime directive); CTP engine consumed by reference. D-6 honored. `schema_version` unchanged (new artifacts, not a wire-format break).

## Verification (this CL — governance + contract only)
- New ADR + new template + appended contract sections + appended CLAUDE.md subsection; ADR-0040/0039 and the existing SUPERSEDED contract section unchanged.
- Full audit chain green; `tests/test-all.sh` 22/22; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path touched.

## Implementation references

- New: this ADR; `.grok/templates/architecture-consult-loop.md`
- Appended: `docs/handoff-contract.md` (§Architecture-Consult-Loop / §Architecture-Cross-Check / §Roadmap), `CLAUDE.md` (crossroads-loop subsection), `TICKETS.md` (TICKET-062)
- Later CLs (held): `/intake` + `/consult` commands (drive CTP's engine in the loop), `/decompose` consuming the consult artifact, the cross-check gate, the roadmap presentation, `applicable_rules`-by-language + code-time detector enforcement (PROPOSAL-001 Proposal B)
- Related: ADR-0039 (original consult), ADR-0040 (static context — superseded additively here), ADR-0037 (standards registry), ADR-0045/0055 (EO spine), PROPOSAL-001 (operator RFC, 2026-06-16; the originating analysis — captured by this ADR, not persisted in-tree this CL)
