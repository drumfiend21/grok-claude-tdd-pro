#!/usr/bin/env bash
# tests/test-source-citations.sh — unit tests for scripts/audit-source-citations.sh
# Per TICKET-051 / ADR-0049. Exit-code contract: 0 (invariants hold) / 1 (violation) / 2 (error).
#
# Uses env-overridable fixtures (SRC_RULES_FILE / SRC_REQUIRED_NS / SRC_ALLOW_EMPTY_NS /
# SRC_SECURITY_NS / SRC_SOURCE_DOCS / SRC_ROOT) so both halves of the gate — operator-
# standards citation integrity (PART A) and authoritative-source doc integrity (PART B) —
# are exercised against controlled inputs without touching the real registry/docs.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-source-citations] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}
assert_match() {
    case "$1" in
        *"$2"*) log "  ✓ $3"; passes=$((passes+1)) ;;
        *)      log "  ✗ $3 (no match for '$2')"; failures=$((failures+1)) ;;
    esac
}

SCRIPT=./scripts/audit-source-citations.sh

TMP=$(mktemp -d -t src-cite-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# --- PART A fixtures ---------------------------------------------------------
# Good registry: google (P1, cited), owasp (P0, cited + controls), _community empty.
cat > "$TMP/good.json" <<'JSON'
{"version":1,"namespaces_seen":["google","owasp","_community"],"rules":[
{"id":"g-ts-001","severity":"P1","provenance":[{"source":"google-tsguide","section":"§5.2"}],"source_namespace":"google"},
{"id":"g-sec-001","severity":"P0","provenance":[{"source":"owasp-asvs","section":"V5.1"}],"controls":[{"framework":"soc2-tsc","section":"CC6.1"}],"source_namespace":"owasp"}
]}
JSON

# owasp P0 WITHOUT controls — A5 is informational, must NOT fail.
cat > "$TMP/good-noctrl.json" <<'JSON'
{"version":1,"namespaces_seen":["google","owasp","_community"],"rules":[
{"id":"g-ts-001","severity":"P1","provenance":[{"source":"google-tsguide","section":"§5.2"}],"source_namespace":"google"},
{"id":"g-sec-002","severity":"P0","provenance":[{"source":"slsa","section":"build"}],"source_namespace":"owasp"}
]}
JSON

# A1 violation: a rule with an empty provenance:[] array.
cat > "$TMP/bad-emptyprov.json" <<'JSON'
{"version":1,"namespaces_seen":["google","owasp"],"rules":[
{"id":"g-ts-001","severity":"P1","provenance":[],"source_namespace":"google"},
{"id":"g-sec-001","severity":"P0","provenance":[{"source":"owasp-asvs","section":"V5.1"}],"source_namespace":"owasp"}
]}
JSON

# A2 violation: a provenance entry with an empty source.
cat > "$TMP/bad-emptysrc.json" <<'JSON'
{"version":1,"namespaces_seen":["google","owasp"],"rules":[
{"id":"g-ts-001","severity":"P1","provenance":[{"source":"","section":"§5.2"}],"source_namespace":"google"},
{"id":"g-sec-001","severity":"P0","provenance":[{"source":"owasp-asvs","section":"V5.1"}],"source_namespace":"owasp"}
]}
JSON

# A3 violation: namespaces_seen lists 'react' but no react rule exists (react not allow-empty).
cat > "$TMP/bad-nsempty.json" <<'JSON'
{"version":1,"namespaces_seen":["google","owasp","react"],"rules":[
{"id":"g-ts-001","severity":"P1","provenance":[{"source":"google-tsguide","section":"§5.2"}],"source_namespace":"google"},
{"id":"g-sec-001","severity":"P0","provenance":[{"source":"owasp-asvs","section":"V5.1"}],"source_namespace":"owasp"}
]}
JSON

# Empty registry → fail-closed (nothing cited).
cat > "$TMP/empty.json" <<'JSON'
{"version":1,"namespaces_seen":[],"rules":[]}
JSON

# --- PART B fixtures: a cited doc + an orphan (uncited) doc -------------------
mkdir -p "$TMP/docroot/docs"
printf '# srcdoc\n' > "$TMP/docroot/docs/srcdoc.md"
printf 'see docs/srcdoc.md for details\n' > "$TMP/docroot/refs.md"   # cites srcdoc.md
printf '# orphan\n' > "$TMP/docroot/docs/orphan.md"                  # nothing cites this

# Benign PART-A env reused so PART-A passes while we probe PART B (and vice versa).
A_OK="SRC_RULES_FILE=$TMP/good.json SRC_REQUIRED_NS=google owasp SRC_ALLOW_EMPTY_NS=_community SRC_SECURITY_NS=owasp"
# A cited source-doc set so PART B passes while we probe PART A.
B_OK_DOCS="$TMP/docroot/docs/srcdoc.md"

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: missing rules file exits 2
SRC_RULES_FILE="$TMP/nope.json" "$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "2" "missing rules registry exits 2"

# Test 4: good fixture → exit 0 (both parts clean)
SRC_RULES_FILE="$TMP/good.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
  SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "0" "good fixture → exit 0"

# Test 5: --quiet suppresses output on a clean run
out=$(SRC_RULES_FILE="$TMP/good.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
      SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet 2>&1)
[ -z "$out" ] && { log "  ✓ --quiet suppresses output"; passes=$((passes+1)); } \
              || { log "  ✗ --quiet emitted output"; failures=$((failures+1)); }

# Test 6: A1 — empty provenance:[] → violation (exit 1)
SRC_RULES_FILE="$TMP/bad-emptyprov.json" SRC_REQUIRED_NS="google owasp" SRC_SECURITY_NS="owasp" \
  SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "1" "A1: empty provenance[] → violation (exit 1)"

# Test 7: A2 — empty provenance source → violation (exit 1)
SRC_RULES_FILE="$TMP/bad-emptysrc.json" SRC_REQUIRED_NS="google owasp" SRC_SECURITY_NS="owasp" \
  SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "1" "A2: empty provenance source → violation (exit 1)"

# Test 8: A3 — namespace seen but empty (not allow-empty) → violation (exit 1)
SRC_RULES_FILE="$TMP/bad-nsempty.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
  SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "1" "A3: seen-but-empty namespace → violation (exit 1)"

# Test 9: A4 — a required namespace missing entirely → violation (exit 1)
SRC_RULES_FILE="$TMP/good.json" SRC_REQUIRED_NS="google owasp slsa" SRC_ALLOW_EMPTY_NS="_community" \
  SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "1" "A4: required namespace 'slsa' absent → violation (exit 1)"

# Test 10: empty registry → fail-closed violation (exit 1)
SRC_RULES_FILE="$TMP/empty.json" SRC_REQUIRED_NS="" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "1" "empty registry → fail-closed (exit 1)"

# Test 11: A5 informational — owasp P0 without controls does NOT fail (exit 0), but is reported
out=$(SRC_RULES_FILE="$TMP/good-noctrl.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
      SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" 2>&1)
ec=$?
assert_eq "$ec" "0" "A5: security P0 without controls is non-blocking (exit 0)"
assert_match "$out" "no compliance controls" "A5: missing controls is surfaced as info"

# Test 12: PART B — a missing source doc → violation (exit 1)
SRC_RULES_FILE="$TMP/good.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
  SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$TMP/docroot/docs/missing.md" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "1" "B1: missing source doc → violation (exit 1)"

# Test 13: PART B — an uncited (orphan) source doc → violation (exit 1)
SRC_RULES_FILE="$TMP/good.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
  SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$TMP/docroot/docs/orphan.md" SRC_ROOT="$TMP/docroot" "$SCRIPT" --quiet
assert_eq "$?" "1" "B2: uncited source doc → violation (exit 1)"

# Test 14: --detail produces more lines than summary
d=$(SRC_RULES_FILE="$TMP/good.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
    SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" --detail 2>&1 | wc -l | tr -d ' ')
s=$(SRC_RULES_FILE="$TMP/good.json" SRC_REQUIRED_NS="google owasp" SRC_ALLOW_EMPTY_NS="_community" \
    SRC_SECURITY_NS="owasp" SRC_SOURCE_DOCS="$B_OK_DOCS" SRC_ROOT="$TMP/docroot" "$SCRIPT" 2>&1 | wc -l | tr -d ' ')
if [ "$d" -gt "$s" ]; then log "  ✓ --detail produces more lines ($d > $s)"; passes=$((passes+1));
else log "  ✗ --detail did not add rows ($d vs $s)"; failures=$((failures+1)); fi

# Test 15: against the REAL registry + REAL docs → exit 0 (the gate is green today)
"$SCRIPT" --quiet
assert_eq "$?" "0" "real registry + real docs → exit 0 (current state is conformant)"

# Test 16: the TIER-0 supreme corpus is actually covered by PART B (the 'widen' claim)
out=$("$SCRIPT" --detail 2>&1)
assert_match "$out" "ai-engineering-corpus.md" "TIER-0 corpus is verified by the citation gate"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-source-citations] OK — $passes/$total passed."; exit 0
else log "[test-source-citations] FAIL — $failures/$total."; exit 1; fi
