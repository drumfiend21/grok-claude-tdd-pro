# ADR-0058 — Plugin pin bump `6d2fe13` → `eb7b2af` (adopt Fix E/F/G + the universal-coverage foundation from GCTP's kata feedback)

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** drumfiend21 (architect) + Claude (cloud session). Cross-repo loop: GCTP's O'Reilly Software Architect AI Kata test build (`softarchcert-win25`) surfaced that only IaC was *actually* enforced by CTP detectors — TS code-rules were under-scoped and never re-run (asserted, not enforced). GCTP delivered four corrections invisible from inside CTP; CTP implemented them in CL-477..481; this ADR adopts them.
- **Trigger:** CTP `main` advanced five commits `6d2fe13 → eb7b2af` (§28.17–§28.21), landing the **entire CTP-side scope** of the enforcement-spine repair: Fix E (external-tree enforcement entrypoint), Fix G (no-any comment false-positive), Fix F (prose detectors), and the universal-coverage foundation.
- **Continues:** the ADR-0025 → 0041 → 0052 → 0053 → 0054 pin chain.
- **Process:** §15-gated pin bump (`architecture-v1.9.md` contract hash changed); lockfile updated by hand under this ADR.

## Compatibility verdict (verified `6d2fe13 → eb7b2af`)

| Check | Result |
|---|---|
| Span size | **5 commits** (CL-477..481) |
| CTP's `architecture-v1.9.md` | **+51 / −0** (the §28.17–§28.21 governance notes; Nygard append-only) |
| `CLAUDE.md` + the 3 consumed skills | **unchanged** (sha256 identical — verified file-by-file) |
| Files deleted / commands removed | **0** (purely additive) |
| New top-level surfaces | **none** (`audit-plugin-surface` 56 → 56; new content lives under the already-declared `rubric/` + `generated-code-quality-standards/`) |
| Rubric rules `active.json` | **42 → 46** (+`g-universal-no-hardcoded-secrets`, +`g-universal-no-debug-output`, +`g-doc-001`, +`g-doc-002`; new namespaces `_universal`, `documentation`) |
| New plugin content | `rubric/enforce.sh` (Fix E), `rubric/detectors/universal-pattern-rule.sh` + `cloud-guidance-rules.json` + `universal-pattern-rules.json`, `generated-code-quality-standards/{_universal,documentation}/`, the Fix-G `no-any` comment-strip, CL-477..481 specs (suite 4258 → 4288) |

## What this adopts (the frozen contract GCTP's Fix B/C build against)

`rubric/enforce.sh` — the stable external-tree enforcement entrypoint. Verified from source (not the report) against the materialized cache:

