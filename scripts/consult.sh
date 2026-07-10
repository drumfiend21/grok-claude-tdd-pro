#!/usr/bin/env bash
# scripts/consult.sh — GCTP→CTP architecture-consult preflight + engine locator.
#
# Per TICKET-063 / ADR-0056. The interactive per-juncture consult LOOP (intake →
# consult CTP → translate → prompt user → decide → size+ticket → cross-check) is
# driven by the `/consult` command (agent-run). This script is the deterministic,
# testable spine that command relies on:
#
#   --preflight            Verify the loop's hard prerequisites (ADR-0056 D-D):
#                          ruby >= 3.0 on PATH AND CTP's architecture engine present
#                          in the pinned plugin cache. Exit 0 only if both hold.
#   --engine-path <name>   Resolve + print the path to a CTP engine script.
#                          Allowlist: the v1.0 quartet (architect-session.sh /
#                          business-intake.sh / architect-recommend.sh /
#                          well-architected-review.sh) AND the v1.1 pair
#                          (full-surface-intake.sh / full-surface-consult.sh)
#                          shipped by CTP at pin f060a8e+ (§30 / §30.1). All
#                          six must be present in the pinned plugin cache at
#                          preflight — a pre-P-12 rollback is not supported by
#                          the /consult skill (KA-1 G-2 close-out).
#   --validate <file>      Validate a consult artifact (FEATURE-NNN.architecture.json)
#                          against docs/handoff-contract.md §Architecture-Consult-Loop:
#                          schema_version=="1", needs_grounding==0, ruby_ok!=false, and
#                          every decisions[] entry sized (complexity ∈ {small,medium,large})
#                          with a non-empty applicable_rules. /decompose runs this before
#                          consuming an artifact (A-4). Requires node (JSON parse).
#   --validate-profile <file>
#                          Validate a business-profile.json against
#                          docs/handoff-contract.md §Business-Intake. Auto-detects
#                          schema_version:
#                            "1.0" — verify answers.workload + grounded_in non-empty
#                                    + complete flag present (existing shape unchanged).
#                            "1.1" — v1.0 checks PLUS workload_classification present
#                                    (workload_types + namespaces + activated_probe_namespaces
#                                    arrays); every activated probe namespace has a
#                                    probes.<namespace> block with ≥ 1 answer;
#                                    grounded_in_namespaces ⊆ activated_probe_namespaces
#                                    with each entry backed by an answered probe.
#                          Universal 9 live in `answers` (universal-stays-universal —
#                          S-57 does not introduce a probes.universal block). Missing
#                          schema_version treated as "1.0". TICKET-114 / ADR-0087;
#                          resolved at CTP pin f060a8e (S-57 / §2.35 / §30).
#                          §30.2 (CTP pin 43ea692+, ADR-0089): tolerates the additive
#                          optional workload_classification.unprobed_in_scope field —
#                          absent ⇒ pre-§30.2 profile ⇒ pass unchanged; present ⇒
#                          must be a string array, ⊆ namespaces, disjoint from
#                          activated_probe_namespaces.
#                          Requires node.
#   --roadmap <file>       Stage 7 of the loop: render a contract-valid consult artifact's
#                          decisions[] as a roadmap (docs/handoff-contract.md §Roadmap) —
#                          real chunks, sized, topologically sequenced over depends_on,
#                          each annotated with applicable_rules + grounding. Emits a
#                          human-readable roadmap AND the §Roadmap JSON block on stdout.
#                          Re-validates first (refuses to render an invalid artifact) and
#                          rejects dependency cycles. /decompose assigns final TICKET-NNN
#                          ids; this presents the junctures as the prospective tickets.
#                          Requires node.
#
# It does NOT invoke CTP's engine or mutate anything — it locates + gates, so the
# agent (or a later CL) can drive the engine with confidence. Additive (ADR-0056):
# absent ruby is a hard stop-and-remediate, never a silent static-context fallback
# for external-project design.
#
# Env overrides (testability):
#   CONSULT_RUBY_BIN       default "ruby" — the ruby executable to probe
#   CONSULT_PLUGIN_CACHE   default ".harness/plugin-cache/claude-tdd-pro"
#   CONSULT_MIN_RUBY       default "3.0" — minimum major.minor
#
# Exit codes:
#   0  ok (preflight prereqs hold / engine-path resolved / artifact valid / roadmap rendered)
#   1  prerequisite missing (ruby absent/old, engine script not found) OR artifact invalid
#      OR roadmap not renderable (invalid artifact / dependency cycle)
#   2  usage error (bad invocation, missing file/arg)
#
# Portability: bash 3.2 + BSD coreutils. ruby probed; node used for --validate/--roadmap.

