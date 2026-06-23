# ADR-0068 — GCTP-side composite engine wiring

- **Status:** Accepted (2026-06-23 — promoted from Proposed on CL-B wiring landing per ADR-0070)
- **Date:** 2026-06-22 (drafted) / 2026-06-23 (W-A + W-B wired marker-gated; hard-require paragraph added; promoted Accepted)
- **Deciders:** drumfiend21 + Claude Opus 4.7 (GCTP cloud session).
- **Pairs with:** **CTP-ADR-0008** (composite engine + 4-axis canonical vocabulary + architectural-content bundle) — lives at `.harness/plugin-cache/claude-tdd-pro/docs/adr/0008-composite-engine-and-4-axis-canonical-vocabulary.md` at pin `230e99d`+.
- **Composes on:** ADR-0046 (two-phase enforcement), ADR-0055 (EO-spine activation), ADR-0058 (`enforce.sh` `not_applicable` neutral), ADR-0060 (Fix A — decompose union + language-floor gate), ADR-0062 (Fix B — `enforce-standards.sh` real verdicts), ADR-0063 (Fix C — dynamic re-run gate), ADR-0066 (YAML/JSON/MD corpora + prose-as-code), ADR-0067 (pin bump to 39903da), **ADR-0070 (pin bump to 230e99d — activation event + no-rewrites discipline this ADR inherits).**

## No-rewrites discipline (inherited from ADR-0070)

Per ADR-0070 §No-rewrites: this ADR's wiring CLs (W-A through W-E) MUST NOT mass-modify `.harness/handoffs/*` runtime state to satisfy new gates. When a wiring CL adds a new audit check that reds on legacy data, the CL documents the surfaced reds in this ADR's "Known follow-up" section and commits clean. Operator re-runs of `/decompose`/`/inner-loop` close legacy gaps naturally as those tickets next come into scope. This discipline is binding on every wiring CL touching this ADR.

## Trigger

CTP-ADR-NNNN lands the composite engine in the CTP plugin: ~115 FOSS tool runners under `composite/runners/`, a 4-axis canonical vocabulary at `vendor/canonical-vocabulary/`, the architectural-content bundle, two-phase enforcement, and the SARIF universal bus. GCTP — as the consumer — must wire these into the existing audit chain WITHOUT violating the prime directive (no cross-repo edits to CTP).

This ADR governs the GCTP-side wiring. It is paired with CTP-ADR-NNNN; neither side touches the other. The contract surface remains `active.json` + the canonical vocabulary mirrors + SARIF + the four CTP-shipped runtime scripts.

## Context

When CTP-ADR-NNNN ships and a pin bump (separate GCTP ADR) adopts it, the harness's existing audit chain needs five things from GCTP's side to consume the engine cleanly:

1. **Schema-aware audit gate.** `audit-applicable-rules.sh` (ADR-0060) must understand the new `applies_to.*` + `applies_to_prose` schema and produce the same applicable-rules union it does today, but with the 4-axis tagging as the authoritative join key.
2. **Composite-engine invocation.** `enforce-standards.sh` (Fix B / ADR-0062) must drive the composite engine across the app tree at audit time, consuming the SARIF aggregator output.
3. **Two-phase wiring.** The post-tool-use hook (CL-E / TICKET-081) must invoke the composite engine on the touched file; the (future) PreToolUse strict variant uses the same dispatch.
4. **Bundle activation.** The dispatch design-phase MD gate (CL-C) must invoke `bundle: architectural-content` on every architectural .md, automatically.
5. **Deviation discipline.** The `## Deviation` row mechanism in `<app_root>/docs/deviations.md` (ADR-0066 D-F) extends to cover composite-engine verdicts.

The harness MUST NOT mirror any tool runners, schemas, or bundle definitions — those are CTP-owned content. The harness owns the **enforcement spine**; the plugin owns the **engine and the rule content**. The two meet at the contract surface (`active.json` + SARIF) — neither reaches into the other.

## Decision

