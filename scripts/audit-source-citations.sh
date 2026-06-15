#!/usr/bin/env bash
# scripts/audit-source-citations.sh — authoritative-source citation-integrity gate.
#
# Per TICKET-051 / ADR-0049. "Widen + deepen" the conformance suite so that
# EVERY rule the harness enforces — across architecture, design, and coding,
# fullstack AND cloud — traces back to a CITED authoritative source. The
# existing conformance audits verify behavior (rubric-runner findings,
# rulebook-citation counts, EO non-exemptibility); none verify that the rule
# corpus the harness consumes is itself fully cited and intact. This closes
# that gap with two halves:
#
#   PART A — operator-standards citation integrity (the fullstack + cloud coding
#            rules in .harness/rules/active.json, sourced from claude-tdd-pro):
#     A1. every enforced rule carries a non-empty provenance[] (a cited source)
#     A2. no provenance entry has an empty source (every citation names a source)
#     A3. full namespace coverage — every namespace in namespaces_seen has >=1
#         rule OR is allow-listed empty (default: _community); catches a silent
#         category drop on a plugin pin bump
#     A4. the canonical authoritative-source set is intact — fullstack
#         (react,typescript,node,web-vitals,w3c) AND cloud/security (owasp,slsa)
#     A5. [informational, non-blocking] compliance-controls coverage among the
#         security-namespace P0 rules (owasp/slsa) — surfaced, not gated, so a
#         plugin-owned gap is visible without the harness failing on content it
#         does not own (prime directive)
#
#   PART B — authoritative-source DOC integrity (the architecture/design
#            rulebooks named in CLAUDE.md, incl. the TIER-0 supreme corpus):
#     B1. each named source doc exists
#     B2. each is cross-referenced >=1 time from an operational surface
#
# ADDITIVE, never subtractive (ADR-0047): this gate only ADDS checks; it relaxes
# nothing. Content-agnostic on rule SEMANTICS (owned by claude-tdd-pro per the
# prime directive) — it verifies the CITATION SPINE, not what a rule means.
#
# Usage:
#   scripts/audit-source-citations.sh            # human-readable summary
#   scripts/audit-source-citations.sh --detail   # per-namespace / per-doc rows
#   scripts/audit-source-citations.sh --quiet    # exit code only
#
# Env overrides (testability):
#   SRC_RULES_FILE       default .harness/rules/active.json
#   SRC_ALLOW_EMPTY_NS   default "_community" (namespaces allowed to be empty)
#   SRC_REQUIRED_NS      default "google node owasp react slsa typescript w3c web-vitals"
#   SRC_SECURITY_NS      default "owasp slsa" (P0 rules here SHOULD carry controls[])
#   SRC_SOURCE_DOCS      default the CLAUDE.md authoritative-source doc set
#   SRC_ROOT             default . (repo root scanned for cross-references)
#
# Exit codes:
#   0  all citation-integrity invariants hold
#   1  one or more violations
#   2  error (bad invocation / rules file missing / unreadable)
#
# Portability: bash 3.2 + BSD coreutils. No external deps (no jq/node).

set -u

DETAIL=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --detail)  DETAIL=1 ;;
        --quiet)   QUIET=1 ;;
        -h|--help) sed -n '2,49p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-source-citations.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

RULES_FILE="${SRC_RULES_FILE:-.harness/rules/active.json}"
ALLOW_EMPTY_NS="${SRC_ALLOW_EMPTY_NS:-_community}"
REQUIRED_NS="${SRC_REQUIRED_NS:-google node owasp react slsa typescript w3c web-vitals}"
SECURITY_NS="${SRC_SECURITY_NS:-owasp slsa}"
ROOT="${SRC_ROOT:-.}"
SOURCE_DOCS="${SRC_SOURCE_DOCS:-\
docs/ai-engineering-corpus.md \
docs/founder-directives.md \
docs/architecture-principles.md \
docs/grok-orchestration-principles.md \
docs/claude-tdd-pro-principles.md \
docs/handoff-contract.md \
docs/quality-gate.md \
docs/eo-2026-ai-innovation-security-alignment.md}"

violations=0
flag() { violations=$((violations + 1)); emit "  [VIOLATION] $*"; }
in_set() { # in_set <needle> <space-separated-haystack>
    local n="$1" hay="$2" x
    for x in $hay; do [ "$x" = "$n" ] && return 0; done
    return 1
}

# =============================================================================
# PART A — operator-standards citation integrity
# =============================================================================
emit "[source-citations] PART A — operator-declared standards registry"
emit "  registry: $RULES_FILE"

if [ ! -f "$RULES_FILE" ]; then
    printf 'audit-source-citations.sh: rules registry missing: %s\n' "$RULES_FILE" >&2
    exit 2
fi

rule_count=$(grep -oE '"id":"[^"]*"' "$RULES_FILE" 2>/dev/null | wc -l | tr -d ' ')
emit "  enforced rules: $rule_count"

if [ "$rule_count" -eq 0 ]; then
    # An empty registry means standards-sync produced nothing — that is a
    # fail-closed condition for a citation gate (no rules ⇒ nothing cited).
    flag "registry has zero rules (standards-sync produced an empty registry?)"
