#!/usr/bin/env bash
# scripts/enforce-standards.sh — Fix B: produce a ticket's `rules_verified` from
# REAL CTP detector results, by running the plugin's enforce.sh against the app_root.
#
# Per TICKET-073 / ADR-0062 (PROPOSAL-002 GCTP-side of the O'Reilly-kata loop). The
# kata failure: `rules_verified` was *asserted* in the response, never produced by a
# detector run. This script closes that — the inner loop calls it between Green and
# writing the .res.json, and writes `rules_verified` STRAIGHT from its output.
#
# It is the consumer of CTP's frozen contract (Fix E / ADR-0058): it resolves the
# external app tree (scripts/app-root.sh, Fix D / ADR-0059) and runs
#   enforce.sh --root <app_root> --rules <ticket applicable_rules> --json
# then maps the per-rule 4-state verdict (pass | fail | not_applicable | not_enforced)
# straight into rules_verified. The mapping is faithful, not lenient:
#   pass            → green-eligible (the detector ran, ≥1 file, 0 findings)
#   not_applicable  → green-eligible NEUTRAL (rule matched no files; never a vacuous pass)
#   fail            → RED
#   not_enforced    → RED (claimed applicable, detector could not verify — tool/model absent)
#   unknown_rule    → RED (id not in the catalog — a scoping/config error)
#
# Usage:
#   scripts/enforce-standards.sh --ticket TICKET-NNN [--app-root <dir>] [--json] [--quiet]
#                                [--changed-files <csv>]
#     --ticket          read .harness/handoffs/<id>.req.json for applicable_rules (required)
#     --app-root        override the app tree (else resolved via scripts/app-root.sh)
#     --json            emit the rules_verified report JSON to stdout
#     --quiet           exit code only
#     --changed-files   ADR-0068 W-B narrowing: CSV of paths (absolute, or relative to
#                       app_root, or relative to pwd). When present, the live re-run
#                       targets only those files via CTP's per-file rubric/enforce-file.sh
#                       (instead of the whole-tree rubric/enforce.sh). Aggregates
#                       per-rule worst verdict across the file set (fail > not_enforced
#                       > pass); files_evaluated[rule] = count of changed files probed.
#                       Scopes re-verification to the inner-loop's actual changes —
#                       sidesteps contaminated-app-tree noise for smoke fixtures.
#
# Env overrides (testability):
#   ES_HANDOFFS_DIR  default .harness/handoffs
#   ES_PLUGIN_ROOT   default .harness/plugin-cache/claude-tdd-pro
#   ES_ENFORCE       default $ES_PLUGIN_ROOT/rubric/enforce.sh
#   ES_ENFORCE_FILE  default $ES_PLUGIN_ROOT/rubric/enforce-file.sh (W-B narrowing)
#   ES_APP_ROOT      override app_root resolution (validated by app-root.sh --validate)
#   ES_APP_ROOT_BIN  default ./scripts/app-root.sh
#
# Exit codes:
#   0  green     — every rule pass or not_applicable
#   1  red       — at least one fail (or unknown_rule)
#   3  incomplete— no fail, but at least one not_enforced (never collapses to green)
#   2  error     — bad invocation / no request / enforce.sh missing / ruby/node missing
#
# Portability: bash 3.2 + BSD coreutils. enforce.sh is Ruby-backed (ADR-0056
# prerequisite); node is used for JSON mapping.

set -u

QUIET=0; JSON=0; TICKET=""; APP_OVERRIDE=""; CHANGED_FILES=""
while [ $# -gt 0 ]; do
    case "$1" in
        --ticket)         TICKET="${2-}"; shift ;;
        --app-root)       APP_OVERRIDE="${2-}"; shift ;;
        --changed-files)  CHANGED_FILES="${2-}"; shift ;;
        --json)           JSON=1 ;;
        --quiet)          QUIET=1 ;;
        -h|--help)        sed -n '2,52p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'enforce-standards.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
err()  { printf '%s\n' "$*" >&2; }

[ -n "$TICKET" ] || { err "enforce-standards.sh: --ticket TICKET-NNN required"; exit 2; }

HANDOFFS_DIR="${ES_HANDOFFS_DIR:-.harness/handoffs}"
PLUGIN_ROOT="${ES_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
ENFORCE="${ES_ENFORCE:-$PLUGIN_ROOT/rubric/enforce.sh}"
ENFORCE_FILE="${ES_ENFORCE_FILE:-$PLUGIN_ROOT/rubric/enforce-file.sh}"
APP_ROOT_BIN="${ES_APP_ROOT_BIN:-./scripts/app-root.sh}"