Five decisions; D-A through D-E. Each defines a wiring change. Implementation is itemized as wiring CLs (W-A through W-E) below.

### D-A. Extend `audit-applicable-rules.sh` to consume the 4-axis schema.

The static gate (ADR-0060) currently gates by typed `file_scope.may_edit` glob extensions. This ADR extends it:

1. For each rule in `active.json`, read `applies_to.linguist_aliases`, `applies_to.iac_dialects`, `applies_to.purl_uses`, `applies_to.k8s_gvks`, and `applies_to_prose`.
2. For each file in the ticket's `file_scope.may_edit`, detect its canonical kinds via Linguist + IaC + PURL + GVK detectors (CTP-shipped or via tool-introspection).
3. A rule is applicable to a file iff:
   - `applies_to.*` intersects the file's kinds, OR
   - `applies_to_prose: true` AND the file is architectural content (via `composite/detect-architectural-content.sh`), OR
   - The rule is in the universal floor (`_universal` namespace, per ADR-0060), OR
   - The rule is in the EO floor (`source_namespace: eo | security-governance`, per ADR-0055).
4. The applicable-rules union goes into the ticket's `applicable_rules` field at `/decompose` time (ADR-0060), unchanged in shape.

Backward compatibility: rules without `applies_to.*` (legacy `language: <string>`) get auto-synthesized via the CTP dual-read shim (CTP-ADR-NNNN G.1) — no harness change required.

### D-B. Extend `enforce-standards.sh` to drive the composite engine.

Fix B (ADR-0062) currently walks `applicable_rules` and emits per-rule verdicts. This ADR extends it:

1. For each applicable rule, walk `enforced_by[]` (after bundle expansion done by CTP at engine load).
2. For each binding, invoke the per-tool runner at `composite/runners/<tool>/runner.sh` against the relevant files in `app_root`.
3. Collect SARIF results per binding.
4. Pass to `scripts/sarif-aggregate.sh` (already shipped in CL-B) for the normalized verdict stream.
5. Write the `rules_verified` block in the response, with per-rule `pass | fail | not_enforced | not_applicable | deviated` derived from the SARIF aggregation.

Composite-engine version skew is handled by CTP's `composite/COMPAT.yaml` (CTP-ADR-NNNN L.2); GCTP reads but does not author this file.

#### D-B-1. Hard-require semantics (per CTP-ADR-0008 "Operator-directed divergence"; added 2026-06-23)

The upstream draft specified `graceful-tool-absence → not_enforced; engine continues`. The CTP-side operator overrode this to **hard-require**: a tool declared `required: true` on a rule's `enforced_by[]` is a **hard failure that BLOCKS** when the binary is absent. CTP MUST NOT claim a gate it cannot run. The 4-state `not_enforced` is retained only for tools marked `optional`/`advisory`.

GCTP-side consumer obligations (ratified by this paragraph):

1. **`enforce-standards.sh` propagates hard-require failures unchanged.** When CTP's `enforce.sh` (tree-mode) or `enforce-file.sh` (narrowed mode via W-B) returns `not_enforced` AND the underlying `enforced_by[]` binding was `required: true`, the harness surfaces this as `red` (not soft "incomplete"). This already holds via the Fix B mapping (ADR-0062): `not_enforced` → incomplete/red in `enforce-standards.sh`. The semantic refinement: when a missing tool was `required: true`, the harness treats it as `red` rather than `incomplete`. CTP determines `required` from `enforced_by[].required`; the harness reads the verdict and respects it.
2. **`audit-standards-enforced.sh` (Fix C / ADR-0063) accepts `not_enforced` only when claimed `not_enforced`.** A response claiming `pass` on a rule whose live verdict is `not_enforced` is a divergence — already enforced by the gate's strict equality.
3. **No silent fallback.** The harness MUST NOT downgrade a hard-require `not_enforced` to a green/advisory state. If the operator's environment lacks a required binary, the gate reds and the inner loop blocks — deliberate fail-closed posture.

