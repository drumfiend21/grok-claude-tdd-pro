---
name: Bug / regression
about: Something that worked is now broken, or a documented contract is violated
title: '[BUG] '
labels: bug
---

## What broke

<!-- One paragraph: which command / script / audit / hook misbehaved. -->

## Steps to reproduce

```bash
# Minimal commands that show the issue. Include `git rev-parse HEAD` so the
# maintainer can pin the exact commit.
git rev-parse HEAD
./scripts/sync-plugin.sh --ensure
# ... your repro steps ...
```

## Expected vs actual

- **Expected:** <!-- what the contract / ADR / rulebook says should happen -->
- **Actual:** <!-- what you saw -->

## Relevant context

- Branch:
- Plugin pin SHA from `docs/claude-tdd-pro.lock.yaml`:
- Claude Code version (`claude --version`):
- Operating system + bash version (`bash --version`):

## Audit chain output

Please paste the relevant section. At minimum:

```text
./scripts/audit-doc-drift.sh
./tests/test-all.sh --quiet
```

## Suspected rule violation

If this looks like a violation of a TIER-0/1/2 rule, name the rule (e.g., D-6, R-2, C-23) and quote the relevant line.
