# Handoff Contract

The API boundary between Grok Build CLI (outer loop) and Claude TDD Pro (inner loop). Every code-change handoff in either direction conforms to one of the two schemas below. Anything not in these schemas is out of contract and the receiver MUST reject it.

## When handoff occurs

- **Grok → Claude**: once per ticket. Grok has finished research and decomposition for one ticket and is dispatching the inner loop to produce a passing change.
- **Claude → Grok**: once per ticket attempt. Claude returns either a green result (tests pass, change ready for deploy), a red result (could not reach green), or blocked (missing context, contract violation).

No streaming. No partial updates. One JSON document per direction per ticket.

## Wire format

- Payload is a single JSON file written to a path agreed at orchestration time. Default: `.harness/handoffs/<ticket-id>.req.json` (Grok→Claude) and `.harness/handoffs/<ticket-id>.res.json` (Claude→Grok).
- Encoding: UTF-8, no BOM.
- The receiver MUST validate the JSON against the schema before acting. Schema violation → `status: "error"` response with `error.code: "schema_invalid"`.

## Grok → Claude (request)

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-NNN",
  "title": "short imperative",
  "issued_at": "2026-05-24T17:30:00Z",
  "context_ttl_seconds": 3600,
  "acceptance_criteria": [
    "<one observable behavior per entry>"
  ],
  "file_scope": {
    "may_edit": ["path/glob/**.ext"],
    "may_read":  ["path/glob/**.ext"],
    "must_not_touch": ["path/glob/**.ext"]
  },
  "context": {
    "research_refs": [
      {"kind": "url|doc-id|file", "ref": "<id>", "summary": "<one line>"}
    ],
    "decomposition_parent": "FEATURE-NNN",
    "prior_decisions": [
      {"ticket_id": "TICKET-MMM", "decision": "<one line>"}
    ]
  },
  "quality_gate": {
    "tests_must_pass": true,
    "coverage_delta_min": 0,
    "lint_clean": true
  },
  "applicable_rules": [
    "g-react-001",
    "g-node-001",
    "g-ts-001"
  ]
}
```

Field rules:

- `schema_version` is required. Currently `"1"`. Bump on breaking changes.
- `acceptance_criteria` MUST be non-empty. Each entry is one observable behavior, not an implementation step.
- `file_scope.may_edit` is an allowlist. Claude MUST NOT edit files outside it. `must_not_touch` is a denylist that wins ties.
- `context_ttl_seconds` is how long the receiver may treat research_refs as fresh. Past TTL, Claude returns `status: "blocked"` with `error.code: "context_stale"` rather than acting on stale facts.
- `quality_gate` defines what counts as "green". The semantics of each sub-field — `tests_must_pass`, `coverage_delta_min`, `lint_clean`, and the recommended-at-v1 `provenance_complete` — are formalized in [`quality-gate.md`](quality-gate.md). This field is the contract surface; per-sub-gate definitions, defaults, override policies, and the reviewer checklist live in the formalization doc.
- `applicable_rules` (added per TICKET-032 / ADR-0037) is an array of rule IDs from `.harness/rules/active.json` (the aggregated standards registry from the plugin's `rubric/aggregator.sh`). Grok populates this by filtering the active registry against the ticket's `file_scope` + detected language(s). Claude MUST run `rubric/runner.sh` against each rule ID and report results in the response's `rules_verified` field. If the field is absent, Claude treats it as "all rules from active.json apply" — fail-closed.
- **EO-governance non-exemptibility (added per TICKET-050 / ADR-0045/0048; activated per ADR-0055).** Rules whose `source_namespace` is in the EO set (`eo` and, live at pin `6d2fe13`+, `security-governance`) are **always-on and non-exemptible**: when `applicable_rules` is present, it MUST include every EO-governance rule in `active.json`, regardless of `file_scope` or language. Grok MUST NOT filter them out per-ticket. (Absent `applicable_rules` already covers them via the fail-closed default above.) Verified by `scripts/audit-eo-governance.sh`. This is **additive** — it never relaxes any other rule (ADR-0047). EO rule *content* is owned by `claude-tdd-pro`; it is now LIVE — `security-governance` ships `require-provenance` (P1) + `no-known-exploited-ingress` (P0).

## Claude → Grok (response)

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-NNN",
  "status": "green",
  "completed_at": "2026-05-24T17:42:00Z",
  "changed_files": [
    {"path": "src/foo.ts", "lines_added": 14, "lines_removed": 2}
  ],
  "test_results": {
    "framework": "<name>",
    "passed": 12,
    "failed": 0,
    "skipped": 0,
    "duration_ms": 842
  },
  "coverage_delta": 0.4,
  "decision_trail_ref": ".harness/trails/TICKET-NNN.md",
  "skills_invoked": ["tdd-pro-cl-workflow"],
  "rules_verified": {
    "g-react-001": "pass",
    "g-node-001": "pass",
    "g-ts-001": "pass"
  },
  "eo_design_conformance": {
    "design_phase_attested": true,
    "rules_considered": ["<eo-namespace rule ids that shaped the pre-code design>"],
    "patterns_applied": ["<EO design/coding patterns chosen>"],
    "notes": "<one line: patterns chosen/rejected and why, at the design phase>"
  },
  "notes": "optional, single short paragraph",
  "error": null
}
```