This paragraph is **binding policy**, not advisory. Operator-side relaxation requires a separate ADR + a `## Deviation` row in `<app_root>/docs/deviations.md` (ADR-0066 D-F).

### D-C. Extend the post-tool-use hook (CL-E) to invoke the composite engine.

The existing `post-tool-use-review-gate.sh`:

1. Detects the just-written file.
2. Invokes `composite/dispatch.sh` (CTP-shipped) with the file path.
3. Receives a SARIF verdict.
4. If any P0 violation, exits non-zero (Claude Code displays the violation inline).

For architectural .md files, `detect-architectural-content.sh` returns true → dispatch automatically activates the bundle (CTP-side; GCTP just passes the file through).

A PreToolUse strict variant (CTP-D-7a in CTP-ADR-NNNN) is deferred to a future GCTP ADR; not part of this wiring.

### D-D. Extend the dispatch design-phase MD gate (CL-C) for the architectural-content bundle.

`audit-design-phase-md.sh` (CL-C) currently runs MD-corpus rules before dispatch. This ADR extends it:

1. For every architectural .md in the app tree, invoke `composite/dispatch.sh` with the architectural-content bundle active.
2. Receive aggregated SARIF.
3. Block `/dispatch` if any P0 violation surfaces.

No new mechanism — same dispatch invocation as Fix B, scoped to whole-tree architectural content.

### D-E. Extend the deviation discipline (ADR-0066 D-F) for composite-engine verdicts.

`## Deviation` rows in `<app_root>/docs/deviations.md` map 1:1 to composite-engine rule IDs. Engine treats a deviation row as `deviated-as-green` for the named rule on the named ticket. No mechanism change; just clarifies that ADR-0066 D-F covers the new rule surface introduced by CTP-ADR-NNNN.

## Wiring CLs

| CL | Deliverable | Status | Acceptance criteria |
|---|---|---|---|
| **W-A** | `audit-applicable-rules.sh` adds 4-axis floor (rules whose `applies_to.linguist_aliases` or `applies_to.iac_dialects` intersects file_scope kinds MUST be in applicable_rules) | ✅ **DONE 2026-06-23** (CL-B, marker-gated) | Opt-in via `applies_to_floor_version >= 2` req.json marker — legacy handoffs grandfathered (no-rewrites discipline). +5 unit tests cover floor activation + legacy grandfathering |
| **W-B** | `enforce-standards.sh` gains `--changed-files <csv>` narrowed mode invoking `rubric/enforce-file.sh` per file; `audit-standards-enforced.sh` auto-passes `res.changed_files`; aggregator feeds `rules_verified` | ✅ **DONE 2026-06-23** (CL-B) | TICKET-042 deferred red (CL-A) closes via narrowing — toy file passes universal rules cleanly; tree-mode fallback preserves Fix B parity for tickets without `changed_files`. +9 unit tests cover narrowed mode + tree fallback |
| **W-C** | `post-tool-use-review-gate.sh` invokes composite engine on the touched file | ⏳ CL-C | Unit test: writing a `.tf` with `cidr_blocks = ["0.0.0.0/0"]` triggers a P0 block; writing a conformant file passes |
| **W-D** | `audit-design-phase-md.sh` invokes bundle on every architectural .md | ⏳ CL-C | E2E: a 5-ADR fixture corpus (3 valid + 2 violations) produces 2 reds and 3 greens |
| **W-E** | Deviation-row docs updated; deviations template extended (operator-facing) | ⏳ CL-C | `docs/deviations-template.md` shows the new rule-ID format; first-time guide references it |

## Known follow-up surfaced by W-B (deferred per no-rewrites discipline)

W-B's narrowing uses `enforce-file.sh` per changed file — meaningfully more accurate than tree-mode (`enforce.sh` whole-tree) because `enforce-file.sh` runs CTP's prose-as-code projection (`prose-judge.sh`) on architectural `.md` files. **Closure of TICKET-042's deferred red (ADR-0070 follow-up #3) is the direct positive consequence.**

