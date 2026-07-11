# GCTP → CTP handoff — P-21 — investigate why the C-13 `COMPLIANCE-URLS.yaml` → `generated-code-quality-standards/<jurisdiction-namespace>/` sync (§5 architecture G-9.1) has not populated `european-union/`, `finance-industry/`, or `industry-self-regulatory/` rule surfaces, leaving `active.json` with **0 rules** for those three namespaces even though 24 authoritative compliance URLs are documented and 24 fetcher scripts exist

**Written:** 2026-07-11 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `724fc4c`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟡 **INVESTIGATION REQUEST + CONTRACT-DESIGN HANDOFF** — pipeline gap surfaced by KA-5 (TICKET-130, 2026-07-10). Operator confirmed URLs ARE documented in the repo; independent verification of the pinned plugin cache at `724fc4c` confirms 24 compliance URLs in `.claude-tdd-pro/COMPLIANCE-URLS.yaml` (14 US-government + 4 European Union + 6 international) and 24 fetcher scripts in `compliance/fetchers/`, BUT the target rule directories are empty and the aggregated rule surface (`active.json`) carries 0 rules for the jurisdictional namespaces. Cross-plugin question: is this an unrun sync, an unimplemented C-N feature, or a missing rule-authoring step? Requires CTP-side diagnosis + a decision on remediation shape.
**Prior turns:**
- KA-5 (TICKET-130 `a170ba3`, 2026-07-10): `kata commit` transform reduced invariant-4 violations 10 → 2; remaining 2 flag `european-union` and `finance-industry` as "activated probe but no rules to reference." Filed as KA-5 G-1 candidate for upstream contract design.
- Operator directive: *"I've got plenty of rules for European Union and finance industry. I mean, I've provided URLs for them. Are those rules not surfacing? based on the four axis naming registry?"*
- Independent investigation of the pinned plugin cache (this handoff §1 below) confirms the URLs are documented but the downstream rule surfaces are empty.

---

## 0. TL;DR

- **What operator provided**: 24 compliance framework URLs at `.claude-tdd-pro/COMPLIANCE-URLS.yaml` per C-13 spec — includes 4 EU sources (EU AI Act at `eur-lex.europa.eu/eli/reg/2024/1689/oj`, EDPB Guidance at `edpb.europa.eu`, GDPR at `eur-lex.europa.eu/eli/reg/2016/679/oj`, DORA at `eur-lex.europa.eu/eli/reg/2022/2554/oj`) and 8 finance-industry sources (FFIEC ITS/CAT, OCC Heightened Standards, SEC Cyber Disclosure, SOX ITCC, HIPAA Security Rule, PCI-DSS v4, SOC 2 TSC).
- **What exists on the plugin side**: fetcher scripts for every URL at `compliance/fetchers/{dora,eu-ai-act,gdpr,eu-ai-act-edpb-guidance,ffiec-cat,ffiec-its,hipaa-security-rule,sec-cyber-disclosure,sox-itcc}.sh`; validator scripts at `rubric/detectors/validate-compliance-{urls,fetchers}.sh`; target directories at `generated-code-quality-standards/{european-union,finance-industry,industry-self-regulatory}/`; architecture §5 (line 432) states *"Each `COMPLIANCE-URLS.yaml` entry maps to a folder under `generated-code-quality-standards/<jurisdiction-namespace>/` (G-9.1 sync)"*.
- **What's missing**: the target directories are **empty**; `active.json` at the current pin `724fc4c` carries **0 rules** with `source_namespace: european-union`, `source_namespace: finance-industry`, or `source_namespace: industry-self-regulatory`. The G-9.1 sync from documented URL → extracted rule YAMLs has not run (or ran and did not commit output).
- **Downstream impact on GCTP**: `regulated` workload activates `european-union` and `finance-industry` probes; `--list-questions` emits `european_union_ai_act_tier` and `finance_industry_data_residency` probe questions; invariant-4 audit demands every activated probe namespace propagate into at least one design decision's `applicable_rules` — but **no rules exist to propagate**. This is genuinely unsatisfiable for empty namespaces by construction. KA-5 cross-check reports 2 legitimate violations (down from 10 pre-`kata commit` transform) — both flag `european-union` and `finance-industry`.
- **Ask**: CTP diagnose the pipeline gap and choose a remediation shape.

---

## 1. Investigation (what GCTP observed in the pinned plugin cache at `724fc4c`)

### 1.1. URLs ARE documented

