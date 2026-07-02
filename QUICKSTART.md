# QUICKSTART — grok-claude-tdd-pro

**Read this first.** This is the operator entry point. The rest of the repo's documentation is reference material; this file is what you do.

## What this is (one paragraph)

`grok-claude-tdd-pro` is a harness that provides **rails for AI-assisted software development**. The AI (Cursor's chat agent / Claude Code / Grok Build CLI / headless `claude -p`) does the actual writing. The harness provides workflow discipline (Red-Green-Refactor per ticket), a JSON wire contract between outer-loop planning and inner-loop execution, drift-detectable provenance manifests, file-fence enforcement, and a 6-pattern pre-commit drift audit. You — the operator — type slash commands, approve plans, review diffs, and commit. The AI writes the code inside the rails.

**This is not autopilot.** It is "AI-assisted with discipline you can show an auditor." The value compounds: Day 1 friction is comparable to a normal Cursor session; Week 1+ shows measurable audit-trail completeness + R-G-R discipline.

> 📖 **Want to see it before you set it up?** [`docs/end-to-end-demo/`](docs/end-to-end-demo/README.md) walks one complete flow — a non-technical user's plain-English request becoming a world-class architectural design — from requirements interview to final handoff.
>
> 🟢 **Brand new / non-technical?** [`docs/first-time-guide.md`](docs/first-time-guide.md) covers both install paths (the full harness via `./install.sh`, and the underlying **claude-tdd-pro** plugin standalone via its `curl … | bash` installer) and the first commands to type.

**The specific problem this solves that a simpler approach cannot.** A `CONTRIBUTING.md` + a few scripts in your repo can document AI-assisted-development conventions, but they cannot enforce TDD discipline *structurally* across **multiple AI agents** (Cursor's chat / Claude Code / Grok Build / headless `claude -p`), **multiple sessions** (provenance trail survives session boundaries), and **multiple IDEs** (same `AGENTS.md` + slash commands + skills compose everywhere). The harness's value is the cross-tool / cross-session enforcement layer, with a drift-detectable audit trail that an auditor can verify without trusting any individual agent's self-report. If you need only single-IDE, single-session, single-author discipline, a `CONTRIBUTING.md` and three scripts probably suffice; the harness is the layer above that.

## §0 Fastest path — your first green ticket in <2 minutes (per Musk-letter §5)

If you just want to see the harness set up and prove itself end-to-end without typing a single slash command, run the one-line installer:

```bash
git clone https://github.com/drumfiend21/grok-claude-tdd-pro.git && cd grok-claude-tdd-pro
./install.sh                            # sets up + self-checks; ~20–30s (mostly a one-time download)
```

`./install.sh` materializes the pinned plugin, **wires the Grok outer loop**, and runs the end-to-end self-check for you, printing plain-language ✓/✗ and a "what now" pointer. The Grok step (TICKET-109 / ADR-0081) is zero-friction: it auto-installs the Grok Build CLI from `x.ai/cli` if missing, and asks **once** for your `XAI_API_KEY` (stored at `~/.config/gctp/xai_key`, chmod 600, never committed — you'll never be asked again on this machine, even on a fresh clone). With both present, `/research` → `/decompose` → `/dispatch` delegate to real `grok -p` runs via `scripts/grok-run.sh`, with a per-run audit trail in `.harness/runs/` (`"stub": false`). Without them the harness still works — those phases fall back to the documented stub/inline path. Opt out with `./install.sh --no-grok`; check readiness any time with `scripts/grok-run.sh --preflight`. (Prefer the steps by hand? They're `./scripts/sync-plugin.sh --ensure` then `./scripts/smoke-e2e.sh`.)

Output you'll see:

```
[smoke-e2e] smoke OK — outer loop → handoff → inner loop → green tests → response
[smoke-e2e]   request : .harness/handoffs/TICKET-042.req.json
[smoke-e2e]   response: .harness/handoffs/TICKET-042.res.json
[smoke-e2e]   trail   : .harness/trails/TICKET-042.md
[smoke-e2e]   manifest: .harness/audit/TICKET-042.manifest.json
```

That's your first green ticket. Contract-valid request + response + R-G-R decision trail + drift-detectable manifest. **Total wall-clock: well under 2 minutes from cold clone.** Open the four files; you've seen everything the harness produces per ticket.

Once you understand what the smoke produced, the rest of this doc walks you through running the full operator workflow in your IDE — same artifacts, your real feature.

## §1 Prerequisites (verify in 60 seconds)

You need:

- `git` (any modern version)
- `bash 3.2+` (macOS default; harness scripts target bash 3.2 + BSD coreutils)
- `node` (any LTS version; used by `scripts/audit-manifest.sh` + `scripts/smoke-e2e.sh`)
- `sha256sum` (Linux) OR `shasum` (macOS) — either; the scripts fall back
- `curl` (used by `scripts/sync-plugin.sh`)

You will use at least one of:

- **Cursor IDE** — recommended primary editor; auto-loads `AGENTS.md` + `.cursor/rules/*.mdc`; exposes 7 slash commands
- **Claude Code** (CLI or web/cloud) — auto-runs SessionStart + PostToolUse hooks; reads `CLAUDE.md`
- **Grok Build CLI** (`x.ai/cli`) — picks up `AGENTS.md` + plugins + hooks + skills + MCP servers out of the box per `docs/founder-directives.md §1 Source 9`

## §2 Bootstrap (3 minutes)

```bash
# Clone (if not already)
git clone https://github.com/drumfiend21/grok-claude-tdd-pro.git
cd grok-claude-tdd-pro

# One command: materialize the pinned plugin + run the end-to-end self-check
./install.sh
```

If you see `✅ Done`, the harness is operationally ready. The installer works on any recent Node version (the self-check pins a stable test-output format, so Node 24+ is fine). If something is wrong it prints a plain-language ✗ telling you exactly what to fix.

Prefer to run each check yourself? The longhand is:

```bash
./scripts/sync-plugin.sh --ensure        # materialize the pinned plugin cache
./scripts/sync-plugin.sh --check         # drift report (leaves cache at the pin)
./scripts/smoke-e2e.sh                   # end-to-end 4-artifact pipeline
./scripts/audit-doc-drift.sh
./scripts/export-cursor-rules.sh --check
./scripts/audit-manifest.sh
```

## §3 Pick your usage mode (5 minutes — answer for yourself)

| Mode | Pick when | Set up by |
|---|---|---|
| **A. Inside this repo** | You want to build features for the harness itself OR add a small project as a subdirectory under `examples/` or a new top-level dir | Clone, work inline, add TICKETS.md rows for your feature, run the workflow below |
| **B. Harness-as-template** | You want a fresh project repo with the harness's discipline applied | Clone, strip harness-development artifacts (TICKETS 001-027 are this repo's own history; `AUTOMATION_INTEL.md` is about THIS harness), keep `AGENTS.md` + `.claude/` + `.cursor/` + `.grok/` + `scripts/` + the TIER-2 rulebooks under `docs/`, reset TICKETS.md to your first ticket |
| **C. Pattern-copy into existing repo** | You already have a project codebase and want the discipline retroactively | Copy `AGENTS.md` + `.claude/hooks/` + `.claude/settings.json` + `.cursor/` + `.grok/templates/` + `scripts/` into your existing repo, then pin `claude-tdd-pro` via `docs/claude-tdd-pro.lock.yaml` |

If you don't know which: **Start with A** to learn the workflow with zero new setup, then decide.

## §4 Your first real cycle (15 minutes — actually do this)

Open the repo in your IDE:

```bash
cursor .          # OR: claude (Claude Code CLI) / grok-build (Grok Build CLI)
```

Pick a deliberately small first feature so you learn the rails before pushing scope. **Suggestion:** add `kebabCase()` to `examples/string-utils/` (sibling of the existing `slugify`).

In your IDE's chat:

```
/research add kebabCase function to examples/string-utils that converts "Hello World" to "hello-world"
```

The agent reads `.grok/templates/research.md`, produces structured research output. **Review it.**

```
/decompose
```

Produces one atomic ticket (e.g., TICKET-DEMO) with `file_scope: examples/string-utils/src/string-utils.mjs` + acceptance criteria.

```
/dispatch TICKET-DEMO
```

Writes `.harness/handoffs/TICKET-DEMO.req.json`. **Open the file — it's the contract.** This JSON is what the inner loop reads.

```
/inner-loop TICKET-DEMO
```

The agent reads `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (the per-CL Red-Green-Refactor skill from the pinned `claude-tdd-pro` plugin) and:

1. **Red** — writes a failing test for `kebabCase`. Runs `node --test`; confirms failure.
2. **Green** — implements the minimum code to pass. Runs tests; confirms green.
3. **Refactor** — cleans up if useful, or documents skip rationale.
4. Writes `.harness/handoffs/TICKET-DEMO.res.json` per `docs/handoff-contract.md`.
5. Writes `.harness/trails/TICKET-DEMO.md` (the R-G-R decision narrative).
6. Auto-emits `.harness/audit/TICKET-DEMO.manifest.json` (index + sha256 per source).

**Review the diff** in Cursor's git pane.

```
/audit
```

Runs `scripts/audit-doc-drift.sh` (F-1..F-6 + manifest validator). Must exit 0 before commit.

Commit:

```bash
git add .
git commit -m "TICKET-DEMO: add kebabCase to string-utils"
```

That's one full cycle. You now have a contract-valid request, response, decision trail, and drift-detectable manifest (sha-chain per source; `--regenerate` re-hashes and exit-1s on any change post-emission). An auditor can verify exactly what the AI did.

## §5 Daily operator workflow (the 7 slash commands)

Once you're past your first cycle, daily usage in your IDE's chat is:

| Command | Drives | Output |
|---|---|---|
| `/sync` | `scripts/sync-plugin.sh --ensure` | Refresh plugin cache + regenerate `.cursor/rules/` |
| `/research <topic>` | `scripts/grok-run.sh research` → `.grok/templates/research.md` (live Grok when wired; inline fallback) | Structured research_refs |
| `/decompose` | `scripts/grok-run.sh decomposition` → `.grok/templates/decomposition.md` (live Grok when wired; inline fallback) | Atomic, file-scoped tickets |
| `/dispatch TICKET-NNN` | `scripts/grok-run.sh dispatch` → `.grok/templates/dispatch.md` (live Grok when wired; inline fallback) | Contract-valid `.req.json` |
| `/inner-loop TICKET-NNN` | `.claude/skills/tdd-pro-cl-workflow/SKILL.md` | `.res.json` + trail + manifest |
| `/smoke` | `scripts/smoke-e2e.sh` | End-to-end pipeline test (stub mode) |
| `/audit` | `scripts/audit-doc-drift.sh` | Pre-commit drift sweep — REQUIRED before commit |

For parallel work (multiple non-overlapping tickets at once), invoke the `orchestrating-swarms` skill after `/decompose` produces ≥ 2 non-overlapping tickets. The lead agent spawns N workers on isolated git worktrees per G-rule §8; cap 8 workers per supervisor per G-9.

## §6 Common gotchas (read these before they bite you)

1. **PostToolUse hook only fires in Claude Code, not Cursor.** Inside Cursor the file-fence is enforced via `.cursor/rules/agent-context.mdc` (always-loaded context) + pre-commit F-5 audit. Both catch the same violations; Claude Code catches them earlier (per tool call). This asymmetry is documented in `docs/cursor-integration.md §7`.

2. **The smoke script's trap reverts `examples/string-utils/` to its Red baseline on exit** (per ADR-0008). If you want to keep your work, run `/inner-loop` directly via Cursor — do NOT run `./scripts/smoke-e2e.sh` against the file you're actually editing.

3. **`/inner-loop` requires a `.req.json` to exist.** Always run `/dispatch TICKET-NNN` first, then `/inner-loop TICKET-NNN`. If the request file is missing, the inner-loop driver exits 2 with an explicit error.

4. **TICKETS.md is append-only by convention.** Add a new row for your ticket; don't edit existing rows. Mark prior tickets DONE in the same CL when you ship them; that's the established convention.

5. **`docs/founder-directives.md §1` is immutable per D-6.** Don't ever edit Sources 1-9. New sources land via the ADR process documented in `docs/researcher-discipline.md` (the WebFetch → WebSearch → cross-attribute fallback chain when primary URLs are blocked at the network policy).

6. **The `.harness/` runtime artifacts are gitignored** — they're per-session evidence, not durable repo state. `.harness/handoffs/`, `.harness/trails/`, `.harness/audit/`, `.harness/plugin-cache/` all live in your local checkout, not in version control.

7. **The pinned plugin is a specific commit, not a branch HEAD.** When upstream `claude-tdd-pro` advances, the session-start hook reports a WARN. Bumping the pin requires an ADR per `docs/architecture-principles.md §15`; see ADR-0025 for the diff-classification pattern.

## §7 Where to go from here

After your first successful cycle:

- **Operator reference:** `docs/cursor-integration.md` — full Cursor playbook with surfaces table, driver compatibility, failure modes
- **Wire format:** `docs/handoff-contract.md` — `.req.json` + `.res.json` schemas
- **Quality gate:** `docs/quality-gate.md` — 4 sub-gates, severities, override policy
- **Architecture rules:** `docs/architecture-principles.md` (R-1..R-20), `docs/grok-orchestration-principles.md` (G-1..G-21), `docs/claude-tdd-pro-principles.md` (C-1..C-24)
- **Authority hierarchy:** TIER 0 corpus → TIER 1 prime directive + founder-directives → TIER 2 rulebooks. Full enumeration in `AGENTS.md §5` and `CLAUDE.md`
- **Decision history:** `docs/adr/0001-...md` through the latest numbered ADR — every architectural decision recorded
- **Researcher discipline** (how to verify primary sources when WebFetch is blocked): `docs/researcher-discipline.md`
- **Provenance bridging design:** `docs/provenance-bridging-design.md`

If you want to extend the harness itself (vs. use it):
- Read `CLAUDE.md` for the prime directive (plugin-dependency model — this repo consumes `claude-tdd-pro` as a pinned version; never edit upstream).
- Read `docs/founder-directives.md §3` for the 13 D-rules.
- Run `/research → /decompose → /dispatch → /inner-loop → /audit` against your proposed change — yes, the harness eats its own dog food (the 33 tickets in `TICKETS.md` are themselves the harness's own development history under its own discipline).

## §8 The honest minimum to start TODAY

Three actions:

1. **Clone + `./scripts/sync-plugin.sh --ensure` + run the 5 verification commands** (§2). 3 minutes. Proves your environment works.
2. **Open in Cursor, run `/research add kebabCase to string-utils` → all the way through `/audit`** (§4). 15 minutes. Proves the workflow drives real code.
3. **Pick your real first feature for your real software, run the same cycle.** Your actual usage starts here. Friction profile compounds: subsequent tickets feel lower-friction than the first; audit trail builds; discipline becomes muscle memory.

The harness was created so you don't have to remember all the discipline yourself — the SKILL.md + rules + hooks + audits hold the rules. You focus on what to build.