The trade: 5 pre-existing handoff response artifacts (TICKETS 002, 003, 006, 007, 010) carry `g-aws-no-unrestricted-ingress: pass` claims that the more-accurate W-B re-run says `not_enforced` for (prose-as-code projection on those tickets' ADR `.md` files, where `prose-judge.sh` returns `not_enforced` absent `LLM_JUDGE=1`). These are stale pre-W-B truth-up gaps the gate now surfaces — not a CL-B regression; the underlying code was already correct, the gate's accuracy increased.

**Closure path (no-rewrite, operator-driven):**
- Set `LLM_JUDGE=1` in dispatch env to convert `not_enforced` → semantic verdict (P-8 fix at the new pin makes this functional), OR
- Re-run the inner loop on those tickets — W-B-aware writes honest `not_enforced` claims, gate stops diverging.

Neither is required for CL-B's correctness; the gate is doing its job by flagging the divergence. Tracked here per ADR-0070's "deferred follow-up, not data rewrite" discipline.

## Consequences

### Positive

- Composite engine becomes available to operators with no harness re-design — the audit chain just picks up the new tool stack.
- Architectural-content enforcement at write-time + audit-time fires automatically on every ADR.
- Deviation discipline scales — the same `## Deviation` row mechanism covers ~115 tools without per-tool extension.
- Engine version skew handled by CTP's compat matrix; GCTP stays version-agnostic.

### Neutral

- The harness gains no new runtime cost — dispatch is CTP-owned; harness just invokes.
- The deviation template stays the same; the rule-ID surface grows (118 rules → potentially 500-1000 after operator catalog ingest), but the row mechanism scales linearly.

### Negative / cost

- **Dependency on CTP-ADR-NNNN landing.** ~~This ADR has no value until CTP ships the engine.~~ **Resolved 2026-06-23:** CTP-ADR-0008 shipped at pin `230e99d` (ADR-0070); this ADR promoted Accepted on CL-B wiring landing.
- **Migration risk for the 118 existing rules.** Mitigation: CTP-side dual-read shim handles the transition; harness sees no change.
- **P-8 fix required upstream.** ~~Before the architectural-content bundle's semantic moat is functional.~~ **Resolved 2026-06-23:** P-8 fixed at pin `230e99d` (ADR-0070 P-8 → ADOPTED).

## Alternatives considered

- **Harness mirrors the composite engine.** REJECTED — violates prime directive. The engine is plugin-side; harness consumes via contract.
- **Harness extends the existing detector framework rather than consuming the new engine.** REJECTED — `rubric/detectors/` is a CTP-shipped surface; harness consumes via `active.json`, doesn't fork the detector framework.
- **Skip composite-engine consumption; keep using hand-rolled detectors.** REJECTED — the operator directive is to use the composite engine for quality + coverage; the hand-rolled detectors have known coverage gaps the new engine closes.
- **Wire the bundle activation in the post-tool-use hook explicitly.** REJECTED — bundle activation is engine-side at dispatch (CTP-D-5 implicit attachment). Harness should not know about bundle expansion.

## Boundary discipline (recap)

- **CTP owns** (CTP-ADR-NNNN): the composite engine runtime, per-tool runners, SARIF bus, bundle definition, canonical vocabulary mirrors, `prose-judge.sh`, `audit-source-citations.sh`.
- **GCTP owns** (this ADR): `audit-applicable-rules.sh`, `enforce-standards.sh`, the post-tool-use hook, `audit-design-phase-md.sh`, the deviation-row mechanism, the consult loop, the operator-facing CLI.
- **Operator owns**: source URLs, per-rule deviation approval, the per-tool custom-rule files committed to `.harness/operator-standards/`.

Neither side reaches into the other. Contract surface: `active.json` + canonical vocabulary mirrors + SARIF.

---

This ADR is paired with CTP-ADR-NNNN in `claude-tdd-pro`. Land on adoption of CTP-ADR-NNNN; advance to accepted at the pin bump that activates the composite engine in this harness.