REQ="$HANDOFFS_DIR/$TICKET.req.json"
[ -f "$REQ" ] || { err "enforce-standards.sh: no request at $REQ"; exit 2; }
if [ -n "$CHANGED_FILES" ]; then
    [ -f "$ENFORCE_FILE" ] || { err "enforce-standards.sh: enforce-file.sh not found at $ENFORCE_FILE (run scripts/sync-plugin.sh --ensure)"; exit 2; }
else
    [ -f "$ENFORCE" ] || { err "enforce-standards.sh: enforce.sh not found at $ENFORCE (run scripts/sync-plugin.sh --ensure)"; exit 2; }
fi
command -v node >/dev/null 2>&1 || { err "enforce-standards.sh: node required"; exit 2; }
# Ruby is required only for the real (default) enforce.sh / enforce-file.sh — both
# Ruby-backed (ADR-0056). When ES_ENFORCE/ES_ENFORCE_FILE is overridden (e.g. a
# test stub), Ruby is not needed.
if [ -z "${ES_ENFORCE:-}" ] && [ -z "${ES_ENFORCE_FILE:-}" ]; then
    command -v ruby >/dev/null 2>&1 || { err "enforce-standards.sh: ruby required (enforce.sh/enforce-file.sh are Ruby-backed; ADR-0056)"; exit 2; }
fi

# Resolve + hard-guard the app_root (Fix D).
RESOLVE="${ES_APP_ROOT:-$APP_OVERRIDE}"
if [ -n "$RESOLVE" ]; then
    APP=$("$APP_ROOT_BIN" --validate "$RESOLVE") || { err "enforce-standards.sh: app_root invalid/empty: $RESOLVE"; exit 2; }
else
    APP=$("$APP_ROOT_BIN") || { err "enforce-standards.sh: app_root unresolved (configure .harness/app.json or pass --app-root)"; exit 2; }
fi

