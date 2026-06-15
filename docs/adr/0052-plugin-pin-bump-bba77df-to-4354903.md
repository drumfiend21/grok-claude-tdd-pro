# ADR-0052 — Plugin pin bump `bba77df` → `4354903` (adopt latest CTP main)

- **Status:** Accepted
- **Date:** 2026-06-15
- **Deciders:** drumfiend21 (architect; 2026-06-15 directive: *"We need to work out the compatibility in order that both plugins are utilizing the latest commit on main"*) + Claude (cloud session). Cross-corroborated by the CTP-side session (independent git verification of the same facts).
- **Trigger:** GCTP's pinned CTP commit (`bba77df`, 2026-06-07) was 70 commits / 8 days behind CTP `main` (`4354903`, 2026-06-15). Operator-facing content added upstream — the dog-walker E2E demo, the cloud-architect feature, the EO security-governance surface, the citation-conformance auditor — was invisible to GCTP, and a first-time-guide link to `examples/dog-walker-marketplace` would be dead because that path doesn't exist at the old pin.
- **Supersedes:** the pin set by ADR-0025 → ADR-0041 chain (pin `bba77df`). This bump continues that chain.
- **Process:** Per `docs/architecture-principles.md §15` + `docs/plugin-sync.md`, a pin bump that changes a `contract_surface_files` hash requires an ADR. `sync-plugin.sh --update` refuses on contract drift by design; the lockfile was updated by hand under this ADR.

## Context

GCTP consumes CTP by versioned reference (R-2). The pin freezes a known-good CTP so upstream change can't silently break the harness; the cost is staleness, which the operator hit. `sync-plugin.sh --check` reported contract-surface drift on 2 of the 5 tracked files (`CLAUDE.md`, CTP's `architecture-v1.9.md`), correctly gating the bump behind this review.

## Compatibility verdict (proven, not assumed)

Diffing the pin against `main` across all 70 commits:

| Check (`bba77df` → `4354903`) | Result |
|---|---|
| CTP's `architecture-v1.9.md` | **+492 / −0** (purely additive) |
| `CLAUDE.md` | **+14 / −0** (purely additive) |
| The 3 consumed skills (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) | **byte-identical** (sha256 unchanged) |
| Commands removed / files deleted | **0** |
| New top-level surface | only `examples/` |
| CTP `main` suite (upstream) | green |

The span is **purely additive** — CTP's append-only discipline held. Nothing GCTP consumes was removed or altered (Postel / R-11 tolerant-reader: additive ⇒ backward-compatible). The "contract-surface drift" was GCTP's mirror being *behind*, not CTP deleting anything; the fix is to re-sync at the new pin, which is what this ADR does.

## Decision

Bump the pin `bba77df` → `4354903`:

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): update `pinned_commit` / `pinned_at` / `pinned_message`, and re-hash the 2 changed contract files (`CLAUDE.md`, CTP's `architecture-v1.9.md`). The 3 skill hashes are unchanged (skills byte-identical).
- **New surface declared**: `examples/` added to `docs/plugin-surface-consumption.md` as DECLARED-NOT-CONSUMED (the harness ships its own walkthrough at `docs/end-to-end-demo/`).
- **Citation gate tolerance**: the regenerated `active.json` adds the cloud/governance source namespaces (`aws`, `azure`, `gcp`, `hashicorp`, `linux-foundation`, `security-governance`, `us-government`) to `namespaces_seen`, but they aggregate to **zero rubric rules** — they are architecture-**guidance** corpora that feed CTP's `/architect` S/L/C grounding engine, not rubric detectors. `audit-source-citations.sh` A3 (seen-but-empty namespace) now allow-lists these guidance namespaces. A4's required-set guard still protects the 8 rule-bearing namespaces, so this does not mask a real rule drop.

## What changes for GCTP (honest scope)

- **Gained:** the dog-walker example becomes present; CTP's cloud-architect + EO + citation-conformance + integration content is now in the cache and feeds the `/architect` grounding corpus; CTP contracts §28 / §2.30–§2.33 are now mirrored.
- **Unchanged:** the **rubric rule set stays 28** across the original 8 rule-bearing namespaces — the new namespaces are guidance, not enforced detector rules. There is still **no `eo` namespace**, so GCTP's EO governance spine remains armed-but-vacuous (EO content lands under `security-governance` as guidance, not as `eo`-namespaced rubric rules). Full EO-rule activation remains a future event, gated on CTP emitting `eo`-namespaced rubric rules.

## Alternatives considered

- **Stay on `bba77df`.** REJECTED — operator explicitly wants the latest; staleness was already biting (dead demo link).
- **Track `main` live (drop the pin).** REJECTED — violates R-2; reproducibility is the whole point of the pin.
- **Bump but block on the new empty namespaces (treat as a violation).** REJECTED — they are empty *by design* (guidance corpora); allow-listing them is accurate, and A4 still guards the rule-bearing set.

## Consequences

### Positive
- GCTP is current with CTP; the dog-walker demo + cloud/EO guidance corpora are available; contract mirror re-synced.
- Compatibility was *proven* additive, not assumed.

### Negative
- The pinned message is a merge commit subject (less descriptive); the lockfile annotates the substance.

### Neutral
- No `claude-tdd-pro` path edited (prime directive); the bump is a consumer-side lockfile change.
- `schema_version` unchanged; the 3 executed skills unchanged.
- D-6 honored — `docs/founder-directives.md` untouched.

## Verification (executed before commit)

- `sync-plugin.sh --ensure` → cache at `4354903`; `--check` → **0 contract drift, pin matches HEAD, OK**.
- `standards-sync.sh` → 28 rubric rules (8 rule-bearing namespaces); 16 namespaces seen (incl. guidance).
- `audit-plugin-surface` green (`examples/` declared); `audit-source-citations` green (guidance namespaces allow-listed); full audit chain green; `tests/test-all.sh` **22/22**; `smoke-e2e` green.
- `git diff docs/founder-directives.md` → 0 (D-6); no `claude-tdd-pro` path modified; `schema_version` unchanged.

## Implementation references

- Modified: `docs/claude-tdd-pro.lock.yaml` (pin + 2 hashes), `docs/plugin-surface-consumption.md` (`examples/`), `scripts/audit-source-citations.sh` (guidance-namespace allow-list), `README.md` + `docs/first-time-guide.md` (pin/version refs), `TICKETS.md` (TICKET-056)
- New: this ADR
- Related: ADR-0025 / ADR-0041 (prior pin bumps), ADR-0051 (TICKET-054 sync-plugin `--check` read-only fix — made `--check` safe to run during this verification), ADR-0037 (standards registry), TICKET-051 / ADR-0049 (`audit-source-citations.sh`)