else
    # A1: every rule must carry a NON-EMPTY provenance array ("[{").
    prov_count=$(grep -oE '"provenance":\[\{' "$RULES_FILE" 2>/dev/null | wc -l | tr -d ' ')
    empty_prov=$(grep -oE '"provenance":\[\]' "$RULES_FILE" 2>/dev/null | wc -l | tr -d ' ')
    emit "  rules with non-empty provenance: $prov_count/$rule_count (empty provenance arrays: $empty_prov)"
    if [ "$prov_count" -lt "$rule_count" ]; then
        flag "A1: $((rule_count - prov_count)) rule(s) lack a non-empty provenance[] (uncited enforced rule)"
    fi
    [ "$empty_prov" -gt 0 ] && flag "A1: $empty_prov rule(s) carry an empty provenance:[] array"

    # A2: no provenance entry may name an empty source.
    empty_src=$(grep -oE '"source":""' "$RULES_FILE" 2>/dev/null | wc -l | tr -d ' ')
    [ "$empty_src" -gt 0 ] && flag "A2: $empty_src provenance entr(ies) name an empty source"
fi

# A3/A4: namespace coverage.
seen_ns=$(grep -oE '"namespaces_seen":\[[^]]*\]' "$RULES_FILE" 2>/dev/null \
    | sed -E 's/.*\[(.*)\]/\1/' | tr ',' ' ' | tr -d '"')
emit "  namespaces_seen: ${seen_ns:-<none>}"

ns_count() { grep -oE "\"source_namespace\":\"$1\"" "$RULES_FILE" 2>/dev/null | wc -l | tr -d ' '; }

# A3: each seen namespace must be non-empty unless allow-listed empty.
for ns in $seen_ns; do
    c=$(ns_count "$ns")
    if [ "$DETAIL" -eq 1 ]; then printf '    %-14s %3d rule(s)\n' "$ns" "$c"; fi
    if [ "$c" -eq 0 ] && ! in_set "$ns" "$ALLOW_EMPTY_NS"; then
        flag "A3: namespace '$ns' is in namespaces_seen but has 0 rules (not allow-empty)"
    fi
done

# A4: the canonical required source set must each be present + non-empty.
for ns in $REQUIRED_NS; do
    c=$(ns_count "$ns")
    if [ "$c" -eq 0 ]; then
        flag "A4: required authoritative-source namespace '$ns' absent or empty (fullstack/cloud coverage gap)"
    fi
done

# A5 (informational, non-blocking): controls coverage among security P0 rules.
# Per-rule walk: split the single-line registry on the rule-start token
# {"id":" (never appears inside a nested object) so each line is one rule.
sec_p0_total=0
sec_p0_with_controls=0
rules_split=$(tr -d '\n' < "$RULES_FILE" 2>/dev/null \
    | awk '{ gsub(/\{"id":"/, "\n&"); print }' | grep '^{"id":"')
while IFS= read -r line; do
    [ -n "$line" ] || continue
    rns=$(printf '%s' "$line" | grep -oE '"source_namespace":"[^"]*"' | head -1 | sed -E 's/.*:"([^"]*)"/\1/')
    [ -n "$rns" ] || continue
    in_set "$rns" "$SECURITY_NS" || continue
    sev=$(printf '%s' "$line" | grep -oE '"severity":"[^"]*"' | head -1 | sed -E 's/.*:"([^"]*)"/\1/')
    [ "$sev" = "P0" ] || continue
    sec_p0_total=$((sec_p0_total + 1))
    if printf '%s' "$line" | grep -qE '"controls":\[\{'; then
        sec_p0_with_controls=$((sec_p0_with_controls + 1))
    else
        rid=$(printf '%s' "$line" | sed -E 's/.*"id":"([^"]*)".*/\1/' | head -1)
        emit "  [info] security P0 rule '$rid' ($rns) has no compliance controls[] mapping"
    fi
done <<EOF
$rules_split
EOF
emit "  security P0 rules with compliance controls[]: $sec_p0_with_controls/$sec_p0_total (informational)"

# =============================================================================
# PART B — authoritative-source DOC integrity (incl. TIER-0 corpus)
# =============================================================================
emit ""
emit "[source-citations] PART B — authoritative-source doc integrity"

xref_count() { # count operational citations of a doc basename, excluding itself
    local doc="$1" base
    base=$(basename "$doc")
    grep -rEl --include='*.md' --include='*.sh' --include='*.yml' -- "$base" \
        "$ROOT" 2>/dev/null | grep -v "/${base}\$" | grep -v "^${doc}\$" \
        | grep -v 'audit-source-citations' | wc -l | tr -d ' '
}

for doc in $SOURCE_DOCS; do
    if [ ! -f "$doc" ]; then
        flag "B1: authoritative-source doc missing: $doc"
        continue
    fi
    n=$(xref_count "$doc")
    if [ "$DETAIL" -eq 1 ]; then printf '    %-52s %3d citation(s)\n' "$(basename "$doc")" "$n"; fi
    if [ "$n" -eq 0 ]; then
        flag "B2: authoritative-source doc '$doc' is never cross-referenced from an operational surface"
    fi
done

# =============================================================================
emit ""
if [ "$violations" -gt 0 ]; then
    emit "[source-citations] $violations violation(s). Every enforced rule must trace to a cited"
    emit "  authoritative source, and every authoritative-source doc (incl. the TIER-0 corpus)"
    emit "  must exist + be wired. ADDITIVE gate (ADR-0047); rule CONTENT owned by claude-tdd-pro."
    exit 1
fi

emit "[source-citations] OK — all enforced rules trace to cited authoritative sources;"
emit "  every authoritative-source doc (incl. TIER-0 corpus) exists + is wired."
exit 0
