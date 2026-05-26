#!/usr/bin/env bash
# scripts/emit-manifest.sh — per-ticket provenance manifest emitter
#
# Implements the design in docs/provenance-bridging-design.md (TICKET-010 /
# ADR-0018). Produces .harness/audit/<ticket-id>.manifest.json indexing the
# three per-ticket source surfaces (request, response, decision_trail) with
# sha256 + size_bytes per source for tamper detection. Index-only per R-3 —
# no content duplication from sources.
#
# Usage:
#   scripts/emit-manifest.sh --ticket TICKET-NNN [--driver <name>] [--upstream-ref <path>] [--quiet]
#
# Flags:
#   --ticket <id>       (required) Ticket id, e.g. TICKET-042 or SELF-HEAL-2026-05-26-001
#   --driver <name>     Caller identification for manifest_generator.tool (default: emit-manifest.sh)
#   --upstream-ref <p>  Path to upstream claude-tdd-pro provenance manifest (§2.8); default: null
#   --quiet             Suppress per-source status output
#
# Exit codes:
#   0  manifest written; all three sources present and indexed
#   1  manifest written with warning (response or trail missing; status set accordingly)
#   2  error (missing --ticket; request file missing; ticket-id mismatch; write failure)
#
# Portability: bash 3.2 + BSD coreutils (per C-23, tdd-pro-bash32-portability).

set -u

TICKET=""
DRIVER="emit-manifest.sh"
UPSTREAM_REF=""
QUIET=0

while [ $# -gt 0 ]; do
    case "$1" in
        --ticket)        TICKET="$2"; shift 2 ;;
        --driver)        DRIVER="$2"; shift 2 ;;
        --upstream-ref)  UPSTREAM_REF="$2"; shift 2 ;;
        --quiet)         QUIET=1; shift ;;
        -h|--help)
            sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//' >&2
            exit 0
            ;;
        *)
            printf 'emit-manifest.sh: unknown arg: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

[ -n "$TICKET" ] || { printf 'emit-manifest.sh: --ticket is required\n' >&2; exit 2; }

log() {
    if [ "$QUIET" -eq 0 ]; then
        printf '%s\n' "$*"
    fi
}

die() {
    printf 'emit-manifest.sh: %s\n' "$*" >&2
    exit 2
}

# sha256 helper (mirrors scripts/sync-plugin.sh): prefer sha256sum (Linux),
# fall back to shasum -a 256 (macOS/BSD).
if command -v sha256sum >/dev/null 2>&1; then
    SHA_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA_CMD="shasum -a 256"
else
    die "neither sha256sum nor shasum found in PATH"
fi

sha256_of() {
    $SHA_CMD "$1" | awk '{print $1}'
}

# file size — wc -c < file is portable; strip leading whitespace BSD-style.
size_of() {
    wc -c < "$1" | tr -d ' '
}

REQ_PATH=".harness/handoffs/${TICKET}.req.json"
RES_PATH=".harness/handoffs/${TICKET}.res.json"
TRAIL_PATH=".harness/trails/${TICKET}.md"
AUDIT_DIR=".harness/audit"
MANIFEST_PATH="${AUDIT_DIR}/${TICKET}.manifest.json"

[ -f "$REQ_PATH" ] || die "request file missing: $REQ_PATH (run /dispatch or scripts/smoke-e2e.sh first)"

mkdir -p "$AUDIT_DIR" || die "could not create $AUDIT_DIR"

# ticket-id agreement check across .req.json and .res.json (defensive — catches
# operator running emit-manifest --ticket X on a wire from --ticket Y).
req_ticket_id=$(awk -F'"' '/"ticket_id"[[:space:]]*:/{print $4; exit}' "$REQ_PATH")
if [ -n "$req_ticket_id" ] && [ "$req_ticket_id" != "$TICKET" ]; then
    die "ticket-id mismatch: $REQ_PATH has '$req_ticket_id' but --ticket says '$TICKET'"
fi

# Compute sources[]. Per design §6: request must exist; response and trail are
# optional (status reflects what's present).
REQ_SHA=$(sha256_of "$REQ_PATH")
REQ_SIZE=$(size_of "$REQ_PATH")

STATUS="blocked"
RES_PRESENT=0
TRAIL_PRESENT=0
WARN=0

