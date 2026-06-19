# ADR-0060 — Fix A: `/decompose` unions the ruleset; `applicable_rules` under-scoping is a static RED

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect) + Claude (cloud session). GCTP-side of the O'Reilly-kata enforcement-gap loop (PROPOSAL-002); composes on the pin-bump (ADR-0058) + the `app_root` model (ADR-0059).
- **Trigger:** the kata's root failure — every code ticket carried only `g-node-001`/`g-node-008`; the full language ruleset was never scoped, so detectors that were never named were never run. The decompose template *said* "filter by language" in prose, but nothing enforced it, and the consult-artifact path took `applicable_rules` verbatim from `decisions[]`, silently dropping the language filter and (now) the apply-by-default universal rules.
- **Scope:** harness self-maintenance (decompose template + commands + a new gate), per the agent-operating-compact's scope boundary. Runs on the ADR + TDD plane.

## Context

CTP's `enforce.sh` (ADR-0058) only enforces the rules a ticket *names* in `applicable_rules`. So scoping IS enforcement coverage: an under-scoped ticket is unenforced no matter how good the detectors are. Two things changed the calculus since the kata:

1. **Universal coverage (CTP §28.21):** `g-universal-*` rules apply to all generated software **by default**; omitting them is the new under-scoping.
2. **`enforce.sh` `not_applicable` (ADR-0058):** a rule that matches no files in the app tree is `not_applicable` (neutral), **not** a fail. So **over-scoping is now safe** — a generous union never produces a false fail. This removes the only reason to scope narrowly.

## Decision

**D-A. `/decompose` produces a union.** Each ticket's `applicable_rules` =
`language-filtered(active.json, file_scope.may_edit)` ∪ `every g-universal-*` ∪ `every EO rule` ∪ `consult/static-context rules`. The decompose template + `.claude`/`.cursor` commands are updated to say so, to prefer **typed globs** (`…/**/*.ts`) so the language floor is machine-checkable, and to state that over-scoping is safe.

**D-B. A static gate makes under-scoping RED — `scripts/audit-applicable-rules.sh`.** For every `.harness/handoffs/*.req.json` carrying `applicable_rules`, computed live from `active.json` (content-agnostic — new catalog rules are picked up automatically):
- **Universal floor:** every `g-universal-*` id MUST be present (apply-by-default).
- **Language floor:** for each `file_scope.may_edit` glob with an explicit extension, the rule-id prefixes that language implies MUST be fully present (`.ts`→`g-ts-*`+`g-node-*`; `.tsx/.jsx`→…+`g-react-*`; `.md`→`g-doc-*`; `.tf`→`g-hashicorp-*`; `.yaml`→`g-linux-foundation-*`). Extensionless directory globs imply no language and are not gated (use typed globs to get the floor).

Vacuous when no request carries `applicable_rules` or `active.json` is absent. EO non-exemptibility stays with `audit-eo-governance.sh` (this gate is the universal + language dimension of the same union). Wired WARN-not-FAIL at session start; the pre-commit chain + CI are the hard gate.

**D-C. The smoke example models it.** `scripts/smoke-e2e.sh` now computes its stub request's `applicable_rules` live from `active.json` (every `g-universal-*` + the EO rules; EO-only fallback when the registry is absent, e.g. CI) and mirrors them into the response's `rules_verified` (`req ⊆ res` holds). The stub uses directory-glob `file_scope` because it cannot run language detectors — real per-language verdicts arrive with Fix B. The stub marking these `pass` is a wire-level attestation for a toy with no secret/debug/provenance surface, explicitly replaced by real `enforce.sh` verdicts in Fix B (ADR-0008 live-deferral).

## Alternatives considered

- **Prose-only (keep the template instruction, no gate).** REJECTED — that is exactly what failed in the kata; prose without a machine check silently drifted.
- **Infer language from the app tree's actual files rather than glob extensions.** REJECTED for this gate — it would couple the static scoping check to a materialized `app_root`; the typed-glob floor is checkable from the request alone. (Fix C re-runs detectors against the real tree; that is where file-level truth is verified.)
- **Hard-require cloud provider namespaces (`g-aws-*`) for `.tf`.** REJECTED — the provider is not inferable from the extension; `.tf` requires only the provider-agnostic `g-hashicorp-*` floor, with the provider rules staying consult/prose-driven. (Over-scoping a provider is safe via `not_applicable`, but mandating the wrong provider would be a false RED.)
- **Make under-scoping a hard fail at session start.** REJECTED — consistent with the other handoff gates (`eo-governance`, `rules-verified`), session start is WARN; CI + pre-commit are the hard gate.

## Consequences

### Positive
- The kata's headline failure (TS scoped to two rules) is now a static RED: a `.ts` ticket missing `g-ts-*`/`g-node-*` fails the gate.
- Universal apply-by-default is mechanically guaranteed on every ticket; it auto-tracks the catalog as CTP grows it (no rework — D-B reads `active.json` live).

### Neutral
- No `claude-tdd-pro` path touched (prime directive). No `schema_version` change (the handoff shape is unchanged; this gates an existing field). D-6 honored.

### Negative / cost
- Slightly more rules per ticket. Cost is near-zero at enforcement time: `enforce.sh` returns `not_applicable` for rules that do not pertain, so over-scoping does not produce false fails.

## Verification (this CL)
- `tests/test-audit-applicable-rules.sh` — 14 assertions (universal floor; the `.ts` under-scope regression; `.tsx`→react; `.md`→doc; `.tf`→hashicorp; typed-glob floor; vacuous on no-reqs / missing registry; not-gated when no `applicable_rules`; malformed JSON; multi-req). Green.
- `smoke-e2e` green with the dynamic union; `audit-applicable-rules` + `audit-eo-governance` + `audit-rules-verified` all agree on the regenerated `TICKET-042` handoff.
- Full audit chain green; `tests/test-all.sh` all suites; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path touched.

## Implementation references
- New: this ADR; `scripts/audit-applicable-rules.sh`; `tests/test-audit-applicable-rules.sh`
- Modified: `.grok/templates/decomposition.md` + `.claude/commands/decompose.md` + `.cursor/commands/decompose.md` (union instruction + typed-glob preference), `scripts/smoke-e2e.sh` (dynamic apply-by-default union, req↔res mirror), `.claude/hooks/session-start.sh` (WARN gate), `.claude/commands/audit.md` + `.github/workflows/test.yml` (hard gate), `tests/README.md`, `tests/hook-security-baseline.txt`, `TICKETS.md` (TICKET-071)
- Enables: Fix B (`enforce-standards.sh` runs the scoped rules), Fix C (dynamic re-run gate)
- Related: ADR-0058 (pin bump / `enforce.sh`), ADR-0059 (`app_root`), `proposals/PROPOSAL-002-app-enforcement-spine.md`
