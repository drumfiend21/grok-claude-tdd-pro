#!/usr/bin/env bash
# tests/test-audit-applicable-rules.sh — unit tests for scripts/audit-applicable-rules.sh (Fix A).
# Per TICKET-071 / ADR-0060. Exit-code contract: 0 (floors satisfied / vacuous) / 1 (under-scope) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-applicable-rules] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-applicable-rules.sh

TMP=$(mktemp -d -t aar-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/h"

# A minimal active.json fixture: 2 universal, a g-ts/g-node/g-react set, a g-doc, a g-hashicorp.
cat > "$TMP/active.json" <<'JSON'
{ "rules": [
  { "id": "g-universal-no-hardcoded-secrets", "source_namespace": "_universal" },
  { "id": "g-universal-no-debug-output", "source_namespace": "_universal" },
  { "id": "g-ts-001", "source_namespace": "google" },
  { "id": "g-ts-006", "source_namespace": "typescript" },
  { "id": "g-node-002", "source_namespace": "node" },
  { "id": "g-react-001", "source_namespace": "react" },
  { "id": "g-doc-001", "source_namespace": "documentation" },
  { "id": "g-hashicorp-pin-required-version", "source_namespace": "hashicorp" }
] }
JSON

run() { AAR_HANDOFFS_DIR="$TMP/h" AAR_ACTIVE="$TMP/active.json" "$SCRIPT" --quiet >/dev/null 2>&1; }
mkreq() { printf '%s\n' "$2" > "$TMP/h/$1.req.json"; }
clear_h() { rm -f "$TMP/h"/*.json; }

UNIV='"g-universal-no-hardcoded-secrets","g-universal-no-debug-output"'

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: no reqs → vacuous (0)
clear_h; run; assert_eq "$?" "0" "no reqs → vacuous (0)"

# Test 4: missing active.json → vacuous (0)
clear_h; mkreq T1 '{"applicable_rules":["g-universal-no-hardcoded-secrets"]}'
AAR_HANDOFFS_DIR="$TMP/h" AAR_ACTIVE="$TMP/none.json" "$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "missing active.json → vacuous (0)"

# Test 5: no applicable_rules on the req → not gated (0)
clear_h; mkreq T1 '{"ticket_id":"T1","file_scope":{"may_edit":["src/**/*.ts"]}}'
run; assert_eq "$?" "0" "no applicable_rules → not gated (0)"

# Test 6: carries both universal, extensionless globs → 0
clear_h; mkreq T1 '{"applicable_rules":['"$UNIV"'],"file_scope":{"may_edit":["src/seam/**"]}}'
run; assert_eq "$?" "0" "universal present + extensionless globs → 0"

# Test 7: omits a universal rule → violation (1)
clear_h; mkreq T1 '{"applicable_rules":["g-universal-no-hardcoded-secrets"],"file_scope":{"may_edit":["README.txt"]}}'
run; assert_eq "$?" "1" "omits a universal rule → 1"

# Test 8: .ts glob but omits g-ts-*/g-node-* → violation (1)  (THE kata regression)
clear_h; mkreq T1 '{"applicable_rules":['"$UNIV"'],"file_scope":{"may_edit":["reference-impl/src/**/*.ts"]}}'
run; assert_eq "$?" "1" ".ts glob under-scopes g-ts-*/g-node-* → 1 (kata regression)"

# Test 9: .ts glob WITH full ts+node set + universal → 0
clear_h; mkreq T1 '{"applicable_rules":['"$UNIV"',"g-ts-001","g-ts-006","g-node-002"],"file_scope":{"may_edit":["src/**/*.ts"]}}'
run; assert_eq "$?" "0" ".ts glob with full ts+node + universal → 0"

# Test 10: .tsx requires g-react-* too — omitting it → 1
clear_h; mkreq T1 '{"applicable_rules":['"$UNIV"',"g-ts-001","g-ts-006","g-node-002"],"file_scope":{"may_edit":["src/**/*.tsx"]}}'
run; assert_eq "$?" "1" ".tsx omitting g-react-* → 1"

# Test 11: .md requires g-doc-* — present → 0
clear_h; mkreq T1 '{"applicable_rules":['"$UNIV"',"g-doc-001"],"file_scope":{"may_edit":["docs/adr/0001.md"]}}'
run; assert_eq "$?" "0" ".md with g-doc-* → 0"

# Test 12: .tf requires g-hashicorp-* — omitting → 1
clear_h; mkreq T1 '{"applicable_rules":['"$UNIV"'],"file_scope":{"may_edit":["infra/main.tf"]}}'
run; assert_eq "$?" "1" ".tf omitting g-hashicorp-* → 1"

# Test 13: malformed req JSON → violation (1)
clear_h; printf '{bad json\n' > "$TMP/h/T1.req.json"
run; assert_eq "$?" "1" "malformed req JSON → 1"

# Test 14: multiple reqs, one good one bad → 1
clear_h
mkreq OK '{"applicable_rules":['"$UNIV"'],"file_scope":{"may_edit":["x/**"]}}'
mkreq BAD '{"applicable_rules":["g-universal-no-debug-output"],"file_scope":{"may_edit":["y/**"]}}'
run; assert_eq "$?" "1" "one good + one under-scoped → 1"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-applicable-rules] OK — $passes/$total passed."; exit 0
else log "[test-applicable-rules] FAIL — $failures/$total."; exit 1; fi