`rules_verified` field rules (added per TICKET-032 / ADR-0037):

- Keys are rule IDs from `applicable_rules` in the matching request.
- Values are `"pass"`, `"fail"`, `"deviated"` (= violation justified by a row in `docs/deviations.md`), `"not_applicable"`, or `"not_enforced"` (extended additively per ADR-0062, "Fix B"; `schema_version` stays `"1"` — a tolerant reader treats an unknown verdict as non-green). The last two come straight from the detector run (`enforce.sh`, ADR-0058) via `scripts/enforce-standards.sh`:
  - `"not_applicable"` — the rule's detector matched **no files** in the app tree (e.g. an EO/cloud rule on a pure-TypeScript ticket). NEUTRAL, distinct from `pass`: the rule legitimately does not pertain, and "nothing to check" is never counted as a vacuous pass.
  - `"not_enforced"` — files existed but the detector **could not verify** them (tool/model absent). The rule was claimed applicable but went unverified → RED. Never read as a pass.
- A `green` status requires every applicable rule to be `pass`, `deviated`, **or** `not_applicable`. Any `fail` **or** `not_enforced` (or `unknown_rule`) forces `status: "red"` with `error.code: "gate_failed"`.
- `rules_verified` SHOULD be produced by a real detector run, not asserted: the inner loop runs `scripts/enforce-standards.sh --ticket <id>` against the `app_root` and writes `rules_verified` from its output (ADR-0062). The forthcoming dynamic gate (`audit-standards-enforced.sh`, Fix C / ADR-0063) re-runs the detectors and rejects a green response whose claims do not match the live verdicts, or whose `pass` rules evaluated zero files.
- Missing keys (request named a rule but response omits it) force `status: "red"` with `error.code: "gate_failed"`.

`eo_design_conformance` field rules (added per TICKET-050 / ADR-0046/0048):

- This is the **two-phase** attestation: the EO governs both the design Claude TDD Pro produces *before* it codes AND the code. This field attests the **design-before-code** phase — which EO-namespace rules/standards shaped the design, and which patterns were chosen or rejected and why.
- Additive optional field; `schema_version` stays `"1"` (R-11 tolerant reader — a reader that does not know the field ignores it).
- **When EO-namespace rules are active in `active.json`**, a `green` response MUST carry a non-empty `eo_design_conformance` (not `null`, `{}`, `[]`, or `""`). A green response missing it (or empty) is rejected by `scripts/audit-eo-governance.sh` — code that passes the rule checks but whose pre-code design carries no EO attestation is **not** green (ADR-0046).
- **When the EO set is empty** (no `eo`-namespace rule yet; pin-bump-gated), the field is optional and the check is vacuous — existing green responses remain valid.

