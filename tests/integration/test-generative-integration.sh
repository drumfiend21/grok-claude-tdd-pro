#!/usr/bin/env bash
# tests/integration/test-generative-integration.sh
#
# Integration tests for the harness's generative functions — cloud architecture
# AND fullstack development. Per TICKET-052 / ADR-0050.
#
# Each scenario simulates a NON-TECHNICAL user describing software in plain
# English, and asserts the harness delivers WORLD-CLASS software: every
# authoritative-source standard applicable to the user's detected stack
# (fullstack AND cloud) is enforced via applicable_rules, the EO governance
# layer is non-exemptible + two-phase, the wire contract validates, and the
# response is green — even for standards the user could never name (accessibility,
# Core Web Vitals, OWASP boundary validation, SLSA provenance).
#
# STUB mode (live-LLM e2e deferred per ADR-0008): tests/integration/simulate.mjs
# stands in for a live tdd-pro-cl-workflow generation. What is REAL: the wire
# contract, the world-class-coverage definition, and the harness gates —
# scripts/audit-eo-governance.sh + scripts/audit-source-citations.sh are run over
# the emitted artifacts, so the actual harness enforcement is exercised.
#
# NEGATIVE scenarios prove the gates BITE (they reject sub-world-class delivery),
# so a green run is a real signal, not a rubber stamp.
#
# Exit codes: 0 all integration assertions hold / 1 a regression / 2 setup error.
# Portability: bash 3.2 + BSD coreutils; requires node (as does smoke-e2e).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-generative-integration] starting"

command -v node >/dev/null 2>&1 || { log "node not on PATH (required, as for smoke-e2e)"; exit 2; }

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

HERE="tests/integration"
SIM="$HERE/simulate.mjs"
SCEN_DIR="$HERE/scenarios"
ACTIVE=".harness/rules/active.json"
EO_RULE="eo-cyber-001"

[ -f "$SIM" ]    || { log "missing simulator: $SIM"; exit 2; }
[ -d "$SCEN_DIR" ] || { log "missing scenarios dir: $SCEN_DIR"; exit 2; }
[ -f "$ACTIVE" ] || { log "missing active registry: $ACTIVE"; exit 2; }

