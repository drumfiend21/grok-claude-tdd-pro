# PROPOSAL-002 — App-Enforcement Spine: make CTP standards actually run on everything written to disk

**Status:** Draft / RFC for the GCTP and CTP development chats
**Author provenance:** discovered during the SoftArchCert O'Reilly win25 kata build, where
the architecture substance came from CTP via GCTP and the IaC was enforced, but the
TypeScript and prose were **not** run through CTP's detectors.
**Authority:** TIER-1 process change; lands per `docs/architecture-principles.md §19` (ADR).
Respects the prime directive — GCTP owns the enforcement spine; CTP owns rule content; the
two meet at the contract surface (`.harness/rules/active.json` + the pinned plugin-cache
detectors). No cross-repo edits.

---

## 0. Goal & confirmed failure

**Goal:** every artifact an app build writes to disk must be **evaluated by CTP's
standards/detectors, driven through GCTP** — not merely *claimed* conformant in a `res.json`.

**Confirmed failure (evidence — SoftArchCert win25 run):**
- Only `g-node-001` + `g-node-008` were ever in any code ticket's `applicable_rules`. The
  full TypeScript ruleset was never scoped.
- Running CTP's detectors manually afterward: `no-any` **fails** (`confidence_gate/index.ts:28`
  +others), `naked-throw` **fails** (8 sites), `type-test-coverage` **fails**. The TS was both
  **under-scoped** and **actually non-conformant**.
- Only the IaC was actually run through CTP (`cloud-guidance-rule.sh`, 10/10 green). Markdown
  had nothing run on it (no Markdown detectors exist).
- `audit-rules-verified` was green only because it checks that `res.json` *claims* cover the
  named rules — it never re-runs detectors. `post-tool-use-review-gate.sh` only checks path
  fences, not standards content.

**Three structural gaps + one decision:** (A) decompose under-scopes rules; (B) nothing runs
CTP detectors against the app working tree; (C) the gate trusts claims instead of re-running;
(D) prose/Markdown/Python have no detectors at all.

---

## WORK ORDER 1 — GCTP repo (`grok-claude-tdd-pro`)

Land each as a CL + ADR. Harness-spine changes; reads CTP rule *content* only via the contract
(`active.json` + pinned plugin-cache detector scripts).

### Fix A — `/decompose` must union the detected-language ruleset (root cause of under-scoping)
- **Files:** `.grok/templates/decomposition.md` (Consult-artifact consumption), `.claude/commands/decompose.md`, `.cursor/commands/decompose.md`.
- **Bug:** the ADR-0056 consult-artifact path takes `applicable_rules` verbatim from the
  artifact's `decisions[]`, silently dropping the template's own pre-emit requirement
  ("populate `applicable_rules` by filtering `active.json` by detected language").
- **Change:** per ticket, `applicable_rules = (artifact decision rules) ∪ (active.json rules
  whose applies/glob matches the ticket's file_scope.may_edit languages) ∪ (all EO-namespace
  rules)`. Detect language from `may_edit` extensions (`.ts/.tsx/.js → node+ts+react`;
  `.tf/.bicep → aws/azure/gcp/hashicorp/us-government/security-governance`; `.yaml/.yml →
  linux-foundation`; …).
- **Acceptance:** a `reference-impl/src/**.ts` ticket carries `g-ts-001/002/003/…`,
  `g-node-001..010` AND the EO rules — not just the consult subset. Unit test for a `.ts` and a
  `.tf` ticket.

### Fix B — `/inner-loop` must RUN CTP detectors against the app tree and derive `rules_verified` from real results
- **New file:** `scripts/enforce-standards.sh --app <dir> --paths <globs> --rules <ids>` — the
  enforcement spine. For each rule id: read its `detector` from `active.json`, locate it in the
  pinned plugin cache, invoke it against the app paths (script detectors take `--paths`;
  `cloud-guidance-rule.sh` takes `--rule … --root …`), collect `pass|fail` from the real exit
  code, emit JSON `{rule: pass|fail, evidence}`. (Prefer driving CTP's `runner.sh` once Fix E
  lands, to avoid re-implementing per-detector dispatch.)
- **Files:** `.claude/commands/inner-loop.md`, `.cursor/commands/inner-loop.md` — add a
  mandatory step between Green and res.json: run `enforce-standards.sh` for the ticket's
  `applicable_rules` against its `file_scope`; **write `rules_verified` straight from those
  results**; any `fail` ⇒ `status: red` (fix, never assert).