set -u

RUBY_BIN="${CONSULT_RUBY_BIN:-ruby}"
PLUGIN_CACHE="${CONSULT_PLUGIN_CACHE:-.harness/plugin-cache/claude-tdd-pro}"
MIN_RUBY="${CONSULT_MIN_RUBY:-3.0}"
# v1.0 quartet + v1.1 pair (full-surface intake + design-consult). The v1.1 pair
# was added to the allowlist to close KA-1 G-2: at pin f060a8e+ CTP ships
# full-surface-intake.sh (§30 / S-57) and full-surface-consult.sh (§30.1) as
# first-class engines the /consult skill and kata.sh drive; the spine's
# --engine-path must resolve them alongside the v1.0 quartet, else callers have
# to reach around the spine to the absolute plugin-cache path (contract-surface
# leak, prime-directive-adjacent). All 6 must be present in the pinned plugin
# cache at preflight (rollback to a pre-P-12 pin is not supported by /consult).
ENGINE_SCRIPTS="architect-session.sh business-intake.sh architect-recommend.sh well-architected-review.sh full-surface-intake.sh full-surface-consult.sh"

emit() { printf '%s\n' "$*"; }

usage() {
    sed -n '2,47p' "$0" | sed 's/^# \{0,1\}//' >&2
}

# ruby_ok: prints resolved version on stdout, returns 0 if >= MIN_RUBY, else 1.
ruby_ok() {
    command -v "$RUBY_BIN" >/dev/null 2>&1 || return 1
    local ver
    ver=$("$RUBY_BIN" -e 'print RUBY_VERSION' 2>/dev/null) || ver=""
    [ -n "$ver" ] || return 1
    # Compare major.minor numerically (bash 3.2; no associative arrays).
    local want_major want_minor got_major got_minor
    want_major=${MIN_RUBY%%.*}; want_minor=${MIN_RUBY#*.}; want_minor=${want_minor%%.*}
    got_major=${ver%%.*};       got_minor=${ver#*.};       got_minor=${got_minor%%.*}
    printf '%s' "$ver"
    [ "$got_major" -gt "$want_major" ] && return 0
    [ "$got_major" -lt "$want_major" ] && return 1
    [ "$got_minor" -ge "$want_minor" ] && return 0
    return 1
}

engine_path() {
    local name="$1" p="$PLUGIN_CACHE/commands/$1"
    case " $ENGINE_SCRIPTS " in *" $name "*) : ;; *) return 1 ;; esac
    [ -f "$p" ] || return 1
    printf '%s\n' "$p"
    return 0
}

