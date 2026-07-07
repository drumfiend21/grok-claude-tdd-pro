# ADR-0090 — Plugin pin bump `43ea692` → `f39fcdc` (adopt CTP CL-549 / §30.3 — word-boundary classifier precision + submission-isolation `.gitignore` guard; closes the KATA pre-flight misfires flagged on `43ea692`)

- **Status:** Accepted
- **Date:** 2026-07-06
- **Deciders:** operator (`drumfiend21`; 2026-07-06: relayed CTP's built-close-out of the classifier-precision item GCTP flagged in the KATA pre-flight — *"`aks` matches inside `le**aks**`; `ci` matches inside `certifi**c**ation` / `a**cc**reditation`; the AI-credentialing vision phantom-activates `azure-platform` + `container-orchestration` + `ci-cd`"*) + Claude Opus 4.7 (local 1M-context session).
- **Trigger:** After ADR-0089 (`43ea692` — §30.2 precise cloud classification + IaC probe coverage + `unprobed_in_scope` transparency), GCTP ran the KATA `--classify` pre-flight against the real Certifiable, Inc. AI-credentialing vision. §30.2's precision was correct in principle but defeated in practice by **substring matching in the signal classifier** — the compact tokens `aks` / `ci` / `spa` matched inside larger business words (`leaks`, `certification`/`accreditation`, `space`) and phantom-activated cloud + orchestration + CI-CD workload types on a vision that mentions none of them. Rather than round-trip a P-13, CTP built the close-out inline as **CL-549 (§30.3)** and returned a re-pin target **`f39fcdc`** (adds the classifier fix + a `.gitignore` submission-isolation guard). This is the intake mirror of §30.2's precise-classification ambition — precise **matching**, not just precise **type-mapping**.
- **Continues:** the pin chain ADR-0072 → ADR-0079 → ADR-0085 → ADR-0086 → ADR-0087 → ADR-0088 → ADR-0089 → this ADR (`43ea692 → f39fcdc`).
- **Process:** §15-gated pin bump (upstream `architecture-v1.9.md` contract hash changes — §30.3 appended, +10 insertions / 0 deletions to the architecture doc). No consumer-side reconciliation required on GCTP: the fix is entirely inside CTP's classifier (`commands/full-surface-intake.sh` matcher line + corpus signals). The v1.1 `business-profile.json` shape is **unchanged** — only classification *behavior* is more precise. `--validate-profile` / invariant 4 audit / `/consult` skill unchanged.

## Compatibility verdict (verified `43ea692 → f39fcdc`)

| Check | Result |
|---|---|
| Span | **2 semantic CTP commits** (`b2a6a01` CL-549 §30.3 + `ba6fdc0` gitignore guard) + 1 noise (`03d962e` unrelated fitness-trend row) |
| upstream `architecture-v1.9.md` | **CHANGED** — **purely additive**: §30.3 appended (+10 insertions / 0 deletions); ADR-0047 additive-only invariant preserved |
| `CLAUDE.md` + 3 consumed `SKILL.md` (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) | **all byte-identical** — verified `git diff 43ea692..f39fcdc -- CLAUDE.md '.claude/skills/**/SKILL.md'` empty |
| Files changed | 14 files, 240 insertions, 38 deletions (aggregate). Arch: +10/0 §30.3. Classifier: `commands/full-surface-intake.sh` +11/-? word-boundary matcher line. Design: `.harness/plugin-cache/claude-tdd-pro/docs/design/v1.14-full-surface-intake.md` +28/0 §30.3. Docs: `.harness/plugin-cache/claude-tdd-pro/docs/handoff-ctp-to-gctp-p12-fixed.md` +123/-38 (packet edit folding §30.1..§30.3). Chore: `.gitignore` +17/0 submission-isolation guard. Add: 8× `evals/specs/cl549-precision-*.json` |
| Classifier semantic delta | Signal matching changes from substring (`hay.include?(sig)`) to word-boundary (`(?<![a-z0-9])<sig>s?(?![a-z0-9])`) — alphanumeric boundaries so phrases (`amazon web services`) and internal punctuation (`ci/cd`) still match; optional trailing `s` so plurals (`microservices`) still match. Can only **tighten** the classifier (fewer false-positive types), never loosen. The real Certifiable, Inc. AI-credentialing vision now yields `workload_types=[ai-governed, baseline-quality]` with no phantom `azure-platform` / `container-orchestration` / `ci-cd`. Real `AKS` / `CI/CD` tokens still fire when actually present. |
| Submission-isolation guard | `.gitignore` in the plugin now covers the consult chain's default output paths (`standards/business-profile.json`, `technical-requirements.json`, `architecture-options.json`, `explanation.md`, `session.*`, `full-surface-grounding.json`, `architect-session/`) — kata submission can never leak into the CTP plugin regardless of where the operator runs `/consult`; **convention:** GCTP passes `--out` into the operator's own submission tree so artifacts land where they belong. |
| `active.json` | expected **118 → 118 rules** (byte-identical; CL-549 adds no authored rules — refines classifier matching precision + adds a `.gitignore` chore) |

## Decision

Bump the pin `43ea692 → f39fcdc` — the semantic-close-out SHA named in CTP's `.harness/plugin-cache/claude-tdd-pro/docs/handoff-ctp-to-gctp-resume-kata.md`. This closes the KATA pre-flight misfires by construction: the classifier can no longer match compact signals inside larger business words, so a vision that speaks only about *AI credentialing / content leak protection / accreditation compliance* classifies **cleanly** to `ai-governed` + `baseline-quality` — no phantom platform / orchestration / CI-CD types. Real cloud/orchestration/CI tokens still fire when actually present. The submission-isolation guard is adopted-by-pin (no ADR-worthy consumer change).

**Explicit non-adoption:** upstream HEAD at fetch time is `84b792b` (a merge of the CTP-side handoff doc `.harness/plugin-cache/claude-tdd-pro/docs/handoff-ctp-to-gctp-resume-kata.md`). We pin to `f39fcdc` — the SHA CTP's handoff packet nominated as the semantic close-out — not `84b792b`. Rationale: `84b792b` adds only a docs handoff record (no rule / classifier / skill change), and the CTP-side convention (per ADR-0086/0089) is that the handoff packet nominates the pin target explicitly; adopting `f39fcdc` matches that convention and keeps the pin chain interpretable.

**Explicit non-adoption of noise:** `03d962e` (upstream `.harness/plugin-cache/claude-tdd-pro/docs/fitness-trend.md` +1) is CTP's own automated DORA scoreboard update — not a semantic CTP change. It rides along inside the `43ea692..f39fcdc` range but has no effect on GCTP's consumed surface.

## What §30.3 delivers (the substantive change)

1. **Word-boundary signal matching (the precision fix).** The classifier's signal-matching function inside `commands/full-surface-intake.sh` changes from a naive substring check (`echo "$hay" | grep -F "$sig"` equivalent) to a Ruby-driven word-boundary regex (`(?<![a-z0-9])<sig>s?(?![a-z0-9])`). Alphanumeric boundaries mean phrases with spaces (`amazon web services` → `aws`, `web services`) still match, and internal punctuation like slashes (`ci/cd`, `k8s`) still matches, because `/` and non-alphanumerics act as boundaries. The optional trailing `s` preserves plurals like `microservices`. Can only *tighten* the classifier — a signal that used to phantom-match through a larger word will not match anymore, but a signal that was correctly matching a boundary-clean substring still matches.
2. **Kata pre-flight cleanup (the intended effect).** The real Certifiable, Inc. AI-credentialing prose — which speaks about *AI-driven credentialing, content leak protection, and accreditation compliance* — no longer phantom-activates `azure-platform` (was: `aks` matching inside `leaks`), `container-orchestration` (was: `aks` matching inside `leaks`), or `ci-cd` (was: `ci` matching inside `certification` and `accreditation`). The classifier now yields `workload_types=[ai-governed, baseline-quality]` with an activated probe set drawn from `documentation`, `european-union`, `observability`, `owasp`, `security-governance`, `us-government` — exactly the surface the operator would expect for an AI-governed compliance workload.
3. **Standing invariant: classifier precision is measurable.** 8 new specs (`evals/specs/cl549-precision-01..08.json`) pin the specific misfires that must never regress: `aks` does not match inside `leaks`, `ci` does not match inside `certification`, `spa` does not match inside `space`, plus positive controls (`aks token still fires`, `ci/cd token still fires`, `plural microservices still matches`, `AI-credentialing prose classifies cleanly`, `no invented cloud platform`). Any future signal-set expansion runs against this corpus first.
4. **Chore: submission isolation.** The plugin's own `.gitignore` now covers the consult chain's default output paths, so a kata submission can never accidentally end up staged in the CTP plugin repo. The intended convention for GCTP-side consumption is unchanged: pass `--out` to `scripts/consult.sh` (or the underlying commands) pointing into the operator's submission tree (e.g. `../softarchcert-win25/…`). Even without `--out`, an in-repo run can no longer pollute the plugin.

## What changes for GCTP

- **Lockfile** (`docs/claude-tdd-pro.lock.yaml`): `pinned_commit`, `pinned_at`, `pinned_message` advanced to `f39fcdc`; the upstream `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md` sha256 updated (`62e87bc4… → 28748cb9…`); other 4 contract-file hashes unchanged (byte-identical, verified). Bumped by hand under this ADR (the manual-edit-under-ADR path per ADR-0079/0086/0087/0088/0089 precedent — `--update` refuses on contract drift by design).
- **Plugin cache** (`.harness/plugin-cache/claude-tdd-pro`): re-materialized at `f39fcdc` via `scripts/sync-plugin.sh --ensure` (idempotent; verified `--check` shows 0 drift at the new pin).
- **`active.json`**: regenerated via `scripts/standards-sync.sh` — expected byte-identical (§30.3 adds no authored rules; only refines classifier matching + a `.gitignore` chore).
- **`scripts/consult.sh` / `--validate-profile`**: **no code change**. The v1.1 profile shape is unchanged; only classifier *behavior* is more precise. Profiles emitted before §30.3 remain valid.
- **`scripts/audit-architecture-crosscheck.sh`**: **no code change**. Invariant 4 continues to key on `activated_probe_namespaces` — §30.3 just makes that set more precise, never less.
- **`/consult` skill**: **no code change**. The Stage 0 → Stage 1 → Stage 2 cascade walks the same way; §30.3 tightens which types Stage 0 reveals for a given vision.
- **`docs/handoff-contract.md §Business-Intake`**: light amend to note the §30.3 word-boundary matching refinement at pin `f39fcdc`+. Contract invariants unchanged.
- **`docs/upstream-ctp-proposals.md §P-12`**: adoption note extended — "precision-of-matching close-out closed at `f39fcdc` (§30.3 word-boundary classifier matching; the AI-credentialing kata pre-flight is now clean)".
- **`docs/kata-runbook.md`**: refresh to reference the `f39fcdc` pin and the §30.3 precision behavior.
- **TICKETS.md**: **TICKET-117** added, DONE, pointing at this ADR.
- **Consumer surfaces (`audit-crosscheck` invariant 4, `/consult` skill, `--validate-profile`)**: no reshape needed — §30.3 is entirely inside the classifier's matcher line and corpora; the consumer surface is unaware of the change beyond the resulting `workload_classification` set being tighter.

## Consequences

**Positive.**

- **The KATA pre-flight is now clean.** The exact operator-facing symptom that blocked the live `/consult` on `43ea692` is gone: the AI-credentialing vision no longer phantom-scopes Azure, Kubernetes, or CI-CD. The `/consult` cascade can run against the real prose and produce a submission that reflects the actual business intent.
- **Precision is now measurable + defended.** 8 spec fixtures encode the exact misfires that must never regress. Any future signal-set expansion (e.g. adding a new namespace like `mesh` or `sbom` to the classifier corpus) runs against this corpus first; a substring-collision regression is caught at spec-time, not at kata-time.
- **Additive invariant preserved.** §30.3 adds fewer false-positive types; never loses a true positive that was already matched at a clean boundary. Classifier can only tighten.
- **Submission-isolation guard closes an ambient risk.** The pre-CL-549 world let an in-repo kata `/consult` accidentally stage `standards/business-profile.json` into the CTP plugin repo. The plugin's `.gitignore` now prevents that regardless of operator care; the GCTP convention of running with `--out` into the operator's submission tree remains the primary discipline.
- Back-compat preserved: v1.1 profiles emitted before §30.3 remain valid; v1.0 profiles unchanged.

**Negative / knowingly accepted.**

- The `43ea692..f39fcdc` range carries an unrelated `03d962e` fitness-trend scoreboard row (+1 line in upstream `.harness/plugin-cache/claude-tdd-pro/docs/fitness-trend.md`). It's CTP's own DORA tracking, not a semantic CTP change; it rides along in the pin bump but has no effect on GCTP's consumed surface. Called out explicitly so future readers don't wonder what it is.
- The pin chain now runs six-deep in one operator week (ADR-0086 through ADR-0090). Unusual cadence, but each pin is a deliberate close-out of a distinct KATA-discovered defect — §29 (full-surface consult), §30 (intake seeding), §30.1 (design-engine consumption), §30.2 (precise cloud + IaC probes), §30.3 (precise signal matching), plus the submission-isolation guard. The rate reflects the KATA's success at finding real gaps, not sloppy pinning; the chain is coherent because each step is grounded in a prior ADR's disclosure.
- The upstream HEAD at fetch time (`84b792b`) is a docs commit ahead of `f39fcdc`. Adopting `f39fcdc` — the SHA CTP nominated in its handoff packet — matches convention but means an operator running `--check` will see "WARN — pin is behind upstream". This is expected + harmless: `84b792b` adds only the handoff record; no consumer-surface change. A future pin bump can catch up when there's a semantic reason.

**Neutral.**

- The kata `/consult` is now cleared to run against the real Certifiable, Inc. vision. The next artifacts in this repo will be the live-produced v1.1 profile, decisions, and architecture — landing in the operator's submission tree, not this tree.
- Historical P-13 candidate is superseded: no P-13 filed (close-out arrived from CTP without a round-trip, same as CL-547/CL-548). The P-12 ledger row extends to "matching-precision close-out at `f39fcdc`".

## Rollback

`git revert` this commit → the lockfile snaps back to `43ea692`; classifier reverts to substring matching (compact signals `aks` / `ci` / `spa` phantom-fire inside larger business words); the AI-credentialing pre-flight regresses to the buggy result. No downstream schema migration on GCTP side (nothing in the consumer surface changed).

## References

- CTP §30.3 amendment: `.harness/plugin-cache/claude-tdd-pro/docs/architecture-v1.9.md §30.3` @ `f39fcdc`
- CTP design detail: `.harness/plugin-cache/claude-tdd-pro/docs/design/v1.14-full-surface-intake.md §30.3` @ `f39fcdc`
- CTP classifier matcher: `.harness/plugin-cache/claude-tdd-pro/commands/full-surface-intake.sh` @ `f39fcdc`
- CTP CL-549 specs: `.harness/plugin-cache/claude-tdd-pro/evals/specs/cl549-precision-01..08.json` @ `f39fcdc`
- CTP handoff packet: `.harness/plugin-cache/claude-tdd-pro/docs/handoff-ctp-to-gctp-resume-kata.md` @ `f39fcdc` (nominates this pin target)
- Preceding pin bumps (§30 / §30.1 / §30.2 chain): ADR-0087 + ADR-0088 + ADR-0089
- Additivity invariant: ADR-0047
- Consult loop mechanism: ADR-0056
- Prime directive: `CLAUDE.md` §"Prime directive: plugin-dependency model"
