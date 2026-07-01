#!/usr/bin/env bash
# tests/test-audit-config-surface.sh — unit tests for scripts/audit-config-surface.sh
# (CL-H / TICKET-105, ADR-0078). Hermetic: ACS_CONFIG_SYNC points at a stub config-sync
# so the completeness verdict is deterministic and no real plugin cache / Ruby is required.
# Exit: 0 all pass / 1 any fail / 2 harness error.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-config-surface] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-config-surface.sh
TMP=$(mktemp -d -t acs-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
CS="$TMP/config-sync.sh"
run() { ACS_CONFIG_SYNC="$CS" "$SCRIPT" --quiet >/dev/null 2>&1; }

# Test 1/2: --help → 0 ; unknown flag → 2
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: config-sync absent → vacuous (0)
ACS_CONFIG_SYNC="$TMP/nope.sh" "$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "config-sync absent → vacuous (0)"

# Test 4: needs_mapping=0 → green (0)
printf '#!/usr/bin/env bash\necho "config-sync rules=10 materialized=10 needs_mapping=0" >&2\nexit 0\n' > "$CS"
run; assert_eq "$?" "0" "needs_mapping=0 → green (0)"

# Test 5: needs_mapping>0 → red (1)
printf '#!/usr/bin/env bash\necho "config-sync rule=g-x tools=1 options=0 needs_mapping=1" >&2\necho "config-sync rules=10 materialized=9 needs_mapping=1" >&2\nexit 1\n' > "$CS"
run; assert_eq "$?" "1" "needs_mapping>0 → red (1)"

# Test 6: no parseable summary (Ruby missing) → vacuous (0)
printf '#!/usr/bin/env bash\necho "ruby: command not found" >&2\nexit 1\n' > "$CS"
run; assert_eq "$?" "0" "no summary (Ruby missing) → vacuous (0)"

# Test 7: multi-digit needs_mapping parsed correctly → red (1)
printf '#!/usr/bin/env bash\necho "config-sync rules=120 materialized=105 needs_mapping=15" >&2\nexit 1\n' > "$CS"
run; assert_eq "$?" "1" "needs_mapping=15 (multi-digit) → red (1)"

total=$((passes + failures))
log ""
log "[test-audit-config-surface] $passes/$total passed"
[ "$failures" -eq 0 ] || exit 1
exit 0
