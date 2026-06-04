#!/usr/bin/env bash
# scripts/audit-cross-references.sh — detect broken cross-references in TIER-1/2 docs
#
# Per Fowler critique #3 closure (TICKET-027 / ADR-0032): walks all
# `path/to/doc.md` references in the harness's TIER-1/TIER-2 authority surface
# + AGENTS.md + CLAUDE.md + QUICKSTART.md + README.md + scripts + skills +
# ADRs, and asserts that every referenced path actually exists on disk.
#
# This is the LIGHTER-WEIGHT version of the proposed TIER-hierarchy refactor:
# instead of restructuring authority, ship a tool that catches the COST of
# coupling (broken cross-references). Per ADR-0032 §Decision-1, the
# canonical-authority refactor remains deferred; this audit closes Fowler #3
# by making the coupling cost detectable, not by removing the coupling.
#
# Reference patterns detected:
#   - Markdown link with path: [...](docs/path.md) [...](../path.md)
#   - Inline-code path: `docs/path.md` `scripts/foo.sh`
#   - Plain backtick relative paths: `path/to/file`
#
# Detection is conservative: only checks .md / .sh / .mdc / .json / .yaml file
# extensions and well-formed paths starting with docs/, scripts/, tests/,
# .claude/, .cursor/, .grok/, .harness/, or being a known root file
# (AGENTS.md, CLAUDE.md, README.md, QUICKSTART.md, TICKETS.md, AUTOMATION_INTEL.md).
#
# Usage:
#   scripts/audit-cross-references.sh           # human-readable findings + summary
#   scripts/audit-cross-references.sh --quiet   # exit code only
#
# Exit codes:
#   0  all detected cross-references resolve to existing files
#   1  one or more broken cross-references detected
#   2  error (script invocation problem)
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies.

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-cross-references.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

emit "[cross-ref-audit] walking TIER-1/TIER-2 surfaces..."

findings_file=$(mktemp -t cross-ref-audit.XXXXXX) || { printf '[cross-ref-audit] mktemp failed\n' >&2; exit 2; }
trap 'rm -f -- "$findings_file"' EXIT INT TERM

findings=0
check_count=0

emit_finding() {
    findings=$((findings + 1))
    printf '  [BROKEN] %s\n' "$*" >> "$findings_file"
}

# --- Walk every TIER-1/TIER-2 markdown document in docs/ + root + ADRs ------
# For each, extract path-like references and check existence.

TARGETS=$(find docs AGENTS.md CLAUDE.md README.md QUICKSTART.md TICKETS.md AUTOMATION_INTEL.md \
                .claude/skills/orchestrating-swarms/SKILL.md \
                tests/README.md \
                -type f \( -name '*.md' \) 2>/dev/null | sort -u)

# Extract candidate references from a single file. Conservative pattern: paths
# starting with one of the known directory prefixes OR root .md/.sh files,
# stripping markdown link syntax and backticks. One path per line.
extract_refs() {
    local f="$1"
    # Markdown link: [...](path)
    grep -oE '\]\([^)]*\)' "$f" 2>/dev/null \
        | sed -E 's|^\]\(([^)#]+)(#[^)]*)?\)$|\1|' \
        | grep -E '^(docs/|scripts/|tests/|\.claude/|\.cursor/|\.grok/|\.harness/|AGENTS\.md|CLAUDE\.md|README\.md|QUICKSTART\.md|TICKETS\.md|AUTOMATION_INTEL\.md)' \
        || true
    # Inline-code paths: `path/to/file.ext`
    grep -oE '`[^`]+\.(md|sh|mdc|json|yaml|yml)`' "$f" 2>/dev/null \
        | sed 's/^`//; s/`$//' \
        | grep -E '^(docs/|scripts/|tests/|\.claude/|\.cursor/|\.grok/|\.harness/|AGENTS\.md|CLAUDE\.md|README\.md|QUICKSTART\.md|TICKETS\.md|AUTOMATION_INTEL\.md)' \
        || true
}

