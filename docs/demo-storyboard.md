# Demo Storyboard — Hybrid Harness Pitch (5 minutes)

**Audience:** State Street agentic-architecture leads (compliance / audit angle) + HubSpot Breeze AI standardization leads (multi-agent flow angle). Both Boston-based, both per `AUTOMATION_INTEL.md` 2026-05-24 entry. Pitch hook (verbatim from that entry):

> "Grok Build CLI gives you the speed of end-to-end automation. Claude TDD Pro gives you the discipline that survives 1,000 engineers shipping in parallel. The harness is the bridge — your outer pipeline is autonomous, but every code change still passes a Red-Green-Refactor gate with provenance you can show an auditor."

**Duration:** 5 minutes. **Setting:** one large screen; presenter narrates over a live terminal + IDE side-by-side. **Pre-demo state:** fresh container (cache absent), repo cloned, toy at Red baseline (4 pass / 1 fail), no `.harness/handoffs/` artifacts on disk.

**Format note:** each step ships *beats* (timestamps + on-screen action + spoken line) and *per-audience talking points*. Read this like a shot list — every beat is a discrete, executable cue.

---

## Step 1 — Cold start (0:00 → 1:00)

### Setup
- Terminal at repo root, freshly opened.
- `.harness/plugin-cache/` absent (gitignored; not yet materialized in this fresh container).
- `examples/string-utils/test/string-utils.test.mjs` at 4 pass / 1 fail baseline.

### Beats
| t | Cue | What happens |
|---|---|---|
| 0:00 | [TERMINAL] | `ls .harness/` → empty. Show the void. |
| 0:05 | [NARRATE] | *"Cold start. No cache, no state. The harness has to materialize itself."* |
| 0:10 | [TERMINAL] | `./scripts/smoke-e2e.sh` |
| 0:15 | [SCREEN] | `step 0/4: verify preconditions ... toy at Red baseline (one failing test)` |
| 0:20 | [SCREEN] | `step 1/4: wrote .harness/handoffs/TICKET-042.req.json` `request validates against handoff-contract.md §Grok→Claude` |
| 0:30 | [SCREEN] | `step 2/4: inner-loop (STUB) apply Green patch` |
| 0:35 | [SCREEN] | `step 3/4: 5 passed, 0 failed` |
| 0:45 | [SCREEN] | `step 4/4: wrote .res.json + .harness/trails/TICKET-042.md` |
| 0:55 | [SCREEN] | `smoke OK — outer loop → handoff → inner loop → green tests → response` `exit=0` |
| 0:58 | [NARRATE] | *"Forty-five seconds. Outer loop → handoff → inner loop → green tests → response. The audit trail is a by-product."* |

### Audience talking points (presenter delivers ONE; the other is held for Q&A)
- **State Street:** "Every line you just saw has an audit trail. The trail file is what you show an auditor — per change, machine-readable, version-pinned, deterministic."
- **HubSpot:** "What you saw is one harness instance closing one R-G-R cycle. Your 47 Breeze AI agent flows would each spawn one of these. Zero per-flow harness customization."

### Contingencies
- **Smoke fails.** Likely cause: outbound network blocked (cache materialization). Recovery: pre-warm cache once before the demo; if mid-demo, switch to "Step 2 — Inner Loop" using a previously-captured screen recording, return to the live terminal at Step 3.
- **Audience interrupts at 0:30 with "Is this real or pre-recorded?"** Response: pause smoke, `cat .harness/handoffs/TICKET-042.req.json | head -20` to show the request was just generated; show the `issued_at` timestamp matches the wall clock.

---

## Step 2 — The inner loop's discipline (1:00 → 2:00)

