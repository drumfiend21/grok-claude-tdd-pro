# ADR-0059 — `app_root`: a first-class external application-working-tree model ("Fix D")

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect) + Claude (cloud session). Part of the GCTP-side response to the O'Reilly Software Architect AI Kata enforcement-gap finding (PROPOSAL-002); the CTP side (Fix E/F/G) landed and was adopted at pin `eb7b2af` (ADR-0058).
- **Trigger:** the kata build showed the harness has no first-class notion that the user's product lives in a **separate working tree** that must be enforced. `/consult` `/decompose` `/inner-loop` `/audit` operate on `.harness/*`; the app itself (e.g. `softarchcert-win25`, a sibling repo) was enforced only ad hoc. Fixes A–C (decompose-union, inner-loop enforcement, dynamic gate) have nowhere to point without this model — so it lands first.
- **Scope:** harness self-maintenance (the harness's own spine), per the agent-operating-compact's scope boundary — not application architecture built through GCTP. Runs on the ADR + TDD plane.

## Context

CTP's `enforce.sh` (Fix E, adopted in ADR-0058) takes `--root <app-dir>` and enforces standards against an **external** tree. GCTP needs a single, well-defined place its commands + enforcement scripts learn *where that tree is* — and a guard so the harness never "enforces" an absent or empty tree and reports green (the vacuous-green failure mode the whole effort targets, one layer up from `enforce.sh`'s own `not_applicable`-vs-`pass` fix).

## Decision

Introduce **`app_root`**, an operator-local pointer to the external application working tree, resolved by a single script.

**D-A. Config:** `.harness/app.json` (operator-local, **gitignored**), shape
`{ "schema_version": "1", "app_root": "<path>", "description": "..." }`. A tracked
`.harness/app.json.example` documents the shape. The value is environment-specific (it points at wherever the operator's product lives), so it is local, not committed — same posture as `.harness/agent-compact-ack.json`'s operator-local record.

**D-B. Resolver:** `scripts/app-root.sh` is the single resolution + validation surface.
- `app-root.sh` → exit `0` (configured + exists + non-empty; absolute path on stdout) / `1` (unconfigured: no `app.json` or no `app_root` key) / `2` (configured but the tree is **missing or empty** → refused; also bad invocation).
- `app-root.sh --validate <dir>` validates an explicit dir (for tests + Fix B/C) → `0` / `2`.
- Relative `app_root` resolves against the repo root; **absolute** is honored; the app tree need **not** be a git repo (enforcement is git-agnostic — a requirement of the `enforce.sh` contract).

**D-C. Hard guard (the anti-vacuous-green invariant):** a configured app_root that does not exist, or holds **zero regular files** (outside `.git`), is exit `2` — REFUSED. "Nothing to enforce" is a configuration error, never a green. This is the consumer-side mirror of `enforce.sh`'s `not_applicable`: GCTP refuses to *call* enforcement on an empty tree just as `enforce.sh` refuses to count an unevaluated rule as a pass.

**D-D. Consumers:** documented in `docs/handoff-contract.md §App-Root`. `/consult` `/decompose` `/inner-loop` `/audit` resolve through the script; `file_scope.may_edit` globs are app_root-relative; the forthcoming Fix-B `enforce-standards.sh` and Fix-C dynamic gate target it as `enforce.sh --root "$app_root"`.

## Alternatives considered

- **A per-feature field in the consult artifact instead of a standalone config.** REJECTED as the primary home — the app_root is environment-level (one product per harness checkout), not per-feature; a single resolver is simpler and all four commands share it. (A future per-feature override could layer on without breaking this.)
- **Commit `.harness/app.json`.** REJECTED — the path is environment-specific; committing it would bake one operator's layout into the repo. The tracked `.example` documents the shape instead.
- **Treat an empty/missing app_root as "nothing to do" (exit 0).** REJECTED — that *is* the vacuous-green disease. Fail-closed (exit 2) is the whole point of Fix D.
- **Require the app tree to be a git repo (scope via `git ls-files`).** REJECTED — `enforce.sh` is git-agnostic; a freshly-scaffolded app may not be a repo yet. File-count via `find` works for both.

## Consequences

### Positive
- Fixes A–C now have a single, guarded target. The vacuous-green vector ("enforced an empty tree → green") is closed at the consumer boundary.
- Git-agnostic + relative/absolute paths → works for sibling repos, subfolders, and fresh scaffolds alike.

### Neutral
- No `claude-tdd-pro` path touched (prime directive). No wire-format (`schema_version`) change — `app.json` is a new local config, not a handoff schema change. D-6 honored.

### Negative / cost
- One more operator setup step (create `.harness/app.json`). Mitigated by the `.example` + the resolver's explicit "create it: …" message on exit 1.

## Verification (this CL)
- `tests/test-app-root.sh` — 14 assertions (exit 0/1/2; relative + absolute; missing + empty refuse; no-key; invalid JSON; `--validate`; `.git`-only tree refused). Green.
- Full audit chain green; `tests/test-all.sh` all suites; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path touched.

## Implementation references
- New: this ADR; `scripts/app-root.sh`; `.harness/app.json.example`; `tests/test-app-root.sh`
- Modified: `.gitignore` (`.harness/app.json`), `docs/handoff-contract.md` (§App-Root), `.claude/commands/inner-loop.md` + `decompose.md` (app_root pointers), `tests/README.md` (coverage), `tests/hook-security-baseline.txt` (test `rm` lines), `TICKETS.md` (TICKET-070)
- Enables: Fix A (decompose-union), Fix B (`enforce-standards.sh`), Fix C (dynamic gate)
- Related: ADR-0058 (pin bump adopting `enforce.sh`), `proposals/PROPOSAL-002-app-enforcement-spine.md`
