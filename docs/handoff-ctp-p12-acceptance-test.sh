#!/usr/bin/env bash
# docs/handoff-ctp-p12-acceptance-test.sh — machine-verifiable acceptance for
# CTP v1.14 §27.16 Full-Surface Intake.
#
# This is a NON-NORMATIVE test harness that CTP can run locally against the
# proposed v1.14 build BEFORE tagging. It exercises the acceptance criteria
# from §5 of docs/handoff-ctp-p12-full-surface-intake.md. Companion to that
# handoff — CTP owns the authoritative test corpus in evals/.
#
# Usage (from a claude-tdd-pro checkout, at the dev/v1.14-full-surface-intake
# branch tip):
#
#   bash docs/handoff-ctp-p12-acceptance-test.sh
#
# Env overrides:
#   CTP_ROOT   default $PWD (the plugin repo checkout)
#   ACTIVE_JSON_HINT  path to any downstream consumer's active.json for the
#                     namespace-resolution check (optional; skipped if absent)
#
# Exit codes:
#   0  all acceptance checks pass
#   1  one or more checks fail
#   2  usage / setup error
#
# Portability: bash 3.2 + BSD coreutils + node (used only for JSON parsing —
# same discipline as commands/business-intake.sh already uses).

set -u

CTP_ROOT="${CTP_ROOT:-$PWD}"
ACTIVE_JSON_HINT="${ACTIVE_JSON_HINT:-}"

fail=0
pass=0
skip=0

section() { printf '\n=== %s ===\n' "$*"; }
ok()      { printf '  \342\234\223 %s\n' "$*"; pass=$((pass + 1)); }
bad()     { printf '  \342\234\227 %s\n' "$*"; fail=$((fail + 1)); }
warn()    { printf '  ! %s\n' "$*"; skip=$((skip + 1)); }

command -v node >/dev/null 2>&1 || { echo "acceptance: node required" >&2; exit 2; }
[ -f "$CTP_ROOT/commands/business-intake.sh" ] || {
    echo "acceptance: not a CTP checkout (missing commands/business-intake.sh) — set CTP_ROOT" >&2
    exit 2
}

TMP=$(mktemp -d 2>/dev/null || mktemp -d -t p12)
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
section "1. --list-questions still parses (bash 3.2 clean)"

if /bin/bash "$CTP_ROOT/commands/business-intake.sh" --list-questions > "$TMP/q.json" 2>"$TMP/q.err"; then
    ok "exit 0"
else
    bad "exit non-zero — see $TMP/q.err"
fi

if [ -s "$TMP/q.err" ]; then
    if grep -qE 'unbound|bad substitution|command not found' "$TMP/q.err"; then
        bad "stderr shows bash-3.2 crash signature"
    else
        ok "no bash-3.2 crash signature on stderr"
    fi
else
    ok "clean stderr"
fi

# ---------------------------------------------------------------------------
section "2. Universal 9 questions preserved (backward-compat baseline)"

UNIVERSAL_KEYS="workload motivation criticality availability_tolerance data_loss_tolerance data_sensitivity compliance_regime scale budget_posture"
for k in $UNIVERSAL_KEYS; do
    if node -e '
        const q = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
        process.exit(q.some(x => x.key === process.argv[2]) ? 0 : 1);
    ' "$TMP/q.json" "$k"; then
        ok "universal key present: $k"
    else
        bad "universal key MISSING: $k"
    fi
done

# ---------------------------------------------------------------------------
section "3. Extended surface — > 9 questions when classifier signals hit"

TOTAL_Q=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).length)' "$TMP/q.json")
if [ "$TOTAL_Q" -gt 9 ]; then
    ok "--list-questions returns $TOTAL_Q > 9 (stage-2 groups exposed)"
else
    bad "--list-questions still returns only $TOTAL_Q — stage-2 groups missing"
fi

# ---------------------------------------------------------------------------
section "4. Every question grounded (source_id present + non-empty)"

