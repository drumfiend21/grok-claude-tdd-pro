#!/usr/bin/env bash
# scripts/audit-standards-enforced.sh — Fix C: the DYNAMIC re-run gate.
#
# Per TICKET-074 / ADR-0063 (PROPOSAL-002 GCTP-side of the O'Reilly-kata loop). Fix B
# made the inner loop *produce* rules_verified from a real detector run. This gate is
# the backstop: for every green handoff response, it RE-RUNS the detectors against the
# app_root (via scripts/enforce-standards.sh, the same spine the inner loop uses) and
# asserts that the response's claims are TRUE — converting the rules_verified gate from
# "claims complete" (audit-rules-verified.sh, static) to "claims true" (dynamic).
#
# For each .harness/handoffs/*.res.json with status "green" whose matching request
# carries applicable_rules, with a resolvable app_root:
#   (1) every claimed rules_verified[rule] MUST equal the LIVE verdict for that rule
#       (a res claiming "pass" on a rule the code now violates ⇒ RED);
#   (2) every LIVE "pass" MUST have files_evaluated > 0 (no vacuous/asserted pass —
#       falsifiability: a green claim must have actually evaluated a file).
#
# VACUOUS (pass) when: no app_root is configured (no external app to verify — the
# common CI case), or no green response carries applicable_rules. So the gate only
# bites once an operator points the harness at a real app tree (.harness/app.json).
#
# Usage:
#   scripts/audit-standards-enforced.sh           # human-readable
#   scripts/audit-standards-enforced.sh --quiet   # exit code only
#
# Env overrides (testability):
#   ASE_HANDOFFS_DIR   default .harness/handoffs
#   ASE_ES_BIN         default ./scripts/enforce-standards.sh
#   ASE_APP_ROOT       override app_root (else resolved via app-root.sh)
#   ASE_APP_ROOT_BIN   default ./scripts/app-root.sh
#   (ES_ENFORCE etc. are passed through to enforce-standards.sh for stubbing.)
#
# Exit codes:
#   0  every green response's claims match the live detector verdicts (incl. vacuous)
#   1  one or more claims diverge from live, or a vacuous "pass" (files_evaluated 0)
#   2  error (bad invocation / node missing)
#
# Portability: bash 3.2 + BSD coreutils; node for JSON compare; enforce.sh Ruby-backed.

set -u

# Epoch-aware enforcement (ADR-0071): source the shared epoch library so this audit
# participates in the uniform epoch-gate surface (operator directive: all 17 audits).
# Exposes epoch_current_pin / epoch_resolve_baseline / epoch_filter_new /
# epoch_req_gated; sourcing is side-effect-free (functions only).
_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet)   QUIET=1 ;;
        -h|--help) sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-standards-enforced.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

HANDOFFS_DIR="${ASE_HANDOFFS_DIR:-.harness/handoffs}"
ES_BIN="${ASE_ES_BIN:-./scripts/enforce-standards.sh}"
APP_ROOT_BIN="${ASE_APP_ROOT_BIN:-./scripts/app-root.sh}"

command -v node >/dev/null 2>&1 || { printf 'audit-standards-enforced.sh: node required\n' >&2; exit 2; }

# Resolve app_root (the "should I run at all" decision). No app_root ⇒ vacuous.
if [ -n "${ASE_APP_ROOT:-}" ]; then
    APP=$("$APP_ROOT_BIN" --validate "$ASE_APP_ROOT" 2>/dev/null) || {
        emit "[standards-enforced] app_root configured but invalid/empty — nothing to re-verify (vacuous)."; exit 0; }
else
    APP=$("$APP_ROOT_BIN" 2>/dev/null) || {
        emit "[standards-enforced] no app_root configured (.harness/app.json) — vacuous pass (no external app to re-verify)."; exit 0; }
fi

