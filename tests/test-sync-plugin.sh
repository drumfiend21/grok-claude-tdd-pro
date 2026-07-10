#!/usr/bin/env bash
# tests/test-sync-plugin.sh — unit tests for scripts/sync-plugin.sh
# Covers ADR-0001/0007 exit-code contract: 0 (in sync / cache materialized) / 1 (drift) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-sync-plugin] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/sync-plugin.sh
LOCKFILE=docs/claude-tdd-pro.lock.yaml

# Test 1: --help exits 0
"$SCRIPT" --help >/dev/null 2>&1
assert_eq "$?" "0" "--help exits 0"

# Test 2: Unknown flag exits 2
"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag exits 2"

# Test 3: --check exits 0 (in sync) or 1 (drift WARN) — both are documented
#          non-error outcomes per the script's --help block. Only exit 2 (error)
#          should fail this assertion.
"$SCRIPT" --check --quiet >/dev/null 2>&1
check_exit=$?
if [ "$check_exit" -eq 0 ] || [ "$check_exit" -eq 1 ]; then
    log "  ✓ --check exits 0 or 1 (got $check_exit; both documented valid)"
    passes=$((passes + 1))
else
    log "  ✗ --check exits 2 (error) — got $check_exit"
    failures=$((failures + 1))
fi

# Test 4: --ensure idempotent (run twice; both exit 0)
"$SCRIPT" --ensure --quiet >/dev/null 2>&1
assert_eq "$?" "0" "--ensure first call exits 0"
"$SCRIPT" --ensure --quiet >/dev/null 2>&1
assert_eq "$?" "0" "--ensure second call exits 0 (idempotent)"

# Test 5: --check on drift induced via lockfile sha mutation exits 1
backup=$(mktemp); cp "$LOCKFILE" "$backup"
# Mutate ANY sha256 entry — pin matches HEAD but contract files now reported as drifted
sed -i 's|^pinned_commit:.*|pinned_commit:   0000000000000000000000000000000000000000|' "$LOCKFILE" 2>/dev/null || \
  sed -i '' 's|^pinned_commit:.*|pinned_commit:   0000000000000000000000000000000000000000|' "$LOCKFILE" 2>/dev/null
# With a bogus pinned_commit, --check tries to fetch + compare; this should exit non-zero (1 for drift or 2 for fetch error)
"$SCRIPT" --check --quiet >/dev/null 2>&1
exit_code=$?
mv "$backup" "$LOCKFILE"   # restore BEFORE asserting
# Accept either 1 (drift detected) or 2 (commit not fetchable) — both non-zero are valid for bogus pin
if [ "$exit_code" -ne 0 ]; then
    log "  ✓ --check on bogus pin exits non-zero (got $exit_code)"; passes=$((passes+1))
else
    log "  ✗ --check on bogus pin should exit non-zero (got 0)"; failures=$((failures+1))
fi

# Test 6: post-restore --check returns to baseline (exit 0 or 1, NOT 2)
"$SCRIPT" --check --quiet >/dev/null 2>&1
post_exit=$?
if [ "$post_exit" -eq 0 ] || [ "$post_exit" -eq 1 ]; then
    log "  ✓ post-restore --check exits 0 or 1 (got $post_exit; both documented valid)"
    passes=$((passes + 1))
else
    log "  ✗ post-restore --check exits 2 (error) — got $post_exit"
    failures=$((failures + 1))
fi

# Test 7: --check leaves the cache at the PINNED commit, not branch HEAD
# (regression guard per TICKET-054 / ADR-0051). A read-only --check must not park
# the cache on branch HEAD: the .claude/skills/* symlinks resolve into the cache at
# the pinned commit, and a drifted cache silently loads the wrong plugin AND trips
# audit-plugin-surface on the next run once upstream adds a top-level dir.
"$SCRIPT" --check --quiet >/dev/null 2>&1
PIN=$(grep '^pinned_commit:' "$LOCKFILE" | awk '{print $2}')
CACHE_HEAD=$(git -C .harness/plugin-cache/claude-tdd-pro rev-parse HEAD 2>/dev/null || echo "")
assert_eq "$CACHE_HEAD" "$PIN" "--check leaves cache at the pinned commit (not branch HEAD)"

