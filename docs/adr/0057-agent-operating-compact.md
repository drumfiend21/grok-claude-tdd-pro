# ADR-0057 — Agent operating compact (fail-closed behavioral binding on the GCTP driver)

- **Status:** Accepted
- **Date:** 2026-06-18
- **Deciders:** drumfiend21 (architect; 2026-06-18 directive: *"I'd like this commitment from Claude Code persisted in the GCTP repo and presented to the user of GCTP, prompting their agreement, and enforced on Claude Code every time the plugin is installed and used"*) + Claude (cloud session, who authored the affirmed commitment + the honest caveat).
- **Second voice (ADR-0029 pattern; 21st application):** the operator's insistence that the binding be *"enforced on Claude Code every time the plugin is installed and used"* — not merely documented — is the second voice. It asserts that a behavioral commitment without a fail-closed gate is theatre; the compact must have teeth.
- **Composes on:** ADR-0056 (the GCTP↔CTP consult loop this compact protects), the prime directive (`CLAUDE.md` plugin-dependency model, invariant 3 — contract-only coupling), ADR-0037 (the standards enforcement-spine pattern this audit mirrors), and ADR-0001 (whose warn-only session-start policy this ADR carves a deliberate, scoped exception from).

## Context

GCTP is the **crossroads/translator** between CTP (`claude-tdd-pro`, the standards-enforced architecture engine) and a (often non-technical) user (ADR-0056). The harness's entire value proposition is **generation under enforcement**: architecture is produced by CTP's engine and independently cross-checked by GCTP's governance — not authored from an agent's memory and then rubber-stamped by the gates.

But GCTP is not a separate brain. It is command-prompts + shell scripts that *an agent* (Claude Code first) executes. That agent can silently **short-circuit the loop** — reach for its own prior knowledge, hand-frame architectural decisions, hand-write artifacts — and thereby substitute its own cognition for CTP's grounded output, converting "a guided experience of world-class software engineering" into "one model's guess wearing the harness as a costume." Nothing in the repo, before this CL, *bound* the agent against that short-circuit or made the binding enforceable.

