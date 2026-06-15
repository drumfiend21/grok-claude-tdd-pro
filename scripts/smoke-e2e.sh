#!/usr/bin/env bash
# scripts/smoke-e2e.sh — end-to-end harness smoke test for TICKET-006.
#
# Drives one full Red-Green-Refactor cycle against examples/string-utils/
# (the TICKET-005 toy) through the harness's wire format:
#
#   1. Outer-loop emit    : write .harness/handoffs/<id>.req.json from the
#                           dispatch template's schema (docs/handoff-contract.md
#                           §"Grok → Claude"). Validate before emit.
#   2. Inner-loop work    : apply the canonical .trim() Green patch to
#                           examples/string-utils/src/string-utils.mjs.
#   3. Test gate          : node --test must report all-pass.
#   4. Outer-loop receive : write .harness/handoffs/<id>.res.json and
#                           .harness/trails/<id>.md (docs/handoff-contract.md
#                           §"Claude → Grok").
#
# This is STUB mode — no Claude API call. The inner-loop's deterministic patch
# stands in for the live tdd-pro-cl-workflow skill invocation. The wire format
# (request, response, trail) is REAL and validates against the contract.
# Live-Claude mode is deferred per ADR-0008.
#
# Idempotent: trap reverts the toy fix at exit so the next run starts from the
# same Red baseline (preserves TICKET-005's "4 pass / 1 fail" invariant).
#
# Per D-11 (design FOR primitives): consumes bash, node:test, mktemp, grep, awk.
# No new tooling introduced. Validated against tdd-pro-bash32-portability.

set -euo pipefail

readonly TICKET_ID="TICKET-042"
readonly REQ_PATH=".harness/handoffs/${TICKET_ID}.req.json"
readonly RES_PATH=".harness/handoffs/${TICKET_ID}.res.json"
readonly TRAIL_PATH=".harness/trails/${TICKET_ID}.md"
readonly TOY_SRC="examples/string-utils/src/string-utils.mjs"
readonly TOY_TEST="examples/string-utils/test/string-utils.test.mjs"

VERBOSE=0

usage() {
    cat >&2 <<EOF
Usage: $0 [--verbose] [-h|--help]

Runs the harness end-to-end smoke test against the TICKET-005 toy module.

  --verbose      Print full test output on failure
  -h, --help     Show this help (to stderr)

Exit codes:
  0  full cycle green (request emitted, fix applied, tests pass, response emitted)
  1  any step failed; see stderr for which step
  2  usage error
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --verbose) VERBOSE=1; shift;;
        -h|--help) usage; exit 0;;
        *) usage; exit 2;;
    esac
done

log()  { printf '[smoke-e2e] %s\n' "$*" >&2; }
fail() { printf '[smoke-e2e] FAIL: %s\n' "$*" >&2; exit 1; }

