#!/usr/bin/env bash
# sync-plugin.sh — claude-tdd-pro plugin sync
#
# Compares the upstream HEAD of the claude-tdd-pro repo against the pin in
# docs/claude-tdd-pro.lock.yaml, and reports drift. Honors the plugin-
# dependency invariant: this repo never edits, vendors, or forks the upstream.
#
# Usage:
#   scripts/sync-plugin.sh --check         # read-only drift report; default; SessionStart hook calls this first
#   scripts/sync-plugin.sh --ensure        # materialize the pinned commit into .harness/plugin-cache/ (idempotent); SessionStart hook calls this after --check so symlinked skills resolve
#   scripts/sync-plugin.sh --update        # bump the lock-file pin to upstream HEAD (requires an ADR per architecture-principles §15)
#   scripts/sync-plugin.sh --quiet         # suppress non-essential output
#
# Exit codes:
#   0  in sync / cache materialized
#   1  drift detected (warning only — does not fail the session)
#   2  error (network, missing tool, malformed lock file, pinned commit not fetchable)
#
# Portability target: bash 3.2 + BSD coreutils (per C-23).

set -u

LOCK_FILE="docs/claude-tdd-pro.lock.yaml"
CACHE_DIR=".harness/plugin-cache"

MODE="check"
QUIET=0

for arg in "$@"; do
    case "$arg" in
        --check)  MODE="check" ;;
        --update) MODE="update" ;;
        --ensure) MODE="ensure" ;;
        --quiet)  QUIET=1 ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' >&2
            exit 0
            ;;
        *)
            echo "sync-plugin.sh: unknown arg: $arg" >&2
            exit 2
            ;;
    esac
done

log() {
    if [ "$QUIET" -eq 0 ]; then
        printf "%s\n" "$*"
    fi
}

die() {
    echo "sync-plugin.sh: $*" >&2
    exit 2
}

# --- Tool checks (BSD-compatible) ------------------------------------------

command -v git >/dev/null 2>&1 || die "git not found in PATH"
command -v awk >/dev/null 2>&1 || die "awk not found in PATH"

# sha256: prefer sha256sum (Linux), fall back to shasum -a 256 (macOS/BSD)
if command -v sha256sum >/dev/null 2>&1; then
    SHA_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA_CMD="shasum -a 256"
else
    die "neither sha256sum nor shasum found in PATH"
fi

sha256_of() {
    # echo the hash only (strip filename column)
    $SHA_CMD "$1" | awk '{print $1}'
}

# --- Lock-file parsing (flat YAML, no jq/yq dependency) --------------------

[ -f "$LOCK_FILE" ] || die "lock file not found: $LOCK_FILE"

