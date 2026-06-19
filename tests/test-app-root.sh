#!/usr/bin/env bash
# tests/test-app-root.sh — unit tests for scripts/app-root.sh (Fix D).
# Per TICKET-070 / ADR-0059. Exit-code contract: 0 (resolved+valid) / 1 (unconfigured) / 2 (refuse-empty/missing or bad-invocation).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-app-root] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/app-root.sh

TMP=$(mktemp -d -t ar-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# A populated app tree + an empty one + a non-git populated one.
mkdir -p "$TMP/app/src"; printf 'const x = 1;\n' > "$TMP/app/src/index.ts"
mkdir -p "$TMP/empty"
CFG="$TMP/app.json"

run() { AR_CONFIG="$CFG" AR_ROOT="$TMP" "$SCRIPT" "$@" 2>/dev/null; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: no config file → 1 (unconfigured)
rm -f "$CFG"
run >/dev/null 2>&1; assert_eq "$?" "1" "no app.json → unconfigured (1)"

# Test 4: config with valid relative app_root → 0 + prints abs path
printf '{"schema_version":"1","app_root":"app"}\n' > "$CFG"
out=$(run); rc=$?
assert_eq "$rc" "0" "valid relative app_root → 0"
assert_eq "$out" "$TMP/app" "prints resolved absolute path"

# Test 5: config with absolute app_root → 0
printf '{"app_root":"%s/app"}\n' "$TMP" > "$CFG"
run >/dev/null 2>&1; assert_eq "$?" "0" "absolute app_root → 0"

# Test 6: configured but MISSING tree → 2 (refuse)
printf '{"app_root":"does-not-exist"}\n' > "$CFG"
run >/dev/null 2>&1; assert_eq "$?" "2" "missing app_root tree → refuse (2)"

# Test 7: configured but EMPTY tree → 2 (vacuous-green guard)
printf '{"app_root":"empty"}\n' > "$CFG"
run >/dev/null 2>&1; assert_eq "$?" "2" "empty app_root tree → refuse (2)"

# Test 8: config present but no app_root key → 1 (unconfigured)
printf '{"schema_version":"1"}\n' > "$CFG"
run >/dev/null 2>&1; assert_eq "$?" "1" "app.json without app_root key → unconfigured (1)"

# Test 9: invalid JSON → 2
printf '{not json\n' > "$CFG"
run >/dev/null 2>&1; assert_eq "$?" "2" "invalid JSON config → 2"

# Test 10: --validate on a populated dir → 0
"$SCRIPT" --validate "$TMP/app" >/dev/null 2>&1; assert_eq "$?" "0" "--validate populated dir → 0"

# Test 11: --validate on an empty dir → 2
"$SCRIPT" --validate "$TMP/empty" >/dev/null 2>&1; assert_eq "$?" "2" "--validate empty dir → 2"

# Test 12: --validate without a dir → 2
"$SCRIPT" --validate >/dev/null 2>&1; assert_eq "$?" "2" "--validate without dir → 2"

# Test 13: empty tree is git-agnostic — a non-.git file counts, a .git-only tree does not
mkdir -p "$TMP/gitonly/.git"; printf 'x\n' > "$TMP/gitonly/.git/HEAD"
"$SCRIPT" --validate "$TMP/gitonly" >/dev/null 2>&1; assert_eq "$?" "2" "tree with only .git files → refuse (2)"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-app-root] OK — $passes/$total passed."; exit 0
else log "[test-app-root] FAIL — $failures/$total."; exit 1; fi
