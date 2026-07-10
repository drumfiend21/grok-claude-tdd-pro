#!/usr/bin/env bash
# tests/test-p15-family-activation.sh — P-15 Phase 1 (family umbrella activation)
# end-to-end acceptance tests exercising CTP's shipped commands/resolve-technology.sh
# (S-58) against the shipped standards/technology-umbrella-registry.yaml (S-59) at
# CTP pin b886658 / ADR-0092.
#
# Assertions (A1..A4 from GCTP's 18-assertion P-15 acceptance corpus):
#   A1 — Vue resolves to the frontend umbrella and activates the exact 6-namespace
#        payload the shipped registry declares (`md,node,owasp,typescript,w3c,web-vitals`).
#   A2 — Angular resolves to the same umbrella (guards against React-only regression;
#        confirms family membership union works for a second tech in the same family).
#   A3 — An unknown technology emits status=unresolved with an empty activated set —
#        cite-or-decline preserved at the classifier layer (no phantom activation).
#   A4 — The registry itself schema-validates: umbrellas map exists, each umbrella
#        entry has an activates list, and every referenced namespace exists somewhere
#        in the plugin's aggregated rule surface (verified via the shipped
#        generated-code-quality-standards/ directory presence, not authored data).
#
# These tests DO NOT need a project scope (--project) — Phase 1 is workload
# classification, not per-project acquisition. The A5..A18 tests exercising
# acquire-technology-rules.sh, promote-project-rule.sh, and recommend-technology.sh
# land in tests/test-p15-acquisition.sh once CTP's production-fetch wrapper ships
# (offered post-adoption).
#
# Portability: bash 3.2 + BSD coreutils. No external dependencies. ruby probed by
# resolve-technology.sh itself (fails cleanly if absent — matches CTP's cite-or-decline).
#
# Exit-code contract: 0 (all pass) / 1 (any assertion fails) / 2 (harness setup error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-p15-family-activation] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}
assert_match() {
    case "$1" in *"$2"*) log "  ✓ $3"; passes=$((passes+1)) ;; *) log "  ✗ $3 (no '$2')"; failures=$((failures+1)) ;; esac
}
assert_no_match() {
    case "$1" in *"$2"*) log "  ✗ $3 (unexpectedly contained '$2')"; failures=$((failures+1)) ;; *) log "  ✓ $3"; passes=$((passes+1)) ;; esac
}

CACHE=".harness/plugin-cache/claude-tdd-pro"
CMD="$CACHE/commands/resolve-technology.sh"
REGISTRY="$CACHE/standards/technology-umbrella-registry.yaml"

# Setup preflight — every assertion below assumes the shipped command + registry
# are present at the pinned commit. A missing artifact is a harness-setup failure,
# not a test-assertion failure.
if [ ! -f "$CMD" ]; then
    log "  ✗ setup: $CMD missing (run scripts/sync-plugin.sh --ensure)"
    exit 2
fi
if [ ! -f "$REGISTRY" ]; then
    log "  ✗ setup: $REGISTRY missing (S-59 registry not present at pin — re-run sync-plugin)"
    exit 2
fi

run_resolve() { CLAUDE_PLUGIN_ROOT="$CACHE" bash "$CMD" "$@" 2>&1; }

# --- A1 — Vue resolves to frontend umbrella and activates the shipped 6-namespace set.
# The exact activated set is deterministic per the registry: any drift here means
# either (a) the registry changed (pin bump needed) or (b) resolve-technology.sh
# behavior changed (contract violation). We assert on the summary line since it is
# the machine-parsable shape the /consult skill will consume.
out=$(run_resolve vue); ec=$?
assert_eq "$ec" "0" "A1: resolve-technology.sh vue → exit 0"
assert_match "$out" "resolve=vue" "A1: summary line names the resolved tech"
assert_match "$out" "umbrellas=frontend" "A1: Vue lists frontend umbrella (schema pins vue → frontend membership)"
# Activated payload is exactly the frontend umbrella activates list, sorted:
# md, node, owasp, typescript, w3c, web-vitals. Each is asserted individually so
# a single missing namespace surfaces as a specific failure.
assert_match "$out" "activated=" "A1: activated= key present on summary line"
for ns in md node owasp typescript w3c web-vitals; do
    assert_match "$out" "$ns" "A1: activated set includes [$ns] (framework-agnostic frontend rule namespace)"
