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
#   --engine-path <name>   Resolve + print the path to a CTP engine script
#                          (architect-session.sh / business-intake.sh /
#                          architect-recommend.sh / well-architected-review.sh).
#   --validate <file>      Validate a consult artifact (FEATURE-NNN.architecture.json)
#                          against docs/handoff-contract.md §Architecture-Consult-Loop:
#                          schema_version=="1", needs_grounding==0, ruby_ok!=false, and
#                          every decisions[] entry sized (complexity ∈ {small,medium,large})
#                          with a non-empty applicable_rules. /decompose runs this before
#                          consuming an artifact (A-4). Requires node (JSON parse).
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
#   0  ok (preflight prereqs hold / engine-path resolved / artifact contract-valid)
#   1  prerequisite missing (ruby absent/old, engine script not found) OR artifact invalid
#   2  usage error (bad invocation, missing file/arg)
#
# Portability: bash 3.2 + BSD coreutils. ruby probed; node used only for --validate.

set -u

RUBY_BIN="${CONSULT_RUBY_BIN:-ruby}"
PLUGIN_CACHE="${CONSULT_PLUGIN_CACHE:-.harness/plugin-cache/claude-tdd-pro}"
MIN_RUBY="${CONSULT_MIN_RUBY:-3.0}"
ENGINE_SCRIPTS="architect-session.sh business-intake.sh architect-recommend.sh well-architected-review.sh"

emit() { printf '%s\n' "$*"; }

usage() {
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' >&2
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
    -h|--help) usage; exit 0 ;;
    *) printf 'consult.sh: unknown arg: %s\n' "$1" >&2; usage; exit 2 ;;
esac