`.claude-tdd-pro/COMPLIANCE-URLS.yaml` — 24 entries by jurisdiction:

| Jurisdiction | Count | Entries |
|---|---|---|
| `european-union` | 4 | `eu-ai-act`, `eu-ai-act-edpb-guidance`, `gdpr`, `dora` |
| `us-government` | 14 | NIST AI RMF + 800-218/218a + CSF 2 + 800-53r5 + 800-171r3, FedRAMP mod/high, FFIEC ITS/CAT, OCC Heightened Standards, SEC Cyber Disclosure, SOX ITCC, HIPAA Security Rule |
| `international` | 6 | PCI-DSS v4, SLSA, OWASP ASVS, ISO 27001 A14, ISO 27017, SOC 2 TSC |

Every entry has `url`, `authoritative_publisher`, `jurisdiction`, `applicable_to`, `identifier_scheme`, `why_authoritative`, `fetch_frequency`, `legal_review_required`, `paywalled`, `fetcher`. Full C-13 shape.

### 1.2. Fetcher scripts EXIST

`compliance/fetchers/` lists 24 executable scripts matching the URL entries (`dora.sh`, `eu-ai-act.sh`, `gdpr.sh`, `eu-ai-act-edpb-guidance.sh`, `ffiec-cat.sh`, `ffiec-its.sh`, `hipaa-security-rule.sh`, `sec-cyber-disclosure.sh`, `sox-itcc.sh`, plus US-government + international scripts).

### 1.3. Target directories EXIST but are EMPTY

`generated-code-quality-standards/`:
- `european-union/` → 0 rule YAMLs
- `finance-industry/` → 0 rule YAMLs
- `industry-self-regulatory/` → 0 rule YAMLs

### 1.4. Aggregated rule surface has 0 jurisdictional rules

`active.json` (regenerated at pin `724fc4c` via `scripts/standards-sync.sh`) — 118 rules total, distributed as:

| Namespace | Rule count |
|---|---|
| `k8s` | 10 |
| `google` | 6 |
| `node` | 6 |
| `react` | 6 |
| `compose` | 5 |
| `gha` | 5 |
| ... (13 more populated namespaces) | ... |
| **`european-union`** | **0** |
| **`finance-industry`** | **0** |
| **`industry-self-regulatory`** | **0** |
| `eo` | 0 |
| `us-government` | 2 (from a different code path — `g-us-government-encrypt-at-rest` + `-audit-logging`) |

The 2 `us-government` rules are the exception — they arrive via a different mechanism (likely hand-authored under `generated-code-quality-standards/us-government/`, not fetcher-derived from COMPLIANCE-URLS). Every other jurisdictional namespace has 0.

### 1.5. Architecture spec (§5, line 432)

Quoted verbatim from the plugin's `docs/architecture-v1.9.md`:

> *Each `COMPLIANCE-URLS.yaml` entry maps to a folder under `generated-code-quality-standards/<jurisdiction-namespace>/` (G-9.1 sync: US Federal → `us-government/`, EU → `european-union/`).*

The mapping is explicit. The sync just hasn't materialized for the EU + international jurisdictions.

### 1.6. Auto-refresh scaffolding EXISTS

- `compliance/auto-refresh-daily.sh` (C-19: first-use-of-day auto-refresh)
- `rubric/detectors/validate-compliance-urls.sh`
- `rubric/detectors/validate-compliance-fetchers.sh`
- `commands/compliance-add.sh` (operator-facing add flow)

Which suggests the pipeline was *designed* to run. Not manually triggered? Not connected to the aggregator?

---

## 2. Cross-plugin diagnosis request

