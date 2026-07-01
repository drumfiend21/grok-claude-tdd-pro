#!/usr/bin/env bash
# tests/test-grok-run.sh — unit tests for scripts/grok-run.sh (TICKET-108 / ADR-0080).
# Hermetic: GROK_BIN points at a stub `grok`, GROK_RUNS_DIR at a temp dir, so the live path
# is exercised without the real CLI, a network call, or a real XAI_API_KEY.
# Exit: 0 all pass / 1 any fail / 2 harness error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-grok-run] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}
assert_contains() {
    case "$1" in *"$2"*) log "  ✓ $3"; passes=$((passes+1)) ;; *) log "  ✗ $3 (missing '$2')"; failures=$((failures+1)) ;; esac
}

SCRIPT=./scripts/grok-run.sh
TMP=$(mktemp -d -t grokrun-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
RUNS="$TMP/runs"
STUBGROK="$TMP/grok"    # a fake grok on disk; GROK_BIN points here

# Fake grok that reads the prompt on stdin and emits valid Structured Output (G-3).
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null   # consume the prompt
printf '{"phase":"stub-live","status":"green","tickets":[]}\n'
exit 0
GROK
chmod +x "$STUBGROK"

# --- usage ---
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
"$SCRIPT" bogusphase >/dev/null 2>&1; assert_eq "$?" "2" "unknown phase → usage (2)"
"$SCRIPT" >/dev/null 2>&1; assert_eq "$?" "2" "missing phase → usage (2)"

# --- stub path: --dry-run always stubs (no CLI/key needed) ---
out=$(GROK_RUNS_DIR="$RUNS" "$SCRIPT" research --input 'topic=x' --dry-run 2>/dev/null); rc=$?
assert_eq "$rc" "0" "--dry-run → 0"
assert_contains "$out" '"stub":true' "--dry-run emits stub structured output"
assert_contains "$out" '"phase":"research"' "--dry-run output names the phase"

# --- stub path: grok absent → stub, not crash ---
out=$(GROK_BIN="$TMP/no-such-grok" GROK_RUNS_DIR="$RUNS" "$SCRIPT" dispatch 2>/dev/null); rc=$?
assert_eq "$rc" "0" "grok absent → stub (0)"
assert_contains "$out" '"stub":true' "grok absent → stub output"

# --- stub path: grok present but XAI_API_KEY unset → stub (G-2) ---
out=$(env -u XAI_API_KEY GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS" "$SCRIPT" dispatch 2>/dev/null); rc=$?
assert_eq "$rc" "0" "grok present, no key → stub (0)"
assert_contains "$out" '"stub":true' "no key → stub output"

# --- LIVE path: grok + key present → real invocation, structured output passed through ---
out=$(XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS" "$SCRIPT" research 2>/dev/null); rc=$?
assert_eq "$rc" "0" "live path (grok+key) → 0"
assert_contains "$out" '"status":"green"' "live path passes grok's structured output through"
case "$out" in *'"stub":true'*) log "  ✗ live path wrongly stubbed"; failures=$((failures+1)) ;; *) log "  ✓ live path is NOT stubbed"; passes=$((passes+1)) ;; esac

# --- LIVE path: grok emits NON-JSON → G-3 violation → exit 4 ---
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null; printf 'not json at all\n'; exit 0
GROK
chmod +x "$STUBGROK"
XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS" "$SCRIPT" research >/dev/null 2>&1
assert_eq "$?" "4" "live path + non-JSON output → G-3 fail (4)"

# --- LIVE path: grok exits non-zero → exit 4 ---
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null; echo "boom" >&2; exit 7
GROK
chmod +x "$STUBGROK"
XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS" "$SCRIPT" research >/dev/null 2>&1
assert_eq "$?" "4" "live path + grok failure → 4"

# --- G-15 observability: a run log is written ---
[ -n "$(ls "$RUNS"/*.jsonl 2>/dev/null)" ] && { log "  ✓ G-15 run log(s) written to runs dir"; passes=$((passes+1)); } \
    || { log "  ✗ no run log written"; failures=$((failures+1)); }

# --- G-4 effort default: dispatch=low, research=medium ---
env -u XAI_API_KEY GROK_BIN="$TMP/none" GROK_RUNS_DIR="$RUNS" "$SCRIPT" dispatch --dry-run 2>/dev/null | grep -q '"effort":"low"' \
    && { log "  ✓ dispatch defaults to effort=low (G-4)"; passes=$((passes+1)); } || { log "  ✗ dispatch effort wrong"; failures=$((failures+1)); }
"$SCRIPT" research --dry-run 2>/dev/null | grep -q '"effort":"medium"' \
    && { log "  ✓ research defaults to effort=medium (G-4)"; passes=$((passes+1)); } || { log "  ✗ research effort wrong"; failures=$((failures+1)); }

total=$((passes + failures))
log ""
log "[test-grok-run] $passes/$total passed"
[ "$failures" -eq 0 ] || exit 1
exit 0
