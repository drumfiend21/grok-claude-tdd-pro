#!/usr/bin/env bash
# tests/test-audit-agent-compact.sh — unit tests for scripts/audit-agent-compact.sh
# AND scripts/accept-compact.sh.
# Per TICKET-068 / ADR-0057. Exit-code contract: 0 (gate holds) / 1 (violation) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-agent-compact] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

AUDIT=./scripts/audit-agent-compact.sh
ACCEPT=./scripts/accept-compact.sh

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    else return 1; fi
}

TMP=$(mktemp -d -t ac-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

COMPACT="$TMP/compact.md"
ACK="$TMP/ack.json"
CLAUDEMD="$TMP/CLAUDE.md"
AGENTSMD="$TMP/AGENTS.md"

# Fixtures: a compact + both binding surfaces wired with the token.
printf 'compact body v1\n' > "$COMPACT"
printf 'see docs/agent-operating-compact.md for the binding\n' > "$CLAUDEMD"
printf 'enumerated: agent-operating-compact.md\n' > "$AGENTSMD"

run_audit() {
    AC_COMPACT="$COMPACT" AC_ACK="$ACK" AC_CLAUDEMD="$CLAUDEMD" AC_AGENTSMD="$AGENTSMD" \
        "$AUDIT" --quiet >/dev/null 2>&1
}
write_good_ack() {
    local h; h=$(sha256_of "$COMPACT")
    printf '{"accepted":true,"compact_sha256":"%s"}\n' "$h" > "$ACK"
}

# Test 1: audit --help → 0
"$AUDIT" --help >/dev/null 2>&1; assert_eq "$?" "0" "audit --help exits 0"
# Test 2: audit unknown flag → 2
"$AUDIT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "audit unknown flag exits 2"

# Test 3: compact present + wired + current ack → 0
write_good_ack
run_audit; assert_eq "$?" "0" "present + wired + current ack → 0"

# Test 4: compact missing → 1
rm -f "$COMPACT"
run_audit; assert_eq "$?" "1" "missing compact → 1"
printf 'compact body v1\n' > "$COMPACT"   # restore

# Test 5: not wired into CLAUDE.md → 1
printf 'no token here\n' > "$CLAUDEMD"
write_good_ack
run_audit; assert_eq "$?" "1" "not wired into CLAUDE.md → 1"
printf 'see docs/agent-operating-compact.md for the binding\n' > "$CLAUDEMD"   # restore

# Test 6: not wired into AGENTS.md → 1
printf 'no token here\n' > "$AGENTSMD"
run_audit; assert_eq "$?" "1" "not wired into AGENTS.md → 1"
printf 'enumerated: agent-operating-compact.md\n' > "$AGENTSMD"   # restore

# Test 7: ack missing → 1
rm -f "$ACK"
run_audit; assert_eq "$?" "1" "no acceptance record → 1"

# Test 8: ack accepted:false → 1
h=$(sha256_of "$COMPACT")
printf '{"accepted":false,"compact_sha256":"%s"}\n' "$h" > "$ACK"
run_audit; assert_eq "$?" "1" "accepted:false → 1"

# Test 9: ack stale hash → 1
printf '{"accepted":true,"compact_sha256":"deadbeef"}\n' > "$ACK"
run_audit; assert_eq "$?" "1" "stale compact_sha256 → 1"

# Test 10: ack missing sha → 1
printf '{"accepted":true}\n' > "$ACK"
run_audit; assert_eq "$?" "1" "ack missing compact_sha256 → 1"

# Test 11: ack invalid JSON → 1 (node path) / tolerated by grep fallback → still 1 via missing fields
printf '{not json\n' > "$ACK"
run_audit; assert_eq "$?" "1" "invalid JSON ack → 1"

# --- accept-compact.sh ---

# Test 12: accept --help → 0
"$ACCEPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "accept --help exits 0"
# Test 13: accept unknown flag → 2
"$ACCEPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "accept unknown flag exits 2"

# Test 14: accept missing compact → 1
AC_COMPACT="$TMP/nope.md" AC_ACK="$ACK" "$ACCEPT" --quiet >/dev/null 2>&1
assert_eq "$?" "1" "accept missing compact → 1"

# Test 15: accept records an ack the audit then accepts (round-trip) → 0 then 0
AC_COMPACT="$COMPACT" AC_ACK="$ACK" "$ACCEPT" --quiet --by "tester" >/dev/null 2>&1
assert_eq "$?" "0" "accept records ack → 0"
run_audit; assert_eq "$?" "0" "audit accepts the freshly-written ack → 0"

# Test 16: after accept, amending the compact makes the audit go stale → 1
printf 'compact body v2 (amended)\n' >> "$COMPACT"
run_audit; assert_eq "$?" "1" "amended compact invalidates prior acceptance → 1"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-agent-compact] OK — $passes/$total passed."; exit 0
else log "[test-agent-compact] FAIL — $failures/$total."; exit 1; fi
