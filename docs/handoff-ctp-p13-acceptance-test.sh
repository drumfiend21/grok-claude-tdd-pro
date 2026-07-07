#!/usr/bin/env bash
# docs/handoff-ctp-p13-acceptance-test.sh — machine-verifiable acceptance for
# CTP §30.4 "Classifier over vision + answers" (P-13).
#
# Runs against a CTP checkout at the dev/v1.15-cloud-classify-from-answers
# branch tip (or an equivalent branch that implements §30.4). CTP owns the
# authoritative test corpus in evals/; this file is the GCTP-side proposal
# fixture — it should pass at the pre-tag branch tip and continue passing at
# whatever CTP tags as v1.15.
#
# Usage:
#   bash docs/handoff-ctp-p13-acceptance-test.sh                # against $PWD (assumed CTP checkout)
#   CTP_ROOT=/path/to/claude-tdd-pro bash docs/handoff-ctp-p13-acceptance-test.sh
#
# Portability: bash 3.2 + BSD coreutils + node (JSON parse only). Matches the
# discipline of the P-12 acceptance test.
#
# Exit codes:
#   0  all assertions pass
#   1  one or more assertions fail
#   2  setup error (missing CTP checkout / node / etc.)

set -u

CTP_ROOT="${CTP_ROOT:-$PWD}"

fail=0
pass=0
skip=0

section() { printf '\n=== %s ===\n' "$*"; }
ok()      { printf '  \342\234\223 %s\n' "$*"; pass=$((pass + 1)); }
bad()     { printf '  \342\234\227 %s\n' "$*"; fail=$((fail + 1)); }
warn()    { printf '  ! %s\n' "$*"; skip=$((skip + 1)); }

command -v node >/dev/null 2>&1 || { echo "acceptance: node required" >&2; exit 2; }
[ -f "$CTP_ROOT/commands/full-surface-intake.sh" ] || {
    echo "acceptance: not a CTP checkout (missing commands/full-surface-intake.sh) — set CTP_ROOT" >&2
    exit 2
}

INTAKE="$CTP_ROOT/commands/full-surface-intake.sh"
export CLAUDE_PLUGIN_ROOT="$CTP_ROOT"

# Cloud-agnostic vision — mirrors the Certifiable, Inc. kata (no cloud mentioned).
CLOUD_AGNOSTIC_VISION="Certifiable, Inc. certifies IT professionals. Their exam process mixes multiple-choice, short-answer, and case-study questions. Multiple-choice is auto-graded; short-answer and case-study are graded by ~300 retired subject matter experts. They want to adopt generative AI to automate grading and question generation and handle 10x growth without losing certification credibility or violating candidate trust."

classify_json() {
    # $1 = extra flags array as a single string (eval'd)
    local extra="$1"
    eval "bash '$INTAKE' --workload \"\$CLOUD_AGNOSTIC_VISION\" $extra --classify 2>/dev/null" \
      | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const i=s.indexOf("{");process.stdout.write(i<0?"{}":s.slice(i))})'
}

classify_types() {
    classify_json "$1" | node -e '
        let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
            try { const j=JSON.parse(s); console.log((j.workload_classification.workload_types||[]).sort().join(",")); }
            catch { console.log(""); }
        })'
}

classify_probes() {
    classify_json "$1" | node -e '
        let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
            try { const j=JSON.parse(s); console.log((j.workload_classification.activated_probe_namespaces||[]).sort().join(",")); }
            catch { console.log(""); }
        })'
}

# --- 1. Regression baseline (documents the bug being closed) -----------------
section "1. Cloud-agnostic vision alone fires no cloud type (unchanged from §30.3)"
types_bare=$(classify_types "")
case ",$types_bare," in
    *,aws-platform,*|*,azure-platform,*|*,gcp-platform,*|*,cloudformation,*)
        bad "vision alone leaked a cloud type: $types_bare" ;;
    *)
        ok "vision alone → no cloud type (types=$types_bare)" ;;
esac

# --- 2. Core Fix: operator-stated cloud in universal answer fires the type ---
section "2. Core Fix — operator answer 'motivation' mentioning AWS fires aws-platform"
types_aws=$(classify_types "--answer motivation=\"reduce grading burden using AWS Bedrock\"")
case ",$types_aws," in
    *,aws-platform,*) ok "aws-platform fired from answer text (types=$types_aws)" ;;
    *) bad "aws-platform did NOT fire when operator stated AWS in an answer (types=$types_aws) — Core Fix not present" ;;
esac

# --- 3. Core Fix: activates the aws probe group -------------------------------
section "3. Core Fix — activated_probe_namespaces includes aws when aws-platform fires"
probes_aws=$(classify_probes "--answer motivation=\"deploy on AWS Bedrock\"")
case ",$probes_aws," in
    *,aws,*) ok "aws probe group activated (probes=$probes_aws)" ;;
    *) bad "aws probe group did NOT activate (probes=$probes_aws)" ;;
esac

# --- 4. Monotonicity: baseline types preserved --------------------------------
section "4. Monotonicity — every type fired without the answer still fires with it"
# Baseline (Certifiable vision → ai-governed + baseline-quality).
case ",$types_bare," in
    *,ai-governed,*) baseline_has_ai=1 ;;
    *) baseline_has_ai=0 ;;
esac
case ",$types_aws," in
    *,ai-governed,*) both_have_ai=1 ;;
    *) both_have_ai=0 ;;
esac
if [ "$baseline_has_ai" -eq 1 ] && [ "$both_have_ai" -eq 1 ]; then
    ok "ai-governed preserved (monotone superset)"
elif [ "$baseline_has_ai" -eq 0 ]; then
    warn "baseline did not include ai-governed (unexpected but not a §30.4 defect)"
