#!/usr/bin/env bash
# tests/test-all.sh — run every tests/test-*.sh; exit non-zero on any failure.
# Provides single-command coverage verification for CI + pre-commit + ADR-0028 §Verification.
#
# Dependency-closure caching (TICKET-099 / ADR-0073): a suite that PASSED and whose
# closure (test file + code-under-test + sourced libs + plugin pin + active.json) is
# unchanged is served from cache instead of re-run. Only passing results are cached;
# a failing suite always re-runs until it passes. See scripts/_lib/test-cache.sh.
#
# Usage:
#   tests/test-all.sh              # verbose; cached suites shown as CACHED
#   tests/test-all.sh --quiet      # one line per suite (PASS/CACHED/FAIL)
#   tests/test-all.sh --no-cache   # ignore + do not update the cache (full run; CI-safe)
#   tests/test-all.sh --clear-cache# wipe the cache, then run everything fresh

set -u
QUIET=0
CACHE=1
CLEAR=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        --no-cache) CACHE=0 ;;
        --clear-cache) CLEAR=1 ;;
    esac
done

# Source the cache library (functions only; safe to source even when --no-cache).
_TA_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../scripts" && pwd)
# shellcheck disable=SC1090
. "$_TA_DIR/_lib/test-cache.sh"
[ "$CLEAR" -eq 1 ] && tc_clear

passed_suites=0; failed_suites=0; cached_suites=0
failed_suite_names=""

for t in tests/test-*.sh tests/integration/test-*.sh; do
    # Don't recurse into self
    [ "$t" = "tests/test-all.sh" ] && continue
    # Skip an unmatched glob (e.g. no integration suites present yet).
    [ -e "$t" ] || continue
    [ -x "$t" ] || continue

    suite_name=$(basename "$t" .sh)

    # Cache fast path: a prior PASS with an unchanged closure is not re-run.
    closure=""
    if [ "$CACHE" -eq 1 ]; then
        closure=$(tc_closure_hash "$t")
        if tc_lookup "$suite_name" "$closure"; then
            passed_suites=$((passed_suites + 1))
            cached_suites=$((cached_suites + 1))
            if [ "$QUIET" -eq 1 ]; then printf '  CACHED %s\n' "$suite_name"
            else printf '\n=== %s === (CACHED — closure unchanged, prior PASS)\n' "$suite_name"; fi
            continue
        fi
    fi

    if [ "$QUIET" -eq 1 ]; then
        output=$("$t" 2>&1) ; exit_code=$?
    else
        printf '\n=== %s ===\n' "$suite_name"
        "$t" 2>&1 ; exit_code=$?
    fi

    if [ "$exit_code" -eq 0 ]; then
        passed_suites=$((passed_suites + 1))
        # Cache the passing result against its closure hash.
        [ "$CACHE" -eq 1 ] && [ -n "$closure" ] && tc_store "$suite_name" "$closure"
        [ "$QUIET" -eq 1 ] && printf '  PASS  %s\n' "$suite_name"
    else
        failed_suites=$((failed_suites + 1))
        failed_suite_names="$failed_suite_names $suite_name"
        # Never cache a failure; drop any stale entry so it keeps re-running.
        [ "$CACHE" -eq 1 ] && rm -f "$(tc_cache_dir)/$suite_name.hash" 2>/dev/null
        [ "$QUIET" -eq 1 ] && printf '  FAIL  %s (exit=%d)\n' "$suite_name" "$exit_code"
        [ "$QUIET" -eq 1 ] && printf '%s\n' "$output"
    fi
done

total_suites=$((passed_suites + failed_suites))
if [ "$cached_suites" -gt 0 ]; then
    printf '\n[test-all] %d/%d suites passed (%d served from cache).\n' "$passed_suites" "$total_suites" "$cached_suites"
else
    printf '\n[test-all] %d/%d suites passed.\n' "$passed_suites" "$total_suites"
fi
if [ "$failed_suites" -gt 0 ]; then
    printf '[test-all] FAILED: %s\n' "$failed_suite_names"
    exit 1
fi
exit 0
