#!/usr/bin/env bash
# scripts/_lib/epoch-gate.sh — shared epoch-aware-enforcement library (ADR-0071)
#
# The consumer-side dual of upstream proposal P-9 ("schema-additive with epoch +
# default"). When a CTP pin bump introduces new rules/floors, harness audits that
# derive requirements from `active.json` (or from an evolving cross-ref/registry
# graph) would otherwise RETROACTIVELY flag legacy tickets/data that predate the
# new requirement — the 205 / 57 / 5 retro-violation cascade documented in
# ADR-0070 "Known follow-up" and diagnosed in P-9.
#
# This library centralizes the two grandfathering mechanisms that fix that:
#
#   1. Pin-keyed baselines (generalizes the ADR-0032 approval-testing pattern).
#      An audit's accepted-findings snapshot is keyed to the pin it was taken at:
#      tests/<audit>-baseline.<pin>.txt. Re-baselining is an explicit pin-bump
#      step (see docs/plugin-sync.md), NOT a silent per-run rewrite. A legacy
#      un-keyed tests/<audit>-baseline.txt is honored as a fallback so this
#      library is a no-behavior-change wiring until the ADR-0072 bump re-keys.
#
#   2. Epoch-marker gating (generalizes W-A's `applies_to_floor_version >= 2`
#      opt-in from audit-applicable-rules.sh floor 4). A per-artifact marker lets
#      going-forward tickets opt into a new floor while legacy artifacts (no
#      marker) are grandfathered — no rewrites of shipped handoff state.
#
# This file is SOURCED, never executed. It defines functions only; it must be
# side-effect-free at source time (no output, no `set -e`/`set -u` mutation of
# the caller's shell — the caller owns its own flags). Bash 3.2 + BSD-tool
# portable per the tdd-pro-bash32-portability checklist.
#
# Public API (all echo to stdout / signal via exit-code as noted):
#   epoch_current_pin                 -> short (7-char) pinned_commit, or "unpinned"
#   epoch_baseline_path <audit>       -> tests/<audit>-baseline.<pin>.txt  (the pin-keyed path)
#   epoch_resolve_baseline <audit>    -> path of the baseline to USE (pin-keyed, else legacy flat), or empty
#   epoch_filter_new <baseline> <cur> -> NEW findings = current - baseline (sorted-set diff), to stdout
#   epoch_req_gated <req.json>        -> exit 0 if req opts into the current epoch's floors, else 1
#   epoch_note <audit> <context>      -> emit a uniform one-line epoch banner (for wired-but-no-op audits)
#
# ADR: docs/adr/0071-epoch-aware-enforcement.md   Proposal: docs/upstream-ctp-proposals.md §P-9

# Resolve the repo root relative to this library file so callers can source it
# from any cwd (CLAUDE_PLUGIN_ROOT-vs-cwd gotcha #10 in the portability skill).
_epoch_lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_epoch_repo_root=$(cd "$_epoch_lib_dir/../.." && pwd)

# Lockfile that carries the pin (source-of-truth per R-2 / ADR-0001). Overridable
# via EPOCH_LOCKFILE for hermetic fixture tests.
: "${EPOCH_LOCKFILE:=$_epoch_repo_root/docs/claude-tdd-pro.lock.yaml}"
# Directory holding baseline snapshots. Overridable via EPOCH_BASELINE_DIR for tests.
: "${EPOCH_BASELINE_DIR:=$_epoch_repo_root/tests}"

# epoch_current_pin — echo the current pin's short hash (first 7 chars), or
# "unpinned" when the lockfile is absent/malformed. The pin IS the epoch.
epoch_current_pin() {
    local full=""
    if [ -f "$EPOCH_LOCKFILE" ]; then
        # `pinned_commit:   <40-hex>` — take the first 40-hex token on that line.
        full=$(grep -E '^[[:space:]]*pinned_commit:' "$EPOCH_LOCKFILE" 2>/dev/null \
            | head -1 \
            | grep -oE '[0-9a-f]{40}' \
            | head -1)
    fi
    if [ -n "$full" ]; then
        printf '%s\n' "$(printf '%s' "$full" | cut -c1-7)"
    else
        printf 'unpinned\n'
    fi
}

