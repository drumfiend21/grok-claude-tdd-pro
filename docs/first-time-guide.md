# 🟢 First time? Start here

This harness — **grok-claude-tdd-pro (GCTP)** — is built on top of **claude-tdd-pro
(CTP)**, the engineering plugin that does the actual world-class design + code work.
GCTP adds the outer-loop planning, the wire contract, and the audit trail around it.

You can get going two ways. Pick the one that matches you.

---

## Path A — Use the full harness (recommended for this repo)

You run **one command** and the pinned CTP plugin is set up for you automatically —
you do **not** install CTP separately.

```bash
git clone https://github.com/drumfiend21/grok-claude-tdd-pro.git && cd grok-claude-tdd-pro
./install.sh
```

`./install.sh` downloads the pinned CTP plugin, wires it in, and runs an end-to-end
self-check (~20–30 seconds, mostly the one-time download). When you see `✅ Done`:

- In **Cursor** *or* **Claude Code**, drive the workflow with GCTP's slash commands
  (shipped for both: `.cursor/commands/` and `.claude/commands/`):
  ```
  /research <your idea> → /decompose → /dispatch TICKET-NNN → /inner-loop TICKET-NNN → /audit
  ```
- The 3 `tdd-pro-*` skills also auto-trigger and the hooks enforce quality as you work —
  so you can equally just **describe what you want in plain English**, or use headless `claude -p`.

Full walk-through: [`QUICKSTART.md`](../QUICKSTART.md). See a complete worked example
first: [`docs/end-to-end-demo/`](end-to-end-demo/README.md).

> **Why automatic?** GCTP consumes CTP *by reference* at a pinned commit
> (currently `6d2fe13`) so every machine gets identical behavior. The pin is bumped
> only via an ADR (most recently ADR-0054; see [`docs/plugin-sync.md`](plugin-sync.md)).
> You never hand-install CTP for this path.

---

## Path B — Use CTP on its own (the plugin, in your own project)

If you just want the engineering plugin inside your own project (no GCTP harness),
install it with **CTP's own one-line installer**:

```bash
curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash
```

> ⚠️ **Before you run it, two real constraints (verified on a fresh machine):**
> - **It needs `ruby ≥ 3.0` on your PATH, or it stops cold** (`exit 3`, nothing installed).
>   Many targets don't have it: **stock macOS ships ruby 2.6** (too old — you need
>   Homebrew's ruby on PATH), and **Claude Code's web/cloud sandbox has no ruby at all.**
> - **It is Cursor-oriented.** It writes `.cursorrules`, installs CTP's commands under
>   `~/.claude-tdd-pro/`, and finishes by telling you to *open in Cursor*. It does **not**
>   register CTP as a Claude Code plugin, so CTP's slash commands appear in **Cursor**,
>   not in a plain Claude Code chat.

It's interactive and (when ruby is present) finishes in under a minute: a preflight
(`bash ≥ 3.2`, `node ≥ 18`, `ruby ≥ 3.0`, `git`), conflict detection, then a few
plain-language choices.

**Useful forms:**

```bash
# Accept all suggested defaults (no prompts):
curl -fsSL .../scripts/install.sh | bash -s -- init --yes

# Strict ruleset + Grok harness + language-server wiring:
curl -fsSL .../scripts/install.sh | bash -s -- init --yes --profile strict --with-grok --with-lsp
```

**Installer subcommands:** `init` (set up here), `upgrade` (update in place),
`doctor` (health check), `uninstall` (clean removal).

**Profiles** (the ruleset/strictness it enforces): `standard` (recommended),
`strict`, `financial`, `regulated`, `government`, `react`, `node`, `library`.