# Extract a scalar value by key from the lock file (first match wins).
# Strips surrounding whitespace and inline comments.
lock_value() {
    awk -v key="$1" '
        $1 == key":" {
            sub(/^[^:]+:[[:space:]]*/, "", $0);
            sub(/[[:space:]]+#.*$/, "", $0);
            gsub(/^"|"$/, "", $0);
            print;
            exit;
        }
    ' "$LOCK_FILE"
}

UPSTREAM_REPO=$(lock_value upstream_repo)
PINNED_BRANCH=$(lock_value pinned_branch)
PINNED_COMMIT=$(lock_value pinned_commit)
PINNED_AT=$(lock_value pinned_at)

[ -n "$UPSTREAM_REPO" ]  || die "lock file missing upstream_repo"
[ -n "$PINNED_BRANCH" ]  || die "lock file missing pinned_branch"
[ -n "$PINNED_COMMIT" ]  || die "lock file missing pinned_commit"

# Build the contract-surface list: pairs of (path, expected_sha256).
# Written to a tmp file so the bash 3.2 main loop can iterate without arrays-of-arrays.
TMP_CSF=$(mktemp -t sync-plugin.csf.XXXXXX) || die "mktemp failed"
trap 'rm -f "$TMP_CSF"' EXIT
awk '
    /^contract_surface_files:/ { in_csf=1; next }
    in_csf && /^[[:space:]]*-[[:space:]]*path:/ {
        sub(/^[^:]+:[[:space:]]*/, "", $0);
        path=$0;
        next;
    }
    in_csf && /^[[:space:]]*sha256:/ {
        sub(/^[^:]+:[[:space:]]*/, "", $0);
        printf "%s\t%s\n", path, $0;
        next;
    }
    in_csf && /^[^[:space:]-]/ { in_csf=0 }
' "$LOCK_FILE" > "$TMP_CSF"

# --- --ensure mode: materialize cache at pinned commit (no drift check) ----
#
# --ensure is the runtime-materialization primitive. The .claude/skills/* symlinks
# resolve into this cache (see .claude/README.md), so the cache MUST exist at the
# pinned commit before claude-tdd-pro skills can load. Idempotent: no-op when
# cache is already at the pinned commit; rebuilds otherwise. Honors R-2
# (by-reference materialization, not vendoring — the cache is gitignored).

if [ "$MODE" = "ensure" ]; then
    PINNED_SHORT_E=$(printf "%s" "$PINNED_COMMIT" | cut -c1-7)
    log "[plugin-ensure] $UPSTREAM_REPO @ $PINNED_SHORT_E"
    mkdir -p "$CACHE_DIR" || die "could not create cache dir: $CACHE_DIR"
    CLONE_DIR_E="$CACHE_DIR/claude-tdd-pro"
    if [ -d "$CLONE_DIR_E/.git" ]; then
        EXISTING_HEAD_E=$(git -C "$CLONE_DIR_E" rev-parse HEAD 2>/dev/null || echo "")
        if [ "$EXISTING_HEAD_E" = "$PINNED_COMMIT" ]; then
            log "  status    : OK (cache already at pinned commit)"
            exit 0
        fi
    fi
    # P-15 Phase 2 (adopted at pin b886658 per ADR-0092): preserve per-project
    # acquired rules across cache rebuild. The store landed at CTP's shipped
    # location `generated-code-quality-standards/_project/<project-id>/<ns>/*.yaml`
    # (relative to the plugin root; CTP answer #3 in the P-15 convergence exchange).
    # These files are CTP-declared contract surface (§31 / S-63) holding rules with
    # `origin: project` scoped to their owning project_id. Gitignored on CTP's side,
    # so NOT part of the pinned commit — a naive rm-rf would wipe operator working
    # state on every pin bump. Convergence doc B2 mandates preservation.
    #
    # Defensive by design: no-op when the store is absent (true pre-acquisition or
    # if the operator has never scoped a consult with --project). Symmetric backup/
    # restore around the rm-rf + clone. TICKET-121.b pre-wired the top-level path;
    # TICKET-122 corrected it to the shipped nested path per CTP answer #3.
    _PROJ_SRC="$CLONE_DIR_E/generated-code-quality-standards/_project"
    _PROJ_BACKUP=""
    if [ -d "$_PROJ_SRC" ]; then
        _PROJ_BACKUP=$(mktemp -d -t sync-plugin-project.XXXXXX) || die "mktemp failed for _project backup"
        cp -R "$_PROJ_SRC" "$_PROJ_BACKUP/_project" 2>/dev/null \
            || { rm -rf "$_PROJ_BACKUP"; die "could not back up generated-code-quality-standards/_project/ for preservation"; }
        log "  preserve  : generated-code-quality-standards/_project/ backed up (P-15 §31/S-63, TICKET-122)"
    fi
    rm -rf "$CLONE_DIR_E"
    git clone --depth=1 --branch "$PINNED_BRANCH" "$UPSTREAM_REPO" "$CLONE_DIR_E" >/dev/null 2>&1 \
        || die "git clone failed for $UPSTREAM_REPO (network policy?)"
    ACTUAL_HEAD_E=$(git -C "$CLONE_DIR_E" rev-parse HEAD)
    if [ "$ACTUAL_HEAD_E" != "$PINNED_COMMIT" ]; then
        log "  status    : WARN — branch HEAD ($(printf "%s" "$ACTUAL_HEAD_E" | cut -c1-7)) differs from pin ($PINNED_SHORT_E); fetching specific commit"
        git -C "$CLONE_DIR_E" fetch --depth=1 origin "$PINNED_COMMIT" >/dev/null 2>&1 \
            && git -C "$CLONE_DIR_E" checkout "$PINNED_COMMIT" >/dev/null 2>&1 \
            || die "could not check out pinned commit $PINNED_COMMIT; bump the pin or unshallow"
    fi
    if [ -n "$_PROJ_BACKUP" ] && [ -d "$_PROJ_BACKUP/_project" ]; then
        # Restore to the same nested path (parent must exist — it always does
        # under a valid CTP checkout because generated-code-quality-standards/
        # is CTP-owned code).
        mkdir -p "$CLONE_DIR_E/generated-code-quality-standards" 2>/dev/null || true
        cp -R "$_PROJ_BACKUP/_project" "$_PROJ_SRC" 2>/dev/null \
            || log "  warn      : generated-code-quality-standards/_project/ restore failed (backup at $_PROJ_BACKUP retained for manual recovery)"
        [ -d "$_PROJ_SRC" ] && rm -rf "$_PROJ_BACKUP" || true
        log "  restore   : generated-code-quality-standards/_project/ preserved across pin bump (P-15 §31/S-63, TICKET-122)"
    fi
    log "  status    : OK (cache materialized at $PINNED_SHORT_E)"

    # Additive step (TICKET-013 / ADR-0014): materialize .cursor/rules/*.mdc
    # from sources-of-truth so Cursor's chat agent has the session-start
    # ritual + skill paths + authority pointers available on session open
    # (Cursor's always-loaded-rule equivalent to Claude Code's push-hook).
    # The generator is idempotent; no-op if outputs already match sources.
    if [ -x "scripts/export-cursor-rules.sh" ]; then
        scripts/export-cursor-rules.sh --quiet || log "  warn      : export-cursor-rules.sh exited non-zero (see scripts/export-cursor-rules.sh output)"
        log "  cursor    : .cursor/rules/*.mdc generated"
    fi

    # Static context injection (per TICKET-035 / ADR-0040; supersedes ADR-0039).
    # Copies docs/PROJECT_CONTEXT_FOR_PLANNER.md from the pinned plugin into the
    # harness's planner-readable context path. Defensive: no-op when the source
    # is absent at the current pin (will activate on the next pin bump that
    # includes the file). Per claude-tdd-pro/docs/adr/0006 (upstream decision).
    PLUGIN_CONTEXT_SRC="$CLONE_DIR_E/docs/PROJECT_CONTEXT_FOR_PLANNER.md"
    HARNESS_CONTEXT_DST=".harness/context/PROJECT_CONTEXT_FOR_PLANNER.md"
    if [ -f "$PLUGIN_CONTEXT_SRC" ]; then
        mkdir -p "$(dirname "$HARNESS_CONTEXT_DST")"
        cp "$PLUGIN_CONTEXT_SRC" "$HARNESS_CONTEXT_DST"
        log "  context   : PROJECT_CONTEXT_FOR_PLANNER.md injected at $HARNESS_CONTEXT_DST"
    else
        log "  context   : PROJECT_CONTEXT_FOR_PLANNER.md not present at this pin (defer to pin bump per ADR-0040)"
    fi

    exit 0
fi

# --- Probe upstream HEAD ---------------------------------------------------

log "[plugin-sync] $UPSTREAM_REPO"

UPSTREAM_HEAD=$(git ls-remote "$UPSTREAM_REPO" "refs/heads/$PINNED_BRANCH" 2>/dev/null | awk '{print $1}')
if [ -z "$UPSTREAM_HEAD" ]; then
    log "  status    : ERROR — could not reach upstream (network policy or repo unavailable)"
    exit 2
fi

PINNED_SHORT=$(printf "%s" "$PINNED_COMMIT"  | cut -c1-7)
UPSTREAM_SHORT=$(printf "%s" "$UPSTREAM_HEAD" | cut -c1-7)

log "  pinned    : $PINNED_SHORT  ($PINNED_AT)"

# If pin == upstream HEAD, no need to clone for hash check.
if [ "$PINNED_COMMIT" = "$UPSTREAM_HEAD" ]; then
    log "  upstream  : $UPSTREAM_SHORT  ($PINNED_BRANCH, in sync)"
    log "  contract  : 0 files drifted (pin matches HEAD)"
    log "  status    : OK"
    exit 0
fi

# Pin differs from HEAD. Need to clone --depth=1 to compute hashes.
mkdir -p "$CACHE_DIR" || die "could not create cache dir: $CACHE_DIR"
CLONE_DIR="$CACHE_DIR/claude-tdd-pro"
rm -rf "$CLONE_DIR"
git clone --depth=1 --branch "$PINNED_BRANCH" "$UPSTREAM_REPO" "$CLONE_DIR" >/dev/null 2>&1 \
    || die "git clone failed for $UPSTREAM_REPO"

AHEAD=$(git -C "$CLONE_DIR" rev-list --count "$PINNED_COMMIT..HEAD" 2>/dev/null || echo "?")

log "  upstream  : $UPSTREAM_SHORT  ($PINNED_BRANCH, $AHEAD commits ahead)"

# Walk contract-surface files, compare hashes.
DRIFTED_COUNT=0
DRIFTED_LIST=""
while IFS="	" read -r CSF_PATH CSF_EXPECTED_SHA; do
    [ -n "$CSF_PATH" ] || continue
    if [ ! -f "$CLONE_DIR/$CSF_PATH" ]; then
        DRIFTED_COUNT=$((DRIFTED_COUNT + 1))
        DRIFTED_LIST="$DRIFTED_LIST
    - $CSF_PATH (MISSING UPSTREAM)"
        continue
    fi
    ACTUAL_SHA=$(sha256_of "$CLONE_DIR/$CSF_PATH")
    if [ "$ACTUAL_SHA" != "$CSF_EXPECTED_SHA" ]; then
        DRIFTED_COUNT=$((DRIFTED_COUNT + 1))
        DRIFTED_LIST="$DRIFTED_LIST
    - $CSF_PATH"
    fi
done < "$TMP_CSF"

# Read-only restore (per TICKET-054 / ADR-0051): the upstream comparison above
# needs the cache cloned at branch HEAD, but a `--check` must NOT leave it there —
# the .claude/skills/* symlinks resolve into this cache at the PINNED commit, so a
# cache parked on branch HEAD silently loads the wrong plugin (and, once upstream
# adds a top-level dir, trips audit-plugin-surface on the next run). Restore the pin
# now that the comparison is done. `--update` intentionally skips this: it leaves the
# cache at the new HEAD, which it is about to make the pin.
if [ "$MODE" = "check" ]; then
    git -C "$CLONE_DIR" fetch --depth=1 origin "$PINNED_COMMIT" >/dev/null 2>&1 \
        && git -C "$CLONE_DIR" checkout "$PINNED_COMMIT" >/dev/null 2>&1 \
        || log "  note      : could not restore cache to pin (offline?); run --ensure"
fi

if [ "$DRIFTED_COUNT" -eq 0 ]; then
    log "  contract  : 0 files drifted (commits moved, contract surface stable)"
    if [ "$MODE" = "update" ]; then
        log "  action    : safe to bump pin (no contract drift) — updating lock file"
        # Inline lock-file update (safe path: contract surface unchanged).
        UPSTREAM_AUTHOR_DATE=$(git -C "$CLONE_DIR" log -1 --format='%cI' HEAD)
        UPSTREAM_MSG=$(git -C "$CLONE_DIR" log -1 --format='%s' HEAD | sed 's/"/\\"/g')
        SED_INPLACE=(-i)
        if sed --version >/dev/null 2>&1; then :; else SED_INPLACE=(-i ''); fi
        sed "${SED_INPLACE[@]}" \
            -e "s|^pinned_commit:.*|pinned_commit:   $UPSTREAM_HEAD|" \
            -e "s|^pinned_at:.*|pinned_at:       $UPSTREAM_AUTHOR_DATE|" \
            -e "s|^pinned_message:.*|pinned_message:  \"$UPSTREAM_MSG\"|" \
            "$LOCK_FILE"
        log "  status    : OK (pin bumped to $UPSTREAM_SHORT)"
        exit 0
    fi
    log "  status    : WARN — pin is behind upstream; safe to bump (run --update)"
    exit 1
fi

log "  contract  : $DRIFTED_COUNT file(s) drifted$DRIFTED_LIST"
if [ "$MODE" = "update" ]; then
    log "  action    : REFUSED — contract-surface drift requires an ADR before bumping"
    log "              See: docs/architecture-principles.md §15, docs/plugin-sync.md"
    exit 1
fi
log "  status    : WARN — contract surface drifted; review upstream before bumping"
log "              Bumping the pin requires an ADR (architecture-principles §15)"
exit 1
