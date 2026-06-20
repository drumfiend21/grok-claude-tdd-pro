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

## P-5 — Fix E: external-tree enforcement entrypoint (`rubric/enforce.sh`)

- **Status:** ✅ ADOPTED — shipped in CTP CL-477/478 (§28.17–28.18); adopted at GCTP pin `eb7b2af` (ADR-0058).
- **Found:** 2026-06-18/19, GCTP O'Reilly kata build (`softarchcert-win25`): only IaC was actually
  enforced by CTP detectors; TS code was scoped to two rules and never re-run (asserted, not enforced).
  Root cause was CTP-side: no single entrypoint dispatches a rule set against an external app tree.
- **GCTP corrections incorporated (invisible from inside CTP):** (1) dispatch by the
  `generated-code-quality-standards/` catalog, NOT `RUBRIC.yaml` — the bare ids collide (`g-ts-001` =
  `no-any` in the catalog vs `naming-style` in RUBRIC.yaml); (2) **4-state** per rule
  (`pass | fail | not_applicable | not_enforced`) + a `files_evaluated` count, so a rule that ran but
  matched no files is `not_applicable` (neutral) not a vacuous `pass`, and an un-run detector is
  `not_enforced` (red) not a pass; (3) generalize the proven `cloud-guidance-rule.sh --rule/--root`
  contract up to a dispatcher over all detectors.
- **Adopted contract:** `enforce.sh --root <app> --rule <id>… | --rules <csv> [--paths <glob>] [--json]`;
  exit `0` all-pass-or-NA / `1` any fail / `2` usage·unknown / `3` ≥1 not_enforced. This is the surface
  the GCTP-side Fix B (a forthcoming `enforce-standards.sh`) + Fix C (dynamic re-run gate) build against.

## P-6 — Fix F: prose enforcement (ADR-structural + citation detectors)

- **Status:** ✅ ADOPTED — shipped in CTP CL-480 (§28.20, option 1); adopted at GCTP pin `eb7b2af` (ADR-0058).
- **Found:** same kata: CTP enforced code + IaC but **prose** (ADRs/design docs — the bulk of an
  architecture submission) had no detectors; it could only be cited, never content-enforced.
- **Adopted:** a `documentation` namespace with `g-doc-001` (ADR structural conformance) + `g-doc-002`
  (doc-citation-presence), emitted **through `generated-code-quality-standards/`** so they sync into
  `active.json` and GCTP can scope them; `enforce.sh` maps `g-doc-*` → `*.md`. (GCTP Correction 4: doc
  detectors must flow through the catalog to reach the contract — honored.)

## P-7 — Fix G: `no-any` comment/string false positive

- **Status:** ✅ ADOPTED — shipped in CTP CL-479 (§28.19); adopted at GCTP pin `eb7b2af` (ADR-0058).
- **Found:** same kata: the reported TS "fails `no-any`" was a single finding on a *comment*
  (`// Fail-closed: any policy error…`); the grep matched `: any` inside the comment text (0 real `any`
  annotations; corroborated by GCTP's independent detector run).
- **Adopted:** the detector strips `//` line comments (line-number-preserving) before the `: any` greps;
  the `// allow-any:` affordance and real `x: any` flagging are unchanged.

---

## Routing

These are tracked here for the harness record. The actual fixes land in `claude-tdd-pro`
as amendments; once they ship, a pin bump (ADR per `docs/architecture-principles.md`
§15) adopts them and the relevant `Status` above flips to ADOPTED with the pin SHA.

The GCTP-side counterparts of the kata-feedback loop — **Fix A** (decompose-union), **Fix B**
(`enforce-standards.sh` driving `enforce.sh`), **Fix C** (dynamic re-run gate), **Fix D** (`app_root`
external-working-tree model) — are NOT upstream items; they land in this repo per
`proposals/PROPOSAL-002-app-enforcement-spine.md`.

---

## P-8 — `prose-judge.sh` tier-2 invocation contract-mismatch with `llm-judge.sh` (semantic tier non-functional)

- **Status:** 🟥 OPEN — surfaced 2026-06-20 during GCTP architecture re-validation under the post-pin-bump 118-rule surface (ADR-0067 / CTP-ADR-0007). LLM_JUDGE=1 across 33 architectural docs yielded zero verdict changes; root cause is a flag-name mismatch in the CTP substrate, not an LLM problem.
- **Found:** 2026-06-20, attempting to convert 28 `not_enforced` verdicts on the kata's architectural `.md` files into explicit semantic verdicts via `LLM_JUDGE=1 rubric/enforce-file.sh --file <doc>`.
- **Symptom:** Every `not_enforced` verdict stayed `not_enforced` regardless of `LLM_JUDGE=1` + `claude` CLI on PATH + `--no-stream -p` working in isolation. Per-file runtime was ~1s (consistent with tier-2 skip, not a model call). Final tally with LLM_JUDGE=1: **3 green / 1 red / 29 incomplete** — identical to LLM_JUDGE=0.
- **Cause:** `rubric/detectors/prose-judge.sh` tier-2 invokes the LLM judge with `--text <prose>` (line ~102):
  ```ruby
  out = `LLM_JUDGE=1 bash #{File.join(plugin,"rubric","detectors","llm-judge.sh")} --rule #{rule} --text #{prose.inspect} 2>/dev/null`
  ```
  But `rubric/detectors/llm-judge.sh` only accepts `--target <file>` + `--rule <rule-id>` + `--model <name>` + `--dry-run` + `--explain`. The `--text` flag falls through to the unknown-arg path → `exit 2`. With stderr suppressed, the prose-judge case statement's regex `/\bYES\b|\bNO\b|\bABSTAIN\b/i` matches nothing → falls through to `verdict="not_enforced"`. The semantic tier is dead-coded.
- **Evidence:** `prose-judge.sh:102` (the `--text` invocation) vs `llm-judge.sh` argument parser (`case "$1" in --target | --rule | --model | --dry-run | --explain | * (echo "llm-judge: unknown arg")`). Direct repro on a clean install of the pin `39903da`.
- **Proposed fix (CTP-side, smallest possible):** add `--text <prose>` to `llm-judge.sh`'s argument parser as an alternative to `--target <file>` — when `--text` is given, skip the file-read step and use the inline prose verbatim. The rest of the dispatch (model selection, response parsing) is reusable. Roughly 5 lines of bash. Alternative: change prose-judge.sh tier-2 to write the prose to a tempfile and call `--target <tempfile>` (preserves llm-judge.sh's existing contract; ~3 lines of Ruby).
- **Workarounds operator-side (until fix):**
  1. **Allow-affordance comments** per ADR-0066 D-F for the 1 keyword-tier false-positive (ADR-0010 `0.0.0.0/0` deny-context citations).
  2. **Deviation rows** for any rule the operator decides genuinely cannot apply to a given ticket.
  3. **Accept `not_enforced`-as-RED** per ADR-0066 D-C until tier-2 ships fixed — the gate is honest (no silent green), just over-broad.
- **Impact on GCTP work:** ADR-0066 wiring (CL-A through CL-E) and ADR-0067 (pin bump) are unaffected — the gates correctly surface `not_enforced` per the no-silent-green invariant. The operator's expectation that LLM_JUDGE=1 would clear the 28 incompletes (recorded in `docs/kata-architecture-revalidation-2026-06-20.md`) cannot be satisfied until this fix lands upstream.
