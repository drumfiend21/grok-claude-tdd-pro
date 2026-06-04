#!/usr/bin/env bash
# tests/test-audit-rulebook-coverage.sh — unit tests for scripts/audit-rulebook-coverage.sh
# Per TICKET-026 / ADR-0031. Exit-code contract: 0 (audit completed) / 2 (script error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-rulebook-coverage] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-rulebook-coverage.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Default (human) mode exits 0
"$SCRIPT" >/dev/null 2>&1
assert_eq "$?" "0" "default mode exits 0"

# Test 4: --detail exits 0
"$SCRIPT" --detail >/dev/null 2>&1
assert_eq "$?" "0" "--detail exits 0"

# Test 5: --quiet exits 0 + no stdout
out=$("$SCRIPT" --quiet 2>&1)
assert_eq "$?" "0" "--quiet exits 0"
if [ -z "$out" ]; then
    log "  ✓ --quiet suppresses output"; passes=$((passes+1))
else
    log "  ✗ --quiet emitted output: $out"; failures=$((failures+1))
fi

# Test 6: Default output mentions all 4 rulebook families
out=$("$SCRIPT" 2>&1)
for family in "D-rules" "R-rules" "G-rules" "C-rules"; do
    case "$out" in
        *"${family}"*) log "  ✓ output mentions ${family}"; passes=$((passes+1)) ;;
        *)              log "  ✗ output missing ${family}"; failures=$((failures+1)) ;;
    esac
done

# Test 7: Default output reports zero-citation candidates (Fowler #1 finding)
case "$out" in
    *"Zero-citation candidates"*) log "  ✓ output reports zero-citation candidates"; passes=$((passes+1)) ;;
    *)                            log "  ✗ output missing zero-citation candidates section"; failures=$((failures+1)) ;;
esac

# Test 8: --detail mode produces per-rule rows (different from summary)
detail_out=$("$SCRIPT" --detail 2>&1)
detail_lines=$(printf '%s\n' "$detail_out" | wc -l | tr -d ' ')
summary_lines=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
if [ "$detail_lines" -gt "$summary_lines" ]; then
    log "  ✓ --detail produces more lines than summary ($detail_lines > $summary_lines)"; passes=$((passes+1))
else
    log "  ✗ --detail did not produce more lines"; failures=$((failures+1))
fi

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-rulebook-coverage] OK — $passes/$total passed."; exit 0
else log "[test-audit-rulebook-coverage] FAIL — $failures/$total."; exit 1; fi
