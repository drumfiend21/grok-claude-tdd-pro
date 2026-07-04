# ADR-0086 — Plugin pin bump `a69f380` → `0cf28fe` (adopt CTP CL-541..CL-545 / §29..§29.6 — full-surface consult grounding + byte-identical native enforcement; resolves P-11)

- **Status:** Accepted
- **Date:** 2026-07-03
- **Deciders:** operator (`drumfiend21`; 2026-07-03: *"Redo the work to enforce 118-rule/43-namespace reasoning at consult time with the new CTP version."*) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** CTP shipped **CL-541 (§29 / S-56 / §2.34)** through **CL-545 (§29.6)** on `main`, adopting the P-11 full-surface consult-grounding proposal and adding byte-identical native enforcement via a shared write-time primitive. CTP returned a handoff naming re-pin target **`0cf28fe`** (recommended: `main` HEAD, includes both handoff docs). Operator directs adoption at this pin, before starting the O'Reilly kata submission on this branch — so the consult reasons against the full 118-rule / 43-namespace surface at architecture-production time, not the 5-source AWS-WA/NIST/SRE/OTel subset.
- **Continues:** the pin chain ADR-0072 (`230e99d → 4668c2e`) → ADR-0079 (`4668c2e → 127804b`) → ADR-0085 (`127804b → a69f380`) → this ADR (`a69f380 → 0cf28fe`).
- **Process:** §15-gated pin bump (upstream `architecture-v1.9.md` contract hash changed `efdd3805… → 4cfa3d97…`); lockfile updated by hand under this ADR (the manual-edit-under-ADR path — `--update` refuses on contract drift, per ADR-0079 precedent).

## Compatibility verdict (verified `a69f380 → 0cf28fe`)

