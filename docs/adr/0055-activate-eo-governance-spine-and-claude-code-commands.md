# ADR-0055 — Activate the EO governance spine against `security-governance`; add Claude Code command surface

- **Status:** Accepted
- **Date:** 2026-06-16
- **Deciders:** drumfiend21 (architect; 2026-06-16 directive: *"Proceed to complete the architecture that I have specified and to get this plugin ready for testing again in a new claude code chat and in an empty folder"*) + Claude (cloud session).
- **Trigger:** Two things became true at pin `6d2fe13`: (1) CTP now ships EO authorities (CISA SSDF/KEV, NIST AI RMF, SLSA) as **enforced detector rules** under `security-governance` — so the EO governance spine (ADR-0045/0046, built content-agnostic and "armed-but-vacuous") finally has live rules to bind to; (2) a fresh-Claude-Code-chat install test (TICKET-058) showed GCTP surfaces **no slash commands** in Claude Code because `.claude/commands/` was empty.
- **Extends:** ADR-0045 (EO always-on / non-exemptible), ADR-0046 (two-phase), ADR-0049/0051 (citation gate), ADR-0054 (pin `6d2fe13`). Additive — supersedes nothing.

## Context

The EO governance architecture the operator specified is "always-on, non-exemptible, two-phase, additive." It was enforced by `scripts/audit-eo-governance.sh`, but keyed on `source_namespace: eo` — a name CTP never used. CTP instead enforces the EO authorities under `security-governance` (2 rules at this pin: `require-provenance` P1, `no-known-exploited-ingress` P0). So the spine sat vacuous despite the rules existing.

Separately, GCTP's operator slash commands lived only in `.cursor/commands/`; a plain Claude Code chat got the 3 `tdd-pro-*` skills + hooks but no commands — so the "test it in a new Claude Code chat" path had nothing to type.

## Decision

**1. Activate the EO spine.** `audit-eo-governance.sh` default `EO_NAMESPACES` is now `eo security-governance` (was `eo`). The spine is live: every present request's `applicable_rules` must include the active EO rules (or rely on the fail-closed absent-default), and every green response must carry a non-empty `eo_design_conformance` (two-phase).

- The harness's own e2e is made EO-compliant: `scripts/smoke-e2e.sh` now emits `applicable_rules` carrying the 2 `security-governance` rules and an `eo_design_conformance` attestation in the response (the toy has no provenance/ingress surface, so the rules are attested not-applicable at the design phase — attested, not skipped).
- The outer-loop templates (`decomposition.md`, `dispatch.md`) now require every EO-governance rule (`source_namespace: eo` OR `security-governance`) in `applicable_rules`.
- A regression test asserts the **default** namespace set recognizes `security-governance` (`tests/test-audit-eo-governance.sh`, 13 tests).

**2. Add the Claude Code command surface.** Ship `.claude/commands/{research,decompose,dispatch,inner-loop,sync,smoke,audit}.md` mirroring `.cursor/commands/`, so GCTP's 7 operator commands surface in a fresh Claude Code chat. They delegate to the same templates/scripts/skills; the EO non-exemptibility note is carried into `decompose`/`dispatch`/`inner-loop`.

## Alternatives considered

- **Rename CTP's namespace to `eo`.** REJECTED — CTP-side, prime-directive forbidden; and `security-governance` is the accurate name for the CISA/NIST/SLSA corpus.
- **Leave the spine vacuous (key only on `eo`).** REJECTED — it would never fire; the operator asked to *complete* the architecture, and the rules now exist.
- **Block green on the toy smoke instead of attesting.** REJECTED — the toy genuinely has no EO surface; the two-phase design is "considered + attested," which `eo_design_conformance` expresses honestly.
- **Generate `.claude/commands/` from `.cursor/commands/`.** Deferred — `.cursor/commands/` are hand-authored (not generated); hand-authoring the Claude mirror is consistent. A parity generator can come later if drift appears.

## Consequences

### Positive
- The EO governance layer is **live**: provenance + known-exploited-ingress are non-exemptible and two-phase-attested on every ticket, enforced by a green-gating audit.
- A fresh Claude Code chat now has GCTP's 7 slash commands — the install test can proceed in Claude Code, not only Cursor.

### Negative
- The bar is strictly higher: every green response must now carry `eo_design_conformance`. Intended; the smoke demonstrates the compliant shape.

### Neutral
- No `claude-tdd-pro` path edited (prime directive). `EO_NAMESPACES` stays env-overridable. D-6 honored.

## Verification (executed before commit)

- `audit-eo-governance.sh` → green; recognizes the 2 `security-governance` rules; smoke handoff compliant (req carries them, res attests).
- `tests/test-audit-eo-governance.sh` 13/13 (incl. the default-recognizes-`security-governance` guard); `tests/test-all.sh` 22/22; full audit chain green; smoke green.
- `.claude/commands/` (7) resolve all referenced paths (cross-references clean).
- `git diff docs/founder-directives.md` → 0 (D-6); no `claude-tdd-pro` path modified.

## Implementation references

- Modified: `scripts/audit-eo-governance.sh` (default `EO_NAMESPACES`), `scripts/smoke-e2e.sh` (EO-compliant handoff), `.grok/templates/{decomposition,dispatch}.md`, `tests/test-audit-eo-governance.sh` (+guard), `tests/hook-security-baseline.txt`, `docs/eo-2026-ai-innovation-security-alignment.md` + `CLAUDE.md` + `docs/quality-gate.md` + `docs/handoff-contract.md` (namespace note), `docs/first-time-guide.md` + `README.md` (Claude Code commands), `TICKETS.md` (TICKET-060/061)
- New: this ADR, `.claude/commands/*.md` (7)
- Related: ADR-0045/0046 (EO spine design), ADR-0054 (pin that made the rules live)