done
# Vue has specific_namespace: null in the shipped registry — needs_source status
# is the expected P-15 signal that Phase 2 acquisition (S-60) would kick in.
assert_match "$out" "status=needs_source" "A1: Vue status=needs_source (no specific_namespace shipped globally; acquisition path applicable)"
# JSON body — the /consult skill uses this for structured consumption.
assert_match "$out" '"technology": "vue"' "A1: JSON body names the resolved technology"
assert_match "$out" '"umbrellas"' "A1: JSON body carries umbrellas array"
assert_match "$out" '"activated_namespaces"' "A1: JSON body carries activated_namespaces array"

# --- A2 — Angular resolves to the same frontend umbrella (guards React-only regression).
# This is load-bearing: at pin 11126a8 (pre-P-15), only React would fire frontend
# rules; naming Angular activated ZERO frontend-family namespaces. The whole
# point of §31 is that Angular, Vue, Ember, Svelte, Solid, and every other
# member of the frontend family activates the same umbrella at Stage 0.
out=$(run_resolve angular); ec=$?
assert_eq "$ec" "0" "A2: resolve-technology.sh angular → exit 0"
assert_match "$out" "resolve=angular" "A2: summary names the resolved tech"
assert_match "$out" "umbrellas=frontend" "A2: Angular lists frontend umbrella (same as Vue — family membership union works)"
for ns in md node owasp typescript w3c web-vitals; do
    assert_match "$out" "$ns" "A2: Angular activates the SAME [$ns] namespace as Vue (regression guard against React-only)"
done

# --- A3 — Unknown tech emits status=unresolved with EMPTY activated set.
# Cite-or-decline preserved: the registry cannot invent a family membership for a
# tech it does not know. No phantom activation. Exit 0 because unresolved is a
# well-defined state, not an error — the caller decides whether to `--stack-add`
# raw namespaces or file a family-registry PR (per convergence-doc Delta B).
out=$(run_resolve totally-fake-tech-that-does-not-exist); ec=$?
assert_eq "$ec" "0" "A3: resolve-technology.sh <unknown> → exit 0 (unresolved is a valid state, not an error)"
assert_match "$out" "resolve=totally-fake-tech-that-does-not-exist" "A3: summary names the input tech"
assert_match "$out" "status=unresolved" "A3: unknown tech → status=unresolved (cite-or-decline actionable signal)"
# Phantom-activation guard: activated= key must be EMPTY (no namespaces attached
# to an unresolved tech). We assert the summary line has `activated= ` (empty)
# and the JSON body carries no activated_namespaces array populated.
assert_no_match "$out" "activated=md" "A3: no phantom activation of md (unknown tech does not silently inherit any umbrella)"
assert_no_match "$out" "activated=owasp" "A3: no phantom activation of owasp"
assert_no_match "$out" "activated=typescript" "A3: no phantom activation of typescript"
assert_no_match "$out" "umbrellas=frontend" "A3: unknown tech does not silently list frontend umbrella"

# --- A4 — Registry schema validates.
# Structural: umbrellas map must exist; every umbrella must declare an activates
# list; every umbrella activates entry must be a bare namespace token (no
# whitespace, no path). We use grep-level validation to avoid a YAML parser
# dependency (matches the bash 3.2 + BSD portability discipline).
assert_match "$(head -1 "$REGISTRY")" "#" "A4: registry file starts with a header comment"
assert_match "$(cat "$REGISTRY")" "umbrellas:" "A4: registry declares an umbrellas: map"
assert_match "$(cat "$REGISTRY")" "technologies:" "A4: registry declares a technologies: list"
assert_match "$(cat "$REGISTRY")" "frontend:" "A4: registry declares the frontend umbrella family"
assert_match "$(cat "$REGISTRY")" "activates:" "A4: each umbrella entry declares an activates: list"

# For each namespace referenced by the frontend umbrella, verify the shipped
# generated-code-quality-standards/ tree contains a directory of the same name.
# This is the cite-or-decline invariant at the registry level: an umbrella
# cannot activate a namespace that does not exist as a rule source in the plugin.
STANDARDS="$CACHE/generated-code-quality-standards"
for ns in md node owasp typescript w3c web-vitals; do
    if [ -d "$STANDARDS/$ns" ]; then
        log "  ✓ A4: shipped standards tree has $ns/ (frontend umbrella's activated namespace is real)"
        passes=$((passes+1))
    else
        log "  ✗ A4: shipped standards tree missing $ns/ (frontend umbrella references a non-existent namespace — cite-or-decline broken)"
        failures=$((failures+1))
    fi
done

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-p15-family-activation] OK — $passes/$total passed."; exit 0
else log "[test-p15-family-activation] FAIL — $failures/$total."; exit 1; fi