for f in $TARGETS; do
    refs=$(extract_refs "$f" | sort -u)
    for ref in $refs; do
        [ -z "$ref" ] && continue
        # Skip template placeholders + runtime artifacts (would never resolve
        # but are documentation patterns, not broken references):
        # - <id>, <ticket-id>, <name>, <NNN>, <slug>, etc. (angle-bracket placeholders)
        # - {req,res}, {research,decomposition,dispatch} (brace expansion docs)
        # - TICKET-NNN, TICKET-DEMO, 0001-...md (template token placeholders)
        # - .harness/ paths (gitignored runtime artifacts that exist transiently)
        case "$ref" in
            *'<'*|*'{'*|*'...'*) continue ;;
            *TICKET-NNN*|*TICKET-DEMO*) continue ;;
            *NNN*|*'<slug>'*) continue ;;
            .harness/*) continue ;;
        esac
        check_count=$((check_count + 1))
        if [ ! -e "$ref" ]; then
            emit_finding "$f references missing path: $ref"
        fi
    done
done

emit ""
emit "[cross-ref-audit] checked $check_count distinct (file, reference) pairs."

# Compare current findings against baseline (approval-testing pattern per
# ADR-0032). The baseline records known-broken refs that are either historical
# (within already-shipped ADRs per Nygard append-only) or §Alternatives-block
# items naming REJECTED/DEFERRED targets. The audit exits 0 when findings
# match the baseline; 1 only when NEW broken refs are introduced.
BASELINE=tests/cross-references-baseline.txt

if [ "$findings" -eq 0 ]; then
    emit "[cross-ref-audit] OK — no broken cross-references detected."
    [ -s "$BASELINE" ] && emit "  (baseline file $BASELINE has $(wc -l < "$BASELINE" | tr -d ' ') entries; consider archiving)"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    if [ "$QUIET" -eq 0 ]; then cat -- "$findings_file"; fi
    emit "[cross-ref-audit] $findings broken reference(s) found; no baseline file present."
    exit 1
fi

# Compute new findings = (current findings) - (baseline)
current_sorted=$(mktemp -t cross-ref-current.XXXXXX) || { printf '[cross-ref-audit] mktemp failed\n' >&2; exit 2; }
sed 's/^  \[BROKEN\] //' "$findings_file" | sort > "$current_sorted"
new_findings=$(comm -23 "$current_sorted" "$BASELINE" 2>/dev/null || true)
fixed_findings=$(comm -13 "$current_sorted" "$BASELINE" 2>/dev/null || true)
rm -f "$current_sorted"

new_count=0
if [ -n "$new_findings" ]; then
    new_count=$(printf '%s\n' "$new_findings" | wc -l | tr -d ' ')
fi
fixed_count=0
if [ -n "$fixed_findings" ]; then
    fixed_count=$(printf '%s\n' "$fixed_findings" | wc -l | tr -d ' ')
fi

emit ""
emit "[cross-ref-audit] $findings finding(s); $new_count new vs baseline; $fixed_count baseline entries no longer broken."

if [ "$new_count" -gt 0 ]; then
    emit "[cross-ref-audit] NEW broken cross-references (regression):"
    printf '%s\n' "$new_findings" | sed 's/^/  [NEW] /'
    emit "[cross-ref-audit] Fix the new references OR add to tests/cross-references-baseline.txt with justification."
    exit 1
fi

if [ "$fixed_count" -gt 0 ]; then
    emit "[cross-ref-audit] FIXED (baseline can shrink):"
    printf '%s\n' "$fixed_findings" | sed 's/^/  [FIXED] /'
    emit "[cross-ref-audit] Run: scripts/audit-cross-references.sh --update-baseline (or manually edit tests/cross-references-baseline.txt)"
fi

emit "[cross-ref-audit] OK — all $findings finding(s) accounted for in baseline."
exit 0
