#!/usr/bin/env bash
# scripts/audit-metrics.sh — DORA-style metrics from the manifest corpus
#
# Per TICKET-030 / ADR-0035: closes Musk Engineering Leadership letter #3
# ("Add Metrics — DORA-style scoreboard with real numbers, not principle
# citations") by aggregating real data from `.harness/audit/*.manifest.json`
# (the per-ticket provenance manifest corpus shipped in TICKETS-010 / ADRs
# 0019-0021). No fabrication: all numbers come from manifest fields
# (`status`, `created_at`, `ticket_id`) cross-referenced with `git log` for
# first-commit-mentioning-ticket timestamps.
#
# Metrics computed (per DORA / Accelerate, Forsgren / Humble / Kim):
#   1. Total ticket count
#   2. Status distribution (green / red / blocked)
#   3. Deployment frequency (green manifests over the observation window)
#   4. Change failure rate (red+blocked / total, as %)
#   5. Lead time for changes (median seconds from first-commit-mentioning-
#      ticket to manifest created_at)
#   6. Time to restore — n/a at v1 (no restore-event corpus; deferred)
#
# Usage:
#   scripts/audit-metrics.sh                # human-readable summary
#   scripts/audit-metrics.sh --json         # JSON output for downstream parse
#   scripts/audit-metrics.sh --quiet        # exit code only
#   scripts/audit-metrics.sh --dir <path>   # alternative manifest dir (testing)
#
# Exit codes:
#   0  audit completed; results written to stdout
#   2  error (script invocation problem)
#
# Portability: bash 3.2 + BSD coreutils. Uses `date -d` (GNU) or `date -j -f`
# (BSD) for epoch conversion — tries both.

set -u

# Epoch-aware enforcement (ADR-0071): source the shared epoch library so this audit
# participates in the uniform epoch-gate surface (operator directive: all 17 audits).
# Exposes epoch_current_pin / epoch_resolve_baseline / epoch_filter_new /
# epoch_req_gated; sourcing is side-effect-free (functions only).
_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

QUIET=0
FORMAT=human
AUDIT_DIR=".harness/audit"
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        --json)  FORMAT=json ;;
        --dir=*) AUDIT_DIR="${arg#--dir=}" ;;
        -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-metrics.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

# Epoch conversion: try GNU `date -d` then BSD `date -j -f`.
to_epoch() {
    local s="$1"
    local e
    e=$(date -d "$s" +%s 2>/dev/null) || \
    e=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$s" +%s 2>/dev/null) || \
    e=""
    printf '%s' "$e"
}

# Field extraction from a manifest file (jq-free; bash 3.2 portable).
extract_field() {
    local f="$1" key="$2"
    grep "\"$key\"" "$f" 2>/dev/null \
        | head -1 \
        | sed "s/.*\"$key\": *\"\\([^\"]*\\)\".*/\\1/"
}

manifests=$(ls "$AUDIT_DIR"/TICKET-*.manifest.json 2>/dev/null)
total=$(printf '%s\n' "$manifests" | grep -c '^.\+' || true)

if [ "$total" -eq 0 ]; then
    if [ "$FORMAT" = "json" ]; then
        printf '{"total":0,"green":0,"red":0,"blocked":0,"deployment_frequency_per_week":null,"change_failure_rate_pct":null,"lead_time_median_seconds":null,"observation_window_days":null,"audit_dir":"%s"}\n' "$AUDIT_DIR"
    else
        emit "[audit-metrics] no manifests under $AUDIT_DIR — metrics undefined."
    fi
    exit 0
fi

green=0; red=0; blocked=0
earliest=""; latest=""
lead_times=""