`status` enum:

- `"green"` — tests pass, gate satisfied, deploy may proceed.
- `"red"` — change attempted, tests do not pass, gate not satisfied. Grok decides retry/escalate.
- `"blocked"` — Claude refused to act. `error` populated. Grok must resolve before retry.
- `"error"` — internal failure (schema invalid, skill missing, etc.). `error` populated.

When `status != "green"`, `error` MUST be populated:

```json
"error": {
  "code": "context_stale|scope_violation|gate_failed|schema_invalid|skill_missing|other",
  "message": "<human-readable>",
  "details": { }
}
```

## Architecture-Consult (FEATURE → consult artifact) — SUPERSEDED

> **STATUS: SUPERSEDED by ADR-0040 (TICKET-035).** The per-feature consult mechanism is deprecated in favor of static context injection at session start (`.harness/context/PROJECT_CONTEXT_FOR_PLANNER.md`). The schema below remains documented for historical reference per Nygard append-only; the consult artifact is no longer required input to `decomposition.md`.

Per TICKET-034 / ADR-0039 (SUPERSEDED). Grok calls Claude-TDD-Pro BEFORE `decomposition.md` runs and persists the structured architecture review to `.harness/handoffs/FEATURE-NNN.architecture.json`. The artifact is a required input to `decomposition.md`. Schema:

```json
{
  "schema_version": "1",
  "feature_id": "FEATURE-NNN",
  "consult_timestamp": "2026-06-06T...Z",
  "consult_skipped": false,
  "consult_skip_rationale": null,
  "cache_key": "<sha256 of canonicalized research_bundle + brief>",
  "test_shape_summary": "<one paragraph>",
  "recommended_tickets": [
    {
      "ticket_id": "TICKET-XXX",
      "title": "<imperative short title>",
      "test_shape": "<one paragraph>",
      "file_scope": {
        "may_edit":       ["path/glob"],
        "may_read":       ["path/glob"],
        "must_not_touch": ["path/glob"]
      },
      "depends_on": ["TICKET-YYY"],
      "applicable_rules": ["<rule_id from .harness/rules/active.json>"],
      "complexity": "small|medium|large",
      "rationale": "<one paragraph>"
    }
  ],
  "prior_decisions": [
    {"kind": "adr_required|extract|delete|other", "ref": "<optional>", "summary": "<one line>"}
  ],
  "grok_notes": "<optional Grok observations>"
}
```

Field rules:

- `consult_skipped: true` is permitted ONLY for trivial / single-line tickets where the round-trip cost exceeds the benefit (per ADR-0039). When `true`, `consult_skip_rationale` is REQUIRED and `recommended_tickets` MUST be empty.
- `recommended_tickets[].applicable_rules` IDs MUST resolve in `.harness/rules/active.json`. Unknown rule = pre-emit error `unknown_rule`.
- `recommended_tickets[].file_scope.must_not_touch` MUST include the prime-directive denylist (`.grok/**`, `.claude/**`, `claude-tdd-pro/**`).
- `prior_decisions` becomes `context.prior_decisions` in each downstream `.req.json` via `decomposition.md`.

Authority: the consult artifact is **advisory input** to decomposition, not a hard contract. Grok retains decomposition authority but is no longer blind to the inner-loop's technical-approach knowledge. Per ADR-0039: when Grok overrides a `prior_decisions` entry, the override is recorded in `grok_notes` of the FEATURE-level artifact AND in `context.prior_decisions` of the relevant ticket.

## Freshness rules

- A request older than `issued_at + context_ttl_seconds` MUST be rejected as `context_stale`.
- A response older than 24 hours MAY be discarded by Grok without action; the orchestrator should reissue the request rather than trust a stale response.

## Example: happy path