MISSING_SRC=$(node -e '
    const q = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const bad = q.filter(x => !x.source_id || !x.source_id.trim()).map(x => x.key);
    console.log(bad.join(","));
' "$TMP/q.json")
if [ -z "$MISSING_SRC" ]; then
    ok "every question has a non-empty source_id"
else
    bad "questions with missing source_id: $MISSING_SRC"
fi

# ---------------------------------------------------------------------------
section "5. probe_group tagging present on stage-2 questions"

MISSING_GROUP=$(node -e '
    const q = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const universal = new Set("workload motivation criticality availability_tolerance data_loss_tolerance data_sensitivity compliance_regime scale budget_posture".split(" "));
    const bad = q.filter(x => !universal.has(x.key)).filter(x => !x.probe_group).map(x => x.key);
    console.log(bad.join(","));
' "$TMP/q.json")
if [ -z "$MISSING_GROUP" ]; then
    ok "every stage-2 question carries probe_group"
else
    bad "stage-2 questions without probe_group: $MISSING_GROUP"
fi

# ---------------------------------------------------------------------------
section "6. source_id catalog resolution (against standards/*.yaml)"

# Every source_id used in --list-questions must appear as `- id: <name>` in
# at least one standards/*.yaml (or be explicitly listed in the ⊕ NEW set).
node -e '
    const fs = require("fs"), path = require("path");
    const q = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const dir = process.argv[2];
    const need = new Set(q.map(x => x.source_id).filter(Boolean));
    const seen = new Set();
    for (const f of fs.readdirSync(dir)) {
        if (!/\.ya?ml$/.test(f)) continue;
        const text = fs.readFileSync(path.join(dir, f), "utf8");
        for (const m of text.matchAll(/^- id:\s*([A-Za-z0-9_.-]+)/gm)) seen.add(m[1]);
    }
    const missing = [...need].filter(x => !seen.has(x));
    if (missing.length) {
        console.log("MISSING:" + missing.join(","));
        process.exit(1);
    }
    console.log("OK");
' "$TMP/q.json" "$CTP_ROOT/standards" > "$TMP/src.out" 2>&1
if grep -q '^OK' "$TMP/src.out"; then
    ok "every source_id resolves in standards/*.yaml"
else
    MISS=$(grep -oE 'MISSING:.*' "$TMP/src.out" | sed 's/^MISSING://')
    bad "source_id(s) not present in standards/*.yaml: $MISS"
fi

# ---------------------------------------------------------------------------
section "7. Classifier stage exists (--classify or equivalent)"

if /bin/bash "$CTP_ROOT/commands/business-intake.sh" --help 2>&1 | grep -qE '\-\-classify|classifier'; then
    ok "--classify surfaced in --help"
else
    warn "--classify not surfaced in --help — verify classifier is invoked from architect-session.sh"
fi

# ---------------------------------------------------------------------------
section "8. schema_version bump 1.0 → 1.1 (with backward-compat on read)"

# Feed a minimal v1.0 profile; --answers should still parse it.
cat > "$TMP/v10.json" <<'EOF'
{ "workload": "test workload" }
EOF
if /bin/bash "$CTP_ROOT/commands/business-intake.sh" --answers "$TMP/v10.json" --partial --out "$TMP/prof-v10.json" >/dev/null 2>&1; then
    if [ -f "$TMP/prof-v10.json" ]; then
        SV=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).schema_version || "")' "$TMP/prof-v10.json")
        case "$SV" in
            "1.0"|"1.1") ok "v1.0 answers → profile schema_version=$SV (backward-compat)" ;;
            *) bad "profile schema_version unexpected: '$SV'" ;;
        esac
    else
        bad "profile not written for v1.0 answers"
    fi
else
    bad "business-intake failed to accept v1.0 answers"
fi

# ---------------------------------------------------------------------------
section "9. Downstream translate accepts the extended profile"

# Feed the sample v1.1 profile shipped with this handoff.
SAMPLE="$CTP_ROOT/../docs/handoff-ctp-p12-sample-profile-v1.1.json"
[ -f "$SAMPLE" ] || SAMPLE="$(dirname "$0")/handoff-ctp-p12-sample-profile-v1.1.json"

if [ -f "$SAMPLE" ]; then
    if /bin/bash "$CTP_ROOT/commands/business-translate.sh" \
        --profile "$SAMPLE" \
        --out "$TMP/tr.json" >/dev/null 2>&1; then
        ok "business-translate accepts sample v1.1 profile"
        NG=$(node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(Array.isArray(r.needs_grounding)?r.needs_grounding.length:0)' "$TMP/tr.json" 2>/dev/null || echo "?")
        if [ "$NG" = "0" ]; then
            ok "translate output needs_grounding=0 (cite-or-decline satisfied)"
        else
            bad "translate needs_grounding=$NG (must be 0)"
        fi
    else
        bad "business-translate REJECTS sample v1.1 profile"
    fi
else
    warn "sample v1.1 profile not found — skipping downstream check (place at $SAMPLE)"
fi

# ---------------------------------------------------------------------------
section "10. Backward-compat: existing v1.0 kata profile still recommends"

# If CTP has an existing eval corpus, exercise one v1.0 fixture end-to-end.
V10_EVAL=""
for c in \
    "$CTP_ROOT/evals/business-intake-v1.13-kata-profile.json" \
    "$CTP_ROOT/standards/business-profile.json" \
    "$CTP_ROOT/evals/business-profile.json"; do
    [ -f "$c" ] && V10_EVAL="$c" && break
done

if [ -n "$V10_EVAL" ]; then
    if /bin/bash "$CTP_ROOT/commands/business-translate.sh" \
        --profile "$V10_EVAL" \
        --out "$TMP/tr-v10.json" >/dev/null 2>&1 && \
       /bin/bash "$CTP_ROOT/commands/architect-recommend.sh" \
        --requirements "$TMP/tr-v10.json" \
        --profile "$V10_EVAL" \
        --out "$TMP/opt-v10.json" >/dev/null 2>&1; then
        ok "v1.0 profile end-to-end: translate + recommend green"
    else
        bad "v1.0 profile regression: translate or recommend failed"
    fi
else
    warn "no v1.0 fixture found — skipping regression check"
fi

# ---------------------------------------------------------------------------
section "11. namespace-count check (informational)"

# Count unique namespaces represented in --list-questions (via probe_group +
# universal being counted as _universal).
NS_COUNT=$(node -e '
    const q = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const universal = new Set("workload motivation criticality availability_tolerance data_loss_tolerance data_sensitivity compliance_regime scale budget_posture".split(" "));
    const ns = new Set();
    for (const x of q) ns.add(universal.has(x.key) ? "_universal" : (x.probe_group || "?"));
    console.log(ns.size);
' "$TMP/q.json")
printf '  info: --list-questions covers %s probe groups (target: > 10 for a namespace-rich workload)\n' "$NS_COUNT"

# ---------------------------------------------------------------------------
section "Summary"
printf '  passed: %d  failed: %d  skipped: %d\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] && exit 0 || exit 1