# epoch_baseline_path <audit> — the pin-keyed baseline path for an audit.
epoch_baseline_path() {
    local audit="$1"
    printf '%s/%s-baseline.%s.txt\n' "$EPOCH_BASELINE_DIR" "$audit" "$(epoch_current_pin)"
}

# epoch_resolve_baseline <audit> — resolve the baseline file the audit should
# read. Preference order (echoes the first that exists; empty if none):
#   1. pin-keyed  tests/<audit>-baseline.<pin>.txt   (the epoch-aware form)
#   2. legacy flat tests/<audit>-baseline.txt         (pre-ADR-0071 back-compat)
# A note about (2) is emitted to stderr so migration is visible without changing
# the stdout contract callers depend on.
epoch_resolve_baseline() {
    local audit="$1"
    local keyed legacy
    keyed=$(epoch_baseline_path "$audit")
    legacy="$EPOCH_BASELINE_DIR/$audit-baseline.txt"
    if [ -f "$keyed" ]; then
        printf '%s\n' "$keyed"
    elif [ -f "$legacy" ]; then
        printf '  [epoch] %s: using legacy un-keyed baseline (%s); re-key to %s at the next pin bump (ADR-0071).\n' \
            "$audit" "$legacy" "$keyed" >&2
        printf '%s\n' "$legacy"
    else
        printf '\n'
    fi
}

# epoch_filter_new <baseline-file> <current-sorted-file> — echo the NEW findings
# (current minus baseline) as a sorted-set difference. Robust to a missing/empty
# baseline (then every current finding is new). Both inputs are treated as sorted
# line sets; the current file is re-sorted defensively.
epoch_filter_new() {
    local baseline="$1" current="$2"
    local cur_sorted
    cur_sorted=$(mktemp -t epoch-cur.XXXXXX) || return 2
    LC_ALL=C sort -u "$current" > "$cur_sorted" 2>/dev/null
    if [ -n "$baseline" ] && [ -f "$baseline" ]; then
        local base_sorted
        base_sorted=$(mktemp -t epoch-base.XXXXXX) || { rm -f "$cur_sorted"; return 2; }
        LC_ALL=C sort -u "$baseline" > "$base_sorted" 2>/dev/null
        LC_ALL=C comm -23 "$cur_sorted" "$base_sorted" 2>/dev/null || true
        rm -f "$base_sorted"
    else
        cat "$cur_sorted"
    fi
    rm -f "$cur_sorted"
}

# epoch_req_gated <req.json> — exit 0 when the request opts into the current
# epoch's floors (`applies_to_floor_version >= 2`), else exit 1 (grandfathered).
# Generalizes the W-A opt-in so any shell-level audit can gate the same way.
# Uses node when available for robust JSON; falls back to a conservative grep.
epoch_req_gated() {
    local req="$1"
    [ -f "$req" ] || return 1
    if command -v node >/dev/null 2>&1; then
        EPOCH_REQ="$req" node -e '
const fs=require("fs");
let r; try { r=JSON.parse(fs.readFileSync(process.env.EPOCH_REQ,"utf8")); } catch(e){ process.exit(1); }
const v=(typeof r.applies_to_floor_version==="number")?r.applies_to_floor_version:1;
process.exit(v>=2?0:1);
' 2>/dev/null
        return $?
    fi
    # grep fallback: match `"applies_to_floor_version": <n>` with n>=2.
    if grep -oE '"applies_to_floor_version"[[:space:]]*:[[:space:]]*[0-9]+' "$req" 2>/dev/null \
        | grep -oE '[0-9]+$' \
        | grep -qE '^[2-9]|^[0-9]{2,}$'; then
        return 0
    fi
    return 1
}

# epoch_note <audit> <context> — uniform one-line banner. Used by audits that are
# wired for uniformity (operator directive: all 17) but derive no requirements
# from the evolving registry, so have nothing epoch-sensitive to grandfather.
epoch_note() {
    local audit="$1" context="$2"
    printf '  [epoch] %s: pin=%s — %s\n' "$audit" "$(epoch_current_pin)" "$context"
}