Request (`.harness/handoffs/TICKET-042.req.json`):

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-042",
  "title": "trim whitespace in slugify()",
  "issued_at": "2026-05-24T17:30:00Z",
  "context_ttl_seconds": 1800,
  "acceptance_criteria": [
    "slugify('  hello world  ') returns 'hello-world'",
    "slugify('') returns ''"
  ],
  "file_scope": {
    "may_edit": ["src/string-utils.*", "test/string-utils.*"],
    "may_read":  ["src/**"],
    "must_not_touch": [".grok/**", ".claude/**"]
  },
  "context": {
    "research_refs": [],
    "decomposition_parent": "FEATURE-007",
    "prior_decisions": []
  },
  "quality_gate": {
    "tests_must_pass": true,
    "coverage_delta_min": 0,
    "lint_clean": true
  }
}
```

Response (`.harness/handoffs/TICKET-042.res.json`):

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-042",
  "status": "green",
  "completed_at": "2026-05-24T17:38:14Z",
  "changed_files": [
    {"path": "src/string-utils.ts", "lines_added": 1, "lines_removed": 0},
    {"path": "test/string-utils.test.ts", "lines_added": 8, "lines_removed": 0}
  ],
  "test_results": {"framework": "vitest", "passed": 6, "failed": 0, "skipped": 0, "duration_ms": 312},
  "coverage_delta": 0.0,
  "decision_trail_ref": ".harness/trails/TICKET-042.md",
  "skills_invoked": ["tdd-pro-cl-workflow"],
  "notes": null,
  "error": null
}
```

## Example: blocked path

