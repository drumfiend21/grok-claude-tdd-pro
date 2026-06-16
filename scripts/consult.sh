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
#   0  ok (preflight: both prereqs hold / engine-path: resolved + executable)
#   1  prerequisite missing (ruby absent/old, or engine script not found)
#   2  usage error (bad/again invocation)
#
# Portability: bash 3.2 + BSD coreutils. No external deps beyond ruby (probed).

set -u

RUBY_BIN="${CONSULT_RUBY_BIN:-ruby}"
PLUGIN_CACHE="${CONSULT_PLUGIN_CACHE:-.harness/plugin-cache/claude-tdd-pro}"
MIN_RUBY="${CONSULT_MIN_RUBY:-3.0}"
ENGINE_SCRIPTS="architect-session.sh business-intake.sh architect-recommend.sh well-architected-review.sh"

emit() { printf '%s\n' "$*"; }

usage() {
    sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//' >&2
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
    -h|--help) usage; exit 0 ;;
    *) printf 'consult.sh: unknown arg: %s\n' "$1" >&2; usage; exit 2 ;;
esac
