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
#         .md                → g-doc-* + g-md-*       (g-md-* added per ADR-0066 D-B)
#         .tf/.tfvars        → g-hashicorp-* (provider-agnostic terraform; the
#                              provider namespace stays prose/consult-driven)
#         .yaml/.yml         → g-linux-foundation-*
#       Extensionless globs (whole-directory `**`) imply no language and are not
#       gated here (use typed globs to get the language floor — see the decompose
#       template). Over-scoping is SAFE: enforce.sh returns `not_applicable` for a
#       rule that matches no files, so a generous union never produces a false fail.
#   (3) PROSE PROJECTION (applies_to_prose) — when any `file_scope.may_edit` glob
#       has a `.md` extension, every rule in active.json carrying
#       `"applies_to_prose": true` MUST be in applicable_rules. This is the Layer-2
#       semantic projection from ADR-0066 D-B: code rules promoted by CTP to prose
#       enforcement bind on architectural MD by construction. Vacuous when no rule
#       carries the flag (i.e. before PROPOSAL-003 lands).
#   (4) 4-AXIS APPLIES-TO FLOOR (ADR-0068 W-A) — OPT-IN via `applies_to_floor_version`
#       integer marker on the req.json (set by post-CL-B /decompose + smoke-e2e
#       generators to >= 2). When opted in, every rule whose `applies_to.linguist_aliases`
#       OR `applies_to.iac_dialects` intersects the file_scope's canonical kinds MUST
#       be in applicable_rules. The ext→{linguist_alias, iac_dialect} map covers the
#       canonical kinds the 4-axis vocabulary uses (CTP §28.28). Content-driven
#       equivalent of (2): instead of joining by rule-id prefix convention (which can
#       drift), join by the rule's declared `applies_to.*` (the schema CTP ships at
#       pin 230e99d+). Composes with (2), never substitutes — a rule needed by either
#       floor must be present.
#
#       LEGACY HANDOFFS (no marker, or marker < 2) skip floor (4): grandfathered as
#       pre-CL-B-contract data per the no-rewrites discipline (ADR-0070 §No-rewrites).
#       Operator re-runs of /decompose on those tickets naturally produce post-CL-B
#       handoffs that carry the marker + the 4-axis rules. This preserves historical
#       handoff state while letting new tickets get the more accurate floor.
#
# EO non-exemptibility is enforced separately by `scripts/audit-eo-governance.sh`;
# this gate is the universal + language + 4-axis dimension of the same union.
#
# CONTENT-AGNOSTIC + VACUOUS when no req carries applicable_rules.
#
# Usage:
#   scripts/audit-applicable-rules.sh           # human-readable
#   scripts/audit-applicable-rules.sh --quiet   # exit code only
#
# ADR-0069 W-I — namespaces.yaml validation (auto-classification pipeline gate):
# When `.harness/operator-standards/namespaces.yaml` exists, this audit ALSO validates
# it conforms to the minimal schema CTP-ADR-0009 / ADR-0069 D-A requires (sources:[]
# with id + url + namespace per entry). Malformed shape = exit 1; missing file =
# vacuous (operator hasn't started using the auto-classification pipeline yet).
# Per ADR-0069: declared-source-only ingest — `gctp standards add` rejects
# undeclared URLs before any LLM cost. This audit is the back-stop.
#
# Env overrides (testability):
#   AAR_HANDOFFS_DIR  default .harness/handoffs
#   AAR_ACTIVE        default .harness/rules/active.json
#   AAR_NAMESPACES    default .harness/operator-standards/namespaces.yaml (W-I)
#
# Exit codes:
#   0  every gated ticket carries the universal + language floors (incl. vacuous);
#      namespaces.yaml (if present) is well-formed
#   1  one or more tickets under-scope a floor, OR namespaces.yaml is malformed
#   2  error (bad invocation / node missing when a req is present)
#
# Portability: bash 3.2 + BSD coreutils; node used only when a req or namespaces.yaml is present.

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
        -h|--help) sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'audit-applicable-rules.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

emit() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }

HANDOFFS_DIR="${AAR_HANDOFFS_DIR:-.harness/handoffs}"
ACTIVE="${AAR_ACTIVE:-.harness/rules/active.json}"
NAMESPACES="${AAR_NAMESPACES:-.harness/operator-standards/namespaces.yaml}"