In the originating session the agent (Claude) affirmed a four-point commitment (act only as GCTP's user; do not self-architect; no direct line to CTP; nothing un-generated enters the app repo) **and** an honest caveat (translation under `/consult` is irreducibly agent cognition; there is no zero-intelligence GCTP). The operator directed that this commitment be persisted, presented to the user for agreement, and enforced fail-closed on every install + use.

## Decision

Adopt `docs/agent-operating-compact.md` as a **TIER-1 behavioral binding** on whatever agent drives GCTP, enforced fail-closed.

**D-A. The compact is a tracked document, not a memory.** `docs/agent-operating-compact.md` carries the four commitments, the honest caveat, the scope boundary, the acceptance + enforcement mechanics, and the amendment rule. It is mirrored as a binding into `CLAUDE.md` (Claude Code) and `AGENTS.md` (other agents).

**D-B. Acceptance is an explicit, hash-keyed operator act.** `scripts/accept-compact.sh` writes `.harness/agent-compact-ack.json` with `accepted: true`, operator identity, UTC timestamp, and `compact_sha256` = SHA-256 of the compact's bytes. The hash key means **any** amendment to the compact invalidates the prior acceptance — re-acceptance surfaces the amended terms. "Prompted on installation" generalizes to "prompted on change."

**D-C. Enforcement is three-layered, fail-closed, and honest about its limits.**
1. *Binding teeth (the agent):* until a current acceptance exists, the agent MUST NOT drive `/consult`..`/inner-loop` for the user's product — only read docs + run the accept script (mirrored in `CLAUDE.md`/`AGENTS.md`).
2. *Presentation teeth (every install):* `.claude/hooks/session-start.sh` runs the audit; absent/stale ⇒ a STOP banner presenting the compact + the accept command; current ⇒ one OK line.
3. *Machine teeth (audit chain + CI):* `scripts/audit-agent-compact.sh` fails-closed (exit 1) if the compact is missing, not wired into both binding surfaces, or unaccepted/stale. It is in the pre-commit chain (`.claude/commands/audit.md`) and CI (`.github/workflows/test.yml`).

The honesty: a SessionStart hook cannot hard-halt a session, and you cannot accept the compact in a dead session, so layer 2 surfaces but does not kill. The genuine teeth are layer 1 (the agent honoring the binding — irreducible because translation is cognitive) + layer 3 (the machine gate over artifacts + wiring). The compact states this rather than overclaiming a watertight sandbox.

**D-D. Scope boundary is part of the decision.** The compact governs **application architecture built through GCTP for the user**. It explicitly does NOT govern **harness self-maintenance** (editing GCTP's own docs/scripts/governance — including authoring *this* ADR and *this* compact), which runs on the ADR + founder-directives + R/G/C-rule + per-CL TDD plane under operator review. Conflating the two — in either direction — is itself a compact violation. Without this boundary the compact would forbid its own construction (you cannot build the consult loop *through* the consult loop).

**D-E. Deliberate ADR-0001 exception.** ADR-0001 makes session-start warn-only because plugin-pin *drift* is informational. Compact acceptance is not informational — it is a gate. This ADR scopes a narrow exception: the compact sub-gate is fail-closed at the machine layer (CI/pre-commit) and STOP-bannered (not warn-only) at session start. ADR-0001's policy is otherwise untouched.

## Alternatives considered

- **Document the commitment in CLAUDE.md prose only (no gate).** REJECTED — the operator's second voice: a binding without teeth is theatre; "enforced every time installed and used" demands a machine gate.
- **Hard-block the session on non-acceptance (non-zero SessionStart exit).** REJECTED — a SessionStart hook cannot reliably hard-halt, and a dead session cannot run `accept-compact.sh`. Fail-closed is realized at the audit/CI layer + the agent binding; session-start presents loudly but stays exit 0.
- **Key acceptance to operator identity instead of content hash.** REJECTED for the primary key — the operator asked for "prompted on installation," and a content-hash key cleanly captures "a changed compact is a fresh install." Identity is recorded for provenance but the gate keys on the hash.
- **Fold the compact into the EO governance lens.** REJECTED — different concern (behavioral binding vs. EO standards conformance) and different lifecycle (always-present + accepted vs. content-agnostic/vacuous). Separate lens, same enforcement-spine pattern.
- **Omit the honest caveat (claim GCTP needs zero agent reasoning).** REJECTED — false. The compact and this ADR state the irreducible-cognition limit plainly; overclaiming would itself violate the corpus's honesty posture.

## Consequences

### Positive
- The agent's role is now explicit, accepted, and enforced: it may not architect the user's product from its own head; CTP generates, GCTP cross-checks, the agent translates + drives.
- Fail-closed at the machine layer; any compact amendment forces re-acceptance.
- Honest about what is and isn't machine-enforceable — no security theatre.

### Negative / cost
- A real gate the operator must satisfy (accept once per compact version) or CI/pre-commit goes red. Mitigated: one command, recorded as a tracked artifact.
- Layer-1 enforcement depends on the agent honoring the binding (irreducible — translation is cognitive). The compact does not pretend otherwise.

### Neutral
- No `claude-tdd-pro` path edited (prime directive); the compact governs the *agent*, not the plugin. D-6 honored (`docs/founder-directives.md` untouched). No `schema_version` bump (new artifacts, not a wire-format change).

## Verification (this CL)
- `tests/test-audit-agent-compact.sh` — 17 assertions (audit exit 0/1/2 across present/wired/accepted/stale/missing/invalid; accept round-trip; amendment-invalidates-acceptance). Green.
- `scripts/audit-agent-compact.sh` green against the real tree (compact present, wired into CLAUDE.md + AGENTS.md, accepted at `.harness/agent-compact-ack.json`).
- Full audit chain green; `tests/test-all.sh` all suites pass; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path touched.

## Implementation references

- New: this ADR; `docs/agent-operating-compact.md`; `scripts/accept-compact.sh`; `scripts/audit-agent-compact.sh`; `tests/test-audit-agent-compact.sh`; `.harness/agent-compact-ack.json` (seed acceptance).
- Wired: `CLAUDE.md` (§Agent operating compact), `AGENTS.md` (§5 TIER-1 enumeration), `.claude/hooks/session-start.sh` (STOP-banner gate), `.claude/commands/audit.md` (chain), `.github/workflows/test.yml` (CI step), `tests/README.md` (coverage table), `tests/hook-security-baseline.txt` (test `rm` lines), `TICKETS.md` (TICKET-068).
- Related: ADR-0056 (consult loop), ADR-0037 (enforcement-spine pattern), ADR-0001 (warn-only policy, scoped exception here), the prime directive (`CLAUDE.md`).
