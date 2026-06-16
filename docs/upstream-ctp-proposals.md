# Upstream proposals for claude-tdd-pro (CTP)

Per the prime directive (`CLAUDE.md`), this harness **consumes** CTP by pinned reference
and **never edits it in place**. When harness work or testing surfaces something that
should change in CTP, it is filed here as a **v1.11 amendment proposal** and routed to the
`claude-tdd-pro` repo separately — it is NOT patched from this repo.

Each entry: the finding, the evidence, and the proposed upstream fix. Status is tracked
until the corresponding CTP change lands and a pin bump (ADR-gated) adopts it.

---

## P-1 — `install.sh` bash 3.2 unbound-variable crash on a clean install (`conflicts[@]`)

- **Status:** ✅ ADOPTED — fixed in CTP CL-476 (§28.16); adopted at GCTP pin `6d2fe13` (ADR-0054). The installer now guards `${#conflicts[@]} -gt 0` before expanding the array.
- **Found:** 2026-06-15, fresh-machine install test of CTP's `install.sh` (CTP v0.4.0+).
- **Symptom:** first run in a clean directory prints
  `ctp-install.sh: line 233: conflicts[@]: unbound variable`.
- **Cause:** `printf '%s\n' "${conflicts[@]}"` under `set -u` when the `conflicts` array is
  empty (zero conflicts) — the classic bash 3.2 empty-array gotcha. Non-fatal here (script
  uses `set -uo pipefail`, not `-e`), so install proceeds, but it fires on exactly the
  fresh-empty-folder case, on macOS's default bash 3.2.
- **Proposed fix:** the standard guard — `"${conflicts[@]+"${conflicts[@]}"}"` (or seed the
  array / test length before expansion). Note: CTP ships a `tdd-pro-bash32-portability`
  skill that documents this exact gotcha; the installer should conform to it.

## P-2 — Ruby preflight is a hard wall on common targets (`exit 3`, nothing installed)

- **Status:** ℹ️ NOT-A-DEFECT (by design) — CTP review confirmed `preflight_check` intentionally hard-stops (`exit 3`) on missing/old ruby. The harness keeps the loud ruby warning in `docs/first-time-guide.md` (Path B) so operators on no-ruby cloud / stock-macOS targets know before they run the one-liner. No CTP change.
- **Found:** 2026-06-15, same test + a no-ruby simulation.
- **Symptom:** missing or `< 3.0` ruby → preflight `exit 3` before anything installs.
  Two real-world bites: (a) **Claude Code's web/cloud sandbox has no ruby** → dead stop;
  (b) **stock macOS ships ruby 2.6.10** (`/usr/bin/ruby`) → fails unless a newer ruby
  (e.g. Homebrew's) is ahead on PATH.
- **Proposed fix:** at minimum, make the ruby dependency loud *before* the one-liner is run
  (README/QUICKSTART), and consider a ruby-optional path that installs the non-ruby features
  and clearly reports which capabilities are gated on ruby — rather than an all-or-nothing
  `exit 3`.

## P-3 — `architect` is not a Claude Code slash command (no `commands/architect.md`)

- **Status:** ✅ ADOPTED — fixed in CTP CL-476 (§28.16); adopted at GCTP pin `6d2fe13` (ADR-0054). CTP added `commands/architect.md` (loads the `architect` skill, mirroring `onboard.md`), so `/architect` is now a real slash command. `docs/first-time-guide.md` restored to list it (TICKET-059).
- **Found:** 2026-06-15, cache inspection at pin `3432b52`.
- **Symptom:** `architect` ships as `agents/architect.md`, `skills/architect/SKILL.md`, and
  `commands/architect.sh`, but there is **no `commands/architect.md`** — so `/architect`
  never registers as a slash command. (The verified `.md` slash commands are `/analyze`,
  `/feature`, `/onboard`, `/doctor`, `/spec`, `/plan-first`, `/pr`, `/remediate`, …; `/help`
  is likewise script-only.)
- **Proposed fix:** if `/architect` is meant to be user-invokable, add `commands/architect.md`
  (delegating to the architect skill/agent). Otherwise document that "architect" is a skill
  triggered by describing an architecture need, not a slash command.
- **Harness-side action taken:** `docs/first-time-guide.md` corrected to stop telling users
  to type `/architect` (TICKET-058).

## P-4 — Standalone installer is Cursor-targeted; doesn't register with Claude Code

- **Status:** ℹ️ CLARIFIED (not a CTP defect) — CTP review notes its `commands/*.md` are Claude-Code-format slash commands; the Cursor-orientation GCTP's test saw is downstream installer packaging, not a missing command surface. The harness docs keep the empirically-verified note that the *standalone installer* (Path B) is Cursor-oriented. No CTP change required; revisit only if a `--with-claude-code` registration path is desired.
- **Found:** 2026-06-15, fresh-machine install test (Path B).
- **Symptom:** CTP's `install.sh` writes `.cursorrules` + a hooks `.claude/settings.json`,
  installs commands under `~/.claude-tdd-pro/commands/`, and its success line says "open in
  Cursor." It does **not** create a project `.claude/commands/` or otherwise register CTP as
  a Claude Code plugin, so CTP's slash commands do not surface in a plain Claude Code chat —
  only in Cursor.
- **Proposed fix:** either add a Claude-Code registration path (project `.claude/commands/`
  or plugin-marketplace entry) so `--with-claude-code` surfaces the commands there, or scope
  the docs to state the installer is Cursor-oriented.
- **Harness-side action taken:** `docs/first-time-guide.md` now states slash commands are a
  Cursor surface and that Claude Code uses the skills + hooks (TICKET-058).

---

## Routing

These are tracked here for the harness record. The actual fixes land in `claude-tdd-pro`
as v1.11 amendments; once they ship, a pin bump (ADR per `docs/architecture-principles.md`
§15) adopts them and the relevant `Status` above flips to ADOPTED with the pin SHA.
