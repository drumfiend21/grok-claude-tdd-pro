# grok-claude-tdd-pro

A harness for **disciplined AI-assisted software development** in Cursor, Claude Code, and Grok Build. Composes a Grok-orchestrated outer loop (research → decompose → dispatch) with Claude TDD Pro's per-ticket Red-Green-Refactor inner loop, joined by a JSON wire contract and gated by a drift-detectable audit trail (sha-chain via `--regenerate`; cryptographic signing deferred per ADR-0018 §3).

> **New here? Read [QUICKSTART.md](QUICKSTART.md) first.** It walks you through the 3-minute environment bootstrap + 15-minute first real cycle. This README is the structural reference; QUICKSTART is the operator entry point.

## What it is

- A **two-tier orchestration harness**. Outer loop plans (templates, no code-editing). Inner loop executes one ticket via Red-Green-Refactor (the only place code gets edited).
- A **plugin consumer**. Imports `claude-tdd-pro` by pinned commit (versioned consumption per architectural rule R-2); the plugin contributes the inner-loop skills.
- A **cross-IDE operator surface**. Same workflow drives from Cursor's chat agent, Claude Code (CLI + cloud), Grok Build CLI, or headless `claude -p` / `grok -p`. `AGENTS.md` is the cross-tool entry point.

## Why use it

AI-assisted coding without discipline produces unauditable, drift-prone output. Each piece of the harness closes a specific failure mode:

- **R-G-R per ticket** — every code change has a failing test before it has an implementation. No green-without-Red.
- **Quality gate** — 4 sub-gates (`tests_must_pass`, `coverage_delta_min`, `lint_clean`, `provenance_complete`); all four REQUIRED.
- **Per-ticket provenance manifest** at `.harness/audit/TICKET-NNN.manifest.json` — indexes request + response + decision trail with sha256 per source. Tamper-detectable via `scripts/emit-manifest.sh --regenerate`.
- **File-fence enforcement** — PostToolUse hook (Claude Code) + `.cursor/rules/` always-loaded context (Cursor) prevent edits to plugin cache, upstream symlinks, and generator-output files.
- **6 pre-commit drift audits (F-1..F-6)** — catch stale stubs, future-tense references to DONE tickets, `--help` / impl parity drift, hand-edited generator output, broken manifest schemas.
- **Cross-IDE consistency** — the same `AGENTS.md` + `.cursor/rules/` + `.claude/skills/` surface composes with xAI Grok Build's "AGENTS.md, plugins, hooks, skills, and MCP servers all work out of the box" model.

The value compounds: Day 1 is comparable to a normal Cursor session; Week 1+ shows measurable audit-trail completeness + R-G-R discipline you can demonstrate to a reviewer.

## How it works

```
Operator → Cursor / Claude Code / Grok Build
              │
              ▼
       /research → /decompose → /dispatch TICKET-NNN
       (.grok/templates/* produce structured output)
              │
              ▼
       .harness/handoffs/TICKET-NNN.req.json   ◄── wire contract (schema_version=1)
              │
              ▼
       /inner-loop TICKET-NNN
       (agent reads .claude/skills/tdd-pro-cl-workflow/SKILL.md;
        runs Red → Green → Refactor in the ticket's file_scope)
              │
              ▼
       .harness/handoffs/TICKET-NNN.res.json   ◄── response contract
       .harness/trails/TICKET-NNN.md           ◄── R-G-R decision trail
       .harness/audit/TICKET-NNN.manifest.json ◄── index + sha256 per source
              │
              ▼
       /audit  (F-1..F-6 + manifest validator)  →  commit
```

Key contracts:

- **Wire format** — `docs/handoff-contract.md` (request + response schemas).
- **Quality gate** — `docs/quality-gate.md` (4 sub-gates, severities, override policy).
- **Provenance** — `docs/provenance-bridging-design.md` + `scripts/emit-manifest.sh`.
- **Cursor integration playbook** — `docs/cursor-integration.md`.
- **Researcher discipline** (how to verify primary sources when WebFetch is blocked) — `docs/researcher-discipline.md`.
- **Authority hierarchy** — TIER 0 corpus → TIER 1 prime directive + founder-directives (D-1..D-13 over §1 sources 1-9) → TIER 2 operational rulebooks (R-1..R-20 architectural, G-1..G-21 Grok-orchestration, C-1..C-24 TDD discipline + design docs). Full enumeration in `AGENTS.md §5` and `CLAUDE.md`.

