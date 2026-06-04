#!/usr/bin/env bash
# tests/test-audit-cross-references.sh — unit tests for scripts/audit-cross-references.sh
# Per TICKET-027 / ADR-0032. Exit-code contract: 0 (no new broken refs vs baseline)
# / 1 (new broken refs detected) / 2 (script error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-cross-references] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-cross-references.sh
BASELINE=tests/cross-references-baseline.txt

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Default mode exits 0 (baseline matches; no new broken refs)
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "default mode exits 0 (baseline-matched)"

# Test 4: Baseline file exists and is non-empty
[ -s "$BASELINE" ] && { log "  ✓ baseline file exists + non-empty"; passes=$((passes+1)); } \
                   || { log "  ✗ baseline missing or empty"; failures=$((failures+1)); }

# Test 5: NEW broken ref → exit 1
# Inject a fake broken ref into a temp file under docs/; audit should detect it.
TMPDOC=docs/__cross_ref_test__.md
printf '%s\n' '# test' '[link](docs/this-path-definitely-does-not-exist.md)' > "$TMPDOC"
"$SCRIPT" --quiet >/dev/null 2>&1
exit_code=$?
rm -f "$TMPDOC"   # restore BEFORE asserting
assert_eq "$exit_code" "1" "new broken ref triggers exit 1"

# Test 6: post-restore audit returns to baseline-matched
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "post-restore audit exits 0 (back to baseline)"

# Test 7: Output mentions the right summary keywords
out=$("$SCRIPT" 2>&1)
case "$out" in
    *"finding(s)"*) log "  ✓ output reports finding count"; passes=$((passes+1)) ;;
    *)              log "  ✗ output missing finding count"; failures=$((failures+1)) ;;
esac
case "$out" in
    *"baseline"*) log "  ✓ output mentions baseline"; passes=$((passes+1)) ;;
    *)            log "  ✗ output missing baseline mention"; failures=$((failures+1)) ;;
esac

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-cross-references] OK — $passes/$total passed."; exit 0
else log "[test-audit-cross-references] FAIL — $failures/$total."; exit 1; fi
