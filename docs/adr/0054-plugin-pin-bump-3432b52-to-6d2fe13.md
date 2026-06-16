# ADR-0054 — Plugin pin bump `3432b52` → `6d2fe13` (adopt CL-476 install fixes from GCTP's own test feedback)

- **Status:** Accepted
- **Date:** 2026-06-16
- **Deciders:** drumfiend21 (architect) + Claude (cloud session). Cross-repo loop: GCTP's fresh-machine install test (TICKET-058) surfaced CTP-side bugs → routed to CTP via `docs/upstream-ctp-proposals.md` → CTP fixed them in CL-476 → this ADR adopts the fix.
- **Trigger:** CTP `main` advanced one commit to `6d2fe13` (CL-476, §28.16), which fixes the two real CTP-side findings from GCTP's install test: P-1 (the bash-3.2 `conflicts[@]` installer crash) and P-3 (`/architect` was not a slash command). GCTP should adopt so its docs can again list `/architect` and so the install path is correct on stock macOS.
- **Continues:** the ADR-0025 → 0041 → 0052 → 0053 pin chain.
- **Process:** §15-gated pin bump (`architecture-v1.9.md` contract hash changed); lockfile updated by hand under this ADR.

## Compatibility verdict (verified `3432b52 → 6d2fe13`)

A single additive commit:

| Check | Result |
|---|---|
| Span size | **1 commit** (CL-476) |
| CTP's `architecture-v1.9.md` | **+10 / −0** (the §28.16 governance note) |
| `CLAUDE.md` + the 3 consumed skills | **unchanged** (sha256 identical) |
| Files deleted / commands removed | **0** |
| New top-level surfaces | **none** |
| Rubric rules `active.json` | **42 → 42** (CL-476 adds no detector rules) |
| New plugin content | `commands/architect.md` (P-3), the `install.sh` conflicts guard (P-1), 5 specs, the §28.16 note |

## Decision

Bump the pin `3432b52` → `6d2fe13`:

- **Lockfile:** update `pinned_commit` / `pinned_at` / `pinned_message` and re-hash `architecture-v1.9.md`. `CLAUDE.md` + the 3 skill hashes are unchanged.
- **Restore `/architect` in `docs/first-time-guide.md`.** TICKET-058 removed it because no `commands/architect.md` existed at the prior pin; CL-476 added it, so at this pin `/architect` is a real slash command again. The honest "slash commands are a Cursor surface; Claude Code Path A uses skills + hooks" framing stays (still empirically true for the standalone installer).
- **Update `docs/upstream-ctp-proposals.md`:** P-1 + P-3 → ADOPTED at `6d2fe13`; P-2 → not-a-defect (ruby hard-stop is intended; the harness keeps the loud warning); P-4 → clarified (CTP's `commands/*.md` are Claude-Code-format; the Cursor-orientation is installer packaging).

## What changes for GCTP

- **Gained:** the install path is correct on stock-macOS bash 3.2 (no abort-before-clone), and `/architect` is a first-class command. No change to the enforced rule set (still 42).
- **Unchanged:** standards registry, the 3 executed skills, `schema_version`.

## Consequences

### Positive
- Closes the cross-repo feedback loop cleanly: GCTP found it → CTP fixed it → GCTP adopts it, all test-pinned on both sides.
- GCTP docs are accurate to the pinned reality again.

### Neutral
- No `claude-tdd-pro` path edited from here (prime directive); consumer-side lockfile change only. D-6 honored.

## Verification (executed before commit)

- `sync-plugin.sh --ensure` → cache at `6d2fe13`; `--check` → 0 contract drift, pin matches HEAD, OK.
- `commands/architect.md` present at the pin; `standards-sync` → 42 rules (unchanged); `audit-plugin-surface` green (no new surface).
- Full audit chain green; `tests/test-all.sh` 22/22 (idempotent); `smoke-e2e` green.
- `git diff docs/founder-directives.md` → 0 (D-6); no `claude-tdd-pro` path modified; `schema_version` unchanged.

## Implementation references

- Modified: `docs/claude-tdd-pro.lock.yaml` (pin + `architecture-v1.9.md` hash), `docs/first-time-guide.md` (restore `/architect`), `docs/upstream-ctp-proposals.md` (P-1/P-3 ADOPTED, P-2/P-4 resolved), `README.md` (pin refs), `TICKETS.md` (TICKET-059)
- New: this ADR
- Related: ADR-0053 (prior pin bump to `3432b52`), TICKET-058 (the install test + the original `/architect` correction this partly reverses), `docs/upstream-ctp-proposals.md`
