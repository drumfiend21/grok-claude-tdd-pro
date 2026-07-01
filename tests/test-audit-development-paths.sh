#!/usr/bin/env bash
# tests/test-audit-development-paths.sh — unit tests for scripts/audit-development-paths.sh
# (CL-I / TICKET-101, ADR-0074). Hermetic: ADPTH_CLASSIFY points at a stub classify-path
# so the corpus verdict is deterministic and no real plugin cache is required.
# Exit: 0 all pass / 1 any fail / 2 harness error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-development-paths] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-development-paths.sh
TMP=$(mktemp -d -t adpth-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

mkstub() { printf '%s\n' "$2" > "$TMP/classify.sh"; }  # $2 = body after shebang
run() { ADPTH_CLASSIFY="$TMP/classify.sh" "$SCRIPT" --quiet >/dev/null 2>&1; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: classify-path absent → vacuous (0)
ADPTH_CLASSIFY="$TMP/does-not-exist.sh" "$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "classify-path absent → vacuous pass (0)"

# Test 4: every rule pathed (unpathed=0) → green (0)
cat > "$TMP/classify.sh" <<'STUB'
#!/usr/bin/env bash
echo "classify-path total=5 iac=2 fullstack=2 both=1 unpathed=0" >&2
exit 0
STUB
run; assert_eq "$?" "0" "unpathed=0 → green (0)"

# Test 5: an unpathed rule → red (1)
cat > "$TMP/classify.sh" <<'STUB'
#!/usr/bin/env bash
echo "classify-path total=5 iac=2 fullstack=1 both=1 unpathed=1" >&2
exit 1
STUB
run; assert_eq "$?" "1" "unpathed>0 → red (1)"

# Test 6: no parseable summary (e.g. Ruby prerequisite missing) → vacuous (0)
cat > "$TMP/classify.sh" <<'STUB'
#!/usr/bin/env bash
echo "ruby: command not found" >&2
exit 1
STUB
run; assert_eq "$?" "0" "no summary (Ruby missing) → vacuous pass (0)"

# Test 7: summary present but multi-digit unpathed parsed correctly → red (1)
cat > "$TMP/classify.sh" <<'STUB'
#!/usr/bin/env bash
echo "classify-path total=120 iac=40 fullstack=30 both=38 unpathed=12" >&2
exit 1
STUB
run; assert_eq "$?" "1" "unpathed=12 (multi-digit) → red (1)"

total=$((passes + failures))
log ""
log "[test-audit-development-paths] $passes/$total passed"
[ "$failures" -eq 0 ] || exit 1
exit 0
