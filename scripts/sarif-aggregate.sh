#!/usr/bin/env bash
# scripts/sarif-aggregate.sh — aggregate per-rule SARIF 2.1.0 outputs into one
# per-ticket SARIF log (per TICKET-078 / ADR-0066 D-E).
#
# WHY THIS EXISTS. Once PROPOSAL-003 lands in CTP, every detector emits SARIF 2.1.0
# (OASIS standard). The harness aggregates per-ticket so the audit chain has a single
# canonical detector-output surface to consume, and so output composes into the wider
# security-tool ecosystem (GitHub code-scanning, Azure DevOps, Sonar, Snyk).
#
# Contract per ADR-0066 D-E. Each detector writes per-rule SARIF to
# `.harness/audit/sarif/raw/TICKET-NNN/<rule-id>.sarif.json`. This script merges them
# into `.harness/audit/sarif/TICKET-NNN.sarif.json` preserving distinct `runs[]` entries
# (so markdownlint's run and prose-judge's run stay separate, attributable per tool).
#
# Flags:
#   --ticket TICKET-NNN   (required) ticket whose outputs to aggregate
#   --inputs <dir>        default .harness/audit/sarif/raw/TICKET-NNN/
#   --output <path>       default .harness/audit/sarif/TICKET-NNN.sarif.json
#   --schema <path>       default .harness/plugin-cache/claude-tdd-pro/schemas/sarif-2.1.0.json
#   --strict              exit 2 on any validation failure (default: warn + skip)
#   --summary             also write <output-without-ext>.summary.json (compact: counts per rule)
#   --quiet               suppress non-essential output
#
# Validation: until the OASIS schema ships in the plugin cache (via PROPOSAL-003 wave 2
# `sarif` namespace), validation is PRAGMATIC — checks `version === "2.1.0"`, `runs` is
# an array, each result has `ruleId` (string), `level` ∈ {error,warning,note,none}, and
# `message.text` (string). When --schema points at a real OASIS schema file, it is
# consulted as a future hook (currently informational; switches to full validation when
# `ajv` or equivalent is available in the plugin cache).
#
# Exit codes:
#   0  ok (incl. empty inputs dir — emits a valid empty SARIF log)
#   1  aggregation error (non-existent --inputs dir, output write failure, …)
#   2  --strict and at least one input failed validation
#
# Portability: bash 3.2 + BSD coreutils + node.

set -u

QUIET=0
TICKET=""
INPUTS=""
OUTPUT=""
SCHEMA=""
STRICT=0
SUMMARY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --ticket)   TICKET="$2"; shift 2 ;;
        --inputs)   INPUTS="$2"; shift 2 ;;
        --output)   OUTPUT="$2"; shift 2 ;;
        --schema)   SCHEMA="$2"; shift 2 ;;
        --strict)   STRICT=1; shift ;;
        --summary)  SUMMARY=1; shift ;;
        --quiet)    QUIET=1; shift ;;
        -h|--help)
            sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//' >&2
            exit 0
            ;;
        *) printf 'sarif-aggregate.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done