Response when Grok asked Claude to edit a denied path:

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-051",
  "status": "blocked",
  "completed_at": "2026-05-24T17:33:02Z",
  "changed_files": [],
  "test_results": null,
  "coverage_delta": null,
  "decision_trail_ref": null,
  "skills_invoked": [],
  "notes": null,
  "error": {
    "code": "scope_violation",
    "message": "Acceptance criteria require editing .grok/templates/research.md, which is in must_not_touch.",
    "details": {"requested_path": ".grok/templates/research.md"}
  }
}
```

## Out of scope (deferred)

- Authentication / signing of payloads (assumes co-located filesystem).
- Multi-ticket batched handoffs (out-of-contract; one ticket per file).
- Streaming progress (deliberately disallowed — one-shot only).
- Concrete quality-gate definitions (lives in TICKET-007).

---

## Architecture-Consult-Loop (FEATURE → consult artifact) — ACTIVE (per ADR-0056)

> Additive successor to the SUPERSEDED `§Architecture-Consult` above. That section is left
> intact as history; this one defines the **live, looped** GCTP↔CTP consult (the crossroads/
> translator model). See `.grok/templates/architecture-consult-loop.md`.

GCTP runs a per-juncture loop (intake → consult CTP → translate → prompt user → decide → size+ticket
→ cross-check), accreting `.harness/handoffs/FEATURE-NNN.architecture.json`:

```jsonc
{
  "schema_version": "1",
  "feature_id": "FEATURE-NNN",
  "user_request": "<the user's ask, in their own words>",
  "ruby_ok": true,                      // D-D preflight; false ⇒ loop refused, stop-and-remediate
  "needs_grounding": 0,                 // MUST be 0 — CTP cite-or-decline satisfied
  "options": [ { "id": "opt-...", "grounded_in": ["nist-800-53","owasp-asvs","aws-waf","..."] } ],
  "recommended_option": "opt-balanced",
  "build_requirements": ["encryption_at_rest","audit_logging","..."],
  "decisions": [
    {
      "juncture": "<plain-language decision point>",
      "user_choice": "<the decision, business/creative language>",
      "technical_mapping": "<how GCTP mapped it to CTP intake>",
      "complexity": "small|medium|large",
      "applicable_rules": ["<active.json rule ids that govern this chunk>"],
      "depends_on": ["<prior juncture ids>"]
    }
  ]
}
```

Field rules: `ruby_ok=false` ⇒ the loop is not run (ADR-0056 D-D). `needs_grounding` MUST be `0`
(else the consult is `blocked`). Every `decisions[*].applicable_rules` entry MUST resolve in
`active.json` and MUST include the non-exemptible EO-governance rules (ADR-0045/0055). `complexity`
∈ {small,medium,large}. Additive field; readers that don't know it ignore it (R-11).

## Architecture-Cross-Check (GCTP audits CTP's output) — ACTIVE (per ADR-0056)

GCTP independently checks CTP's proposed architecture/design/development against **GCTP's own** rules
— the shared `active.json` (consistency check) **plus** GCTP-native governance (R-rules, D-rules, EO
spine, citation-integrity, TIER-0 corpus). Recorded alongside the consult artifact:

```jsonc
{
  "feature_id": "FEATURE-NNN",
  "checks": [
    { "rule": "<rule id or R-/D-/EO-/citation ref>", "result": "pass|deviated|reconsulted" }
  ],
  "reconsults": [ { "rule": "<id>", "constraint_fed_back": "<text>", "attempts": 1 } ],
  "deviations": [ { "rule": "<id>", "deviations_md_row": "<ref>" } ]
}
```

Failure handling (ADR-0056 D-E): a violation is fed back to CTP as an added constraint (bounded
re-consult); if still unsatisfiable after N attempts, it MUST appear in `deviations` with a
`docs/deviations.md` row (operator-approved) — never silently accepted.

## Roadmap (FEATURE → user-facing deliverable) — ACTIVE (per ADR-0056)

The accreted output presented to the user: real tickets, sized, sequenced, planned. Derived from the
consult artifact's `decisions[]` once the loop completes.

```jsonc
{
  "feature_id": "FEATURE-NNN",
  "tickets": [
    { "id": "TICKET-NNN", "title": "<plain-language>", "complexity": "small|medium|large",
      "depends_on": ["TICKET-..."], "applicable_rules": ["..."], "grounded_in": ["..."] }
  ],
  "sequence": ["TICKET-A","TICKET-B","..."],     // topological over depends_on
  "world_class_basis": "CTP architected under standards + GCTP cross-check enforced"
}
```

## App-Root (external application working tree) — ACTIVE (per ADR-0059, "Fix D")

The harness builds the user's product in a **separate working tree** ("app_root"), distinct from
`.harness/*` (which holds handoffs/trails/manifests). The app_root is the tree CTP standards are
**enforced on** (via `enforce.sh`, Fix B/C). It is named in an operator-local config:

```jsonc
// .harness/app.json  (gitignored; .harness/app.json.example is the tracked template)
{ "schema_version": "1", "app_root": "<path>", "description": "..." }
```

- `app_root` may be **relative** (resolved against the repo root) or **absolute**; the app tree need
  **not** be a git repo (enforcement is git-agnostic).
- The single resolver is **`scripts/app-root.sh`** — exit `0` (resolved + exists + non-empty, abs path
  on stdout) / `1` (unconfigured) / `2` (configured but missing or **empty** → refused).
- **Hard guard (anti-vacuous-green):** an app_root that is missing or has zero regular files is exit `2`,
  never a silent pass. "Nothing to enforce" is a configuration error, not a green. This is the consumer
  half of `enforce.sh`'s `not_applicable`-vs-pass distinction: GCTP refuses to *call* enforcement on an
  empty tree just as `enforce.sh` refuses to count an unevaluated rule as passed.
- **Consumers:** `/consult` `/decompose` `/inner-loop` `/audit` resolve the app_root through this script;
  the forthcoming Fix-B `enforce-standards.sh` and the Fix-C dynamic gate target it as `enforce.sh --root`.

## Business-Intake (business-profile.json) — AUTHORITATIVE (CTP §30 / S-57 / §2.35, CL-546)

> **Status: AUTHORITATIVE at CTP pin `f060a8e`.** This section reflects the shape CTP shipped on
> `main` under the P-12 amendment. GCTP filed P-12 as "§27.16 Full-Surface Intake"; that label
> already existed in CTP's architecture ("Layered multi-cloud advisor"), so CTP landed the amendment
> at **§30 / S-57 / §2.35**. CTP is authoritative on the shape; GCTP reconciles. Backward-compat is
> guaranteed: `schema_version: "1.0"` profiles remain valid indefinitely.

### v1.0 shape (still supported, unchanged)

Emitted by CTP's `commands/business-intake.sh` (S-32). Nine universal question keys under `answers`,
`grounded_in` sourced to 4 catalog IDs.

```jsonc
{
  "schema_version": "1.0",
  "generated_at": "<iso>",
  "complete": <bool>,
  "answers": { "workload": "...", "motivation": "...", /* 8 more */ },
  "grounded_in": ["azure-waf-business-requirements", "aws-rpo-rto-targets",
                  "nist-800-53", "aws-wa-tool-profiles"],
  "unanswered": [ /* keys still pending */ ]
}
```

### v1.1 shape (CTP §30 / S-57 / §2.35, `commands/full-surface-intake.sh`)

Additive extension. `schema_version` bumps to `"1.1"`. The universal 9 answers **remain in `answers`
unchanged** (universal-stays-universal — S-57 composes S-32 for the universal layer). New top-level
`workload_classification` records the workload types the classifier detected, the aggregator
namespaces they put in scope, and which of those had a probe group activated. New `probes.<namespace>`
blocks carry per-namespace committed postures. `grounded_in` becomes a **strict superset** of what
v1.0 would have emitted; `grounded_in_namespaces` enumerates the namespaces grounded from a gathered
probe answer (not a default).

```jsonc
{
  "schema_version": "1.1",
  "generated_at": "<iso>",
  "complete": <bool>,
  "answers": { /* universal 9, mirrored UNCHANGED from S-32 */ },
  "workload_classification": {
    "workload_types":             ["web-frontend", "rest-api", "ml-inference", ...],
    "namespaces":                 ["react", "node", "k8s", "jwt", "owasp", ...],
    "activated_probe_namespaces": ["react", "jwt", "k8s", ...]
  },
  "probes": {
    "react": { "react_rendering_model": "spa" },
    "jwt":   { "jwt_token_lifetime": "short" },
    "k8s":   { "resource_limits_posture": "requests-and-limits" }
    /* per-namespace probe answers; every key here belongs to an activated_probe_namespace */
  },
  "grounded_in":            [ /* universal source_ids ∪ answered-probe source_ids (STRICT SUPERSET of v1.0) */ ],
  "grounded_in_namespaces": [ "react", "jwt", "k8s", ... ],
  "unanswered": [ /* activated probes still pending */ ]
}
```

Authoritative schema: `.harness/plugin-cache/claude-tdd-pro/schemas/business-profile.schema.json`
(`oneOf` on `schema_version`; v1.1 additionally requires `workload_classification` + `probes` +
`grounded_in_namespaces`). Validatable by CTP's own `rubric/detectors/lib/validate-json-schema.js`
(no npm dep).

### Contract invariants (guaranteed by CTP under §2.35, all tested in `cl546-fsintake-01..12`)

1. **Additivity (ADR-0047 compliance).** No universal-9 key is removed or renamed. No enum value is
   dropped. Every S-57 addition is *additional*; the classifier can only turn a probe group ON.
2. **Backward-compat.** `schema_version: "1.0"` profiles validate + translate + recommend unchanged.
   Downstream engines (`business-translate.sh`, `architect-recommend.sh`) read `answers` (unchanged)
   — the whole existing chain works on a v1.1 profile without knowing about probes. Consumption of
   the richer `probes` block by downstream engines is a deliberate CTP follow-up CL, not part of
   this contract.
3. **`grounded_in` monotonicity.** For the same workload, v1.1 `grounded_in` ⊇ v1.0 `grounded_in`.
   Never a subset.
4. **Cite-or-decline preserved.** Every activated probe question is grounded in a `source_id` that
   resolves in one of CTP's `standards/*.yaml` catalogs AND to at least one `active.json` namespace.
   `needs_grounding=0` discipline retained.
5. **Universal-stays-universal.** The universal 9 answers live in `answers` (byte-identical to S-32
   output) — S-57 does not introduce a `probes.universal` block. Only namespace-scoped probes live
   under `probes.<namespace>`.
6. **Namespace-grounding traceability.** Every `grounded_in_namespaces` entry appears in
   `workload_classification.activated_probe_namespaces` and is backed by ≥ 1 answered probe.

### Consumer contract on the GCTP side (TICKET-114, resolved at pin `f060a8e`)

- `scripts/consult.sh --validate-profile <profile>` — detects `schema_version`; for `"1.1"`
  additionally verifies `workload_classification.{workload_types,namespaces,activated_probe_namespaces}`
  present, every activated probe namespace has an answered `probes.<ns>` block, and
  `grounded_in_namespaces` ⊆ `activated_probe_namespaces` with each entry backed by an answer.
  For `"1.0"` unchanged.
- `scripts/audit-architecture-crosscheck.sh` — invariant 4: for every v1.1 profile in the run,
  every `activated_probe_namespaces` entry propagates into at least one `decisions[]` juncture's
  `applicable_rules` (a rule whose `source_namespace` matches the namespace). Fail-closed on silent
  omission.
- `/consult` skill — walks Stage 0 (`--classify` reveal → operator confirms workload types) →
  Stage 1 (universal 9, forwarded to S-32) → Stage 2 (`--probe-answer ns:key=value` per activated
  namespace, translated to plain business language per the crossroads/translator loop, ADR-0056).
- **Downstream consumption (CL-547 / §30.1, pin `c23e5fe`+).** CTP's S-33 `business-translate.sh`
  reads `probes.<namespace>` and adds a grounded concern per committed posture (cited by the probe
  `source_id`); S-34 `architect-recommend.sh` lets a decisive commitment modestly move the pick
  (multi-region → most-resilient; hard cost-cap → cost-optimized). Both engines emit
  `probes_consumed=<n>` on stderr. Gated on `probes` presence — v1.0 profiles byte-identical.
  Adopted via ADR-0088. Observable end-to-end: intake → translate `probes_consumed=<n>` →
  recommend `probes_consumed=<n>` → decisions[] `applicable_rules` cover the propagated namespaces
  (invariant 4).
- **Precise classification + coverage transparency (CL-548 / §30.2, pin `43ea692`+).** The classifier
  is now precise on clouds: the generic `iac-cloud` type scopes only provider-agnostic namespaces
  (`hashicorp`, `iam`, `security-governance`); dedicated `aws-platform` / `azure-platform` /
  `gcp-platform` / `cloudformation` / `config-management` types fire on cloud-specific signals — so
  an AWS-only workload is probed for `aws`+`cfn`, not Azure/GCP. Grounded probe groups added for
  `azure` / `gcp` / `cfn`. New `workload_classification.unprobed_in_scope` field (additive optional)
  enumerates in-scope namespaces with no probe group — surfaced on `--classify`, run marker, and
  the persisted block. **Standing invariant: no in-scope namespace is silently unprobed** (the
  intake mirror of "no rule silently unenforced"). Adopted via ADR-0089. `scripts/consult.sh
  --validate-profile` tolerates the new key as an additive optional field — absent ⇒ pre-§30.2
  profile ⇒ pass unchanged; present ⇒ must be a string array, ⊆ `namespaces`, disjoint from
  `activated_probe_namespaces` (mutually exclusive by construction).
- `docs/handoff-ctp-p12-full-surface-intake.md` + companions
  (`docs/handoff-ctp-p12-namespace-question-manifest.md`,
  `docs/handoff-ctp-p12-sample-profile-v1.1.json`,
  `docs/handoff-ctp-p12-acceptance-test.sh`) remain in-repo as the P-12 proposal trail; the
  authoritative reference is now the plugin cache (`schemas/business-profile.schema.json`,
  `commands/full-surface-intake.sh`, `docs/architecture-v1.9.md §30`) at pin `f060a8e`. Historical
  key-name drift between the proposal and the shipped shape is documented in ADR-0087.

