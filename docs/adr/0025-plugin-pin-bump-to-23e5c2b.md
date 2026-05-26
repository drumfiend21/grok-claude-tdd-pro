# ADR-0025 — Bump plugin pin to upstream HEAD `23e5c2b` (TICKET-018)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 direction: *"Qualify and quantify over-engineering and avoid it. Assess for drift and ensure it doesn't happen. And proceed to expand upon anything that is still worth it. And then complete."*) + Claude (cloud session, implementer)
- **Supersedes:** none (extends ADR-0001 lockfile mechanism; first pin-bump ADR)
- **Extends:** ADR-0001 (plugin lockfile + session-start sync — the mechanism this ADR exercises for the first time); ADR-0002 (verification-tier model — diff classification follows the same evidence-tier discipline); `docs/architecture-principles.md §15` (the rule that requires ADR for contract-surface drift bumps)

## Context

Since the harness's birth (TICKET-001.e, pin `b277284`, 2026-05-24), the upstream `claude-tdd-pro` repo has landed one feature commit: `23e5c2b architecture-dev: 39 CLs, 22 CC contracts, §25 fidelity gate, AI-dev corpus (+379 specs) (#2)`. The session-start hook has shown the WARN every session since the upstream commit:

```
[plugin-sync] https://github.com/drumfiend21/claude-tdd-pro
  pinned    : b277284  (2026-05-24T17:43:52-04:00)
  upstream  : 23e5c2b  (main, ? commits ahead)
  contract  : 3 file(s) drifted
    - CLAUDE.md
    - docs/architecture-v1.9.md
    - .claude/skills/tdd-pro-cl-workflow/SKILL.md
  status    : WARN — contract surface drifted; review upstream before bumping
              Bumping the pin requires an ADR (architecture-principles §15)
```

Per `docs/architecture-principles.md §15` and ADR-0001, a contract-surface drift bump requires an ADR with diff classification. This is that ADR.

The drift's class — operator-bitten reality check — was assessed in the 2026-05-26 session against the over-engineering filter:

- **Operator-bitten?** YES — the WARN has shown every session for 2+ days; trust decays.
- **Composable?** YES — `scripts/sync-plugin.sh --update` already exists for bumping the pin; this ADR satisfies the §15 prerequisite.
- **R-3 risk?** Low — the lockfile is the source of truth; no duplicated content.
- **Maintenance cost?** Tiny (one lockfile edit + one cache re-materialization).
- **Deletion-pass survives?** NO — without the bump, the WARN persists indefinitely.

PASS the filter; execute.

## Diff classification (per `docs/architecture-principles.md §15` + `docs/researcher-discipline.md §2`)

Upstream commit sequence between pin and HEAD: **exactly ONE commit** (`23e5c2b`). Three contract-surface files changed; two unchanged.

### File 1: `CLAUDE.md` (+27 / -3 lines)

**Change class: ADDITIVE.** Upstream added:

- A new "PRIMARY RULESET" section at the top pointing at `generated-code-quality-standards/_universal/ai-dev-corpus.md` (an upstream-internal corpus file).
- A new "Step 0.5 — Pending-spec content fidelity check" workflow step that fires only for CLs promoting pre-existing pending specs via `probe-feature` or `promote-pending`.
- One new memory-tree file reference (`feedback-pending-spec-content-fidelity.md`).
- The §2.X count updated from "§2.7..§2.22" to "§2.7..§2.25" (reflecting the new §2.23/§2.24/§2.25 contracts).

**Harness-side impact:** ZERO breaking change. The harness consumes the trio via symlink (per ADR-0007); it does NOT run promotion CLs against upstream's `evals/pending/` tree, so the new Step 0.5 is a no-op for harness consumers. The upstream's own "PRIMARY RULESET" pointer to its own corpus is upstream's concern; the harness has its own TIER-0 corpus at `docs/ai-engineering-corpus.md` (per ADR-0005) which remains canonical for harness work.

### File 2: `docs/architecture-v1.9.md` (+72 / -8 lines)

**Change class: ADDITIVE.** Upstream added the §2.25 cross-cutting contract (the "pending spec content fidelity" contract introduced by the v1.9.2 amendment). The §2.1–§2.24 contracts that the harness depends on (e.g., §2.8 AI Provenance Manifest cited by `docs/provenance-bridging-design.md`; §2.1 Rubric rule schema cited by quality-gate) are byte-stable across the bump.

**Harness-side impact:** ZERO breaking change. The harness cites specific §2.X contracts by name (§2.1, §2.8, §2.11, §2.14, §2.15, §2.17 across self-healing-design.md + provenance-bridging-design.md + quality-gate.md); none of those contracts changed. §2.25 is new content the harness doesn't yet reference.