emit()  { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
warn()  { printf 'sarif-aggregate.sh: WARN: %s\n' "$*" >&2; }
errout(){ printf 'sarif-aggregate.sh: ERROR: %s\n' "$*" >&2; }

if [ -z "$TICKET" ]; then
    errout "--ticket is required"
    exit 2
fi

[ -n "$INPUTS" ] || INPUTS=".harness/audit/sarif/raw/$TICKET"
[ -n "$OUTPUT" ] || OUTPUT=".harness/audit/sarif/$TICKET.sarif.json"
[ -n "$SCHEMA" ] || SCHEMA=".harness/plugin-cache/claude-tdd-pro/schemas/sarif-2.1.0.json"

# Default schema URL when no cached schema is available (informational only).
SCHEMA_URL="https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json"

if [ ! -d "$INPUTS" ]; then
    errout "inputs directory does not exist: $INPUTS"
    exit 1
fi

command -v node >/dev/null 2>&1 || { errout "node is required"; exit 1; }

# Ensure output directory exists
out_dir=$(dirname -- "$OUTPUT")
mkdir -p -- "$out_dir" || { errout "cannot create output directory: $out_dir"; exit 1; }

# Aggregate via node. The script reads each *.sarif.json in $INPUTS, validates
# pragmatically, merges runs[], and writes the aggregate to $OUTPUT.
# Emits to stdout: number-of-invalid-inputs (for --strict gating).
result=$(SAR_INPUTS="$INPUTS" SAR_OUTPUT="$OUTPUT" SAR_SCHEMA="$SCHEMA" SAR_SCHEMA_URL="$SCHEMA_URL" SAR_TICKET="$TICKET" SAR_SUMMARY="$SUMMARY" node -e '
const fs = require("fs");
const path = require("path");

const inputsDir = process.env.SAR_INPUTS;
const outputPath = process.env.SAR_OUTPUT;
const schemaPath = process.env.SAR_SCHEMA;
const schemaUrl  = process.env.SAR_SCHEMA_URL;
const ticket     = process.env.SAR_TICKET;
const emitSummary = process.env.SAR_SUMMARY === "1";

const allowedLevels = new Set(["error", "warning", "note", "none"]);

function validate(doc, file) {
  const errs = [];
  if (doc === null || typeof doc !== "object") { errs.push("not an object"); return errs; }
  if (doc.version !== "2.1.0") errs.push("version must be \"2.1.0\" (got " + JSON.stringify(doc.version) + ")");
  if (!Array.isArray(doc.runs)) errs.push("runs must be an array");
  if (Array.isArray(doc.runs)) {
    for (let i = 0; i < doc.runs.length; i++) {
      const run = doc.runs[i];
      if (!run || typeof run !== "object") { errs.push("runs[" + i + "] not an object"); continue; }
      if (!run.tool || !run.tool.driver || typeof run.tool.driver.name !== "string") errs.push("runs[" + i + "].tool.driver.name missing");
      if (run.results !== undefined) {
        if (!Array.isArray(run.results)) { errs.push("runs[" + i + "].results not array"); continue; }
        for (let j = 0; j < run.results.length; j++) {
          const r = run.results[j];
          if (!r || typeof r !== "object") { errs.push("runs[" + i + "].results[" + j + "] not object"); continue; }
          if (typeof r.ruleId !== "string") errs.push("runs[" + i + "].results[" + j + "].ruleId not string");
          if (r.level !== undefined && !allowedLevels.has(r.level)) errs.push("runs[" + i + "].results[" + j + "].level not in enum: " + r.level);
          if (!r.message || (typeof r.message.text !== "string" && typeof r.message.id !== "string")) errs.push("runs[" + i + "].results[" + j + "].message.text or .id required");
        }
      }
    }
  }
  return errs;
}

let entries;
try { entries = fs.readdirSync(inputsDir).filter(n => n.endsWith(".sarif.json")).sort(); }
catch (e) { process.stderr.write("E|cannot read inputs dir: " + e.message + "\n"); process.exit(2); }

const aggregatedRuns = [];
const ruleCounts = {};
let totalResults = 0;
let invalidCount = 0;

for (const name of entries) {
  const file = path.join(inputsDir, name);
  let doc;
  try { doc = JSON.parse(fs.readFileSync(file, "utf8")); }
  catch (e) {
    process.stderr.write("W|" + name + " not JSON: " + e.message + "\n");
    invalidCount++;
    continue;
  }
  const errs = validate(doc, file);
  if (errs.length > 0) {
    process.stderr.write("W|" + name + " invalid SARIF: " + errs.join("; ") + "\n");
    invalidCount++;
    continue;
  }
  if (Array.isArray(doc.runs)) {
    for (const run of doc.runs) {
      aggregatedRuns.push(run);
      if (Array.isArray(run.results)) {
        for (const r of run.results) {
          totalResults++;
          const id = r.ruleId || "(no-id)";
          ruleCounts[id] = (ruleCounts[id] || 0) + 1;
        }
      }
    }
  }
}

const aggregate = {
  version: "2.1.0",
  "$schema": schemaUrl,
  runs: aggregatedRuns,
  properties: {
    ticket: ticket,
    aggregated_by: "scripts/sarif-aggregate.sh",
    aggregated_at: new Date().toISOString(),
    invalid_inputs_skipped: invalidCount
  }
};

// Validate the aggregated log itself before writing.
const aggErrs = validate(aggregate, outputPath);
if (aggErrs.length > 0) {
  process.stderr.write("E|aggregate invalid: " + aggErrs.join("; ") + "\n");
  process.exit(2);
}

try { fs.writeFileSync(outputPath, JSON.stringify(aggregate, null, 2) + "\n"); }
catch (e) { process.stderr.write("E|cannot write output: " + e.message + "\n"); process.exit(2); }

// Schema-file presence is informational; do not fail if missing.
if (schemaPath && !fs.existsSync(schemaPath)) {
  process.stderr.write("I|OASIS schema not in plugin cache yet (expected at " + schemaPath + ") — pragmatic validation used.\n");
}

if (emitSummary) {
  const summaryPath = outputPath.replace(/\.sarif\.json$/, ".summary.json");
  const summary = {
    ticket: ticket,
    runs: aggregatedRuns.length,
    total_results: totalResults,
    invalid_inputs_skipped: invalidCount,
    by_rule: ruleCounts
  };
  try { fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2) + "\n"); }
  catch (e) { process.stderr.write("W|cannot write summary: " + e.message + "\n"); }
}

// Emit invalid count to stdout for the bash wrapper.
process.stdout.write("INVALID=" + invalidCount + "\n");
process.exit(0);
' 2>&1)

# Surface warnings/errors from node
printf '%s\n' "$result" | grep -E '^[WIE]\|' | while IFS= read -r line; do
    case "$line" in
        E\|*) errout "${line#E|}" ;;
        W\|*) warn   "${line#W|}" ;;
        I\|*) [ "$QUIET" -eq 0 ] && printf 'sarif-aggregate.sh: INFO: %s\n' "${line#I|}" >&2 ;;
    esac
done

# Extract INVALID count
invalid=$(printf '%s\n' "$result" | grep -E '^INVALID=' | sed 's/^INVALID=//')
[ -z "$invalid" ] && invalid=0

# If node exited non-zero (write failure / aggregate invalid), the result string
# won't carry INVALID= and we should exit 1.
if ! printf '%s\n' "$result" | grep -q '^INVALID='; then
    errout "aggregation failed"
    exit 1
fi

if [ "$STRICT" -eq 1 ] && [ "$invalid" -gt 0 ]; then
    errout "$invalid invalid input(s) under --strict; exiting 2"
    exit 2
fi

emit "[sarif-aggregate] OK — $TICKET → $OUTPUT (invalid skipped: $invalid)"
exit 0
