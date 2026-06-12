# Security Policy

## Reporting a vulnerability

If you believe you've found a security issue in this repo, **please do not file a public GitHub issue**. Instead:

1. Email the maintainer (see the GitHub profile attached to the most recent commit on `main` for current contact).
2. Include: a description of the issue, steps to reproduce, the commit SHA where you observed it, and your assessment of impact.
3. Allow up to 7 days for an initial response.

## Scope

This repository (`grok-claude-tdd-pro`) is a substrate harness — primarily Bash scripts, Markdown rulebooks, JSON wire-format contracts, and Claude Code hook configurations. The relevant attack surfaces are:

| Surface | Class | Where to look |
|---|---|---|
| Claude Code hooks (`PreToolUse`, `PostToolUse`, `SessionStart`) | Tool-arg injection at write-time | `.claude/hooks/*.sh` |
| Substrate scripts invoked at session start + pre-commit | Local-shell propagation | `scripts/*.sh` |
| Grok templates fed to LLM-driven agents | Prompt-injection vectors | `.grok/templates/*.md` |
| Plugin pin contract surface | Supply-chain risk on the pinned commit | `docs/claude-tdd-pro.lock.yaml` |

## What's already in place

The harness ships a re-runnable security audit covering six known-dangerous shell pattern classes mapped to canonical CWE / OWASP attack vectors:

```bash
./scripts/audit-hook-security.sh
```

Pattern classes (full details in [`docs/security-review.md`](docs/security-review.md)):

- **S-1** unprotected `eval` (CWE-95 Eval Injection)
- **S-2** `curl | bash` / `wget | sh` (CWE-494 Download of Code Without Integrity Check)
- **S-3** `rm -rf` (CWE-73 External Control of File Name)
- **S-4** hardcoded credentials (CWE-798 Hard-coded Credentials)
- **S-5** `sudo` invocation (CWE-250 Execution with Unnecessary Privileges)
- **S-6** `bash -c` with unquoted variable (CWE-77 Command Injection)

The audit uses an approval-baseline pattern (per ADR-0032 / 0034): known-accepted findings live in `tests/hook-security-baseline.txt`; the script exits 0 when current findings match the baseline, 1 when new findings appear, 2 on script error. New findings are surfaced as a regression.

At the time of the last audit, **zero findings in classes S-1, S-2, S-4, S-5, S-6.** The baseline at v1 covers only 15 bounded `rm -rf` cleanup operations in `rm -f -- "$tmp"` form, all with explicit locally-constructed paths.

## Supply chain

The harness consumes `claude-tdd-pro` at a pinned commit SHA via `docs/claude-tdd-pro.lock.yaml`. Bumping the pin requires an ADR per `docs/architecture-principles.md §15`. Pin bumps run a contract-surface drift check (`sync-plugin.sh --check`) and a plugin-surface declaration audit (`audit-plugin-surface.sh`) before the bump can land.

The harness also pins the host Claude Code version range via `docs/claude-code-compat.yaml` per ADR-0036 — if the running CLI falls outside the declared range, the SessionStart hook prints a WARN line. See `docs/claude-code-upgrade-runbook.md` for the operator procedure.

## What's deferred

Per the standing over-engineering filter and the documented out-of-scope sections in the ADR series:

- **Cryptographic signing** of substrate scripts and manifest artifacts — `signature: null` at v1 per ADR-0018 §3. Trigger to revisit: signature-rotation requirements with KMS access.
- **MCP-server permission audits** — not yet self-hosted in this repo; harness consumes GitHub MCP tools via Claude Code's broker.
- **Pre-commit wiring of `audit-hook-security.sh`** — currently on-demand + part of `tests/test-all.sh`; pre-commit integration triggered by the first operator-reported hook bug.

See `docs/security-review.md §7` for the full deferral list with named triggers.

## Disclosure timeline

Once a vulnerability is reported privately:

1. Maintainer acknowledges within 7 days.
2. Maintainer assesses severity and produces a fix candidate.
3. A new ADR documents the fix + the deferral or scan policy that should have caught it.
4. Public disclosure happens once the fix has been on `main` for ≥ 7 days (sooner if the issue is actively exploited; later if rollout requires more time).