for f in $manifests; do
    s=$(extract_field "$f" status)
    case "$s" in
        green)   green=$((green + 1)) ;;
        red)     red=$((red + 1)) ;;
        blocked) blocked=$((blocked + 1)) ;;
    esac
    created=$(extract_field "$f" created_at)
    if [ -n "$created" ]; then
        if [ -z "$earliest" ] || [ "$created" \< "$earliest" ]; then earliest="$created"; fi
        if [ -z "$latest" ]   || [ "$created" \> "$latest" ];   then latest="$created";   fi
        tid=$(extract_field "$f" ticket_id)
        if [ -n "$tid" ]; then
            first_commit=$(git log --reverse --grep="$tid" --format="%cI" 2>/dev/null | head -1)
            if [ -n "$first_commit" ]; then
                fc_ep=$(to_epoch "$first_commit")
                cr_ep=$(to_epoch "$created")
                if [ -n "$fc_ep" ] && [ -n "$cr_ep" ] && [ "$cr_ep" -ge "$fc_ep" ]; then
                    lead_times="$lead_times $((cr_ep - fc_ep))"
                fi
            fi
        fi
    fi
done

# Observation window in days
window_days="null"
if [ -n "$earliest" ] && [ -n "$latest" ]; then
    e1=$(to_epoch "$earliest")
    e2=$(to_epoch "$latest")
    if [ -n "$e1" ] && [ -n "$e2" ] && [ "$e2" -ge "$e1" ]; then
        window_days=$(awk "BEGIN { d = ($e2 - $e1) / 86400.0; printf \"%.2f\", d }")
    fi
fi

# Deployment frequency (green per week)
df_per_week="null"
if [ "$window_days" != "null" ] && [ "$green" -gt 0 ]; then
    df_per_week=$(awk "BEGIN { w = $window_days / 7.0; if (w <= 0) printf \"%.2f\", $green * 7.0; else printf \"%.2f\", $green / w }")
fi

# Change failure rate
cfr_pct="0.0"
if [ "$total" -gt 0 ]; then
    fail=$((red + blocked))
    cfr_pct=$(awk "BEGIN { printf \"%.1f\", ($fail / $total) * 100 }")
fi

# Median lead time
median_lead="null"
if [ -n "$lead_times" ]; then
    median_lead=$(printf '%s\n' $lead_times | tr ' ' '\n' | grep -v '^$' | sort -n | awk '
        { a[NR] = $1 }
        END {
            if (NR == 0) { print "null"; exit }
            if (NR % 2 == 1) print a[(NR+1)/2]
            else print int((a[NR/2] + a[NR/2+1]) / 2)
        }
    ')
fi

if [ "$FORMAT" = "json" ]; then
    printf '{"total":%d,"green":%d,"red":%d,"blocked":%d,"deployment_frequency_per_week":%s,"change_failure_rate_pct":%s,"lead_time_median_seconds":%s,"observation_window_days":%s,"audit_dir":"%s"}\n' \
        "$total" "$green" "$red" "$blocked" "$df_per_week" "$cfr_pct" "$median_lead" "$window_days" "$AUDIT_DIR"
    exit 0
fi

emit "[audit-metrics] DORA-style metrics from $AUDIT_DIR manifest corpus"
emit "  (per ADR-0035; closes Musk Engineering Leadership letter #3 — real numbers, no fabrication)"
emit ""
emit "  Ticket counts:"
emit "    total              $total"
emit "    green              $green"
emit "    red                $red"
emit "    blocked            $blocked"
emit ""
emit "  Deployment frequency: $df_per_week green tickets/week  (window: $window_days days)"
emit "  Change failure rate:  ${cfr_pct}%  (red+blocked / total)"
emit "  Lead time (median):   $median_lead seconds  (first-commit-mentioning-ticket -> manifest created_at)"
emit "  Time to restore:      n/a  (no restore-event corpus at v1; deferred per ADR-0035 §Out-of-scope)"
emit ""
emit "  Source: .harness/audit/TICKET-*.manifest.json (per-ticket provenance manifest trilogy; ADRs 0019-0021)"

exit 0
