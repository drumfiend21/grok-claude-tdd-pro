#!/usr/bin/env bash
# .claude/hooks/pre-tool-use-govern.sh — PreToolUse GOVERN-BEFORE-WRITE gate (CL-C / TICKET-102, ADR-0075).
#
# Wires CTP §28.60 `hooks/scripts/enforce-standards-pre-write.sh` as a PreToolUse DENY gate:
# an Edit/Write/MultiEdit whose PROPOSED content (reconstructed in memory) violates a P0/P1
# rule is DENIED (exit 2) before the file is written. Per the operator §4 decision (ADR-0072),
# the routed-tool path (`composite-dispatch.sh`) is ALSO run pre-write with parse-then-block
# (ADR-0068 W-C discipline) — forward-ready but INERT on bash 3.2 until upstream P-10 (the
# composite-dispatch `ra[@]` crash) is fixed.
#
# SCOPE (agent-operating-compact): governs ONLY writes under the app_root (the external product
# tree, via scripts/app-root.sh). Harness self-maintenance writes (this repo's own docs/scripts)
# are EXEMPT and pass through. With no `.harness/app.json` configured this hook is a vacuous no-op.
#
# Fail-open: any missing dep / unparseable input / defense-trip -> exit 0 (never block the session
# on a hook bug). Prime directive: the plugin scripts are consumed by reference, never edited.
#
# Overridable for tests: PREW_APP_ROOT_BIN, PREW_APP_ROOT, PREW_PLUGIN_ROOT.
# Exit codes: 0 allow (or out-of-scope / fail-open) | 2 deny (governed P0/P1 violation).

set -u
INPUT=$(cat)
command -v node >/dev/null 2>&1 || exit 0

parsed=$(printf '%s' "$INPUT" | node -e '
  let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
    try{const m=JSON.parse(d);const t=m.tool_name||"";const fp=(m.tool_input&&(m.tool_input.file_path||m.tool_input.path))||"";console.log(t+"\t"+fp);}catch(e){console.log("\t");}
  });' 2>/dev/null || printf '\t')
TOOL_NAME=$(printf '%s' "$parsed" | awk -F'\t' '{print $1}')
FILE_PATH=$(printf '%s' "$parsed" | awk -F'\t' '{print $2}')

case "$TOOL_NAME" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac
[ -n "$FILE_PATH" ] || exit 0

# --- app_root scoping: only govern the external product tree -----------------
APP_ROOT_BIN="${PREW_APP_ROOT_BIN:-scripts/app-root.sh}"
APP_ROOT=""
if [ -n "${PREW_APP_ROOT:-}" ]; then APP_ROOT="$PREW_APP_ROOT"
elif [ -x "$APP_ROOT_BIN" ]; then APP_ROOT=$("$APP_ROOT_BIN" 2>/dev/null) || APP_ROOT=""; fi
[ -n "$APP_ROOT" ] || exit 0    # no app_root configured -> vacuous no-op (this harness repo)

absroot=$(cd "$APP_ROOT" 2>/dev/null && pwd -P) || exit 0
absfile=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename "$FILE_PATH")") || absfile="$FILE_PATH"
case "$absfile" in
    "$absroot"/*) ;;                 # under app_root -> govern
    *) exit 0 ;;                     # harness self-maintenance / outside product -> exempt
esac

PLUGIN_ROOT="${PREW_PLUGIN_ROOT:-.harness/plugin-cache/claude-tdd-pro}"
absplugin=$(cd "$PLUGIN_ROOT" 2>/dev/null && pwd -P || printf '%s' "$PLUGIN_ROOT")

# --- Native pre-write gate — delegate to the plugin (§28.60) ------------------
NATIVE="$PLUGIN_ROOT/hooks/scripts/enforce-standards-pre-write.sh"
if [ -f "$NATIVE" ]; then
    nrc=0
    printf '%s' "$INPUT" | CLAUDE_PLUGIN_ROOT="$absplugin" bash "$NATIVE" || nrc=$?
    [ "$nrc" -eq 2 ] && exit 2      # native P0/P1 -> deny (the plugin already surfaced the message)
fi

# --- §4 tools pre-write — composite-dispatch, parse-then-block (inert until P-10) --
DISPATCH="$PLUGIN_ROOT/rubric/composite-dispatch.sh"
if [ -f "$DISPATCH" ]; then
    scratch=$(mktemp -d 2>/dev/null) || exit 0
    trap 'rm -rf "$scratch" 2>/dev/null' EXIT
    sfile=$(printf '%s' "$INPUT" | SCR="$scratch" node -e '
      const fs=require("fs"),path=require("path");
      let raw="";process.stdin.on("data",c=>raw+=c);process.stdin.on("end",()=>{
        let j;try{j=JSON.parse(raw);}catch{process.exit(0);}
        const ti=j.tool_input||{},tool=j.tool_name||"",fp=ti.file_path||ti.path||"";
        if(!fp)process.exit(0);
        const base=path.basename(fp);
        const rd=()=>{try{return fs.readFileSync(fp,"utf8");}catch{return "";}};
        const ap=(s,o,n,all)=>{if(o===undefined||o==="")return s;if(all)return s.split(o).join(n==null?"":n);const i=s.indexOf(o);return i<0?s:s.slice(0,i)+(n==null?"":n)+s.slice(i+o.length);};
        let c=null;
        if(tool==="Write")c=ti.content!=null?String(ti.content):"";
        else if(tool==="Edit")c=ap(rd(),ti.old_string,ti.new_string,!!ti.replace_all);
        else if(tool==="MultiEdit"){let x=rd();for(const e of(ti.edits||[]))x=ap(x,e.old_string,e.new_string,!!e.replace_all);c=x;}
        else process.exit(0);
        if(c==null)process.exit(0);
        const out=path.join(process.env.SCR,base);
        try{fs.writeFileSync(out,c);}catch{process.exit(0);}
        process.stdout.write(out);
      });' 2>/dev/null)
    if [ -n "$sfile" ] && [ -f "$sfile" ]; then
        disp_out=$(CLAUDE_PLUGIN_ROOT="$absplugin" bash "$DISPATCH" --file "$sfile" 2>&1 >/dev/null)
        # Parse-then-block: a bare non-zero exit (e.g. the P-10 bash-3.2 crash) is NOT a verdict.
        if printf '%s' "$disp_out" | grep -qE '^composite-dispatch[[:space:]]+.*\bstatus=red\b'; then
            printf 'PreToolUse govern-before-write: composite-engine P0 in %s (routed tools).\n' "$FILE_PATH" >&2
            printf '%s\n' "$disp_out" | grep -E '^composite-dispatch' | sed 's/^/  /' >&2
            printf '  Fix the violation or add a deviation row to <app_root>/docs/deviations.md (ADR-0066 D-F).\n' >&2
            exit 2
        fi
    fi
fi

exit 0
