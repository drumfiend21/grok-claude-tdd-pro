#!/usr/bin/env node
// tests/integration/simulate.mjs — simulate one "non-technical user → world-class
// software" delivery cycle through the harness wire format, for the integration
// suite. Per TICKET-052 / ADR-0050.
//
// STUB mode (no live LLM; live-Claude deferred per ADR-0008): the simulated
// inner-loop output stands in for a live `tdd-pro-cl-workflow` generation. What
// is REAL and asserted here is (a) the Grok→Claude→Grok wire contract
// (docs/handoff-contract.md) and (b) the *world-class delivery* definition:
// every authoritative-source standard applicable to the user's detected stack
// (fullstack AND cloud) is actually enforced via `applicable_rules`, the EO
// governance layer is non-exemptible + two-phase, and the response is green.
//
// The bash runner (test-generative-integration.sh) composes the REAL audit
// scripts (audit-eo-governance.sh, audit-source-citations.sh) over the artifacts
// this script emits — so the integration test exercises the actual harness gates,
// not a reimplementation of them.
//
// Usage:
//   node simulate.mjs <scenario.json> <active.json> <out_dir> <mode> [eo_rule_id]
//
// mode:
//   world-class            faithful world-class delivery (should pass every gate)
//   drop-stack             omit the scenario's critical_namespace rules from
//                          applicable_rules (a sub-world-class delivery — the
//                          stack-coverage check must catch it)
//   omit-eo-attestation    green response with no eo_design_conformance (the EO
//                          two-phase gate must catch it; stack coverage is fine)
//   omit-eo-rule           drop the EO rule from applicable_rules (the EO
//                          non-exemptibility gate must catch it)
//
// Exit codes (this script validates schema + world-class STACK coverage only;
// EO governance is validated by the bash audit over the emitted artifacts):
//   0  schema valid AND world-class stack coverage complete
//   1  schema invalid OR a stack standard is missing from applicable_rules
//   2  usage / IO error

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const STD_DENYLIST = [".grok/**", ".claude/**", "claude-tdd-pro/**"];

function die(code, msg) {
  process.stderr.write(`simulate.mjs: ${msg}\n`);
  process.exit(code);
}

const [scenarioPath, activePath, outDir, mode, eoRuleId] = process.argv.slice(2);
if (!scenarioPath || !activePath || !outDir || !mode) {
  die(2, "usage: simulate.mjs <scenario.json> <active.json> <out_dir> <mode> [eo_rule_id]");
}
const VALID_MODES = ["world-class", "drop-stack", "omit-eo-attestation", "omit-eo-rule"];
if (!VALID_MODES.includes(mode)) die(2, `unknown mode: ${mode}`);

let scenario, active;
try {
  scenario = JSON.parse(readFileSync(scenarioPath, "utf8"));
} catch (e) { die(2, `cannot read scenario: ${e.message}`); }
try {
  active = JSON.parse(readFileSync(activePath, "utf8"));
} catch (e) { die(2, `cannot read active registry: ${e.message}`); }

const rules = Array.isArray(active.rules) ? active.rules : [];
const ticketId = `INTEG-${scenario.id}`;
const now = new Date().toISOString().replace(/\.\d+Z$/, "Z");

// --- World-class standard set for the user's detected stack ------------------
// Every rule in the active registry whose namespace is in the scenario's
// detected stack is a world-class standard that MUST be enforced for this user,
// even though a non-technical user would never ask for it by name.
const stackRules = rules.filter((r) => scenario.expected_namespaces.includes(r.source_namespace));
const stackRuleIds = stackRules.map((r) => r.id);

let applicable = [...stackRuleIds];

// drop-stack: simulate a delivery that silently skips the scenario's critical
// namespace (e.g. accessibility for a recipe site, supply-chain for a pipeline).
if (mode === "drop-stack") {
  const dropped = new Set(
    rules.filter((r) => r.source_namespace === scenario.critical_namespace).map((r) => r.id)
  );
  applicable = applicable.filter((id) => !dropped.has(id));
}

// EO layer is non-exemptible: always appended unless we are simulating that miss.
if (eoRuleId && mode !== "omit-eo-rule") applicable.push(eoRuleId);

