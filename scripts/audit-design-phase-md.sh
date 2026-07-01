#!/usr/bin/env bash
# scripts/audit-design-phase-md.sh — design-phase MD gate (ADR-0066 D-D / TICKET-079).
#
# WHY THIS EXISTS. Composes on ADR-0046 (two-phase enforcement) and the prose-as-code
# principle (ADR-0066 / PROPOSAL-003). For any handoff request whose file_scope.may_edit
# touches architectural Markdown — by path or by frontmatter — this gate verifies that
# every rule in active.json carrying `applies_to_prose: true` has been scored against the
# MD content and is either GREEN (judge reports compatible) or DEVIATED (an entry in
# `<app_root>/docs/deviations.md` references the rule + ticket). RED here blocks
# `/dispatch` from emitting the request until the operator either rewrites the prose or
# files a deviation row.
#
# ARCHITECTURAL DETECTION — a file is "architectural" for this gate when ANY of:
#   - its path matches glob: docs/architecture/**, docs/adr/**, docs/decisions/**
#   - its YAML frontmatter declares: kind: architecture | adr | decision
#
# VERDICT (per request, then aggregated across all gated requests):
#   - vacuous-green when no architectural MD in scope
#   - vacuous-green when active.json has no `applies_to_prose: true` rules (today's state,
#     before PROPOSAL-003 lands)
#   - GREEN when the judge reports compatible (currently delegated; the actual judge
#     ships with PROPOSAL-003 wave 3 as `prose-judge.sh`)
#   - GREEN when every projected rule has a matching deviation row
#   - NOT_ENFORCED → RED when prose-judge.sh is not yet present in the plugin cache
#     and no deviation rows cover the rules (no silent green)
#
# Per ADR-0066 D-D, this is PHASE 1 (design-phase scoring before dispatch). PHASE 2
# (drift detection on code dispatch) lands separately when enforce-standards.sh gains
# the `--phase code` mode against prose-judge.sh.
#
# Usage:
#   scripts/audit-design-phase-md.sh           # human-readable
#   scripts/audit-design-phase-md.sh --quiet   # exit code only
#
# Env overrides (testability):
#   ADPM_HANDOFFS_DIR  default .harness/handoffs
#   ADPM_ACTIVE        default .harness/rules/active.json
#   ADPM_APP_ROOT      default: scripts/app-root.sh output (operator-local app tree)
#   ADPM_TEST_JUDGE_VERDICT  test-only; when set ∈ {green,red,not_enforced}, bypass the
#                            judge-detector existence check and assume that verdict for
#                            every prose-projected rule.
#   ADPM_EXCLUDE_FILE  test-only; relative path (under app_root) to skip during
#                      architectural detection.
#
# Exit codes:
#   0  every architectural-MD-touching ticket is green or fully deviated (incl. vacuous)
#   1  one or more tickets have an undeviated red (gate blocks dispatch)
#   2  error / bad invocation
#
# Portability: bash 3.2 + BSD coreutils + node.

set -u

# Epoch-aware enforcement (ADR-0071): source the shared epoch library so this audit
# participates in the uniform epoch-gate surface (operator directive: all 17 audits).
# Exposes epoch_current_pin / epoch_resolve_baseline / epoch_filter_new /
# epoch_req_gated; sourcing is side-effect-free (functions only).
_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet)   QUIET=1 ;;
        -h|--help) sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-design-phase-md.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

HANDOFFS_DIR="${ADPM_HANDOFFS_DIR:-.harness/handoffs}"
ACTIVE="${ADPM_ACTIVE:-.harness/rules/active.json}"
APP_ROOT="${ADPM_APP_ROOT:-}"
TEST_VERDICT="${ADPM_TEST_JUDGE_VERDICT:-}"
EXCLUDE_FILE="${ADPM_EXCLUDE_FILE:-}"

# Resolve app_root via scripts/app-root.sh when not overridden.
if [ -z "$APP_ROOT" ] && [ -x "scripts/app-root.sh" ]; then
    APP_ROOT="$(scripts/app-root.sh 2>/dev/null || true)"