# ADR-0069 W-I: validate namespaces.yaml shape if present (vacuous if absent).
ns_violations=0
if [ -f "$NAMESPACES" ]; then
    command -v node >/dev/null 2>&1 || { printf 'audit-applicable-rules.sh: node required for namespaces.yaml validation\n' >&2; exit 2; }
    ns_check=$(AAR_NS="$NAMESPACES" node -e '
const fs=require("fs");
const ns=fs.readFileSync(process.env.AAR_NS,"utf8");
// Minimal YAML parse: walk "sources:" list, each entry must declare id + url + namespace.
const lines=ns.split("\n");
let inSources=false, curEntry=null, entries=[];
for (const raw of lines) {
  const l=raw.replace(/#.*$/,"");
  if (/^sources\s*:\s*$/.test(l)) { inSources=true; continue; }
  if (inSources) {
    if (/^\S/.test(l) && l.trim().length > 0 && !/^\s*-/.test(l)) { inSources=false; continue; }
    const m1=l.match(/^\s*-\s*id\s*:\s*([\w\-.]+)\s*$/);
    if (m1) { if (curEntry) entries.push(curEntry); curEntry={id:m1[1]}; continue; }
    if (curEntry) {
      const mu=l.match(/^\s*url\s*:\s*(.+?)\s*$/);
      const mn=l.match(/^\s*namespace\s*:\s*(.+?)\s*$/);
      if (mu) curEntry.url=mu[1];
      if (mn) curEntry.namespace=mn[1];
    }
  }
}
if (curEntry) entries.push(curEntry);
if (!inSources && entries.length === 0) { console.log("ERR|namespaces.yaml: no `sources:` block found (CTP-ADR-0009 minimum schema)"); process.exit(0); }
for (const e of entries) {
  if (!e.url) { console.log("ERR|namespaces.yaml: source id="+e.id+" missing url"); }
  if (!e.namespace) { console.log("ERR|namespaces.yaml: source id="+e.id+" missing namespace"); }
}
if (entries.every(e => e.url && e.namespace)) console.log("OK|"+entries.length+" sources declared");
process.exit(0);
' 2>&1)
    if printf '%s' "$ns_check" | grep -q '^ERR|'; then
        printf '%s\n' "$ns_check" | sed -n 's/^ERR|/  [VIOLATION] /p' | while IFS= read -r l; do emit "$l"; done
        ns_violations=$(printf '%s\n' "$ns_check" | grep -c '^ERR|')
        emit ""
        emit "[applicable-rules] namespaces.yaml malformed — fix before running 'gctp standards add'."
        exit 1
    fi
    [ -n "$ns_check" ] && emit "[applicable-rules] namespaces.yaml: $(printf '%s' "$ns_check" | sed -n 's/^OK|//p')."
fi

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
const EXT={ts:["g-ts-","g-node-"],tsx:["g-ts-","g-node-","g-react-"],mts:["g-ts-","g-node-"],cts:["g-ts-","g-node-"],js:["g-node-"],jsx:["g-node-","g-react-"],mjs:["g-node-"],cjs:["g-node-"],md:["g-doc-","g-md-"],tf:["g-hashicorp-"],tfvars:["g-hashicorp-"],yaml:["g-linux-foundation-"],yml:["g-linux-foundation-"]};
const may=(req.file_scope&&Array.isArray(req.file_scope.may_edit))?req.file_scope.may_edit:[];
const prefixes=new Set();
const extsSeen=new Set();
for(const g of may){ const m=String(g).match(/\.([A-Za-z0-9]+)$/); if(m){ const e=m[1].toLowerCase(); extsSeen.add(e); if(EXT[e]) EXT[e].forEach(p=>prefixes.add(p)); } }
for(const p of prefixes){ for(const id of ids.filter(x=>x.startsWith(p))) if(!have.has(id)) errs.push("file_scope implies "+p+"* but applicable_rules omits: "+id); }
// (3) prose projection — fires when any .md glob is in file_scope.may_edit
if(extsSeen.has("md")){
  const rules=Array.isArray(active.rules)?active.rules:active;
  for(const r of rules){ if(r && r.applies_to_prose===true && r.id && !have.has(r.id)) errs.push("file_scope .md glob projects applies_to_prose rule: "+r.id); }
}
// (4) 4-axis applies_to floor — content-driven per ADR-0068 W-A.
// Opt-in: only enforced when req.applies_to_floor_version >= 2. Legacy handoffs
// (no marker, or marker < 2) skip this floor — grandfathered per the no-rewrites
// discipline (ADR-0070). New /decompose + smoke-e2e generators set the marker AND
// populate the 4-axis rules, so going-forward tickets get the more accurate floor
// without rewriting old handoffs.
const floorVer = (typeof req.applies_to_floor_version === "number") ? req.applies_to_floor_version : 1;
if (floorVer >= 2) {
  // ext → canonical linguist_alias + iac_dialect (covers the kinds CTP ships at pin 230e99d)
  const EXT_TO_LINGUIST={ts:["typescript"],tsx:["tsx","typescript"],mts:["typescript"],cts:["typescript"],js:["javascript"],jsx:["jsx","javascript"],mjs:["javascript"],cjs:["javascript"],md:["markdown"],tf:["hcl"],tfvars:["hcl"],yaml:["yaml"],yml:["yaml"],json:["json"],dockerfile:["dockerfile"],py:["python"],rb:["ruby"],go:["go"],sh:["shell"],bash:["shell"]};
  const EXT_TO_IAC={tf:["terraform"],tfvars:["terraform"]}; // .yaml dialects need content inspection; deferred to per-file kind detection (W-C)
  const kindsLinguist=new Set(), kindsIac=new Set();
  for(const e of extsSeen){
    (EXT_TO_LINGUIST[e]||[]).forEach(k=>kindsLinguist.add(k));
    (EXT_TO_IAC[e]||[]).forEach(k=>kindsIac.add(k));
  }
  if(kindsLinguist.size>0 || kindsIac.size>0){
    const rules=Array.isArray(active.rules)?active.rules:active;
    for(const r of rules){
      if(!r || !r.id || !r.applies_to) continue;
      const al=Array.isArray(r.applies_to.linguist_aliases)?r.applies_to.linguist_aliases:[];
      const ai=Array.isArray(r.applies_to.iac_dialects)?r.applies_to.iac_dialects:[];
      const hitsLinguist=al.some(a=>kindsLinguist.has(a));
      const hitsIac=ai.some(d=>kindsIac.has(d));
      if((hitsLinguist||hitsIac) && !have.has(r.id)) errs.push("file_scope kinds intersect rule applies_to.* but applicable_rules omits: "+r.id);
    }
  }
}
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
