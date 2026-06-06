#!/usr/bin/env bash
# scripts/standards-sync.sh — emit the unified rule registry from the plugin's
# standards pipeline into .harness/rules/active.json so the harness (and the
# agents reading session context) can consume operator-declared standards.
#
# Per TICKET-032 / ADR-0037. Mirrors the plugin-pin sync pattern
# (scripts/sync-plugin.sh): no fabrication, no fork of plugin code; this
# script only invokes the plugin's `rubric/aggregator.sh` and persists the
# output in a known location.
#
# Usage:
#   scripts/standards-sync.sh             # human-readable summary
#   scripts/standards-sync.sh --quiet     # exit code only
#   scripts/standards-sync.sh --check     # verify .harness/rules/active.json is fresh
#
# Exit codes:
#   0  registry written / fresh
#   1  --check found stale registry
#   2  error (plugin cache missing, aggregator failed, write failed)
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies.

set -u

QUIET=0
CHECK=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        --check) CHECK=1 ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'standards-sync.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

PLUGIN_CACHE=".harness/plugin-cache/claude-tdd-pro"
AGGREGATOR="$PLUGIN_CACHE/rubric/aggregator.sh"
RULES_DIR=".harness/rules"
ACTIVE="$RULES_DIR/active.json"

[ -x "$AGGREGATOR" ] || { printf 'standards-sync.sh: aggregator missing: %s (run sync-plugin.sh --ensure)\n' "$AGGREGATOR" >&2; exit 2; }

mkdir -p "$RULES_DIR" || { printf 'standards-sync.sh: cannot create %s\n' "$RULES_DIR" >&2; exit 2; }

# Generate the registry. Set CLAUDE_PLUGIN_ROOT so the aggregator finds its
# generated-code-quality-standards root.
TMP_OUT=$(mktemp -t standards-sync.XXXXXX) || { printf 'mktemp failed\n' >&2; exit 2; }
trap 'rm -f -- "$TMP_OUT"' EXIT INT TERM

if ! CLAUDE_PLUGIN_ROOT="$PLUGIN_CACHE" bash "$AGGREGATOR" --format json > "$TMP_OUT" 2>/dev/null; then
    printf 'standards-sync.sh: aggregator failed\n' >&2
    exit 2
fi

if [ "$CHECK" -eq 1 ]; then
    if [ ! -f "$ACTIVE" ]; then
        emit "[standards-sync] CHECK FAILED — $ACTIVE missing. Run scripts/standards-sync.sh."
        exit 1
    fi
    # Compare ignoring the aggregated_at timestamp (which changes per run).
    sed -E 's/"aggregated_at":"[^"]*"/"aggregated_at":""/' "$TMP_OUT" > "$TMP_OUT.norm"
    sed -E 's/"aggregated_at":"[^"]*"/"aggregated_at":""/' "$ACTIVE" > "$TMP_OUT.cur"
    if ! diff -q "$TMP_OUT.norm" "$TMP_OUT.cur" >/dev/null 2>&1; then
        emit "[standards-sync] CHECK FAILED — $ACTIVE is stale. Re-run scripts/standards-sync.sh."
        rm -f "$TMP_OUT.norm" "$TMP_OUT.cur"
        exit 1
    fi
    rm -f "$TMP_OUT.norm" "$TMP_OUT.cur"
    emit "[standards-sync] CHECK OK — $ACTIVE is fresh."
    exit 0
fi

mv "$TMP_OUT" "$ACTIVE" || { printf 'standards-sync.sh: write failed\n' >&2; exit 2; }
trap - EXIT INT TERM

# Extract summary fields for emit (jq-free; bash 3.2 portable).
rule_count=$(grep -oE '"id":"[^"]+"' "$ACTIVE" | wc -l | tr -d ' ')
namespaces=$(grep -oE '"namespaces_seen":\[[^]]*\]' "$ACTIVE" | head -1 | sed 's/.*\[//;s/\].*//;s/"//g')

emit "[standards-sync] wrote $ACTIVE"
emit "  rules:      $rule_count"
emit "  namespaces: $namespaces"
emit "  source:     $PLUGIN_CACHE/generated-code-quality-standards/"

exit 0