# --- Cleanup: revert toy fix on any exit to preserve TICKET-005's Red baseline.
TOY_BACKUP=""
cleanup() {
    if [[ -n "$TOY_BACKUP" ]] && [[ -f "$TOY_BACKUP" ]]; then
        mv -- "$TOY_BACKUP" "$TOY_SRC" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# --- Step 0: preconditions ---
log "step 0/4: verify preconditions"
[[ -f "$TOY_SRC" ]]  || fail "missing toy source: $TOY_SRC"
[[ -f "$TOY_TEST" ]] || fail "missing toy test: $TOY_TEST"
command -v node >/dev/null || fail "node not on PATH"
mkdir -p .harness/handoffs .harness/trails

# Confirm Red baseline.
if node --test "$TOY_TEST" >/dev/null 2>&1; then
    fail "TICKET-005 invariant broken: toy tests already green at start; expected Red baseline"
fi
log "  ok: toy at Red baseline (one failing test)"

# Back up the toy before patching.
TOY_BACKUP="$(mktemp)"
cp -- "$TOY_SRC" "$TOY_BACKUP"

# --- Step 1: outer-loop emit (.req.json) ---
log "step 1/4: outer-loop emit handoff request"

ISSUED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

# In a live run this would be `grok -p < .grok/templates/dispatch.md`.
# Here we build the same document directly from the contract example.
env TICKET_ID="$TICKET_ID" ISSUED_AT="$ISSUED_AT" REQ_PATH="$REQ_PATH" node -e '
const fs = require("fs");
const req = {
    schema_version: "1",
    ticket_id: process.env.TICKET_ID,
    title: "trim whitespace in slugify()",
    issued_at: process.env.ISSUED_AT,
    context_ttl_seconds: 1800,
    acceptance_criteria: [
        "slugify(\"  hello world  \") returns \"hello-world\"",
        "slugify(\"\") returns \"\""
    ],
    file_scope: {
        may_edit: [
            "examples/string-utils/src/string-utils.mjs",
            "examples/string-utils/test/string-utils.test.mjs"
        ],
        may_read: ["examples/string-utils/**"],
        must_not_touch: [".grok/**", ".claude/**", "claude-tdd-pro/**"]
    },
    context: {
        research_refs: [],
        decomposition_parent: "FEATURE-007",
        prior_decisions: [{
            ticket_id: "TICKET-005",
            decision: "toy ships at 4 pass / 1 fail; the fail is the cycle the harness must close"
        }]
    },
    quality_gate: { tests_must_pass: true, coverage_delta_min: 0, lint_clean: true }
};
fs.writeFileSync(process.env.REQ_PATH, JSON.stringify(req, null, 2) + "\n");
' || fail "failed to write request"
log "  ok: wrote $REQ_PATH"

# Validate per dispatch.md §"Pre-emit checks".
env REQ_PATH="$REQ_PATH" node -e '
const req = JSON.parse(require("fs").readFileSync(process.env.REQ_PATH, "utf8"));
const fail = (m) => { console.error("schema_invalid: " + m); process.exit(1); };
if (req.schema_version !== "1") fail("schema_version != \"1\"");
if (!Array.isArray(req.acceptance_criteria) || req.acceptance_criteria.length < 1) fail("acceptance_criteria empty");
if (!Array.isArray(req.file_scope.may_edit) || req.file_scope.may_edit.length < 1) fail("may_edit empty");
for (const dl of [".grok/**", ".claude/**", "claude-tdd-pro/**"]) {
    if (!req.file_scope.must_not_touch.includes(dl)) fail("must_not_touch missing " + dl);
}
if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(req.issued_at)) fail("issued_at not ISO-8601 second-precision UTC");
if (req.context_ttl_seconds < 60 || req.context_ttl_seconds > 86400) fail("context_ttl_seconds out of [60, 86400]");
' || fail "request schema validation failed (see dispatch.md pre-emit checks)"
log "  ok: request validates against handoff-contract.md §Grok→Claude"

# --- Step 2: inner-loop apply Green patch ---
log "step 2/4: inner-loop (STUB) apply Green patch"
env TOY_SRC="$TOY_SRC" node -e '
const fs = require("fs");
const src = fs.readFileSync(process.env.TOY_SRC, "utf8");
const patched = src.replace(/(\.toLowerCase\(\))/, "$1\n        .trim()");
if (src === patched) { console.error("patch did not apply (no .toLowerCase() found)"); process.exit(1); }
fs.writeFileSync(process.env.TOY_SRC, patched);
' || fail "failed to apply Green patch"
log "  ok: .trim() inserted after .toLowerCase()"

# --- Step 3: test gate ---
log "step 3/4: test gate"
TEST_OUT="$(mktemp)"
TEST_EXIT=0
# Force the TAP reporter so the parse below is deterministic across Node versions.
# Node >= 24 defaults to the `spec` reporter (emits "ℹ pass N", not "# pass N") even
# when piped, which silently broke the `grep '^# pass '` parse under set -o pipefail.
# TAP output is identical on the LTS line and stable going forward (per ADR-0051).
node --test --test-reporter=tap "$TOY_TEST" > "$TEST_OUT" 2>&1 || TEST_EXIT=$?
if (( TEST_EXIT != 0 )); then
    if (( VERBOSE )); then cat -- "$TEST_OUT" >&2; fi
    rm -f -- "$TEST_OUT"
    fail "test gate failed (node --test exit=$TEST_EXIT); inner loop did not close the Red test"
fi
# `|| true` so a no-match never aborts the pipeline under `set -o pipefail` before
# the explicit guard below — the script reports a clear parse error instead of dying
# silently (the failure mode that masked the Node-24 reporter change; ADR-0051).
TESTS_PASSED="$(grep -- '^# pass ' "$TEST_OUT" | awk '{print $3}' || true)"
TESTS_FAILED="$(grep -- '^# fail ' "$TEST_OUT" | awk '{print $3}' || true)"
DURATION_MS="$(grep -- '^# duration_ms ' "$TEST_OUT" | awk '{printf "%d", $3}' || true)"
rm -f -- "$TEST_OUT"
[[ -n "$TESTS_PASSED" ]] || fail "could not parse test pass count (node --test output format?)"
[[ "$TESTS_FAILED" == "0" ]] || fail "test gate reported $TESTS_FAILED failures"
log "  ok: $TESTS_PASSED passed, $TESTS_FAILED failed"

