#!/usr/bin/env bash
# tests/test-standards-sync.sh — unit tests for scripts/standards-sync.sh
# Per TICKET-032 / ADR-0037. Exit-code contract: 0 (synced) / 1 (--check stale) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-standards-sync] starting"

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

SCRIPT=./scripts/standards-sync.sh
ACTIVE=.harness/rules/active.json

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Default mode exits 0 + writes active.json
"$SCRIPT" --quiet
assert_eq "$?" "0" "default mode exits 0"
[ -s "$ACTIVE" ] && { log "  ✓ active.json written + non-empty"; passes=$((passes+1)); } \
                 || { log "  ✗ active.json missing or empty"; failures=$((failures+1)); }

# Test 4: active.json contains expected fields
content=$(cat "$ACTIVE")
assert_match "$content" '"version":1' "active.json has version field"
assert_match "$content" '"rules":' "active.json has rules array"
assert_match "$content" '"namespaces_seen"' "active.json has namespaces_seen"
assert_match "$content" '"owasp"' "active.json includes owasp namespace"
assert_match "$content" '"google"' "active.json includes google namespace"
assert_match "$content" '"slsa"' "active.json includes slsa namespace"

# Test 5: Rule count >= 20 (current baseline: 28 rules)
rule_count=$(grep -oE '"id":"[^"]+"' "$ACTIVE" | wc -l | tr -d ' ')
if [ "$rule_count" -ge 20 ]; then
    log "  ✓ rule count >= 20 (actual: $rule_count)"
    passes=$((passes+1))
else
    log "  ✗ rule count < 20 (actual: $rule_count)"
    failures=$((failures+1))
fi

# Test 6: --check exits 0 against fresh registry
"$SCRIPT" --check --quiet
assert_eq "$?" "0" "--check exits 0 against fresh registry"

# Test 7: Mutating active.json triggers --check exit 1
cp "$ACTIVE" "$ACTIVE.bak"
printf '%s\n' '{"version":1,"rules":[],"namespaces_seen":[]}' > "$ACTIVE"
"$SCRIPT" --check --quiet >/dev/null 2>&1
exit_code=$?
mv "$ACTIVE.bak" "$ACTIVE"   # restore BEFORE asserting
assert_eq "$exit_code" "1" "mutated active.json triggers --check exit 1"

# Test 8: Post-restore --check returns to 0
"$SCRIPT" --check --quiet
assert_eq "$?" "0" "post-restore --check exits 0"

# Test 9: Summary output includes rule count and namespaces
out=$("$SCRIPT" 2>&1)
assert_match "$out" "rules:" "summary mentions rules"
assert_match "$out" "namespaces:" "summary mentions namespaces"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-standards-sync] OK — $passes/$total passed."; exit 0
else log "[test-standards-sync] FAIL — $failures/$total."; exit 1; fi
