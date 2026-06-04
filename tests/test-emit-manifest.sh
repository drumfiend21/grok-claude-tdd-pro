#!/usr/bin/env bash
# tests/test-emit-manifest.sh — unit tests for scripts/emit-manifest.sh
#
# Per ADR-0028: closes Fowler critique #2 ("preaches TDD without practicing
# it on your own substrate"). The first harness substrate script with unit
# tests; the remaining 5 (sync-plugin, audit-doc-drift, smoke-e2e,
# export-cursor-rules, audit-manifest) are deferred per ADR-0028 §Out-of-scope
# with named triggers (operator-bitten signal per script).
#
# Tests the exit-code contract documented in scripts/emit-manifest.sh + ADR-0019
# + ADR-0021 (--regenerate path). Portable bash 3.2 + BSD coreutils per C-23;
# native assertions; no bats / shellspec dependency.
#
# Usage:
#   tests/test-emit-manifest.sh           # exit 0 on all-pass; exit 1 on any failure
#   tests/test-emit-manifest.sh --quiet   # suppress per-test ✓/✗ lines; exit code only
#
# Run from repo root.

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'test-emit-manifest.sh: unknown arg: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-emit-manifest] starting"

failures=0
passes=0

assert_eq() {
    local actual="$1" expected="$2" desc="$3"
    if [ "$actual" = "$expected" ]; then
        log "  ✓ $desc"
        passes=$((passes + 1))
    else
        log "  ✗ $desc (expected $expected, got $actual)"
        failures=$((failures + 1))
    fi
}

assert_file_exists() {
    local path="$1" desc="$2"
    if [ -f "$path" ]; then
        log "  ✓ $desc"
        passes=$((passes + 1))
    else
        log "  ✗ $desc (file missing: $path)"
        failures=$((failures + 1))
    fi
}

# --- Setup: ensure smoke artifacts exist so emit-manifest has inputs --------
./scripts/smoke-e2e.sh >/dev/null 2>&1 || true   # smoke trap may produce non-zero on toy state; that's fine
[ -f .harness/handoffs/TICKET-042.req.json ] || {
    printf '[test-emit-manifest] FATAL: smoke did not produce TICKET-042.req.json — environment broken\n' >&2
    exit 2
}

# --- Test 1: --ticket required (exit 2) -------------------------------------
./scripts/emit-manifest.sh >/dev/null 2>&1
assert_eq "$?" "2" "no --ticket flag should exit 2"

# --- Test 2: unknown flag exits 2 -------------------------------------------
./scripts/emit-manifest.sh --bogus-flag >/dev/null 2>&1
assert_eq "$?" "2" "unknown flag should exit 2"

# --- Test 3: nonexistent request file exits 2 -------------------------------
./scripts/emit-manifest.sh --ticket TICKET-DOES-NOT-EXIST --quiet >/dev/null 2>&1
assert_eq "$?" "2" "missing request file should exit 2"

# --- Test 4: clean emit produces parseable manifest with required fields ----
./scripts/emit-manifest.sh --ticket TICKET-042 --driver test-runner --quiet
exit_code=$?
assert_eq "$exit_code" "0" "clean emit should exit 0"
assert_file_exists ".harness/audit/TICKET-042.manifest.json" "manifest file written"

# JSON-parseable + required fields present (uses node — already a harness dep)
fields_ok=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(".harness/audit/TICKET-042.manifest.json", "utf8"));
    const required = ["schema_version", "ticket_id", "created_at", "status", "sources", "upstream_provenance_manifest_ref", "manifest_generator", "signature"];
    const missing = required.filter(k => !(k in m));
    const ok = missing.length === 0 && m.schema_version === "1" && m.ticket_id === "TICKET-042" && Array.isArray(m.sources) && m.sources.length >= 1;
    process.stdout.write(ok ? "ok" : "fail:" + missing.join(","));
' 2>/dev/null)
assert_eq "$fields_ok" "ok" "manifest has all 8 required fields + valid schema_version + non-empty sources"

# manifest_generator.tool reflects --driver
driver_tool=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(".harness/audit/TICKET-042.manifest.json", "utf8"));
    process.stdout.write(m.manifest_generator.tool);
' 2>/dev/null)
assert_eq "$driver_tool" "test-runner" "--driver value lands in manifest_generator.tool"

# --- Test 5: --regenerate on clean tree exits 0 + writes .regenerated.json --
./scripts/emit-manifest.sh --ticket TICKET-042 --regenerate --driver test-runner --quiet
assert_eq "$?" "0" "--regenerate on unmodified sources should exit 0"
assert_file_exists ".harness/audit/TICKET-042.manifest.regenerated.json" "--regenerate writes .regenerated.json"

