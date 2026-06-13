# ADR-0044 — Review-driven refinements to the EO-2026 alignment design (multi-perspective triage)

- **Status:** Accepted
- **Date:** 2026-06-13
- **Deciders:** drumfiend21 (architect; supplied four simulated engineering-leadership reviews of the ADR-0043 design and directed refinement) + Claude (cloud session, designer).
- **Second voice (per ADR-0029 pattern; 14th application):** Four simulated leadership reviews (Musk/xAI, Gates/Microsoft, Bezos/Amazon, Cook/Apple) are the second voices. They converged on "activate latent capabilities first, extend harness-side without bloating process," and each contributed concrete suggestions triaged in `docs/eo-2026-ai-innovation-security-alignment.md §8`.
- **Trigger:** Operator supplied review feedback on the ADR-0043 design before any of TICKET-043..049 was implemented — the cheapest point to fold feedback in is now, pre-implementation.
- **Extends:** ADR-0043 (the EO design this refines). Does NOT supersede it — purely additive (§8 appended to the design doc; ADR-0043 stays Accepted, unedited, per Nygard append-only).

## Context

ADR-0043 landed the EO-2026 alignment design (features F-EO-1..F-EO-10, tickets TICKET-043..049) as a design CL with nothing yet implemented. The operator then supplied four leadership-perspective reviews. The reviews were largely affirming (scores A/A/A-/B+) and converged on a prioritized roadmap matching ADR-0043's own ordering, but added ~14 concrete suggestions ranging from cheap high-value enrichments (CISA KEV prioritization, in-toto attestations, a security-score/MTTR metric) to heavyweight new surfaces (fast-track mode, STRIDE audit, compliance dashboard, chaos testing, real-time CISA monitoring).

Adopting all of them would violate the repo's over-engineering filter — and, pointedly, the Bezos review's own "strict scoping to avoid backlog bloat." The decision was therefore a triage, not a wholesale adoption.

## Decision

Fold the cheap, high-value, infra-reusing suggestions into existing tickets; defer the heavyweight ones behind named triggers; reject the ones that conflict with the EO's voluntary posture or harness invariants. Full disposition table in `docs/eo-2026-ai-innovation-security-alignment.md §8`. Summary:

- **ADOPT (into existing tickets, no new tickets):** CISA KEV prioritization → 043; security-score + vuln-MTTR (reuses `audit-metrics.sh`/`dora-metrics.md`) → 044; in-toto attestations + SLSA L3+ target → 045; data-minimization/edge/insider-risk checklist lines → 046; WCAG 2.2 + ethical section (reuses `w3c`/`web-vitals` namespaces) → 049; model-extraction/sandboxing/prompt-injection defenses reaffirmed in 047/048; trusted-partner SBOM/provenance pack → 045/046.
- **DEFER (named trigger):** fast-track/spike mode; STRIDE audit; compliance dashboard; chaos testing; real-time CISA monitoring; differential-privacy evals.
- **REJECT (permanent):** auto-upload to CISA/OMB; replicate classified benchmark; cosign-on-by-default.

**No new tickets are created** — the meta-decision is that the adopted items are scope-refinements to TICKET-043..049, not new work units. This keeps the backlog flat (honoring the Bezos scoping point) while capturing every adopted suggestion.

## Alternatives considered

- **Adopt every suggestion as new tickets.** REJECTED — backlog bloat; violates the over-engineering filter and the Bezos review's own scoping caution.
- **Adopt none (reviews are affirming, leave design as-is).** REJECTED — the KEV/in-toto/metric suggestions are concrete, cheap, and materially improve EO §2/IP alignment.
- **Build the fast-track mode now (Musk).** REJECTED for now — no operator-bitten drag signal; it conflicts with the non-negotiable green gate unless carefully designed to defer (not remove) gates to merge-time. Deferred behind an explicit trigger.
- **Edit ADR-0043 in place to absorb the refinements.** REJECTED — Nygard append-only; landed a follow-on ADR + a §8 design-doc section instead.
- **Create `RECRUITING.md` for positioning (reviews' synthesis).** REJECTED — no such file exists and it is outside EO-design scope; noted out-of-band for the operator.

## Consequences

### Positive

- **Every adopted suggestion is captured without enlarging the backlog** (refinements fold into 043..049).
- **The deferral rationale is recorded** — future readers see *why* fast-track/STRIDE/dashboard/chaos/monitoring were not built, with the trigger that would revive each.
- **Adopted items reuse existing infra** (`audit-metrics.sh`, `dora-metrics.md`, `w3c`/`web-vitals` namespaces) rather than building new substrate.
- **14th application of the `Second voice` field**; first multi-voice (four reviews) application.

### Negative

- **§8 adds review-specific detail to a design doc**, slightly lengthening it. Mitigation: it is a bounded triage table, not prose sprawl.

### Neutral

- **No new tickets**; TICKET-043/044/045 Scope cells refined to name KEV / metric / in-toto.
- **TIER-0 corpus, §1 provenance, D-/R-/G-/C-rule bodies untouched** (D-6 honored).
- **Plugin pin `bba77df` + `schema_version` unchanged**; no `claude-tdd-pro` path touched (prime directive).

## Verification (executed before commit)

- §8 appended to `docs/eo-2026-ai-innovation-security-alignment.md`; this ADR follows the numbered template + `Second voice` field (14th application).
- TICKET-043/044/045 Scope cells refined; no new tickets added.
- `git diff docs/founder-directives.md` → 0 lines (D-6).
- Cross-reference, doc-drift, rulebook-coverage audits green; `tests/test-all.sh` 18/18.
- No `claude-tdd-pro` path modified; plugin pin + `schema_version` unchanged.

## Implementation references

- Modified: `docs/eo-2026-ai-innovation-security-alignment.md` (new §8)
- Modified: `TICKETS.md` (TICKET-043/044/045 Scope refinements; no new rows)
- New: this ADR
- Related: ADR-0043 (the design refined here), ADR-0029 (`Second voice` — 14th application), ADR-0026 (quality-gate non-negotiability cited in the fast-track deferral), ADR-0037 (standards namespaces reused)
