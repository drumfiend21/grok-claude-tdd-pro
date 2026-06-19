#!/usr/bin/env bash
# tests/test-audit-standards-enforced.sh — unit tests for scripts/audit-standards-enforced.sh (Fix C).
# Per TICKET-074 / ADR-0063. Hermetic: a stub enforce.sh (ES_ENFORCE) gives deterministic
# live verdicts; res.json claims are crafted to match / diverge. Exit: 0 (claims true /
# vacuous) / 1 (divergence or vacuous-pass) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-standards-enforced] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-standards-enforced.sh

TMP=$(mktemp -d -t ase-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/h" "$TMP/app/src"
printf 'x\n' > "$TMP/app/src/index.ts"

# Stub enforce.sh: verdict by rule-id substring. "-vac" = anomalous pass with 0 files
# (to exercise the vacuous-pass guard); "fail"/"-ne"/"-na" as usual; else pass(3 files).
cat > "$TMP/enforce.sh" <<'STUB'
#!/usr/bin/env bash
rules=""
while [ $# -gt 0 ]; do case "$1" in --rules) rules="$2"; shift 2;; --root) shift 2;; --rule) rules="$rules,$2"; shift 2;; --json|--quiet) shift;; *) shift;; esac; done
RULES="$rules" node -e '
const rs=(process.env.RULES||"").split(",").filter(Boolean);
function v(id){ if(id.indexOf("fail")>=0)return["fail",2]; if(id.indexOf("-ne")>=0)return["not_enforced",1]; if(id.indexOf("-na")>=0)return["not_applicable",0]; if(id.indexOf("-vac")>=0)return["pass",0]; return["pass",3]; }
const results=rs.map(id=>{const [vv,n]=v(id);return{rule:id,detector:"stub",verdict:vv,files_evaluated:n,exit:0};});
const sum={pass:0,fail:0,not_applicable:0,not_enforced:0,unknown_rule:0};
for(const r of results) sum[r.verdict]++;
console.log(JSON.stringify({root:"x",results,summary:sum}));
'
STUB

mkreq() { printf '%s\n' "$2" > "$TMP/h/$1.req.json"; }
mkres() { printf '%s\n' "$2" > "$TMP/h/$1.res.json"; }
clear_h() { rm -f "$TMP/h"/*.json; }
run() { ASE_HANDOFFS_DIR="$TMP/h" ASE_APP_ROOT="$TMP/app" ES_ENFORCE="$TMP/enforce.sh" "$SCRIPT" --quiet >/dev/null 2>&1; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: no app_root configured → vacuous (0)
clear_h
mkreq T1 '{"applicable_rules":["g-a"]}'; mkres T1 '{"status":"green","rules_verified":{"g-a":"pass"}}'
ASE_HANDOFFS_DIR="$TMP/h" ASE_APP_ROOT="$TMP/does-not-exist" ES_ENFORCE="$TMP/enforce.sh" "$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "unresolvable app_root → vacuous (0)"

# Test 4: no green response → vacuous (0)
clear_h
mkreq T1 '{"applicable_rules":["g-a"]}'; mkres T1 '{"status":"red","rules_verified":{"g-a":"fail"}}'
run; assert_eq "$?" "0" "no green response → vacuous (0)"

# Test 5: green, claims match live verdicts → 0
clear_h
mkreq T1 '{"applicable_rules":["g-a","g-b"]}'
mkres T1 '{"status":"green","rules_verified":{"g-a":"pass","g-b":"pass"}}'
run; assert_eq "$?" "0" "green + claims match live → 0"

# Test 6: green, claims pass on a rule the live run FAILS → divergence (1)
clear_h
mkreq T1 '{"applicable_rules":["g-a","g-x-fail"]}'
mkres T1 '{"status":"green","rules_verified":{"g-a":"pass","g-x-fail":"pass"}}'
run; assert_eq "$?" "1" "green claim of pass on a live fail → divergence (1)"

# Test 7: green, claims pass but live pass evaluated 0 files → vacuous-pass (1)
clear_h
mkreq T1 '{"applicable_rules":["g-vac"]}'
mkres T1 '{"status":"green","rules_verified":{"g-vac":"pass"}}'
run; assert_eq "$?" "1" "vacuous pass (files_evaluated 0) → violation (1)"

# Test 8: green, claims not_applicable matching live not_applicable → 0
clear_h
mkreq T1 '{"applicable_rules":["g-a","g-cloud-na"]}'
mkres T1 '{"status":"green","rules_verified":{"g-a":"pass","g-cloud-na":"not_applicable"}}'
run; assert_eq "$?" "0" "green + not_applicable matches live → 0"

# Test 9: green response whose request has no applicable_rules → skipped → vacuous (0)
clear_h
mkreq T1 '{"ticket_id":"T1"}'; mkres T1 '{"status":"green","rules_verified":{}}'
run; assert_eq "$?" "0" "green but no applicable_rules → skipped (0)"

# Test 10: claims a verdict that diverges (claims not_applicable, live pass) → 1
clear_h
mkreq T1 '{"applicable_rules":["g-a"]}'
mkres T1 '{"status":"green","rules_verified":{"g-a":"not_applicable"}}'
run; assert_eq "$?" "1" "claimed not_applicable but live pass → divergence (1)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-standards-enforced] OK — $passes/$total passed."; exit 0
else log "[test-standards-enforced] FAIL — $failures/$total."; exit 1; fi
