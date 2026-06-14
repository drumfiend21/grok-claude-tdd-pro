# ADR-0048 — EO governance enforcement spine + handoff-contract extension (TICKET-050)

- **Status:** Accepted
- **Date:** 2026-06-14
- **Deciders:** drumfiend21 (architect) + Claude (cloud session, designer/implementer).
- **Trigger:** TICKET-050 — turn the EO-2026 governance layer (ADR-0045/0046/0047) from documented posture into an *enforced* cross-cutting requirement, using the **existing** operator-declared-standards machinery (ADR-0037), with no harness-native EO rule content invented (prime directive).
- **Extends:** ADR-0045 (governance-layer elevation), ADR-0046 (two-phase: design-before-code AND code), ADR-0047 (additive, never subtractive), ADR-0037 (operator-declared-standards regime), ADR-0026 (structural promotion precedent — `provenance_complete` rode the gate without a new wire-format sub-field). Does NOT supersede anything — additive (Nygard append-only).

## Context

ADR-0045/0046/0047 elevated the EO-2026 governance layer to an always-on, two-phase, additive cross-cutting dimension and recorded it in `CLAUDE.md`. What was still missing was the **enforcement spine**: a contract surface that makes the EO subset non-exemptible and carries the design-phase attestation, plus an audit that verifies both invariants over the handoff artifacts.

Constraints (from TICKET-050 + the prime directive):

- **No new enforcement mechanism.** Reuse the `applicable_rules` → `rules_verified` → quality-gate machinery (ADR-0037) plus one structural audit, the same way `provenance_complete` was promoted structurally (ADR-0026).
- **No harness-native EO rule content.** EO rule *content* is owned by `claude-tdd-pro`'s in-flight EO work and arrives in `.harness/rules/active.json` via a future pin bump. The harness owns the **enforcement spine**; the plugin owns the **rule content**; they meet at the contract surface (`active.json` + `applicable_rules`). Content-agnostic by construction.
- **Additive (ADR-0047).** The spine may only ADD checks; it never relaxes a base standard. `green` is the conjunction of base standards AND the EO layer.

## Decision

Land the EO governance enforcement spine as a content-agnostic structural audit plus a handoff-contract extension:

1. **Handoff-contract extension (`docs/handoff-contract.md`).**
   - **Non-exemptibility clause (request side):** when `applicable_rules` is present, it MUST include every rule whose `source_namespace` is in the EO set (canonical: `eo`) in `active.json`, regardless of `file_scope` or language. Grok MUST NOT filter them out per-ticket. The pre-existing fail-closed default (absent `applicable_rules` ⇒ all rules apply) already covers the EO subset.
   - **New optional response field `eo_design_conformance` (response side):** the two-phase design-before-code attestation (`design_phase_attested`, `rules_considered`, `patterns_applied`, `notes`). Additive optional field; `schema_version` stays `"1"` (R-11 tolerant reader). When EO-namespace rules are active, a `green` response MUST carry a non-empty `eo_design_conformance`; when the EO set is empty the field is optional and the check is vacuous.

2. **Enforcement spine (`scripts/audit-eo-governance.sh` + `tests/test-audit-eo-governance.sh`).** A bash 3.2 / BSD-portable, dependency-free audit that, **only once** an EO-namespace rule appears in `active.json` (spine "armed", then "biting"), verifies: (a) non-exemptibility over every `*.req.json`, and (b) the two-phase attestation over every green `*.res.json`. Vacuous pass while the EO set is empty (pin-bump-gated). Env-overridable fixture paths (`EO_RULES_FILE` / `EO_HANDOFFS_DIR` / `EO_NAMESPACES`) make the content-agnostic spine testable with and without EO rules present.

3. **Wiring.** Session-start hook runs the audit WARN-only (never blocks a session); CI (`.github/workflows/test.yml`) runs it as a hard gate. `.grok/templates/decomposition.md` + `dispatch.md` instruct Grok to always inject the EO subset into `applicable_rules`. `AGENTS.md` mirrors the `CLAUDE.md` standing directive. `docs/quality-gate.md` records the EO governance as a standing cross-cutting `green` requirement.

## Alternatives considered

- **Add a fifth wire-format sub-gate field to `quality_gate`.** REJECTED — `provenance_complete` set the precedent (ADR-0026) that a standing requirement can ride the existing machinery structurally without a new sub-field; a new sub-gate would be redundant mechanism.
- **Author harness-native EO rules now so the spine bites immediately.** REJECTED — violates the prime directive (rule content is the plugin's) and ADR-0045's content-agnostic mandate. The spine is armed and waits for the pin bump.
- **Hard-fail at session start.** REJECTED — mirrors every other harness audit's WARN-not-FAIL session-start policy; CI is the hard gate. A local artifact state must never strand a session.
- **Parse JSON with `jq`/`node`.** REJECTED — bash 3.2 + BSD coreutils portability (C-23); the audit uses `grep`/`awk`/`sed` token scanning robust to nested provenance braces.

## Consequences

### Positive

- The EO layer is now **enforced**, not just documented — non-exemptibility and the two-phase attestation are verified in CI.
- **Content-agnostic:** zero behavior change until the plugin's EO rules land via a pin bump; no false gate failures in the interim.
- **No new mechanism, no plugin edits** — reuses ADR-0037 machinery; the contract surface is the only coupling point (prime directive honored).
- **Additive (ADR-0047):** the spine only ADDS checks; `green` remains the conjunction of base standards AND the EO layer.

### Negative

- A future pin bump that introduces EO rules will immediately make the spine bite; tickets emitted before that bump that omit the (then-active) EO subset would fail the audit. This is the intended teeth, not a regression.

### Neutral

- `schema_version` stays `"1"` (tolerant-reader additive field).
- TIER-0 corpus, prime directive, founder-directives, §1 provenance untouched (D-6 honored); no `claude-tdd-pro` path modified; plugin pin `bba77df` unchanged.

## Verification (executed before commit)

- `tests/test-audit-eo-governance.sh` — 10/10 passing (vacuous pass, non-exemptibility violation, two-phase attestation present/missing/null, fail-closed default, nested-brace id extraction, `EO_NAMESPACES` override).
- `tests/test-all.sh --quiet` — 19/19 suites passing.
- `scripts/audit-eo-governance.sh` against the real registry → vacuous pass (no EO namespace active yet).
- `audit-hook-security` green (new bounded-cleanup `rm` lines added to the baseline with justification); doc-drift, cross-references, standards-conformance, plugin-surface, manifest, metrics, smoke-e2e all green.
- `git diff docs/founder-directives.md` → 0 lines (D-6); plugin pin + `schema_version` unchanged; no `claude-tdd-pro` path modified (prime directive).

## Implementation references

- New: `scripts/audit-eo-governance.sh`, `tests/test-audit-eo-governance.sh`, this ADR.
- Modified: `docs/handoff-contract.md` (non-exemptibility clause + `eo_design_conformance` field), `docs/quality-gate.md` (EO standing requirement), `AGENTS.md` (standing directive mirror), `.grok/templates/decomposition.md` + `.grok/templates/dispatch.md` (always inject EO subset), `.claude/hooks/session-start.sh` (WARN-only wiring), `.github/workflows/test.yml` (hard gate), `tests/hook-security-baseline.txt` (bounded-cleanup baseline entries).
- Related: ADR-0045/0046/0047 (EO layer), ADR-0037 (base registry + machinery), ADR-0026 (structural-promotion precedent), `docs/eo-2026-ai-innovation-security-alignment.md` (design), TICKET-050.