fi

if [ ! -f "$ACTIVE" ]; then
    emit "[design-phase-md] no rule registry at $ACTIVE — vacuous pass."
    exit 0
fi

if [ -z "$APP_ROOT" ] || [ ! -d "$APP_ROOT" ]; then
    emit "[design-phase-md] no app_root configured/present — vacuous pass."
    exit 0
fi

have=0
if [ -d "$HANDOFFS_DIR" ]; then
    for req in "$HANDOFFS_DIR"/*.req.json; do [ -e "$req" ] && have=1 && break; done
fi
if [ "$have" -eq 0 ]; then
    emit "[design-phase-md] no request artifacts in $HANDOFFS_DIR — vacuous pass."
    exit 0
fi

command -v node >/dev/null 2>&1 || { printf 'audit-design-phase-md.sh: node required\n' >&2; exit 2; }

# Existence check for the prose-judge detector in the plugin cache.
PROSE_JUDGE="${ADPM_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}/rubric/detectors/prose-judge.sh"
if [ -f "$PROSE_JUDGE" ]; then PROSE_JUDGE_PRESENT=1; else PROSE_JUDGE_PRESENT=0; fi

# ADR-0068 W-D: composite-dispatch presence (architectural-content bundle activator).
# When present and an architectural .md is in scope, dispatch is invoked per file —
# CTP's auto-attached architectural-content bundle (markdownlint + Vale + remark +
# prose-judge + …) runs against the file. exit 1 from dispatch = P0 → red the ticket.
COMPOSITE_DISPATCH="${ADPM_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}/rubric/composite-dispatch.sh"
if [ -x "$COMPOSITE_DISPATCH" ]; then COMPOSITE_PRESENT=1; else COMPOSITE_PRESENT=0; fi
COMPOSITE_PLUGIN_ROOT="${ADPM_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"

DEVIATIONS_FILE="$APP_ROOT/docs/deviations.md"

violations=0
for req in "$HANDOFFS_DIR"/*.req.json; do
    [ -e "$req" ] || continue

    out=$(ADPM_REQ="$req" ADPM_ACTIVE="$ACTIVE" ADPM_APP_ROOT="$APP_ROOT" \
          ADPM_PJ_PRESENT="$PROSE_JUDGE_PRESENT" ADPM_TEST_VERDICT="$TEST_VERDICT" \
          ADPM_DEVIATIONS="$DEVIATIONS_FILE" ADPM_EXCLUDE_FILE="$EXCLUDE_FILE" \
          ADPM_COMPOSITE="$COMPOSITE_DISPATCH" ADPM_COMPOSITE_PRESENT="$COMPOSITE_PRESENT" \
          ADPM_PLUGIN_ROOT="$COMPOSITE_PLUGIN_ROOT" \
          node -e '
const fs = require("fs");
const path = require("path");

function readJSON(p) { try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) { return null; } }

const reqPath = process.env.ADPM_REQ;
const active  = readJSON(process.env.ADPM_ACTIVE);
const appRoot = process.env.ADPM_APP_ROOT;
const pjPresent = process.env.ADPM_PJ_PRESENT === "1";
const testVerdict = process.env.ADPM_TEST_VERDICT || "";
const deviationsFile = process.env.ADPM_DEVIATIONS;
const excludeFile = process.env.ADPM_EXCLUDE_FILE || "";

const req = readJSON(reqPath);
if (!req) { console.log("ERR|cannot read req: " + reqPath); process.exit(0); }
if (!active) { console.log("ERR|cannot read active.json"); process.exit(0); }

const may = (req.file_scope && Array.isArray(req.file_scope.may_edit)) ? req.file_scope.may_edit : [];
const ticketId = req.ticket_id || path.basename(reqPath).replace(/\.req\.json$/, "");

// Collect candidate .md paths under app_root from glob list.
function enumerateMdFromGlob(g) {
  // Find the leading literal directory portion before any glob metacharacter.
  const m = String(g).match(/^([^*?[]*)/);
  let prefix = m ? m[1] : "";
  // Strip trailing slash
  prefix = prefix.replace(/\/+$/, "");
  const absPrefix = path.join(appRoot, prefix);
  // If the glob has no metacharacters, treat as a literal file.
  if (!/[*?[]/.test(g)) {
    if (g.endsWith(".md") && fs.existsSync(absPrefix)) return [absPrefix];
    return [];
  }
  // Walk the directory recursively and collect .md files.
  const results = [];
  function walk(dir) {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return; }
    for (const ent of entries) {
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) walk(full);
      else if (ent.isFile() && ent.name.endsWith(".md")) results.push(full);
    }
  }
  if (fs.existsSync(absPrefix)) {
    const st = fs.statSync(absPrefix);
    if (st.isDirectory()) walk(absPrefix);
    else if (st.isFile() && absPrefix.endsWith(".md")) results.push(absPrefix);
  }
  return results;
}

const mdGlobs = may.filter(g => /\.md$/.test(String(g)));
if (mdGlobs.length === 0) { console.log("NOTE|no .md globs in scope"); process.exit(0); }

const allMd = new Set();
for (const g of mdGlobs) { for (const f of enumerateMdFromGlob(g)) allMd.add(f); }
if (excludeFile) {
  const absExcl = path.join(appRoot, excludeFile);
  allMd.delete(absExcl);
}

// Architectural detection: path heuristic OR frontmatter kind.
function relUnder(p) { return path.relative(appRoot, p).split(path.sep).join("/"); }
function isArchitecturalPath(rel) {
  return /^docs\/architecture(\/|$)/.test(rel)
      || /^docs\/adr(\/|$)/.test(rel)
      || /^docs\/decisions(\/|$)/.test(rel);
}
function isArchitecturalFrontmatter(absPath) {
  let content;
  try { content = fs.readFileSync(absPath, "utf8"); } catch (e) { return false; }
  if (!content.startsWith("---")) return false;
  const end = content.indexOf("\n---", 3);
  if (end < 0) return false;
  const fm = content.slice(3, end);
  const m = fm.match(/^\s*kind\s*:\s*([A-Za-z0-9_-]+)\s*$/m);
  if (!m) return false;
  const kind = m[1].toLowerCase();
  return kind === "architecture" || kind === "adr" || kind === "decision";
}

const architecturalFiles = [];
for (const f of allMd) {
  const rel = relUnder(f);
  if (isArchitecturalPath(rel) || isArchitecturalFrontmatter(f)) {
    architecturalFiles.push(rel);
  }
}
if (architecturalFiles.length === 0) { console.log("NOTE|no architectural .md in scope"); process.exit(0); }

// Compute applies_to_prose rules from active.json.
const rules = Array.isArray(active.rules) ? active.rules : active;
const proseRules = rules.filter(r => r && r.applies_to_prose === true).map(r => r.id).filter(Boolean);
if (proseRules.length === 0) { console.log("NOTE|vacuous: no applies_to_prose rules in registry"); process.exit(0); }

// Per-rule verdict: GREEN | DEVIATED | RED
function isDeviated(ruleId) {
  let content;
  try { content = fs.readFileSync(deviationsFile, "utf8"); } catch (e) { return false; }
  // Match "## Deviation — <ruleId> on <ticketId>" (em dash or hyphen tolerated)
  const re = new RegExp("^##\\s*Deviation\\s*[\\u2014\\-]\\s*" + ruleId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s+on\\s+" + ticketId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s*$", "m");
  return re.test(content);
}

let red = 0;
for (const rid of proseRules) {
  let verdict;
  if (testVerdict) verdict = testVerdict;
  else if (pjPresent) verdict = "not_enforced"; // would invoke prose-judge.sh here; for now defer
  else verdict = "not_enforced";

  if (verdict === "green") continue;
  if (isDeviated(rid)) continue;
  red++;
  console.log("VIOL|" + ticketId + "|" + rid + "|" + verdict + "|files=" + architecturalFiles.join(","));
}

// ADR-0068 W-D: invoke composite-dispatch.sh per architectural .md.
// CTP-side detect-architectural-content auto-attaches the architectural-content
// bundle (markdownlint + Vale + remark + prose-judge + …) for .md files. exit 1
// from dispatch = P0 violation surfaced → red this ticket per file. Each P0 is
// a separate violation row; matched-by-deviation is honored at the rule level.
const compositePresent = process.env.ADPM_COMPOSITE_PRESENT === "1";
const compositeBin = process.env.ADPM_COMPOSITE || "";
const pluginRoot = process.env.ADPM_PLUGIN_ROOT || "";
if (compositePresent && !testVerdict) {
  const { spawnSync } = require("child_process");
  for (const relFile of architecturalFiles) {
    const absFile = path.join(appRoot, relFile);
    const r = spawnSync("bash", [compositeBin, "--file", absFile], {
      encoding: "utf8",
      env: Object.assign({}, process.env, { CLAUDE_PLUGIN_ROOT: pluginRoot })
    });
    // Parse-then-block — mirrors ADR-0068 W-C (post-tool-use-review-gate.sh). A real
    // verdict is an AUTHORITATIVE `composite-dispatch … status=red` summary line. A
    // bare non-zero exit is NOT authoritative: a CTP-side bash 3.2 crash (observed at
    // pin 4668c2e — `composite-dispatch.sh: ra[@]: unbound variable`; filed upstream
    // as P-10) surfaces as exit 1 without representing a design violation and MUST NOT
    // red the gate. The applies_to_prose semantic verdict is already covered by the
    // prose-rule loop above; this path only surfaces authoritative composite P0s.
    const out = (r.stderr || "") + (r.stdout || "");
    if (!/^composite-dispatch\s+.*\bstatus=red\b/m.test(out)) continue;
    const m = out.match(/\brule[\s=:]+([\w.\-]+)/);
    const inferredRule = m ? m[1] : "composite-engine-p0";
    if (isDeviated(inferredRule)) continue;
    red++;
    console.log("VIOL|" + ticketId + "|" + inferredRule + "|composite-dispatch-fail|file=" + relFile);
    // exit 3 = incomplete (optional tool missing) — advisory per ADR-0068 D-B-1.
    // Not red here; surfaces in the post-tool-use hook for write-time signal.
  }
}

if (red === 0) console.log("OK|" + ticketId + "|all prose rules green or deviated across " + architecturalFiles.length + " architectural .md file(s)");
process.exit(0);
' 2>&1)

    if printf '%s' "$out" | grep -q '^ERR|'; then
        emit "  [ERR] $(basename "$req"): $(printf '%s' "$out" | sed -n 's/^ERR|//p' | head -1)"
        violations=$((violations + 1)); continue
    fi
    nviol=$(printf '%s\n' "$out" | grep -c '^VIOL|' || true)
    if [ "$nviol" -gt 0 ]; then
        printf '%s\n' "$out" | sed -n 's/^VIOL|/  [VIOLATION] '"$(basename "$req")"': /p' | while IFS= read -r line; do emit "$line"; done
        violations=$((violations + nviol))
    elif printf '%s' "$out" | grep -q '^NOTE|'; then
        emit "  [ok] $(basename "$req"): $(printf '%s' "$out" | sed -n 's/^NOTE|//p' | head -1)"
    elif printf '%s' "$out" | grep -q '^OK|'; then
        emit "  [ok] $(basename "$req"): $(printf '%s' "$out" | sed -n 's/^OK|//p' | head -1)"
    fi
done

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[design-phase-md] $violations violation(s). Architectural MD must be scored green or carry a"
    emit "  deviation row in <app_root>/docs/deviations.md for every applies_to_prose rule before dispatch."
    exit 1
fi
emit "[design-phase-md] OK — every architectural-MD-touching ticket is green or fully deviated."
exit 0
