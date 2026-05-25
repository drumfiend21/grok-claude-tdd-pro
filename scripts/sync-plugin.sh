#!/usr/bin/env bash
# sync-plugin.sh — claude-tdd-pro plugin sync
#
# Compares the upstream HEAD of the claude-tdd-pro repo against the pin in
# docs/claude-tdd-pro.lock.yaml, and reports drift. Honors the plugin-
# dependency invariant: this repo never edits, vendors, or forks the upstream.
#
# Usage:
#   scripts/sync-plugin.sh --check         # read-only; default; SessionStart hook calls this
#   scripts/sync-plugin.sh --update        # bump the lock-file pin to upstream HEAD
#   scripts/sync-plugin.sh --quiet         # suppress non-essential output
#
# Exit codes:
#   0  in sync
#   1  drift detected (warning only — does not fail the session)
#   2  error (network, missing tool, malformed lock file)
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
        --quiet)  QUIET=1 ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
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
