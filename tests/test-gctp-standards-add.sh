#!/usr/bin/env bash
# tests/test-gctp-standards-add.sh — unit tests for scripts/gctp-standards-add.sh (ADR-0069 W-F).
# Hermetic: stub CTP pipeline commands via GSA_PIPELINE_CMD env override.
# Exit-code contract: 0 ok / 1 source unknown / 2 bad invocation / 3 budget declined / 4 pipeline error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-gctp-standards-add] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/gctp-standards-add.sh

TMP=$(mktemp -d -t gsa-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/cmd" "$TMP/ops"

# Stub pipeline: each command writes a minimal-shape JSON to stdout + exits 0.
for c in extract-rules-from-url classify-rule route-rule draft-custom-rule; do
    cat > "$TMP/cmd/$c.sh" <<'STUB'
#!/usr/bin/env bash
out="[]"
case "$0" in *extract-rules-from-url.sh) out='[{"rule_id":"r1","prose":"x"},{"rule_id":"r2","prose":"y"},{"rule_id":"r3","prose":"z"}]' ;; esac
printf '%s' "$out"
exit 0
STUB
    chmod +x "$TMP/cmd/$c.sh"
done
cat > "$TMP/cmd/review-queue.sh" <<'STUB'
#!/usr/bin/env bash
printf '{"queues":{"auto_stage":[{"rule_id":"r1","confidence":"high"}]},"staged":["r1"]}'
exit 0
STUB
chmod +x "$TMP/cmd/review-queue.sh"

# Default namespaces.yaml fixture: one declared source.
cat > "$TMP/ops/namespaces.yaml" <<'YAML'
sources:
  - id: test-source
    url: https://example.com/standard
    namespace: test
YAML

run() { GSA_PLUGIN_ROOT="$TMP" GSA_OPERATOR_DIR="$TMP/ops" GSA_NAMESPACES="$TMP/ops/namespaces.yaml" GSA_PIPELINE_CMD="$TMP/cmd" GSA_NONINTERACTIVE=1 "$SCRIPT" "$@"; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"

# Test 2: missing --source-id → 2
"$SCRIPT" --url x >/dev/null 2>&1; assert_eq "$?" "2" "missing --source-id → 2"

# Test 3: missing --url → 2
"$SCRIPT" --source-id x >/dev/null 2>&1; assert_eq "$?" "2" "missing --url → 2"

# Test 4: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag → 2"

# Test 5: missing namespaces.yaml → 1
GSA_NAMESPACES="$TMP/nonexistent.yaml" \
    GSA_PLUGIN_ROOT="$TMP" GSA_OPERATOR_DIR="$TMP/ops" GSA_PIPELINE_CMD="$TMP/cmd" \
    "$SCRIPT" --source-id test-source --url https://x --quiet >/dev/null 2>&1
assert_eq "$?" "1" "missing namespaces.yaml → 1"

# Test 6: undeclared source-id → 1
run --source-id undeclared-source --url https://x --quiet >/dev/null 2>&1
assert_eq "$?" "1" "undeclared source-id → 1"

# Test 7: happy path with declared source → 0
run --source-id test-source --url https://example.com/standard --quiet >/dev/null 2>&1
assert_eq "$?" "0" "happy path (declared source, mocked pipeline) → 0"

# Test 8: pipeline produces a cache file
[ -f "$TMP/ops/.cache/test-source.extract.json" ] && r=0 || r=1
assert_eq "$r" "0" "extract cache file written"

[ -f "$TMP/ops/.cache/test-source.queue.json" ] && r=0 || r=1
assert_eq "$r" "0" "queue cache file written"

# Test 10: budget exceeded + non-interactive → 3
run --source-id test-source --url https://example.com/standard --budget-usd 0.01 --quiet >/dev/null 2>&1
assert_eq "$?" "3" "budget exceeded + non-interactive → 3"

# Test 11: missing pipeline entrypoint → 4
GSA_PLUGIN_ROOT="$TMP" GSA_OPERATOR_DIR="$TMP/ops" GSA_NAMESPACES="$TMP/ops/namespaces.yaml" \
    GSA_PIPELINE_CMD="$TMP/nonexistent-cmd-dir" GSA_NONINTERACTIVE=1 \
    "$SCRIPT" --source-id test-source --url https://example.com/standard --quiet >/dev/null 2>&1
assert_eq "$?" "4" "missing pipeline entrypoint → 4"

# Test 12: pipeline stage failure → 4 (replace extract stub with failing one)
cat > "$TMP/cmd/extract-rules-from-url.sh" <<'STUB'
#!/usr/bin/env bash
exit 7
STUB
chmod +x "$TMP/cmd/extract-rules-from-url.sh"
run --source-id test-source --url https://example.com/standard --quiet >/dev/null 2>&1
assert_eq "$?" "4" "extract stage failure → 4"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-gctp-standards-add] OK — $passes/$total passed."; exit 0
else log "[test-gctp-standards-add] FAIL — $failures/$total."; exit 1; fi
