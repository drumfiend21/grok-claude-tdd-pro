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

# --- P-15 §31/S-63 (TICKET-122): _project/ preservation across re-clone ---
# Rationale: CTP shipped per-project acquired rules at the nested path
# `generated-code-quality-standards/_project/<project-id>/<ns>/*.yaml` inside
# the plugin root (CTP answer #3 in the convergence exchange). Convergence
# doc B2 mandates preservation across the naive rm-rf that --ensure does on
# a forced re-clone. This test creates a stub _project/ tree AT THE SHIPPED
# PATH, forces a re-clone by wiping .git, then asserts the tree survives.
# Defensive path (no-op when _project/ absent) is asserted separately.
#
# Test 8: baseline — no _project/ at the shipped nested path.
CACHE_PATH=.harness/plugin-cache/claude-tdd-pro
PROJ_PATH="$CACHE_PATH/generated-code-quality-standards/_project"
[ ! -d "$PROJ_PATH" ]
assert_eq "$?" "0" "generated-code-quality-standards/_project/ absent at pin (baseline no-op path)"

# Test 9: stub _project/ tree at the shipped nested path survives --ensure re-clone.
mkdir -p "$PROJ_PATH/FEATURE-121/vue"
STUB_RULE="$PROJ_PATH/FEATURE-121/vue/vue-composition-api.yaml"
cat > "$STUB_RULE" <<'YAML'
id: vue-composition-api
source_namespace: vue
origin: project
project_id: FEATURE-121
source_url: https://vuejs.org/guide/introduction.html
YAML
STUB_SHA_BEFORE=$(shasum "$STUB_RULE" | awk '{print $1}')
# Force a re-clone by wiping .git so --ensure re-clones from scratch. Backup .git
# to a temp location so we can restore if network fails.
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
        rm -rf "$PROJ_PATH"
    else
        rm -rf "$_GIT_BACKUP"
        assert_eq "$ensure_ec" "0" "--ensure after wiped .git exits 0 (re-clones cleanly)"
        [ -f "$STUB_RULE" ]
        assert_eq "$?" "0" "generated-code-quality-standards/_project/FEATURE-121/vue/vue-composition-api.yaml preserved across re-clone (P-15 §31/S-63 B2 spine)"
        STUB_SHA_AFTER=$(shasum "$STUB_RULE" 2>/dev/null | awk '{print $1}')
        assert_eq "$STUB_SHA_AFTER" "$STUB_SHA_BEFORE" "preserved _project/ rule bytes identical (no silent corruption)"
        # Clean up stub _project/ so it does not persist across test runs.
        rm -rf "$PROJ_PATH"
    fi
else
    log "  (skipped preservation test: cache .git not present — network-dependent path unavailable)"
fi

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-sync-plugin] OK — $passes/$total passed."; exit 0
else log "[test-sync-plugin] FAIL — $failures/$total."; exit 1; fi
