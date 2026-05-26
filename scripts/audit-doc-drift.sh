#!/usr/bin/env bash
# scripts/audit-doc-drift.sh — pre-commit doc-vs-implementation drift audit
#
# Born of TICKET-006.b after the TICKET-006.a audit found 6 P0/P1 items where
# operator-facing docs (README, --help text, runbooks, stub files) lagged behind
# the implementation across TICKETS 004–006. The harness's value is production-
# grade trust (D-12); a harness whose own docs lie about its own interface is not
# production-grade. This script is the mechanical guard against that class of
# drift; the procedural guard is the §4 checklist item added in TICKET-006.b.
#
# Patterns caught:
#   F-1  "stub — filled in by TICKET-NNN" markers where TICKET-NNN is DONE in TICKETS.md
#   F-2  "No code yet" / "Design-only" strings in README.md
#   F-3  "lands in TICKET-NNN" / "will land in TICKET-NNN" future-tense for DONE tickets
#   F-4  scripts/sync-plugin.sh case-arm flags vs --help output parity
#   F-5  .cursor/rules/*.mdc files differ from scripts/export-cursor-rules.sh
#        output (generator-output-only invariant per ADR-0014 / TICKET-013)
#   F-6  .harness/audit/*.manifest.json files invalid per ADR-0018 v1 schema
#        (delegated to scripts/audit-manifest.sh per TICKET-010.b / ADR-0020)
#
# Usage:
#   scripts/audit-doc-drift.sh                    # exit 0 clean / 1 with findings
#   scripts/audit-doc-drift.sh --quiet            # suppress per-finding output
#
# This is NOT wired to the SessionStart hook (would bloat startup). Author runs
# it pre-commit. The procedural checklist enforces the run.
#
# Portability target: bash 3.2 + BSD coreutils (per C-23, validated against
# tdd-pro-bash32-portability's 9 gotchas + bonus rule).

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help)
            sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//' >&2
            exit 0
            ;;
        *)
            printf 'audit-doc-drift.sh: unknown arg: %s\n' "$arg" >&2
            exit 2
            ;;
    esac
done

[[ -f TICKETS.md ]] || { printf 'audit-doc-drift.sh: TICKETS.md not found (run from repo root)\n' >&2; exit 2; }

FINDINGS_FILE="$(mktemp)"
trap 'rm -f -- "$FINDINGS_FILE"' EXIT INT TERM

findings=0
emit() {
    findings=$((findings + 1))
    printf '[doc-drift] %s\n' "$*" >> "$FINDINGS_FILE"
}

# --- DONE-ticket lookup (parses TICKETS.md table) ---
DONE_LIST="$(grep -E '^\| TICKET-' TICKETS.md | grep -E '\*\*DONE' | grep -oE 'TICKET-[0-9a-zA-Z.]+' | sort -u)"

ticket_is_done() {
    printf '%s\n' "$DONE_LIST" | grep -q -x -F -- "$1"
}

# --- Check F-1: stale stub markers ---
while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    file="${match%%:*}"
    rest="${match#*:}"
    lineno="${rest%%:*}"
    content="${rest#*:}"
    ticket="$(printf '%s' "$content" | grep -oE 'TICKET-[0-9a-zA-Z.]+' | head -1)"
    if [[ -n "$ticket" ]] && ticket_is_done "$ticket"; then
        emit "F-1 (stale stub): $file:$lineno declares stub for $ticket which is DONE in TICKETS.md."
    fi
done < <(grep -rnE -- 'stub.*filled in by TICKET-' --include='*.md' . 2>/dev/null \
    | grep -v -- '/.git/' | grep -v -- 'docs/adr/' | grep -v -- 'TICKETS.md' \
    | grep -v -- 'scripts/audit-doc-drift.sh' || true)

# --- Check F-2: "No code yet" / "Design-only" in README ---
if [[ -f README.md ]]; then
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        emit "F-2 (stale framing): README.md:$match"
    done < <(grep -nE -- '(No code yet|Design-only)' README.md 2>/dev/null || true)
fi

