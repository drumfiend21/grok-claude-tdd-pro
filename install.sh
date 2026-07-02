#!/usr/bin/env bash
# install.sh — one-command setup for grok-claude-tdd-pro.
#
# Goal: get a newcomer from "just cloned this" to "it works" in well under a
# minute, with plain-language output and no prior knowledge required. The slow
# part is a one-time download of the pinned engineering plugin; everything else
# is near-instant.
#
# What it does (three steps):
#   1. Materializes the pinned `claude-tdd-pro` plugin cache (scripts/sync-plugin.sh --ensure).
#   2. Wires the Grok outer loop (TICKET-109): auto-installs the Grok Build CLI
#      from x.ai/cli if missing, asks ONCE for your XAI_API_KEY (only if it can't
#      find one), and persists it to ~/.config/gctp/xai_key (chmod 600) so every
#      future session and clone on this machine just works. Failures here are
#      warnings, never fatal — the harness still runs stub-first without Grok.
#   3. Proves the harness works end-to-end (scripts/smoke-e2e.sh) — exits non-zero
#      with a clear message if anything is wrong, so install problems surface here.
#
# Usage:
#   ./install.sh              # set up + verify (default)
#   ./install.sh --quick      # set up only; skip the end-to-end verification
#   ./install.sh --no-grok    # skip step 2 (no Grok CLI install, no key prompt)
#   ./install.sh -h|--help    # this help
#
# Env overrides: GCTP_KEY_FILE (key location; default ~/.config/gctp/xai_key),
#   GROK_ENV_FILE (repo-local .env; default .grok/.env),
#   GCTP_GROK_INSTALL=skip (detect the grok CLI but never auto-install it).
#
# Exit codes:
#   0  installed (and verified, unless --quick)
#   1  a prerequisite is missing OR a step failed
#   2  usage error (unknown flag)
#
# Portability: bash 3.2 + BSD/GNU coreutils. No dependency beyond git + node.

set -euo pipefail

QUICK=0; NO_GROK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --quick)   QUICK=1; shift ;;
        --no-grok) NO_GROK=1; shift ;;
        -h|--help) sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'install.sh: unknown option: %s (try --help)\n' "$1" >&2; exit 2 ;;
    esac
done

# Run from the repo root regardless of where the user invoked us.
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }   # ✓
bad()  { printf '  \xe2\x9c\x97 %s\n' "$*" >&2; } # ✗
warn() { printf '  ! %s\n' "$*"; }

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
say "  Step 1/3 — downloading the engineering plugin …"
if scripts/sync-plugin.sh --ensure >/dev/null 2>&1; then
    ok "plugin ready"
else
    bad "could not download the plugin. Check your internet connection and re-run ./install.sh"
    exit 1
fi

# --- Step 2: wire the Grok outer loop (TICKET-109) ----------------------------
# Everything in this step is WARN-only: the harness is stub-first (ADR-0080), so
# a missing CLI or key degrades to stub outer-loop runs, never a broken install.
KEY_FILE="${GCTP_KEY_FILE:-$HOME/.config/gctp/xai_key}"
ENV_FILE="${GROK_ENV_FILE:-.grok/.env}"

persist_key() { # $1 = the key. 0600 file in a 0700 dir; never echoed.
    keydir=$(dirname "$KEY_FILE")
    mkdir -p "$keydir" 2>/dev/null || true
    chmod 700 "$keydir" 2>/dev/null || true
    ( umask 077; printf '%s\n' "$1" > "$KEY_FILE" )
    chmod 600 "$KEY_FILE" 2>/dev/null || true
}

if [ "$NO_GROK" -eq 1 ]; then
    say "  Step 2/3 — skipped (--no-grok): Grok outer loop stays in stub mode."