- **Acceptance:** an inner-loop on a ticket whose code contains `any` yields
  `rules_verified["g-ts-001"]="fail"` + red — never a green claim. Hermetic test with a
  violating fixture.

### Fix C — make the gate DYNAMIC (re-run, don't trust)
- **Files:** `scripts/audit-rules-verified.sh` (or a new `scripts/audit-standards-enforced.sh`
  wired into `/audit`).
- **Change:** for handoffs whose deliverables live in an app working tree, **re-run
  `enforce-standards.sh`** for `applicable_rules` and assert live results match the `res.json`
  `rules_verified` claims; mismatch ⇒ gate red. Converts "claims complete" → "claims true."
- **Acceptance:** tampering a `res.json` to claim `pass` on a violated rule makes `/audit` fail.

### Fix D — give GCTP a first-class "external app working tree" model
- **Why:** today `/consult` `/decompose` `/inner-loop` `/audit` operate on `.harness/*`; there
  is no notion that the app lives in a separate gitignored subfolder that must be enforced —
  so A–C have nowhere to point.
- **Change:** add an `app_root` concept (config or per-feature field, e.g. in the consult
  artifact or a `.harness/app.json`) consumed by all four commands; `enforce-standards.sh` +
  the dynamic gate target `app_root`. Document in `docs/handoff-contract.md`.
- **Acceptance:** a smoke test builds a 1-file TS app in a subfolder and shows the full
  `consult→…→audit` chain enforcing on it.

---

## WORK ORDER 2 — CTP repo (`claude-tdd-pro`) — file upstream; do NOT edit from GCTP

### Fix E — `rubric/runner.sh` must target an external tree
- **Today:** modes are `--full/--diff/--staged/--rule/--severity/--json/--md/--quiet`, all
  scoped to the harness's own git working tree. No `--root <dir>`/`--paths <glob>` to evaluate
  an arbitrary app directory.
- **Ask:** add `--root <dir>` and/or `--paths <glob>` passthrough so a consumer can run the
  single runner entrypoint against an external app tree restricted to a rule set, exit code
  reflecting findings. Lets GCTP call one stable contract surface instead of duplicating
  CTP-owned per-detector dispatch (which would risk drift).
- **Acceptance:** `runner.sh --root /path/to/app --rule g-ts-001 --quiet` exits non-zero iff
  the app violates that rule.

### Fix F (DECISION POINT) — prose / Markdown / Python enforcement
- **Reality:** CTP ships **no Markdown or Python detectors**, so ADRs, design docs, and any
  Python deliverable can never be *content-enforced* — only cited. The stated goal ("CTP
  controls the substance of everything written") is **unachievable for prose** until one of:
  1. **CTP adds doc detectors** — ADR structural conformance (Status/Context/Decision/
     Consequences present), citation-presence, no-dangling-rule-ids. (Note: "did not invent
     architecture" is not mechanically checkable — that stays a cross-check-at-decision-level
     guarantee, not a detector.)
  2. **Accept a documented boundary:** prose is governed by the `architecture-crosscheck` gate
     at the *decision* level (ADRs are expansions of cross-checked decisions) + a structural
     ADR-lint in GCTP; prose *content substance* is explicitly out of detector scope.
- **Action:** CTP picks 1 or 2 and records it in an ADR; GCTP's `/audit` is updated to match.
  **This decision determines whether the original goal is literally attainable or must be
  scoped to "all code + IaC, plus decision-level governance for prose."**

---

## Validation (proves the goal once Work Orders 1+2 land)

1. Re-pin GCTP to the CTP commit carrying Fix E.
2. Re-run the SoftArchCert build end to end (`/consult … /audit`) against
   `app_root=softarchcert-win25`.
3. **Expected:** decompose scopes the full TS ruleset; the inner-loop's `enforce-standards.sh`
   **fails** on the current TypeScript (no-any, naked-throw×8, type-test-coverage) → red →
   fixed under RGR until detectors are genuinely green; `/audit`'s dynamic gate re-runs
   detectors and passes only because they actually pass. Prose handled per Fix F.
4. **Done =** every code/IaC file's `rules_verified` is backed by a live detector run recorded
   in the trail, and `/audit` re-verifies it — no asserted passes anywhere.

---

## Honest scope note

Work Orders 1–2 make **code + IaC** truly CTP-enforced end-to-end. Whether **prose** (the
ADRs/docs that are most of an architecture submission) can be "run by CTP" at all depends
entirely on Fix F — the single most important decision for the stated goal, because today the
bulk of a kata submission is prose that CTP has no mechanism to evaluate.
