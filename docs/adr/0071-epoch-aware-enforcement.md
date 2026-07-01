# ADR-0071 — Epoch-aware enforcement (consumer-side dual of P-9; pin-keyed baselines + generalized epoch marker)

- **Status:** Accepted
- **Date:** 2026-06-30
- **Deciders:** operator (`drumfiend21`; 2026-06-30 directive: readiness-first adoption of CTP `4668c2e`, and — on the epoch-gate coverage question — *"all 17 audits"*) + Claude Opus 4.8 (local session).
- **Trigger:** the retro-violation cascade documented in ADR-0070 "Known follow-up" (205 `applicable-rules` + 57 `cross-references` + 5 `standards-enforced` reds at the `39903da → 230e99d` pin bump) and diagnosed in `docs/upstream-ctp-proposals.md` §P-9. Every one of those reds is a harness audit **retroactively** demanding, of legacy tickets/data, a requirement that only entered the registry at the bump epoch.
- **Pairs with:** P-9 (the **CTP-side** invariant *"schema-additive with epoch + default"* — OPEN upstream). This ADR is the **GCTP-side** dual that P-9 itself names: *"a forthcoming GCTP ADR codifying the consumer-side dual invariant: epoch-aware enforcement … harness-only and lands separately under the §15 ADR process."* This is that ADR.
- **Readiness CL:** CL-α / TICKET-093 — the second readiness CL (after CL-β/TICKET-092 ledger reconcile) on the path to the ADR-0072 pin bump `230e99d → 4668c2e`. Lands **before** the bump so the bump's new retro-violations are grandfathered by construction rather than documented as deferred reds.

## Problem

A harness audit that derives requirements from the evolving `active.json` registry (or from an evolving cross-reference graph) has no notion of *when* a requirement entered the registry. So when a pin bump adds a rule/floor, the audit instantly holds **all** pre-existing tickets/data to the new bar — producing violations on artifacts that were correct at the epoch they were authored. P-9's table enumerates the asymmetry: each change is "additive on the rule body" but "breaking on the consumer's enforcement-state derivations."

The prototype fix already shipped narrowly: W-A (ADR-0068) added a per-req `applies_to_floor_version >= 2` opt-in to `audit-applicable-rules.sh` floor 4, so legacy handoffs (no marker) skip the new floor. This ADR **generalizes** that idea and pairs it with **pin-keyed baselines** so the whole audit surface is epoch-aware, not just one floor of one audit.

## Decision

Introduce a single shared library — `scripts/_lib/epoch-gate.sh` — as the canonical home of two grandfathering mechanisms, and wire the audit surface to it.

1. **Pin-keyed baselines (generalizes the ADR-0032 approval-testing pattern).** An audit's accepted-findings snapshot is keyed to the pin it was captured at: `tests/<stem>-baseline.<pin>.txt`. The pin (short `pinned_commit` from `docs/claude-tdd-pro.lock.yaml`) **is** the epoch. Re-baselining is an **explicit pin-bump step** (see `docs/plugin-sync.md`), never a silent per-run rewrite — a regression must still fail the gate between bumps. A legacy un-keyed `tests/<stem>-baseline.txt` is honored as a fallback, so adopting the library is a **no-behavior-change** wiring until the ADR-0072 bump re-keys the snapshots.

2. **Generalized epoch marker.** `epoch_req_gated <req.json>` lifts W-A's `applies_to_floor_version >= 2` opt-in to a shell-level helper any audit can call: a going-forward artifact opts into a new floor via the marker; a legacy artifact (no marker) is grandfathered. No rewrites of shipped handoff state (the ADR-0070 no-rewrites discipline).

### Library API (`scripts/_lib/epoch-gate.sh`, sourced, side-effect-free, bash 3.2 portable)

| Function | Contract |
|---|---|
| `epoch_current_pin` | short (7-char) `pinned_commit`, or `unpinned` if the lockfile is absent/malformed |
| `epoch_baseline_path <stem>` | the pin-keyed path `tests/<stem>-baseline.<pin>.txt` |
| `epoch_resolve_baseline <stem>` | baseline to USE: pin-keyed if present, else legacy flat, else empty (migration note to **stderr**; path to stdout) |
| `epoch_filter_new <baseline> <current>` | NEW = current − baseline (sorted-set diff); empty/missing baseline ⇒ all current are new |
| `epoch_req_gated <req.json>` | exit 0 if the req opts into the current epoch's floors (`applies_to_floor_version >= 2`), else 1 |
| `epoch_note <stem> <context>` | uniform one-line `[epoch]` banner for audits wired for uniformity but with nothing registry-derived to grandfather |

