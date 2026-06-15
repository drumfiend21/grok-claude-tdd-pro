# ADR-0049 — Authoritative-source citation-integrity gate (widen + deepen the conformance suite)

- **Status:** Accepted
- **Date:** 2026-06-15
- **Deciders:** drumfiend21 (architect; 2026-06-15 directive: *"Widen and Deepen all tests to ensure that all architecture, design and coding done by the plugin, fullstack and cloud, conforms to cited rules from all authoritative sources."*) + Claude (cloud session, designer).
- **Second voice (per ADR-0029 pattern; 18th application):** The operator's "conforms to cited rules from all authoritative sources" directive is the second voice — it asserts that conformance must be *traceable to a cited source*, not merely asserted, and that *all* authoritative sources (fullstack and cloud) are in scope.
- **Trigger:** The conformance suite verified behavior (rubric-runner findings, rulebook-citation counts, EO non-exemptibility) but nothing verified that the rule corpus the harness enforces is itself fully cited and structurally intact — and the TIER-0 supreme corpus appeared in no coverage audit at all.
- **Extends:** ADR-0031 (rulebook-coverage audit), ADR-0037 (operator-declared-standards regime + `active.json`), ADR-0045/0046/0047/0048 (EO governance layer; additivity). Composes on the architecture R-rules, founder-directives D-rules, the TIER-0 corpus, and the TDD/C-rule discipline. Supersedes nothing — additive (Nygard append-only).

## Context

The repo enforces rules from several authoritative-source tiers:

- **TIER-0 corpus** (`docs/ai-engineering-corpus.md`) — supreme operating directive.
- **Internal rulebooks** — founder-directives D-rules, architecture R-rules, Grok G-rules, Claude TDD Pro C-rules.
- **Operator-declared standards** (`.harness/rules/active.json`, ADR-0037) — 28 rules across `google`, `node`, `owasp`, `react`, `slsa`, `typescript`, `w3c`, `web-vitals`, `_community`; each rule carries a `provenance[]` citing an authoritative source (Google style guides, OWASP ASVS, SLSA, WCAG 2.2, Web Vitals, React/Next.js, Node.js, TypeScript handbook).
- **EO-2026 governance layer** (ADR-0045..0048).

Existing conformance audits and the gap each leaves:

- `audit-rulebook-coverage.sh` — counts D/R/G/C citations, but **excludes the TIER-0 corpus** and the operator-declared standards.
- `audit-standards-conformance.sh` — runs the rubric runner against the diff for P0 findings, but assumes the registry is well-formed; it does not verify the registry's **citation integrity** or **namespace breadth**.
- `audit-eo-governance.sh` — verifies EO non-exemptibility + two-phase attestation only.

So nothing verified two things the operator's directive requires: (1) that **every enforced rule traces to a cited authoritative source** (no uncited rule, no dropped source category — fullstack *and* cloud), and (2) that the **TIER-0 supreme corpus** (and every other authoritative-source doc named in `CLAUDE.md`) exists and is operationally wired.

## Decision

Add **`scripts/audit-source-citations.sh`** — a citation-integrity gate with two halves, wired WARN-only at session start and as a hard gate in CI, alongside a thorough substrate test (`tests/test-source-citations.sh`).

**PART A — operator-standards citation integrity** (over `.harness/rules/active.json`):

- **A1.** Every enforced rule carries a non-empty `provenance[]` (a cited source). An uncited enforced rule fails.
- **A2.** No `provenance` entry names an empty `source`.
- **A3.** Every namespace in `namespaces_seen` has ≥1 rule, unless allow-listed empty (default: `_community`). Catches a silent category drop on a plugin pin bump.
- **A4.** The canonical authoritative-source set is intact — fullstack (`react`, `typescript`, `node`, `web-vitals`, `w3c`) **and** cloud/security (`owasp`, `slsa`) namespaces each present + non-empty.
- **A5.** *(Informational, non-blocking.)* Compliance-`controls[]` coverage among security-namespace P0 rules is surfaced, not gated — a plugin-owned gap (e.g. `g-node-010` lacks `controls`) is made visible without the harness failing on content it does not own (prime directive).

