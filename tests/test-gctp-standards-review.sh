#!/usr/bin/env bash
# tests/test-gctp-standards-review.sh — unit tests for scripts/gctp-standards-review.sh (ADR-0069 W-G).
# Hermetic: stub CTP review-queue + queue fixture files via GSR_* env overrides.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-gctp-standards-review] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/gctp-standards-review.sh

TMP=$(mktemp -d -t gsr-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/cmd" "$TMP/ops/.cache"

# Stub CTP review-queue.sh
cat > "$TMP/cmd/review-queue.sh" <<'STUB'
#!/usr/bin/env bash
printf '{"queues":{},"staged":["r1","r2"]}'
exit 0
STUB
chmod +x "$TMP/cmd/review-queue.sh"

# Fixture queue file
cat > "$TMP/ops/.cache/test-source.queue.json" <<'JSON'
{
  "queues": {
    "auto_stage": [
      {"rule_id":"r-high","confidence":"high"}
    ],
    "side_by_side": [
      {"rule_id":"r-medium","confidence":"medium","source":"https://example.com/clause"}
    ]
  },
  "staged": ["r-high"]
}
JSON
cat > "$TMP/ops/.cache/test-source.draft.json" <<'JSON'
[{"rule_id":"r-high","draft":"..."},{"rule_id":"r-medium","draft":"..."}]
JSON

run() { GSR_PLUGIN_ROOT="$TMP" GSR_OPERATOR_DIR="$TMP/ops" GSR_REVIEW_BIN="$TMP/cmd/review-queue.sh" "$SCRIPT" "$@"; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"

# Test 2: no mode → 2
"$SCRIPT" --quiet >/dev/null 2>&1; assert_eq "$?" "2" "no mode → 2"

# Test 3: multiple modes (mutually exclusive) → 2
"$SCRIPT" --list --review r-high >/dev/null 2>&1; assert_eq "$?" "2" "multiple modes → 2"

# Test 4: --batch-accept without --confidence → 2
"$SCRIPT" --batch-accept >/dev/null 2>&1; assert_eq "$?" "2" "--batch-accept without --confidence → 2"

# Test 5: --batch-accept --confidence medium → 2 (only "high" supported)
GSR_PLUGIN_ROOT="$TMP" GSR_OPERATOR_DIR="$TMP/ops" GSR_REVIEW_BIN="$TMP/cmd/review-queue.sh" \
    "$SCRIPT" --batch-accept --confidence medium >/dev/null 2>&1
assert_eq "$?" "2" "--batch-accept --confidence medium → 2"

# Test 6: --list with no queue dir → 1
GSR_PLUGIN_ROOT="$TMP" GSR_OPERATOR_DIR="$TMP/nope" GSR_REVIEW_BIN="$TMP/cmd/review-queue.sh" \
    "$SCRIPT" --list >/dev/null 2>&1
assert_eq "$?" "1" "no queue dir → 1"

# Test 7: --list with queue files → 0
run --list >/dev/null 2>&1; assert_eq "$?" "0" "--list with queue files → 0"

# Test 8: --list output includes the rule id
out=$(run --list 2>&1)
echo "$out" | grep -q "r-high" && r=0 || r=1
assert_eq "$r" "0" "--list output mentions r-high"

# Test 9: --review <rule-id> with present rule → 0
run --review r-medium >/dev/null 2>&1; assert_eq "$?" "0" "--review existing rule → 0"

# Test 10: --batch-accept --confidence high → 0 (mocked review-queue.sh)
run --batch-accept --confidence high >/dev/null 2>&1
assert_eq "$?" "0" "--batch-accept --confidence high → 0"

# Test 11: --accept <rule-id> → 0 with manual-workflow guidance
out=$(run --accept r-medium 2>&1)
echo "$out" | grep -q "manual workflow" && r=0 || r=1
assert_eq "$r" "0" "--accept emits manual workflow guidance"

# Test 12: --reject <rule-id> → 0 with manual-workflow guidance
out=$(run --reject r-medium 2>&1)
echo "$out" | grep -q "manual workflow" && r=0 || r=1
assert_eq "$r" "0" "--reject emits manual workflow guidance"

# Test 13: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag → 2"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-gctp-standards-review] OK — $passes/$total passed."; exit 0
else log "[test-gctp-standards-review] FAIL — $failures/$total."; exit 1; fi
