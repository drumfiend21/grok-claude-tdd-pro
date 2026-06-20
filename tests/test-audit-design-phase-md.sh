#!/usr/bin/env bash
# tests/test-audit-design-phase-md.sh — unit tests for scripts/audit-design-phase-md.sh
# (TICKET-079 / ADR-0066 D-D). Exit-code contract: 0 (green / vacuous) / 1 (red) / 2 (error).

set -u
QUIET=0
for arg in "$@"; do [ "$arg" = "--quiet" ] && QUIET=1; done
log() { [ "$QUIET" -eq 0 ] && printf '%s\n' "$*"; return 0; }
log "[test-audit-design-phase-md] starting"

failures=0; passes=0
assert_eq() {
    if [ "$1" = "$2" ]; then log "  ✓ $3"; passes=$((passes+1))
    else log "  ✗ $3 (expected $2, got $1)"; failures=$((failures+1)); fi
}

SCRIPT=./scripts/audit-design-phase-md.sh

TMP=$(mktemp -d -t adpm-test.XXXXXX) || { log "mktemp failed"; exit 2; }
trap 'rm -rf -- "$TMP"' EXIT INT TERM
mkdir -p "$TMP/h" "$TMP/app/docs/architecture/adr" "$TMP/app/docs"

# active-vacuous.json: no rules with applies_to_prose:true
cat > "$TMP/active-vacuous.json" <<'JSON'
{ "rules": [
  { "id": "g-universal-no-hardcoded-secrets" },
  { "id": "g-md-001", "source_namespace": "md" },
  { "id": "g-aws-tag-resources", "source_namespace": "aws" }
] }
JSON

# active-prose.json: includes a rule with applies_to_prose:true
cat > "$TMP/active-prose.json" <<'JSON'
{ "rules": [
  { "id": "g-universal-no-hardcoded-secrets" },
  { "id": "g-md-001", "source_namespace": "md" },
  { "id": "g-aws-no-unrestricted-ingress", "source_namespace": "aws", "applies_to_prose": true },
  { "id": "g-iam-no-action-star", "source_namespace": "iam", "applies_to_prose": true }
] }
JSON

# Worked-example ADR fixtures: violation, clean, deviation
cat > "$TMP/app/docs/architecture/adr/0015-violation.md" <<'EOF'
---
status: proposed
kind: adr
date: 2026-06-19
---
# ADR-0015 — Dev-cluster network posture

## Decision

For developer convenience, we will leave dev-cluster ingress unrestricted
(0.0.0.0/0 on all egress ports) and rely on a private VPN.
EOF

cat > "$TMP/app/docs/architecture/adr/0015-clean.md" <<'EOF'
---
status: proposed
kind: adr
date: 2026-06-19
---
# ADR-0015 — Dev-cluster network posture

## Decision

We will use a private VPN gateway plus an AWS WAF with explicit IP allowlist
for developer SSH access; no 0.0.0.0/0 ingress on any port.
EOF

# Deviation file for the deviation test case
cat > "$TMP/app/docs/deviations.md" <<'EOF'
# Deviations

## Deviation — g-aws-no-unrestricted-ingress on TICKET-DEV
- Rule: g-aws-no-unrestricted-ingress
- Scope: TICKET-DEV, dev-cluster network
- Why-cannot-apply: dev cluster is in an isolated VPC with no IGW; the "0.0.0.0/0" reference is intra-VPC only.
- Operator acceptance: test@example.com on 2026-06-19

## Deviation — g-iam-no-action-star on TICKET-DEV
- Rule: g-iam-no-action-star
- Scope: TICKET-DEV
- Why-cannot-apply: dev environment uses sandboxed roles per ADR-0099.
- Operator acceptance: test@example.com on 2026-06-19
EOF

# A non-architectural .md (no frontmatter, not under docs/architecture)
mkdir -p "$TMP/app/docs/notes"
cat > "$TMP/app/docs/notes/random.md" <<'EOF'
# Random notes

Just some notes, not architecture.
EOF

# A non-architectural .md WITH frontmatter kind: architecture
cat > "$TMP/app/docs/notes/secret-arch.md" <<'EOF'
---
kind: architecture
---
# Secret architecture note

This is architectural per frontmatter even though the path doesn't show it.
EOF

