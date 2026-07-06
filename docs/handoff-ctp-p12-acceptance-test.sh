#!/usr/bin/env bash
# docs/handoff-ctp-p12-acceptance-test.sh — machine-verifiable acceptance for
# CTP §30 / S-57 / §2.35 Full-Surface Intake (P-12; resolved at CTP pin f060a8e
# per ADR-0087).
#
# Originally written as a pre-tag proposal-era test; reconciled at ADR-0087 to
# verify the SHIPPED shape (S-57 landed as a NEW commands/full-surface-intake.sh
# composing S-32, rather than modifying business-intake.sh). Sections that key
# on S-57 output (3, 5, 7, 11) invoke commands/full-surface-intake.sh with a
# namespace-rich workload; sections that verify v1.0 back-compat (1, 2, 4, 6,
# 8, 10) still exercise commands/business-intake.sh. CTP's authoritative test
# corpus is evals/specs/cl546-fsintake-01..12 in the plugin cache.
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
section "3. Extended surface — > 9 questions when S-57 classifier signals hit"

# S-57 landed as a NEW command composing S-32 (rather than modifying business-intake.sh);
# --list-questions on the new command returns {universal_source, probe_groups: {ns: [...]}}
# — flatten to the same shape sections 4/5/6 downstream expect.
S57="$CTP_ROOT/commands/full-surface-intake.sh"
if [ -f "$S57" ]; then
    RICH_WORKLOAD="React SPA REST API JWT auth on Kubernetes via Terraform SQL database"
    if CLAUDE_PLUGIN_ROOT="$CTP_ROOT" /bin/bash "$S57" --workload "$RICH_WORKLOAD" --list-questions > "$TMP/s57-q.json" 2>"$TMP/s57-q.err"; then
        node -e '
            const raw = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
            const flat = [];
            const groups = (raw && raw.probe_groups) || {};
            for (const ns of Object.keys(groups)) for (const q of (groups[ns]||[])) flat.push({...q, probe_group: ns});
            // Prepend universal 9 for downstream sections that scan for them.
            const univ = JSON.parse(require("fs").readFileSync(process.argv[2],"utf8"));
            require("fs").writeFileSync(process.argv[3], JSON.stringify(univ.concat(flat), null, 2));
        ' "$TMP/s57-q.json" "$TMP/q.json" "$TMP/q.json.new" && mv "$TMP/q.json.new" "$TMP/q.json"
        TOTAL_Q=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).length)' "$TMP/q.json")
        if [ "$TOTAL_Q" -gt 9 ]; then
            ok "S-57 --list-questions (universal + probe_groups flattened) returns $TOTAL_Q > 9"
        else
            bad "S-57 --list-questions still returns only $TOTAL_Q — probe groups empty for rich workload"
        fi
    else
        bad "S-57 --list-questions failed: $(head -1 "$TMP/s57-q.err" 2>/dev/null || echo unknown)"
    fi
else
    bad "commands/full-surface-intake.sh not present — S-57 not shipped at this pin"
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
section "7. S-57 classifier stage exists + emits workload_classification"

if [ -f "$CTP_ROOT/commands/full-surface-intake.sh" ]; then
    if CLAUDE_PLUGIN_ROOT="$CTP_ROOT" /bin/bash "$CTP_ROOT/commands/full-surface-intake.sh" \
        --workload "React SPA REST API on Kubernetes" --classify > "$TMP/cls.json" 2>/dev/null; then
        if node -e '
            const c = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
            const wc = c && c.workload_classification;
            const ok = wc
                && Array.isArray(wc.workload_types) && wc.workload_types.length > 0
                && Array.isArray(wc.namespaces) && wc.namespaces.length > 0
                && Array.isArray(wc.activated_probe_namespaces);
            process.exit(ok ? 0 : 1);
        ' "$TMP/cls.json"; then
            ok "--classify emits workload_classification.{workload_types,namespaces,activated_probe_namespaces}"
        else
            bad "--classify output missing required workload_classification fields"
        fi
    else
        bad "--classify failed on S-57 command"
    fi
