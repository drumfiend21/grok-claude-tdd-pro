#!/usr/bin/env bash
# tests/test-sarif-aggregate.sh — unit tests for scripts/sarif-aggregate.sh (ADR-0066 D-E).
# Per TICKET-078. Contract: bash 3.2 + BSD coreutils + node.

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-sarif-aggregate] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/sarif-aggregate.sh
FIX=./tests/fixtures/sarif

TMP=$(mktemp -d -t sarif-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM

# Help / unknown flag
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"
"$SCRIPT" >/dev/null 2>&1; assert_eq "$?" "2" "missing --ticket exits 2"

# ---------- test_aggregate_single_file_passthrough ----------
mkdir -p "$TMP/raw1"
cp "$FIX/valid-single-result.sarif.json" "$TMP/raw1/g-md-fenced-code-language-declared.sarif.json"
out1="$TMP/out1.sarif.json"
"$SCRIPT" --ticket TICKET-001 --inputs "$TMP/raw1" --output "$out1" --quiet >/dev/null 2>&1
rc=$?
assert_eq "$rc" "0" "test_aggregate_single_file_passthrough — exit 0"
runs1=$(node -e 'const d=require("'"$out1"'"); console.log(Array.isArray(d.runs)?d.runs.length:-1)' 2>/dev/null)
assert_eq "$runs1" "1" "test_aggregate_single_file_passthrough — runs[].length=1"

# ---------- test_aggregate_multi_file_merges_distinct_runs ----------
mkdir -p "$TMP/raw2"
cp "$FIX/valid-single-result.sarif.json" "$TMP/raw2/g-md-fenced.sarif.json"
cp "$FIX/valid-multi-result.sarif.json" "$TMP/raw2/g-aws-prose.sarif.json"
out2="$TMP/out2.sarif.json"
"$SCRIPT" --ticket TICKET-002 --inputs "$TMP/raw2" --output "$out2" --quiet >/dev/null 2>&1
rc=$?
assert_eq "$rc" "0" "test_aggregate_multi_file_merges_distinct_runs — exit 0"
runs2=$(node -e 'const d=require("'"$out2"'"); console.log(Array.isArray(d.runs)?d.runs.length:-1)' 2>/dev/null)
assert_eq "$runs2" "2" "test_aggregate_multi_file_merges_distinct_runs — runs[].length=2"
tools=$(node -e 'const d=require("'"$out2"'"); console.log(d.runs.map(r=>r.tool.driver.name).sort().join(","))' 2>/dev/null)
assert_eq "$tools" "markdownlint,prose-judge" "test_aggregate_multi_file_merges_distinct_runs — distinct tool.driver.name preserved"

# ---------- test_aggregate_validates_against_oasis_schema ----------
# Minimal contract: version, $schema, runs[] all present.
version=$(node -e 'const d=require("'"$out2"'"); console.log(d.version||"MISSING")' 2>/dev/null)
assert_eq "$version" "2.1.0" "test_aggregate_validates_against_oasis_schema — version 2.1.0"
schema=$(node -e 'const d=require("'"$out2"'"); console.log(d["$schema"]?"present":"missing")' 2>/dev/null)
assert_eq "$schema" "present" "test_aggregate_validates_against_oasis_schema — \$schema present"

# ---------- test_aggregate_invalid_input_warns_non_strict ----------
mkdir -p "$TMP/raw3"
cp "$FIX/valid-single-result.sarif.json" "$TMP/raw3/good.sarif.json"
cp "$FIX/invalid-no-version.sarif.json" "$TMP/raw3/bad.sarif.json"
out3="$TMP/out3.sarif.json"
"$SCRIPT" --ticket TICKET-003 --inputs "$TMP/raw3" --output "$out3" --quiet >/dev/null 2>&1
rc=$?
assert_eq "$rc" "0" "test_aggregate_invalid_input_warns_non_strict — exit 0"
runs3=$(node -e 'const d=require("'"$out3"'"); console.log(Array.isArray(d.runs)?d.runs.length:-1)' 2>/dev/null)
assert_eq "$runs3" "1" "test_aggregate_invalid_input_warns_non_strict — invalid skipped, 1 run preserved"

# ---------- test_aggregate_invalid_input_strict_fails ----------
out3s="$TMP/out3s.sarif.json"
"$SCRIPT" --ticket TICKET-003 --inputs "$TMP/raw3" --output "$out3s" --strict --quiet >/dev/null 2>&1
rc=$?
assert_eq "$rc" "2" "test_aggregate_invalid_input_strict_fails — exit 2"

# Also: invalid-bad-level in strict mode → 2
mkdir -p "$TMP/raw4"
cp "$FIX/invalid-bad-level.sarif.json" "$TMP/raw4/bad-level.sarif.json"
"$SCRIPT" --ticket TICKET-004 --inputs "$TMP/raw4" --output "$TMP/out4.sarif.json" --strict --quiet >/dev/null 2>&1
assert_eq "$?" "2" "test_aggregate_invalid_input_strict_fails (bad level) — exit 2"

# ---------- test_aggregate_empty_inputs_dir_emits_empty_log ----------
mkdir -p "$TMP/raw_empty"
out_e="$TMP/out_empty.sarif.json"
"$SCRIPT" --ticket TICKET-EMPTY --inputs "$TMP/raw_empty" --output "$out_e" --quiet >/dev/null 2>&1
rc=$?
assert_eq "$rc" "0" "test_aggregate_empty_inputs_dir_emits_empty_log — exit 0"
runs_e=$(node -e 'const d=require("'"$out_e"'"); console.log(Array.isArray(d.runs)?d.runs.length:-1)' 2>/dev/null)
assert_eq "$runs_e" "0" "test_aggregate_empty_inputs_dir_emits_empty_log — runs[]=[]"
ver_e=$(node -e 'const d=require("'"$out_e"'"); console.log(d.version||"MISSING")' 2>/dev/null)
assert_eq "$ver_e" "2.1.0" "test_aggregate_empty_inputs_dir_emits_empty_log — version 2.1.0"

# ---------- test_aggregate_summary_compact_correct ----------
out_s="$TMP/out_s.sarif.json"
sum_s="$TMP/out_s.summary.json"
"$SCRIPT" --ticket TICKET-SUM --inputs "$TMP/raw2" --output "$out_s" --summary --quiet >/dev/null 2>&1
rc=$?
assert_eq "$rc" "0" "test_aggregate_summary_compact_correct — exit 0"
# Summary file goes next to output by default convention
sum_path="${out_s%.sarif.json}.summary.json"
[ -f "$sum_path" ] && sum_ok=1 || sum_ok=0
assert_eq "$sum_ok" "1" "test_aggregate_summary_compact_correct — summary file written"
total_findings=$(node -e 'const d=require("'"$sum_path"'"); console.log(d.total_results)' 2>/dev/null)
assert_eq "$total_findings" "3" "test_aggregate_summary_compact_correct — total_results=3"

# ---------- test_aggregate_default_paths ----------
# Default --inputs = .harness/audit/sarif/raw/TICKET-NNN/; default --output = .harness/audit/sarif/TICKET-NNN.sarif.json
DEFAULT_TICKET="TICKET-DEFAULTS-TEST"
mkdir -p ".harness/audit/sarif/raw/$DEFAULT_TICKET"
cp "$FIX/valid-single-result.sarif.json" ".harness/audit/sarif/raw/$DEFAULT_TICKET/probe.sarif.json"
"$SCRIPT" --ticket "$DEFAULT_TICKET" --quiet >/dev/null 2>&1
rc=$?
assert_eq "$rc" "0" "test_aggregate_default_paths — exit 0 with defaults"
[ -f ".harness/audit/sarif/$DEFAULT_TICKET.sarif.json" ] && def_ok=1 || def_ok=0
assert_eq "$def_ok" "1" "test_aggregate_default_paths — default output path written"
rm -rf ".harness/audit/sarif/raw/$DEFAULT_TICKET" ".harness/audit/sarif/$DEFAULT_TICKET.sarif.json" ".harness/audit/sarif/$DEFAULT_TICKET.summary.json"

# ---------- Non-existent inputs dir → exit 1 ----------
"$SCRIPT" --ticket TICKET-NOPE --inputs "$TMP/does-not-exist" --output "$TMP/nope.sarif.json" --quiet >/dev/null 2>&1
assert_eq "$?" "1" "non-existent inputs dir → exit 1"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-sarif-aggregate] OK — $passes/$total passed."; exit 0
else log "[test-sarif-aggregate] FAIL — $failures/$total."; exit 1; fi