For parallel work, the **orchestrating-swarms** skill (`.claude/skills/orchestrating-swarms/SKILL.md`) fans out atomic tickets across git worktrees (one ticket = one worktree = one branch = one PR; per G-rule §8; cap 8 workers per supervisor per G-9).

### External planner context (per ADR-0040 + ADR-0041)

At every session start, `scripts/sync-plugin.sh --ensure` copies `docs/PROJECT_CONTEXT_FOR_PLANNER.md` from the pinned `claude-tdd-pro` plugin into `.harness/context/`. Grok's decomposition template reads this file BEFORE proposing tickets, so the planner is informed by the plugin's durable engineering discipline — test-shape patterns, R-G-R sizing, refactor sequencing, architecture-fidelity invariants, ADR triggers, the six CLAUDE.md drift mechanisms, and the seven bash 3.2 portability gotchas — without any per-feature round-trip cost. The static-context approach replaces an earlier dynamic per-feature consult mechanism (ADR-0039, SUPERSEDED) that was rejected as framework-itis. See `docs/adr/0040-static-context-injection-supersedes-consult.md` and `docs/adr/0041-plugin-pin-bump-23e5c2b-to-bba77df.md`; cross-paired with plugin-side `docs/adr/0006-static-context-injection-for-external-planners.md`.

## Setup — get ready to use it

### Prerequisites

You need:

- `git` (any modern version).
- `bash` 3.2+ (macOS default; the harness scripts target bash 3.2 + BSD coreutils for portability).
- `node` (any LTS version; used by `scripts/audit-manifest.sh` and `scripts/smoke-e2e.sh` for JSON parsing).
- `sha256sum` (Linux) OR `shasum` (macOS) — either works; the scripts fall back automatically.
- `curl` (used by `scripts/sync-plugin.sh` to validate connectivity).

You will probably want at least one of:

- **Cursor IDE** — recommended primary editor; auto-loads `AGENTS.md` + `.cursor/rules/*.mdc` and exposes the 7 slash commands.
- **Claude Code** (CLI or web/cloud) — auto-runs the SessionStart + PostToolUse hooks; reads CLAUDE.md.
- **Grok Build CLI** (`x.ai/cli`) — picks up `AGENTS.md` + plugins + hooks + skills + MCP servers out of the box per Source 9.

### 1. Clone

```bash
git clone https://github.com/drumfiend21/grok-claude-tdd-pro.git
cd grok-claude-tdd-pro
```

### 2. Materialize the plugin cache

This is the **session-start ritual**. It runs automatically in Claude Code (via `.claude/hooks/session-start.sh`) and in Cursor (via `.cursor/rules/agent-context.mdc` always-loaded context). Run it manually for first-time setup:

```bash
./scripts/sync-plugin.sh --ensure
```

Expected output:

```
[plugin-ensure] https://github.com/drumfiend21/claude-tdd-pro @ <pinned-sha>
  status    : OK (cache materialized at <pinned-sha>)
  cursor    : .cursor/rules/*.mdc generated
```

This:
- Clones `claude-tdd-pro` at the pinned commit into `.harness/plugin-cache/` (gitignored).
- Resolves `.claude/skills/tdd-pro-*` symlinks into the materialized cache.
- Regenerates `.cursor/rules/*.mdc` from harness sources-of-truth.

### 3. Verify your setup

```bash
./scripts/sync-plugin.sh --check        # exits 0; "pin matches HEAD" or "in sync"
./scripts/smoke-e2e.sh                  # exits 0; produces 4 artifacts under .harness/
./scripts/audit-doc-drift.sh            # exits 0; F-1..F-6 all clean
./scripts/export-cursor-rules.sh --check  # exits 0; .cursor/rules/ matches generator
./scripts/audit-manifest.sh             # exits 0; manifest schema valid
```

If all five exit 0, the harness is operationally ready.

### 4. Open in your IDE

```bash
cursor .          # Cursor — auto-loads AGENTS.md + .cursor/rules/agent-context.mdc
# OR
claude            # Claude Code CLI — auto-loads CLAUDE.md + runs session-start hook
# OR
grok-build        # Grok Build CLI — picks up AGENTS.md + extensions out of the box
```

### 5. Smoke the operator journey

The harness ships a deliberate Red test at `examples/string-utils/` — `slugify('  hello world  ')` returns `'-hello-world-'` instead of `'hello-world'` because there's no `.trim()` before whitespace collapse. Use it to validate end-to-end.

In your IDE's chat:

```
/research add trim to slugify
/decompose
/dispatch TICKET-DEMO
/inner-loop TICKET-DEMO
/audit
```

