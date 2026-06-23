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

# ---------- ADR-0068 W-B: --changed-files narrowed mode ----------
# Stub enforce-file.sh: emits CTP-style stderr (`enforce-file file=<f> rule=<id> verdict=<v>`).
# Verdict by filename pattern — drives failure scenarios deterministically.
cat > "$TMP/enforce-file.sh" <<'STUB'
#!/usr/bin/env bash
file=""
while [ $# -gt 0 ]; do case "$1" in --file) file="$2"; shift 2;; --root|--quiet) [ "$1" = "--root" ] && shift 2 || shift;; *) shift;; esac; done
base=$(basename "$file")
case "$base" in
    *.fail.*) printf 'enforce-file file=%s rule=g-x-fail severity=P0 detector=stub verdict=fail\n' "$file" >&2 ;;
    *.ne.*)   printf 'enforce-file file=%s rule=g-y-ne detector=stub verdict=not_enforced\n' "$file" >&2 ;;
esac
printf 'enforce-file file=%s status=na rules_checked=0\n' "$file" >&2
exit 0
STUB
chmod +x "$TMP/enforce-file.sh"
mkdir -p "$TMP/app/src"
printf 'clean\n' > "$TMP/app/src/clean.ts"
printf 'leaky\n' > "$TMP/app/src/secret.fail.ts"
printf 'maybe\n' > "$TMP/app/src/probe.ne.ts"

# Test 14: W-B all-clean changed-files → green (0)
mkreq TC1 '{"applicable_rules":["g-universal-x","g-ts-clean"]}'
out=$(ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE_FILE="$TMP/enforce-file.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket TC1 --changed-files "src/clean.ts" --json --quiet 2>/dev/null)
rc=$?
assert_eq "$rc" "0" "W-B all-clean changed-files → green (0)"
fe=$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(j.files_evaluated["g-universal-x"]));});')
assert_eq "$fe" "1" "W-B files_evaluated = number of changed_files (1)"

# Test 15: W-B with fail signal → red (1)
mkreq TC2 '{"applicable_rules":["g-universal-x","g-x-fail"]}'
ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE_FILE="$TMP/enforce-file.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket TC2 --changed-files "src/secret.fail.ts" --quiet >/dev/null 2>&1
assert_eq "$?" "1" "W-B changed-files with fail signal → red (1)"

# Test 16: W-B with not_enforced signal → incomplete (3)
mkreq TC3 '{"applicable_rules":["g-universal-x","g-y-ne"]}'
ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE_FILE="$TMP/enforce-file.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket TC3 --changed-files "src/probe.ne.ts" --quiet >/dev/null 2>&1
assert_eq "$?" "3" "W-B changed-files with not_enforced signal → incomplete (3)"

# Test 17: W-B multi-file, worst verdict wins (fail in one)
mkreq TC4 '{"applicable_rules":["g-universal-x","g-x-fail","g-y-ne"]}'
ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE_FILE="$TMP/enforce-file.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket TC4 --changed-files "src/clean.ts,src/secret.fail.ts,src/probe.ne.ts" --quiet >/dev/null 2>&1
assert_eq "$?" "1" "W-B multi-file, fail in one → red (1)"

# Test 18: W-B missing file skipped, others processed
mkreq TC5 '{"applicable_rules":["g-universal-x"]}'
out=$(ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE_FILE="$TMP/enforce-file.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket TC5 --changed-files "src/clean.ts,src/nonexistent.ts" --json --quiet 2>/dev/null)
rc=$?
assert_eq "$rc" "0" "W-B missing file skipped, others processed → green (0)"
fe=$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(j.files_evaluated["g-universal-x"]));});')
assert_eq "$fe" "1" "W-B files_evaluated = files actually found (1, not 2)"

# Test 19: W-B absolute changed_files path resolves
mkreq TC6 '{"applicable_rules":["g-universal-x","g-x-fail"]}'
ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE_FILE="$TMP/enforce-file.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket TC6 --changed-files "$TMP/app/src/secret.fail.ts" --quiet >/dev/null 2>&1
assert_eq "$?" "1" "W-B absolute changed_files path resolves → red (1)"

# Test 20: W-B missing enforce-file.sh → error (2)
mkreq TC7 '{"applicable_rules":["g-x"]}'
ES_HANDOFFS_DIR="$TMP/h" ES_ENFORCE_FILE="$TMP/nope.sh" ES_APP_ROOT="$TMP/app" "$SCRIPT" --ticket TC7 --changed-files "src/clean.ts" --quiet >/dev/null 2>&1
assert_eq "$?" "2" "W-B missing enforce-file.sh → error (2)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-enforce-standards] OK — $passes/$total passed."; exit 0
else log "[test-enforce-standards] FAIL — $failures/$total."; exit 1; fi
