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

# --- stub path: grok present but XAI_API_KEY unset (and no key files) → stub (G-2) ---
out=$(env -u XAI_API_KEY GCTP_KEY_FILE="$TMP/no-keyfile" GROK_ENV_FILE="$TMP/no-env" GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS" "$SCRIPT" dispatch 2>/dev/null); rc=$?
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

# --- key discovery (TICKET-109): install.sh-persisted key file → live ---
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null
printf '{"phase":"stub-live","status":"green","tickets":[]}\n'
exit 0
GROK
chmod +x "$STUBGROK"
printf 'xai-testkey-from-file\n' > "$TMP/keyfile"
out=$(env -u XAI_API_KEY GCTP_KEY_FILE="$TMP/keyfile" GROK_ENV_FILE="$TMP/no-env" GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS" "$SCRIPT" research 2>&1); rc=$?
assert_eq "$rc" "0" "key from GCTP_KEY_FILE → live (0)"
case "$out" in *'"stub":true'*) log "  ✗ key-file path wrongly stubbed"; failures=$((failures+1)) ;; *) log "  ✓ key-file path is NOT stubbed"; passes=$((passes+1)) ;; esac
case "$out" in *xai-testkey-from-file*) log "  ✗ key leaked into output (G-2)"; failures=$((failures+1)) ;; *) log "  ✓ key never printed (G-2)"; passes=$((passes+1)) ;; esac

# --- key discovery (TICKET-109): repo-local .grok/.env → live; parsed, not sourced ---
printf 'XAI_API_KEY="xai-testkey-from-env-file"\n' > "$TMP/dotenv"
out=$(env -u XAI_API_KEY GCTP_KEY_FILE="$TMP/no-keyfile" GROK_ENV_FILE="$TMP/dotenv" GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS" "$SCRIPT" research 2>/dev/null); rc=$?
assert_eq "$rc" "0" "key from .grok/.env → live (0)"
case "$out" in *'"stub":true'*) log "  ✗ .env path wrongly stubbed"; failures=$((failures+1)) ;; *) log "  ✓ .env path is NOT stubbed"; passes=$((passes+1)) ;; esac

# --- key discovery precedence: env var wins over key files ---
KEYPROBE="$TMP/keyprobe"    # fake grok that records which key it saw
cat > "$KEYPROBE" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null
printf '{"status":"green","saw":"%s"}\n' "${XAI_API_KEY:-none}"
exit 0
GROK
chmod +x "$KEYPROBE"
out=$(XAI_API_KEY=xai-env-wins GCTP_KEY_FILE="$TMP/keyfile" GROK_ENV_FILE="$TMP/dotenv" GROK_BIN="$KEYPROBE" GROK_RUNS_DIR="$RUNS" "$SCRIPT" research 2>/dev/null)
assert_contains "$out" '"saw":"xai-env-wins"' "env XAI_API_KEY wins over key files"

# --- --preflight (TICKET-109): not live-ready → 3; live-ready → 0; never prints the key ---
env -u XAI_API_KEY GCTP_KEY_FILE="$TMP/no-keyfile" GROK_ENV_FILE="$TMP/no-env" GROK_BIN="$TMP/no-such-grok" "$SCRIPT" --preflight >/dev/null 2>&1
assert_eq "$?" "3" "--preflight, nothing wired → 3"
out=$(env -u XAI_API_KEY GCTP_KEY_FILE="$TMP/keyfile" GROK_ENV_FILE="$TMP/no-env" GROK_BIN="$STUBGROK" "$SCRIPT" --preflight 2>&1); rc=$?
assert_eq "$rc" "0" "--preflight, CLI + key present → 0 (LIVE-ready)"
assert_contains "$out" "LIVE" "--preflight reports LIVE readiness"
case "$out" in *xai-testkey-from-file*) log "  ✗ --preflight leaked the key"; failures=$((failures+1)) ;; *) log "  ✓ --preflight never prints the key"; passes=$((passes+1)) ;; esac

# --- G-15 observability: a run log is written ---
[ -n "$(ls "$RUNS"/*.jsonl 2>/dev/null)" ] && { log "  ✓ G-15 run log(s) written to runs dir"; passes=$((passes+1)); } \
    || { log "  ✗ no run log written"; failures=$((failures+1)); }

# --- G-4 effort default: dispatch=low, research=medium ---
env -u XAI_API_KEY GROK_BIN="$TMP/none" GROK_RUNS_DIR="$RUNS" "$SCRIPT" dispatch --dry-run 2>/dev/null | grep -q '"effort":"low"' \
    && { log "  ✓ dispatch defaults to effort=low (G-4)"; passes=$((passes+1)); } || { log "  ✗ dispatch effort wrong"; failures=$((failures+1)); }
"$SCRIPT" research --dry-run 2>/dev/null | grep -q '"effort":"medium"' \
    && { log "  ✓ research defaults to effort=medium (G-4)"; passes=$((passes+1)); } || { log "  ✗ research effort wrong"; failures=$((failures+1)); }

