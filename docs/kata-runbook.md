# Runbook — O'Reilly Kata session: audit / rebuild `softarchcert-win25` on the fixed GCTP

This runbook is grounded in a real audit of the existing submission against the now-fixed
enforcement: detectors were run against the tree and the result is reproduced inline so the
kata session knows exactly what to expect.

## 0. Prerequisites

- **Ruby ≥ 3.0** (CTP's `enforce.sh` is Ruby-backed — Fix B/C produce `not_enforced`→red without it), **Node**, **git**. `gh` optional.
- Network egress is *nice* (fresh scraping) but not required — refresh degrades to cached, never blocks.

## 1. Get the latest GCTP

```bash
git clone https://github.com/drumfiend21/grok-claude-tdd-pro   # or: git -C grok-claude-tdd-pro pull origin main
cd grok-claude-tdd-pro                                          # origin/main == 4fbbd63
```

## 2. Bootstrap the harness (in order)

```bash
./scripts/sync-plugin.sh --ensure        # materializes CTP plugin @ pinned 7a7f74d + skills + active.json (46 rules)
./scripts/accept-compact.sh              # REQUIRED: fail-closed agent compact (ADR-0057). Until accepted, the
                                         # agent MUST NOT drive /consult../inner-loop. Accept = you agree to act
                                         # only as GCTP's user (don't self-architect; CTP generates, GCTP enforces).
./scripts/standards-refresh.sh --configure 1d   # optional; default is already daily, aligned across GCTP+CTP
```

## 3. Point GCTP at the app tree (Fix D — `app_root`)

```bash
git clone https://github.com/drumfiend21/softarchcert-win25 ../softarchcert-win25
cp .harness/app.json.example .harness/app.json
# edit .harness/app.json → "app_root": "../softarchcert-win25"
./scripts/app-root.sh                     # must print the abs path (exit 0). Empty/missing tree → exit 2 (refused).
```

## 4. PATH A — Audit the existing code (recommended first; cheap, gives ground truth)

Run the real detectors against the tree (over-scope all 46 rules; `not_applicable` is harmless):

```bash
PR=.harness/plugin-cache/claude-tdd-pro
ALL=$(node -e 'process.stdout.write(require("./.harness/rules/active.json").rules.map(r=>r.id).join(","))')
CLAUDE_PLUGIN_ROOT="$PR" bash "$PR/rubric/enforce.sh" --root ../softarchcert-win25 --rules "$ALL" --json
```

**What you'll get (real result from this audit):** `pass:22 · fail:14 · not_applicable:10 · not_enforced:0`. Interpret the 14 fails by category:

| Category | Rules | Verdict |
|---|---|---|
| **Real code gaps — FIX** | `g-ts-001/002/004/005/006/007/008` (no-any, no-default-export, no-eval, strict-eq, type-test-coverage, strict-tsconfig, prefer-const), `g-node-002/005/006/007/009` (naked-throw family) | Genuine — fix under RGR (mostly in `reference-impl/test/**`, which the first attempt never scoped). |
| **Real doc gap — FIX or scope** | `g-doc-001` (ADR structural conformance) over 33 `.md` | Bring ADRs to Status/Context/Decision/Consequences, or scope to the `adr/` dir only. |
| **Cross-provider artifacts — SCOPE OUT** | `g-azure-encrypt-at-rest` (+ any gcp/azure rule) | The project is **AWS** — Azure/GCP rules don't apply. Don't enforce them; scope to `aws/hashicorp/us-government/linux-foundation/security-governance`. |
| **Not applicable (fine)** | all `g-react-*` (0 files) | No React in the app. Neutral. |

**Fix loop:** for each real fail, fix the code/test/ADR, then re-run the command above (or per-rule: `enforce.sh --root ../softarchcert-win25 --rule g-ts-006 --json`) until the real set is `pass`/`not_applicable`. **Done when** no `fail` and no `not_enforced` remain for the project-applicable rules.

## 5. PATH B — Rewrite it correctly through the loop (strongest "generated-under-enforcement" trail)

Drive only the sanctioned commands, in plain language, letting CTP architect and GCTP enforce:

```
/consult     # CTP's architecture engine designs under standards (cite-or-decline); GCTP translates + cross-checks
/roadmap     # sized, sequenced tickets
/decompose   # Fix A: each ticket's applicable_rules = language floor ∪ all g-universal-* ∪ EO (typed globs!)
/dispatch    # emit the contract-valid request per ticket
/inner-loop  # Fix B: runs enforce-standards.sh against app_root, writes rules_verified from REAL verdicts; fail/not_enforced ⇒ red
/audit       # Fix C: dynamic gate re-runs detectors — a green that claims pass on violating code is rejected
```

Per ticket, the inner loop now self-checks:

```bash
./scripts/enforce-standards.sh --ticket TICKET-NNN --json   # pass/fail/not_applicable/not_enforced + files_evaluated
```

The app code lands in `app_root`, enforced green for real — no asserted passes.

## 6. Definition of done (either path)

- `enforce.sh` (or `/audit`) shows **0 `fail`, 0 `not_enforced`** for project-applicable rules; remaining are `pass`/`not_applicable`.
- ADRs pass `g-doc-001` (or are scoped with rationale).
- `tsc --noEmit` clean + tests pass (the architecture proof) **plus** detector-green (the new bar).

## 7. Honest notes

- **The first attempt wasn't lying so much as un-enforced:** it scoped only `g-node-001/008` and never re-ran detectors. The 14 fails above were always there (esp. in test files) — now they're *visible and gated*.
- **Cross-provider scoping matters:** over-scoping is safe at the detector level (`not_applicable`), but for a clean gate, scope to the project's actual cloud (AWS here). Fix A's per-ticket union does this when `file_scope` globs are typed.
- **The compact binds the agent:** act as GCTP's user — don't hand-author architecture or code for the product; CTP generates, GCTP enforces. Harness self-maintenance is the only exception.

---

**Recommendation:** run PATH A first (ground-truth audit, ~seconds, proves the loop on the existing work), then fix the real reds in place — the architecture itself stood up; only code-rule + ADR-structure conformance was missing. Reserve PATH B (full rewrite) for the pristine generation-under-enforcement provenance trail.
