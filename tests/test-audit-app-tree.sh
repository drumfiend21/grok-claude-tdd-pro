#!/usr/bin/env bash
# tests/test-audit-app-tree.sh — unit tests for scripts/audit-app-tree.sh (CL-F / TICKET-104, ADR-0077).
# Hermetic: AAT_APP_ROOT + a stub composite-audit (AAT_COMPOSITE_AUDIT via AAT_PLUGIN_ROOT) give
# deterministic tree verdicts — the real composite-audit walks a whole tree and is slow.
# Exit: 0 all pass / 1 any fail / 2 harness error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-app-tree] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-app-tree.sh
TMP=$(mktemp -d -t aat-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/app" "$TMP/plugin/rubric"
CA="$TMP/plugin/rubric/composite-audit.sh"
stub() { printf '%s\n' "$1" > "$CA"; }
run() { AAT_APP_ROOT="$TMP/app" AAT_PLUGIN_ROOT="$TMP/plugin" AAT_APP_ROOT_BIN="$TMP/no.sh" "$SCRIPT" --quiet >/dev/null 2>&1; }

# Test 1: --help → 0 ; Test 2: unknown flag → 2
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: no app_root → vacuous (0)
AAT_APP_ROOT="" AAT_APP_ROOT_BIN="$TMP/no.sh" AAT_PLUGIN_ROOT="$TMP/plugin" "$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "no app_root → vacuous (0)"

# Test 4: composite-audit absent → vacuous (0)
rm -f "$CA"
run; assert_eq "$?" "0" "composite-audit absent → vacuous (0)"

# Test 5: status=green → 0
stub '#!/usr/bin/env bash
echo "composite-audit root=x status=green files_flagged=0 red=0 incomplete=0" >&2
exit 0'
run; assert_eq "$?" "0" "status=green → 0"

# Test 6: status=red → 1
stub '#!/usr/bin/env bash
echo "audit file=a.tf verdict=red" >&2
echo "composite-audit root=x status=red files_flagged=1 red=1 incomplete=0" >&2
exit 1'
run; assert_eq "$?" "1" "status=red → 1"

# Test 7: status=incomplete → advisory (0)
stub '#!/usr/bin/env bash
echo "composite-audit root=x status=incomplete files_flagged=0 red=0 incomplete=1" >&2
exit 3'
run; assert_eq "$?" "0" "status=incomplete → advisory (0)"

# Test 8: bare crash / no summary (P-10) → vacuous (0), NOT a red
stub '#!/usr/bin/env bash
echo "composite-audit.sh: ra[@]: unbound variable" >&2
exit 1'
run; assert_eq "$?" "0" "crash / no summary → vacuous (0) [parse-then-block]"

total=$((passes + failures))
log ""
log "[test-audit-app-tree] $passes/$total passed"
[ "$failures" -eq 0 ] || exit 1
exit 0
