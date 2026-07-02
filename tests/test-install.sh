#!/usr/bin/env bash
# tests/test-install.sh — unit tests for install.sh
# Per TICKET-054 / ADR-0051. Exit-code contract: 0 (installed) / 1 (prereq missing
# or a step failed) / 2 (usage error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-install] starting"

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

SCRIPT=./install.sh
TMP=$(mktemp -d -t install-test.XXXXXX) || { log "mktemp failed"; exit 1; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# Hermetic Grok-step env for every invocation below: no network auto-install
# (GCTP_GROK_INSTALL=skip), key file redirected into the temp dir, stdin closed
# (</dev/null) so the one-time key prompt can never block a test run.
HKEY="$TMP/gctp/xai_key"

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: --quick sets up and exits 0, skipping the end-to-end verification
out=$(env -u XAI_API_KEY GCTP_GROK_INSTALL=skip GCTP_KEY_FILE="$HKEY" "$SCRIPT" --quick </dev/null 2>&1); ec=$?
assert_eq "$ec" "0" "--quick exits 0"
assert_match "$out" "skipped" "--quick skips the verification step"

# Test 4: default run exits 0 and reports readiness
out=$(env -u XAI_API_KEY GCTP_GROK_INSTALL=skip GCTP_KEY_FILE="$HKEY" "$SCRIPT" </dev/null 2>&1); ec=$?
assert_eq "$ec" "0" "default run exits 0"
assert_match "$out" "ready to go" "default run reports readiness"
assert_match "$out" "verified" "default run runs the end-to-end verification"

# Test 5: prerequisite/location guard — run a copy from a folder with no scripts/.
# install.sh cd's to its own dirname, so a copy in an empty temp dir must detect
# that it is not in the project folder and exit 1 (not 0, not crash).
cp install.sh "$TMP/install.sh"
out=$(bash "$TMP/install.sh" 2>&1); ec=$?
assert_eq "$ec" "1" "missing project folder exits 1"
assert_match "$out" "project folder" "missing-folder path explains the problem"

# --- Grok outer-loop setup (TICKET-109) ---------------------------------------

# Test 6: --no-grok skips the Grok step entirely and still succeeds
out=$(env -u XAI_API_KEY "$SCRIPT" --no-grok --quick </dev/null 2>&1); ec=$?
assert_eq "$ec" "0" "--no-grok --quick exits 0"
assert_match "$out" "skipped (--no-grok)" "--no-grok reports the Grok step skipped"

# Test 7: key already in env + no key file → install persists it (one-time setup),
# file gets 600 perms, and the key itself is never echoed to the terminal.
out=$(XAI_API_KEY=xai-test-persist-me GCTP_GROK_INSTALL=skip GCTP_KEY_FILE="$HKEY" "$SCRIPT" --quick </dev/null 2>&1); ec=$?
assert_eq "$ec" "0" "env-key run exits 0"
[ -f "$HKEY" ] && { log "  ✓ key persisted to GCTP_KEY_FILE"; passes=$((passes+1)); } \
    || { log "  ✗ key file not written"; failures=$((failures+1)); }
IFS= read -r persisted < "$HKEY" 2>/dev/null || persisted=""
assert_eq "$persisted" "xai-test-persist-me" "persisted key matches the env key"
perms=$(stat -f '%Lp' "$HKEY" 2>/dev/null || stat -c '%a' "$HKEY" 2>/dev/null)
assert_eq "$perms" "600" "key file is chmod 600"
case "$out" in *xai-test-persist-me*) log "  ✗ key echoed in install output"; failures=$((failures+1)) ;; *) log "  ✓ key never echoed in install output"; passes=$((passes+1)) ;; esac

# Test 8: no key anywhere, non-interactive → still exit 0 (stub outer loop),
# with a plain-language pointer to how to supply the key later.
out=$(env -u XAI_API_KEY GCTP_GROK_INSTALL=skip GCTP_KEY_FILE="$TMP/absent/xai_key" GROK_ENV_FILE="$TMP/absent/.env" "$SCRIPT" --quick </dev/null 2>&1); ec=$?
assert_eq "$ec" "0" "keyless non-interactive run exits 0 (stub-first, never bricked)"
assert_match "$out" "XAI_API_KEY" "keyless run tells the operator how to supply the key"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-install] OK — $passes/$total passed."; exit 0
else log "[test-install] FAIL — $failures/$total."; exit 1; fi