Three candidate root causes, in decreasing likelihood (GCTP's read from the outside):

### 2.1. Candidate A — Fetchers exist but were never invoked; no rule extraction ran

Each `compliance/fetchers/<id>.sh` is a wrapper around the URL fetch. Perhaps the design intent was for a downstream step to extract the fetched content into rule YAMLs, and that extraction has not run (or has not committed output).

**Diagnostic**: does invoking `bash compliance/fetchers/gdpr.sh` produce output? Does anything downstream turn the output into `generated-code-quality-standards/european-union/gdpr-*.yaml` rule files?

### 2.2. Candidate B — The fetch pipeline is designed to be operator-triggered per-project, not shipped

C-13 says "operator-editable registry"; C-19 says "first-use-of-day auto-refresh." If the design is that the operator opts in (perhaps via `compliance-add.sh`), that would explain shipped-but-empty state.

**Diagnostic**: is there a documented operator flow to populate `european-union/` rules? If yes, GCTP's kata driver should invoke it as part of intake. If no, the discoverability is the gap.

### 2.3. Candidate C — Feature is DEFERRED / not yet built

The architecture describes the sync (§5, G-9.1) but implementation may be scheduled for a later CL. `active.json` at `724fc4c` reflects reality: the sync hasn't been implemented for the jurisdictional namespaces yet.

**Diagnostic**: what's the shipping status of G-9.1 sync per §20 execution order? Is it targeted at a future CL, or was it shipped but broke silently?

---

## 3. Remediation shapes to consider (CTP's choice)

**Shape A — CTP ships the sync + populates rules from the fetchers.** Every `COMPLIANCE-URLS.yaml` entry gets extracted into rule YAMLs under `generated-code-quality-standards/<jurisdiction>/`. Aggregator picks them up. `active.json` grows. GCTP re-pins per §15 ADR (same pattern as ADR-0092/0093/0094).

*Pros*: closes the honest KA-5 finding; regulatory workloads finally have enforcement teeth; matches architecture §5 spec.
*Cons*: rule authorship effort — someone has to write real rule YAMLs from the fetched EU AI Act text, GDPR articles, DORA obligations, etc. (or CTP defines automated extraction).

**Shape B — Operator-triggered flow via `compliance-add.sh`.** The plugin already ships `commands/compliance-add.sh`. If the operator is expected to invoke it, GCTP's kata driver can do so during intake when `regulated` workload fires. No change to CTP.

*Pros*: no CTP-side rule authorship needed.
*Cons*: doesn't match the "shipped rule surface" expectation; operator UX has an invisible step.

**Shape C — Empty-namespace tolerance in invariant-4 (GCTP-side)**. GCTP softens `audit-architecture-crosscheck.sh` invariant-4 to accept `namespace with 0 rules in active.json` as a valid vacuous case. The activated probe was answered (probe question exists); rules simply aren't enforceable yet.

*Pros*: no CTP change; unblocks kata runs immediately.
*Cons*: hides the real gap; regulated workloads pass cross-check without any actual enforcement.

**GCTP's leaning: Shape A** (populate the rules), with **Shape C as a stopgap** (empty-namespace tolerance) until Shape A ships. The operator's directive was that the URLs are provided — Shape A honors that directive; Shape C is a temporary bypass.

---

## 4. Additive per ADR-0047

Whichever shape CTP picks, all three are additive:
- Shape A adds rule YAMLs under existing namespace directories (never removes an existing rule).
- Shape B adds a documented operator flow (uses existing commands).
- Shape C adds a permissive branch to invariant-4 (never rejects an accepted namespace).

Cite-or-decline preserved: no fabricated rules; every rule that lands must cite its source URL from `COMPLIANCE-URLS.yaml`.

---

## 5. Ask (CTP-side)

1. **Confirm which candidate root cause (§2.1–§2.3) matches CTP's shipping status of the G-9.1 sync.**
2. **Pick a remediation shape (§3.A/B/C) or propose a counter-shape.**
3. **If Shape A**: file as a §31.x amendment + companion CL landing the rule YAMLs. GCTP re-pins per §15 ADR following ADR-0092/0093/0094 precedent.
4. **If Shape B**: document the operator flow in the plugin `.claude-tdd-pro/COMPLIANCE-URLS.yaml` header + provide the invocation contract. GCTP's kata driver adds a `kata compliance-add <framework-id> --project <id>` verb.
5. **If Shape C**: GCTP softens `scripts/audit-architecture-crosscheck.sh` invariant-4 unilaterally — no CTP change; land under a new GCTP ticket with a test.

---

## 6. Meta-note on the cross-plugin contract

Per the operator's guidance to "design contracts between both plugins in this single chat" (2026-07-10): this is exactly that pattern. GCTP discovered the gap via KA-5's iteration; independently verified against the pinned plugin at `724fc4c`; brought it back to this chat as a documented investigation request. Whether CTP diagnoses via reading this handoff or independently reproduces, the finding stands: **shipped URLs + shipped fetchers + empty rule surfaces = pipeline seam broke somewhere between `.claude-tdd-pro/COMPLIANCE-URLS.yaml` and `generated-code-quality-standards/<jurisdiction>/`.**

Filed as **P-21** in `docs/upstream-ctp-proposals.md`. Awaiting CTP consult.

Ready when you are.
