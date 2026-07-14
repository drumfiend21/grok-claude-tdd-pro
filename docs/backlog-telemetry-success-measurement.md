# Backlog — GCTP-owned slice of the telemetry + software-success-measurement design

**Status: DESIGN — backlogged for build.** This records the **GCTP harness's** responsibilities
in the telemetry / anonymous-project-id / software-success-measurement architecture, so the work
is captured in-repo and can be built later. It is a pointer, not a duplicate: the **authoritative
design lives in the CTP plugin repo** at
`drumfiend21/claude-tdd-pro:docs/design/v1.28-telemetry-collector-and-success-measurement.md`
(architecture pointer: CTP `docs/architecture-v1.9.md` §34), which carries the full vision, the
tiered consent model, the collector infrastructure, the measurement design, the consent-as-feature
reciprocity (§9), the meta-improvement engine (§10), and the per-item build-location table (§11).

Per the prime directive (CTP = capability/standards provider; GCTP = orchestration / app-scaffolding
/ user-facing consumer) and the joint-design regime, the split below is authoritative-by-reference
to CTP v1.28 §11. GCTP owns three things and the GCTP halves of the joint items.

## What GCTP builds (its own repo, its own CLs)

1. **Tier-2a production beacon — scaffold-time injection.** When GCTP generates/scaffolds a
   user's project (the `/consult → /roadmap → /decompose → /dispatch` outer loop), it offers to
   wire the opt-in production-success beacon into the generated app. The beacon's **data contract**
   is a CTP capability; **injecting it at scaffold time** is GCTP's job. Opt-in + reciprocity per
   the consent model; the app runs identically without it.

2. **Consent-as-feature benchmarking — user-facing presentation.** GCTP is the crossroads /
   translator to the (often non-technical) user, so the user-facing view of "how your project
   stacks up within the GCTP/CTP fleet" (percentile, nearest anonymized exemplars, gap-to-gold-
   standard, "do X to move up" guidance) is presented **by GCTP**. The **standing computation**
   over the fleet is author-infra/CTP; GCTP renders and explains it. K-anonymity floor enforced
   before any comparative stat is shown.

3. **Feedback loop + meta-improvement — self-healing + operator-HITL orchestration.** The
   **action on standards/registries** (promote sources, propose rules) is PR-gated in CTP
   (§31.2); the **inference/meta-learning pipeline** is author-infra. GCTP owns the
   **orchestration and the operator human-in-the-loop gating** of those proposals, composing with
   the existing self-healing design (`docs/self-healing-design.md`, TICKET-008) and the
   consult/audit spine — the operator reviews a well-evidenced decision, never raw data, and no
   standard mutates silently.

## Joint items (GCTP half + CTP half, coordinated, never cross-staged)

| Item (CTP v1.28 §8 roadmap) | GCTP half | CTP half |
|---|---|---|
| Excellence-signature model | — (fleet training is author-infra; user-facing score surfaced via item 2) | per-project signature scoring (CTP detectors) |
| Tier-2a production beacon | scaffold-time injection (item 1 above) | beacon data-contract |
| Feedback loop | self-healing + HITL orchestration (item 3) | registry/rule action layer, PR-gated |
| Consent-as-feature view | user-facing presentation (item 2) | standing computation |
| Meta-improvement engine | operator-review orchestration (item 3) | action-drafting into CTP registries |

## Not GCTP's to build (recorded for completeness)

- **CTP-owned:** Tier-0 public-URL telemetry (BUILT), Tier-1 anon project-id + aggregate
  health/DORA emit, Tier-2b codebase-signature analysis, and all CTP halves above.
- **Author-infra:** the collector (API Gateway → Lambda → S3 lake / DynamoDB) and the fleet
  inference/meta-learning pipeline — generated via the governed IaC pipeline, operator-deployed,
  explicitly **not** a consumed plugin surface (so no prime-directive coupling).

## Build discipline when these are picked up

- GCTP work → committed + pushed in this repo; CTP work → committed + pushed in the CTP repo.
  Never stage a CTP file in a GCTP commit or vice versa (joint-design regime).
- GCTP consumes any new CTP capability by **pinned reference** (pin-bump ADR, §15-gated), never
  by editing the plugin cache in place.
- Each GCTP build CL follows the GCTP TDD + audit-chain discipline; each disclosed/opt-in tier
  keeps the consent posture recorded in CTP `docs/telemetry.md` truthful.

## Open questions (owned jointly; see CTP v1.28 §7 + §10)

O-1 kata corpus licensing · O-2 production-signal set + beacon shape · O-3 correlation-vs-causation
method · O-4 EU consent posture · O-5 collector retention/deletion · O-6 min evidence rung to draft
an action · O-7 explore/exploit budget · O-8 k-anonymity + differential-privacy parameters.