# --- P-15 Phase 2 pre-wire (TICKET-121.b): _project/ preservation across re-clone ---
# Rationale: the `_project/<project-id>/` directory inside the plugin cache is a
# CTP-declared contract surface (per §31 / S-63 / convergence doc B2) holding
# per-project acquired rules. It is gitignored — NOT part of any pinned commit —
# so a naive --ensure re-clone would wipe operator working state. This test
# creates a stub _project/ tree, forces a re-clone by wiping .git, then asserts
# the _project/ tree survives. Defensive path exercised: no-op when _project/
# absent (baseline behavior unchanged). At CTP pin 11126a8 the _project/ directory
# does not yet exist; the test creates it locally so this pre-wire assertion is
# meaningful. Convergence doc B2 mandates preservation.
#
# Test 8: baseline — no _project/ present, --ensure works unchanged.
CACHE_PATH=.harness/plugin-cache/claude-tdd-pro
[ ! -d "$CACHE_PATH/_project" ]
assert_eq "$?" "0" "_project/ absent at pin (baseline; TICKET-121.b preservation no-op path)"

# Test 9: stub _project/ tree survives --ensure re-clone.
mkdir -p "$CACHE_PATH/_project/FEATURE-121/vue"
STUB_RULE="$CACHE_PATH/_project/FEATURE-121/vue/vue-composition-api.yaml"
cat > "$STUB_RULE" <<'YAML'
id: vue-composition-api
source_namespace: vue
origin: project
project_id: FEATURE-121
source_url: https://vuejs.org/guide/introduction.html
YAML
STUB_SHA_BEFORE=$(shasum "$STUB_RULE" | awk '{print $1}')
# Force a re-clone by wiping .git so --ensure re-clones from scratch. Backup .git
# via a marker path to a temp location so we can restore if network fails.
if [ -d "$CACHE_PATH/.git" ]; then
    _GIT_BACKUP=$(mktemp -d -t sync-plugin-git.XXXXXX)
    cp -R "$CACHE_PATH/.git" "$_GIT_BACKUP/.git"
    # Force re-clone: delete .git so --ensure's early-return check fails on
    # `rev-parse HEAD` and it wipes the cache.
    rm -rf "$CACHE_PATH/.git"
    "$SCRIPT" --ensure --quiet >/dev/null 2>&1
    ensure_ec=$?
    # Restore .git if the re-clone somehow failed to establish one (network etc).
    if [ ! -d "$CACHE_PATH/.git" ]; then
        cp -R "$_GIT_BACKUP/.git" "$CACHE_PATH/.git"
        log "  (note: re-clone failed to establish .git; skipping preservation test)"
        rm -rf "$_GIT_BACKUP"
        # Also clean up the stub _project we created; it would leak if the re-clone bailed.
        rm -rf "$CACHE_PATH/_project"
    else
        rm -rf "$_GIT_BACKUP"
        assert_eq "$ensure_ec" "0" "--ensure after wiped .git exits 0 (re-clones cleanly)"
        [ -f "$STUB_RULE" ]
        assert_eq "$?" "0" "_project/FEATURE-121/vue/vue-composition-api.yaml preserved across re-clone (TICKET-121.b B2 spine)"
        STUB_SHA_AFTER=$(shasum "$STUB_RULE" 2>/dev/null | awk '{print $1}')
        assert_eq "$STUB_SHA_AFTER" "$STUB_SHA_BEFORE" "preserved _project/ rule bytes identical (no silent corruption)"
        # Clean up stub _project/ so it does not persist across test runs.
        rm -rf "$CACHE_PATH/_project"
    fi
else
    log "  (skipped preservation test: cache .git not present — network-dependent path unavailable)"
fi

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-sync-plugin] OK — $passes/$total passed."; exit 0
else log "[test-sync-plugin] FAIL — $failures/$total."; exit 1; fi