[ $# -ge 1 ] || { usage; exit 2; }

case "$1" in
    --preflight)
        rc=0
        ver=$(ruby_ok); rstat=$?
        if [ "$rstat" -eq 0 ]; then
            emit "  ✓ ruby ${ver} (>= ${MIN_RUBY})"
        else
            emit "  ✗ ruby >= ${MIN_RUBY} required on PATH (CTP's architecture engine is Ruby-backed)."
            emit "    Install ruby >= ${MIN_RUBY} and re-run — the consult loop will not run without it (ADR-0056)."
            rc=1
        fi
        missing=""
        for s in $ENGINE_SCRIPTS; do
            [ -f "$PLUGIN_CACHE/commands/$s" ] || missing="$missing $s"
        done
        if [ -z "$missing" ]; then
            emit "  ✓ CTP architecture engine present ($PLUGIN_CACHE/commands/)"
        else
            emit "  ✗ CTP engine script(s) missing:$missing — run scripts/sync-plugin.sh --ensure"
            rc=1
        fi
        [ "$rc" -eq 0 ] && emit "[consult] preflight OK — ready to run the architecture-consult loop."
        exit "$rc"
        ;;
    --engine-path)
        [ $# -ge 2 ] || { usage; exit 2; }
        if engine_path "$2"; then exit 0; else
            printf 'consult.sh: engine script not found or not allowed: %s\n' "$2" >&2; exit 1
        fi
        ;;
    --validate-profile)
        [ $# -ge 2 ] || { usage; exit 2; }
        [ -f "$2" ] || { printf 'consult.sh: profile not found: %s\n' "$2" >&2; exit 2; }
        command -v node >/dev/null 2>&1 || { printf 'consult.sh: node required for --validate-profile\n' >&2; exit 2; }
        # Validate a business-profile.json against docs/handoff-contract.md §Business-Intake.
        # Auto-detects schema_version. v1.0 checks unchanged; v1.1 adds classifier + probes
        # + grounded_in_namespaces invariants (universal-stays-universal — universal 9 live
        # in `answers`, not `probes.universal`). Reconciled to CTP's shipped shape (S-57 /
        # §2.35 / §30) at pin f060a8e per ADR-0087. env-var-first (no argv quoting);
        # process.exit only (bash32/node portability). Backward-compat: absent
        # schema_version → treat as "1.0".
        CONSULT_PROFILE="$2" node -e '
const fs = require("fs");
let p;
try { p = JSON.parse(fs.readFileSync(process.env.CONSULT_PROFILE, "utf8")); }
catch (e) { console.error("[consult --validate-profile] INVALID: not JSON (" + e.message + ")"); process.exit(1); }
const sv = p.schema_version || "1.0";
const errs = [];
// v1.0 baseline (also applies to v1.1 — universal-stays-universal in `answers`).
const answers = (p && p.answers) || {};
if (!answers.workload || !String(answers.workload).trim()) errs.push("answers.workload missing/empty");
if (!Array.isArray(p.grounded_in) || p.grounded_in.length < 1) errs.push("grounded_in empty");
if (typeof p.complete === "undefined") errs.push("complete flag missing");
if (sv === "1.0") {
  // done — v1.0 stops here.
} else if (sv === "1.1") {
  const wc = p.workload_classification || {};
  if (!Array.isArray(wc.workload_types)) errs.push("workload_classification.workload_types not an array");
  if (!Array.isArray(wc.namespaces))     errs.push("workload_classification.namespaces not an array");
  const activated = Array.isArray(wc.activated_probe_namespaces) ? wc.activated_probe_namespaces : null;
  if (!activated) errs.push("workload_classification.activated_probe_namespaces not an array");
  // §30.2 coverage-transparency marker: optional additive field. Absent ⇒ pre-§30.2
  // profile ⇒ pass unchanged. Present ⇒ must be a string array, must be a subset of
  // namespaces (unprobed only makes sense inside the in-scope set), and must be
  // disjoint from activated_probe_namespaces (a namespace is either probed or unprobed,
  // never both). Adopted at CTP pin 43ea692 per ADR-0089.
  if ("unprobed_in_scope" in wc) {
    const unprobed = wc.unprobed_in_scope;
    if (!Array.isArray(unprobed)) errs.push("workload_classification.unprobed_in_scope not an array");
    else {
      const nsSet = new Set(Array.isArray(wc.namespaces) ? wc.namespaces : []);
      const actSet = new Set(activated || []);
      for (const ns of unprobed) {
        if (typeof ns !== "string") errs.push("workload_classification.unprobed_in_scope contains non-string entry");
        else {
          if (nsSet.size && !nsSet.has(ns)) errs.push("unprobed_in_scope has [" + ns + "] not in workload_classification.namespaces");
          if (actSet.has(ns)) errs.push("unprobed_in_scope has [" + ns + "] which is also in activated_probe_namespaces (mutually exclusive)");
        }
      }
    }
  }
  // §30.5/§30.6 (P-13 ADOPTED at CTP pin 11126a8 / CL-550+CL-551+CL-552, ADR-0091):
  // workload_classification.stack[] tolerance. Additive optional; absent ⇒ pre-§30.5
  // profile ⇒ pass unchanged. Present ⇒ array of objects, each with the four keys
  // {namespace, source, trigger, added_at} (entry shape locked by CL-552 §30.6 —
  // matches GCTP acceptance test T-B.2). Enum: [stack-add, vision, answer] — the
  // shipped enum at pin 11126a8. Only stack-add is emitted today (from --stack-add);
  // vision and answer are reserved by CTP for future haystack-inferred entries.
  // Idempotence-at-persistence per §30.6: CTP dedupes by namespace at append-time;
  // this validator enforces uniqueness as a shape invariant.
  const stackEnumSources = ["stack-add","vision","answer"];
  if ("stack" in wc) {
    if (!Array.isArray(wc.stack)) errs.push("workload_classification.stack not an array");
    else {
      const nsSetForStack = new Set(Array.isArray(wc.namespaces) ? wc.namespaces : []);
      const seenNs = new Set();
      for (let i = 0; i < wc.stack.length; i++) {
        const e = wc.stack[i];
        if (!e || typeof e !== "object" || Array.isArray(e)) { errs.push("workload_classification.stack["+i+"] not an object"); continue; }
        for (const k of ["namespace","source","trigger","added_at"]) {
          if (typeof e[k] !== "string" || !e[k]) errs.push("workload_classification.stack["+i+"]."+k+" missing or not a non-empty string");
        }
        if (typeof e.namespace === "string" && e.namespace) {
          if (nsSetForStack.size && !nsSetForStack.has(e.namespace)) errs.push("workload_classification.stack["+i+"].namespace ["+e.namespace+"] not in workload_classification.namespaces");
          if (seenNs.has(e.namespace)) errs.push("workload_classification.stack["+i+"].namespace ["+e.namespace+"] duplicated (idempotence violated)");
          seenNs.add(e.namespace);
        }
        if (typeof e.source === "string" && e.source && !stackEnumSources.includes(e.source)) errs.push("workload_classification.stack["+i+"].source ["+e.source+"] not in enum [" + stackEnumSources.join(", ") + "]");
      }
    }
  }
  // §31 / S-58 / S-59 (P-15 Phase 1 pre-wire, TICKET-121.a): families_active[] tolerance.
  // Additive optional; absent ⇒ pre-P-15 profile ⇒ pass unchanged. Present ⇒ array of
  // non-empty strings, each a family ID (e.g. "frontend", "backend_runtime"). Set
  // semantics: no duplicates (a tech belongs to a family once). Structural only —
  // the family-registry corpus (`standards/technology-family-registry.yaml`) does
  // not exist at CTP pin 11126a8; semantic cross-check against known family IDs is
  // deferred to TICKET-122 (post-S-58/S-59 tag). Adopted per ADR-0047 additive
  // discipline + GCTP-side convergence doc §3.3 (Phase 1 startable NOW via existing
  // `--stack-add` mechanism — no `_project/` dependency).
  if ("families_active" in wc) {
    const fa = wc.families_active;
    if (!Array.isArray(fa)) errs.push("workload_classification.families_active not an array");
    else {
      const seenFam = new Set();
      for (let i = 0; i < fa.length; i++) {
        const f = fa[i];
        if (typeof f !== "string" || !f) errs.push("workload_classification.families_active["+i+"] not a non-empty string");
        else if (seenFam.has(f)) errs.push("workload_classification.families_active["+i+"] duplicated: ["+f+"] (family membership is a set)");
        else seenFam.add(f);
      }
    }
  }
  // §31.1 / S-63 (P-15 Phase 2 pre-wire, TICKET-121.b): project scoping tolerance.
  // Additive optional; absent ⇒ global-scope profile (pre-P-15) ⇒ pass unchanged.
  // Present ⇒ project_id must be a stable ID matching [A-Z][A-Z0-9_-]{2,63} (GCTP
  // owns assignment per convergence doc B1). project_overlay_namespaces[] is
  // derived by the CTP-side aggregator from `_project/<project_id>/`; if present it must
  // be a string array with each entry a subset of workload_classification.namespaces AND
  // project_id MUST also be present. Overlay without owning project id is meaningless.
  // The no-silent-globalization spine (convergence doc B4): overlay namespaces
  // never appear in a profile without an owning project_id; cross-project scoping
  // enforcement (A15 leakage rejection) lives in audit-architecture-crosscheck.sh
  // invariant-4, not here — the profile-level check is structural.
  if ("project_id" in wc) {
    if (typeof wc.project_id !== "string" || !wc.project_id) {
      errs.push("workload_classification.project_id present but not a non-empty string");
    } else if (!/^[A-Z][A-Z0-9_-]{2,63}$/.test(wc.project_id)) {
      errs.push("workload_classification.project_id ["+wc.project_id+"] does not match [A-Z][A-Z0-9_-]{2,63} (GCTP-owned ID format per convergence doc B1)");
    }
  }
  if ("project_overlay_namespaces" in wc) {
    const pon = wc.project_overlay_namespaces;
    if (!Array.isArray(pon)) errs.push("workload_classification.project_overlay_namespaces not an array");
    else {
      if (!("project_id" in wc)) errs.push("workload_classification.project_overlay_namespaces present but project_id missing (overlay without owning project — no silent globalization spine, convergence doc B4)");
      const nsSetForOverlay = new Set(Array.isArray(wc.namespaces) ? wc.namespaces : []);
      const seenOverlay = new Set();
      for (let i = 0; i < pon.length; i++) {
        const ns = pon[i];
        if (typeof ns !== "string" || !ns) errs.push("workload_classification.project_overlay_namespaces["+i+"] not a non-empty string");
        else {
          if (nsSetForOverlay.size && !nsSetForOverlay.has(ns)) errs.push("workload_classification.project_overlay_namespaces["+i+"] ["+ns+"] not in workload_classification.namespaces");
          if (seenOverlay.has(ns)) errs.push("workload_classification.project_overlay_namespaces["+i+"] ["+ns+"] duplicated");
          seenOverlay.add(ns);
        }
      }
    }
  }
  const probes = p.probes || {};
  if (typeof probes !== "object") errs.push("probes not an object");
  // Completeness rule: when complete=true, every activated namespace must be answered.
  // When complete=false (partial), unanswered activated probes are legitimate and
  // surfaced via the top-level "unanswered" array — that is incompleteness, not
  // structural invalidity. Matches CTP S-57 semantics (spec cl546-fsintake-06).
  if (p.complete === true && activated) for (const ns of activated) {
    const b = probes[ns];
    if (!b || typeof b !== "object" || Object.keys(b).length < 1) errs.push("probes." + ns + " missing or empty (complete=true but activated probe unanswered)");
  }
  // grounded_in_namespaces (regardless of completeness): every entry must be an
  // activated probe namespace AND be backed by an answered probe. This is the
  // namespace-grounding traceability invariant — a namespace can appear in
  // grounded_in_namespaces only if it contributed a stated fact.
  const gns = Array.isArray(p.grounded_in_namespaces) ? p.grounded_in_namespaces : null;
  if (!gns) errs.push("grounded_in_namespaces not an array");
  else if (activated) for (const ns of gns) {
    if (!activated.includes(ns)) errs.push("grounded_in_namespaces has [" + ns + "] not in activated_probe_namespaces");
    const b = probes[ns];
    if (!b || typeof b !== "object" || Object.keys(b).length < 1) errs.push("grounded_in_namespaces has [" + ns + "] but no answered probe under probes." + ns);
  }
} else {
  errs.push("unsupported schema_version: " + sv + " (expected \"1.0\" or \"1.1\")");
}
if (errs.length) { console.error("[consult --validate-profile] INVALID (schema_version=" + sv + "):\n  " + errs.join("\n  ")); process.exit(1); }
console.log("[consult --validate-profile] OK (schema_version=" + sv + ") — contract-conformant.");
process.exit(0);
'
        exit $?
        ;;
    --validate)
        [ $# -ge 2 ] || { usage; exit 2; }
        [ -f "$2" ] || { printf 'consult.sh: artifact not found: %s\n' "$2" >&2; exit 2; }
        command -v node >/dev/null 2>&1 || { printf 'consult.sh: node required for --validate\n' >&2; exit 2; }
        # Validate against docs/handoff-contract.md §Architecture-Consult-Loop.
        # node reads the path from env (env-var-first; avoids argv quoting); uses
        # process.exit (no top-level return — bash32/node portability).
        CONSULT_ARTIFACT="$2" node -e '
const fs = require("fs");
let a;
try { a = JSON.parse(fs.readFileSync(process.env.CONSULT_ARTIFACT, "utf8")); }
catch (e) { console.error("[consult --validate] INVALID: not JSON (" + e.message + ")"); process.exit(1); }
const errs = [];
if (a.schema_version !== "1") errs.push("schema_version != \"1\"");
if (a.needs_grounding !== 0) errs.push("needs_grounding != 0 (CTP cite-or-decline not satisfied)");
if (a.ruby_ok === false) errs.push("ruby_ok=false (consult loop did not run; ADR-0056 D-D)");
if (!Array.isArray(a.decisions) || a.decisions.length < 1) errs.push("decisions[] empty");
else for (const d of a.decisions) {
  const j = d && d.juncture ? d.juncture : "?";
  if (!["small","medium","large"].includes(d && d.complexity)) errs.push("decision [" + j + "] complexity not in {small,medium,large}");
  if (!Array.isArray(d && d.applicable_rules) || d.applicable_rules.length < 1) errs.push("decision [" + j + "] applicable_rules empty");
}
if (errs.length) { console.error("[consult --validate] INVALID:\n  " + errs.join("\n  ")); process.exit(1); }
console.log("[consult --validate] OK — contract-valid (needs_grounding=0; sized; rules present).");
process.exit(0);
'
        exit $?
        ;;
    --roadmap)
        [ $# -ge 2 ] || { usage; exit 2; }
        [ -f "$2" ] || { printf 'consult.sh: artifact not found: %s\n' "$2" >&2; exit 2; }
        command -v node >/dev/null 2>&1 || { printf 'consult.sh: node required for --roadmap\n' >&2; exit 2; }
        # Render docs/handoff-contract.md §Roadmap from a §Architecture-Consult-Loop
        # artifact. Re-validates (refuses invalid), topologically sequences decisions[]
        # over depends_on (Kahn; cycle ⇒ exit 1), pulls grounded_in from the recommended
        # option. node reads the path from env (env-var-first); process.exit (no top-level
        # return — bash32/node portability).
        CONSULT_ARTIFACT="$2" node -e '
const fs = require("fs");
let a;
try { a = JSON.parse(fs.readFileSync(process.env.CONSULT_ARTIFACT, "utf8")); }
catch (e) { console.error("[consult --roadmap] cannot render: not JSON (" + e.message + ")"); process.exit(1); }
// Re-validate (same gate as --validate) — never render a roadmap from an invalid artifact.
const verrs = [];
if (a.schema_version !== "1") verrs.push("schema_version != \"1\"");
if (a.needs_grounding !== 0) verrs.push("needs_grounding != 0");
if (a.ruby_ok === false) verrs.push("ruby_ok=false (loop did not run)");
const decisions = Array.isArray(a.decisions) ? a.decisions : [];
if (decisions.length < 1) verrs.push("decisions[] empty");
for (const d of decisions) {
  const j = (d && d.juncture) ? d.juncture : "?";
  if (!["small","medium","large"].includes(d && d.complexity)) verrs.push("decision [" + j + "] complexity invalid");
  if (!Array.isArray(d && d.applicable_rules) || d.applicable_rules.length < 1) verrs.push("decision [" + j + "] applicable_rules empty");
}
if (verrs.length) { console.error("[consult --roadmap] cannot render — artifact invalid:\n  " + verrs.join("\n  ")); process.exit(1); }
// grounded_in: prefer the recommended option, else union across options.
const opts = Array.isArray(a.options) ? a.options : [];
let grounded = [];
const rec = opts.find(o => o && o.id === a.recommended_option);
if (rec && Array.isArray(rec.grounded_in)) grounded = rec.grounded_in.slice();
else { const s = new Set(); for (const o of opts) for (const g of (o && o.grounded_in || [])) s.add(g); grounded = [...s]; }
// Tickets keyed by juncture (/decompose assigns final TICKET-NNN ids).
const byJ = new Map();
const tickets = decisions.map(d => {
  const t = {
    id: d.juncture, title: d.user_choice || d.juncture, complexity: d.complexity,
    depends_on: Array.isArray(d.depends_on) ? d.depends_on.slice() : [],
    applicable_rules: d.applicable_rules.slice(), grounded_in: grounded.slice()
  };
  byJ.set(d.juncture, t); return t;
});
// Kahn topological sort over depends_on (edges: dep -> ticket). Unknown deps ignored.
const indeg = new Map(tickets.map(t => [t.id, 0]));
for (const t of tickets) for (const dep of t.depends_on) if (byJ.has(dep)) indeg.set(t.id, indeg.get(t.id) + 1);
const queue = tickets.filter(t => indeg.get(t.id) === 0).map(t => t.id);
const sequence = [];
while (queue.length) {
  const id = queue.shift(); sequence.push(id);
  for (const t of tickets) if (byJ.has(t.id) && t.depends_on.includes(id)) {
    indeg.set(t.id, indeg.get(t.id) - 1);
    if (indeg.get(t.id) === 0) queue.push(t.id);
  }
}
if (sequence.length !== tickets.length) {
  console.error("[consult --roadmap] cannot render — dependency cycle among junctures (depends_on not a DAG).");
  process.exit(1);
}
const roadmap = { feature_id: a.feature_id, tickets, sequence,
  world_class_basis: "CTP architected under standards + GCTP cross-check enforced" };
// Human-readable roadmap (GCTP translates to plain language for the user).
console.log("[consult --roadmap] " + a.feature_id + " — roadmap (sized, sequenced, planned):");
console.log("  request: " + (a.user_request || "(unstated)"));
sequence.forEach((id, i) => {
  const t = byJ.get(id);
  console.log("  " + (i + 1) + ". [" + t.complexity + "] " + t.title);
  if (t.depends_on.length) console.log("       depends_on: " + t.depends_on.join(", "));
  console.log("       applicable_rules: " + t.applicable_rules.join(", "));
});
console.log("  grounded_in: " + (grounded.length ? grounded.join(", ") : "(none cited)"));
console.log("  basis: " + roadmap.world_class_basis);
console.log("  note: /decompose assigns final TICKET-NNN ids; junctures shown as prospective tickets.");
console.log("--- §Roadmap JSON ---");
console.log(JSON.stringify(roadmap, null, 2));
process.exit(0);
'
        exit $?
        ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'consult.sh: unknown arg: %s\n' "$1" >&2; usage; exit 2 ;;
esac
