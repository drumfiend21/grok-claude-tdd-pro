# GCTP → CTP handoff — P-11: consult engines cite only an IaC/reliability subset; the full 118-rule surface (all 43 namespaces) is not reasoned against at architecture-production time

**Written:** 2026-07-03 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `a69f380` (per ADR-0085)
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Ask:** extend CTP's consult engines (`business-translate.sh` → `architect-recommend.sh` → `well-architected-review.sh`) so that architecture production reasons against the **full** aggregated standards surface — all 43 namespaces / 118 rules that `rubric/aggregator.sh` already builds — not the 5-source AWS-WA/NIST/SRE/OTel subset burned into the pillar model today. GCTP cannot fix it — the prime directive forbids GCTP editing the plugin; this is a CTP-repo change, followed by a GCTP re-pin.

Precedent: this is the mirror image of the successful P-10 handoff (`docs/handoff-ctp-p10-composite-dispatch-crash.md`, adopted in CL-538 within 24 hours, re-pinned via ADR-0079). Same pattern: file the artifact, fix upstream under CTP's own discipline, coordinate the re-pin back.

---

## 0. TL;DR

At architecture-production time (S-32 intake → S-33 translate → S-34 recommend), CTP grounds every emitted option in only **5 sources**: `aws-reliability-pillar`, `aws-rpo-rto-targets`, `nist-800-53`, `google-sre-book`, `opentelemetry-docs`. This is the AWS Well-Architected pillar model.

