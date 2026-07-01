#!/usr/bin/env bash
# scripts/_lib/test-cache.sh — dependency-closure test-result caching (TICKET-099).
#
# Operator requirement (2026-06-30): a unit/integration test suite should be cached
# after its first passing run and NOT re-run until the code it tests is updated or
# deleted.
#
# Design — cache-until-closure-changes:
#   A suite's result is keyed by a CLOSURE HASH over everything that can change its
#   verdict, at FILE granularity (a function edit is a file edit — function-level
#   caching is impractical and unnecessary in shell; mirrors CTP §28.53 per-spec
#   dependency-closure hashing). The closure is:
#     1. the test file itself,
#     2. every `scripts/…​.sh` the test references (its code-under-test),
#     3. every `scripts/_lib/*.sh` those scripts source (transitive deps, 1 level),
#     4. the EXTERNAL EPOCH — the plugin pin (`epoch_current_pin`, from the tracked
#        lockfile). This is load-bearing: a suite can flip verdict with unchanged
#        test/script code when the plugin changes (observed this session —
#        test-audit-design-phase-md passed at 230e99d and failed at 4668c2e on the
#        pin bump alone). Folding the pin into the closure means a pin bump
#        invalidates every cache entry, so no stale green survives a plugin change.
#        NOTE: `active.json` is deliberately NOT in the closure — `standards-sync.sh`
#        regenerates it non-deterministically (byte-unstable for the same pin), so it
#        could never be a stable key. The pin captures the plugin version that drives
#        rule content; the residual case (a mid-session standards refresh that changes
#        rules WITHOUT a pin bump) is rare (1d cadence) — use --no-cache / --clear-cache.
#
# SAFETY: only PASSING results are ever cached. A failing suite is never skipped —
# it re-runs every time until it passes. A cache HIT therefore means "this exact
# closure passed before", which is still true if the hash matches.
#
# Sourced, side-effect-free (functions only), bash 3.2 portable. Overridable for
# hermetic tests: TC_CACHE_DIR, TC_REPO_ROOT (+ EPOCH_LOCKFILE via epoch-gate).
#
# API:
#   tc_cache_dir                 -> the cache directory (created on store)
#   tc_closure_hash <test-file>  -> the closure hash for a suite, to stdout
#   tc_lookup <suite> <hash>     -> exit 0 if a cached PASS matches <hash>, else 1
#   tc_store  <suite> <hash>     -> record a passing result for <suite> at <hash>
#   tc_clear                     -> remove all cache entries

_tc_lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Repo root — overridable via TC_REPO_ROOT for hermetic fixture tests.
: "${TC_REPO_ROOT:=$(cd "$_tc_lib_dir/../.." && pwd)}"
# Reuse the epoch library for the pin component (external-epoch, item 4 above).
# shellcheck disable=SC1090
. "$_tc_lib_dir/epoch-gate.sh"

: "${TC_CACHE_DIR:=$TC_REPO_ROOT/.harness/test-cache}"

tc_cache_dir() { printf '%s\n' "$TC_CACHE_DIR"; }

# _tc_closure_files <test-file> — echo (one per line) the file set whose contents
# key the suite: the test file + referenced scripts + their sourced libs. Only
# existing files, de-duplicated.
_tc_closure_files() {
    local test_file="$1"
    [ -f "$test_file" ] || return 0
    local list="$test_file"
    # Scripts the test references (its code-under-test). Conservative path chars.
    local refs script lib
    refs=$(grep -oE 'scripts/[A-Za-z0-9_./-]+\.sh' "$test_file" 2>/dev/null | LC_ALL=C sort -u)
    for script in $refs; do
        [ -f "$TC_REPO_ROOT/$script" ] || continue
        list="$list
$TC_REPO_ROOT/$script"
        # Libs that script sources (transitive, one level).
        for lib in $(grep -oE '_lib/[A-Za-z0-9_-]+\.sh' "$TC_REPO_ROOT/$script" 2>/dev/null | LC_ALL=C sort -u); do
            [ -f "$TC_REPO_ROOT/scripts/$lib" ] && list="$list
$TC_REPO_ROOT/scripts/$lib"
        done
    done
    printf '%s\n' "$list" | LC_ALL=C sort -u
}

# tc_closure_hash <test-file> — sha256 over (sorted closure file contents) + the
# external epoch (the plugin pin). Empty file set (undeterminable) still yields a
# stable hash bound to the test file path + pin.
tc_closure_hash() {
    local test_file="$1"
    local pin f
    pin=$(epoch_current_pin)
    {
        _tc_closure_files "$test_file" | while IFS= read -r f; do
            [ -f "$f" ] && cat "$f"
        done
        printf 'EPOCH|%s|%s' "$pin" "$test_file"
    } | _tc_sha_stream
}

# _tc_sha_stream — sha256 of stdin (shasum on macOS, sha256sum on Linux).
_tc_sha_stream() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
    else sha256sum | awk '{print $1}'; fi
}

# tc_lookup <suite> <hash> — exit 0 iff a cached passing entry matches <hash>.
tc_lookup() {
    local suite="$1" hash="$2" entry
    entry="$TC_CACHE_DIR/$suite.hash"
    [ -f "$entry" ] || return 1
    [ "$(cat "$entry" 2>/dev/null)" = "$hash" ] && return 0
    return 1
}

# tc_store <suite> <hash> — record a PASSING result. (Callers only invoke on pass.)
tc_store() {
    local suite="$1" hash="$2"
    mkdir -p "$TC_CACHE_DIR" 2>/dev/null || return 1
    printf '%s' "$hash" > "$TC_CACHE_DIR/$suite.hash"
}

# tc_clear — drop all cached results (bounded to the cache dir).
tc_clear() {
    [ -d "$TC_CACHE_DIR" ] || return 0
    rm -f "$TC_CACHE_DIR"/*.hash 2>/dev/null
    return 0
}