Canonical, always-current details live in CTP's own docs:
[CTP README + QUICKSTART](https://github.com/drumfiend21/claude-tdd-pro).

---

## Once it's installed — how you actually drive it

**Where commands show up:** GCTP ships its operator commands for **both Cursor and Claude
Code** (`.cursor/commands/` + `.claude/commands/`), so `/research`, `/decompose`,
`/dispatch`, `/inner-loop`, `/sync`, `/smoke`, `/audit` work in either. **CTP's** commands
(`/architect`, `/analyze`, `/feature`, …) come from the plugin; with the **standalone**
installer (Path B) they're Cursor-oriented (see the Path B note above). The 3 `tdd-pro-*`
skills also auto-trigger in any chat — so you can equally just describe what you want in
plain English.

These slash commands are available (Cursor and Claude Code unless noted):

| Type this | From | What it does |
|---|---|---|
| **`/architect`** then describe your idea | CTP | Interviews you in plain English, turns your idea into decisions, gives **grounded options with trade-offs**, and writes the design records (ADRs) — then hands off to build. *(Added in CTP CL-476; available at pin `6d2fe13`+.)* |
| **`/analyze`** | CTP | Read-only audit of existing code → a plain-English report with cited findings + risky-file list. |
| **`/onboard`** | CTP | Tours an existing codebase and proposes conventions. |
| **`/feature` `<description>`** | CTP | Builds a feature test-first (Red → Green → Refactor). |
| **`/spec`** / **`/plan-first`** `<description>` | CTP | Writes a spec / a plan before any code. |
| **`/doctor`** | CTP | Smoke-tests the toolchain; green/yellow/red matrix. |
| **`/research` → `/decompose` → `/dispatch` → `/inner-loop` → `/audit`** | GCTP | The harness's outer→inner loop. |

> `/architect` became a real slash command in CTP CL-476 (adopted at GCTP pin
> `6d2fe13`); before that it was only a skill/agent. There is still **no `/help`**
> slash command — just ask in plain English. For a new design, `/architect` (or
> `/spec` / `/plan-first`) is the entry point.

> Every choice `/architect`, `/analyze`, and `/feature` make is **backed by a cited
> source** — OWASP, Google's style guides, SLSA, WCAG, and more — so the professional-grade
> parts you'd never know to ask for are added (and justified) for you.

---

## When dispatch is blocked by design-phase MD scoring

After PROPOSAL-003 lands in CTP (the upstream rule-content amendment introducing the YAML/JSON/MD corpora + `prose-judge.sh`), the harness's design-phase MD gate (ADR-0066 D-D) activates. If you run `/dispatch` for a ticket that touches architectural Markdown (anything under `docs/architecture/**`, `docs/adr/**`, `docs/decisions/**`, or any `.md` with frontmatter `kind: architecture | adr | decision`), the gate scores the prose against every rule in `active.json` carrying `applies_to_prose: true` **before** the request is emitted.

If the gate blocks dispatch, you have two paths:

1. **Rewrite the prose.** The gate flagged a concrete claim — e.g. an ADR proposing `0.0.0.0/0` ingress on the dev cluster against the `g-aws-no-unrestricted-ingress` rule. Edit the section so the proposed design no longer violates the rule, then re-run `/dispatch`.
2. **File a deviation.** If the rule legitimately cannot apply in this context (cross-provider, isolated subsystem, etc.), add a `## Deviation — <RULE-ID> on <TICKET-ID>` row to `<app_root>/docs/deviations.md`. Use [`docs/deviations-template.md`](deviations-template.md) as the template. The gate matches the heading and treats the rule as `deviated`-as-green; dispatch then proceeds with the deviation visible in the audit trail.

This is **never silent exclusion** — deviations are recorded, reviewable, and revisited on the re-eval condition you write into the row. Full operator workflow + worked example: [`docs/kata-runbook.md` PATH C](kata-runbook.md#path-c--fix-architectural-prose-under-enforcement-after-proposal-003-lands).

The gate is vacuous-pass today (no `applies_to_prose: true` rules exist in `active.json` until PROPOSAL-003 lands). When it activates, you'll see it.

## If you get stuck

- In **Cursor**: run **`/doctor`** (CTP). In **GCTP**: run **`./install.sh`** again — both are safe to re-run.
- Or just **ask in plain English**: "what should I do next?" works fine in any chat.

> 💡 **Want to watch a full run before you try?** Open the
> [end-to-end demonstration](end-to-end-demo/README.md) — a non-technical person's
> plain-English request becoming a complete, standards-enforced design.