### Setup
- IDE open with three panes:
  - left: `examples/string-utils/src/string-utils.mjs` (the toy source, now reverted to Red baseline by the trap)
  - middle: `examples/string-utils/test/string-utils.test.mjs` (the test file)
  - right: `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (the actual upstream skill that drives R-G-R)
- Terminal still visible at the bottom.

### Beats
| t | Cue | What happens |
|---|---|---|
| 1:00 | [IDE LEFT] | Show `slugify` function. Highlight the missing `.trim()` call. |
| 1:05 | [IDE MIDDLE] | Highlight the failing test: `slugify('  hello world  ')` expected `'hello-world'`, actual `'-hello-world-'`. |
| 1:15 | [TERMINAL] | `node --test examples/string-utils/test/string-utils.test.mjs` → 4 pass, 1 fail. |
| 1:20 | [NARRATE] | *"This is the Red. One designed failing test. The inner loop's job is to close exactly this gap, never widen `file_scope.may_edit`, never break the other four tests."* |
| 1:30 | [IDE RIGHT] | Open `.claude/skills/tdd-pro-cl-workflow/SKILL.md`. Scroll the R-G-R discipline section. |
| 1:40 | [TERMINAL] | `ls -la .claude/skills/tdd-pro-cl-workflow` → `lrwxrwxrwx ... -> ../../.harness/plugin-cache/claude-tdd-pro/.claude/skills/tdd-pro-cl-workflow` |
| 1:45 | [NARRATE] | *"That skill file isn't a copy. It's a symlink. The harness doesn't fork or vendor — it composes by reference. The plugin's authority remains upstream."* |
| 1:55 | [NARRATE] | *"Every R-G-R cycle the inner loop runs uses THIS skill, at THIS commit pin, with hash-verified contract surface."* |

### Audience talking points
- **State Street:** "TDD discipline at the inner loop survives high-velocity engineering. Each commit is reviewable by a human in seconds — not minutes — because the structure is the same every time. That's what auditability at scale looks like."
- **HubSpot:** "Your Breeze AI flows compose on this same skill — pinned, versioned, no fork. When the plugin's R-G-R discipline upgrades, every consumer benefits in one CL — the pin bump."

### Contingencies
- **"Why not just copy the skill?"** Open `docs/architecture-principles.md §R-2` (no vendoring). Walk one line: "consumed by reference, never copied or forked." Tie back to the audit angle: copied skills drift silently; pinned skills' drift is detected and surfaced.
- **"Show me the skill driving R-G-R."** Read aloud the SKILL.md "Workflow" section. The skill IS the discipline; presenter just narrates.

---

## Step 3 — The wire (receipt of service) (2:00 → 3:00)

### Setup
- IDE: three files side-by-side:
  - `.harness/handoffs/TICKET-042.req.json`
  - `.harness/handoffs/TICKET-042.res.json`
  - `.harness/trails/TICKET-042.md`
- Reference open in a 4th tab: `docs/quality-gate.md` § "Reviewer checklist".

### Beats
| t | Cue | What happens |
|---|---|---|
| 2:00 | [IDE REQ] | Highlight `acceptance_criteria` (2 lines), `file_scope.must_not_touch` (3 globs including `.grok/**`, `.claude/**`, `claude-tdd-pro/**`), `quality_gate` (4 fields). |
| 2:10 | [NARRATE] | *"This is what Grok wrote. Acceptance criteria stated in behaviors, not steps. Scope locked. Gates declared."* |
| 2:20 | [IDE RES] | Highlight `status: "green"`, `test_results.passed: 5`, `decision_trail_ref: .harness/trails/TICKET-042.md`. |
| 2:25 | [IDE TRAIL] | Show Red / Green / Refactor sections. Read the Refactor entry aloud: *"None. Single-line change; further restructuring would be embellishment per Musk's Algorithm step 3."* |
| 2:35 | [NARRATE] | *"This is what Claude returned. Every claim in the response — the test count, the changed file, the trail — is traceable to a file the auditor can open."* |
| 2:45 | [IDE Q-G] | Switch to `docs/quality-gate.md`. Walk the four sub-gate reviewer checklists (5 seconds each). |
| 2:55 | [NARRATE] | *"'Green' isn't a model's opinion. It's a checklist. Either every box is checked, or the response status changes to 'red' and the audit trail says exactly which box failed."* |

### Audience talking points
- **State Street:** "This is the audit artifact, point-blank. Per change. Schema-versioned. The reviewer's job — your job, your auditor's job — is mechanical: walk the checklist. No subjective sign-off."
- **HubSpot:** "This wire is universal across your Breeze AI flows. One contract, many producers (Grok agents, future planner agents, even human-typed dispatches). One contract, many consumers (Claude TDD Pro today, your bespoke evaluators tomorrow). Standardized."

### Contingencies
- **"What if Claude lies?"** Walk to `docs/quality-gate.md §"Cross-cutting checks"`. The scope check, freshness check, schema check, idempotency check all run independent of the response's claims. A response that says "green" but touched a forbidden path is rejected as `scope_violation`.
- **"Can we change the quality gate?"** Open ADR-0010. Walk the alternatives section. Changes land via ADR; they don't land via a model deciding to relax the rules.

---

## Step 4 — The long loop (self-healing for between-commit debt) (3:00 → 4:00)

### Setup
- IDE: `docs/self-healing-design.md` open at §3 (signals table).
- Reference open in a second tab: §8 (failure modes).

### Beats
| t | Cue | What happens |
|---|---|---|
| 3:00 | [IDE] | Show §2 architecture diagram: Observer → Evaluator → Dispatcher → Response Watcher → Outcome Handler. |
| 3:10 | [NARRATE] | *"Per-CL gating catches debt at commit time. But debt also accumulates BETWEEN commits — coverage decay, lint drift, complexity creep, dependency staleness. This is the long loop that catches that."* |
| 3:25 | [IDE] | Scroll to §3 signals table. Highlight the severity column: P0 auto-dispatch, P1 auto with mandatory provenance, P2 HITL-only. |
| 3:35 | [NARRATE] | *"Seven signals. Three severity tiers. P0 — auto. P1 — auto with mandatory audit trail. P2 — human in the loop, every time."* |
| 3:45 | [IDE] | Switch to §8 failure modes. Highlight §8.1 (monitor loop divergence) and §8.6 (cost runaway). |
| 3:55 | [NARRATE] | *"Seven named failure modes, each with structural mitigation — cooldowns, circuit breakers, budget caps. We thought through how this breaks before we asked it to run."* |

### Audience talking points
- **State Street:** "P2 routing for `dependency-staleness` means a security advisory triggers a human approval queue, not an autonomous bump. The harness errs toward asking. Your operator owns the call."
- **HubSpot:** "At Breeze AI scale, debt is statistical. A 0.1% per-agent regression is invisible per-agent and catastrophic across 1,000 agents. The long loop is how you catch the statistical pattern before it compounds."

### Contingencies
- **"Why HITL for P2 instead of auto?"** ADR-0011 §"Alternatives considered". Read the rejected alternative "Auto-dispatch everything, no HITL" — short, decisive.
- **"When does the implementation land?"** Open `docs/self-healing-design.md §16`. Show TICKET-008.a..e sequencing. Honest answer: design is shipped; reference implementation is the next executable CL.

---

## Step 5 — The contract (no-vendor, no-fork) (4:00 → 5:00)

### Setup
- Terminal at repo root.
- IDE: `docs/claude-tdd-pro.lock.yaml`.

### Beats
| t | Cue | What happens |
|---|---|---|
| 4:00 | [IDE] | Open the lock file. Highlight `pinned_commit: b277284...`, the `pinned_at` timestamp, and the `contract_surface_hashes` list (4 file hashes). |
| 4:10 | [TERMINAL] | `./scripts/sync-plugin.sh --check` |
| 4:15 | [SCREEN] | `pinned: b277284 ... upstream: 23e5c2b ... 3 file(s) drifted ... status: WARN — contract surface drifted; review upstream before bumping` |
| 4:25 | [NARRATE] | *"Upstream moved. The harness sees it. The harness does NOT auto-update — bumping the pin requires an ADR."* |
| 4:35 | [TERMINAL] | `ls docs/adr/` (show ADR-0001 through ADR-0011). |
| 4:40 | [IDE] | Open `docs/adr/0001-plugin-lockfile-session-sync.md`. Scroll the decision + alternatives sections. |
| 4:50 | [NARRATE] | *"Eleven architectural decisions, each one append-only, each one reviewable. No silent upstream change ever reaches your codebase. No fork to maintain. The contract is the surface; the pin is the signature."* |

### Audience talking points
- **State Street:** "Your auditor opens `docs/claude-tdd-pro.lock.yaml` and immediately knows the upstream version state. Drift is detected, not silenced. Pin bumps are versioned, dated, ADR-traced."
- **HubSpot:** "If you fork the harness for Breeze AI internals, you fork the harness — NOT the plugin. Plugin stays clean. Your customizations live in your repo. Zero vendor lock-in. The plugin's authors don't need to know you exist."

### Closing beat (4:55 → 5:00)
- 4:55 [NARRATE] *"Five minutes. The harness is real. The wire is real. The discipline is real. The long loop is designed. The contract is signed. Questions?"*
- 5:00 [PAUSE FOR Q&A].

---

## Q&A reserve cues (held back; deploy as asked)

| If asked | Open | Spoken anchor |
|---|---|---|
| "What's the minimum to adopt this?" | `README.md` §Status + `scripts/smoke-e2e.sh` | "Clone, run the smoke, watch exit 0. The harness self-materializes." |
| "What about [language X] support?" | `examples/string-utils/test/string-utils.test.mjs` (the framework) | "The test framework is named in `test_results.framework`. Any framework that exits non-zero on failure works." |
| "What about [tool] integration?" | `docs/handoff-contract.md` | "The wire is JSON. Any producer that writes the request schema, any consumer that reads it. Open contract." |
| "What's the failure mode if Claude is offline?" | `docs/handoff-contract.md` §"freshness rules" + smoke's stub mode | "Stub mode is the CI-deterministic path. Live-Claude is one of two producer options at step 2." |
| "Is this open source?" | (decline scope) | "Architecturally yes by design; licensing is a separate conversation." |
| "How do I get started today?" | `TICKETS.md` + `docs/architecture.md` | "Read TICKETS.md to understand the ten-CL scaffold. Read architecture.md for the role split." |
| "What hasn't been built yet?" | `README.md` §Status (Pending bullet) + `docs/self-healing-design.md §16` | "Self-heal implementation, demo-target work for your specific repo, provenance bridging. All sequenced." |

## Pre-demo checklist (run T-minus 10 minutes)

- [ ] `./scripts/sync-plugin.sh --ensure` → cache materialized.
- [ ] `./scripts/smoke-e2e.sh` → exit 0.
- [ ] `node --test examples/string-utils/test/string-utils.test.mjs` → 4 pass / 1 fail (Red baseline preserved).
- [ ] `rm -rf .harness/plugin-cache/` so Step 1 demonstrates a real cold-start. (The hook + smoke will re-materialize.)
- [ ] Terminal font size ≥18pt; IDE font ≥14pt; screen mirror tested.
- [ ] Backup screen recording of `smoke-e2e.sh` available (file path documented; play in case of network blackout).
- [ ] Q&A reserve cues table printed on a single sheet beside the laptop.

## Post-demo follow-ups

- [ ] Send each attendee `README.md`, `docs/architecture.md`, `docs/quality-gate.md`, `docs/self-healing-design.md` (4 files; ~50KB total; cold-readable).
- [ ] Offer a follow-up working session with their team's repo plugged in (live-Claude mode, real linter, real coverage).
- [ ] Log the audience reactions / objections in a new `AUTOMATION_INTEL.md` dated entry per the append-only convention.

## Authority and amendment

This storyboard is operational, not architectural — it describes how the harness is *demonstrated*, not how it *behaves*. Amendments land as updates to this file without ADR (the demo itself is not in the contract surface). Bumping a beat's timing or re-ordering steps is fine; changing what's claimed about the harness is NOT — claim consistency with the design docs is enforced indirectly by `./scripts/audit-doc-drift.sh` (the docs the storyboard references must stay current; if they shift, the storyboard's references go stale and the audit's F-class extensions will catch it).

## Cross-references

- `AUTOMATION_INTEL.md` — Boston/US enterprise signals + pitch hook.
- `README.md` — top-of-repo orientation.
- `docs/handoff-contract.md` — the wire shown at Step 3.
- `docs/quality-gate.md` — the reviewer checklists shown at Step 3.
- `docs/self-healing-design.md` — the long loop shown at Step 4.
- `docs/claude-tdd-pro.lock.yaml` — the pin shown at Step 5.
- `docs/adr/` — the eleven decision records referenced at Step 5.