else
    bad "ai-governed LOST when answer added — non-monotone regression (types=$types_aws)"
fi

# --- 5. Word-boundary preservation over the new haystack ---------------------
section "5. §30.3 word-boundary matching still holds over answer text"
# 'leaks' inside a motivation answer must NOT fire azure-platform (aks inside leaks).
types_leaks=$(classify_types "--answer motivation=\"prevent content leaks in exams\"")
case ",$types_leaks," in
    *,azure-platform,*) bad "azure-platform mis-fired on 'leaks' in answer text — §30.3 boundary regressed" ;;
    *) ok "no azure-platform mis-fire from 'leaks' in answer (types=$types_leaks)" ;;
esac
# 'certification' in a motivation answer must NOT fire ci-cd (ci inside certification).
types_cert=$(classify_types "--answer motivation=\"IT certification credibility\"")
case ",$types_cert," in
    *,ci-cd,*) bad "ci-cd mis-fired on 'certification' in answer — §30.3 boundary regressed" ;;
    *) ok "no ci-cd mis-fire from 'certification' in answer (types=$types_cert)" ;;
esac

# --- 6. Multi-cloud precision --------------------------------------------------
section "6. Precise disambiguation — target_platform=aws does NOT drag Azure/GCP"
types_only_aws=$(classify_types "--answer target_platform=aws")
saw_aws=0; saw_az=0; saw_gcp=0
case ",$types_only_aws," in *,aws-platform,*) saw_aws=1 ;; esac
case ",$types_only_aws," in *,azure-platform,*) saw_az=1 ;; esac
case ",$types_only_aws," in *,gcp-platform,*) saw_gcp=1 ;; esac
if [ "$saw_aws" -eq 1 ] && [ "$saw_az" -eq 0 ] && [ "$saw_gcp" -eq 0 ]; then
    ok "target_platform=aws fires only aws-platform (types=$types_only_aws)"
else
    bad "target_platform=aws mis-fired (aws=$saw_aws az=$saw_az gcp=$saw_gcp)"
fi

# --- 7. Undecided / on-prem / hybrid don't fire cloud types ------------------
section "7. Non-cloud target_platform values fire no cloud type"
for tgt in undecided on-prem hybrid; do
    t=$(classify_types "--answer target_platform=$tgt")
    case ",$t," in
        *,aws-platform,*|*,azure-platform,*|*,gcp-platform,*)
            bad "target_platform=$tgt leaked a cloud type (types=$t)" ;;
        *)
            ok "target_platform=$tgt fires no cloud type (types=$t)" ;;
    esac
done

# --- 8. Vision + answer union (not preference) --------------------------------
section "8. Vision + answer signals union (both fire when both stated)"
# Vision mentions AWS; answer mentions GCP → both should fire.
types_union=$(bash "$INTAKE" \
    --workload "$CLOUD_AGNOSTIC_VISION Deploy on AWS Bedrock." \
    --answer target_platform=gcp \
    --classify 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const i=s.indexOf("{");if(i<0){console.log("");return}try{const j=JSON.parse(s.slice(i));console.log((j.workload_classification.workload_types||[]).sort().join(","))}catch{console.log("")}})')
saw_a=0; saw_g=0
case ",$types_union," in *,aws-platform,*) saw_a=1 ;; esac
case ",$types_union," in *,gcp-platform,*) saw_g=1 ;; esac
if [ "$saw_a" -eq 1 ] && [ "$saw_g" -eq 1 ]; then
    ok "vision(AWS) + answer(gcp) fires both (union — types=$types_union)"
else
    bad "vision+answer union failed (aws=$saw_a gcp=$saw_g types=$types_union)"
fi

# --- 9. v1.0 back-compat: business-intake still emits identical v1.0 profile -
section "9. v1.0 profile back-compat"
if [ -f "$CTP_ROOT/commands/business-intake.sh" ]; then
    v10=$(bash "$CTP_ROOT/commands/business-intake.sh" --dry-run 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);console.log(j.schema_version||"")}catch{console.log("")}})' || true)
    if [ "$v10" = "1.0" ]; then
        ok "business-intake --dry-run still emits schema_version=1.0"
    else
        warn "business-intake --dry-run did not emit schema_version=1.0 (v=$v10) — may be a §30.4-adjacent shape change"
    fi
else
    warn "business-intake.sh missing — skipping v1.0 back-compat check"
fi

# --- 10. Extension check (RECOMMENDED, not required for Core Fix) ------------
section "10. Extension — target_platform universal question present (if shipped)"
n_universal=$(bash "$INTAKE" --workload "$CLOUD_AGNOSTIC_VISION" --list-questions 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const u=(j||[]).filter(q=>!q.probe_group||q.probe_group==="universal");console.log(u.length)}catch{console.log(0)}})' 2>/dev/null || echo 0)
has_target=$(bash "$INTAKE" --workload "$CLOUD_AGNOSTIC_VISION" --list-questions 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);console.log(((j||[]).find(q=>q.key==="target_platform"))?"1":"0")}catch{console.log("0")}})' 2>/dev/null || echo 0)
if [ "$has_target" = "1" ]; then
    ok "target_platform universal question present ($n_universal universal Qs total)"
else
    warn "target_platform universal question NOT shipped — Extension deferred (Core Fix still passes)"
fi

# --- Summary -----------------------------------------------------------------
section "Summary"
printf '  pass:  %d\n' "$pass"
printf '  fail:  %d\n' "$fail"
printf '  skip:  %d\n' "$skip"

if [ "$fail" -eq 0 ]; then
    printf '\nP-13 acceptance: OK\n'
    exit 0
else
    printf '\nP-13 acceptance: FAIL (%d assertion(s))\n' "$fail"
    exit 1
fi
