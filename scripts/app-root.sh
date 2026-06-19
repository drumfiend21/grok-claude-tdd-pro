#!/usr/bin/env bash
# scripts/app-root.sh — resolve + validate the EXTERNAL application working tree
# ("app_root") that GCTP builds for the user and must enforce CTP standards on.
#
# Per TICKET-070 / ADR-0059 ("Fix D" from the GCTP O'Reilly-kata feedback loop;
# PROPOSAL-002). Today the harness commands operate on `.harness/*`; there was no
# first-class notion that the user's product lives in a separate (often gitignored)
# tree that must be enforced. This resolver is that notion: the single place
# `/consult` `/decompose` `/inner-loop` `/audit` + the Fix-B/C enforcement scripts
# learn where the app is, with a HARD GUARD against the vacuous-green failure mode.
#
# The app_root is read from `.harness/app.json` (operator-local; gitignored), shape:
#   { "schema_version": "1", "app_root": "<path>", "description": "..." }
# A relative app_root resolves against the repo root (CLAUDE_PROJECT_DIR or cwd).
#
# HARD GUARD (the anti-false-green invariant): a configured app_root that is MISSING
# or contains ZERO regular files is exit 2 — REFUSED — because "nothing to enforce"
# must never silently pass as "enforced clean". (Mirrors enforce.sh not_applicable vs
# the gate: an empty tree is not a green, it is a configuration error.)
#
# Usage:
#   scripts/app-root.sh                  # resolve from config; print abs path; exit 0/1/2
#   scripts/app-root.sh --quiet          # same, no stdout path (exit code only)
#   scripts/app-root.sh --validate <dir> # validate an explicit dir (skip config); exit 0/2
#
# Env overrides (testability):
#   AR_CONFIG   default .harness/app.json
#   AR_ROOT     default ${CLAUDE_PROJECT_DIR:-$(pwd)}  (base for relative app_root)
#
# Exit codes:
#   0  app_root configured + exists + non-empty  (abs path printed to stdout)
#   1  not configured (no app.json, or no app_root key) — no external app target yet
#   2  configured but the tree is MISSING or EMPTY → refuse (would be vacuous green)
#      (also: bad invocation)
#
# Portability: bash 3.2 + BSD coreutils. JSON parsed with node when present; falls
# back to a bounded grep parse.

set -u

QUIET=0
MODE="resolve"
EXPLICIT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --quiet)    QUIET=1 ;;
        --validate) MODE="validate"; EXPLICIT="${2-}"; shift ;;
        -h|--help)  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'app-root.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

emit()  { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
err()   { printf '%s\n' "$*" >&2; }

AR_CONFIG="${AR_CONFIG:-.harness/app.json}"
BASE="${AR_ROOT:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

# A tree is "non-empty" iff it holds >=1 regular file outside .git (git-agnostic;
# works for non-git app folders too — a requirement of the enforce.sh contract).
tree_has_files() {
    [ -d "$1" ] || return 1
    find "$1" -type f -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q .
}

# Validate a resolved directory against the hard guard. Echoes nothing; sets exit.
validate_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        err "app-root.sh: app_root does not exist: $dir (refusing — an absent tree is not a green)"
        return 2
    fi
    if ! tree_has_files "$dir"; then
        err "app-root.sh: app_root is empty (no regular files): $dir (refusing — vacuous green guard)"
        return 2
    fi
    return 0
}

# --- explicit-validate mode -------------------------------------------------
if [ "$MODE" = "validate" ]; then
    [ -n "$EXPLICIT" ] || { err "app-root.sh: --validate requires a <dir>"; exit 2; }
    case "$EXPLICIT" in /*) abs="$EXPLICIT" ;; *) abs="$BASE/$EXPLICIT" ;; esac
    validate_dir "$abs"; rc=$?
    [ "$rc" -eq 0 ] && emit "$abs"
    exit "$rc"
fi

# --- resolve-from-config mode ----------------------------------------------
if [ ! -f "$AR_CONFIG" ]; then
    err "app-root.sh: no app config at $AR_CONFIG — external app target not configured."
    err "  create it: { \"schema_version\": \"1\", \"app_root\": \"<path-to-your-app>\" }"
    exit 1
fi

# Extract the app_root value.
APP_ROOT_VAL=""
if command -v node >/dev/null 2>&1; then
    APP_ROOT_VAL=$(AR_CFG="$AR_CONFIG" node -e '
const fs=require("fs");
let c;
try { c=JSON.parse(fs.readFileSync(process.env.AR_CFG,"utf8")); }
catch(e){ console.log("PARSE_ERR|"+e.message); process.exit(0); }
console.log("OK|"+(typeof c.app_root==="string"?c.app_root:""));
' 2>&1)
else
    v=$(grep -o '"app_root"[[:space:]]*:[[:space:]]*"[^"]*"' "$AR_CONFIG" 2>/dev/null | head -1 | sed 's/.*"app_root"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    APP_ROOT_VAL="OK|$v"
fi

case "$APP_ROOT_VAL" in
    PARSE_ERR\|*)
        err "app-root.sh: $AR_CONFIG is not valid JSON (${APP_ROOT_VAL#PARSE_ERR|})"; exit 2 ;;
esac
RAW="${APP_ROOT_VAL#OK|}"
if [ -z "$RAW" ]; then
    err "app-root.sh: $AR_CONFIG has no \"app_root\" key — external app target not configured."
    exit 1
fi

case "$RAW" in /*) ABS="$RAW" ;; *) ABS="$BASE/$RAW" ;; esac
validate_dir "$ABS"; rc=$?
[ "$rc" -eq 0 ] && emit "$ABS"
exit "$rc"