TMP=$(mktemp -d -t integ-gen-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# Fixture EO registry so the (currently pin-bump-gated) EO governance layer is
# exercised end-to-end: it contains a real eo-namespace rule the requests must
# carry and whose green responses must attest.
cat > "$TMP/active-eo.json" <<'JSON'
{"version":1,"rules":[
{"id":"g-node-007","source_namespace":"node"},
{"id":"eo-cyber-001","name":"misuse-resistance","provenance":[{"source":"eo-2026"}],"source_namespace":"eo"}
]}
JSON
EO_REG="$TMP/active-eo.json"

persona_of() { grep -oE '"persona": *"[^"]*"' "$1" | head -1 | sed -E 's/.*"persona": *"([^"]*)".*/\1/'; }
domain_of()  { grep -oE '"domain": *"[^"]*"' "$1" | head -1 | sed -E 's/.*"domain": *"([^"]*)".*/\1/'; }

# --- Positive batch: every scenario delivers world-class software ------------
POS_DIR="$TMP/pos"
mkdir -p "$POS_DIR"
cloud_count=0; fullstack_count=0; scen_count=0

for scen in "$SCEN_DIR"/*.json; do
    [ -e "$scen" ] || continue
    scen_count=$((scen_count + 1))
    persona=$(persona_of "$scen")
    domain=$(domain_of "$scen")
    case "$domain" in
        cloud)     cloud_count=$((cloud_count + 1)) ;;
        fullstack) fullstack_count=$((fullstack_count + 1)) ;;
    esac

    out=$(node "$SIM" "$scen" "$ACTIVE" "$POS_DIR" world-class "$EO_RULE" 2>&1); ec=$?
    assert_eq "$ec" "0" "[$domain] world-class delivery for: $persona"
    if [ "$ec" -ne 0 ] && [ "$QUIET" -eq 0 ]; then printf '%s\n' "$out"; fi
done

# Both generative domains must be represented.
[ "$cloud_count" -ge 1 ] && { log "  ✓ cloud-architecture scenarios present ($cloud_count)"; passes=$((passes+1)); } \
                         || { log "  ✗ no cloud-architecture scenarios"; failures=$((failures+1)); }
[ "$fullstack_count" -ge 1 ] && { log "  ✓ fullstack-development scenarios present ($fullstack_count)"; passes=$((passes+1)); } \
                             || { log "  ✗ no fullstack-development scenarios"; failures=$((failures+1)); }

# Real harness gate over the whole batch: EO non-exemptibility + two-phase.
EO_RULES_FILE="$EO_REG" EO_HANDOFFS_DIR="$POS_DIR" ./scripts/audit-eo-governance.sh --quiet
assert_eq "$?" "0" "EO governance gate (non-exemptible + two-phase) green over all deliveries"

# Real harness gate (global): every enforced rule traces to a cited source.
./scripts/audit-source-citations.sh --quiet
assert_eq "$?" "0" "citation-integrity gate green (every enforced standard is cited)"

# --- Negative scenarios: the gates must REJECT sub-world-class delivery -------
REP_SCEN="$SCEN_DIR/recipe-sharing-web-app.json"        # fullstack, critical_namespace=w3c
CLOUD_SCEN="$SCEN_DIR/serverless-photo-resize-api.json" # cloud, critical_namespace=owasp

# N1: a delivery that silently drops the scenario's critical standard family
# (accessibility for the recipe site) is caught by the stack-coverage check.
node "$SIM" "$REP_SCEN" "$ACTIVE" "$TMP/neg-drop" drop-stack "$EO_RULE" >/dev/null 2>&1
assert_eq "$?" "1" "N1: dropping a fullstack standard (a11y/w3c) is rejected as sub-world-class"

# N1b: same for a cloud scenario dropping its critical security family (owasp).
node "$SIM" "$CLOUD_SCEN" "$ACTIVE" "$TMP/neg-drop-cloud" drop-stack "$EO_RULE" >/dev/null 2>&1
assert_eq "$?" "1" "N1b: dropping a cloud standard (owasp) is rejected as sub-world-class"

# N2: a green response with no design-phase EO attestation passes stack coverage
# but the EO two-phase gate must reject it.
mkdir -p "$TMP/neg-eoattest"
node "$SIM" "$REP_SCEN" "$ACTIVE" "$TMP/neg-eoattest" omit-eo-attestation "$EO_RULE" >/dev/null 2>&1
assert_eq "$?" "0" "N2: stack coverage still complete when only the EO attestation is missing"
EO_RULES_FILE="$EO_REG" EO_HANDOFFS_DIR="$TMP/neg-eoattest" ./scripts/audit-eo-governance.sh --quiet
assert_eq "$?" "1" "N2: missing EO design attestation is rejected by the two-phase gate"

# N3: a request that drops the non-exemptible EO rule must be caught by the
# non-exemptibility gate (even though stack coverage is fine).
mkdir -p "$TMP/neg-eorule"
node "$SIM" "$CLOUD_SCEN" "$ACTIVE" "$TMP/neg-eorule" omit-eo-rule "$EO_RULE" >/dev/null 2>&1
assert_eq "$?" "0" "N3: stack coverage still complete when only the EO rule is dropped"
EO_RULES_FILE="$EO_REG" EO_HANDOFFS_DIR="$TMP/neg-eorule" ./scripts/audit-eo-governance.sh --quiet
assert_eq "$?" "1" "N3: dropping the non-exemptible EO rule is rejected"

# --- Coverage breadth: at least the documented scenario count ----------------
[ "$scen_count" -ge 6 ] && { log "  ✓ scenario breadth: $scen_count personas across cloud + fullstack"; passes=$((passes+1)); } \
                        || { log "  ✗ too few scenarios ($scen_count < 6)"; failures=$((failures+1)); }

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-generative-integration] OK — $passes/$total passed."; exit 0
else log "[test-generative-integration] FAIL — $failures/$total."; exit 1; fi