- **Catalog-keyed dispatch** — resolves rule ids from `generated-code-quality-standards/` (the catalog that syncs into `active.json`), NOT `RUBRIC.yaml` (the bare ids collide: `g-ts-001` = `no-any` in the catalog vs `g-ts-001-naming-style` in `RUBRIC.yaml`). This was GCTP's Correction 1.
- **4-state per rule + `files_evaluated`** — `pass` (ran, ≥1 file, 0 findings) · `fail` (≥1 finding) · `not_applicable` (0 files matched the rule's scope — NEUTRAL, distinct from pass; kills the vacuous-green class) · `not_enforced` (files existed, detector couldn't verify — RED). This was GCTP's Corrections 2 + the 4-state/`files_evaluated` refinement.
- **Aggregate exit** — `0` iff every rule is pass or not_applicable; `1` any fail; `2` usage/unknown_rule; `3` ≥1 not_enforced (never collapses to success).
- **EO interaction preserved** — a non-exemptible EO/cloud rule against a pure-code tree resolves `not_applicable` (neutral), so it does **not** force every code ticket red; EO-by-detector runs on IaC, EO-by-attestation covers the rest (GCTP's flagged edge case, handled correctly).

Live check from the cache: `enforce.sh --root <kata> --rule g-ts-001 --rule g-security-governance-require-provenance --json` → `g-ts-001` **fail** (27 files), EO rule **pass** (3 files), exit 1. Catalog dispatch, 4-state, and `files_evaluated` all confirmed.

## Decision

Bump the pin `6d2fe13` → `eb7b2af`:

- **Lockfile:** update `pinned_commit` / `pinned_at` / `pinned_message` / `last_synced_*` and re-hash `architecture-v1.9.md` (`d2da1b8c…` → `4e1bc2c2…`). `CLAUDE.md` + the 3 skill hashes are unchanged.
- **Adopt the new contract surface read-only** — GCTP consumes `enforce.sh` and the new `g-universal-*` / `g-doc-*` rules through `active.json` + the pinned cache; no `claude-tdd-pro` path is edited from here (prime directive).
- **Record the cross-repo loop** in `docs/upstream-ctp-proposals.md`: Fix E/F/G → ADOPTED at `eb7b2af`.

## What changes for GCTP

- **Gained:** a real, catalog-keyed, falsifiable enforcement entrypoint (`enforce.sh`) for an external app tree — the prerequisite for GCTP-side Fix A (decompose-union), Fix B (inner-loop runs `enforce.sh`), Fix C (dynamic re-run gate), Fix D (`app_root` model). Prose is now enforceable (`g-doc-001/002`). Universal rules (`g-universal-*`) are apply-by-default.
- **Unchanged:** the 3 executed inner-loop skills, `CLAUDE.md`, `schema_version`. No GCTP enforcement behavior changes *yet* — the new rules are available in `active.json` but are not auto-unioned onto tickets until Fix A lands. The bump is inert/safe standalone.
- **Dependency note:** GCTP's Fix B/C require **Ruby ≥ 3.0** at enforcement time (`enforce.sh` is Ruby-backed) — consistent with the existing ADR-0056 consult-loop prerequisite; Fix C's CI wiring must provision Ruby.

## Consequences

### Positive
- Closes the cross-repo loop cleanly: GCTP found it (kata) → corrected CTP's design (4 corrections) → CTP shipped E/F/G + universal foundation → GCTP adopts, test-pinned on both sides (CTP 4288/0; GCTP chain green + 26/26).
- Unblocks the GCTP-side Fix A–D.

### Neutral
- No `claude-tdd-pro` path edited from here (prime directive); consumer-side lockfile change only. D-6 honored (`docs/founder-directives.md` diff == 0). `schema_version` unchanged.

### Negative / cost
- `active.json` grows (42 → 46) and will grow further as CTP extends universal coverage per-CL; GCTP's Fix A wire-up is designed to absorb that without rework (new rules simply appear in the catalog).

## Verification (executed before commit)

- `sync-plugin.sh --check` → pin matches HEAD, **0 contract drift**; `--ensure` → cache materialized at `eb7b2af`.
- `standards-sync` → **46 rules** (was 42), namespaces include `_universal` + `documentation`.
- Full audit chain green (doc-drift, cross-references, hook-security, agent-compact, plugin-surface 56/56, standards-conformance, eo-governance, source-citations 46/46 provenance, architecture-crosscheck, rules-verified, manifest, metrics).
- `tests/test-all.sh` **26/26**; `smoke-e2e` green; `git diff docs/founder-directives.md` == 0 (D-6); no `claude-tdd-pro` path modified.
- `enforce.sh` exercised live from the cache (catalog dispatch + 4-state + `files_evaluated` confirmed).

## Implementation references

- Modified: `docs/claude-tdd-pro.lock.yaml` (pin + `architecture-v1.9.md` hash), `README.md` (pin badge), `docs/upstream-ctp-proposals.md` (Fix E/F/G ADOPTED), `TICKETS.md` (TICKET-069)
- New: this ADR
- Adopts (CTP-side, not edited here): CL-477 (§28.17 Fix E), CL-478 (§28.18 4-state freeze), CL-479 (§28.19 Fix G), CL-480 (§28.20 Fix F), CL-481 (§28.21 universal-coverage foundation)
- Enables (GCTP-side, subsequent CLs): Fix D (`app_root`), Fix A (decompose-union), Fix B (`enforce-standards.sh`), Fix C (dynamic re-run gate) — see PROPOSAL-002 + `docs/upstream-ctp-proposals.md`
- Related: ADR-0054 (prior pin bump `3432b52`→`6d2fe13`), ADR-0056 (consult loop; Ruby prerequisite), `proposals/PROPOSAL-002-app-enforcement-spine.md`
