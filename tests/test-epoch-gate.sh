#!/usr/bin/env bash
# tests/test-epoch-gate.sh — unit tests for scripts/_lib/epoch-gate.sh (ADR-0071).
# Hermetic: EPOCH_LOCKFILE + EPOCH_BASELINE_DIR are pointed at fixtures under a
# temp dir so no test touches the real lockfile or tests/ baselines.
# Exit: 0 all pass / 1 any fail / 2 harness error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-epoch-gate] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected [$2], got [$1])"; failures=$((failures+1)); fi
}

# Locate + source the library under test.
LIB="$(cd "$(dirname "$0")/.." && pwd)/scripts/_lib/epoch-gate.sh"
[ -f "$LIB" ] || { log "  ✗ library missing: $LIB"; exit 2; }

TMP=$(mktemp -d -t epoch-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# --- Fixtures -----------------------------------------------------------------
mkdir -p "$TMP/tests"
# A fixture lockfile with a known 40-hex pin (short = "abc1234").
PIN_FULL="abc1234def5678000000000000000000000cafe0"
cat > "$TMP/lock.yaml" <<EOF
schema_version: 1
pinned_commit:   $PIN_FULL
pinned_branch:   main
EOF

# Re-source with fixture env each time (functions read the : \${VAR:=...} defaults
# at *call* time via the exported vars, so exporting before sourcing is enough).
export EPOCH_LOCKFILE="$TMP/lock.yaml"
export EPOCH_BASELINE_DIR="$TMP/tests"
# shellcheck disable=SC1090
. "$LIB"

# --- epoch_current_pin --------------------------------------------------------
assert_eq "$(epoch_current_pin)" "abc1234" "epoch_current_pin returns 7-char short pin"

EPOCH_LOCKFILE="$TMP/nonexistent.yaml" assert_eq "$(EPOCH_LOCKFILE="$TMP/none.yaml" epoch_current_pin)" "unpinned" "missing lockfile → unpinned"

cat > "$TMP/lock-bad.yaml" <<EOF
schema_version: 1
pinned_commit:   not-a-hash
EOF
assert_eq "$(EPOCH_LOCKFILE="$TMP/lock-bad.yaml" epoch_current_pin)" "unpinned" "malformed pin → unpinned"

# --- epoch_baseline_path ------------------------------------------------------
assert_eq "$(epoch_baseline_path myaudit)" "$TMP/tests/myaudit-baseline.abc1234.txt" \
    "epoch_baseline_path is pin-keyed"

# --- epoch_resolve_baseline ---------------------------------------------------
# (a) neither present → empty
assert_eq "$(epoch_resolve_baseline myaudit 2>/dev/null)" "" "resolve: none present → empty"
# (b) legacy flat only → returns legacy (note to stderr)
printf 'legacy-finding\n' > "$TMP/tests/myaudit-baseline.txt"
assert_eq "$(epoch_resolve_baseline myaudit 2>/dev/null)" "$TMP/tests/myaudit-baseline.txt" \
    "resolve: legacy flat used as fallback"
# (c) pin-keyed present → preferred over legacy
printf 'keyed-finding\n' > "$TMP/tests/myaudit-baseline.abc1234.txt"
assert_eq "$(epoch_resolve_baseline myaudit 2>/dev/null)" "$TMP/tests/myaudit-baseline.abc1234.txt" \
    "resolve: pin-keyed preferred over legacy"

# --- epoch_filter_new ---------------------------------------------------------
printf 'a\nb\nc\n' > "$TMP/cur.txt"
printf 'a\nc\n'     > "$TMP/base.txt"
assert_eq "$(epoch_filter_new "$TMP/base.txt" "$TMP/cur.txt" | tr '\n' ',')" "b," \
    "filter_new: current minus baseline = new only"
# empty/absent baseline → all current are new
assert_eq "$(epoch_filter_new "" "$TMP/cur.txt" | tr '\n' ',')" "a,b,c," \
    "filter_new: no baseline → all current are new"
assert_eq "$(epoch_filter_new "$TMP/does-not-exist.txt" "$TMP/cur.txt" | tr '\n' ',')" "a,b,c," \
    "filter_new: missing baseline file → all current are new"
# identical → no new
assert_eq "$(epoch_filter_new "$TMP/cur.txt" "$TMP/cur.txt" | tr '\n' ',')" "" \
    "filter_new: current == baseline → nothing new"

# --- epoch_req_gated ----------------------------------------------------------
printf '{"applies_to_floor_version":2,"applicable_rules":[]}\n' > "$TMP/req-v2.json"
epoch_req_gated "$TMP/req-v2.json"; assert_eq "$?" "0" "req_gated: floor_version 2 → gated (0)"
printf '{"applies_to_floor_version":5}\n' > "$TMP/req-v5.json"
epoch_req_gated "$TMP/req-v5.json"; assert_eq "$?" "0" "req_gated: floor_version 5 → gated (0)"
printf '{"applies_to_floor_version":1}\n' > "$TMP/req-v1.json"
epoch_req_gated "$TMP/req-v1.json"; assert_eq "$?" "1" "req_gated: floor_version 1 → grandfathered (1)"
printf '{"applicable_rules":[]}\n' > "$TMP/req-none.json"
epoch_req_gated "$TMP/req-none.json"; assert_eq "$?" "1" "req_gated: no marker → grandfathered (1)"
printf 'not json{{\n' > "$TMP/req-bad.json"
epoch_req_gated "$TMP/req-bad.json"; assert_eq "$?" "1" "req_gated: malformed → grandfathered (1)"
epoch_req_gated "$TMP/missing.json"; assert_eq "$?" "1" "req_gated: missing file → grandfathered (1)"

# --- epoch_note ---------------------------------------------------------------
note=$(epoch_note structural-audit "nothing registry-derived")
case "$note" in
    *"pin=abc1234"*"nothing registry-derived"*) assert_eq "ok" "ok" "epoch_note carries pin + context" ;;
    *) assert_eq "$note" "<banner with pin+context>" "epoch_note carries pin + context" ;;
esac

# --- summary ------------------------------------------------------------------
log ""
log "[test-epoch-gate] $passes passed, $failures failed"
[ "$failures" -eq 0 ] || exit 1
exit 0
