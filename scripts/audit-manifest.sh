#!/usr/bin/env bash
# scripts/audit-manifest.sh — validate .harness/audit/*.manifest.json against v1 schema
#
# Implements TICKET-010.b / ADR-0020: the schema validator complement to the
# scripts/emit-manifest.sh emitter (TICKET-010.a / ADR-0019). Walks every
# `.harness/audit/*.manifest.json` and checks:
#
#   * JSON is parseable
#   * schema_version == "1"
#   * Required top-level fields present: ticket_id, created_at, status, sources,
#     manifest_generator, signature
#   * status is one of: green | red | blocked
#   * sources is a non-empty array; each entry has kind, path, sha256, size_bytes
#   * upstream_provenance_manifest_ref is null OR a path that exists
#
# Reused by scripts/audit-doc-drift.sh as the F-6 pattern.
#
# Usage:
#   scripts/audit-manifest.sh                     # scan all .harness/audit/*.manifest.json
#   scripts/audit-manifest.sh path/to/file.json   # validate one explicit file
#   scripts/audit-manifest.sh --quiet             # suppress per-file OK output
#
# Exit codes:
#   0  all manifests valid (or none present — empty directory is not an error)
#   1  one or more findings (invalid schema, missing fields, type errors)
#   2  error (script invocation problem; not a finding)
#
# Portability: bash 3.2 + BSD coreutils; uses `node -e` for JSON validation
# (node is already a harness dependency per scripts/smoke-e2e.sh).

set -u

# Epoch-aware enforcement (ADR-0071): source the shared epoch library so this audit
# participates in the uniform epoch-gate surface (operator directive: all 17 audits).
# Exposes epoch_current_pin / epoch_resolve_baseline / epoch_filter_new /
# epoch_req_gated; sourcing is side-effect-free (functions only).
_EPOCH_AUDIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# shellcheck disable=SC1090
. "$_EPOCH_AUDIT_DIR/_lib/epoch-gate.sh"

QUIET=0
EXPLICIT_FILE=""

for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help)
            sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//' >&2
            exit 0
            ;;
        --*)
            printf 'audit-manifest.sh: unknown flag: %s\n' "$arg" >&2
            exit 2
            ;;
        *)
            if [ -n "$EXPLICIT_FILE" ]; then
                printf 'audit-manifest.sh: only one explicit file allowed\n' >&2
                exit 2
            fi
            EXPLICIT_FILE="$arg"
            ;;
    esac
done

log() {
    if [ "$QUIET" -eq 0 ]; then
        printf '%s\n' "$*"
    fi
}

command -v node >/dev/null 2>&1 || { printf 'audit-manifest.sh: node not found in PATH\n' >&2; exit 2; }

findings_file=$(mktemp -t audit-manifest.XXXXXX) || { printf 'audit-manifest.sh: mktemp failed\n' >&2; exit 2; }
trap 'rm -f -- "$findings_file"' EXIT INT TERM

findings=0
emit() {
    findings=$((findings + 1))
    printf '[manifest-audit] %s\n' "$*" >> "$findings_file"
}

