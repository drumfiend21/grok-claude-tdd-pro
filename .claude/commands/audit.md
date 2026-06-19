---
description: Run the pre-commit audit chain (drift, cross-refs, EO governance, etc.)
---

Run the pre-commit audit chain (Claude Code mirror of `.cursor/commands/audit.md`). Run each and report pass/fail:

```
./scripts/audit-doc-drift.sh
./scripts/audit-cross-references.sh --quiet
./scripts/audit-hook-security.sh --quiet
./scripts/audit-agent-compact.sh --quiet
./scripts/audit-plugin-surface.sh --quiet
./scripts/audit-standards-conformance.sh --quiet
./scripts/audit-eo-governance.sh --quiet
./scripts/audit-applicable-rules.sh --quiet
./scripts/audit-source-citations.sh --quiet
./scripts/audit-manifest.sh
./scripts/audit-metrics.sh --quiet
./tests/test-all.sh --quiet
```

All must exit 0 before committing. Investigate and fix any non-zero exit; do not commit a red chain.