# --- TICKET-110: G-19 result reuse / G-20 opt-in model / G-15 usage capture ---
CALLS="$TMP/calls"; RUNS2="$TMP/runs2"
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null
echo x >> "${CALL_LOG:?}"
printf '{"status":"green","req":"r1","usage":{"input_tokens":10,"output_tokens":5}}\n'
exit 0
GROK
chmod +x "$STUBGROK"

# dispatch: identical re-run reuses the recorded result — no second grok call, byte-identical stdout
out1=$(CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-1' 2>/dev/null); rc1=$?
assert_eq "$rc1" "0" "live dispatch (cache-priming run) → 0"
out2=$(CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-1' 2>"$TMP/err2"); rc2=$?
assert_eq "$rc2" "0" "identical dispatch re-run → 0"
assert_eq "$(wc -l < "$CALLS" | tr -d ' ')" "1" "identical dispatch re-run does NOT re-invoke grok (G-19)"
assert_eq "$out2" "$out1" "reused output is byte-identical to the paid run"
assert_contains "$(cat "$TMP/err2")" "CACHED" "reuse is announced (never silent)"

# --fresh bypasses reuse
CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-1' --fresh >/dev/null 2>&1
assert_eq "$(wc -l < "$CALLS" | tr -d ' ')" "2" "--fresh re-invokes grok"

# GROK_REUSE=0 kill switch
CALL_LOG="$CALLS" GROK_REUSE=0 XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-1' >/dev/null 2>&1
assert_eq "$(wc -l < "$CALLS" | tr -d ' ')" "3" "GROK_REUSE=0 disables reuse"

# an explicit quality ask (higher --effort) is a different cache slot → always runs live
CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-1' --effort high >/dev/null 2>&1
assert_eq "$(wc -l < "$CALLS" | tr -d ' ')" "4" "different --effort never reuses a lower-effort result"

# research: FRESH by default (G-17) — identical re-run still re-invokes …
CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" research --input 'topic=t1' >/dev/null 2>&1
CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" research --input 'topic=t1' >/dev/null 2>&1
assert_eq "$(wc -l < "$CALLS" | tr -d ' ')" "6" "research re-run re-invokes by default (fresh research, G-17)"
# … and reuses only under an explicit TTL opt-in
CALL_LOG="$CALLS" GROK_REUSE_TTL_SECONDS=3600 XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" research --input 'topic=t1' >/dev/null 2>&1
assert_eq "$(wc -l < "$CALLS" | tr -d ' ')" "6" "research reuses within explicit GROK_REUSE_TTL_SECONDS"

# G-15: token usage from grok's response is recorded in the run log
grep -h '"usage"' "$RUNS2"/*.jsonl 2>/dev/null | grep -q '"output_tokens":5' \
    && { log "  ✓ G-15 usage tokens recorded in the run log"; passes=$((passes+1)); } \
    || { log "  ✗ usage tokens missing from run log"; failures=$((failures+1)); }

# G-20: --model passthrough + recorded escalation when the cheap model fails structured output
ARGLOG="$TMP/arglog"; ARGPROBE="$TMP/argprobe"
cat > "$ARGPROBE" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null   # prompt may arrive via argv (real CLI) or stdin; consume either way
case "$*" in
    *"--model grok-4-fast"*) printf 'ATTEMPT --model grok-4-fast\n' >> "${ARG_LOG:?}"; printf 'not json at all\n'; exit 0 ;;
    *)                       printf 'ATTEMPT default\n' >> "${ARG_LOG:?}"; printf '{"status":"green"}\n'; exit 0 ;;
esac
GROK
chmod +x "$ARGPROBE"
out=$(ARG_LOG="$ARGLOG" XAI_API_KEY=test-key GROK_BIN="$ARGPROBE" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" decomposition --input 'brief=b' --model grok-4-fast 2>/dev/null); rc=$?
assert_eq "$rc" "0" "cheap-model non-JSON → escalate to default model → 0 (G-20)"
assert_contains "$out" '"status":"green"' "escalated attempt's output is passed through"
grep -q -- "--model grok-4-fast" "$ARGLOG" \
    && { log "  ✓ --model is passed to the CLI"; passes=$((passes+1)); } \
    || { log "  ✗ --model not passed"; failures=$((failures+1)); }
assert_eq "$(wc -l < "$ARGLOG" | tr -d ' ')" "2" "exactly one escalation retry (two attempts total)"
grep -h '"event":"escalate"' "$RUNS2"/*.jsonl 2>/dev/null | grep -q '"from_model":"grok-4-fast"' \
    && { log "  ✓ escalation recorded with model + reason (G-20 no-silent)"; passes=$((passes+1)); } \
    || { log "  ✗ escalation not recorded"; failures=$((failures+1)); }

# CLI envelope handling (TICKET-111): the real grok wraps replies in {text, stopReason, ...} —
# a completed turn (EndTurn) emits the INNER phase JSON; a cancelled turn fails and is never cached
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null
printf '{"text":"{\\"phase_doc\\":true}","stopReason":"EndTurn","sessionId":"s","thought":"t"}\n'
exit 0
GROK
chmod +x "$STUBGROK"
out=$(XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-ENV' 2>/dev/null); rc=$?
assert_eq "$rc" "0" "EndTurn envelope → 0"
assert_eq "$out" '{"phase_doc":true}' "envelope is unwrapped — stdout is the inner phase JSON"
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null
printf '{"text":"","stopReason":"Cancelled","sessionId":"s","thought":"t"}\n'
exit 0
GROK
chmod +x "$STUBGROK"
XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-CANCEL' >/dev/null 2>&1
assert_eq "$?" "4" "Cancelled envelope (valid JSON, empty text) → 4, not a false green"
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null
printf '{"phase_doc":"second"}\n'
exit 0
GROK
chmod +x "$STUBGROK"
out=$(XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-CANCEL' 2>/dev/null); rc=$?
assert_eq "$rc" "0" "run after a cancelled turn goes live (cancelled result was not cached)"
assert_contains "$out" '"phase_doc":"second"' "post-cancel run returns the fresh live result"
# the runner-compiled prompt carries the headless transport contract (G-5 byte-stable footer)
PROBE_PROMPT="$TMP/promptprobe"
cat > "$PROBE_PROMPT" <<'GROK'
#!/usr/bin/env bash
printf '%s' "$2" > "${PROMPT_COPY:?}"    # $1=-p $2=<prompt>
printf '{"ok":true}\n'
GROK
chmod +x "$PROBE_PROMPT"
PROMPT_COPY="$TMP/prompt-copy" XAI_API_KEY=test-key GROK_BIN="$PROBE_PROMPT" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-FOOT' >/dev/null 2>&1
grep -q "Headless transport contract" "$TMP/prompt-copy" \
    && { log "  ✓ compiled prompt carries the headless transport contract footer"; passes=$((passes+1)); } \
    || { log "  ✗ headless footer missing from compiled prompt"; failures=$((failures+1)); }

# standing default model (TICKET-111): plain runs pass --model grok-4.3 (§2 reasoning pick —
# the CLI's non-reasoning default rejects the G-4-mandated --effort); GROK_DEFAULT_MODEL overrides
MODPROBE="$TMP/modprobe"
cat > "$MODPROBE" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null
case "$*" in
    *"--model grok-4.3"*)  echo default43 >> "${ARG_LOG:?}" ;;
    *"--model my-model"*)  echo mymodel   >> "${ARG_LOG:?}" ;;
esac
printf '{"status":"green"}\n'
GROK
chmod +x "$MODPROBE"
: > "$ARGLOG"
ARG_LOG="$ARGLOG" XAI_API_KEY=test-key GROK_BIN="$MODPROBE" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" research --input 'topic=dm1' >/dev/null 2>&1
grep -q default43 "$ARGLOG" \
    && { log "  ✓ plain run uses the standing default model grok-4.3"; passes=$((passes+1)); } \
    || { log "  ✗ standing default model not passed"; failures=$((failures+1)); }
ARG_LOG="$ARGLOG" GROK_DEFAULT_MODEL=my-model XAI_API_KEY=test-key GROK_BIN="$MODPROBE" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" research --input 'topic=dm2' >/dev/null 2>&1
grep -q mymodel "$ARGLOG" \
    && { log "  ✓ GROK_DEFAULT_MODEL override respected"; passes=$((passes+1)); } \
    || { log "  ✗ GROK_DEFAULT_MODEL override ignored"; failures=$((failures+1)); }

# a failed run must not poison the cache: failure → then a good run invokes live and succeeds
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null; echo x >> "${CALL_LOG:?}"; echo boom >&2; exit 7
GROK
chmod +x "$STUBGROK"
CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-2' >/dev/null 2>&1
assert_eq "$?" "4" "failing dispatch → 4 (no model set → no ladder)"
cat > "$STUBGROK" <<'GROK'
#!/usr/bin/env bash
cat >/dev/null; echo x >> "${CALL_LOG:?}"; printf '{"status":"green"}\n'; exit 0
GROK
chmod +x "$STUBGROK"
out=$(CALL_LOG="$CALLS" XAI_API_KEY=test-key GROK_BIN="$STUBGROK" GROK_RUNS_DIR="$RUNS2" "$SCRIPT" dispatch --input 'ticket=T-2' 2>/dev/null); rc=$?
assert_eq "$rc" "0" "same inputs after a failure run live and succeed (no poisoned cache)"
assert_contains "$out" '"status":"green"' "post-failure run returns the live result"

total=$((passes + failures))
log ""
log "[test-grok-run] $passes/$total passed"
[ "$failures" -eq 0 ] || exit 1
exit 0