**PART B — authoritative-source doc integrity** (the `CLAUDE.md` source-doc set, **including the TIER-0 corpus**):

- **B1.** Each named source doc exists.
- **B2.** Each is cross-referenced ≥1 time from an operational surface.

The gate is **additive** (ADR-0047) — it only ADDS checks; it relaxes nothing. It is **content-agnostic on rule semantics** (owned by `claude-tdd-pro` per the prime directive): it verifies the *citation spine*, not what a rule means. Existing test suites are deepened in the same CL (EO governance: green-only-bite + `deviated`-tolerance edge cases; standards-conformance: registry breadth + namespace-coverage assertions).

## Alternatives considered

- **Extend `audit-rulebook-coverage.sh` to fold in the corpus + standards.** REJECTED — that audit is a per-numbered-rule *citation counter*; the corpus has no numbered rules and the registry is JSON. Conflating two parsing models in one script hurts clarity. Separate, single-purpose gate (R-1 cohesion).
- **Make A5 (security-rule `controls[]`) a hard gate.** REJECTED — `g-node-010` (slsa, P0) legitimately lacks `controls` and that content is plugin-owned; a hard gate would fail CI on content the harness cannot fix without violating the prime directive. Surfaced as informational (honest-reporting ethos; matches the rulebook-coverage "zero-citation candidate" pattern).
- **Parse `active.json` with `jq`/`node`.** REJECTED — C-23 bash 3.2 + BSD portability; no external dependency. Single-line registry is split on the `{"id":"` rule-start token (never appears inside a nested object) for the per-rule walk.
- **Leave verification implicit.** REJECTED — the operator asked for traceability to *cited* sources across *all* authoritative sources; an explicit, tested gate is the only durable guarantee.

## Consequences

### Positive

- **Every enforced rule now provably traces to a cited authoritative source** — fullstack and cloud — and a dropped source category fails CI.
- **The TIER-0 supreme corpus is, for the first time, covered by a conformance gate** (21 operational citations verified).
- **Deeper existing suites** — EO governance + standards-conformance gain edge-case + breadth coverage.
- **18th application of the `Second voice` field.**

### Negative

- **One more audit in the chain.** Mitigated: pure-bash, sub-second, no external deps.

### Neutral

- **No mechanism change to enforcement**; rides the existing `active.json` registry + session-start/CI audit pattern.
- **TIER-0 corpus, prime directive, founder-directives, §1 provenance untouched** (D-6 honored — 0 diff).
- **No `claude-tdd-pro` path touched** (prime directive); plugin pin `bba77df` + `schema_version` unchanged.

## Verification (executed before commit)

- `scripts/audit-source-citations.sh` exits 0 on the real registry + docs (28/28 rules cited; all 8 required namespaces present; TIER-0 corpus wired).
- `tests/test-source-citations.sh` — 17/17 (both halves; A1–A5 + B1–B2 + real-state + corpus-coverage assertions).
- `tests/test-all.sh` — 20/20 suites.
- Full audit chain green (doc-drift, cross-references, hook-security, plugin-surface, standards-conformance, eo-governance, source-citations, rulebook-coverage, metrics).
- `git diff docs/founder-directives.md` → 0 lines (D-6); no `claude-tdd-pro` path modified; pin + `schema_version` unchanged.

## Implementation references

- New: `scripts/audit-source-citations.sh`, `tests/test-source-citations.sh`
- Modified: `.claude/hooks/session-start.sh` (WARN-only wire), `.github/workflows/test.yml` (hard gate), `tests/test-audit-eo-governance.sh` + `tests/test-audit-standards-conformance.sh` (deepened), `tests/hook-security-baseline.txt` (2 justified `mktemp $TMP` cleanup entries), `tests/README.md` (coverage table), `TICKETS.md` (TICKET-051)
- New: this ADR
- Related: ADR-0031 (rulebook-coverage), ADR-0037 (standards regime), ADR-0045..0048 (EO governance), ADR-0029 (`Second voice` — 18th application), `docs/ai-engineering-corpus.md` (TIER-0)