# --- Check F-3: future-tense references to DONE tickets ---
while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    file="${match%%:*}"
    rest="${match#*:}"
    lineno="${rest%%:*}"
    content="${rest#*:}"
    ticket="$(printf '%s' "$content" | grep -oE 'TICKET-[0-9a-zA-Z.]+' | head -1)"
    if [[ -n "$ticket" ]] && ticket_is_done "$ticket"; then
        emit "F-3 (future tense for done ticket): $file:$lineno references $ticket as future work."
    fi
done < <(grep -rnE -- '(lands?|will land|will be (defined|wired|added|implemented)) in TICKET-' --include='*.md' . 2>/dev/null \
    | grep -v -- '/.git/' | grep -v -- 'docs/adr/' | grep -v -- 'TICKETS.md' \
    | grep -v -- 'scripts/audit-doc-drift.sh' || true)

# --- Check F-4: sync-plugin.sh mode parity ---
SP="scripts/sync-plugin.sh"
if [[ -f "$SP" ]]; then
    impl_flags="$(awk '/^for arg in "\$@"; do$/,/^done$/' "$SP" \
        | grep -oE -- '--[a-z]+' | sort -u | grep -v -- '--help' || true)"
    help_flags="$(bash "$SP" --help 2>&1 | grep -oE -- '--[a-z]+' | sort -u | grep -v -- '--help' || true)"

    missing_from_help="$(comm -23 <(printf '%s\n' "$impl_flags") <(printf '%s\n' "$help_flags") 2>/dev/null || true)"
    missing_from_impl="$(comm -13 <(printf '%s\n' "$impl_flags") <(printf '%s\n' "$help_flags") 2>/dev/null || true)"

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        emit "F-4 (impl/help mismatch): $SP implements $f but --help does not document it."
    done <<< "$missing_from_help"

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        emit "F-4 (help/impl mismatch): $SP --help documents $f but no case arm implements it."
    done <<< "$missing_from_impl"
fi

# --- Check F-5: .cursor/rules/*.mdc generator-output-only invariant ---
#
# .cursor/rules/*.mdc files are generator output from scripts/export-cursor-rules.sh
# (ADR-0014). Hand-edits are forbidden because the next sync-plugin.sh --ensure
# would clobber them. F-5 catches hand-edits or stale outputs by re-running the
# generator in --check mode (writes to a temp dir, diffs against on-disk).
ECR="scripts/export-cursor-rules.sh"
if [[ -x "$ECR" ]]; then
    if ! "$ECR" --check --quiet >/dev/null 2>&1; then
        # Re-run with output captured to surface the specific drift file(s).
        ecr_out="$("$ECR" --check 2>&1 || true)"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            case "$line" in
                *DRIFT:*|*MISSING*)
                    emit "F-5 (cursor-rules drift): ${line#\[cursor-rules\] }"
                    ;;
            esac
        done <<< "$ecr_out"
    fi
fi

# --- Check F-6: manifest schema validity per ADR-0018 / ADR-0020 ---
#
# .harness/audit/*.manifest.json files must validate against the v1 schema
# documented in docs/provenance-bridging-design.md §3. Delegated to
# scripts/audit-manifest.sh which uses node for JSON parsing + structural
# checks. Defensive: if audit-manifest.sh is missing, this F-pattern is
# silently skipped (matches the F-5 defensive pattern).
AM="scripts/audit-manifest.sh"
if [[ -x "$AM" ]]; then
    if ! am_out="$("$AM" --quiet 2>&1)"; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            case "$line" in
                \[manifest-audit\]\ * )
                    emit "F-6 (manifest schema): ${line#\[manifest-audit\] }"
                    ;;
            esac
        done <<< "$am_out"
    fi
fi

# --- Report ---
if [[ $findings -eq 0 ]]; then
    [[ $QUIET -eq 0 ]] && printf '[doc-drift] OK — no drift detected.\n'
    exit 0
else
    if [[ $QUIET -eq 0 ]]; then
        cat -- "$FINDINGS_FILE"
        printf '[doc-drift] %d finding(s). See above.\n' "$findings"
    fi
    exit 1
fi
