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

violations=0
checked=0
for res in "$HANDOFFS_DIR"/*.res.json; do
    [ -e "$res" ] || continue
    base=$(basename "$res" .res.json)
    req="$HANDOFFS_DIR/$base.req.json"
    [ -f "$req" ] || continue

    # Only green responses whose request carries applicable_rules are gated.
    gate=$(AE_RES="$res" AE_REQ="$req" node -e '
const fs=require("fs");
let res,req; try{res=JSON.parse(fs.readFileSync(process.env.AE_RES,"utf8"));req=JSON.parse(fs.readFileSync(process.env.AE_REQ,"utf8"));}catch(e){console.log("SKIP");process.exit(0);}
if(res.status!=="green"){console.log("SKIP");process.exit(0);}
if(!Array.isArray(req.applicable_rules)||req.applicable_rules.length===0){console.log("SKIP");process.exit(0);}
console.log("GATE");
' 2>/dev/null)
    [ "$gate" = "GATE" ] || continue

    # Re-run the detectors via the same spine the inner loop uses.
    live=$(ES_HANDOFFS_DIR="$HANDOFFS_DIR" ES_APP_ROOT="$APP" "$ES_BIN" --ticket "$base" --app-root "$APP" --json --quiet 2>/dev/null)
    if [ -z "$live" ]; then
        emit "  [VIOLATION] $base: could not re-run enforcement (no live report)"
        violations=$((violations + 1)); continue
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
        printf '%s\n' "$out" | sed -n 's/^VIOL|/  [VIOLATION] '"$base"': /p' | while IFS= read -r l; do emit "$l"; done
        violations=$((violations + nviol))
    else
        emit "  [ok] $base: green claims match live detector verdicts ($APP)."
    fi
done

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[standards-enforced] $violations divergence(s). A green response's rules_verified MUST match a"
    emit "  live detector re-run against the app_root — no asserted passes, no vacuous (0-file) passes."
    exit 1
fi
if [ "$checked" -eq 0 ]; then
    emit "[standards-enforced] no green response with applicable_rules to re-verify — vacuous pass."
else
    emit "[standards-enforced] OK — $checked green response(s) re-verified against live detectors ($APP)."
fi
exit 0
