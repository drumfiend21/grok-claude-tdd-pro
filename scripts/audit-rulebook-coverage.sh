#!/usr/bin/env bash
# scripts/audit-rulebook-coverage.sh — count operational citations per rulebook clause
#
# Per Fowler critique #1 (closed in TICKET-026 / ADR-0031): identifies rulebook
# clauses that are documented but never operationally invoked elsewhere in the
# codebase. The audit produces a per-rule citation count across:
#
#   - D-1 .. D-13 (founder-directives.md §3)
#   - R-1 .. R-20 (architecture-principles.md)
#   - G-1 .. G-21 (grok-orchestration-principles.md)
#   - C-1 .. C-24 (claude-tdd-pro-principles.md)
#
# Citations are counted across:
#   - ADRs (docs/adr/*.md)
#   - TIER-2 design docs (docs/*.md excluding the rulebooks themselves)
#   - Scripts (scripts/*.sh, .claude/hooks/*.sh)
#   - Skills (.claude/skills/*/SKILL.md)
#   - Root-level docs (AGENTS.md, CLAUDE.md, QUICKSTART.md, README.md, AUTOMATION_INTEL.md, TICKETS.md)
#   - The rule's OWN source doc is NOT counted; this script itself is NOT counted.
#
# Rules with 0 external citations are candidates for archival or consolidation
# review per ADR-0031 §Decision-3. Actual deletion is deferred to subsequent
# CLs per D-8.
#
# Usage:
#   scripts/audit-rulebook-coverage.sh                    # human-readable summary
#   scripts/audit-rulebook-coverage.sh --detail           # per-rule rows
#   scripts/audit-rulebook-coverage.sh --quiet            # exit code only
#
# Exit codes:
#   0  audit completed; results written to stdout
#   2  error (script invocation problem)
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies.

set -u

DETAIL=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --detail) DETAIL=1 ;;
        --quiet)  QUIET=1 ;;
        -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-rulebook-coverage.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

count_citations() {
    local rule="$1" source_doc="$2"
    grep -rEl --include='*.md' --include='*.sh' -- "\\b${rule}\\b" \
        docs/ scripts/ .claude/ tests/ AGENTS.md CLAUDE.md QUICKSTART.md README.md AUTOMATION_INTEL.md TICKETS.md 2>/dev/null \
        | grep -v "^${source_doc}\$" \
        | grep -v 'audit-rulebook-coverage.sh' \
        | wc -l | tr -d ' '
}

audit_family() {
    local family_label="$1" source_doc="$2" range_start="$3" range_end="$4" prefix="$5"
    emit ""
    emit "${family_label} (source: ${source_doc})"

    local zero_count=0 low_count=0 total_count=0
    local zero_list="" low_list=""
    local i n
    for i in $(seq "$range_start" "$range_end"); do
        local rule="${prefix}-${i}"
        n=$(count_citations "$rule" "$source_doc")
        total_count=$((total_count + n))
        if [ "$n" -eq 0 ]; then
            zero_count=$((zero_count + 1))
            zero_list="${zero_list} ${rule}"
        elif [ "$n" -le 2 ]; then
            low_count=$((low_count + 1))
            low_list="${low_list} ${rule}(${n})"
        fi
        if [ "$DETAIL" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
            printf '  %-6s %3d citations\n' "$rule" "$n"
        fi
    done

    emit "  Total: ${total_count} citations across $((range_end - range_start + 1)) rules"
    emit "  Zero-citation candidates (${zero_count}):${zero_list}"
    emit "  Low-citation candidates 1-2 (${low_count}):${low_list}"
}

emit "[rulebook-coverage] starting per-rule citation audit..."
emit "  Excludes each rule's own source doc + this script."

audit_family "D-rules" "docs/founder-directives.md" 1 13 "D"
audit_family "R-rules" "docs/architecture-principles.md" 1 20 "R"
audit_family "G-rules" "docs/grok-orchestration-principles.md" 1 21 "G"
audit_family "C-rules" "docs/claude-tdd-pro-principles.md" 1 24 "C"

emit ""
emit "[rulebook-coverage] Audit complete. Per ADR-0031, rules with 0 external"
emit "  citations are candidates for archival or consolidation review."
emit "  Actual deletion is deferred to subsequent CLs per D-8."

exit 0