CTP's own `rubric/aggregator.sh` builds a **118-rule surface across 43 namespaces** (`ts`, `node`, `react`, `owasp`, `oas`, `jwt`, `web-vitals`, `w3c`, `security-governance` (EO-2026), `arch`, `doc`, `k8s`, `helm`, `sbom`, `sarif`, `iam`, `_universal`, and 26 others). **None** of these namespaces are consulted at architecture-production time. They flow into consumers only later — at rule-enforcement time — via each consumer's per-ticket rule filtering (in GCTP, ADR-0037's `applicable_rules`).

The consequence: architectures produced by CTP cannot pre-account for the code-level, contract-level, or prose-level rules that will bite at implementation time. GCTP's Stage-5 cross-check (`audit-architecture-crosscheck.sh`, per its ADR-0056) can only verify that whatever rules CTP *did* cite resolve — it cannot verify the full 118-rule surface was reasoned against, because CTP does not emit that reasoning.

One design-additive fix restores the invariant. **The rule aggregator already builds the full surface; the consult engines just need to consume it.**

## 1. The bug (exact site — with line numbers, at pin `a69f380`)

The grounding subset is not a hard-coded string list; it is an **architectural gap in the composition** between `rubric/aggregator.sh` (which knows about 118 rules across 43 namespaces) and the consult engines (which know only about the 5 Well-Architected pillars).

### 1a. `commands/business-translate.sh` — S-33 concern extraction

`business-translate.sh` reads the S-32 `business-profile.json` and produces `technical-requirements.json` shaped as:

```json
{
  "pillars": {
    "security":                [{"concern": "...", "source_id": "nist-800-53",           "driver": "..."}, ...],
    "reliability":             [{"concern": "...", "source_id": "aws-reliability-pillar", "driver": "..."}, ...],
    "performance-efficiency":  [{"concern": "...", "source_id": "opentelemetry-docs",     "driver": "..."}, ...],
    "cost-optimization":       [{"concern": "...", "source_id": "aws-rpo-rto-targets",    "driver": "..."}, ...],
    "operational-excellence":  [{"concern": "...", "source_id": "google-sre-book",        "driver": "..."}, ...]
  }
}
```

The concerns list is populated from a hand-picked source set aligned with the AWS Well-Architected pillars. There is no ingestion of `rubric/aggregator.sh` output; there is no representation of `ts`, `node`, `react`, `owasp`, `oas`, `jwt`, `web-vitals`, `w3c`, `security-governance`, `arch`, `doc`, `k8s`, `helm`, `sbom`, `sarif`, `iam`, or the 26 other namespaces.

### 1b. `commands/architect-recommend.sh` — S-34 option composer (verified: lines 66–89, pin `a69f380`)

```ruby
sec  = pil["security"] || []
rel  = pil["reliability"] || []
perf = pil["performance-efficiency"] || []
cost = pil["cost-optimization"] || []
ops  = pil["operational-excellence"] || []
...
make = lambda do |id, summary, posture, concerns, trade_offs|
  {
    ...
    "grounding" => concerns.map { |c| c["source_id"] }.compact.uniq.sort,
    ...
  }
end
```

`architect-recommend.sh` is a **faithful consumer** of the 5-pillar shape. Its `grounding` field carries exactly the `source_id`s handed to it — so its grounding is only ever as broad as `business-translate.sh` populates. If `business-translate.sh` never emits an `oas`-namespaced concern, the resulting architecture options never cite an `oas` rule.

### 1c. `commands/well-architected-review.sh` — same shape

Consumes the same pillar model. Same limitation.

### 1d. `rubric/aggregator.sh` — builds the full surface, is not consumed here

`rubric/aggregator.sh` (622 lines at pin `a69f380`) is the CTP-side canonical rule aggregator — it walks `standards/` + `rubric/` + `generated-code-quality-standards/`, produces the 118-rule / 43-namespace manifest, and is the same authoring surface that feeds GCTP's `.harness/rules/active.json` via `standards-sync.sh`. None of the three consult engines above invoke it or ingest its output.

**This is the composition gap.** The rule-authoring plane and the architecture-production plane were built to different corpora and never connected.

## 2. Reproduction (deterministic, from the plugin cache)

```bash
cd .harness/plugin-cache/claude-tdd-pro
CLAUDE_PLUGIN_ROOT="$PWD"

# 1. Any TypeScript/React-flavored workload description will do.
bash commands/business-intake.sh \
  --answer "workload=Grade short-answer exam responses with an LLM plus human-in-the-loop UI (TypeScript + React frontend, Node.js API)" \
  --answer "criticality=mission-critical" \
  --answer "budget_posture=cost-first" \
  --out /tmp/profile.json --now 2026-07-03T00:00:00Z

# 2. Translate the profile into technical requirements + concerns.
bash commands/business-translate.sh \
  --profile /tmp/profile.json \
  --out /tmp/reqs.json --now 2026-07-03T00:00:00Z

# 3. Compose architecture options grounded in those concerns.
bash commands/architect-recommend.sh \
  --requirements /tmp/reqs.json \
  --profile /tmp/profile.json \
  --out /tmp/opts.json --now 2026-07-03T00:00:00Z

# 4. Inspect the grounding surface.
node -e '
  const opts = JSON.parse(require("fs").readFileSync("/tmp/opts.json","utf8"));
  const g = new Set();
  for (const o of opts.options) for (const s of (o.grounding||[])) g.add(s);
  console.log("distinct grounding sources:", [...g].sort());
'
# → distinct grounding sources: [ 'aws-reliability-pillar', 'aws-rpo-rto-targets', 'google-sre-book', 'nist-800-53', 'opentelemetry-docs' ]

# 5. Inspect the FULL surface that aggregator.sh knows about.
bash rubric/aggregator.sh --out /tmp/agg.json --now 2026-07-03T00:00:00Z
node -e '
  const a = JSON.parse(require("fs").readFileSync("/tmp/agg.json","utf8"));
  const ns = new Set();
  for (const r of a.rules) ns.add(r.id.split("-")[1] || r.namespace);
  console.log("distinct namespaces in aggregator:", [...ns].sort(), "rule count:", a.rules.length);
'
# → distinct namespaces in aggregator: [ 'arch', 'doc', 'helm', 'iam', 'jwt', 'k8s', 'node', 'oas', 'owasp',
#     'react', 'sbom', 'sarif', 'security-governance', 'ts', 'w3c', 'web-vitals', ...43 total ]
#   rule count: 118
```

**Delta:** 5 sources consulted / 118 available across 43 namespaces / 38 namespaces silently omitted at architecture-production time.

## 3. Impact on the consumer (GCTP), and why the harness stays safe

### 3a. Empirical impact — this-session, the O'Reilly kata attempt

GCTP is on `dev/kata-2026-07-02` producing a submission for the O'Reilly Winter 2025 Architectural Kata (Certifiable, Inc.: LLM-assisted grading of certification exams with human-in-the-loop, TypeScript/React/Node.js stack). The published quality bar (`../softarchcert-kata-2026-07-02/docs/quality-bar.md`) shows the top-3 Winter 2025 finalists (ZAITects, Litmus, Software-Architecture-Guild) shared gaps precisely in the namespaces CTP does not consult at design time — `g-react-*` (component test coverage), `g-node-*` (typed errors, structured logging), `g-owasp-*` (application-layer threat model), `g-oas-*` (API contract discipline), `g-jwt-*` (auth), `g-web-vitals-*` (UX perf), `g-w3c-*` (WCAG), `security-governance` (EO-2026). Under P-11, these become part of the architecture itself; without it, they can only be applied ex-post at ticket time — which is exactly the gap the finalists hit.

### 3b. Systemic impact — every future kata / product / consult

Under the current shape, GCTP produces an architectural rework class: an option looks green at consult, then at `/inner-loop` code time a rule fires that would have changed the architecture had it been surfaced earlier. This is architectural debt manufactured at design time — the opposite of the design-time / code-time two-phase enforcement CTP itself designed (which GCTP mirrors in ADR-0046 — see §5 grounding below).

### 3c. Why GCTP stays safe

GCTP's Stage-5 cross-check `scripts/audit-architecture-crosscheck.sh` (per ADR-0056 / TICKET-065) already runs on every emitted CTP architecture artifact. Today it enforces:
1. every cited `rule_id` resolves against `.harness/rules/active.json`
2. the `security-governance` (EO-2026) namespace is present (per ADR-0045)

It **does not** enforce completeness across all 43 namespaces because CTP does not currently emit per-namespace verdicts. This gate is honest — it does what it can with the reasoning CTP supplies — but it cannot manufacture the reasoning CTP omitted. GCTP's fail-closed default (absent `applicable_rules` ⇒ all rules apply, per `docs/handoff-contract.md`) prevents *enforcement-time* omission but not *production-time* omission.

GCTP has filed the consumer-side companion as **TICKET-113** (`TICKETS.md`, this repo): extend `audit-architecture-crosscheck.sh` with a third check — verdict-completeness across all applicable namespaces per decision — fail-closed on silent omission. Deliberately blocked on P-11; meaningful only once CTP emits the fuller reasoning.

## 4. Proposed fix (CTP to assess; discipline-conforming)

Under CTP's discipline as declared in your `CLAUDE.md` — architecture is law; append-only; feature-ID cited verbatim; per-CL TDD (Steps 0–4); §25 pending-spec fidelity gate:

### 4a. Amendment shape — append-only, per your CLAUDE.md "ARCHITECTURE IS LAW" + `feedback-additive-amendment-by-reference.md`

The fix is **additive** to the existing S-32 / S-33 / S-34 chain (v1.13 §27.15 in your `architecture-v1.9.md`). It does not delete or alter the AWS Well-Architected pillar model; it composes a new grounding-completeness surface on top of it. Proposed amendment path per your append-only discipline:

- Write the detailed content into a new design file (e.g. `v1.13-full-surface-grounding.md` under your `docs/design/`), then
- APPEND a reference block as a new end-of-file section (e.g. `## §29. …`) to `architecture-v1.9.md`,
- with a new feature ID (e.g. **S-N** = "full-surface grounding aggregation for the S-34 option composer"),
- and a new §2.X contract (e.g. **§2.26** = "consult engine grounding-completeness contract: every emitted option MUST carry a per-rule verdict across every applicable namespace in the aggregated surface").

Never delete or alter existing §1–§28 content. Verify additivity: `git diff --numstat` on `architecture-v1.9.md` must show `0` in the deletions column.

### 4b. Engine behavior — five design points

1. **Ingest the full aggregated surface.** `business-translate.sh` (or a new `commands/architect-ground.sh` inserted between S-33 and S-34) invokes `rubric/aggregator.sh` and reads its output as the grounding corpus, not a hand-picked pillar set. Each concern in `technical-requirements.json` carries a `rule_id` (`g-<namespace>-<n>`) alongside the existing `source_id`, and the pillars structure is retained as a **view** over the full surface (backwards compatible — no consumer breaks).

2. **Per-decision verdict emission.** For every decision emitted by `architect-recommend.sh` (each `option_id`) and downstream (each ADR emitted via `--emit-adr-args`), produce a `rule_verdicts` array shaped as:
   ```json
   [
     {"rule_id": "g-ts-001",  "namespace": "ts",   "verdict": "applies",         "implication": "concrete design implication..."},
     {"rule_id": "g-oas-003", "namespace": "oas",  "verdict": "applies",         "implication": "..."},
     {"rule_id": "g-react-007","namespace": "react","verdict": "not_applicable", "rationale": "no browser UI in this workload"},
     {"rule_id": "g-owasp-…", "namespace": "owasp","verdict": "needs_deviation","deviation_shape": "..."}
   ]
   ```
   For every rule in the aggregator surface. `verdict` ∈ {`applies`, `not_applicable`, `needs_deviation`}. `not_applicable` MUST carry a one-line rationale (empty rationale ⇒ engine bug).

3. **Fail-closed on silent omission.** If a workload is TypeScript-heavy (visible from the profile / vision text), suppressing the `ts` namespace at architect time is a bug, not a design choice. The engine MUST emit either `applies` or `not_applicable` for every rule; silent omission ⇒ non-zero exit + `needs_grounding=<n>` stderr line (mirror the existing `needs_grounding` pattern in `architect-recommend.sh` line 152 for `grounding.empty?`).

4. **Design-time-vs-code-time note per decision.** Each `applies` verdict carries a `handoff_phase` field:
   ```json
   {"rule_id": "g-react-007", "verdict": "applies", "handoff_phase": "code-time", "code_time_note": "component-level test coverage will need budget in sizing"}
   {"rule_id": "g-oas-003",   "verdict": "applies", "handoff_phase": "design-time","design_time_note": "API contract shape decision needed at architecture time"}
   ```
   This is the missing signal that lets the operator budget for `g-react-007`, `g-node-002`, `g-owasp-*`, etc. at architecture time rather than at rework time.

5. **Grounding for the amendment (per your Step 0 architecture extraction).** Cross-refs to include in the amendment doc:
   - GCTP ADR-0037 (operator-declared standards regime — the invariant this fix restores at production time)
   - GCTP ADR-0045 (EO governance as standing dimension — additive discipline; the P-11 amendment respects the same monotonic rule: additive-only, never subtractive)
   - GCTP ADR-0046 (two-phase enforcement — design phase AND code phase; today the design phase is under-informed)
   - GCTP ADR-0047 (standards layer additive-only — the P-11 amendment does not remove/relax any existing rule)

### 4c. Per-CL TDD (per your `CLAUDE.md` Workflow loop Steps 0–4)

- **Step 0:** Quote §27.15 (v1.13 §27.15) verbatim + the new §29 amendment being introduced.
- **Step 0.5:** N/A (this is fresh authoring, not promotion — unless you promote pre-existing pending specs for this feature, in which case run `rubric/detectors/audit-pending-spec-fidelity.sh` against `evals/pending/S/N-full-surface-grounding/`).
- **Step 1:** Write pending specs in `evals/pending/S/N-full-surface-grounding/`. Non-shallow behavior specs — e.g.:
  - "architect-recommend emits per-rule verdict for every rule in aggregator surface"
  - "engine fail-closes when workload is TypeScript-heavy but ts namespace has zero applies verdicts"
  - "verdict for not_applicable rule carries non-empty rationale"
  - "verdict for applies rule carries handoff_phase design-time OR code-time"
  - "engine is backwards compatible: pillars view over technical-requirements.json shape retained"
- **Step 2:** Architecture fidelity (folder maps to §29 amendment); 10 specs; non-shallow; CLI-flag disclosure.
- **Step 3:** `bash evals/runner.sh` — 58/58 active suite stays clean.
- **Step 4:** Commit body carries per-feature spec counts, audit findings, §29 amendment quoted, next-CL scope per §20.

### 4d. Regression test

A minimal regression: run the reproduction chain in §2 above and assert that `distinct grounding sources` count ≥ (aggregator namespace count × ~2), and that every namespace in the aggregator is present in at least one per-rule verdict on at least one emitted option. Fail-red if any namespace is silently absent.

## 5. Coordination back to GCTP (after the CTP fix lands)

Mirror of the P-10 → ADR-0079 pattern:

1. CTP writes design + specs + implementation under CLs conforming to §29 amendment; pushes.
2. Notify GCTP of the new commit SHA (`f53aa6f`-analog).
3. GCTP re-pins `docs/claude-tdd-pro.lock.yaml` `a69f380` → `<fixed>` via **§15-gated ADR-0086** (chained: 230e99d → 4668c2e → 127804b → a69f380 → `<fixed>`), reusing the ADR-0079 / ADR-0085 template.
4. GCTP unblocks **TICKET-113**: extends `audit-architecture-crosscheck.sh` with the third check (verdict-completeness across 43 namespaces per decision, fail-closed on silent omission). Auto-verifies against the new CTP output shape.
5. GCTP's `docs/upstream-ctp-proposals.md` §P-11 flips 🟥 OPEN → ✅ ADOPTED at that pin.
6. GCTP resumes the O'Reilly kata `/consult` — this time producing a design that pre-accounts for all 43 namespaces at architecture time rather than at rework time.

## 6. Context / cross-refs

### GCTP side
- GCTP proposal record: `docs/upstream-ctp-proposals.md` §P-11 (OPEN, filed 2026-07-02).
- GCTP consumer companion: `TICKETS.md` TICKET-113 (blocked on P-11).
- GCTP Stage-5 gate: `scripts/audit-architecture-crosscheck.sh` (per ADR-0056 / TICKET-065).
- GCTP current pin: `a69f380` (per ADR-0085, 2026-07-02).
- GCTP branch this was discovered on: `dev/kata-2026-07-02` (O'Reilly Winter 2025 Certifiable, Inc. kata).
- GCTP quality bar: `../softarchcert-kata-2026-07-02/docs/quality-bar.md` — top-3 finalists' shared gaps are precisely in the 38 namespaces P-11 unblocks.
- GCTP prime directive: consume CTP by pinned reference only; do not edit the plugin — hence this handoff rather than a cross-repo patch.

### CTP side (references extracted from your plugin cache at `a69f380`)
- Consult chain entry point: `commands/architect-session.sh` (137 lines).
- Concerns/pillars producer: `commands/business-translate.sh`.
- Options composer: `commands/architect-recommend.sh` (168 lines; grounding lambda at lines 75–89).
- WA-review sibling: `commands/well-architected-review.sh` (153 lines).
- Rule aggregator that already builds the full surface: `rubric/aggregator.sh` (622 lines).
- Current architecture surface for amendment: your `architecture-v1.9.md` §27.15 (v1.13 architect session), §27.16 (option composer), §27.17 (objectives).

### Precedent
- P-1 (`install.sh` `conflicts[@]`) — adopted CTP CL-476 / §28.16.
- P-10 (composite-dispatch bash 3.2) — filed 2026-06-30, adopted CL-538, GCTP re-pinned via ADR-0079 on 2026-07-01. Model for this handoff.

---

**One-line summary for the CTP dev chat:** *"CTP consult engines produce architecture grounded in 5 IaC/reliability sources; the aggregator already builds a 118-rule surface across 43 namespaces; the composition gap between `rubric/aggregator.sh` and `business-translate.sh` is P-11. Additive amendment (new S-N feature + new §2.X contract) restores full-surface grounding at architecture-production time. Then GCTP re-pins and unblocks TICKET-113."*
