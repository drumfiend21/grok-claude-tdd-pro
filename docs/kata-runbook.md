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
cd grok-claude-tdd-pro                                          # main tip; for the KATA session use branch dev/kata-2026-07-03-consult
```

## 2. Bootstrap the harness (in order)

```bash
./scripts/sync-plugin.sh --ensure        # materializes CTP plugin @ pinned f39fcdc (2026-07-06) + skills +
                                         # active.json (118 rules across 43 namespaces). At this pin: §29..§29.6
                                         # (full-surface consult grounding + byte-identical native enforcement),
                                         # §30 (full-surface intake — workload classifier + per-namespace probe
                                         # groups), §30.1 (design engines consume the probes), §30.2 (precise
                                         # cloud classification + IaC probe coverage + unprobed_in_scope
                                         # transparency marker), and §30.3 (word-boundary signal matching so
                                         # compact tokens like `aks`/`ci`/`spa` don't phantom-match inside
                                         # larger business words like `leaks`/`certification`/`space`) —
                                         # see ADR-0086/0087/0088/0089/0090.
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

Run the real detectors against the tree (over-scope all 118 rules; `not_applicable` is harmless):

```bash
PR=.harness/plugin-cache/claude-tdd-pro
ALL=$(node -e 'process.stdout.write(require("./.harness/rules/active.json").rules.map(r=>r.id).join(","))')
CLAUDE_PLUGIN_ROOT="$PR" bash "$PR/rubric/enforce.sh" --root ../softarchcert-win25 --rules "$ALL" --json
```

**What you'll get (numbers below are the audit result at the historical pin `7a7f74d` / 46 rules — kept as an illustrative shape, NOT a target).** At today's pin `f39fcdc` / 118 rules the counts will be larger (more rules in scope means more `pass` and more `not_applicable`); the *interpretation* of the failure categories still applies. Re-run at the current pin to get the ground-truth numbers for this kata. Historical snapshot: `pass:22 · fail:14 · not_applicable:10 · not_enforced:0`. Interpret the 14 fails by category:

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
/consult     # Crossroads/translator loop (ADR-0056):
             #   Stage 0 — S-57 --classify reveal. CTP infers workload_types from the vision;
             #             GCTP translates plainly ("public-facing REST API on Kubernetes with an
             #             AWS deployment") and confirms with the operator. At pin 43ea692+
             #             (§30.2): classification is PRECISE — a pure-AWS kata is probed for
             #             aws+cfn only, not Azure/GCP. Any in-scope namespace without a probe
             #             group appears in unprobed_in_scope — visible, never silent. NEW at
             #             pin f39fcdc (§30.3): signal matching is WORD-BOUNDARY — compact
             #             tokens like `aks`/`ci`/`spa` no longer phantom-match inside
             #             larger business words (`leaks`/`certification`/`space`), so an
             #             AI-credentialing vision classifies cleanly (ai-governed +
             #             baseline-quality) instead of dragging in Azure/K8s/CI-CD phantoms.
             #   Stage 1 — universal 9 (S-32, unchanged). Business language, one at a time.
             #   Stage 2 — activated per-namespace probes (§30 / S-57). e.g. jwt token lifetime,
             #             react rendering model, k8s multitenancy, aws region strategy — CTP
             #             grounded in a cite-or-decline source, GCTP translated to plain business
             #             language. Each answered probe becomes a COMMITTED POSTURE the design
             #             engines honor (§30.1 / S-33 / S-34): translate emits a grounded concern,
             #             recommend can let a decisive commitment modestly move the pick.
             #   Per juncture — CTP proposes under enforcement (google/owasp/EO/SLSA/…); GCTP
             #                   cross-checks against active.json + R/D/G/C-rules + EO spine.
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

---

## PATH C — fix architectural prose under enforcement (after PROPOSAL-003 lands)

Once the upstream PROPOSAL-003 lands in CTP and a pin bump adopts the new namespaces + `prose-judge.sh`, the harness's design-phase MD gate (ADR-0066 D-D, `scripts/audit-design-phase-md.sh`) activates. Then every `.md` under `docs/architecture/**`, `docs/adr/**`, or `docs/decisions/**` (and any `.md` with frontmatter `kind: architecture | adr | decision`) is scored against every rule in `active.json` carrying `applies_to_prose: true` **before** `/dispatch` will emit the request. PATH C is the operator workflow for that gate.

### Trigger

The gate fires when, in any handoff request whose `file_scope.may_edit` includes an architectural `.md` glob, an applicable `applies_to_prose: true` rule (e.g. `g-aws-no-unrestricted-ingress`) reports a violation in the design prose without a matching deviation row.

### Two operator paths when the gate blocks

**Path 1 — rewrite the prose.** The cheap path. The judge flagged a concrete claim (e.g. an ADR proposing `0.0.0.0/0` ingress on the dev cluster). Edit the section so the proposed design no longer violates the rule, then re-run `/dispatch`. The judge re-tokenizes, the section hash changes, cache miss, judge replies NO. Verdict: GREEN. Dispatch proceeds.

**Path 2 — file a deviation.** The right path when the rule legitimately cannot apply in this context (e.g., a cross-provider rule on a single-cloud project, or a rule whose premise doesn't hold for an isolated subsystem). Add a row to `<app_root>/docs/deviations.md`:

```bash
cp docs/deviations-template.md "$APP_ROOT/docs/deviations.md"     # first time only
# then append a Deviation section per the template:
#   ## Deviation — <RULE-ID> on <TICKET-ID>
#   - **Rule:** ...
#   - **Why-cannot-apply:** ... (cite the ADR that locks the scope)
#   - **Operator acceptance:** <email> on YYYY-MM-DD
#   - **Re-eval condition:** ...
```

Then re-run `/dispatch`. The gate matches the heading, treats the rule as `deviated`-as-green, and dispatch proceeds with the deviation visible in the audit trail.

### What the gate does NOT do

- It does not silently exclude any rule. Every rule that fires either passes, is deviated, or is red — never dropped.
- It does not run on plain `.md` files (README, CHANGELOG, notes) — only on architectural docs by path heuristic or frontmatter `kind`.
- It does not run when `active.json` has no `applies_to_prose: true` rules (which is today's state, before PROPOSAL-003 lands).

### Reference

- Spec: `docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md` (especially the "Worked example" §).
- Script: `scripts/audit-design-phase-md.sh` (run standalone for diagnosis).
- Deviation template: `docs/deviations-template.md` (copy to `<app_root>/docs/deviations.md`).