# --- Step 4: emit response (.res.json) + decision trail ---
log "step 4/4: outer-loop receive response"
COMPLETED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
env TICKET_ID="$TICKET_ID" COMPLETED_AT="$COMPLETED_AT" \
    TOY_SRC="$TOY_SRC" TRAIL_PATH="$TRAIL_PATH" RES_PATH="$RES_PATH" \
    TESTS_PASSED="$TESTS_PASSED" TESTS_FAILED="$TESTS_FAILED" DURATION_MS="$DURATION_MS" \
    node -e '
const fs = require("fs");
const env = process.env;
const res = {
    schema_version: "1",
    ticket_id: env.TICKET_ID,
    status: "green",
    completed_at: env.COMPLETED_AT,
    changed_files: [{ path: env.TOY_SRC, lines_added: 1, lines_removed: 0 }],
    test_results: {
        framework: "node:test",
        passed: parseInt(env.TESTS_PASSED, 10),
        failed: parseInt(env.TESTS_FAILED, 10),
        skipped: 0,
        duration_ms: parseInt(env.DURATION_MS, 10)
    },
    coverage_delta: 0.0,
    decision_trail_ref: env.TRAIL_PATH,
    skills_invoked: ["tdd-pro-cl-workflow"],
    notes: "STUB MODE: response synthesized by scripts/smoke-e2e.sh; deterministic .trim() patch stood in for live claude -p invocation.",
    error: null
};
fs.writeFileSync(env.RES_PATH, JSON.stringify(res, null, 2) + "\n");
' || fail "failed to write response"
log "  ok: wrote $RES_PATH"

# Decision trail (referenced by res.decision_trail_ref).
cat > "$TRAIL_PATH" <<TRAIL
# Decision Trail — ${TICKET_ID}

**Mode:** stub (scripts/smoke-e2e.sh)
**Completed:** ${COMPLETED_AT}

## R-G-R cycle

- **Red:** \`slugify('  hello world  ')\` returned \`'-hello-world-'\`. Expected \`'hello-world'\`. Root cause: no whitespace trim before internal-whitespace collapse.
- **Green:** Added \`.trim()\` after \`.toLowerCase()\` in \`${TOY_SRC}\`. Tests now ${TESTS_PASSED} pass / ${TESTS_FAILED} fail.
- **Refactor:** None. Single-line change; further restructuring would be embellishment per Musk's Algorithm step 3 ("simplify, don't accelerate what shouldn't exist").

## Files touched

- \`${TOY_SRC}\` (+1 line)

## Quality gate

- tests_must_pass: pass
- coverage_delta_min ≥ 0: pass (no coverage tooling; reported as 0.0 — TICKET-007 will formalize)
- lint_clean: pass (no linter configured — TICKET-007 will formalize)

## Provenance

Generated by \`scripts/smoke-e2e.sh\` in stub mode. Live-Claude mode (deferred per ADR-0008) will emit this trail via the tdd-pro-cl-workflow skill instead.
TRAIL
log "  ok: wrote $TRAIL_PATH"

log "smoke OK — outer loop → handoff → inner loop → green tests → response"
log "  request : $REQ_PATH"
log "  response: $RES_PATH"
log "  trail   : $TRAIL_PATH"

# Provenance manifest (TICKET-010.a / ADR-0019): index the three sources
# with sha256 + size_bytes for tamper detection per the design in
# docs/provenance-bridging-design.md. Defensive call — only invoked when
# the emitter is present; non-zero exit is logged as a warning rather
# than failing the smoke (the manifest is additive audit evidence, not a
# smoke gate).
if [ -x "scripts/emit-manifest.sh" ]; then
    if scripts/emit-manifest.sh --ticket "$TICKET_ID" --driver smoke-e2e.sh --quiet; then
        log "  manifest: .harness/audit/${TICKET_ID}.manifest.json"
    else
        log "  warn: emit-manifest.sh exited non-zero (manifest may be degraded)"
    fi
fi

# AIBOM emit (per TICKET-033 / ADR-0038 Batch 8). Wires the plugin's
# compliance/aibom-emit.sh so every green ticket produces an AI Bill of
# Materials alongside the manifest. Defensive — non-fatal on error.
PLUGIN_CACHE=".harness/plugin-cache/claude-tdd-pro"
AIBOM_EMITTER="$PLUGIN_CACHE/compliance/aibom-emit.sh"
AIBOM_PATH=".harness/audit/${TICKET_ID}.aibom.json"
if [ -x "$AIBOM_EMITTER" ]; then
    CLAUDE_PLUGIN_ROOT="$PLUGIN_CACHE" \
    bash "$AIBOM_EMITTER" --out "$AIBOM_PATH" 2>/dev/null && \
        log "  aibom   : $AIBOM_PATH" || \
        log "  warn: aibom-emit.sh exited non-zero (compliance artifact may be degraded)"
fi

# trap cleanup restores TOY_SRC from backup on EXIT (preserves Red baseline).
exit 0
