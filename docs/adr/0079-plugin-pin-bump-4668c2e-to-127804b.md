# ADR-0079 — Plugin pin bump `4668c2e` → `127804b` (adopt CTP §28.70 / CL-538 — the bash-3.2 composite-dispatch fix; resolves P-10)

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"unblock full tool-effectiveness from P-10 following all the architectural rules of CTP/GCTP"*, then *"prepare the handoff for CTP chat to assess GCTP's blocker"*) + Claude Opus 4.8 (local session).
- **Trigger:** CTP assessed + fixed **P-10** (the `composite-dispatch.sh` bash-3.2 empty-array crash GCTP filed + handed off in TICKET-106) in **CL-538 (§28.70)**, and returned a CTP→GCTP handoff naming re-pin target **`127804b`**. This is the coordinated re-pin.
- **Continues:** the pin chain ADR-0072 (`230e99d → 4668c2e`) → this ADR (`4668c2e → 127804b`).
- **Process:** §15-gated pin bump (`architecture-v1.9.md` contract hash changed `a2c34ace… → efdd3805…`); lockfile updated by hand under this ADR (the manual-edit-under-ADR path, `--update` refuses on contract drift).

## Compatibility verdict (verified `4668c2e → 127804b`)

| Check | Result |
|---|---|
| Span | **2 commits** (the CL-538 fix + merge) |
| `architecture-v1.9.md` | **CHANGED** (`a2c34ace… → efdd3805…`) — purely additive: the §28.70 fix note appended (Nygard) |
| `CLAUDE.md` + 3 consumed `SKILL.md` | **all byte-identical** — prime-directive text + inner-loop discipline unchanged |
| Files removed | **0** (ADR-0047 additive-only invariant preserved) |
| `active.json` | **118 → 118 rules** (fix is behavioral, not a rule change) |
| Changed plugin file | `rubric/composite-dispatch.sh` (the `${ra[@]+…}`/`${toa[@]+…}` empty-array guard) + `evals/specs/cl538-bash32-*` |

## Decision

Bump the pin `4668c2e → 127804b`. Pin to the **exact fix commit** `127804b` named in the CTP handoff; CTP `main` HEAD (`7d41370`) is a docs-only commit on top (the CTP-side handoff), contract-identical (`--check` reports **0 drift** between `127804b` and HEAD). No other GCTP change is required: the already-wired routed-tool paths **activate automatically** once `composite-dispatch` emits real verdicts.

## The decisive verification (the whole point of this bump)

CTP's CI runs bash 5.2, where the empty-array-under-`set -u` bug is invisible — so the **definitive** confirmation is a run under macOS's default `/bin/bash` 3.2.57, which this session performed against the materialized `127804b` cache:

| | at `4668c2e` (before) | at `127804b` (after) |
|---|---|---|
| `composite-dispatch --file <violating .md>` | `line 119: ra[@]: unbound variable`, exit 1, **no verdict** | `dispatch … status=red … fallback=native`, real verdict |
| `composite-dispatch --file <clean .yaml>` | crash | `dispatch … status=green …`, exit 0 |
| `composite-dispatch --file <clean .md>` | crash | `status=green` |

So the crash is gone **and** verdicts are correct (clean → green, violating → red) — the now-live governors will allow clean app_root writes and deny real violations, not false-red on absent tools (native fallback handles them).

## What changes for GCTP
- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): pin + `pinned_at`/`message` + the single `architecture-v1.9.md` hash. Cache re-materialized at `127804b` (`--ensure`; `--check` 0 drift).
- **`active.json`** regenerated (118 → 118; no rule change).
- **Routed-FOSS-tool enforcement now ACTIVE on bash 3.2** across the wired phases: pre-write (ADR-0075 §4 tools half), on-save (ADR-0076 W-C), audit-time whole-tree (ADR-0077). Native enforcement was already working; this lights up the ~80-tool routed path.
- **No handoff regeneration** (no-rewrites discipline, ADR-0070 §1).
- `docs/upstream-ctp-proposals.md` §P-10 flipped 🟥 OPEN → ✅ ADOPTED at this pin.

## Consequences
- **Positive:** the headline capability of the whole `4668c2e` adoption — routed FOSS-tool enforcement — is finally effective on the default macOS shell. Every wired tools-path emits real verdicts.
- **Neutral:** the pin targets `127804b` (behind CTP HEAD `7d41370` by one docs-only commit) — `--check` will WARN "pin behind upstream" until the next bump; this is intentional (pin the exact fix commit) and contract-safe (0 drift).
- **Cost:** the pre-write/on-save governors now spawn + parse `composite-dispatch` for real on app_root writes (small latency); still parse-then-block, so an operator-local environment lacking the FOSS tools falls back to native (verified: absent tools → native fallback → correct verdict, not a false red).

## Verification (executed before commit)
- `sync-plugin.sh --check`: **0 files drifted** (contract surface stable `127804b`↔HEAD).
- **Live `/bin/bash` 3.2.57**: `composite-dispatch --file` emits real `status=` verdicts, no `unbound variable` (table above).
- `tests/test-all.sh --no-cache`: **41/41** — activating `composite-dispatch` regressed nothing (design-phase-md's parse-then-block + prose-loop handle the now-live verdicts).
- Prime directive: no `claude-tdd-pro` path edited (cache only re-materialized; the fix was made in the CTP repo by the CTP side, per TICKET-106). D-6: `docs/founder-directives.md` unchanged.

## Note on ADR numbering
ADR-0078 forward-referenced the (deferred) profile-honoring ADR as "ADR-0079". ADRs are assigned in landing order; this coordinated fix-bump landed first and took **0079**. The profile-honoring ADR will take the next free number (0080+).

## Implementation references
- Lockfile: `docs/claude-tdd-pro.lock.yaml` · Proposal resolved: `docs/upstream-ctp-proposals.md` §P-10 · Handoffs: `docs/handoff-ctp-p10-composite-dispatch-crash.md` (GCTP→CTP, TICKET-106)
- Activated consumers: ADR-0075 (pre-write), ADR-0076 (on-save), ADR-0077 (audit-time) · Prior bump: ADR-0072 · Process: `docs/plugin-sync.md`, `docs/architecture-principles.md` §15
