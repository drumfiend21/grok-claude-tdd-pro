#!/bin/bash
# session-start.sh — runs at the start of every Claude Code session.
#
# Today: thin wrapper around scripts/sync-plugin.sh --check, which compares
# this repo's pinned claude-tdd-pro plugin SHA + contract-surface hashes
# against upstream. Output lands in session context so every agent (local,
# remote, cloud, GitHub Action, IDE) opens knowing whether the plugin pin
# matches upstream.
#
# Warn-only policy (per docs/adr/0001-plugin-lockfile-session-sync.md): drift
# (sync-plugin.sh exit 1) is informational, not fatal — we surface it but
# always exit 0 so the session is never blocked. A real error (exit 2) is
# also surfaced and not propagated, because a network/tool failure shouldn't
# strand a session that can still do useful work.
#
# Runs unconditionally (not gated on $CLAUDE_CODE_REMOTE) because CLAUDE.md
# requires the sync to apply to every session type.

set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [ -x scripts/sync-plugin.sh ]; then
    scripts/sync-plugin.sh --check
    SYNC_EXIT=$?
    if [ "$SYNC_EXIT" -eq 2 ]; then
        echo "[session-start] sync-plugin.sh reported an error (exit 2). Session continuing; investigate before acting on plugin state."
    fi
    # Materialize the plugin cache at the pinned commit so that the
    # .claude/skills/* symlinks resolve. Idempotent: no-op if the cache is
    # already at the pinned commit. Required by TICKET-004 (skill consumption).
    scripts/sync-plugin.sh --ensure
    ENSURE_EXIT=$?
    if [ "$ENSURE_EXIT" -ne 0 ]; then
        echo "[session-start] sync-plugin.sh --ensure failed (exit $ENSURE_EXIT). Skills under .claude/skills/ may not resolve. Session continuing."
    fi
else
    echo "[session-start] WARN: scripts/sync-plugin.sh missing or not executable; plugin sync skipped."
fi

# Claude Code host-CLI version compat check (per TICKET-031 / ADR-0036).
# Mirrors the plugin-pin drift-detect pattern: WARN if outside the declared
# supported_range; never blocks. Operator follows docs/claude-code-upgrade-runbook.md.
if [ -x scripts/audit-claude-code-compat.sh ]; then
    scripts/audit-claude-code-compat.sh || true
fi

# Standards rule registry sync (per TICKET-032 / ADR-0037).
# Aggregates the plugin's standards/rubric pipeline into .harness/rules/active.json
# so both Grok and Claude consume operator-declared rules (OWASP, Google, SLSA, etc.)
# at session start. WARN-not-FAIL: a sync failure surfaces but does not block.
if [ -x scripts/standards-sync.sh ]; then
    scripts/standards-sync.sh || true
fi

# Plugin surface declaration audit (per TICKET-032 / ADR-0037).
# Catches the regression class where a plugin pin bump introduces a new
# top-level directory and the consumption registry doesn't acknowledge it.
if [ -x scripts/audit-plugin-surface.sh ]; then
    scripts/audit-plugin-surface.sh || true
fi

# EO-2026 governance enforcement spine (per TICKET-050 / ADR-0045..0048).
# Verifies the always-on, non-exemptible EO governance invariants over present
# handoff artifacts: every active EO-namespace rule appears in each request's
# applicable_rules, and every green response carries the two-phase design
# attestation (eo_design_conformance). Content-agnostic: vacuous until an
# EO-namespace rule lands in active.json via a plugin pin bump. WARN-not-FAIL
# at session start; CI (.github/workflows/test.yml) is the hard gate.
if [ -x scripts/audit-eo-governance.sh ]; then
    scripts/audit-eo-governance.sh || true
fi

exit 0