### File 3: `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (+13 / -0 lines)

**Change class: ADDITIVE.** Upstream added Step 0.5 to the per-CL workflow skill body — the same fidelity-gate step added to CLAUDE.md. The skill's Steps 0, 1, 2, 3 (the canonical R-G-R + audit + verify discipline the harness's inner-loop consumers invoke) are byte-stable.

**Harness-side impact:** ZERO breaking change. Step 0.5's documented trigger is *"If this CL promotes pre-existing pending specs (via `probe-feature` or `promote-pending`)"* — the harness's inner-loop sessions don't promote upstream pending specs, so the new step is a no-op for harness consumers. The R-G-R sequence the harness depends on (`tdd-pro-cl-workflow/SKILL.md` per AGENTS.md §4) is unchanged.

### Files unchanged

- `.claude/skills/tdd-pro-batch-cl/SKILL.md` — sha256 `9a00413178...` unchanged.
- `.claude/skills/tdd-pro-bash32-portability/SKILL.md` — sha256 `10d07ac999...` unchanged.

## Decision

### Bump the pin to `23e5c2b78ffe170ef875067edd14cd950c19e7b5`

All three drifted files are ADDITIVE. Zero breaking changes to the harness's consumption surface. The bump is safe per `docs/architecture-principles.md §15`.

Lockfile updates:

- `pinned_commit`: `b277284529b8b3ce3f7df904892d6ffb0080d045` → `23e5c2b78ffe170ef875067edd14cd950c19e7b5`
- `pinned_at`: `2026-05-24T17:43:52-04:00` → `2026-05-25T11:15:00-04:00`
- `pinned_message`: updated to the new commit's subject line
- `last_synced_at`: bumped to current UTC
- `last_synced_session`: `TICKET-018 pin bump`
- `contract_surface_files[].sha256` for the 3 drifted files updated to upstream-HEAD values; the 2 unchanged files' sha256s preserved.

Post-bump verification:

- `scripts/sync-plugin.sh --check` must exit 0 (no drift between new pin and HEAD).
- `scripts/sync-plugin.sh --ensure` must re-materialize cache at the new pin.
- `scripts/smoke-e2e.sh` must continue to exit 0 (toy R-G-R against `examples/string-utils/` unaffected).
- `scripts/audit-doc-drift.sh` must exit 0 (F-1..F-6 unchanged by the bump).
- `scripts/export-cursor-rules.sh --check` must exit 0 (`.cursor/rules/` content unchanged).
- `scripts/audit-manifest.sh` must exit 0.

### Don't ship the "plugin-pin-discipline" TIER-2 doc that I previously proposed

Per the over-engineering filter applied at the start of this CL: a separate TIER-2 doc codifying pin-bump discipline would duplicate content already in `scripts/sync-plugin.sh --help`, `docs/plugin-sync.md`, ADR-0001, and `docs/architecture-principles.md §15`. R-3 risk + maintenance cost exceed the value-add. The procedure is operationally complete with the existing surfaces.

### Don't ship `scripts/sync-plugin.sh --diff` as a new flag in this CL

Considered as a sub-expansion ("operator-facing diff inspection between pin and HEAD"). REJECTED per D-8 — the existing `git diff` + `--check` output names the drifted files; the operator can `cd .harness/plugin-cache/claude-tdd-pro && git diff b277284..HEAD -- <file>` if needed. Adding a script flag for this is over-engineering at v1. If the inspection becomes a frequent enough operation, a future TICKET-018.a could revisit.

## Alternatives considered

- **Hold the pin.** Rejected. The drift is purely additive; nothing breaks; the WARN persists every session indefinitely. Holding has no benefit and a real trust-decay cost.
- **Bump without an ADR.** Rejected. Architecture-principles §15 mandates ADR for contract-surface drift bumps; ADR-0001 records the mechanism. Bumping silently would be a TIER-1 invariant violation.
- **Bump only some of the drifted files** (e.g., update CLAUDE.md + architecture-v1.9.md but not SKILL.md). Rejected. The lockfile pins a SINGLE commit sha; per-file pinning would invent a new mechanism class for no value.
- **Cherry-pick upstream changes into a different pin.** Rejected. The pin is a commit, not a curated set; cherry-picking would diverge from the upstream's release line and break R-2 versioned-consumption discipline.
- **Ship the discipline TIER-2 doc anyway.** Rejected per over-engineering filter; R-3 risk + maintenance cost vs. limited value-add. Existing surfaces cover the procedure adequately.

## Consequences

### Positive

