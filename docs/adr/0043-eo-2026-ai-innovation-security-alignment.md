# ADR-0043 — Adopt EO-2026 "Promoting Advanced AI Innovation and Security" as a harness design driver

- **Status:** Accepted
- **Date:** 2026-06-13
- **Deciders:** drumfiend21 (architect; 2026-06-13 directive: *"Design improvements and new features based on the new executive order from the Whitehouse"* plus an explicit, detailed alignment analysis tying the EO to the repos' existing TDD/provenance/security-hook/multi-agent-review foundation) + Claude (cloud session, designer).
- **Second voice (per ADR-0029 pattern; 13th application):** The operator's 2026-06-13 alignment analysis IS the second voice. It named the EO's four thrusts (cyber-defense hardening, secure frontier-model practices, IP protection, criminal-misuse prevention), proposed a concrete short/medium-term roadmap, and asserted the repos are *"already a huge head start."* This ADR records the structural design that converts that analysis into prime-directive-respecting tickets.
- **Trigger:** Operator-bitten signal fired — explicit operator directive to design EO-aligned improvements, on a branch (`claude/eo-security-governance-tyjupl`) named for exactly this work.
- **Extends:** ADR-0010 (provenance-bridging / manifest — the `signature: null` extension point F-EO-4 activates), ADR-0018..0021 (manifest trilogy), ADR-0026 (quality-gate v2 — F-EO-1 adds a fifth sub-gate by the same promotion pattern), ADR-0037 (standards pipeline — F-EO-5/F-EO-9 build on the `slsa`/`owasp` namespaces), ADR-0017 (orchestrating-swarms — F-EO-7 composes it), ADR-0023 (researcher-discipline — applied to the blocked primary EO URL).
- **Does NOT supersede anything.** Purely additive.

## Context

On 2026-06-02 the White House issued the EO *"Promoting Advanced Artificial Intelligence Innovation and Security."* Its posture — secure-by-design AI innovation with minimal new regulation — maps cleanly onto what the harness already encodes: disciplined TDD, provenance/audit trails, CWE-mapped security hooks, multi-lens review, and governance-as-code.

The operator directed a design of EO-aligned improvements and supplied a detailed analysis. Three facts shaped this ADR:

1. **The primary EO text was not directly fetchable** in this environment (whitehouse.gov returned HTTP 403 — the `host_not_allowed`/bot-block class in `docs/researcher-discipline.md`). Per the §3 fallback, the EO's operative content was reconstructed from ≥ 3 independent indexed secondary legal analyses agreeing on the same section structure and deadlines, and is recorded at **verification tier T-C**. The EO is a **design input**, not a `docs/founder-directives.md §1` elevation — no §1 entry is created or modified.

2. **Much of the operator's roadmap is latent-extension-point activation, not greenfield.** The provenance manifest already reserves `signature: null`; an `aibom.json` AI-BOM already exists; the standards registry already ships `slsa` + `owasp` namespaces. The EO does not demand a new architecture.

3. **Part of the operator's roadmap proposed plugin-side skills** ("vulnerability-gated TDD" skill, "cyber red-teaming" skill). The prime directive (`CLAUDE.md` TIER-1) forbids editing `claude-tdd-pro` from this repo. Those items are inner-loop discipline and belong upstream.

## Decision

Adopt the EO as a documented TIER-2 design driver via `docs/eo-2026-ai-innovation-security-alignment.md`, and decompose it into ten features (F-EO-1..F-EO-10) across seven harness-side tickets (TICKET-043..049), with a strict prime-directive boundary:

- **Harness-side (built in this repo, per-ticket):** a fifth `vulnerabilities_remediated` quality sub-gate + `audit-vuln-scan.sh` (F-EO-1); a clearinghouse-style `emit-cyber-report.sh` (F-EO-2); Sigstore/cosign manifest signing + CycloneDX/SPDX SBOM activating the reserved extension points (F-EO-4/F-EO-5); a "covered frontier model" public self-assessment template + secure-deployment checklist (F-EO-6/F-EO-8); a red/blue-team adversarial swarm *composition* of the existing skill (F-EO-7); a misuse-resistance review profile + defensive-coding examples (F-EO-9/F-EO-3); and an EO compliance profile mapping harness gates to NIST AI RMF / SSDF / CISA BODs (F-EO-10).

- **Plugin track (filed separately, NOT built here):** the "vuln-gated TDD" and "cyber red-team" *skills* are recorded as v1.11 amendment proposals to be filed in `claude-tdd-pro` per the prime directive.

- **Out of scope (permanent):** replicating the EO's classified cyber-capability benchmark; making the harness an automated CISA/OMB upload client; any mandatory (non-voluntary) frontier-model gate.

This design CL ships the doc + this ADR + the tickets only. Implementation lands per-ticket, each with its own substrate test, audit-chain-green verification, and (where architecturally significant) its own ADR.

## Alternatives considered

- **Implement the features in this CL.** REJECTED. The harness's discipline is one ticket per CL; a ten-feature CL violates it. Design-then-decompose is the on-convention path (mirrors ADR-0011/0018 design-first ADRs).
- **Edit `claude-tdd-pro` to add the proposed skills directly.** REJECTED — prime-directive violation (no cross-repo edits). Filed as upstream proposals instead.
- **Promote the vuln sub-gate to Required immediately.** DEFERRED to TICKET-043's own ADR. New default-on gates follow the ADR-0026 promotion pattern; the promotion decision is the ticket's, not this design ADR's.
- **Treat the EO as a `founder-directives.md §1` source.** REJECTED. §1 is for engineering-practice provenance (Karpathy/Musk/Anthropic/Amodei). The EO is a compliance/design input, recorded at T-C in a TIER-2 doc, not elevated to §1 (and §1 is immutable/append-only regardless).
- **Bump the plugin pin to pick up any EO-related upstream work.** REJECTED for this CL. No feature here depends on a pin change; pin bumps require their own ADR (architecture-principles §15).
- **Build a classified-benchmark analogue.** REJECTED permanently — classified/government-run; the harness ships only a public self-assessment proxy.

## Consequences

### Positive

- **Direct EO alignment becomes an auditable, traceable design artifact** (control → harness asset → enforcing gate matrix in F-EO-10), suitable for enterprise/government-adjacent review.
- **Latent extension points get activated** (manifest signing, AI-BOM → SBOM), increasing IP-protection / tamper-evidence value at low cost.
- **The prime directive is honored explicitly** — the harness/plugin boundary is documented per feature, and inner-loop items are routed to upstream proposals rather than patched in.
- **13th application of the `Second voice` field** (operator analysis is the second voice).
- **Researcher-discipline applied to a blocked primary** — the EO facts carry an honest T-C tier rather than a fabricated T-A.

### Negative

- **The EO facts are T-C, not T-A** (primary blocked). Mitigation: no feature depends on phrasing finer than the corroborated section structure; a follow-on may upgrade to T-A if the primary becomes fetchable.
- **Seven new tickets enlarge the backlog.** Mitigation: sequenced into the operator's own short/medium-term horizons; each is ~1 CL.

### Neutral

- **TIER-0 corpus untouched.**
- **§1 provenance + D-rule bodies + D-checklist untouched** (D-6 honored — `git diff docs/founder-directives.md` == 0).
- **R-/G-/C-rule bodies untouched.**
- **Plugin pin unchanged** (`bba77df`).
- **Wire-format `schema_version` unchanged.**
- **No `claude-tdd-pro` path touched** (prime directive).

## Verification (executed before commit)

- `docs/eo-2026-ai-innovation-security-alignment.md` + this ADR follow the numbered template + `Second voice` field present (13th application).
- `TICKETS.md` extended with TICKET-043..049 in the existing table format.
- `git diff docs/founder-directives.md` → 0 lines (D-6 honored).
- No file under `.harness/plugin-cache/claude-tdd-pro/` or any `claude-tdd-pro` path modified.
- Plugin pin (`bba77df`) unchanged; `schema_version` unchanged.

## Implementation references

- New: `docs/eo-2026-ai-innovation-security-alignment.md` (the design)
- New: this ADR
- Modified: `TICKETS.md` (TICKET-043..049)
- Related: ADR-0010/0018-0021 (provenance), ADR-0026 (quality-gate v2), ADR-0037 (standards pipeline), ADR-0017 (swarms), ADR-0023 (researcher-discipline), ADR-0029 (`Second voice` field — 13th application)
