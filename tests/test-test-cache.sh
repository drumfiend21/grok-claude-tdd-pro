#!/usr/bin/env bash
# tests/test-test-cache.sh — unit tests for scripts/_lib/test-cache.sh (TICKET-099).
# Fully hermetic: TC_REPO_ROOT / TC_CACHE_DIR / TC_ACTIVE_JSON / EPOCH_LOCKFILE are
# pointed at fixtures under a temp dir so nothing touches the real repo/cache.
# Exit: 0 all pass / 1 any fail / 2 harness error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-test-cache] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected [$2], got [$1])"; failures=$((failures+1)); fi
}
assert_ne() {
    if [ "$1" != "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected change, both [$1])"; failures=$((failures+1)); fi
}

LIB="$(cd "$(dirname "$0")/.." && pwd)/scripts/_lib/test-cache.sh"
[ -f "$LIB" ] || { log "  ✗ library missing: $LIB"; exit 2; }

TMP=$(mktemp -d -t tc-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# --- Fixture repo ------------------------------------------------------------
mkdir -p "$TMP/repo/scripts/_lib" "$TMP/repo/tests"
printf '#!/usr/bin/env bash\n. "$D/_lib/dep.sh"\necho foo-v1\n' > "$TMP/repo/scripts/foo.sh"
printf '#!/usr/bin/env bash\necho dep-v1\n' > "$TMP/repo/scripts/_lib/dep.sh"
printf '#!/usr/bin/env bash\nSCRIPT=./scripts/foo.sh\n"$SCRIPT"\n' > "$TMP/repo/tests/test-foo.sh"
cat > "$TMP/lock.yaml" <<'EOF'
pinned_commit:   1111111aaaaaaa00000000000000000000000000
EOF
printf '{"rules":[]}\n' > "$TMP/active.json"

export TC_REPO_ROOT="$TMP/repo"
export TC_CACHE_DIR="$TMP/cache"
export TC_ACTIVE_JSON="$TMP/active.json"
export EPOCH_LOCKFILE="$TMP/lock.yaml"
# shellcheck disable=SC1090
. "$LIB"

TF="$TMP/repo/tests/test-foo.sh"

# --- Determinism -------------------------------------------------------------
h1=$(tc_closure_hash "$TF")
h1b=$(tc_closure_hash "$TF")
assert_eq "$h1" "$h1b" "closure hash is deterministic"
assert_ne "$h1" "" "closure hash is non-empty"

# --- Closure sensitivity: test file ------------------------------------------
printf '#!/usr/bin/env bash\nSCRIPT=./scripts/foo.sh\n"$SCRIPT" --v2\n' > "$TF"
h_testchg=$(tc_closure_hash "$TF")
assert_ne "$h1" "$h_testchg" "changing the TEST file changes the hash"
# restore
printf '#!/usr/bin/env bash\nSCRIPT=./scripts/foo.sh\n"$SCRIPT"\n' > "$TF"
assert_eq "$(tc_closure_hash "$TF")" "$h1" "restoring the test file restores the hash"

# --- Closure sensitivity: referenced script ----------------------------------
printf '#!/usr/bin/env bash\n. "$D/_lib/dep.sh"\necho foo-v2\n' > "$TMP/repo/scripts/foo.sh"
assert_ne "$h1" "$(tc_closure_hash "$TF")" "changing the code-under-test script changes the hash"
printf '#!/usr/bin/env bash\n. "$D/_lib/dep.sh"\necho foo-v1\n' > "$TMP/repo/scripts/foo.sh"

# --- Closure sensitivity: sourced lib (transitive) ---------------------------
printf '#!/usr/bin/env bash\necho dep-v2\n' > "$TMP/repo/scripts/_lib/dep.sh"
assert_ne "$h1" "$(tc_closure_hash "$TF")" "changing a sourced lib changes the hash (transitive dep)"
printf '#!/usr/bin/env bash\necho dep-v1\n' > "$TMP/repo/scripts/_lib/dep.sh"
assert_eq "$(tc_closure_hash "$TF")" "$h1" "restoring the lib restores the hash"

# --- External epoch: plugin pin ----------------------------------------------
cat > "$TMP/lock.yaml" <<'EOF'
pinned_commit:   2222222bbbbbbb00000000000000000000000000
EOF
assert_ne "$h1" "$(tc_closure_hash "$TF")" "changing the plugin PIN changes the hash (external epoch)"
cat > "$TMP/lock.yaml" <<'EOF'
pinned_commit:   1111111aaaaaaa00000000000000000000000000
EOF

# --- active.json is NOT in the closure (pin-only external epoch; it is byte-unstable
#     because standards-sync regenerates it non-deterministically) --------------
printf '{"rules":[{"id":"g-x"}]}\n' > "$TMP/active.json"
assert_eq "$(tc_closure_hash "$TF")" "$h1" "active.json does NOT affect the hash (pin-only epoch, stable)"
printf '{"rules":[]}\n' > "$TMP/active.json"

# --- lookup / store / clear --------------------------------------------------
tc_lookup test-foo "$h1"; assert_eq "$?" "1" "lookup miss before store"
tc_store test-foo "$h1"
tc_lookup test-foo "$h1"; assert_eq "$?" "0" "lookup hit after store (matching hash)"
tc_lookup test-foo "deadbeef"; assert_eq "$?" "1" "lookup miss on hash mismatch (closure changed)"
tc_clear
tc_lookup test-foo "$h1"; assert_eq "$?" "1" "lookup miss after clear"

# --- summary -----------------------------------------------------------------
log ""
log "[test-test-cache] $passes passed, $failures failed"
[ "$failures" -eq 0 ] || exit 1
exit 0