# --- Test 6: --regenerate detects source tamper (exit 1; original untouched) -
original_sha_before=$(sha256sum .harness/audit/TICKET-042.manifest.json 2>/dev/null | awk '{print $1}' \
                     || shasum -a 256 .harness/audit/TICKET-042.manifest.json | awk '{print $1}')

printf '\n# TAMPER TEST INJECTION\n' >> .harness/trails/TICKET-042.md
./scripts/emit-manifest.sh --ticket TICKET-042 --regenerate --driver test-runner --quiet
assert_eq "$?" "1" "--regenerate after source tamper should exit 1"

original_sha_after=$(sha256sum .harness/audit/TICKET-042.manifest.json 2>/dev/null | awk '{print $1}' \
                     || shasum -a 256 .harness/audit/TICKET-042.manifest.json | awk '{print $1}')
assert_eq "$original_sha_after" "$original_sha_before" "original .manifest.json is NEVER overwritten by --regenerate"

# --- Test 7: --regenerate without an existing original exits 2 --------------
rm -f .harness/audit/TICKET-042.manifest.json .harness/audit/TICKET-042.manifest.regenerated.json
./scripts/emit-manifest.sh --ticket TICKET-042 --regenerate --driver test-runner --quiet >/dev/null 2>&1
assert_eq "$?" "2" "--regenerate without existing original should exit 2"

# --- Test 8: -h / --help exits 0 + prints usage to stderr -------------------
help_out=$(./scripts/emit-manifest.sh --help 2>&1 1>/dev/null)
help_exit=$?
assert_eq "$help_exit" "0" "--help should exit 0"
case "$help_out" in
    *--ticket*) log "  ✓ --help mentions --ticket flag"; passes=$((passes + 1)) ;;
    *) log "  ✗ --help output missing --ticket reference"; failures=$((failures + 1)) ;;
esac

# Restore smoke artifacts so subsequent tests have fresh inputs
./scripts/smoke-e2e.sh >/dev/null 2>&1 || true

# --- Test 9: --upstream-ref with valid existing file populates field --------
./scripts/emit-manifest.sh --ticket TICKET-042 --driver test --quiet --upstream-ref docs/quality-gate.md
assert_eq "$?" "0" "--upstream-ref valid path exits 0"
ref_val=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(".harness/audit/TICKET-042.manifest.json", "utf8"));
    process.stdout.write(m.upstream_provenance_manifest_ref || "null");
' 2>/dev/null)
assert_eq "$ref_val" "docs/quality-gate.md" "--upstream-ref valid path populates manifest field"

# --- Test 10: --upstream-ref with missing path warns + sets null + exit 1 ---
./scripts/emit-manifest.sh --ticket TICKET-042 --driver test --quiet --upstream-ref /tmp/does-not-exist.json
assert_eq "$?" "1" "--upstream-ref missing path exits 1 (warning)"
ref_val=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(".harness/audit/TICKET-042.manifest.json", "utf8"));
    process.stdout.write(m.upstream_provenance_manifest_ref === null ? "null" : "set");
' 2>/dev/null)
assert_eq "$ref_val" "null" "--upstream-ref missing path leaves field null"

# --- Test 11: missing response file → exit 1 + status=blocked + response_missing kind
res_backup=$(mktemp); cp .harness/handoffs/TICKET-042.res.json "$res_backup"
rm .harness/handoffs/TICKET-042.res.json
./scripts/emit-manifest.sh --ticket TICKET-042 --driver test --quiet
warn_exit=$?
status_val=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(".harness/audit/TICKET-042.manifest.json", "utf8"));
    process.stdout.write(m.status);
' 2>/dev/null)
kind_val=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(".harness/audit/TICKET-042.manifest.json", "utf8"));
    const r = m.sources.find(s => s.kind === "response_missing" || s.kind === "response");
    process.stdout.write(r ? r.kind : "absent");
' 2>/dev/null)
mv "$res_backup" .harness/handoffs/TICKET-042.res.json  # restore BEFORE asserting
assert_eq "$warn_exit" "1" "missing response → exit 1 (warning)"
assert_eq "$status_val" "blocked" "missing response → status=blocked"
assert_eq "$kind_val" "response_missing" "missing response → source-kind=response_missing"

# --- Cleanup: restore smoke artifacts for downstream commands ---------------
./scripts/smoke-e2e.sh >/dev/null 2>&1 || true
rm -f .harness/audit/TICKET-042.manifest.regenerated.json

# --- Report -----------------------------------------------------------------
total=$((passes + failures))
if [ "$failures" -eq 0 ]; then
    log "[test-emit-manifest] OK — $passes/$total passed."
    exit 0
else
    log "[test-emit-manifest] FAIL — $failures failures, $passes passes ($total total)."
    exit 1
fi
