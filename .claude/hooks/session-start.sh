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
else
    echo "[session-start] WARN: scripts/sync-plugin.sh missing or not executable; plugin sync skipped."
fi

exit 0
