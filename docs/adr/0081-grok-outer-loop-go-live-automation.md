# ADR-0081 — Grok outer-loop go-live automation: install-time CLI + key wiring, runner key discovery, command delegation

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** operator (`drumfiend21`; 2026-07-01: *"Zero manual setup beyond supplying your XAI_API_KEY once … On any future machine (or fresh clone) you only ever need to supply the key one time during install. After that it just works."*) + Claude (local session).
- **Trigger:** ADR-0080 shipped the G-2 headless runner **stub-first** and left go-live operator-gated: install the `grok` CLI by hand, `export XAI_API_KEY` by hand, every shell, every machine. The operator directed that this friction be removed — `./install.sh` should own the one-time setup end-to-end.

## Decision

Three composing changes, no new contract surface:

1. **`install.sh` owns one-time Grok setup (new Step 2/3, warn-only).**
   - Detects the `grok` CLI; if absent, auto-installs it from the **official** xAI installer (`curl -fsSL https://x.ai/cli/install.sh | bash` — the canonical product surface per `docs/founder-directives.md §1` Source 9). `GCTP_GROK_INSTALL=skip` disables the network attempt; `--no-grok` skips the whole step.
   - Discovers the key (env `XAI_API_KEY` → repo-local `.grok/.env` → `~/.config/gctp/xai_key`). If found via env/.env but not yet persisted, persists it. If absent and the terminal is interactive, asks **once** (hidden input, Enter-to-skip), validates lightly (format warn on non-`xai-` prefix; best-effort `api.x.ai/v1/models` reachability check, warn-only), and persists to `${GCTP_KEY_FILE:-~/.config/gctp/xai_key}` — 0600 file in a 0700 dir, written under `umask 077`, never echoed.
   - Ends the step with a readiness verdict via `scripts/grok-run.sh --preflight` (no network, never the key): **LIVE** or **stub**.
   - **Every failure in this step is a warning, never fatal** — the harness is stub-first (ADR-0008/0080); a missing CLI or key degrades to stub outer-loop runs, not a broken install.
2. **`scripts/grok-run.sh` discovers the key (and gains `--preflight`).**
   - Discovery precedence: env `XAI_API_KEY` > repo-local `.grok/.env` (gitignored; **parsed** with `sed`, never sourced — a credentials file must not execute code) > `~/.config/gctp/xai_key`. The found key is exported into the env for the single `grok` child — **G-2's env-var-auth contract is preserved**: the CLI still authenticates from the env; discovery only populates it. Overridable for tests: `GROK_ENV_FILE`, `GCTP_KEY_FILE`.
   - `--preflight` reports live-readiness (CLI present? key discoverable + its source?) with **no phase, no network, and never the key**; exit 0 = LIVE-ready, 3 = stub. Consumed by `install.sh` and available to the operator directly.
   - The runner remains read-only on credentials: never prints the key, never writes it, never passes it in argv (argv is `ps`-visible).
3. **The three outer-loop commands delegate to the runner (Mode B wiring).**
   - `.claude/commands/` + `.cursor/commands/` for `/research`, `/decompose`, `/dispatch` gain a **Step 0: run `scripts/grok-run.sh <phase>`**. `"stub": false` → real Grok ran and owns the phase (G-7 — the driving agent stops doing outer-loop reasoning inline and becomes the translator/validator of Grok's structured output, per the agent-operating-compact division of labor); every downstream gate (contract fields, EO rules union, design-phase MD gate) still applies to Grok's output before anything is written. `"stub": true` → one-line notice + the pre-existing inline procedure as fallback, unchanged.
   - This makes delegation identical whether the session is driven from `grok` (Mode A), Cursor, or Claude Code — all ride the same §14 contract surface.

## Key-persistence stance (supersedes ADR-0080's phrasing, not G-2)

ADR-0080 recorded *"never written to disk"* as the runner's auth posture. G-2's actual rule text mandates **env-var auth for every Grok invocation** — it does not prohibit an operator-local credentials file. This ADR splits the concern:

- The **runner** still never writes the key (unchanged).
- **`install.sh`** persists it — only when supplied by the operator (typed at the prompt, or already in their env), which is the human approval G-13 wants for secret handling. Storage is out-of-tree by default (`~/.config/gctp/`, XDG-style, survives clones), 0600, and the repo-local `.grok/.env` alternative is gitignored (`.gitignore` entry added). A key can never enter version control through this path.

## Consequences

### Positive
- Fresh machine: `git clone … && ./install.sh`, paste the key once → the outer loop is LIVE everywhere, forever (per machine). Fresh clone on the same machine: zero prompts.
- Real Grok runs now produce the G-15 audit trail (`.harness/runs/*.jsonl`, `"stub": false`) through the commands the operator already uses.
- The stub path, exit codes, templates, and handoff schemas are all byte-compatible with ADR-0080 — nothing downstream renegotiated.

### Neutral / honest caveats
- `curl | bash` from `x.ai/cli` executes a remote script at install time. It is xAI's official installer (same trust decision as installing the CLI by hand), attempted only when `grok` is absent, skippable (`--no-grok` / `GCTP_GROK_INSTALL=skip`), and failure is a warning.
- The api.x.ai key validation is best-effort and warn-only (offline installs still succeed); a bad key surfaces on the first live run.
- `_grok_invoke`'s flags remain built against the documented CLI contract; first live run on a given CLI version verifies them (G-21, unchanged from ADR-0080).

### Negative
- A credentials file now exists on the operator's machine (0600, operator-owned). Operators who rotate keys re-run `./install.sh` or edit the file; nothing auto-rotates (G-13 keeps rotation human-gated).

## Verification (executed before commit)
- `tests/test-grok-run.sh` **28/28** (prior 18 + key-file discovery live; `.grok/.env` discovery live, parsed-not-sourced; env-precedence probe; `--preflight` 3/0 exits + LIVE banner; key never printed on any path).
- `tests/test-install.sh` **18/18** (prior 9 hermetically re-pinned [no network, no tty] + `--no-grok`; env-key persisted to `GCTP_KEY_FILE` with 600 perms and never echoed; keyless non-interactive run exits 0 with a plain-language pointer).
- `.grok/.env` gitignored; no `claude-tdd-pro` path touched (prime directive); D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- Installer: `install.sh` (Step 2/3) · Runner: `scripts/grok-run.sh` (discovery + `--preflight`) · Commands: `.claude/commands/{research,decompose,dispatch}.md`, `.cursor/commands/{research,decompose,dispatch}.md`
- Docs: `QUICKSTART.md §0/§5`, `docs/first-time-guide.md` Path A, `.grok/templates/README.md`
- G-rules: `docs/grok-orchestration-principles.md` §15 (G-2, G-7, G-13, G-15, G-21) + §14 · Prior: TICKET-108 / ADR-0080 (stub-first runner), TICKET-006 / ADR-0008 (stub-first pattern)
