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
self-check (~20–30 seconds, mostly the one-time download). When you see `✅ Done`,
open the folder in **Cursor** or **Claude Code** and drive the workflow:

```
/research <your idea>     → /decompose → /dispatch TICKET-NNN → /inner-loop TICKET-NNN → /audit
```

Full walk-through: [`QUICKSTART.md`](../QUICKSTART.md). See a complete worked example
first: [`docs/end-to-end-demo/`](end-to-end-demo/README.md).

> **Why automatic?** GCTP consumes CTP *by reference* at a pinned commit
> (currently `4354903`) so every machine gets identical behavior. The pin is bumped
> only via an ADR (most recently ADR-0052; see [`docs/plugin-sync.md`](plugin-sync.md)).
> You never hand-install CTP for this path.

---

## Path B — Use CTP on its own (the plugin, in any Claude Code project)

If you just want the engineering plugin inside your own project (no GCTP harness),
install it with **CTP's own one-line installer** — the latest, straight from CTP:

```bash
curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash
```

It's interactive and finishes in under a minute. It runs a quick preflight
(`bash ≥ 3.2`, `node ≥ 18`, `ruby ≥ 3.0`, `git`), detects conflicts with other
plugins, and walks you through a few choices in plain language.

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

## Once CTP is installed, the commands you'll actually use

Type a **slash command** in Claude Code. The friendliest starting points:

| Type this | When you want to… | What it does |
|---|---|---|
| **`/architect`** then describe your idea | design something new | Interviews you in plain English, turns your idea into decisions, gives you **grounded options with trade-offs**, and writes the design records (ADRs) — then hands off to build. |
| **`/analyze`** | check code you already have | Read-only audit of your working tree → a plain-English report with cited findings (and a list of risky files). |
| **`/onboard`** | get oriented in an existing project | Tours the codebase and proposes conventions. |
| **`/feature` `<description>`** | build a feature | Builds it test-first (Red → Green → Refactor). |
| **`/doctor`** | make sure setup is healthy | Smoke-tests every tool and reports a green/yellow/red matrix. |
| **`/help`** | you're not sure | Explains your options. |

> Every choice `/architect` and `/analyze` make is **backed by a cited source** —
> OWASP, Google's style guides, SLSA, WCAG, and more — so the professional-grade
> parts you'd never know to ask for are added (and justified) for you.

---

## If you get stuck

- Run **`/doctor`** (CTP) or **`./install.sh`** again (GCTP) — both are safe to re-run.
- Or just **ask in plain English**: "what should I do next?" works fine.

> 💡 **Want to watch a full run before you try?** Open the
> [end-to-end demonstration](end-to-end-demo/README.md) — a non-technical person's
> plain-English request becoming a complete, standards-enforced design.