| Check | Result |
|---|---|
| Span | **14 commits** (CL-541 through CL-545 + merges + handoff docs) |
| upstream `architecture-v1.9.md` | **CHANGED** (`efdd3805… → 4cfa3d97…`) — **purely additive**: §29 through §29.6 appended (+59 insertions / 0 deletions per the compare view; matches CTP's append-only discipline + ADR-0047 additive-only invariant) |
| `CLAUDE.md` + 3 consumed `SKILL.md` (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) | **all byte-identical** — prime-directive text + inner-loop discipline unchanged |
| Files removed | **0** (ADR-0047 additive-only invariant preserved) |
| `active.json` | **118 → 118 rules** across the same 43 namespaces (byte-identical after `standards-sync.sh` regeneration; the §29 amendments are engine changes, not new authored rules — CTP's rule surface is unchanged, but the consult engines now *reason against* the full surface at production time, which was the whole point of P-11) |
| Changed plugin files | Add: `rubric/enforce-write-time.sh` (the shared primitive), `commands/full-surface-consult.sh`, `.markdownlint.json`, upstream design docs `v1.20-full-surface-grounding-consult.md` + `v1.21-byte-identical-native-enforcement.md`, 2× upstream handoff docs, 34× `cl541..cl545-*` evals specs; Modify (upstream-only): `commands/architect-session.sh` (+35/-1), `hooks/scripts/enforce-standards-pre-write.sh` (+5/-8), `rubric/runners/run-tool.sh` (+5/-1) |

## Decision

Bump the pin `a69f380 → 0cf28fe` — the target named in the CTP handoff (recommended over the code-only `de4edec` because it includes the durable in-repo handoff record). This resolves **P-11 upstream** and lands **§29.6 byte-identical native enforcement** in one bump, before any kata `/consult` runs on the current dev branch.

## What §29..§29.6 delivers (the substantive change)

CTP's consult engines now:

1. **Ingest the full aggregated standards surface** at architecture-production time (`commands/full-surface-consult.sh`), not just the 5-source AWS-WA/NIST/SRE/OTel subset the pillar model was hardwired to. This is the direct fix for P-11's composition gap (`business-translate.sh` never invoked `rubric/aggregator.sh`; now it does).
2. **Emit per-decision verdicts across every applicable namespace** — `needs_grounding=0` after CL-542 means every design decision now carries reasoning against the 118 rules × 43 namespaces surface + the IaC-convention rules.
3. **Enforce the design output against the same rules** — CL-543/§29.4 (same-engine enforcement) + CL-544/§29.5 (parity) + CL-545/§29.6 (byte-identical primitive) mean the consult path and the write-time governor now run through **one shared primitive** (`rubric/enforce-write-time.sh`) with byte-identical verdicts by construction. Not identical-by-inspection; identical-by-shared-code-path.

The observable delta on the GCTP side is intentionally minimal, per the CTP handoff:

- The consult stderr marker's engine field changed: `engine=enforce-file` → `engine=enforce-write-time`.
- The `design_enforcement=green|red` field and its semantics are **unchanged**.
- Routed opt-in (`ARCHITECT_ENFORCE_ROUTED=1` → `design_enforcement_routed=… engine=composite-audit tools=80`) is **unchanged**.
- No CTP contract interface changed shape (`full-surface-consult`, `architect-session`, `composite-audit`, SARIF bus are all unaffected in their shape).

## What changes for GCTP

- **Lockfile** (`claude-tdd-pro.lock.yaml` under `docs/`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `0cf28fe`; the single upstream `architecture-v1.9.md` sha256 updated to `4cfa3d97…`; other 4 contract-surface hashes unchanged (verified byte-identical); `last_synced_at` + `last_synced_session` refreshed to reference this ADR.
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `0cf28fe` via `sync-plugin.sh --ensure` (idempotent).
- **`active.json`**: regenerated via `standards-sync.sh` — **118 rules unchanged** (no git diff on `.harness/rules/active.json`; the §29 amendments change engine behavior, not authored rules).
- **No `engine=enforce-file` string update needed**: GCTP-side grep confirmed zero consumer files reference the old engine token (verified during the prior instance of this same bump). Step 2 of the CTP handoff is a verified no-op.
- **P-11 filed as ✅ ADOPTED** in `docs/upstream-ctp-proposals.md` at pin `0cf28fe` (this ADR is the adoption record).
- **No handoff regeneration** (no-rewrites discipline, ADR-0070 §1); no `applicable_rules` change on any open ticket.

## Consequences

- **Positive — the P-11 invariant is restored at production time.** Every architectural decision CTP produces for a GCTP consult now carries reasoning against all 43 namespaces / 118 rules (+ IaC convention rules). This is exactly the invariant the O'Reilly kata attempt needs: the empirical quality bar (`../softarchcert-kata-2026-07-03/docs/quality-bar.md`) shows the top-3 Winter 2025 finalists all shared gaps precisely in the namespaces CTP did not consult at design time (Google TS/React discipline, OWASP ASVS, OAS discipline, WCAG, EO-2026). Under this pin, that reasoning becomes part of the architecture at design time, not at rework time.
- **Positive — the CTP-side enforcement of that reasoning is now byte-identical to write-time enforcement.** §29.6 gives us "one shared write-time primitive" (`rubric/enforce-write-time.sh`), so the consult verdict and the development-time verdict cannot drift on the same file — they are the same code path.
- **Positive — the kata `/consult` is unblocked** at world-class-standards resolution. Ready to run when the operator directs.
- **Neutral — no runtime shape change on the GCTP side.** No parser updates. No `applicable_rules` refactoring. Consult stderr marker field name change is the only cosmetic delta and no GCTP file greps it.
- **Cost — negligible.** Cache re-materialization + `active.json` regeneration (both idempotent, seconds). One-time.

## Verification (executed before commit)

- `sync-plugin.sh --ensure`: `status: OK (cache materialized at 0cf28fe)`.
- `sync-plugin.sh --check`: `pinned: 0cf28fe · upstream: 0cf28fe (main, in sync) · contract: 0 files drifted (pin matches HEAD) · status: OK`.
- Installed cache `git rev-parse HEAD` at `.harness/plugin-cache/claude-tdd-pro` = `0cf28fecab9d885a9fc31b8ffa3a674482e776c8`.
- `standards-sync.sh`: `rules: 118`, same 43 namespaces; `git status` shows `active.json` unchanged (byte-identical output).
- GitHub-truth checks via `gh api` (before this bump): GCTP `main` HEAD = `03674ec` (dev/kata-2026-07-03 branchpoint); CTP `main` HEAD = `0cf28fe` (target of this bump); both upstream handoff docs (`handoff-ctp-to-gctp-p11-fixed.md` and `handoff-ctp-to-gctp-byte-identical-enforcement.md`) exist at `0cf28fe`.
- Prime directive: no `claude-tdd-pro` path edited (cache only re-materialized; the P-11 fix + §29..§29.6 amendments were made in the CTP repo by CTP). D-6: `docs/founder-directives.md` unchanged. Compact scope: harness self-maintenance, not app-architecture — permitted under the scope boundary in `docs/agent-operating-compact.md`.

## Implementation references

- Lockfile: `docs/claude-tdd-pro.lock.yaml`
- Proposal resolved: `docs/upstream-ctp-proposals.md` §P-11 (filed + ADOPTED in this ADR at `0cf28fe`)
- CTP→GCTP handoffs (return direction, upstream-only): `handoff-ctp-to-gctp-p11-fixed.md` + `handoff-ctp-to-gctp-byte-identical-enforcement.md` in the CTP repo `docs/` at `0cf28fe`
- Sync tooling: `scripts/sync-plugin.sh`, `scripts/standards-sync.sh`
- Prior bumps: ADR-0072 (`230e99d → 4668c2e`), ADR-0079 (`4668c2e → 127804b`), ADR-0085 (`127804b → a69f380`)
- Process: `docs/plugin-sync.md`, `docs/architecture-principles.md` §15
- Session context: `dev/kata-2026-07-03` branch open for O'Reilly Winter 2025 kata attempt (Certifiable, Inc.); this bump lands on the dev branch (main lands separately, on operator direction, per work-preservation discipline).
