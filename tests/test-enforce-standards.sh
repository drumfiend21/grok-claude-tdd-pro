#!/usr/bin/env bash
# tests/test-enforce-standards.sh — unit tests for scripts/enforce-standards.sh (Fix B).
# Per TICKET-073 / ADR-0062. Hermetic: a STUB enforce.sh (via ES_ENFORCE) returns
# canned 4-state verdicts keyed off rule-id substrings, so the verdict→status→exit
# mapping is exercised without Ruby/detectors. Exit contract: 0 green / 1 red /
# 3 incomplete / 2 error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-enforce-standards] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/enforce-standards.sh

TMP=$(mktemp -d -t es-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/h" "$TMP/app/src" "$TMP/empty"
printf 'x\n' > "$TMP/app/src/index.ts"

# Stub enforce.sh: verdict by rule-id substring — "fail"→fail, "-ne"→not_enforced,
# "-na"→not_applicable, else pass. Emits the enforce.sh --json shape.
cat > "$TMP/enforce.sh" <<'STUB'
#!/usr/bin/env bash
rules=""
while [ $# -gt 0 ]; do case "$1" in --rules) rules="$2"; shift 2;; --root) shift 2;; --rule) rules="$rules,$2"; shift 2;; --json|--quiet) shift;; *) shift;; esac; done
RULES="$rules" node -e '
const rs=(process.env.RULES||"").split(",").filter(Boolean);
const v=(id)=> id.indexOf("fail")>=0?"fail": id.indexOf("-ne")>=0?"not_enforced": id.indexOf("-na")>=0?"not_applicable":"pass";
const f=(x)=> x==="not_applicable"?0: x==="pass"?3: x==="fail"?2:1;
const results=rs.map(id=>{const vv=v(id);return{rule:id,detector:"stub",verdict:vv,files_evaluated:f(vv),exit:0};});
const sum={pass:0,fail:0,not_applicable:0,not_enforced:0,unknown_rule:0};
for(const r of results) sum[r.verdict]++;
console.log(JSON.stringify({root:"x",results,summary:sum}));
'
STUB

mkreq() { printf '%s\n' "$2" > "$TMP/h/$1.req.json"; }
# Run with the stub enforce + an explicit (populated) app_root.
run() { ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE="$TMP/enforce.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" "$@"; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"
# Test 3: missing --ticket → 2
ES_HANDOFFS_DIR="$TMP/h" "$SCRIPT" --quiet >/dev/null 2>&1; assert_eq "$?" "2" "missing --ticket → 2"
# Test 4: no request file → 2
run --ticket NOPE --quiet >/dev/null 2>&1; assert_eq "$?" "2" "no request file → 2"

# Test 5: all-pass rules → green (0)
mkreq T1 '{"applicable_rules":["g-universal-x","g-ts-001"]}'
run --ticket T1 --quiet >/dev/null 2>&1; assert_eq "$?" "0" "all pass → green (0)"

# Test 6: a fail rule → red (1)
mkreq T2 '{"applicable_rules":["g-ts-001","g-x-fail"]}'
run --ticket T2 --quiet >/dev/null 2>&1; assert_eq "$?" "1" "a fail → red (1)"

# Test 7: a not_enforced rule (no fail) → incomplete (3)
mkreq T3 '{"applicable_rules":["g-ts-001","g-x-ne"]}'
run --ticket T3 --quiet >/dev/null 2>&1; assert_eq "$?" "3" "not_enforced (no fail) → incomplete (3)"

# Test 8: not_applicable + pass → green (0)
mkreq T4 '{"applicable_rules":["g-ts-001","g-aws-na"]}'
run --ticket T4 --quiet >/dev/null 2>&1; assert_eq "$?" "0" "not_applicable + pass → green (0)"

# Test 9: empty applicable_rules → green empty (0)
mkreq T5 '{"applicable_rules":[]}'
run --ticket T5 --quiet >/dev/null 2>&1; assert_eq "$?" "0" "empty applicable_rules → green (0)"

# Test 10: --json emits a faithful rules_verified mapping
mkreq T6 '{"applicable_rules":["g-pass-1","g-x-fail","g-y-na","g-z-ne"]}'
out=$(run --ticket T6 --json --quiet 2>/dev/null)
v=$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{const j=JSON.parse(s);process.stdout.write([j.rules_verified["g-pass-1"],j.rules_verified["g-x-fail"],j.rules_verified["g-y-na"],j.rules_verified["g-z-ne"],j.status].join("|"));});')
assert_eq "$v" "pass|fail|not_applicable|not_enforced|red" "--json maps 4-state verdicts + status"

# Test 11: files_evaluated present for a pass rule
fe=$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(j.files_evaluated["g-pass-1"]));});')
assert_eq "$fe" "3" "files_evaluated reported per rule"

# Test 12: empty app_root → refuse (2) (vacuous-green guard via app-root.sh --validate)
mkreq T7 '{"applicable_rules":["g-ts-001"]}'
ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE="$TMP/enforce.sh" ES_APP_ROOT="$TMP/empty" "$SCRIPT" --ticket T7 --quiet >/dev/null 2>&1
assert_eq "$?" "2" "empty app_root → refuse (2)"

# Test 13: missing enforce.sh → error (2)
mkreq T8 '{"applicable_rules":["g-ts-001"]}'
ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE="$TMP/nope.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket T8 --quiet >/dev/null 2>&1
assert_eq "$?" "2" "missing enforce.sh → error (2)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-enforce-standards] OK — $passes/$total passed."; exit 0
else log "[test-enforce-standards] FAIL — $failures/$total."; exit 1; fi
