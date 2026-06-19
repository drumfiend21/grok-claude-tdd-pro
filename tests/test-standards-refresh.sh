#!/usr/bin/env bash
# tests/test-standards-refresh.sh — unit tests for scripts/standards-refresh.sh (TICKET-075 / ADR-0064).
# Hermetic: stub CTP entrypoints (SR_REFRESH_BIN / SR_SYNC_BIN / SR_SETFREQ_BIN) + SR_NOW
# drive the cadence math. Exit contract: 0 (ok/not-due/non-fatal) / 2 (error/invalid freq).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-standards-refresh] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/standards-refresh.sh

TMP=$(mktemp -d -t sr-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# Stub CTP entrypoints. refresh.sh appends to a log so we can count drives.
printf '#!/usr/bin/env bash\necho ran >> "%s/refresh.log"\nexit 0\n' "$TMP" > "$TMP/refresh.sh"; chmod +x "$TMP/refresh.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/sync.sh"; chmod +x "$TMP/sync.sh"
# Stub set-refresh-frequency validator: accept <N>m|h|d|w|mo + calendar tokens (writing
# the --config registry, like the real one), else exit 2.
cat > "$TMP/setfreq.sh" <<'SF'
#!/usr/bin/env bash
f=""; cfg=""; while [ $# -gt 0 ]; do case "$1" in --config) cfg="$2"; shift 2;; *) f="$1"; shift;; esac; done
ok=0
case "$f" in
  daily|weekly|monthly|quarterly|on-demand) ok=1 ;;
  *mo) n="${f%mo}";; *m) n="${f%m}";; *h) n="${f%h}";; *d) n="${f%d}";; *w) n="${f%w}";; *) exit 2 ;;
esac
if [ "$ok" -ne 1 ]; then case "$n" in ''|*[!0-9]*) exit 2 ;; esac; fi
[ -n "$cfg" ] && { mkdir -p "$(dirname "$cfg")"; printf 'default: %s\nchosen_at_install: "%s"\n' "$f" "$f" > "$cfg"; }
exit 0
SF
chmod +x "$TMP/setfreq.sh"

C="$TMP/cfg.json"; CTPFF="$TMP/ctp/.claude-tdd-pro/FETCH-FREQUENCIES.yaml"
refresh_count() { [ -f "$TMP/refresh.log" ] && wc -l < "$TMP/refresh.log" | tr -d ' ' || echo 0; }
run() { SR_CONFIG="$C" SR_REFRESH_BIN="$TMP/refresh.sh" SR_SYNC_BIN="$TMP/sync.sh" SR_SETFREQ_BIN="$TMP/setfreq.sh" SR_CTP_FREQ_FILE="$CTPFF" SR_STATE_DIR="$TMP/state" "$SCRIPT" "$@"; }

# Test 1: --help → 0
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
# Test 2: unknown flag → 2
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"
# Test 3: --significance → 0 and prints the explanation
out=$("$SCRIPT" --significance 2>&1); assert_eq "$?" "0" "--significance exits 0"
printf '%s' "$out" | grep -q "DERIVED FROM" && assert_eq "yes" "yes" "--significance explains source→enforcement" || assert_eq "no" "yes" "--significance explains source→enforcement"

# Test 4: --configure missing freq → 2
run --configure >/dev/null 2>&1; assert_eq "$?" "2" "--configure without freq → 2"
# Test 5: --configure valid (30m) → 0, config marked configured
run --configure 30m >/dev/null 2>&1; assert_eq "$?" "0" "--configure 30m → 0"
cfg=$(node -e 'const c=require(process.argv[1]);console.log(c.frequency+"|"+c.configured)' "$C" 2>/dev/null)
assert_eq "$cfg" "30m|true" "config records frequency + configured=true"
# Test 5b: --configure ALSO writes CTP's registry (two-layer alignment, ADR-0065)
rm -f "$CTPFF"; run --configure 6h >/dev/null 2>&1
( [ -f "$CTPFF" ] && grep -q '6h' "$CTPFF" ) && assert_eq "yes" "yes" "--configure writes CTP fetch registry too" || assert_eq "no" "yes" "--configure writes CTP fetch registry too"

# Test 6: --configure invalid (bogus) → 2  (and does NOT write the CTP registry)
rm -f "$CTPFF"; run --configure bogus >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "--configure bogus → 2"
[ -f "$CTPFF" ] && assert_eq "wrote" "absent" "invalid freq must not write CTP registry" || assert_eq "absent" "absent" "invalid freq must not write CTP registry"
# Test 7: grammar accepts m/h/d/w/mo
ok=1; for f in 5m 6h 2d 1w 1mo daily; do run --configure "$f" >/dev/null 2>&1 || ok=0; done
assert_eq "$ok" "1" "grammar accepts m/h/d/w/mo + calendar token"
# Test 8: grammar rejects malformed
bad=1; for f in 5x 30 mo d; do run --configure "$f" >/dev/null 2>&1 && bad=0; done
assert_eq "$bad" "1" "grammar rejects malformed cadence"

# --- cadence / due logic (config: 1h) ---
rm -f "$C" "$TMP/refresh.log"
run --configure 1h >/dev/null 2>&1

# Test 9: first --check → DUE → drives refresh once
SR_NOW=1000000 run --check --quiet >/dev/null 2>&1
assert_eq "$(refresh_count)" "1" "first --check (no prior) → refresh runs"

# Test 10: --check 30m later → NOT due (within 1h) → no extra refresh
SR_NOW=1001800 run --check --quiet >/dev/null 2>&1
assert_eq "$(refresh_count)" "1" "within-window --check → no refresh"

# Test 11: --check 2h later → DUE → refresh again
SR_NOW=1008200 run --check --quiet >/dev/null 2>&1
assert_eq "$(refresh_count)" "2" "after-interval --check → refresh again"

# Test 12: --force always refreshes even within window
SR_NOW=1008300 run --force --quiet >/dev/null 2>&1
assert_eq "$(refresh_count)" "3" "--force → refresh regardless of cadence"

# Test 13: on-demand cadence → not due on --check (manual only)
rm -f "$C" "$TMP/refresh.log"; run --configure on-demand >/dev/null 2>&1
SR_NOW=2000000 run --check --quiet >/dev/null 2>&1
# first run has no last_ms → DUE once even for on-demand (initial seed); second run → not due
n1=$(refresh_count)
SR_NOW=2999999 run --check --quiet >/dev/null 2>&1
assert_eq "$(refresh_count)" "$n1" "on-demand → no auto-refresh after the initial seed"

# Test 14: missing refresh bin → non-fatal (0)
rm -f "$C"; run --configure 1d >/dev/null 2>&1
SR_NOW=3000000 SR_CONFIG="$C" SR_REFRESH_BIN="$TMP/nope.sh" SR_SYNC_BIN="$TMP/sync.sh" SR_STATE_DIR="$TMP/state" "$SCRIPT" --check --quiet >/dev/null 2>&1
assert_eq "$?" "0" "missing refresh entrypoint → non-fatal (0)"

# Test 15: --status reports cadence
out=$(run --status 2>&1); printf '%s' "$out" | grep -q "cadence=1d" && assert_eq "yes" "yes" "--status reports cadence" || assert_eq "no" "yes" "--status reports cadence"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-standards-refresh] OK — $passes/$total passed."; exit 0
else log "[test-standards-refresh] FAIL — $failures/$total."; exit 1; fi
