# ADR-0077 — Per-file `--single-file-gate` (CL-E) + audit-time whole-tree gate `audit-app-tree.sh` (CL-F); CL-G already present; app_root-config record correction

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"proceed with the architecture as planned in the handoff"*) + Claude Opus 4.8 (local session).
- **Trigger:** **CL-E + CL-F** of the ADR-0072 "Known follow-up" #2 backlog, batched (per `tdd-pro-batch-cl`: related composite-engine consumption).

## CL-E — thread `--single-file-gate` into per-file re-verification

`scripts/enforce-standards.sh` W-B mode (ADR-0068) runs the plugin's `rubric/enforce-file.sh` per changed file to re-verify a ticket's `rules_verified`. Per-file enforcement should **skip tree-context rules** (coverage etc.) that only make sense whole-tree. The `4668c2e` engine adds `enforce-file.sh --single-file-gate` for exactly this. Decision: pass `--single-file-gate` on the per-file invocation, **guarded by a support check** (`grep -q -- --single-file-gate "$ENFORCE_FILE"`) so an older cache still works. Verified: no change to the standards-enforced verdicts (still 5 grandfathered).

## CL-F — audit-time whole-tree gate `scripts/audit-app-tree.sh`

New harness audit consuming CTP **§28.35/§28.42** `rubric/composite-audit.sh --root <app_root>` — the **audit-time, whole-tree, strict** phase of two-phase enforcement, the complement to the per-file write-time hooks (CL-C pre-write, CL-D on-save). Same engine, different moment.

- **app_root-scoped** (agent-operating-compact): audits the external product tree only; vacuous when no app_root.
- **Parse-then-block:** acts only on an authoritative `composite-audit … status=<v>` summary; a bare crash / no summary (the P-10 composite-dispatch bash-3.2 issue) is **not a verdict** → vacuous, never a false red. `incomplete` (optional tool absent) is advisory.
- **NOT wired into `session-start`:** `composite-audit` walks the whole tree and is **slow** (seconds-to-minutes on a real product). It is an **on-demand / CI-time** gate (`scripts/audit-app-tree.sh`), not part of the fast per-session WARN chain. Its unit test uses a stub `composite-audit` and is fast.
- Prime directive: `composite-audit.sh` consumed by reference, never edited.

## CL-G — SARIF 2.1.0 bus: already present

`scripts/sarif-aggregate.sh` was built in TICKET-078 (ADR-0066) and is tested (`tests/test-sarif-aggregate.sh`); the composite engine already emits/aggregates SARIF 2.1.0 through it. **CL-G is closed as already-present** — no new wiring needed.

## Record correction — the CL-C/CL-D governors are app_root-scoped, not "vacuous"

ADR-0075 (CL-C) and ADR-0076 (CL-D), and their commit/ledger text, described the governors as *"vacuous — no `.harness/app.json`."* **That was imprecise:** `.harness/app.json` **is** configured (`app_root = ../softarchcert-win25`, the kata product). The correct statement:

- The CL-C pre-write governor and the CL-D on-save composite-dispatch are **app_root-scoped and ACTIVE for `softarchcert-win25`** — native enforcement is live; the routed-tool half is inert until P-10.
- They are **EXEMPT for harness self-maintenance** writes (anything outside `app_root`), so they do not block edits to this harness repo.

The **safety property is unchanged** (harness self-maintenance is not blocked); only the "vacuous / no app.json" reasoning was wrong. ADRs are append-only, so this note corrects the record rather than editing ADR-0075/0076.

## Consequences
- Audit-time whole-tree enforcement is available on-demand (`scripts/audit-app-tree.sh`) for the product tree; per-file re-verification is correctly a single-file gate.
- P-10 gates the composite verdicts; parse-then-block keeps both the write-time and audit-time paths safe (no false reds from the crash).

## Verification (executed before commit)
- `tests/test-audit-app-tree.sh` — 8/8 hermetic (help/unknown-flag; no app_root → vacuous; composite-audit absent → vacuous; green → 0; red → 1; incomplete → advisory; crash → vacuous).
- `tests/test-enforce-standards.sh` + `tests/test-audit-standards-enforced.sh` pass; live `audit-standards-enforced` still green (5 grandfathered) with `--single-file-gate`.
- Live `composite-audit` on a tiny tree: `status=green`.
- No `claude-tdd-pro` path touched. D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- CL-E: `scripts/enforce-standards.sh` (W-B `--single-file-gate`) · CL-F: `scripts/audit-app-tree.sh` + `tests/test-audit-app-tree.sh`
- Consumed entrypoints: `rubric/enforce-file.sh` (`--single-file-gate`), `rubric/composite-audit.sh` (§28.35/§28.42) · SARIF: `scripts/sarif-aggregate.sh` (TICKET-078)
- Corrects the record of: ADR-0075, ADR-0076 · Backlog: ADR-0072 KFU #2 · Gated: P-10
