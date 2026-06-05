#!/usr/bin/env bash
# tests/test-audit-metrics.sh — unit tests for scripts/audit-metrics.sh
# Per TICKET-030 / ADR-0035. Exit-code contract: 0 (success) / 2 (script error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-metrics] starting"

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

SCRIPT=./scripts/audit-metrics.sh

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: Default mode exits 0
"$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "default mode exits 0"

# Test 4: Empty dir produces "no manifests" message + exits 0
TMPDIR=tests/__metrics_empty__
mkdir -p "$TMPDIR"
out=$("$SCRIPT" --dir="$TMPDIR" 2>&1)
exit_code=$?
rmdir "$TMPDIR"
assert_eq "$exit_code" "0" "empty dir exits 0"
assert_match "$out" "no manifests" "empty dir reports 'no manifests'"

# Test 5: Synthetic fixture corpus produces correct counts
TMPDIR=tests/__metrics_fixture__
mkdir -p "$TMPDIR"
for i in 1 2 3 4 5; do
    case $i in
        1|2|3) st=green ;;
        4)     st=red ;;
        5)     st=blocked ;;
    esac
    cat > "$TMPDIR/TICKET-99$i.manifest.json" <<JSON
{
  "schema_version": "1",
  "ticket_id": "TICKET-99$i",
  "created_at": "2026-06-0$i T12:00:00Z",
  "status": "$st",
  "sources": []
}
JSON
done
# Strip the space the heredoc inserted (it would break ISO 8601 parse).
for f in "$TMPDIR"/TICKET-*.manifest.json; do
    sed -i.bak 's/T12:00:00Z/T12:00:00Z/' "$f" 2>/dev/null
    # actually fix the space we accidentally introduced via " T12"
    sed -i.bak 's/ T12:00:00Z/T12:00:00Z/' "$f"
    rm -f "$f.bak"
done
out=$("$SCRIPT" --dir="$TMPDIR" 2>&1)
exit_code=$?
rm -rf "$TMPDIR"   # restore BEFORE asserting
assert_eq "$exit_code" "0" "fixture corpus exits 0"
assert_match "$out" "total              5" "fixture reports total=5"
assert_match "$out" "green              3" "fixture reports green=3"
assert_match "$out" "red                1" "fixture reports red=1"
assert_match "$out" "blocked            1" "fixture reports blocked=1"
assert_match "$out" "40.0%" "fixture computes CFR=40.0% (2/5)"

# Test 6: --json mode produces parseable single-line output
TMPDIR=tests/__metrics_json__
mkdir -p "$TMPDIR"
cat > "$TMPDIR/TICKET-998.manifest.json" <<'JSON'
{"schema_version":"1","ticket_id":"TICKET-998","created_at":"2026-06-01T12:00:00Z","status":"green","sources":[]}
JSON
out=$("$SCRIPT" --dir="$TMPDIR" --json 2>&1)
exit_code=$?
rm -rf "$TMPDIR"   # restore BEFORE asserting
assert_eq "$exit_code" "0" "--json exits 0"
assert_match "$out" '"total":1' "json output contains total field"
assert_match "$out" '"green":1' "json output contains green field"
assert_match "$out" '"change_failure_rate_pct":0.0' "json output contains CFR"

# Test 7: Output mentions DORA + the ADR
out=$("$SCRIPT" 2>&1)
assert_match "$out" "DORA" "default output mentions DORA"
assert_match "$out" "ADR-0035" "default output cites ADR-0035"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-metrics] OK — $passes/$total passed."; exit 0
else log "[test-audit-metrics] FAIL — $failures/$total."; exit 1; fi
