#!/usr/bin/env bash
# tests/test-all.sh — run every tests/test-*.sh; exit non-zero on any failure.
# Provides single-command coverage verification for CI + pre-commit + ADR-0028 §Verification.
#
# Usage:
#   tests/test-all.sh           # verbose per-suite output
#   tests/test-all.sh --quiet   # one line per suite (PASS/FAIL); useful in CI

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done

passed_suites=0; failed_suites=0; total_assertions=0
failed_suite_names=""

for t in tests/test-*.sh tests/integration/test-*.sh; do
    # Don't recurse into self
    [ "$t" = "tests/test-all.sh" ] && continue
    # Skip an unmatched glob (e.g. no integration suites present yet).
    [ -e "$t" ] || continue
    [ -x "$t" ] || continue

    suite_name=$(basename "$t" .sh)
    if [ "$QUIET" -eq 1 ]; then
        output=$("$t" 2>&1) ; exit_code=$?
    else
        printf '\n=== %s ===\n' "$suite_name"
        "$t" 2>&1 ; exit_code=$?
    fi

    if [ "$exit_code" -eq 0 ]; then
        passed_suites=$((passed_suites + 1))
        [ "$QUIET" -eq 1 ] && printf '  PASS  %s\n' "$suite_name"
    else
        failed_suites=$((failed_suites + 1))
        failed_suite_names="$failed_suite_names $suite_name"
        [ "$QUIET" -eq 1 ] && printf '  FAIL  %s (exit=%d)\n' "$suite_name" "$exit_code"
        [ "$QUIET" -eq 1 ] && printf '%s\n' "$output"
    fi
done

total_suites=$((passed_suites + failed_suites))
printf '\n[test-all] %d/%d suites passed.\n' "$passed_suites" "$total_suites"
if [ "$failed_suites" -gt 0 ]; then
    printf '[test-all] FAILED: %s\n' "$failed_suite_names"
    exit 1
fi
exit 0
