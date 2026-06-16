# PROPOSAL-001 — Wire CTP's architecture engine into GCTP as a live consult, and make standards machine-enforced in the loop

> **Tracked copy of the operator RFC (2026-06-16).** Persisted verbatim for the record (per the
> operator's "capture PROPOSAL-001" request). Only this banner is added.
>
> **Current status:** Proposal A's governance + contract landed **additively** as **ADR-0056 /
> TICKET-062** (the GCTP↔CTP looped-consult "crossroads/translator" model — superseding ADR-0040's
> mechanism choice without deleting it). Command/hook **wiring** (Proposal A `/intake`+`/consult`,
> decompose-consumes-consult, cross-check gate, roadmap) and Proposal B (code-time detector
> enforcement) follow as later additive CLs. CTP-side items (A-6, B-5) are upstream requests
> (`docs/upstream-ctp-proposals.md`); the app-side demo (B-6) is out of GCTP scope.
>
> Note: some paths below name **proposed-but-not-yet-created** files (e.g. a `consult` command) or
> **external kata-build** artifacts; they are intentionally referenced and recorded in
> `tests/cross-references-baseline.txt` so the cross-reference audit stays green.

---

| | |
|---|---|
| **Status** | RFC / Proposal (for GCTP development) |
| **Target repo** | `grok-claude-tdd-pro` (GCTP) |
| **CTP pin referenced** | `claude-tdd-pro @ 6d2fe13` (the pin live in `docs/claude-tdd-pro.lock.yaml`) |
| **Date** | 2026-06-16 |
| **Author** | Operator (surfaced while running the O'Reilly "Certifiable, Inc." kata end-to-end through GCTP) |
| **Prime-directive note** | Every change below is to **GCTP's own tree**. The two CTP-side items are filed as **upstream requests** (consumed by reference at a pinned commit) — never forked/edited in-tree. |

---

## 0. TL;DR

Running a real architecture problem (the O'Reilly "Certifiable, Inc." kata) end-to-end through GCTP surfaced **two linked gaps between what GCTP/CTP were built to do and what the default flow actually does**:

1. **GCTP never consults CTP's architecture engine.** The `architecture-consult` flow that would have CTP ground each design decision and size each ticket is **SUPERSEDED by ADR-0040** ("do not invoke"), replaced by a static doc that is CTP-self-referential. CTP's `/architect` engine is never invoked by the loop (the inner loop wires only the `tdd-pro-cl-workflow` TDD skill).
2. **The standards registry is cited, not enforced.** `active.json` carries 42 detector rules (owasp/google/us-government/aws/azure/gcp/…), but they target IaC + JS/TS/web files; on a docs+Python deliverable they never fire. `applicable_rules` in dispatch was scoped to EO rules only; the PostToolUse hook only guards forbidden paths; the inner loop trusts the skill rather than running detectors.

This proposal:
- **Proposal A** — re-activate the `architecture-consult` as a live, cached, opt-in CTP consult and wire `/decompose` to consume it (so sizing + `applicable_rules` + grounding come from CTP, not a planner guess).
- **Proposal B** — make standards machine-enforced in the loop: detect languages → populate `applicable_rules` → run CTP detectors in the inner loop → gate `/audit` on `rules_verified`.

Both are proven feasible: we **manually revived the consult and ran CTP's engine** against the kata workload — 43 grounded concerns, `needs_grounding=0`, a recommended option corroborating the design, 6/6 Well-Architected pillars grounded, and 17 build requirements that map onto real enforceable rules. See §6 (Evidence).

---

## 1. Background

GCTP is the outer-loop harness (`/research → /decompose → /dispatch → /inner-loop → /audit`); it consumes CTP **by reference** at a pinned commit (materialized into the plugin cache). CTP is the engineering plugin: standards/sources registry, detector rubric, the `tdd-pro-*` skills, **and an architecture engine** (architect-session + architect-recommend + well-architected-review + the architect skill/agent).

The intended division of labour: GCTP plans and orchestrates; **CTP does the architecting and enforces the standards.** The findings below show the link that delivers this is currently switched off.

---

## 2. Findings (evidence)

### F-1 — The architecture-consult is deprecated, so CTP is never consulted per decision
- The consult template is headed **SUPERSEDED by ADR-0040 … do not invoke this template**. It defines exactly the right thing: a pre-decomposition consult answering six questions including **"which active.json rules apply per ticket"** and **"complexity/sizing per ticket (small/medium/large) + ADR-required flag."**
- `.grok/templates/decomposition.md` marks `architecture_consult` **DEPRECATED — ignored as of ADR-0040**; sizing now leans on the static planner context, which is **CTP-self-referential** (it talks about CTP's own architecture, Phase-E features, evals, bash-3.2 substrate) — not about an external project being designed.
- `.claude/commands/inner-loop.md` loads `tdd-pro-cl-workflow` (TDD), **never the architect skill**. So CTP's architecture engine is not in the loop at all.

**Consequence:** in two full kata builds through GCTP, CTP never architected anything; the architecture was produced by the planner/executor following outer-loop templates, with standards only *cited*.

### F-2 — Standards are cited, not enforced at runtime
- `active.json` = **42 enforced rules** across owasp(2) google(6) us-government(2) aws(2) azure(2) gcp(2) node(6) react(6) typescript(4) security-governance(2) slsa(1) w3c(1) web-vitals(2) hashicorp(2) linux-foundation(2).
- Their detectors target **IaC and JS/TS/web** files. **Zero** fire on `.md` or `.py`.
- Dispatch populated `applicable_rules` with **only the two EO rules** (correct per the "filter by detected language" rule, since the artifacts were docs+Python).
- `.claude/hooks/post-tool-use-review-gate.sh` only blocks **forbidden-path** edits — it is not a standards checker.
- CTP ships **no Python security (or Markdown) detectors** (only a Python *formatter*, pyink); the rubric runner + detectors are bash, for IaC/JS/TS/web.
- Net: only the **EO/security-governance** rules were enforced, and only at the **handoff-attestation** level (non-exemptibility + two-phase `eo_design_conformance`), not via a detector run against code.

---

## 3. Proposal A — Live, permanent GCTP→CTP architecture consult

**Goal:** before `/decompose`, GCTP calls CTP's architecture engine to (i) ground the design in tier-1 sources (cite-or-decline), (ii) recommend an option, (iii) emit build requirements, and (iv) size each ticket and pre-populate `applicable_rules`.

| ID | Change | Size |
|---|---|---|
| **A-1** | New ADR superseding ADR-0040: re-activate the architecture-consult as an opt-in *live* CTP consult; static context remains the cache-miss/ruby-absent fallback. Rationale: the consult is **cacheable**, so the round-trip cost ADR-0040 worried about is paid once; the static context cannot size an *external* project. | S |
| **A-2** | Reinstate the consult template + handoff-contract Architecture-Consult section as active (additively). | S |
| **A-3** | Add a **consult command** (+ Cursor mirror) that runs between research and decompose: invokes CTP's architect-session (S-32 intake → S-33 translate → S-34 recommend → S-35 explain) and well-architected-review (S-26) against the feature brief + research bundle, then writes the architecture artifact with grounded options, recommended option, build requirements, per-ticket **complexity** + **applicable_rules**. Cache per the template. | M |
| **A-4** | Wire `/decompose` to **consume** the consult artifact as a (default-on) input: ticket sizing + `applicable_rules` derive from CTP, not a planner guess. | M |
| **A-5** | `session-start.sh`: when the consult is enabled, **preflight ruby ≥ 3.0**. If absent, skip-to-static-context with a visible WARN rather than failing. | S |
| **A-6** *(CTP upstream)* | architect-session drops `--answers <json>` passed through its wrapper (nested-quoting bug); drive `business-intake.sh --with-data --answers <file>` directly until the upstream fix lands. | S |

**Clarifying-questions tie-in:** CTP's `business-intake.sh` already surfaces `next_question` until the profile is complete. The consult should route those to the operator, then map answers to the intake enums.

---

## 4. Proposal B — Machine-enforce the standards in the inner loop

**Goal:** the OWASP/Google/government/cloud rules in `active.json` actually *run* against produced artifacts and gate the loop — not just appear as citations.

| ID | Change | Size |
|---|---|---|
| **B-1** | `/decompose` + `/dispatch` populate `applicable_rules` by **real detected languages** over each ticket's `file_scope`, in addition to the always-on EO rules. | M |
| **B-2** | The **inner loop runs CTP detectors** against changed files for each `applicable_rule`, and reports results in the response's `rules_verified`. | M |
| **B-3** | Extend the write-time gate: run **P0 detectors** on edited IaC/web files, blocking on violation. | M |
| **B-4** | `/audit` gates on **`rules_verified` completeness**: every `applicable_rule` must be `pass` or `deviated`. | S |
| **B-5** *(CTP upstream)* | **Python security + Markdown detectors** for the rubric (ruff/bandit-backed). | L |
| **B-6** *(app-side demo, not GCTP)* | In a target project, emit **deployment IaC** so the existing P0 rules become machine-enforced. | M |

**Why B-6 matters:** the kata consult emitted build requirements that map directly onto enforceable rules — encryption_at_rest → encrypt-at-rest, audit_logging → audit-logging, "no unrestricted ingress" → no-unrestricted-ingress (P0). The moment IaC exists, those rules enforce. No registry change needed.

---

## 5. Acceptance criteria (fitness functions)

**Proposal A**
- The consult produces a **schema-valid** architecture artifact, `needs_grounding=0`, with per-ticket `complexity` ∈ {small,medium,large} and `applicable_rules` that all resolve in `active.json`.
- A regression test asserts that, when enabled, `/decompose` **consumes the consult artifact** rather than the static-context fallback.
- Ruby-absent path: the consult emits a WARN and falls back to static context; the loop still completes.

**Proposal B**
- A dispatched ticket whose `file_scope` includes an IaC file gets the corresponding cloud rule in `applicable_rules`.
- The inner loop runs the detector and reports `pass|fail` in `rules_verified`; `/audit` **fails** if any P0 detector fails or any `applicable_rule` is missing.
- A test fixture with unrestricted ingress in an IaC file is **rejected** at the write-time gate.

---

## 6. Evidence — the consult was revived and run (proof of feasibility)

Run manually against the kata workload (CTP engine, Ruby-backed, pin 6d2fe13):
- architect-session (S-32→S-36): **43 grounded concerns** across 12 dimensions, **`needs_grounding=0`**; **4 options**, each grounded in NIST 800-53 / OWASP ASVS / AWS Well-Architected / OAuth2-OIDC / Google SRE / Fowler; engine **recommended the balanced option** — independently corroborating the design's hybrid/balanced choice.
- well-architected-review (S-26): **6/6 pillars grounded**, `needs_grounding=0`.
- **17 build requirements** emitted; several map to enforceable rules (see §4, B-6). The consult also **surfaced a real gap** (reliability/ops baseline) the hand-authored ADRs had under-specified.

Reference artifacts live in the kata build (external to this repo): the CTP-engine session + well-architected JSON/MD outputs, the revived FEATURE-100 architecture artifact, the consult record, and the ADR documenting the gap it surfaced.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Consult round-trip latency/cost | Cache; opt-in toggle for trivial tickets. |
| **Ruby ≥ 3.0 absent on target** | Preflight in session-start; per ADR-0056 the loop hard-stops-and-remediates for external-project design rather than silently degrading. |
| CTP detector coverage gap (no Python/MD) | Upstream request (B-5); meanwhile enforce where detectors exist (IaC/web, B-6). Do not claim enforcement where none runs. |
| Prime-directive violation | All GCTP-tree edits; CTP changes (A-6, B-5) are upstream requests consumed by reference; pin bump only via ADR. |
| Scope creep in `/decompose` | Keep consult **advisory** to decomposition (Grok retains authority) — it informs sizing/rules, it doesn't seize orchestration. |

---

## 8. Suggested execution order

1. **A-1, A-2** (ADR + un-supersede) — unblocks everything; pure governance. *(Landed additively as ADR-0056 / TICKET-062.)*
2. **A-3** (consult command) + **A-6 workaround** — get a real artifact flowing.
3. **A-4** (decompose consumes it) + **A-5** (ruby preflight/fallback).
4. **B-1** (applicable_rules by language) — cheap, high-value.
5. **B-2, B-3, B-4** (run detectors + gate) — the enforcement teeth.
6. **B-6** (app-side IaC demo) — proves end-to-end enforcement now.
7. **B-5** (CTP Python detectors) — upstream, longest lead time.

Each GCTP step ships as one CL with its own ADR where it crosses a contract.