# Any green responses with applicable_rules to check?
have=0
if [ -d "$HANDOFFS_DIR" ]; then
    for res in "$HANDOFFS_DIR"/*.res.json; do [ -e "$res" ] && have=1 && break; done
fi
if [ "$have" -eq 0 ]; then
    emit "[standards-enforced] no response artifacts in $HANDOFFS_DIR — vacuous pass."
    exit 0
fi

# Epoch-aware enforcement (ADR-0071): collect divergences, then grandfather any
# recorded in the baseline (pin-keyed, legacy-flat fallback) as pre-epoch legacy
# claims. NEW divergences (not baselined) still fail. No baseline => every
# divergence is new (behavior identical to pre-ADR-0071).
div_file=$(mktemp -t std-enf-div.XXXXXX) || { printf 'audit-standards-enforced.sh: mktemp failed\n' >&2; exit 2; }
trap 'rm -f -- "$div_file"' EXIT INT TERM
checked=0
for res in "$HANDOFFS_DIR"/*.res.json; do
    [ -e "$res" ] || continue
    base=$(basename "$res" .res.json)
    req="$HANDOFFS_DIR/$base.req.json"
    [ -f "$req" ] || continue

    # Only green responses whose request carries applicable_rules are gated. Also
    # extract res.changed_files for ADR-0068 W-B narrowed re-run: when the response
    # names the files the inner loop touched, the live re-run scopes to those files
    # via enforce-file.sh (per CL-B W-B), instead of scanning the whole app_root.
    # Sidesteps smoke-fixture / contaminated-app-tree mismatch.
    gate_out=$(AE_RES="$res" AE_REQ="$req" node -e '
const fs=require("fs");
let res,req; try{res=JSON.parse(fs.readFileSync(process.env.AE_RES,"utf8"));req=JSON.parse(fs.readFileSync(process.env.AE_REQ,"utf8"));}catch(e){console.log("SKIP");process.exit(0);}
if(res.status!=="green"){console.log("SKIP");process.exit(0);}
if(!Array.isArray(req.applicable_rules)||req.applicable_rules.length===0){console.log("SKIP");process.exit(0);}
const cf=Array.isArray(res.changed_files)?res.changed_files.map(x=>(x&&typeof x==="object"&&x.path)?x.path:(typeof x==="string"?x:null)).filter(Boolean):[];
console.log("GATE|"+cf.join(","));
' 2>/dev/null)
    case "$gate_out" in
        GATE|GATE\|*) ;;
        *) continue ;;
    esac
    CHANGED_FILES_CSV="${gate_out#GATE|}"
    [ "$CHANGED_FILES_CSV" = "GATE" ] && CHANGED_FILES_CSV=""

    # Re-run via the same spine the inner loop uses. Narrow to changed_files when
    # present (W-B); tree-mode fallback when absent (Fix B parity preserved).
    if [ -n "$CHANGED_FILES_CSV" ]; then
        live=$(ES_HANDOFFS_DIR="$HANDOFFS_DIR" ES_APP_ROOT="$APP" "$ES_BIN" --ticket "$base" --app-root "$APP" --changed-files "$CHANGED_FILES_CSV" --json --quiet 2>/dev/null)
    else
        live=$(ES_HANDOFFS_DIR="$HANDOFFS_DIR" ES_APP_ROOT="$APP" "$ES_BIN" --ticket "$base" --app-root "$APP" --json --quiet 2>/dev/null)
    fi
    if [ -z "$live" ]; then
        printf '%s\n' "$base: could not re-run enforcement (no live report)" >> "$div_file"
        continue
    fi
    checked=$((checked + 1))

    out=$(AE_RES="$res" AE_LIVE="$live" node -e '
const fs=require("fs");
const res=JSON.parse(fs.readFileSync(process.env.AE_RES,"utf8"));
let live; try{live=JSON.parse(process.env.AE_LIVE);}catch(e){console.log("VIOL|live report not JSON");process.exit(0);}
const claimed=(res.rules_verified&&typeof res.rules_verified==="object")?res.rules_verified:{};
const lv=live.rules_verified||{}, fe=live.files_evaluated||{};
for(const rule of Object.keys(claimed)){
  if(!(rule in lv)){ console.log("VIOL|claims "+rule+"="+claimed[rule]+" but the live run did not evaluate it"); continue; }
  if(claimed[rule]!==lv[rule]) console.log("VIOL|claims "+rule+"="+claimed[rule]+" but live verdict is "+lv[rule]);
  if(lv[rule]==="pass" && !(fe[rule]>0)) console.log("VIOL|"+rule+" live pass but files_evaluated="+(fe[rule]||0)+" (vacuous — not a real pass)");
}
' 2>&1)
    nviol=$(printf '%s\n' "$out" | grep -c '^VIOL|' || true)
    if [ "$nviol" -gt 0 ]; then
        printf '%s\n' "$out" | sed -n 's/^VIOL|/'"$base"': /p' >> "$div_file"
    else
        emit "  [ok] $base: green claims match live detector verdicts ($APP)."
    fi
done

# Grandfather divergences recorded in the epoch baseline (pre-epoch legacy claims,
# ADR-0071); only NEW divergences fail the gate.
total_div=$(wc -l < "$div_file" | tr -d ' ')
if [ "$total_div" -gt 0 ]; then
    BASELINE=$(epoch_resolve_baseline standards-enforced)
    div_sorted=$(mktemp -t std-enf-cur.XXXXXX) || { printf 'audit-standards-enforced.sh: mktemp failed\n' >&2; exit 2; }
    sort "$div_file" > "$div_sorted"
    new_div=$(epoch_filter_new "$BASELINE" "$div_sorted")
    rm -f "$div_sorted"
    new_count=0
    [ -n "$new_div" ] && new_count=$(printf '%s\n' "$new_div" | grep -c . || true)
    grandfathered=$((total_div - new_count))
    if [ "$new_count" -gt 0 ]; then
        emit ""
        printf '%s\n' "$new_div" | sed 's/^/  [VIOLATION] /' | while IFS= read -r l; do emit "$l"; done
        emit ""
        emit "[standards-enforced] $new_count NEW divergence(s); $grandfathered grandfathered as pre-epoch (ADR-0071)."
        emit "  A green response's rules_verified MUST match a live detector re-run — no asserted/vacuous passes."
        exit 1
    fi
    emit "[standards-enforced] OK — $total_div divergence(s), all grandfathered as pre-epoch in the baseline (ADR-0071)."
    exit 0
fi
if [ "$checked" -eq 0 ]; then
    emit "[standards-enforced] no green response with applicable_rules to re-verify — vacuous pass."
else
    emit "[standards-enforced] OK — $checked green response(s) re-verified against live detectors ($APP)."
fi
exit 0
