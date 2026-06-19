#!/usr/bin/env bash
# scripts/audit-applicable-rules.sh — static gate over handoff `applicable_rules`
# scoping ("Fix A" from the GCTP O'Reilly-kata feedback; PROPOSAL-002 / ADR-0060).
#
# The kata's root failure: code tickets carried only `g-node-001`/`g-node-008` —
# the full language ruleset was never scoped, so detectors that were never named
# were never run. This gate makes the under-scoping a RED, statically, per ticket.
#
# For every `.harness/handoffs/*.req.json` whose `applicable_rules` is present, it
# asserts two floors (computed live from `.harness/rules/active.json` — content-
# agnostic, so new catalog rules are picked up automatically):
#
#   (1) UNIVERSAL apply-by-default floor — every `g-universal-*` rule in active.json
#       MUST be in applicable_rules, regardless of language/file_scope. These apply
#       to all generated software by default (CTP §28.21); omitting one is the new
#       under-scoping. (The withheld set is CTP's `audit-universality-coverage.sh`,
#       currently empty.)
#   (2) LANGUAGE floor — for every `file_scope.may_edit` glob carrying an explicit
#       extension, the rule-id prefixes that language implies MUST be fully present:
#         .ts/.tsx/.mts/.cts → g-ts-* + g-node-*      (.tsx/.jsx also → g-react-*)
#         .js/.jsx/.mjs/.cjs → g-node-*
#         .md                → g-doc-*
#         .tf/.tfvars        → g-hashicorp-* (provider-agnostic terraform; the
#                              provider namespace stays prose/consult-driven)
#         .yaml/.yml         → g-linux-foundation-*
#       Extensionless globs (whole-directory `**`) imply no language and are not
#       gated here (use typed globs to get the language floor — see the decompose
#       template). Over-scoping is SAFE: enforce.sh returns `not_applicable` for a
#       rule that matches no files, so a generous union never produces a false fail.
#
# EO non-exemptibility is enforced separately by `scripts/audit-eo-governance.sh`;
# this gate is the universal + language dimension of the same union.
#
# CONTENT-AGNOSTIC + VACUOUS when no req carries applicable_rules.
#
# Usage:
#   scripts/audit-applicable-rules.sh           # human-readable
#   scripts/audit-applicable-rules.sh --quiet   # exit code only
#
# Env overrides (testability):
#   AAR_HANDOFFS_DIR  default .harness/handoffs
#   AAR_ACTIVE        default .harness/rules/active.json
#
# Exit codes:
#   0  every gated ticket carries the universal + language floors (incl. vacuous)
#   1  one or more tickets under-scope a floor
#   2  error (bad invocation / node missing when a req is present)
#
# Portability: bash 3.2 + BSD coreutils; node used only when a req is present.

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet)   QUIET=1 ;;
        -h|--help) sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-applicable-rules.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

HANDOFFS_DIR="${AAR_HANDOFFS_DIR:-.harness/handoffs}"
ACTIVE="${AAR_ACTIVE:-.harness/rules/active.json}"

if [ ! -f "$ACTIVE" ]; then
    emit "[applicable-rules] no rule registry at $ACTIVE — vacuous pass (nothing to scope against)."
    exit 0
fi

have=0
if [ -d "$HANDOFFS_DIR" ]; then
    for req in "$HANDOFFS_DIR"/*.req.json; do [ -e "$req" ] && have=1 && break; done
fi
if [ "$have" -eq 0 ]; then
    emit "[applicable-rules] no request artifacts in $HANDOFFS_DIR — vacuous pass."
    exit 0
fi

command -v node >/dev/null 2>&1 || { printf 'audit-applicable-rules.sh: node required\n' >&2; exit 2; }

violations=0
for req in "$HANDOFFS_DIR"/*.req.json; do
    [ -e "$req" ] || continue
    out=$(AAR_REQ="$req" AAR_ACTIVE="$ACTIVE" node -e '
const fs=require("fs");
let active, req;
try { active=JSON.parse(fs.readFileSync(process.env.AAR_ACTIVE,"utf8")); } catch(e){ console.log("ERR|active.json not JSON: "+e.message); process.exit(0); }
try { req=JSON.parse(fs.readFileSync(process.env.AAR_REQ,"utf8")); } catch(e){ console.log("ERR|"+process.env.AAR_REQ+" not JSON: "+e.message); process.exit(0); }
const ids=(Array.isArray(active.rules)?active.rules:active).map(r=>r.id).filter(Boolean);
const appl=Array.isArray(req.applicable_rules)?req.applicable_rules:null;
if(appl===null){ console.log("NOTE|no applicable_rules (not gated)"); process.exit(0); }
const have=new Set(appl);
const errs=[];
// (1) universal apply-by-default floor
for(const u of ids.filter(x=>x.startsWith("g-universal-"))) if(!have.has(u)) errs.push("omits apply-by-default universal rule: "+u);
// (2) language floor from typed globs
const EXT={ts:["g-ts-","g-node-"],tsx:["g-ts-","g-node-","g-react-"],mts:["g-ts-","g-node-"],cts:["g-ts-","g-node-"],js:["g-node-"],jsx:["g-node-","g-react-"],mjs:["g-node-"],cjs:["g-node-"],md:["g-doc-"],tf:["g-hashicorp-"],tfvars:["g-hashicorp-"],yaml:["g-linux-foundation-"],yml:["g-linux-foundation-"]};
const may=(req.file_scope&&Array.isArray(req.file_scope.may_edit))?req.file_scope.may_edit:[];
const prefixes=new Set();
for(const g of may){ const m=String(g).match(/\.([A-Za-z0-9]+)$/); if(m){ const e=m[1].toLowerCase(); if(EXT[e]) EXT[e].forEach(p=>prefixes.add(p)); } }
for(const p of prefixes){ for(const id of ids.filter(x=>x.startsWith(p))) if(!have.has(id)) errs.push("file_scope implies "+p+"* but applicable_rules omits: "+id); }
for(const e of errs) console.log("VIOL|"+e);
process.exit(0);
' 2>&1)
    if printf '%s' "$out" | grep -q '^ERR|'; then
        emit "  [VIOLATION] $(basename "$req"): $(printf '%s' "$out" | sed -n 's/^ERR|//p' | head -1)"
        violations=$((violations + 1)); continue
    fi
    nviol=$(printf '%s\n' "$out" | grep -c '^VIOL|' || true)
    if [ "$nviol" -gt 0 ]; then
        printf '%s\n' "$out" | sed -n 's/^VIOL|/  [VIOLATION] '"$(basename "$req")"': /p' | while IFS= read -r line; do emit "$line"; done
        violations=$((violations + nviol))
    elif printf '%s' "$out" | grep -q '^NOTE|'; then
        emit "  [ok] $(basename "$req"): $(printf '%s' "$out" | sed -n 's/^NOTE|//p' | head -1)"
    else
        emit "  [ok] $(basename "$req"): universal + language floors satisfied."
    fi
done

if [ "$violations" -gt 0 ]; then
    emit ""
    emit "[applicable-rules] $violations under-scoping violation(s). Every ticket MUST carry all"
    emit "  g-universal-* rules (apply-by-default) + the language floor for each typed file_scope glob."
    exit 1
fi
emit "[applicable-rules] OK — every ticket's applicable_rules satisfies the universal + language floors."
exit 0