# Extract the ticket's applicable_rules as a CSV.
RULES_CSV=$(AAR_REQ="$REQ" node -e '
const fs=require("fs");
let r; try{ r=JSON.parse(fs.readFileSync(process.env.AAR_REQ,"utf8")); }catch(e){ process.exit(7); }
const a=Array.isArray(r.applicable_rules)?r.applicable_rules:[];
process.stdout.write(a.join(","));
') || { err "enforce-standards.sh: $REQ not valid JSON"; exit 2; }

if [ -z "$RULES_CSV" ]; then
    # No applicable_rules → nothing to enforce; emit an empty, green report.
    emit "[enforce-standards] $TICKET: no applicable_rules — nothing to enforce (green, empty)."
    [ "$JSON" -eq 1 ] && printf '{"ticket_id":"%s","app_root":"%s","rules_verified":{},"files_evaluated":{},"status":"green"}\n' "$TICKET" "$APP"
    exit 0
fi

if [ -n "$CHANGED_FILES" ]; then
    # W-B narrowed mode: invoke CTP's per-file enforce-file.sh on each changed file
    # and aggregate per-rule worst verdict (fail > not_enforced > pass). Each file is
    # tried as: absolute (as-is), relative to app_root, or relative to pwd — the
    # production case is app_root-relative; smoke fixtures (TICKET-042-style) are
    # pwd-relative because they edit files inside the GCTP repo itself.
    PER_FILE_STDERR=""
    NUM_FILES=0
    PWD_ABS=$(pwd -P)
    OLDIFS="$IFS"; IFS=','
    for f in $CHANGED_FILES; do
        [ -n "$f" ] || continue
        ABS=""
        case "$f" in
            /*) [ -f "$f" ] && ABS="$f" ;;
            *)  if   [ -f "$APP/$f" ];     then ABS="$APP/$f"
                elif [ -f "$PWD_ABS/$f" ]; then ABS="$PWD_ABS/$f"
                fi ;;
        esac
        if [ -z "$ABS" ]; then
            PER_FILE_STDERR="${PER_FILE_STDERR}enforce-file file=$f status=na rules_checked=0
"
            continue
        fi
        NUM_FILES=$((NUM_FILES + 1))
        # --root passed for context; enforce-file.sh does its own per-file rule discovery.
        FILE_OUT=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$ENFORCE_FILE" --file "$ABS" --root "$APP" 2>&1 >/dev/null) || true
        PER_FILE_STDERR="${PER_FILE_STDERR}${FILE_OUT}
"
    done
    IFS="$OLDIFS"

    # Aggregate to the same {rules_verified, files_evaluated, status} shape that
    # tree-mode produces. For rules in the applicable_rules CSV:
    #   * worst verdict wins across files (fail > not_enforced > pass)
    #   * absence of per-rule signal = pass (rule was probed via enforce-file but
    #     produced no fail/not_enforced output → clean)
    #   * files_evaluated[rule] = NUM_FILES (every applicable rule was checked
    #     against every changed file by the enforce-file pipeline)
    REPORT=$(ES_TICKET="$TICKET" ES_APP="$APP" ES_RULES="$RULES_CSV" ES_NUM="$NUM_FILES" ES_PFSE="$PER_FILE_STDERR" node -e '
const ticket=process.env.ES_TICKET, app=process.env.ES_APP;
const rules=(process.env.ES_RULES||"").split(",").filter(Boolean);
const numFiles=parseInt(process.env.ES_NUM||"0",10);
const lines=(process.env.ES_PFSE||"").split("\n").filter(l=>l.indexOf("enforce-file ")===0);
const ruleVerdict={};
for (const id of rules) ruleVerdict[id]="pass";
const rank={pass:0,not_enforced:1,fail:2};
for (const l of lines) {
  const m = l.match(/\brule=(\S+).*\bverdict=(\S+)/);
  if (!m) continue;
  const id=m[1]; const v=m[2];
  if (!(id in ruleVerdict)) continue;
  // "warn" stays pass (advisory at write-time per enforce-file.sh semantics)
  const norm = (v==="fail"?"fail":(v==="not_enforced"?"not_enforced":(v==="warn"?"pass":"pass")));
  if (rank[norm] > rank[ruleVerdict[id]]) ruleVerdict[id]=norm;
}
const rv={}, fe={};
for (const id of rules) { rv[id]=ruleVerdict[id]; fe[id]=numFiles; }
let red=0, incomplete=0;
for (const v of Object.values(rv)) { if (v==="fail") red++; else if (v==="not_enforced") incomplete++; }
const status = red>0 ? "red" : (incomplete>0 ? "incomplete" : "green");
console.log(JSON.stringify({ticket_id:ticket, app_root:app, rules_verified:rv, files_evaluated:fe, status}));
')
else
    # Tree-mode (Fix B / ADR-0062 default). Frozen enforce.sh against whole app_root.
    ENFORCE_OUT=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$ENFORCE" --root "$APP" --rules "$RULES_CSV" --json 2>/dev/null)

    # Map the 4-state output into rules_verified + an overall status.
    REPORT=$(ES_TICKET="$TICKET" ES_APP="$APP" ES_OUT="$ENFORCE_OUT" node -e '
const out=process.env.ES_OUT;
let j; try{ j=JSON.parse(out); }catch(e){ console.log("PARSE_ERR"); process.exit(0); }
const rv={}, fe={};
let red=0, incomplete=0;
for(const r of (j.results||[])){
  rv[r.rule]=r.verdict;
  fe[r.rule]=(typeof r.files_evaluated==="number")?r.files_evaluated:0;
  if(r.verdict==="fail"||r.verdict==="unknown_rule") red++;
  else if(r.verdict==="not_enforced") incomplete++;
}
const status = red>0 ? "red" : (incomplete>0 ? "incomplete" : "green");
console.log(JSON.stringify({ticket_id:process.env.ES_TICKET, app_root:process.env.ES_APP, rules_verified:rv, files_evaluated:fe, status}));
')
fi

if [ "$REPORT" = "PARSE_ERR" ] || [ -z "$REPORT" ]; then
    err "enforce-standards.sh: enforce.sh produced no parseable JSON (root=$APP rules=$RULES_CSV)"
    exit 2
fi

[ "$JSON" -eq 1 ] && printf '%s\n' "$REPORT"

STATUS=$(ES_R="$REPORT" node -e 'process.stdout.write(JSON.parse(process.env.ES_R).status)')
if [ "$QUIET" -eq 0 ]; then
    printf '%s\n' "$REPORT" | node -e '
const fs=require("fs");let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{
const j=JSON.parse(s);
console.log("[enforce-standards] "+j.ticket_id+" on "+j.app_root+" → status="+j.status);
for(const k of Object.keys(j.rules_verified)) console.log("   "+k+" = "+j.rules_verified[k]+" (files:"+j.files_evaluated[k]+")");
});'
fi

case "$STATUS" in
    green)      exit 0 ;;
    red)        exit 1 ;;
    incomplete) exit 3 ;;
    *)          exit 2 ;;
esac
