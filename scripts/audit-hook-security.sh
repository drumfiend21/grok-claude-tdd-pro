#!/usr/bin/env bash
# scripts/audit-hook-security.sh — security scan for hooks, skills, scripts, templates
#
# Per Musk #4 (closed in TICKET-029 / ADR-0034): the harness has substantial
# code-execution surface (Claude Code hooks fired on tool use; substrate scripts
# invoked at session start + pre-commit; Grok templates fed to LLM-driven agents).
# This script scans for known-dangerous shell patterns AND hardcoded-secret
# patterns, with a baseline-tolerant exit policy for documented false positives.
#
# Patterns scanned (per ADR-0034 §Decision-2 scope statement):
#   S-1  Unprotected `eval` (command injection risk)
#   S-2  `curl | bash` / `wget | sh` (supply-chain risk in shell scripts)
#   S-3  Recursive force-delete (`rm -rf`) without explicit path quoting
#   S-4  Hardcoded credentials: *_KEY=, *_TOKEN=, *_SECRET=, password=, api_key=
#   S-5  `sudo` invocation (privilege escalation; should not appear in harness substrate)
#   S-6  Unquoted `$@` or `$*` in `eval` / `bash -c` contexts (argument injection)
#
# Scope: .claude/hooks/, scripts/, .claude/skills/*/SKILL.md, .grok/templates/, tests/
#
# Usage:
#   scripts/audit-hook-security.sh           # human-readable findings + summary
#   scripts/audit-hook-security.sh --quiet   # exit code only
#
# Exit codes:
#   0  no findings OR all findings accounted for in baseline
#   1  new findings introduced since baseline (regression)
#   2  error (script invocation problem)
#
# Approval-baseline pattern (per ADR-0032 cross-ref audit precedent):
#   tests/hook-security-baseline.txt records known-accepted patterns (e.g.,
#   eval calls that are intentional + bounded, or pattern strings inside this
#   audit script itself).
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies.

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-hook-security.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

emit "[hook-security-audit] scanning hooks + scripts + skills + templates..."

findings_file=$(mktemp -t hook-sec.XXXXXX) || { printf 'mktemp failed\n' >&2; exit 2; }
trap 'rm -f -- "$findings_file"' EXIT INT TERM

scan_pattern() {
    local pattern_id="$1" pattern="$2" description="$3"
    # rg-equivalent via grep -rEln; restricted to the harness security scope.
    grep -rnE -- "$pattern" \
        .claude/hooks/ scripts/ tests/ \
        .claude/skills/orchestrating-swarms/SKILL.md \
        .grok/templates/ 2>/dev/null \
        | grep -v 'audit-hook-security.sh' \
        | grep -v 'hook-security-baseline.txt' \
        | while IFS= read -r match; do
            # Format: file:line:content
            printf '%s|%s|%s\n' "$pattern_id" "$description" "$match" >> "$findings_file"
        done
}

# S-1: unprotected eval (command injection)
scan_pattern "S-1" '\beval\b' "unprotected eval"

# S-2: curl-piped-to-shell
scan_pattern "S-2" '(curl|wget)[^|]*\|[[:space:]]*(bash|sh)' "curl/wget piped to shell"

# S-3: recursive force-delete (rm -rf without explicit safe path)
scan_pattern "S-3" 'rm[[:space:]]+-[rRf]+f?' "rm -rf usage (verify path is bounded)"

# S-4: hardcoded credentials in code
scan_pattern "S-4a" '[A-Z_]+_KEY[[:space:]]*=[[:space:]]*["\047][^"\047$]+' "hardcoded _KEY assignment"
scan_pattern "S-4b" '[A-Z_]+_TOKEN[[:space:]]*=[[:space:]]*["\047][^"\047$]+' "hardcoded _TOKEN assignment"
scan_pattern "S-4c" '[A-Z_]+_SECRET[[:space:]]*=[[:space:]]*["\047][^"\047$]+' "hardcoded _SECRET assignment"
scan_pattern "S-4d" 'password[[:space:]]*=[[:space:]]*["\047][^"\047$]+' "hardcoded password assignment"
scan_pattern "S-4e" 'api_key[[:space:]]*=[[:space:]]*["\047][^"\047$]+' "hardcoded api_key assignment"

# S-5: sudo in harness substrate
scan_pattern "S-5" '\bsudo\b' "sudo invocation"

# S-6: bash -c with unquoted variable expansion
scan_pattern "S-6" 'bash[[:space:]]+-c[[:space:]]+[^"\047]*\$' "bash -c with unquoted variable"

# --- Compare against baseline ---
BASELINE=tests/hook-security-baseline.txt
total_findings=$(wc -l < "$findings_file" | tr -d ' ')

if [ "$total_findings" -eq 0 ]; then
    emit "[hook-security-audit] OK — no findings in harness substrate."
    [ -s "$BASELINE" ] && emit "  (baseline file $BASELINE has $(wc -l < "$BASELINE" | tr -d ' ') entries; consider archiving)"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    if [ "$QUIET" -eq 0 ]; then
        cat -- "$findings_file" | sed 's/^/  [FINDING] /' | awk -F'|' '{print $0}'
    fi
    emit "[hook-security-audit] $total_findings finding(s); no baseline file present."
    exit 1
fi

# Diff findings against baseline (lines normalize to "S-X|description|file:line:content")
current_sorted=$(mktemp -t hook-sec-cur.XXXXXX) || { printf 'mktemp failed\n' >&2; exit 2; }
sort "$findings_file" > "$current_sorted"
new_findings=$(comm -23 "$current_sorted" "$BASELINE" 2>/dev/null || true)
rm -f "$current_sorted"

if [ -n "$new_findings" ]; then
    new_count=$(printf '%s\n' "$new_findings" | wc -l | tr -d ' ')
    emit "[hook-security-audit] $total_findings finding(s); $new_count new vs baseline."
    emit "[hook-security-audit] NEW security findings (regression):"
    printf '%s\n' "$new_findings" | sed 's/^/  [NEW] /' | awk -F'|' '{print $0}'
    emit "[hook-security-audit] Fix the new finding(s) OR add to tests/hook-security-baseline.txt with security justification."
    exit 1
fi

emit "[hook-security-audit] OK — all $total_findings finding(s) accounted for in baseline."
exit 0