if [ -f "$RES_PATH" ]; then
    res_ticket_id=$(awk -F'"' '/"ticket_id"[[:space:]]*:/{print $4; exit}' "$RES_PATH")
    if [ -n "$res_ticket_id" ] && [ "$res_ticket_id" != "$TICKET" ]; then
        die "ticket-id mismatch: $RES_PATH has '$res_ticket_id' but --ticket says '$TICKET'"
    fi
    res_status=$(awk -F'"' '/"status"[[:space:]]*:/{print $4; exit}' "$RES_PATH")
    if [ -n "$res_status" ]; then
        STATUS="$res_status"
    fi
    RES_SHA=$(sha256_of "$RES_PATH")
    RES_SIZE=$(size_of "$RES_PATH")
    RES_PRESENT=1
else
    log "[emit-manifest] warn: response missing — status will be 'blocked'"
    WARN=1
fi

if [ -f "$TRAIL_PATH" ]; then
    TRAIL_SHA=$(sha256_of "$TRAIL_PATH")
    TRAIL_SIZE=$(size_of "$TRAIL_PATH")
    TRAIL_PRESENT=1
else
    log "[emit-manifest] warn: decision trail missing — sources will record absence"
    WARN=1
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build sources[] entries. Hand-rolled JSON to avoid jq dependency (per existing
# harness convention — see scripts/smoke-e2e.sh / sync-plugin.sh).
TMP_OUT=$(mktemp -t emit-manifest.XXXXXX) || die "mktemp failed"
trap 'rm -f -- "$TMP_OUT"' EXIT INT TERM

{
    printf '{\n'
    printf '  "schema_version": "1",\n'
    printf '  "ticket_id": "%s",\n' "$TICKET"
    printf '  "created_at": "%s",\n' "$NOW"
    printf '  "status": "%s",\n' "$STATUS"
    printf '  "sources": [\n'
    printf '    {\n'
    printf '      "kind": "request",\n'
    printf '      "path": "%s",\n' "$REQ_PATH"
    printf '      "sha256": "%s",\n' "$REQ_SHA"
    printf '      "size_bytes": %s\n' "$REQ_SIZE"
    if [ "$RES_PRESENT" -eq 1 ] || [ "$TRAIL_PRESENT" -eq 1 ]; then
        printf '    },\n'
    else
        printf '    }\n'
    fi

    if [ "$RES_PRESENT" -eq 1 ]; then
        printf '    {\n'
        printf '      "kind": "response",\n'
        printf '      "path": "%s",\n' "$RES_PATH"
        printf '      "sha256": "%s",\n' "$RES_SHA"
        printf '      "size_bytes": %s\n' "$RES_SIZE"
        if [ "$TRAIL_PRESENT" -eq 1 ]; then
            printf '    },\n'
        else
            printf '    }\n'
        fi
    else
        printf '    {\n'
        printf '      "kind": "response_missing",\n'
        printf '      "path": "%s",\n' "$RES_PATH"
        printf '      "sha256": null,\n'
        printf '      "size_bytes": 0\n'
        if [ "$TRAIL_PRESENT" -eq 1 ]; then
            printf '    },\n'
        else
            printf '    }\n'
        fi
    fi

    if [ "$TRAIL_PRESENT" -eq 1 ]; then
        printf '    {\n'
        printf '      "kind": "decision_trail",\n'
        printf '      "path": "%s",\n' "$TRAIL_PATH"
        printf '      "sha256": "%s",\n' "$TRAIL_SHA"
        printf '      "size_bytes": %s\n' "$TRAIL_SIZE"
        printf '    }\n'
    fi

    printf '  ],\n'
    if [ -n "$UPSTREAM_REF" ]; then
        # Validate the upstream ref exists; if not, set to null and warn (per
        # design §8 failure-mode-4).
        if [ -f "$UPSTREAM_REF" ]; then
            printf '  "upstream_provenance_manifest_ref": "%s",\n' "$UPSTREAM_REF"
        else
            log "[emit-manifest] warn: --upstream-ref points at missing file; setting null"
            printf '  "upstream_provenance_manifest_ref": null,\n'
            WARN=1
        fi
    else
        printf '  "upstream_provenance_manifest_ref": null,\n'
    fi
    printf '  "manifest_generator": {\n'
    printf '    "tool": "%s",\n' "$DRIVER"
    printf '    "version": null\n'
    printf '  },\n'
    printf '  "signature": null\n'
    printf '}\n'
} > "$TMP_OUT"

# Atomic rename: write to .tmp, then mv -f to target. Prevents partial writes
# from racing readers (design §8 failure-mode-3).
mv -f -- "$TMP_OUT" "$MANIFEST_PATH" || die "could not write $MANIFEST_PATH"
trap - EXIT INT TERM

log "[emit-manifest] wrote $MANIFEST_PATH (status=$STATUS)"

if [ "$WARN" -eq 1 ]; then
    exit 1
fi
exit 0
