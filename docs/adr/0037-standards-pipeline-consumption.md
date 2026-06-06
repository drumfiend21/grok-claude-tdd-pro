# ADR-0037 — Standards pipeline consumption: wire the plugin's rubric into the harness (TICKET-032)

- **Status:** Accepted
- **Date:** 2026-06-06
- **Deciders:** drumfiend21 (architect; 2026-06-06 directive: *"when I provide input to the harness of what I want built ... I need it built by the inner-loop according to the engineering rules I've already built (Google, owasp, federal government, etc) ... If it's not working this way now between the two plugins then describe how to make it work. And make it happen now in batches of 15 mins of work."*) + Claude (cloud session, implementer).
- **Second voice (per ADR-0029 pattern; 7th application):** The operator's 2026-06-06 directive itself, which named the gap (the harness was treating the plugin as a 3-SKILL surface while the plugin shipped `standards/`, `rubric/`, `generated-code-quality-standards/`, `pr-corpus/`, `compliance/`, etc.) and demanded immediate closure. The directive IS the second voice; this ADR records the structural fix.
- **Trigger:** Operator-bitten signal fired: the operator explicitly stated that the harness must enforce the rules they programmed into claude-tdd-pro. Prior over-engineering-filter deferrals (where the harness's standards-consumption gap was implicitly accepted because "no app code shipped through the harness yet") are SUPERSEDED.
- **Supersedes:** the implicit deferral of the standards-consumption wire across TICKETS 005, 010, 015, 023, 026, 029, 031. None of those ADRs explicitly named the gap; this ADR names it and closes it.
- **Extends:** ADR-0007 (sync-plugin / plugin-cache contract); ADR-0010 (provenance-bridging — handoff contract); ADR-0022 (PostToolUse review gate); ADR-0028 (substrate-script test discipline); ADR-0032 + 0034 (approval-baseline pattern); ADR-0036 (Claude Code upgrade strategy — symmetric pattern this CL mirrors).

## Context

The harness was originally scoped (TICKET-004 / ADR-0007) to consume only three SKILL.md files from the plugin: `tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`. That contract surface was correct when the plugin was small. The plugin has since grown to **39 top-level surfaces** including a full standards pipeline (`standards/sources.yaml` with 17 declared authoritative sources: Google TS/JS/Python style guides, OWASP ASVS + Top 10, SLSA, WCAG 2.2, Web Vitals, React docs, Next.js docs, TypeScript handbook, Node.js best practices, etc.) and a working rubric (`rubric/aggregator.sh` + `rubric/runner.sh` + per-language detectors).

**None of those new surfaces were wired into the harness.** Until this CL:

- `.claude/hooks/` never invoked `rubric/runner.sh`.
- `.claude/skills/` never symlinked `generated-code-quality-standards/`.
- `docs/quality-gate.md` `lint_clean` sub-gate was contract-only (a pass/fail field with no linter backing).
- The handoff contract had no `applicable_rules` or `rules_verified` field — the wire couldn't exist because the data shape didn't exist.
- `CLAUDE.md` + `AGENTS.md` told both agents to "read the inner-loop SKILL.md" but never named the rule registry as a required pre-flight surface.

The operator's directive made the gap explicit: feature requests submitted to the harness must produce code that conforms to the operator-declared rulesets. The wire had to ship.

## Decision

Ship the end-to-end consumption wire across five sequenced batches (each ~15 minutes per the operator's batching directive):

### Batch 1 — Plugin surface declaration audit

- **`scripts/audit-plugin-surface.sh`** — walks `.harness/plugin-cache/claude-tdd-pro/` top-level and verifies every entry is declared in the consumption registry. Exit 1 on UNKNOWN surfaces.
- **`docs/plugin-surface-consumption.md`** — TIER-2 registry listing all 39 plugin surfaces, classified as CONSUMED (11) or DECLARED-NOT-CONSUMED (28) with rationale. Catches the structural failure mode that motivated this CL: any future plugin pin bump that introduces a new top-level surface fails the audit until acknowledged.
- **`tests/test-audit-plugin-surface.sh`** — 9 assertions including injected-unknown-surface; restore-before-assert.

### Batch 2 — Standards rule registry sync

- **`scripts/standards-sync.sh`** — invokes the plugin's `rubric/aggregator.sh`, persists the unified JSON registry to `.harness/rules/active.json`. Modes: default / `--check` / `--quiet`. Bash 3.2 portable wrapper; no fork of plugin code.
- **`.harness/rules/active.json`** (gitignored) — 28 rules across 9 namespaces (google, node, owasp, react, slsa, typescript, w3c, web-vitals, _community).
- **`tests/test-standards-sync.sh`** — 16 assertions including `--check` freshness contract.
- **`.claude/hooks/session-start.sh`** — extended to call `standards-sync` + the `plugin-surface` audit at session start. WARN-not-FAIL stance preserved.

### Batch 3 — Handoff contract extension + agent bindings

- **`docs/handoff-contract.md`** — `applicable_rules` array added to `.req.json`; `rules_verified` map added to `.res.json`. Field rules document fail-closed semantics (missing field = "all rules apply"; any `fail` forces `red`).
- **`docs/quality-gate.md`** — `lint_clean` sub-gate definition updated to consume `rules_verified` as a first layer above any project-configured linter.
- **`CLAUDE.md`** — new section "Operator-declared standards (TIER 1)" requires Claude to consult `.harness/rules/active.json` at session start.
- **`AGENTS.md §7`** — `standards-sync.sh` named as the second session-start action; both agents required to read `.harness/rules/active.json`.

### Batch 4 — PostToolUse runtime enforcement

- **`.claude/hooks/post-tool-use-review-gate.sh`** — extended to run the plugin's `rubric/runner.sh --diff --severity P0` after every Edit/Write/MultiEdit on app-code file extensions (js/jsx/ts/tsx/py/go/rs/java/kt/swift). Exit 2 on any P0 finding for the touched file. Bash + Markdown substrate excluded (no detectors; pure noise).
- Catches violations BEFORE the test gate runs — strongest enforcement point. Claude cannot continue past a write that broke a P0 rule.

### Batch 5 — Pre-commit conformance audit + deviation registry

- **`docs/deviations.md`** — append-only TIER-2 registry; each row = rule_id, file_scope_glob, justification, ADR_ref, expiry_trigger. Mirrors the `docs/founder-directives.md §1` immutability pattern.
- **`scripts/audit-standards-conformance.sh`** — pre-commit audit; runs `rubric/runner.sh` against the working-tree (or staged) diff; exits 1 on P0 findings without matching deviation rows. Approval-baseline pattern matches ADR-0032 / 0034.
- **`tests/test-audit-standards-conformance.sh`** — 8 assertions.

## Alternatives considered

- **Vendor the rubric into harness substrate.** REJECTED per R-1 (no cross-repo edits) + R-2 (versioned consumption). The harness wraps the plugin's runner; it does not fork it.
- **Wait for federal-government namespace before shipping the wire.** REJECTED. The wire and the source-set additions are independent CLs. Shipping the wire first means federal-government can drop in via a future namespace addition without re-wiring.
- **Make the PostToolUse hook block on ALL severities (P0/P1/P2).** REJECTED. P0 is the named blocking class per the plugin's RUBRIC schema; P1/P2 surface as findings in the response trail without blocking. Aligns with the plugin's own contract.
- **Run the runner on Bash + Markdown substrate too.** REJECTED. The plugin's detectors are language-specific (ESLint, tsc, ruff, mypy, etc.); running them on shell scripts produces pure SKIP noise. The substrate is governed by C-23 (bash 3.2 portability) + `audit-doc-drift.sh` + `audit-hook-security.sh`, not the rubric.
- **Skip the deviations registry; require literal rule fixes.** REJECTED. Real engineering has legitimate exceptions (legacy compat, performance trade-offs). Operator-justified deviation rows with ADR refs + expiry triggers are the right escape valve. The PostToolUse hook fails closed unless a row exists.
- **Defer the plugin-surface audit; ship only the standards wire.** REJECTED. The surface audit is what prevents this gap from recurring. Without it, the next plugin pin bump introducing a new directory would silently re-create the consumption gap.

## Consequences

### Positive

- **Operator-declared standards now enforced end-to-end.** Session-start loads them; handoff contract carries them; PostToolUse blocks violations; pre-commit gates the diff. Four enforcement points, each documented.
- **Plugin surface gap is structurally prevented from recurring.** `scripts/audit-plugin-surface.sh` fails on any new undeclared plugin directory; SessionStart + pre-commit both run it.
- **Symmetric with the plugin-pin discipline** (R-2) and the Claude Code compat discipline (ADR-0036). The harness now manages its three dependencies — plugin, Claude Code, standards — with the same WARN-at-session-start + ADR-gated-bump pattern.
- **No fabrication.** Every rule trace through the wire ends at a real entry in `standards/sources.yaml` and a real detector in `rubric/detectors/`. The harness reports what the plugin produces; it doesn't invent rules.
- **Substrate test coverage extends to 16/16 surfaces** (was 13/13 after ADR-0035): +`test-audit-plugin-surface`, +`test-standards-sync`, +`test-audit-standards-conformance`.
- **7th application of the `Second voice` field per ADR-0029.** The operator's directive is the second voice; this ADR quotes it verbatim.

### Negative

- **Substrate edits trigger the plugin-surface audit on every SessionStart.** Mitigation: the audit takes <0.1s; the WARN-not-FAIL stance means transient cache divergence (between upstream fetch and `--ensure` revert) doesn't block work.
- **The deviations registry must be honored.** Mitigation: pre-commit audit runs it; PR review must check that new deviation rows have ADR refs + expiry triggers. Anti-pattern section in `docs/deviations.md` calls out misuse.
- **The `applicable_rules` field is REQUIRED for app-code tickets** (fail-closed default if missing). Mitigation: Grok dispatch template can be updated to populate it from `active.json` automatically. Until then, missing field = "all rules from active.json apply" — strict but safe.
- **The federal-government namespace is not present in `standards/sources.yaml`.** Mitigation: separate CL (TICKET-033 candidate); requires operator-supplied URLs.

### Neutral

- **D-rules unchanged** (D-1..D-13).
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched** (D-6 honored).
- **R-rule + G-rule + C-rule bodies untouched.**
- **Plugin pin unchanged** (`23e5c2b` per ADR-0025).
- **Wire-format `schema_version` unchanged** — the new fields are additive; missing fields are interpreted as fail-closed defaults.

## Verification (executed before commit)

- `./tests/test-all.sh --quiet` shows 16/16 suites passing (was 13/13; +3 new).
- `./scripts/audit-plugin-surface.sh` exits 0 with 11 CONSUMED + 28 DECLARED + 0 UNKNOWN.
- `./scripts/standards-sync.sh` writes `.harness/rules/active.json` with 28 rules across 9 namespaces.
- `./scripts/standards-sync.sh --check` exits 0 against a fresh registry.
- `./scripts/audit-standards-conformance.sh` + `--staged` both exit 0 against the harness substrate.
- Full audit chain green: audit-doc-drift + smoke-e2e + export-cursor-rules --check + audit-manifest + audit-cross-references + audit-hook-security + audit-metrics + audit-claude-code-compat + audit-plugin-surface + audit-standards-conformance all exit 0.
- `git diff docs/founder-directives.md` returns 0 lines (D-6 honored).
- ADR-0037 follows the numbered ADR template + `Second voice` field present (7th application).
- `CLAUDE.md` + `AGENTS.md` both name `.harness/rules/active.json` as a required pre-flight surface.

## Out of scope (named follow-ons)

- **TICKET-033: Federal Government sources (and other operator-collected URLs).** DEFERRED until operator pastes the URLs. Wire is ready; namespace folder + sources.yaml entries are mechanical when URLs arrive.
- **Grok dispatch template updates** to auto-populate `applicable_rules` from `active.json`. DEFERRED to a follow-on; current fail-closed default ("all rules apply if field absent") is safe.
- **pr-corpus / compliance / monitors consumption.** Plugin surface declared NOT-CONSUMED at v1 per registry. Triggers named in `docs/plugin-surface-consumption.md`.
- **CI integration of `audit-standards-conformance.sh`.** DEFERRED per ADR-0028 §Out-of-scope (trigger: first PR-driven external contribution).
- **LLM-judge dispatch for DEFERRED findings.** The rubric runner emits DEFERRED findings for rules requiring agent review (e.g., `g-eng-001-design-belongs-here`). v1 ignores these; v2 will surface them in the response trail. Trigger: first app-code feature ticket.

## Implementation references

- New: `scripts/audit-plugin-surface.sh` (~95 lines; bash 3.2 + BSD portable)
- New: `scripts/standards-sync.sh` (~95 lines)
- New: `scripts/audit-standards-conformance.sh` (~90 lines)
- New: `tests/test-audit-plugin-surface.sh` (9 assertions)
- New: `tests/test-standards-sync.sh` (16 assertions)
- New: `tests/test-audit-standards-conformance.sh` (8 assertions)
- New: `docs/plugin-surface-consumption.md` (TIER-2 registry; 39 entries)
- New: `docs/deviations.md` (TIER-2 append-only registry; 0 deviations at ship time)
- New: this ADR
- Modified: `.claude/hooks/session-start.sh` (+ standards-sync + plugin-surface audit)
- Modified: `.claude/hooks/post-tool-use-review-gate.sh` (+ rubric runner enforcement for app-code extensions)
- Modified: `docs/handoff-contract.md` (+ `applicable_rules`, + `rules_verified`)
- Modified: `docs/quality-gate.md` (`lint_clean` sub-gate definition)
- Modified: `CLAUDE.md` (new section: Operator-declared standards TIER 1)
- Modified: `AGENTS.md §7` (standards-sync as second session-start action)
- Modified: `.gitignore` (+ `.harness/rules/`)
- Related: ADR-0007 (sync-plugin / R-2), ADR-0010 (handoff contract), ADR-0022 (PostToolUse review gate), ADR-0028 (substrate-script test discipline), ADR-0032 + 0034 (approval-baseline precedent), ADR-0036 (Claude Code upgrade — symmetric pattern), ADR-0029 (`Second voice` field — 7th application).