Expected outcome: `.harness/handoffs/TICKET-DEMO.{req,res}.json` + `.harness/trails/TICKET-DEMO.md` + `.harness/audit/TICKET-DEMO.manifest.json` produced; all four quality-gate sub-gates pass; pre-commit audit exits 0. Commit with `git commit` and you have your first auditable AI-assisted CL.

## How to use it (daily operator workflow)

Once setup is complete, daily usage in your IDE's chat:

```
/sync                       ← refresh plugin cache (also runs automatically on session open)
/research <topic>           ← outer-loop research per .grok/templates/research.md
/decompose                  ← split into atomic, file-scoped tickets
/dispatch TICKET-NNN        ← write .harness/handoffs/TICKET-NNN.req.json (contract-valid)
/inner-loop TICKET-NNN      ← agent runs R-G-R inside the ticket's file_scope
/smoke                      ← end-to-end pipeline test (toy module)
/audit                      ← pre-commit drift audit (REQUIRED before commit)
```

For parallel-ticket work, invoke the `orchestrating-swarms` skill after `/decompose` produces ≥ 2 non-overlapping tickets — the lead agent fans out workers across git worktrees, one ticket per worker.

For the alternative inner-loop driver (when you want a guaranteed-Claude model regardless of Cursor's chat-model selection), open Cursor's terminal pane and run `claude -p "<inner-loop prompt referencing .harness/handoffs/TICKET-NNN.req.json>"`. Same wire format; documented in `docs/cursor-integration.md §5`.

## Repo map (one-screen orientation)

```
AGENTS.md                  Cross-tool agent-binding surface (Cursor/Codex/Amp/Jules/Grok Build)
CLAUDE.md                  Claude Code prime directive + authority hierarchy
TICKETS.md                 Ticket ledger (one ticket per CL; all rows marked DONE)
AUTOMATION_INTEL.md        Append-only enterprise-pitch + adoption-signal log
docs/
  ai-engineering-corpus.md             TIER-0 supreme operating directive
  founder-directives.md                TIER-1 D-1..D-13 + §1 Sources 1-9 (immutable provenance)
  architecture-principles.md           R-1..R-20 architectural rulebook
  grok-orchestration-principles.md     G-1..G-21 Grok-as-outer-loop rulebook
  claude-tdd-pro-principles.md         C-1..C-24 inner-loop discipline (composes on upstream)
  handoff-contract.md                  Wire format (request + response schemas)
  quality-gate.md                      4 sub-gates (all REQUIRED post-ADR-0026)
  cursor-integration.md                Operator playbook for Cursor IDE
  provenance-bridging-design.md        Per-ticket manifest design
  researcher-discipline.md             WebFetch→WebSearch fallback for §1 source verification
  self-healing-design.md               Long-loop monitor design (impl deferred per ADR-0011)
  demo-storyboard.md                   Boston-enterprise demo shot list
  plugin-sync.md                       Plugin pin management runbook
  architecture.md                      Harness role-split overview
  claude-tdd-pro.lock.yaml             Pinned plugin commit + contract-surface sha256s
  adr/                                 41 numbered ADRs (0001-0041; Nygard append-only with SUPERSEDES chains)
  plugin-surface-consumption.md        Registry of every plugin top-level surface (CONSUMED / DECLARED-NOT-CONSUMED)
  deviations.md                        Append-only operator-justified standards-rule exceptions
  security-review.md                   TIER-2 threat model + S-1..S-6 scan policy
  dora-metrics.md                      TIER-2 operationalization of C-24 (Four Keys from manifest corpus)
  claude-code-upgrade-strategy.md      TIER-2 host-CLI version-range discipline (symmetric with plugin pin)
  rulebook-coverage-audit.md           Per-rule operational-citation audit report
.claude/
  settings.json                        Hooks config (SessionStart + PostToolUse)
  hooks/session-start.sh               Auto-run sync-plugin.sh --ensure
  hooks/post-tool-use-review-gate.sh   File-fence violation detector
  skills/orchestrating-swarms/         Worker-fanout coordinator (harness-native)
  skills/tdd-pro-*                     Symlinks into the pinned plugin cache
  README.md                            Skill consumption wiring notes
.cursor/
  rules/agent-context.mdc              Always-loaded session-start ritual (generator output)
  rules/harness-overview.mdc           Two-tier loop summary
  rules/quality-gate.mdc               Sub-gate enforcement at diff review
  rules/d-rules.mdc                    D-1..D-13 catalog
  commands/*.md                        7 slash commands (sync/smoke/audit/research/decompose/dispatch/inner-loop)
.grok/
  templates/research.md                Outer-loop research template
  templates/decomposition.md           Outer-loop decomposition template
  templates/dispatch.md                Outer-loop dispatch (request-emit) template
scripts/
  sync-plugin.sh                       Plugin cache + pin management (--check / --ensure / --update)
  smoke-e2e.sh                         4-artifact end-to-end smoke (stub mode)
  audit-doc-drift.sh                   F-1..F-6 pre-commit audit
  emit-manifest.sh                     Per-ticket provenance manifest (+ --regenerate audit mode)
  audit-manifest.sh                    Manifest schema validator
  export-cursor-rules.sh               Regenerate .cursor/rules/ from sources
examples/
  string-utils/                        Toy demo target with a deliberate Red baseline
.harness/
  plugin-cache/    (gitignored)        Materialized claude-tdd-pro at the pinned commit
  handoffs/        (gitignored)        Per-ticket .req.json / .res.json runtime artifacts
  trails/          (gitignored)        Per-ticket R-G-R decision trails
  audit/           (gitignored)        Per-ticket provenance manifests
```

## Status (2026-06-07)

All numbered tickets DONE through **TICKET-036**. **41 ADRs** landed (`docs/adr/0001-...md` through `0041-...md`; Nygard append-only with explicit SUPERSEDES chains). Plugin pin synced at `bba77df`; cross-repo paired with `claude-tdd-pro` ADR-0006. Full audit chain (10 audits + smoke-e2e + 18/18 substrate test suites) exits 0 at every commit.

- **Substrate tests:** 18/18 suites passing (~194 assertions). One test per executable substrate script + every Claude Code hook + the swarm coordinator's collection contract.
- **Audit chain (all exit 0):** `audit-doc-drift` (F-1..F-6 patterns), `audit-cross-references` (approval-baseline), `audit-hook-security` (S-1..S-6 CWE-mapped patterns), `audit-manifest` (sha256 + schema), `audit-plugin-surface` (55 plugin surfaces declared), `audit-standards-conformance` (rubric runner against the diff), `audit-metrics` (DORA Four Keys), `audit-claude-code-compat` (host-CLI semver range), `sync-plugin --check`, `smoke-e2e`.
- **Plugin surface:** 55 top-level surfaces declared (11 CONSUMED + 44 DECLARED-NOT-CONSUMED + 0 UNKNOWN).
- **Standards loaded:** 28 rules at session start from 9 namespaces — `google`, `owasp`, `slsa`, `react`, `node`, `typescript`, `w3c` (WCAG 2.2), `web-vitals`, `_community`.
- **PR-quality corpus:** 10 elite engineering-org sources (see "Engineering standards enforced" section below).
- **Claude Code:** declared range `>=2.0.0,<3.0.0`; current tested version `2.1.x`.

What's explicitly deferred (with documented rationale in ADR Out-of-scope sections):

- **TICKET-008.a..e** — self-healing implementation (ADR-0011 design shipped; implementation triggered by operational need).
- **MCP server / devcontainer / Cursor extension** — per D-8 / D-13; permanent deferrals unless evidence demands.
- **Cryptographic manifest signing** — `signature: null` at v1 per ADR-0018 §3.
- **Live-Claude smoke driver mode** — `smoke-e2e.sh` stub mode is the default per ADR-0008.
- **Two-week falsification window** for the static-context wire (ADR-0040 §Out-of-scope) — active since `bba77df` pin bump landed.

## Engineering standards enforced

The plugin maintains a versioned standards inventory (refreshed daily on the publisher side) that aggregates into a single rule registry at `.harness/rules/active.json` on every session start. The PostToolUse hook runs `rubric/runner.sh --diff --severity P0` after every Edit/Write on app-code files; **P0 violations block the write at keystroke-time**, not at commit-time.

Sources currently enforced (28 rules across 9 namespaces, from plugin `bba77df`):

| Namespace | Examples |
|---|---|
| `google` | TypeScript style guide, JavaScript style guide, Python style guide, eng-practices, testing-blog |
| `owasp` | ASVS (boundary schema validation, secret hygiene), Top 10 |
| `slsa` | Build provenance attestation level 2+ for dependencies |
| `w3c` | WCAG 2.2 (alt-text, focus indicators, ARIA usage) |
| `web-vitals` | LCP / INP bundle-size budgets, image + font optimization |
| `react` | RSC boundary integrity, exhaustive-deps, no-effect-for-derived-state, Suspense around async |
| `node` | Schema validation at boundary, structured logging (pino/winston), fetch timeout + retry, supply-chain provenance |
| `typescript` | strict tsconfig flags, discriminated-union exhaustiveness, no-any-without-justification, branded types at library boundaries |
| `_community` | Operator-extensible namespace |

**PR-quality bar** — the plugin's `pr-corpus/` extracts review patterns from public PRs at named engineering orgs and converts them into rubric rules. DEFERRED findings (rules that require agent review, not pure detection) are surfaced by the PostToolUse hook as `[peer-review]` prompts that the agent must address in the response trail before a ticket can close:

| Source | Class | Tier |
|---|---|---|
| JPMorgan Chase (mosaic) | financial-industry | 1 |
| Stripe (node) | financial-industry | 1 |
| Capital One (cloud-custodian) | financial-industry | 1 |
| FINOS (perspective) | financial-industry-consortium | 1 |
| Kubernetes (core) | gold-standard-process | 1 |
| CFPB (consumerfinance.gov) | federal-financial-regulator | 1 |
| 18F (identity-idp) | fedramp-high | 1 |
| VA (vets-website) | federal-digital-services | 1 |
| GSA (site-scanning) | federal-infrastructure | 1 |
| Bloomberg (memray) | financial-industry | 2 |

**Freshness model.** Plugin auto-refreshes the rule corpus and PR pattern set daily (`standards/auto-refresh-daily.sh` + `pr-corpus/auto-refresh-daily.sh`). The harness consumes via R-2 versioned consumption — pinned to a specific plugin commit. Effective freshness window = the operator's pin-bump cadence (small, ADR-gated CL; demonstrated repeatable in TICKET-036).

## Live evidence

What a fresh `claude` session prints when this harness opens (real output captured at branch HEAD):

```
[plugin-sync] https://github.com/drumfiend21/claude-tdd-pro
  pinned    : bba77df  (2026-06-07T00:43:02+00:00)
  upstream  : <upstream HEAD>
  contract  : <0 files drifted, or N files drifted with named list>
  status    : OK
[plugin-ensure] https://github.com/drumfiend21/claude-tdd-pro @ bba77df
  status    : OK (cache materialized at bba77df)
  cursor    : .cursor/rules/*.mdc generated
  context   : PROJECT_CONTEXT_FOR_PLANNER.md injected at .harness/context/PROJECT_CONTEXT_FOR_PLANNER.md
[claude-code-compat] OK — 2.1.x is inside supported_range (2.0.0 <= version < 3.0.0)
[standards-sync] wrote .harness/rules/active.json
  rules:      28
  namespaces: google,node,owasp,react,slsa,typescript,w3c,web-vitals,_community
  source:     .harness/plugin-cache/claude-tdd-pro/generated-code-quality-standards/
[plugin-surface] scanning .harness/plugin-cache/claude-tdd-pro top-level entries...

[plugin-surface] summary:
  total entries:           55
  CONSUMED:                11
  DECLARED-NOT-CONSUMED:   44
  UNKNOWN:                 0
[plugin-surface] OK — every plugin surface is declared.
```

Per-ticket artifacts produced (gitignored runtime; the harness commits only the substrate, not the per-ticket trails):

```
.harness/
├── handoffs/TICKET-NNN.req.json     ← contract-valid request (Grok → Claude)
├── handoffs/TICKET-NNN.res.json     ← contract-valid response (Claude → Grok)
├── trails/TICKET-NNN.md             ← R-G-R decision trail
├── audit/TICKET-NNN.manifest.json   ← sha256 + schema; --regenerate verifies tamper-free
└── audit/TICKET-NNN.aibom.json      ← AI Bill of Materials (compliance artifact)
```

## Authority

This file is operator orientation. The canonical sources of truth are the documents under `docs/` enumerated above. When this README conflicts with any TIER-0/1/2 source, the TIER-0/1/2 source wins (per `CLAUDE.md` and `docs/founder-directives.md §5` conflict-resolution).

History: introduced as `README.md` in TICKET-001; refreshed in TICKET-020 to reflect TICKETS 011-019; refreshed again in this branch's optimization + cleanup pass to reflect TICKETS 020-036 (standards pipeline wire, peer-review surface, formatters + AIBOM, static-context injection per ADR-0040, pin bump per ADR-0041, security review per ADR-0034, DORA metrics per ADR-0035, Claude Code upgrade discipline per ADR-0036). Full milestone trail in `CHANGELOG.md`.