- **WARN cleared every future session.** `sync-plugin.sh --check` exits 0 once the bump lands; the session-start hook reports "OK" rather than "WARN."
- **Trust-decay reversed.** The operator (and future readers) see that the pin is current with upstream as of 2026-05-25.
- **First pin-bump ADR establishes the pattern.** Future bumps cite this ADR's diff-classification structure as the template.
- **R-2 (versioned consumption) operationally validated.** The lockfile mechanism (TICKET-001.e / ADR-0001) handles its first real bump cleanly.
- **All harness audits remain green.** Smoke + audit-doc-drift + cursor-rules + audit-manifest all exit 0 post-bump.
- **Over-engineering filter applied.** Two sub-expansions (TIER-2 discipline doc + `--diff` flag) rejected with documented rationale; net work is the bump + this ADR.

### Negative

- **Future upstream commits may not be additive.** The next bump may face breaking changes; the harness will need a heavier ADR + possible contract-surface adaptation. Mitigation: the drift-detection mechanism (sync-plugin.sh --check) catches the situation; the mandatory ADR process forces deliberate review.
- **The harness inherits one new SKILL.md Step 0.5** in `tdd-pro-cl-workflow/SKILL.md`. The harness's inner-loop consumers (Cursor's chat agent invoking `/inner-loop`, Claude Code via the symlink) will see the new step. Mitigation: Step 0.5 is no-op for non-promotion CLs (which is all harness CLs); the documented trigger is clear.
- **The §2.25 contract is new content the harness doesn't yet reference.** Future provenance-bridging or self-healing-implementation work could reference §2.25 (fidelity gate is conceptually adjacent to manifest schema validity per ADR-0020); not in scope here.

### Neutral

- **D-rule count unchanged.**
- **TIER-0 corpus untouched.**
- **§1 provenance + §3 D-rule bodies + §4 D-checklist untouched.** (Source 9 from TICKET-017 is the most recent §1 amendment; this CL doesn't touch §1.)
- **`schema_version` of the handoff contract unchanged.**
- **`schema_version` of the lockfile unchanged** (still `1`).
- **AGENTS.md unchanged in this CL.**
- **`.cursor/rules/` unchanged** (the generator's input docs are unchanged; regeneration is idempotent and yields zero diff).

## Verification (executed before commit)

- Lockfile updated with new `pinned_commit`, `pinned_at`, `pinned_message`, `last_synced_at`, `last_synced_session`, and 3 updated `sha256` entries; 2 unchanged sha256s preserved verbatim.
- `scripts/sync-plugin.sh --check` exits 0 (no drift between new pin and HEAD).
- `scripts/sync-plugin.sh --ensure` re-materializes cache at `23e5c2b` cleanly.
- `scripts/smoke-e2e.sh` exits 0.
- `scripts/audit-doc-drift.sh` exits 0 (F-1..F-6 clean; the new lockfile content doesn't trip any pattern).
- `scripts/export-cursor-rules.sh --check` exits 0.
- `scripts/audit-manifest.sh` exits 0.
- `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (via symlink) now shows the new Step 0.5 — readable by inspection.
- TICKETS.md gains TICKET-018 row marked DONE.

## Out of scope (deferred / rejected per over-engineering filter)

- **`docs/plugin-pin-discipline.md` TIER-2 doc.** REJECTED per R-3 (duplicates `sync-plugin.sh --help` + `docs/plugin-sync.md` + ADR-0001 + architecture-principles §15).
- **`scripts/sync-plugin.sh --diff` flag.** REJECTED per D-8 (existing `git diff` covers it; not operator-bitten).
- **Reference §2.25 in harness TIER-2 docs.** Defer until a future provenance / self-healing CL has a concrete cite-target need.
- **Automated upstream-drift review cadence.** Defer; current mechanism (session-start WARN + pre-commit audit) is sufficient.
- **Multi-pin support** (multiple plugins). Defer; single-plugin is the current model.

## Implementation references

- Modified: `docs/claude-tdd-pro.lock.yaml` (5 field updates per Decision; sha256 updates for the 3 drifted contract files; 2 unchanged preserved)
- Modified (via re-ensure): `.harness/plugin-cache/claude-tdd-pro/` cache re-materialized at the new pin (gitignored runtime state)
- Modified: `.cursor/rules/d-rules.mdc` — regenerated; since the cache now has the v1.9.2 SKILL.md, but the d-rules.mdc parses from `docs/founder-directives.md §3` (harness-local), the regeneration is a no-op.
- Modified: `TICKETS.md` (TICKET-018 row marked DONE)
- New: this ADR
- Related: ADR-0001 (lockfile + session-start sync mechanism — first exercise), ADR-0002 (verification-tier model — diff classification follows the additive/breaking framework), ADR-0007 (Claude skill consumption — symlink-based consumption unaffected by the bump), `docs/architecture-principles.md §15` (the rule this ADR satisfies), `docs/plugin-sync.md` (the operator-facing pin-management runbook).
