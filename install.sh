#!/usr/bin/env bash
# install.sh — one-command setup for grok-claude-tdd-pro.
#
# Goal: get a newcomer from "just cloned this" to "it works" in well under a
# minute, with plain-language output and no prior knowledge required. The slow
# part is a one-time download of the pinned engineering plugin; everything else
# is near-instant.
#
# What it does (two steps):
#   1. Materializes the pinned `claude-tdd-pro` plugin cache (scripts/sync-plugin.sh --ensure).
#   2. Proves the harness works end-to-end (scripts/smoke-e2e.sh) — exits non-zero
#      with a clear message if anything is wrong, so install problems surface here.
#
# Usage:
#   ./install.sh            # set up + verify (default)
#   ./install.sh --quick    # set up only; skip the end-to-end verification
#   ./install.sh -h|--help  # this help
#
# Exit codes:
#   0  installed (and verified, unless --quick)
#   1  a prerequisite is missing OR a step failed
#   2  usage error (unknown flag)
#
# Portability: bash 3.2 + BSD/GNU coreutils. No dependency beyond git + node.

set -euo pipefail

QUICK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --quick)   QUICK=1; shift ;;
        -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'install.sh: unknown option: %s (try --help)\n' "$1" >&2; exit 2 ;;
    esac
done

# Run from the repo root regardless of where the user invoked us.
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }   # ✓
bad()  { printf '  \xe2\x9c\x97 %s\n' "$*" >&2; } # ✗

START=$(date +%s 2>/dev/null || echo 0)

say ""
say "  Installing grok-claude-tdd-pro …"
say "  (one-time setup — usually 20–30 seconds, mostly a download)"
say ""

# --- Prerequisites -----------------------------------------------------------
missing=0
if command -v git >/dev/null 2>&1; then ok "git found"; else
    bad "git is not installed. Install it from https://git-scm.com and re-run ./install.sh"; missing=1
fi
if command -v node >/dev/null 2>&1; then
    ok "node found ($(node --version 2>/dev/null))"
else
    bad "node is not installed. Install any recent version from https://nodejs.org and re-run ./install.sh"; missing=1
fi
if [ ! -x scripts/sync-plugin.sh ]; then
    bad "this doesn't look like the project folder (scripts/sync-plugin.sh is missing)."
    bad "Make sure you ran ./install.sh from inside the grok-claude-tdd-pro folder."; missing=1
fi
if [ "$missing" -ne 0 ]; then
    say ""
    say "  Setup stopped — please fix the item(s) marked ✗ above, then run ./install.sh again."
    exit 1
fi

# --- Step 1: materialize the plugin cache ------------------------------------
say ""
say "  Step 1/2 — downloading the engineering plugin …"
if scripts/sync-plugin.sh --ensure >/dev/null 2>&1; then
    ok "plugin ready"
else
    bad "could not download the plugin. Check your internet connection and re-run ./install.sh"
    exit 1
fi

# --- Step 2: verify end-to-end -----------------------------------------------
if [ "$QUICK" -eq 0 ]; then
    say "  Step 2/2 — checking everything works …"
    if scripts/smoke-e2e.sh >/dev/null 2>&1; then
        ok "verified — the harness ran a full cycle successfully"
    else
        bad "setup finished but the self-check failed."
        bad "Run ./scripts/smoke-e2e.sh --verbose to see why, or open an issue with that output."
        exit 1
    fi
else
    say "  Step 2/2 — skipped (--quick)"
fi

END=$(date +%s 2>/dev/null || echo 0)
ELAPSED=$((END - START))

say ""
say "  ✅ Done${START:+ in ${ELAPSED}s}. You're ready to go."
say ""
say "  What now:"
say "   • Open this folder in an AI coding assistant (Cursor or Claude Code)."
say "   • In the chat box, just describe what you want to build, in plain English."
say "   • See a worked example first: docs/end-to-end-demo/README.md"
say "   • More detail when you want it: QUICKSTART.md"
say ""
