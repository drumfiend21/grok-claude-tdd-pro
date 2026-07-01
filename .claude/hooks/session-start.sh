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

# Agent operating compact gate (per TICKET-068 / ADR-0057). Fail-closed binding:
# the operator MUST accept docs/agent-operating-compact.md before GCTP may build
# the user's product, and the agent is enforced by that agreement. This is the
# deliberate ADR-scoped exception to ADR-0001's warn-only session-start policy.
# When acceptance is absent/stale, present a STOP banner + the accept command;
# when current, the audit prints one OK line. The hook still exits 0 (you cannot
# accept in a dead session, and a SessionStart hook cannot hard-halt) — the real
# teeth are the CLAUDE.md/AGENTS.md binding + the CI/pre-commit machine gate.
if [ -x scripts/audit-agent-compact.sh ]; then
    if ! scripts/audit-agent-compact.sh; then
        echo ""
        echo "  ====  STOP — GCTP OPERATING COMPACT NOT ACCEPTED  ===="
        echo "  GCTP is NOT authorized to build the user's product until the operating"
        echo "  compact is accepted by the operator. The agent MUST NOT drive"
        echo "  /consult /roadmap /decompose /dispatch /inner-loop until then —"
        echo "  only read docs and run the accept command below."
        echo "    review : docs/agent-operating-compact.md"
        echo "    accept : ./scripts/accept-compact.sh"
        echo ""
    fi
fi

# Standards rule registry sync (per TICKET-032 / ADR-0037).
# Aggregates the plugin's standards/rubric pipeline into .harness/rules/active.json
# so both Grok and Claude consume operator-declared rules (OWASP, Google, SLSA, etc.)
# at session start. WARN-not-FAIL: a sync failure surfaces but does not block.
if [ -x scripts/standards-sync.sh ]; then
    scripts/standards-sync.sh || true
fi

# Standards source-refresh on the operator's cadence (per TICKET-075 / ADR-0064).
# GCTP consumes CTP as a pinned snapshot, so CTP's own begin-refreshing-on-install
# (§28.23) never fires here. This drives CTP's standards/initial-refresh.sh on the
# configured cadence (default: every active day), re-scraping the cited sources
# (OWASP/Google/NIST/SLSA/AWS WA/EO/…) so enforcement tracks upstream, then
# re-aggregates active.json. It also surfaces WHY freshness matters and, until the
# operator chooses a cadence, prompts for one. Non-fatal + offline-tolerant.
if [ -x scripts/standards-refresh.sh ]; then
    scripts/standards-refresh.sh --check || true
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

# Authoritative-source citation-integrity gate (per TICKET-051 / ADR-0049).
# Verifies every enforced rule in .harness/rules/active.json traces to a cited
# authoritative source (full fullstack + cloud namespace coverage) AND that every
# authoritative-source doc named in CLAUDE.md — including the TIER-0 supreme corpus
# — exists and is cross-referenced. WARN-not-FAIL at session start; CI is the hard gate.
if [ -x scripts/audit-source-citations.sh ]; then
    scripts/audit-source-citations.sh || true
fi

# Architecture cross-check gate (per TICKET-065 / ADR-0056). GCTP's dual-enforcement
# on CTP's architecture output: for any present consult artifact
# (.harness/handoffs/FEATURE-NNN.architecture.json), every decision's applicable_rules
# must resolve in active.json and include the non-exemptible EO rules; cross-check
# records must not carry an un-deviated fail. Vacuous until /consult runs. WARN at
# session start; CI is the hard gate.
if [ -x scripts/audit-architecture-crosscheck.sh ]; then
    scripts/audit-architecture-crosscheck.sh || true
fi

# rules_verified gate (Proposal B, harness-side; TICKET-067). The harness owns the
# enforcement spine; the plugin owns rule content + detectors. For every handoff
# request/response pair, a green response MUST verify every applicable rule as
# pass/deviated (deviations need a docs/deviations.md row); any fail/missing key
# forces red. Content-agnostic: vacuous until a handoff carries applicable_rules.
# WARN-not-FAIL at session start; CI is the hard gate.
if [ -x scripts/audit-rules-verified.sh ]; then
    scripts/audit-rules-verified.sh || true
fi

# applicable_rules under-scoping gate (Fix A, TICKET-071 / ADR-0060). For every
# handoff request, every ticket MUST carry all g-universal-* rules (apply-by-default)
# + the language floor for each typed file_scope glob — the kata's under-scoping
# (TS scoped to two rules, full ruleset never run) becomes a static RED. Content-
# agnostic: vacuous until a request carries applicable_rules + active.json is present.
# WARN-not-FAIL at session start; CI is the hard gate.
if [ -x scripts/audit-applicable-rules.sh ]; then
    scripts/audit-applicable-rules.sh || true
fi

# Design-phase MD gate (ADR-0066 D-D, TICKET-079 / CL-C). For every handoff request
# whose file_scope.may_edit touches architectural Markdown (docs/architecture/**,
# docs/adr/**, docs/decisions/**, or any .md with frontmatter kind: architecture|adr|
# decision), checks that every rule with applies_to_prose:true is either green per the
# prose judge OR carries a matching deviation row in <app_root>/docs/deviations.md.
# Content-agnostic: vacuous until active.json carries applies_to_prose:true rules AND
# an app_root is configured AND a request touches architectural MD. WARN-not-FAIL at
# session start; the hard gate is /dispatch (pre-emit, per .claude/commands/dispatch.md).
if [ -x scripts/audit-design-phase-md.sh ]; then
    scripts/audit-design-phase-md.sh || true
fi

# Dynamic standards re-run gate (Fix C, TICKET-074 / ADR-0063). For every green
# handoff response, re-runs the detectors against the app_root (via enforce-standards.sh)
# and asserts the response's rules_verified claims MATCH the live verdicts + that every
# live pass evaluated ≥1 file — converting "claims complete" to "claims true". VACUOUS
# until an operator configures .harness/app.json (no external app ⇒ nothing to re-verify).
# WARN-not-FAIL at session start; CI is the hard gate.
if [ -x scripts/audit-standards-enforced.sh ]; then
    scripts/audit-standards-enforced.sh || true
fi

# Development-path coverage (CL-I / ADR-0074): every corpus rule must resolve to a
# development path (iac/fullstack/both) — the partition behind both-paths pre-write
# enforcement (§28.63/§28.68). Vacuous on a pre-§28.63 cache. WARN at session start.
if [ -x scripts/audit-development-paths.sh ]; then
    scripts/audit-development-paths.sh || true
fi

exit 0
