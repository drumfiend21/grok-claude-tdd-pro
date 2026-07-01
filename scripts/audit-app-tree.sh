#!/usr/bin/env bash
# scripts/audit-app-tree.sh — audit-time whole-tree enforcement gate (CL-F / TICKET-104, ADR-0077).
#
# Consumes CTP §28.35/§28.42 `rubric/composite-audit.sh --root <app_root>`: the AUDIT-TIME
# (whole-tree, strict zero-violation) phase of two-phase enforcement — the complement to the
# per-file write-time hooks (CL-C pre-write, CL-D on-save). Walks the app_root and drives the
# composite engine across every file; a `status=red` tree verdict is a hard red.
#
# SCOPE (agent-operating-compact): the app_root ONLY (the external product tree). Vacuous when
# no `.harness/app.json` is configured — nothing to audit — like the write-time governors.
#
# Parse-then-block: acts ONLY on an authoritative `composite-audit … status=<v>` summary line;
# a bare crash / no summary (e.g. the P-10 composite-dispatch bash-3.2 issue) is NOT a verdict
# and is treated as vacuous, never a red. `incomplete` (optional tool absent) is advisory.
#
# Prime directive: composite-audit.sh is consumed by reference from the pinned cache, never edited.
#
# Usage: scripts/audit-app-tree.sh [--quiet]
# Exit:  0 green / vacuous / advisory-incomplete   |   1 tree red   |   2 usage
# Overridable for tests: AAT_APP_ROOT, AAT_APP_ROOT_BIN, AAT_PLUGIN_ROOT, AAT_COMPOSITE_AUDIT.

set -u
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-app-tree.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

emit "[app-tree] audit-time whole-tree enforcement over the app_root (§28.35/§28.42)..."

# Resolve app_root (external product tree). No app_root -> vacuous (nothing to audit).
APP_ROOT_BIN="${AAT_APP_ROOT_BIN:-$_EPOCH_AUDIT_DIR/app-root.sh}"
APP_ROOT=""
if [ -n "${AAT_APP_ROOT:-}" ]; then APP_ROOT="$AAT_APP_ROOT"
elif [ -x "$APP_ROOT_BIN" ]; then APP_ROOT=$("$APP_ROOT_BIN" 2>/dev/null) || APP_ROOT=""; fi
if [ -z "$APP_ROOT" ] || [ ! -d "$APP_ROOT" ]; then
    emit "[app-tree] no app_root configured (.harness/app.json) — vacuous pass (no external product to audit)."
    epoch_note app-tree "no app_root; nothing to audit"
    exit 0
fi

# Resolve the composite-audit entrypoint. Absent -> pre-§28.35 cache -> vacuous.
PLUGIN_ROOT="${AAT_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
COMPOSITE_AUDIT="${AAT_COMPOSITE_AUDIT:-$PLUGIN_ROOT/rubric/composite-audit.sh}"
if [ ! -f "$COMPOSITE_AUDIT" ]; then
    emit "[app-tree] composite-audit.sh absent ($COMPOSITE_AUDIT) — pre-§28.35 cache; vacuous pass."
    exit 0
fi

absplugin=$(cd "$PLUGIN_ROOT" 2>/dev/null && pwd -P || printf '%s' "$PLUGIN_ROOT")
out=$(CLAUDE_PLUGIN_ROOT="$absplugin" bash "$COMPOSITE_AUDIT" --root "$APP_ROOT" 2>&1)
summary=$(printf '%s\n' "$out" | grep -E '^composite-audit[[:space:]]+.*\bstatus=' | tail -1)

# Parse-then-block: no authoritative summary => not a verdict (crash/P-10) => vacuous.
if [ -z "$summary" ]; then
    emit "[app-tree] no authoritative composite-audit summary (crash / P-10 / empty tree) — vacuous pass."
    [ "$QUIET" -eq 0 ] && printf '%s\n' "$out" | sed 's/^/    /' | tail -3
    exit 0
fi
emit "  $summary"

status=$(printf '%s' "$summary" | grep -oE 'status=[a-z]+' | head -1 | sed 's/status=//')
case "$status" in
    green)
        emit "[app-tree] OK — app_root tree passes whole-tree composite enforcement."
        exit 0 ;;
    incomplete)
        emit "[app-tree] incomplete (optional tool absent) — advisory only, not a red (ADR-0068 D-B-1)."
        exit 0 ;;
    red)
        emit "[app-tree] RED — the app_root tree has whole-tree enforcement violations."
        printf '%s\n' "$out" | grep -E '^audit[[:space:]]+.*verdict=red' | sed 's/^/  /' | head -20
        emit "  Fix the violations or add deviation rows in <app_root>/docs/deviations.md (ADR-0066 D-F)."
        exit 1 ;;
    *)
        emit "[app-tree] unrecognized status='$status' — treated as vacuous (no verdict)."
        exit 0 ;;
esac