else
    say "  Step 2/3 — wiring the Grok outer loop …"

    # 2a. The Grok Build CLI — detect, else auto-install from the official x.ai installer.
    if command -v grok >/dev/null 2>&1; then
        ok "grok CLI found"
    elif [ "${GCTP_GROK_INSTALL:-}" = "skip" ]; then
        warn "grok CLI not found (auto-install disabled by GCTP_GROK_INSTALL=skip) — outer loop stays stub."
    elif command -v curl >/dev/null 2>&1; then
        say "    grok CLI not found — installing it now (one-time, from x.ai/cli) …"
        if curl -fsSL https://x.ai/cli/install.sh | bash >/dev/null 2>&1; then
            hash -r 2>/dev/null || true
            if command -v grok >/dev/null 2>&1 || [ -x "$HOME/.local/bin/grok" ]; then
                ok "grok CLI installed"
                command -v grok >/dev/null 2>&1 || warn "grok landed in ~/.local/bin — open a new terminal (or add it to PATH) before live runs."
            else
                warn "the x.ai installer ran but 'grok' isn't on PATH yet — open a new terminal and re-run ./install.sh to finish."
            fi
        else
            warn "could not auto-install the grok CLI (offline? blocked?). Install it later from x.ai/cli — the harness still works (stub outer loop)."
        fi
    else
        warn "curl not found, so the grok CLI can't be auto-installed. Install it from x.ai/cli when ready."
    fi

    # 2b. The key — discover (env → repo .grok/.env → key file); ask once only if absent.
    key=""
    key_src=""
    if [ -n "${XAI_API_KEY:-}" ]; then key="$XAI_API_KEY"; key_src="your environment"; fi
    if [ -z "$key" ] && [ -f "$ENV_FILE" ]; then
        key=$(sed -n 's/^[[:space:]]*XAI_API_KEY[[:space:]]*=[[:space:]]*//p' "$ENV_FILE" | head -n 1 | sed "s/^[\"']//; s/[\"']\$//")
        [ -n "$key" ] && key_src="$ENV_FILE"
    fi
    if [ -z "$key" ] && [ -f "$KEY_FILE" ]; then
        IFS= read -r key < "$KEY_FILE" || true
        [ -n "$key" ] && key_src="$KEY_FILE"
    fi

    if [ -n "$key" ] && [ "$key_src" != "$KEY_FILE" ] && [ ! -f "$KEY_FILE" ]; then
        # Found via env or .env but not yet persisted — persist so it's one-time-ever.
        persist_key "$key"
        ok "XAI_API_KEY found in $key_src — saved to $KEY_FILE (chmod 600) so you never set it again."
    elif [ -n "$key" ]; then
        ok "XAI_API_KEY found ($key_src)"
    elif [ -t 0 ]; then
        say ""
        say "    One-time setup: paste your xAI API key (from https://console.x.ai)."
        say "    It is stored ONLY at $KEY_FILE (chmod 600, never committed)."
        printf '    XAI_API_KEY (input hidden, Enter to skip): '
        read -r -s key || key=""
        say ""
        if [ -z "$key" ]; then
            warn "no key entered — outer loop stays stub. Re-run ./install.sh (or export XAI_API_KEY) any time."
        else
            case "$key" in
                xai-*) : ;;
                *) warn "that doesn't look like an xAI key (they start with 'xai-') — saving it anyway; re-run ./install.sh to replace it." ;;
            esac
            if command -v curl >/dev/null 2>&1; then
                http=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -H "Authorization: Bearer $key" https://api.x.ai/v1/models 2>/dev/null || echo 000)
                case "$http" in
                    2*)      ok "key accepted by api.x.ai" ;;
                    401|403) warn "api.x.ai rejected that key (HTTP $http) — saved anyway; double-check it at console.x.ai and re-run ./install.sh to replace." ;;
                    *)       warn "couldn't reach api.x.ai to validate (HTTP $http) — saved; it'll be exercised on the first live run." ;;
                esac
            fi
            persist_key "$key"
            ok "key saved to $KEY_FILE (chmod 600). You will not be asked again on this machine."
        fi
    else
        warn "no XAI_API_KEY found and this isn't an interactive terminal — outer loop stays stub."
        warn "Fix later with: export XAI_API_KEY=…  (or re-run ./install.sh in a terminal to save it once)."
    fi

    # 2c. Readiness verdict — no network, never prints the key (scripts/grok-run.sh --preflight).
    if scripts/grok-run.sh --preflight >/dev/null 2>&1; then
        ok "Grok outer loop: LIVE — /research, /decompose, /dispatch will invoke real grok -p runs."
    else
        warn "Grok outer loop: STUB for now — run scripts/grok-run.sh --preflight to see what's missing."
    fi
fi

# --- Step 3: verify end-to-end -----------------------------------------------
if [ "$QUICK" -eq 0 ]; then
    say "  Step 3/3 — checking everything works …"
    if scripts/smoke-e2e.sh >/dev/null 2>&1; then
        ok "verified — the harness ran a full cycle successfully"
    else
        bad "setup finished but the self-check failed."
        bad "Run ./scripts/smoke-e2e.sh --verbose to see why, or open an issue with that output."
        exit 1
    fi
else
    say "  Step 3/3 — skipped (--quick)"
fi

END=$(date +%s 2>/dev/null || echo 0)
ELAPSED=$((END - START))

say ""
say "  ✅ Done${START:+ in ${ELAPSED}s}. You're ready to go."
say ""
say "  What now:"
say "   • Open this folder in an AI coding assistant (Cursor or Claude Code) — or run 'grok' in it."
say "   • In the chat box, just describe what you want to build, in plain English."
say "   • See a worked example first: docs/end-to-end-demo/README.md"
say "   • More detail when you want it: QUICKSTART.md"
say ""