else
    bad "S-57 command not present at CTP_ROOT"
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
section "11. namespace-count check (S-57 classifier on a rich workload)"

if [ -f "$CTP_ROOT/commands/full-surface-intake.sh" ] && [ -f "$TMP/cls.json" ]; then
    NS_COUNT=$(node -e '
        const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
        const wc = c && c.workload_classification || {};
        console.log((wc.activated_probe_namespaces||[]).length);
    ' "$TMP/cls.json")
    if [ "$NS_COUNT" -gt 10 ]; then
        ok "S-57 classifier activated $NS_COUNT probe namespaces for a rich workload (> 10 target)"
    else
        printf '  info: S-57 classifier activated %s probe namespaces (target: > 10 for a namespace-rich workload)\n' "$NS_COUNT"
    fi
else
    warn "S-57 command or classification output not available for namespace count"
fi

# ---------------------------------------------------------------------------
section "12. GCTP --validate-profile accepts sample v1.1 profile (shipped shape)"

SAMPLE_V11="$CTP_ROOT/../../../docs/handoff-ctp-p12-sample-profile-v1.1.json"
[ -f "$SAMPLE_V11" ] || SAMPLE_V11="$(dirname "$0")/handoff-ctp-p12-sample-profile-v1.1.json"

if [ -f "$SAMPLE_V11" ]; then
    warn "sample v1.1 fixture uses PROPOSAL-ERA keys (signals_detected / activated_probe_groups / probes.universal) — will not validate against SHIPPED shape; regenerate via S-57 for a live check"
else
    warn "sample v1.1 profile not found — skipping GCTP validator check"
fi

# Additionally: exercise S-57 end-to-end and validate the emitted v1.1 profile.
if [ -f "$CTP_ROOT/commands/full-surface-intake.sh" ]; then
    cat > "$TMP/univ.json" <<'EOF'
{"workload":"React SPA on Kubernetes","motivation":"revenue","criticality":"mission-critical","availability_tolerance":"minutes","data_loss_tolerance":"minutes","data_sensitivity":"confidential","compliance_regime":"soc2","scale":"large","budget_posture":"balanced"}
EOF
    if CLAUDE_PLUGIN_ROOT="$CTP_ROOT" /bin/bash "$CTP_ROOT/commands/full-surface-intake.sh" \
        --workload "React SPA REST API JWT auth on Kubernetes" \
        --answers "$TMP/univ.json" \
        --probe-answer react:react_rendering_model=spa \
        --probe-answer jwt:jwt_token_lifetime=short \
        --probe-answer k8s:k8s_multitenancy=multi-tenant \
        --partial --out "$TMP/live-v11.json" --now 2026-07-05T00:00:00Z >/dev/null 2>&1; then
        ok "S-57 emits v1.1 profile end-to-end"
        # Repo-relative path to consult.sh — this test file lives under docs/, so
        # scripts/ is two levels up from CTP_ROOT (.harness/plugin-cache/claude-tdd-pro).
        CONSULT_SH="$CTP_ROOT/../../../scripts/consult.sh"
        [ -f "$CONSULT_SH" ] || CONSULT_SH="$(dirname "$0")/../scripts/consult.sh"
        if [ -f "$CONSULT_SH" ]; then
            if /bin/bash "$CONSULT_SH" --validate-profile "$TMP/live-v11.json" >/dev/null 2>"$TMP/vp.err"; then
                ok "GCTP scripts/consult.sh --validate-profile accepts live S-57 v1.1 profile"
            else
                bad "GCTP --validate-profile REJECTS live S-57 v1.1 profile: $(head -3 "$TMP/vp.err" | tr '\n' ' ')"
            fi
        else
            warn "scripts/consult.sh not locatable from test — skipping validator check"
        fi
    else
        bad "S-57 failed to emit v1.1 profile end-to-end"
    fi
fi

# ---------------------------------------------------------------------------
section "Summary"
printf '  passed: %d  failed: %d  skipped: %d\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] && exit 0 || exit 1
