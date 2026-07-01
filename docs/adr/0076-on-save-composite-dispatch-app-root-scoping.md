# ADR-0076 — On-save enforcement: app_root-scope the composite-dispatch corpus path; `enforce-standards-on-save.sh` intentionally not wired

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"proceed with the architecture as planned in the handoff"*) + Claude Opus 4.8 (local session).
- **Trigger:** **CL-D** of the ADR-0072 "Known follow-up" #2 backlog — "on-save backstop (`enforce-standards-on-save.sh`)". Investigation changed the shape of the work (below).

## Finding — the on-save backstop is already wired, and more capably

The harness's `.claude/hooks/post-tool-use-review-gate.sh` (PostToolUse) already performs on-save enforcement: `rubric/runner.sh --diff` (code-quality rubric) **plus** `rubric/composite-dispatch.sh` (the 4-axis SARIF routing engine, ADR-0068 W-C). CTP's `hooks/scripts/enforce-standards-on-save.sh` runs only `rubric/enforce-file.sh` (native). Since `composite-dispatch` routes to the FOSS toolchain **and** falls back to native (§28.56), it is a **superset** of `enforce-standards-on-save.sh`.

**Decision 1: do NOT wire `enforce-standards-on-save.sh`.** A second PostToolUse hook enforcing the same files would be redundant and risk double-blocking. The backlog item is satisfied by the existing (superior) W-C path. Recorded here so the omission is intentional, not an oversight.

## Gap fixed — the on-save corpus path was not app_root-scoped

The on-save `composite-dispatch` invocation fired on **every** written file keyed to the harness project dir — including harness self-maintenance files. Pre-bump it was vacuous (no detectors); the `4668c2e` bump activated real detectors, and once **P-10** (the `composite-dispatch` bash 3.2 crash) is fixed, it would enforce the CTP **app-architecture corpus** (`g-aws`/`g-k8s`/`g-iam`/…) on harness files — violating the agent-operating-compact (self-maintenance is exempt from app-architecture enforcement) and inconsistent with the CL-C pre-write governor (which is app_root-scoped).

**Decision 2: app_root-scope the on-save `composite-dispatch`** (via `scripts/app-root.sh`), consistent with CL-C. **The `rubric/runner.sh` path stays harness-wide** — it is the code-quality/TDD rubric plane, which legitimately governs harness self-maintenance (ADR-0037 write-time enforcement preserved). This cleanly separates the two planes:

| On-save path | Enforces | Scope |
|---|---|---|
| `rubric/runner.sh --diff` | code-quality / TDD rubric | **harness-wide** (ADR-0037; compact's C-rule plane) |
| `composite-dispatch` | CTP app-architecture corpus (`g-*`) | **app_root only** (compact's app-architecture plane; matches CL-C) |

The forbidden-path fence (AGENTS.md §2) is unchanged and still applies to **all** writes.

**Decision 3 (latent fix):** `ABS_FILE` for the composite path now handles an **absolute** `REL_PATH` (a sibling app_root tree) instead of reparenting it under the harness workdir.

With no `.harness/app.json`, the on-save composite path is now a **no-op** in this harness repo (like CL-C).

## Consequences

### Positive
- On-save app-architecture enforcement is consistent with pre-write (both app_root-scoped) and compact-compliant; harness self-maintenance is not app-architecture-governed even after P-10.
- No redundant second hook.

### Neutral
- Vacuous in this repo (no app_root). Runner + fence behavior unchanged.

### Negative
- One more app_root resolution per config/markup write (fast; fails toward not-firing).

## Verification (executed before commit)
- `tests/test-post-tool-use-review-gate.sh` — 17/17 (14 prior + 3 new: composite fires under app_root → deny; skipped outside app_root; no app_root → never fires). Stub plugin via `PTU_PLUGIN_ROOT`; app_root via `PTU_APP_ROOT`.
- No `claude-tdd-pro` path touched (prime directive). D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- Hook: `.claude/hooks/post-tool-use-review-gate.sh` (composite-dispatch block) · Tests: `tests/test-post-tool-use-review-gate.sh`
- Consistent with: ADR-0075 (CL-C pre-write governor, app_root scope) · Preserves: ADR-0037 (write-time standards) · Superseded entrypoint: `hooks/scripts/enforce-standards-on-save.sh` · Backlog: ADR-0072 KFU #2 · Gated: P-10