// --- Grok → Claude request (docs/handoff-contract.md §Grok→Claude) -----------
const request = {
  schema_version: "1",
  ticket_id: ticketId,
  title: scenario.title,
  issued_at: now,
  context_ttl_seconds: 1800,
  acceptance_criteria: scenario.acceptance_criteria,
  file_scope: {
    may_edit: scenario.file_scope.may_edit,
    may_read: scenario.file_scope.may_read || ["**/*"],
    must_not_touch: STD_DENYLIST,
  },
  context: {
    research_refs: [],
    decomposition_parent: `FEATURE-${scenario.id}`,
    prior_decisions: [],
    user_request: scenario.plain_request,
    persona: scenario.persona,
    domain: scenario.domain,
    detected_stack: scenario.detected_stack,
  },
  quality_gate: { tests_must_pass: true, coverage_delta_min: 0, lint_clean: true },
  applicable_rules: applicable,
};

// --- Claude → Grok response (docs/handoff-contract.md §Claude→Grok) ----------
const rulesVerified = {};
for (const id of applicable) rulesVerified[id] = "pass";

const response = {
  schema_version: "1",
  ticket_id: ticketId,
  status: "green",
  completed_at: now,
  changed_files: scenario.file_scope.may_edit.map((g) => ({
    path: g.replace(/\*\*?/g, "index.ts"),
    lines_added: 12,
    lines_removed: 0,
  })),
  test_results: { framework: "vitest", passed: 14, failed: 0, skipped: 0, duration_ms: 420 },
  coverage_delta: 1.5,
  decision_trail_ref: `.harness/trails/${ticketId}.md`,
  skills_invoked: ["tdd-pro-cl-workflow"],
  rules_verified: rulesVerified,
  eo_design_conformance:
    mode === "omit-eo-attestation"
      ? null
      : {
          design_phase_attested: true,
          rules_considered: eoRuleId ? [eoRuleId] : [],
          patterns_applied: ["input-validation-at-boundary", "least-privilege-defaults"],
          notes: "EO-aligned patterns chosen at the design phase before any code was written.",
        },
  notes: `STUB MODE: world-class delivery simulated for persona "${scenario.persona}".`,
  error: null,
};

// --- Emit artifacts ----------------------------------------------------------
mkdirSync(outDir, { recursive: true });
const reqPath = join(outDir, `${ticketId}.req.json`);
const resPath = join(outDir, `${ticketId}.res.json`);
writeFileSync(reqPath, JSON.stringify(request, null, 2) + "\n");
writeFileSync(resPath, JSON.stringify(response, null, 2) + "\n");

// --- Validate: schema (mirror dispatch.md pre-emit + response field rules) ----
const problems = [];
if (request.schema_version !== "1") problems.push("request.schema_version != 1");
if (!Array.isArray(request.acceptance_criteria) || request.acceptance_criteria.length < 1)
  problems.push("acceptance_criteria empty");
if (!Array.isArray(request.file_scope.may_edit) || request.file_scope.may_edit.length < 1)
  problems.push("file_scope.may_edit empty");
for (const dl of STD_DENYLIST)
  if (!request.file_scope.must_not_touch.includes(dl)) problems.push(`must_not_touch missing ${dl}`);
if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(request.issued_at))
  problems.push("issued_at not ISO-8601 second-precision UTC");
if (request.context_ttl_seconds < 60 || request.context_ttl_seconds > 86400)
  problems.push("context_ttl_seconds out of [60, 86400]");
if (response.status !== "green") problems.push("response.status != green");

// --- Validate: world-class STACK coverage ------------------------------------
// Every standard applicable to the detected stack must be enforced.
const missing = stackRuleIds.filter((id) => !applicable.includes(id));
const byNs = {};
for (const ns of scenario.expected_namespaces) {
  const nsIds = rules.filter((r) => r.source_namespace === ns).map((r) => r.id);
  const covered = nsIds.filter((id) => applicable.includes(id)).length;
  byNs[ns] = { total: nsIds.length, covered };
}

// --- Report ------------------------------------------------------------------
const report = {
  scenario: scenario.id,
  domain: scenario.domain,
  persona: scenario.persona,
  user_request: scenario.plain_request,
  detected_stack: scenario.detected_stack,
  mode,
  ticket_id: ticketId,
  world_class_standards_for_stack: stackRuleIds.length,
  applicable_rules: applicable.length,
  namespace_coverage: byNs,
  missing_stack_standards: missing,
  schema_problems: problems,
  delivered: response.status,
};
process.stdout.write(JSON.stringify(report, null, 2) + "\n");

if (problems.length > 0) process.exit(1);
if (missing.length > 0) process.exit(1);
process.exit(0);
