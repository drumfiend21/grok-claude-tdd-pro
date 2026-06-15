#!/usr/bin/env bash
# tests/test-audit-eo-governance.sh — unit tests for scripts/audit-eo-governance.sh
# Per TICKET-050. Exit-code contract: 0 (invariants hold / vacuous) / 1 (violation) / 2 (error).
#
# Uses env-overridable fixture paths (EO_RULES_FILE / EO_HANDOFFS_DIR / EO_NAMESPACES)
# so the content-agnostic spine can be exercised WITH and WITHOUT EO rules present,
# without touching the real (gitignored) .harness/ runtime artifacts.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-eo-governance] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-eo-governance.sh

TMP=$(mktemp -d -t eo-gov-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/handoffs"

# Registry WITHOUT an eo namespace (mirrors the real current state).
cat > "$TMP/active-noeo.json" <<'JSON'
{"version":1,"rules":[
{"id":"g-node-007","source_namespace":"node"},
{"id":"g-owasp-003","source_namespace":"owasp"}
]}
JSON

# Registry WITH an eo namespace rule (mirrors post-pin-bump state).
cat > "$TMP/active-eo.json" <<'JSON'
{"version":1,"rules":[
{"id":"g-node-007","source_namespace":"node"},
{"id":"eo-cyber-001","name":"vuln-remediation","provenance":[{"source":"a"},{"source":"b"}],"source_namespace":"eo"}
]}
JSON

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: no EO rules in registry → vacuous pass (spine armed), exit 0
EO_RULES_FILE="$TMP/active-noeo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "0" "no EO namespace → vacuous pass (exit 0)"

# Test 4: EO rule present, req omits it from applicable_rules → violation (exit 1)
cat > "$TMP/handoffs/TICKET-900.req.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-900","applicable_rules":["g-node-007"]}
JSON
EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "1" "EO rule omitted from applicable_rules → violation (exit 1)"

# Test 5: req includes the EO rule + green res WITH attestation → exit 0
cat > "$TMP/handoffs/TICKET-900.req.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-900","applicable_rules":["g-node-007","eo-cyber-001"]}
JSON
cat > "$TMP/handoffs/TICKET-900.res.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-900","status":"green","eo_design_conformance":{"design_phase_attested":true,"rules_considered":["eo-cyber-001"]}}
JSON
EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "0" "EO rule present in applicable_rules + green res w/ attestation → exit 0"

# Test 6: green res MISSING attestation → violation (exit 1)
cat > "$TMP/handoffs/TICKET-900.res.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-900","status":"green"}
JSON
EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "1" "green res missing eo_design_conformance → violation (exit 1)"

# Test 7: green res with EMPTY attestation (null) → violation (exit 1)
cat > "$TMP/handoffs/TICKET-900.res.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-900","status":"green","eo_design_conformance":null}
JSON
EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "1" "green res with null attestation → violation (exit 1)"

# Test 8: req with NO applicable_rules field (fail-closed default) + green res w/ attestation → exit 0
rm -f "$TMP/handoffs/TICKET-900.req.json"
cat > "$TMP/handoffs/TICKET-901.req.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-901"}
JSON
cat > "$TMP/handoffs/TICKET-901.res.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-901","status":"green","eo_design_conformance":{"design_phase_attested":true}}
JSON
rm -f "$TMP/handoffs/TICKET-900.res.json"
EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "0" "absent applicable_rules = fail-closed default (all apply) → exit 0"

# Test 9: EO rule id correctly extracted despite nested braces (multi-provenance)
out=$(EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" 2>&1)
case "$out" in
    *"eo-cyber-001"*) log "  ✓ EO rule id extracted despite nested provenance braces"; passes=$((passes+1)) ;;
    *) log "  ✗ EO rule id not extracted from nested-brace rule"; failures=$((failures+1)) ;;
esac

# Test 10: non-eo namespace override → 'node' treated as EO subset, req must carry it
cat > "$TMP/handoffs/TICKET-902.req.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-902","applicable_rules":["g-owasp-003"]}
JSON
rm -f "$TMP/handoffs/TICKET-901.req.json" "$TMP/handoffs/TICKET-901.res.json"
EO_NAMESPACES="node" EO_RULES_FILE="$TMP/active-noeo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "1" "EO_NAMESPACES override is honored (node-as-EO; req omits g-node-007 → violation)"

# Test 11: a NON-green (red) response missing the attestation is NOT a violation
# (the two-phase design attestation is only required for green responses).
rm -f "$TMP/handoffs"/TICKET-*.req.json "$TMP/handoffs"/TICKET-*.res.json
cat > "$TMP/handoffs/TICKET-903.req.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-903","applicable_rules":["g-node-007","eo-cyber-001"]}
JSON
cat > "$TMP/handoffs/TICKET-903.res.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-903","status":"red","error":{"code":"gate_failed"}}
JSON
EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "0" "red response without attestation is not flagged (only green requires it)"

# Test 12: a green response whose rules_verified marks the EO rule 'deviated'
# (not 'pass') is still acceptable so long as the design attestation is present.
cat > "$TMP/handoffs/TICKET-903.res.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-903","status":"green","rules_verified":{"eo-cyber-001":"deviated"},"eo_design_conformance":{"design_phase_attested":true,"rules_considered":["eo-cyber-001"]}}
JSON
EO_RULES_FILE="$TMP/active-eo.json" EO_HANDOFFS_DIR="$TMP/handoffs" "$SCRIPT" --quiet
assert_eq "$?" "0" "green + deviated EO rule + attestation present → exit 0"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-eo-governance] OK — $passes/$total passed."; exit 0
else log "[test-audit-eo-governance] FAIL — $failures/$total."; exit 1; fi