mkreq() { printf '%s\n' "$2" > "$TMP/h/$1.req.json"; }
clear_h() { rm -f "$TMP/h"/*.json; }

run_vacuous() { ADPM_HANDOFFS_DIR="$TMP/h" ADPM_ACTIVE="$TMP/active-vacuous.json" ADPM_APP_ROOT="$TMP/app" "$SCRIPT" --quiet >/dev/null 2>&1; }
run_prose()   { ADPM_HANDOFFS_DIR="$TMP/h" ADPM_ACTIVE="$TMP/active-prose.json"   ADPM_APP_ROOT="$TMP/app" "$SCRIPT" --quiet >/dev/null 2>&1; }

# Help / unknown flag
"$SCRIPT" --help >/dev/null 2>&1; assert_eq "$?" "0" "--help exits 0"
"$SCRIPT" --bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown flag exits 2"

# No reqs / no active → vacuous
clear_h; run_prose; assert_eq "$?" "0" "no reqs → vacuous (0)"

# ---------- test_dispatch_md_no_architectural_scope_skips_gate ----------
# A req touching only .ts files: gate doesn't fire even when prose rules exist
clear_h
mkreq T-CODE-ONLY '{"ticket_id":"T-CODE-ONLY","file_scope":{"may_edit":["src/**/*.ts"]}}'
run_prose; assert_eq "$?" "0" "test_dispatch_md_no_architectural_scope_skips_gate — .ts only → 0"

# ---------- test_dispatch_gate_vacuous_when_no_prose_rules ----------
# Architectural MD in scope, but active.json has NO applies_to_prose rules
clear_h
mkreq T-VAC '{"ticket_id":"T-VAC","file_scope":{"may_edit":["docs/architecture/adr/**/*.md"]}}'
run_vacuous; assert_eq "$?" "0" "test_dispatch_gate_vacuous_when_no_prose_rules — vacuous (0)"

# ---------- test_dispatch_md_design_red_blocks ----------
# Architectural MD in scope, applies_to_prose rule present, no deviation
clear_h
mkreq T-VIOL '{"ticket_id":"T-VIOL","file_scope":{"may_edit":["docs/architecture/adr/**/*.md"]}}'
run_prose; assert_eq "$?" "1" "test_dispatch_md_design_red_blocks — prose rule + no deviation → 1"

# ---------- test_dispatch_md_design_green_proceeds ----------
# Same scope, but prose-judge.sh detector path STUBBED green (skip flag for test mode).
clear_h
mkreq T-OK '{"ticket_id":"T-OK","file_scope":{"may_edit":["docs/architecture/adr/**/*.md"]}}'
ADPM_HANDOFFS_DIR="$TMP/h" ADPM_ACTIVE="$TMP/active-prose.json" ADPM_APP_ROOT="$TMP/app" ADPM_TEST_JUDGE_VERDICT=green "$SCRIPT" --quiet >/dev/null 2>&1
assert_eq "$?" "0" "test_dispatch_md_design_green_proceeds — judge reports green → 0"

# ---------- test_dispatch_md_design_deviated_proceeds ----------
# All applies_to_prose rules have deviation rows for TICKET-DEV
clear_h
mkreq TICKET-DEV '{"ticket_id":"TICKET-DEV","file_scope":{"may_edit":["docs/architecture/adr/**/*.md"]}}'
run_prose; assert_eq "$?" "0" "test_dispatch_md_design_deviated_proceeds — both rules deviated for TICKET-DEV → 0"

# ---------- test_dispatch_frontmatter_kind_detection ----------
# A req touching docs/notes/secret-arch.md whose frontmatter is kind: architecture
clear_h
mkreq T-FM '{"ticket_id":"T-FM","file_scope":{"may_edit":["docs/notes/**/*.md"]}}'
run_prose; assert_eq "$?" "1" "test_dispatch_frontmatter_kind_detection — frontmatter triggers gate → 1"

# ---------- test_dispatch_path_heuristic_detection ----------
# A req touching docs/architecture/notes/foo.md (path glob match, no frontmatter)
mkdir -p "$TMP/app/docs/architecture/notes"
cat > "$TMP/app/docs/architecture/notes/foo.md" <<'EOF'
# Plain note
No frontmatter.
EOF
clear_h
mkreq T-PATH '{"ticket_id":"T-PATH","file_scope":{"may_edit":["docs/architecture/notes/**/*.md"]}}'
run_prose; assert_eq "$?" "1" "test_dispatch_path_heuristic_detection — path glob triggers gate → 1"

# ---------- Plain (non-architectural) docs MD not gated ----------
# Without frontmatter and not under architecture/adr paths, the gate doesn't fire
clear_h
mkreq T-PLAIN '{"ticket_id":"T-PLAIN","file_scope":{"may_edit":["docs/notes/random.md"]}}'
ADPM_HANDOFFS_DIR="$TMP/h" ADPM_ACTIVE="$TMP/active-prose.json" ADPM_APP_ROOT="$TMP/app" ADPM_EXCLUDE_FILE="docs/notes/secret-arch.md" "$SCRIPT" --quiet >/dev/null 2>&1
# secret-arch.md has frontmatter so it would be picked up by the dir glob; isolate by excluding it
assert_eq "$?" "0" "plain docs MD (no frontmatter, not under arch path) → 0"

total=$((passes + failures))
if [ "$failures" -eq 0 ]; then log "[test-audit-design-phase-md] OK — $passes/$total passed."; exit 0
else log "[test-audit-design-phase-md] FAIL — $failures/$total."; exit 1; fi