# Validate one manifest file. Uses node for JSON parsing + structural checks.
validate_one() {
    local f="$1"
    local result
    if ! result=$(env MANIFEST_FILE="$f" node -e '
        const fs = require("fs");
        const path = process.env.MANIFEST_FILE;
        let m;
        try {
            m = JSON.parse(fs.readFileSync(path, "utf8"));
        } catch (e) {
            console.log("FAIL:json-parse:" + e.message);
            process.exit(0);
        }
        const findings = [];
        const must = ["schema_version", "ticket_id", "created_at", "status", "sources", "upstream_provenance_manifest_ref", "manifest_generator", "signature"];
        for (const k of must) {
            if (!(k in m)) findings.push("missing-field:" + k);
        }
        if (m.schema_version !== "1") findings.push("schema_version-not-1:" + JSON.stringify(m.schema_version));
        if (typeof m.ticket_id !== "string" || !m.ticket_id) findings.push("ticket_id-invalid");
        if (typeof m.created_at !== "string" || !/^20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(m.created_at)) findings.push("created_at-not-iso8601-utc");
        if (!["green", "red", "blocked"].includes(m.status)) findings.push("status-not-enum:" + JSON.stringify(m.status));
        if (!Array.isArray(m.sources) || m.sources.length < 1) {
            findings.push("sources-not-nonempty-array");
        } else {
            const validKinds = new Set(["request", "response", "decision_trail", "response_missing"]);
            for (let i = 0; i < m.sources.length; i++) {
                const s = m.sources[i];
                if (!s || typeof s !== "object") { findings.push("source[" + i + "]-not-object"); continue; }
                if (!validKinds.has(s.kind)) findings.push("source[" + i + "]-bad-kind:" + JSON.stringify(s.kind));
                if (typeof s.path !== "string") findings.push("source[" + i + "]-path-not-string");
                if (s.kind === "response_missing") {
                    if (s.sha256 !== null) findings.push("source[" + i + "]-response_missing-sha256-not-null");
                    if (s.size_bytes !== 0) findings.push("source[" + i + "]-response_missing-size-not-0");
                } else {
                    if (typeof s.sha256 !== "string" || !/^[a-f0-9]{64}$/.test(s.sha256)) findings.push("source[" + i + "]-sha256-not-64-hex");
                    if (typeof s.size_bytes !== "number" || s.size_bytes < 0) findings.push("source[" + i + "]-size_bytes-not-nonneg-number");
                }
            }
        }
        if (m.upstream_provenance_manifest_ref !== null && typeof m.upstream_provenance_manifest_ref !== "string") {
            findings.push("upstream_provenance_manifest_ref-not-string-or-null");
        }
        if (m.upstream_provenance_manifest_ref && !fs.existsSync(m.upstream_provenance_manifest_ref)) {
            findings.push("upstream_provenance_manifest_ref-path-missing:" + m.upstream_provenance_manifest_ref);
        }
        if (!m.manifest_generator || typeof m.manifest_generator !== "object") {
            findings.push("manifest_generator-not-object");
        } else if (typeof m.manifest_generator.tool !== "string" || !m.manifest_generator.tool) {
            findings.push("manifest_generator.tool-invalid");
        }
        if (m.signature !== null && typeof m.signature !== "string") {
            findings.push("signature-not-null-or-string");
        }
        if (findings.length === 0) {
            console.log("OK");
        } else {
            console.log("FAIL:" + findings.join(","));
        }
    ' 2>&1); then
        emit "$f: node parse threw — $(printf '%s' "$result" | head -1)"
        return 1
    fi
    if [ "$result" = "OK" ]; then
        log "[manifest-audit] OK $f"
        return 0
    fi
    # Strip "FAIL:" prefix and emit each finding
    rest=${result#FAIL:}
    # Split comma-separated findings
    IFS=','
    for fnd in $rest; do
        emit "$f: $fnd"
    done
    unset IFS
    return 1
}

# Walk manifest files.
if [ -n "$EXPLICIT_FILE" ]; then
    [ -f "$EXPLICIT_FILE" ] || { printf 'audit-manifest.sh: file not found: %s\n' "$EXPLICIT_FILE" >&2; exit 2; }
    validate_one "$EXPLICIT_FILE" || true
else
    audit_dir=".harness/audit"
    if [ ! -d "$audit_dir" ]; then
        log "[manifest-audit] OK (no .harness/audit/ directory; nothing to validate)"
        exit 0
    fi
    found_any=0
    for f in "$audit_dir"/*.manifest.json; do
        # Guard against literal glob when no files match (bash 3.2 nullglob unavailable).
        [ -f "$f" ] || continue
        found_any=1
        validate_one "$f" || true
    done
    if [ "$found_any" -eq 0 ]; then
        log "[manifest-audit] OK (no .harness/audit/*.manifest.json files; nothing to validate)"
        exit 0
    fi
fi

if [ "$findings" -eq 0 ]; then
    log "[manifest-audit] OK — all manifests valid."
    exit 0
fi

cat -- "$findings_file"
printf '[manifest-audit] %d finding(s).\n' "$findings" >&2
exit 1