`EPOCH_LOCKFILE` and `EPOCH_BASELINE_DIR` are overridable for hermetic fixture tests. Unit tests: `tests/test-epoch-gate.sh` (18 assertions, fully hermetic).

## Coverage — all 17 `audit-*.sh` (per the operator's *"all 17"* directive)

The operator chose to wire **all 17** audits rather than the ~6-audit registry-derived subset the remote handoff recommended. This ADR honors that literally, and is honest about what "wired" buys each audit. Three tiers:

**Tier 1 — real epoch teeth (baseline-backed):** `cross-references`, `hook-security`, `standards-conformance`. Baseline resolution + new-vs-baseline computation route through `epoch_resolve_baseline` + `epoch_filter_new`. Behavior is identical today (legacy fallback) and becomes pin-keyed at the ADR-0072 re-baseline.

**Tier 2 — registry-derived (marker + baseline capability):** `applicable-rules` (already carries the node-internal floor-4 marker — `epoch_req_gated` is its extracted/generalized form; the working node check is retained to avoid regression and cross-referenced here), `standards-enforced`, `rules-verified`, `source-citations`. Sourced against the library so a pin-keyed baseline can be populated for them at bump time (e.g. CL-δ populates `standards-enforced`'s baseline for the 5 divergences).

**Tier 3 — structural / config audits (uniform, no-op today):** `agent-compact`, `architecture-crosscheck`, `claude-code-compat`, `design-phase-md`, `doc-drift`, `eo-governance`, `manifest`, `metrics`, `plugin-surface`, `rulebook-coverage`. These do not derive requirements from the evolving registry and so have nothing epoch-sensitive to grandfather. They source the library and emit one `epoch_note` line for uniformity and future-proofing (if such an audit later grows a registry-derived requirement, the mechanism is already present). This is the "adds machinery without present benefit" tradeoff the operator accepted knowingly.

## Consequences

### Positive
- The root cause of the retro-violation cascade is fixed once, centrally. The ADR-0072 bump's new reds are grandfathered by construction, not carried as deferred reds.
- One definition of "epoch" (the pin) and one baseline convention across the whole audit surface.
- Pin-keyed baselines make "what did we accept, and at which pin" auditable and reviewable in diffs.

### Neutral
- Existing flat baselines keep working unchanged until the bump re-keys them (fallback path).

### Negative / cost
- Tier-3 audits carry a sourced library + one banner line for no present benefit (operator-accepted).
- Re-baselining becomes a required, checklist-enforced pin-bump step; skipping it re-opens the cascade. Documented in `docs/plugin-sync.md`.

## Re-baseline procedure (pin-bump step, binding on ADR-0072 and every future bump)

At a pin bump `<old> → <new>`:
1. Run the full audit chain at `<new>` after `sync-plugin.sh --ensure` + `standards-sync.sh`.
2. For each Tier-1/Tier-2 audit whose findings changed, snapshot the accepted set into `tests/<stem>-baseline.<new>.txt` (review each new line — a regression must NOT be baselined).
3. Record the re-baseline in the pin-bump ADR (mirror ADR-0070's "Known follow-up" structure), listing every newly-baselined line with justification.
4. The old `tests/<stem>-baseline.<old>.txt` (or legacy flat file) is retained for history; the resolver prefers the newest pin-keyed file.

## Verification (executed before commit)
- `tests/test-epoch-gate.sh` — 18/18 (hermetic).
- Full audit chain re-run: **no NEW reds** vs the pre-CL `230e99d` baseline (the standing 205/5 + cross-ref reds are unchanged; Tier-1 audits produce byte-identical verdicts via the legacy fallback).
- `tests/test-all.sh` — no regression.
- Prime directive: no `claude-tdd-pro` path touched. D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- Library: `scripts/_lib/epoch-gate.sh` · Tests: `tests/test-epoch-gate.sh`
- Wired: the 17 `scripts/audit-*.sh` (tiers above)
- Proposal: `docs/upstream-ctp-proposals.md` §P-9 · Prior art: ADR-0032 (approval-testing baselines), ADR-0068 W-A (`applies_to_floor_version` marker), ADR-0070 (no-rewrites discipline + the deferred reds this ADR roots)
- Re-baseline step: `docs/plugin-sync.md`
