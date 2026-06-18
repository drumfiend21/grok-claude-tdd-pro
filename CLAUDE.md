# CLAUDE.md — grok-claude-tdd-pro

Project instructions for Claude when operating in this repo. These instructions apply to **every** session type — local CLI, remote, cloud (web), GitHub Action, IDE — without exception.

**Operator entry point: [`QUICKSTART.md`](QUICKSTART.md) at repo root.** If the operator is bootstrapping the harness for the first time (or asks "how do I start"), route them there — it's the 3-minute environment bootstrap + 15-minute first cycle. This CLAUDE.md file is the prime directive (authority + invariants); QUICKSTART is the operator's "what to do" path.

## Supreme operating directive (TIER 0): AI engineering corpus

`docs/ai-engineering-corpus.md` is the **highest-priority ruleset and instruction** for architecture, planning, and development done in the repo of and by grok-claude-tdd-pro. It is the supreme operating directive — TIER 0 — and sits above every other rule, directive, principle, or invariant in this codebase. When any rule below conflicts with the corpus, the corpus wins.

That document is the operational procedural playbook for software engineering inside grok-claude-tdd-pro: a synthesis of the founder-directives §1 sources (Karpathy's agentic-engineering shift; Musk's 5-step Algorithm; Anthropic's Claude Code best practices and Building Effective Agents; Amodei's Machines of Loving Grace) into a single, ruthlessly actionable corpus covering mindset, the 5-step algorithm, Claude/Grok/LLM interaction practices, agent and workflow patterns, scaling, risks, and vision.

Authority tier: **TIER 0 — supreme**. Sits above the prime directive (plugin-dependency model), the founder-directives rulebook (D-1 .. D-13), and all R- / G- / C- rulebooks. There is no rulebook above TIER 0. When the corpus conflicts with any other rule in this repo, the corpus wins. The only legitimate override of the corpus is an explicit, named amendment to the corpus itself, landed via ADR per `docs/architecture-principles.md` §19.

Before architecting, planning, or engineering anything in this repo:

1. Read `docs/ai-engineering-corpus.md` — both the framing (authority, provenance chain, amendment process, pre-commit corpus checklist) and the verbatim corpus body (§§ 1–5 + Overarching Principles).
2. Apply the corpus's pre-commit checklist as the **first** checklist in pre-commit review. Other checklists (founder-directives D-checklist, architectural, Grok, Claude TDD Pro) compose on top but never override.
3. If the corpus conflicts with the request, raise it before acting. The corpus is supreme — silent relaxation is forbidden.
4. The corpus is explicitly living — amendments follow the ADR process in `docs/architecture-principles.md` §19. Unlike `docs/founder-directives.md §1` (which is immutable and append-only), the corpus body is editable; the amendment trail lives in ADRs and `git log`.

This obligation applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Prime directive: plugin-dependency model (TIER 1, non-negotiable beneath TIER 0)

`grok-claude-tdd-pro` (this repo) **imports and consumes** `claude-tdd-pro` (sibling repo) as a **plugin**. The two repos are independent microservices:

- **This repo** is the harness/consumer. It depends on `claude-tdd-pro` the same way an application depends on a library — by referencing a pinned version through the documented contract surface, never by editing it in place.
- **`claude-tdd-pro`** is the plugin/provider. It exposes skills (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) and the architecture text that defines TDD discipline. It does not know about this repo and never imports from it.

Invariants every change here MUST preserve:

1. **No cross-repo edits.** A change in this repo MUST NOT require an edit inside `claude-tdd-pro`. If a harness need surfaces that the plugin doesn't satisfy, file it as a v1.11 amendment proposal in `claude-tdd-pro` separately — do not patch the plugin from here.
2. **Versioned consumption.** The plugin is imported by reference (path, git ref, or skill name + version) — never copied, vendored, or forked into this tree. If you find yourself duplicating a file from `claude-tdd-pro`, stop and wire it through the import path instead.
3. **Contract-only coupling.** The only legitimate coupling surface is the handoff contract in `docs/handoff-contract.md` and the named skill IDs the plugin exposes. Reaching into plugin internals (private paths, undocumented behaviors) is a contract violation.
4. **Independent release cadence.** This repo and `claude-tdd-pro` ship on independent timelines. A breaking change in this repo must not block a `claude-tdd-pro` release, and vice versa, beyond renegotiating the contract version.

If a request or future instruction conflicts with these invariants, raise it before acting. These rules override default Claude behavior and override any contradictory TIER-1 or TIER-2 instruction not explicitly marked as superseding the prime directive. They do NOT override the TIER-0 supreme operating directive (the AI engineering corpus) above — that authority sits above the prime directive.

## Authoritative founder-directives rulebook (TIER 1, co-equal with prime directive beneath TIER 0)

All work in this repo — design, code, docs, prompts, hooks, skills, monitors — MUST conform to `docs/founder-directives.md`. That document is the operational rulebook for named-source directives elevated to repo-canonical authority by the architecture team: thirteen numbered directives (D-1 .. D-13) derived from immutable §1 provenance entries. Sources currently elevated: @teslayoda + @elonmusk on closing the loop on progressively harder problems (2026-05-24 X posts); Elon Musk's 5-step "Algorithm" engineering process; xAI's official Grok Build CLI announcement (`x.ai/news/grok-build-cli`, 2026-05-14); Anthropic's Schluntz/Zhang "Building Effective Agents" (2024-12-19); Dario Amodei's "Machines of Loving Grace" (2024-10); Andrej Karpathy's agentic-engineering workflow shift (2026-01-26); Anthropic's "Best practices for Claude Code" (code.claude.com/docs; T-A direct primary, persisted verbatim in §1); and xAI's "Grok Build Beta" canonical product surface (`x.ai/cli`, accessed 2026-05-26; Source 9 elevated via the `docs/researcher-discipline.md` fallback procedure at T-C). §1 entries are tagged with explicit verification tiers (T-A direct primary / T-B screenshot / T-C search-engine-indexed extract / T-D substantive paraphrase) — see `docs/founder-directives.md` §1 for the model and `docs/researcher-discipline.md` for the operationalized procedure.

Authority tier: **TIER 1**, co-equal with the prime directive above, and beneath the TIER-0 supreme operating directive (the AI engineering corpus). When a D-rule conflicts with an R- / G- / C-rule, the D-rule wins (per `docs/founder-directives.md` §5). When a D-rule conflicts with the TIER-0 corpus, the corpus wins. When the two TIER-1 authorities (prime directive and founder-directives) themselves conflict, raise it explicitly — neither defers to the other by default.

Before designing or coding anything:

1. Read `docs/founder-directives.md` §3 (the D-rules) and §4 (the pre-commit self-audit checklist).
2. Apply the D-checklist alongside the architectural, Grok, and Claude TDD Pro checklists before committing.
3. If a D-rule conflicts with the request, raise it before acting — do not silently relax a directive.
4. Amendments follow the ADR process in `docs/architecture-principles.md` §19. Never edit a D-rule in place. Never edit a §1 provenance entry, ever — even for typos.

This obligation applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Authoritative architectural rulebook

All architectural design and development work in this repo MUST conform to `docs/architecture-principles.md`. That document is the operational rulebook — twenty numbered rules (R-1 .. R-20) synthesized from the canonical industry sources on microservice loose coupling (Lewis/Fowler, Newman, Richardson, CNCF, Twelve-Factor, Reactive Manifesto, DDD, Clean Architecture, Team Topologies, Postel's Law, CDC, SemVer, AWS Well-Architected, Nygard ADRs).

Before designing or coding anything architecturally significant:

1. Read `docs/architecture-principles.md` §16 (the rules) and §17 (the self-audit checklist).
2. Apply the checklist to the proposed change before committing.
3. If a rule conflicts with the request, raise it before acting — do not silently relax a rule.
4. If you propose to change a rule, do it through the ADR amendment process in §15 + §19 of that document. Never edit a rule in place.

This obligation applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Authoritative Grok orchestration rulebook

All work that touches `.grok/`, AGENTS.md, the handoff layer, the Grok system prompts, the Grok-driven monitors, or any other Grok-facing config MUST conform to `docs/grok-orchestration-principles.md`. That document is the operational rulebook for Grok-as-outer-loop-orchestrator — twenty-one numbered rules (G-1 .. G-21) synthesized from xAI's official Grok and Grok Build CLI guidance, Anthropic's *Building Effective Agents*, canonical orchestrator-worker and hierarchical multi-agent patterns, LangGraph's supervisor pattern, the AGENTS.md and Agent Client Protocol open standards, the self-healing agent pattern, and the production HITL approval-gate literature.

Before designing or coding anything Grok-facing:

1. Read `docs/grok-orchestration-principles.md` §15 (the G-rules) and §16 (the Grok self-audit checklist).
2. Apply the Grok checklist alongside the architectural checklist before committing.
3. If a G-rule conflicts with the request, raise it before acting.
4. Amendments follow the same ADR process documented in `architecture-principles.md` §19 — never edit a G-rule in place.

This obligation also applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Authoritative Claude TDD Pro consumption rulebook

All work inside acceptance-tested scope — every inner-loop invocation, every test, every refactor, every commit driven by `claude-tdd-pro` — MUST conform to `docs/claude-tdd-pro-principles.md`. That document is the operational rulebook for consuming the plugin. Per Musk #1 deletion-pass closure (ADR-0033) the active harness-side rule set is **4 rules** (C-1 TDD discipline; C-22 substrate batching; C-23 bash 3.2 portability; C-24 DORA scoreboard); 20 inner-loop discipline rules (formerly C-2..C-21) are CONSOLIDATED into the upstream plugin per the prime directive (the harness consumes via the SKILL.md trio symlinked from the pinned plugin cache; canonical rule bodies live in `claude-tdd-pro/.claude/skills/tdd-pro-cl-workflow/SKILL.md`). Intellectual provenance (Beck, Uncle Bob's Three Laws, Fowler's *Refactoring*, Feathers' *Working Effectively with Legacy Code*, Cohn's test pyramid, London/Chicago schools, mutation/property-based testing, Anthropic's Claude Code best practices, DORA from *Accelerate*) retained in `docs/claude-tdd-pro-principles.md §§1-15`.

Before designing or coding anything inside acceptance-tested scope:

1. Read `docs/claude-tdd-pro-principles.md` §16 (the C-rules) and §17 (the inner-loop self-audit checklist).
2. Apply the C-checklist alongside the architectural and Grok checklists before committing.
3. If a C-rule conflicts with the request, raise it before acting.
4. Amendments follow the same ADR process documented in `architecture-principles.md` §19 — never edit a C-rule in place.

This obligation also applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions.

## Scope

This repo is a **prototype harness**, not the quality core. The quality core lives in `claude-tdd-pro` (sibling repo). When in doubt about TDD discipline, architecture fidelity, or commit workflow, defer to:

- `claude-tdd-pro/CLAUDE.md` (the authoritative workflow)
- `claude-tdd-pro/docs/architecture-v1.9.md` (the authoritative architecture)
- `claude-tdd-pro/.claude/skills/tdd-pro-cl-workflow/SKILL.md` (the per-CL loop)

This file adds only what is specific to the hybrid harness.

## Two harness rules (non-negotiable)

1. **Grok owns the outer loop.** Research, requirements gathering, architecture decomposition, ticket spawning, deployment, long-running monitoring, self-healing triggers. Grok does not edit code directly inside acceptance-tested scope — it hands off to Claude TDD Pro for that.
2. **Claude TDD Pro owns the inner loop.** Red-Green-Refactor enforcement for one ticket at a time. Claude does not do its own research or deploy — it receives a structured handoff (TICKET-002 schema), produces a passing change, returns control.

Violating either rule means the harness is not being used; it's just two tools running adjacent.

### GCTP↔CTP architecture-consult loop — the crossroads/translator model (per ADR-0056)

This composes on (does not replace) the two rules above. GCTP sits at the **crossroads** between
CTP (technical architecture + development, standards-enforced) and the **user** (often non-technical,
speaking business/creative language), and runs a **per-juncture loop**:

1. **Intake (GCTP).** Elicit, in plain language, what the user wants to build.
2. **Consult-and-translate loop (GCTP↔CTP), repeated at every juncture/decision:** GCTP consults
   CTP's architecture engine for grounded technical direction (CTP enforces google/owasp/government/
   EO/SLSA/… with cite-or-decline); GCTP **translates** that technical reality into non-technical,
   business/creative terms as clarification + guidance; prompts the user; the user decides; GCTP
   translates the decision back to CTP.
3. **Incremental sizing/ticketing (GCTP).** As decisions are made, GCTP sizes + tickets each chunk
   via a CTP consult on its technical reality.
4. **Dual enforcement (GCTP).** GCTP independently cross-checks all of CTP's proposed architecture/
   design/development against GCTP's own rules — the shared `active.json` registry **plus** the
   GCTP-native governance (R-rules, D-rules, EO spine, citation-integrity, TIER-0 corpus). Cross-check
   failure ⇒ bounded re-consult, else an operator-approved deviation (`docs/deviations.md`).
5. **Roadmap (GCTP).** Present real tickets — sized, sequenced, planned — to the user.

The whole loop is a **guided experience of world-class software engineering**: world-class because CTP
architects under enforcement **and** GCTP checks/enforces on top. Ruby ≥ 3.0 is a hard prerequisite for
the loop (CTP's engine is Ruby-backed; absent ⇒ stop-and-remediate, no silent fallback). Contract
schemas: `docs/handoff-contract.md §Architecture-Consult-Loop / §Architecture-Cross-Check / §Roadmap`.
Mechanism + sequencing: ADR-0056 (wired in later CLs; this entry is the standing model).

## Agent operating compact (TIER 1 — non-negotiable behavioral binding, per TICKET-068 / ADR-0057)

`docs/agent-operating-compact.md` is the **binding behavioral contract** on the agent (Claude Code first) that drives GCTP. It composes beneath the TIER-0 corpus and alongside the prime directive; it binds *how the agent behaves* when running the harness. Read it at session start. Its commitments, in brief:

1. **Act only as the user of GCTP** — describe what to build in plain language; drive only the sanctioned commands `/consult → /roadmap → /decompose → /dispatch → /inner-loop → /audit`.
2. **Do not architect anything yourself** — every architectural decision comes out of CTP's engine via the consult spine (`scripts/consult.sh` + `/consult`), never from the agent's own head or memory. Generation under enforcement, never authoring-then-validating.
3. **No direct line to CTP** — no ad-hoc engine prompts, no reaching into plugin internals, no hand-written req/res/architecture artifacts. The only contact with CTP is through GCTP's spine (prime-directive contract surface).
4. **Nothing enters the app repo that GCTP didn't generate** — no hand-authored ADRs/designs/code for the user's product; the gates are the backstop, not the source.

**Honest caveat (in the compact, not papered over):** GCTP is not a separate brain — it is command-prompts + shell scripts that *the agent* executes. The agent's cognition is unavoidable (it performs the CTP→plain-language translation `/consult` instructs); what is enforced is that this cognition is **confined to executing GCTP's procedure and translating CTP's output — never to originating architecture.**

**Scope boundary (so the compact does not eat itself):** the compact governs **application architecture built through GCTP for the user**. It does **NOT** govern **harness self-maintenance** (editing GCTP's own docs/scripts/governance) — that runs on the ADR + founder-directives + R/G/C-rule + per-CL TDD plane, under operator review. Conflating the two is itself a violation, in either direction.

**Enforcement (fail-closed, per ADR-0057):** the operator MUST accept the compact (`scripts/accept-compact.sh`, recorded at `.harness/agent-compact-ack.json`, keyed to the compact's content hash), and the agent is enforced by that agreement. **Until a current acceptance exists, Claude Code MUST NOT drive the sanctioned GCTP workflow** (`/consult`..`/inner-loop`) for the user's product — it may only read docs and run `scripts/accept-compact.sh`. `.claude/hooks/session-start.sh` presents the compact + STOP banner when unaccepted/stale (a deliberate ADR-scoped exception to ADR-0001's warn-only policy); `scripts/audit-agent-compact.sh` is the pre-commit + CI machine gate (present + wired + currently accepted, else red). Any amendment to the compact invalidates acceptance until re-accepted. This obligation applies to every session type.

## Operator-declared standards (TIER 1 — non-negotiable, per TICKET-032 / ADR-0037)

Both agents MUST consult `.harness/rules/active.json` at session start. This file is the aggregated rule registry from the plugin's `standards/` + `rubric/` + `generated-code-quality-standards/` pipeline — currently 28 rules across the namespaces `google`, `node`, `owasp`, `react`, `slsa`, `typescript`, `w3c`, `web-vitals`, `_community`. Operator-declared sources include Google's TS/JS/Python style guides, OWASP ASVS + Top 10, SLSA build provenance, WCAG 2.2, Web Vitals, React + Next.js best practices, Node.js best practices, TypeScript handbook.

Workflow enforcement:

- **Grok (outer loop):** when emitting a `.harness/handoffs/TICKET-NNN.req.json`, populate `applicable_rules` by filtering `active.json` against the ticket's `file_scope` + detected language(s). The field is REQUIRED for any ticket touching app code.
- **Claude (inner loop):** when receiving a request, run `rubric/runner.sh` against each rule in `applicable_rules` as part of the R-G-R green check. The response's `rules_verified` field carries pass/fail/deviated per rule ID. A `green` status requires every applicable rule to be `pass` OR `deviated` (= violation with a row in `docs/deviations.md`). Any `fail` is `red`.
- **Both:** if a deviation is genuinely needed, surface back through the response trail; the operator lands an ADR + a row in `docs/deviations.md`. Neither agent silently accepts a rule violation.

The `.claude/hooks/post-tool-use-review-gate.sh` enforces this at write-time (per Batch 4 of TICKET-032).

### EO-2026 as a standing governance dimension (per ADR-0045)

The 2026-06-02 Executive Order *"Promoting Advanced Artificial Intelligence Innovation and Security"* is elevated to a **cross-cutting governance layer**, not a siloed feature — it patterns quality, process, and security across **every** ticket, handoff, and CL the harness dispatches, by construction. It is a first-class, **always-on** member of this operator-declared-standards regime, governed by the same `applicable_rules` → `rules_verified` → quality-gate machinery above. Mechanics:

- **Additive, never subtractive (per ADR-0047).** The EO standards/patterns layer ON TOP of the pre-existing world-class standards established at the start of this repo — the full `active.json` registry (`google`, `node`, `owasp`, `react`, `slsa`, `typescript`, `w3c`, `web-vitals`, `_community`), the architecture R-rules, the founder-directives D-rules, the TIER-0 corpus, and the TDD/C-rule discipline. The EO layer may only ADD required rules, gates, and attestations; it MUST NOT remove, relax, weaken, or substitute for any existing standard. The gate is a conjunction: both the base standards AND the EO layer must pass. On overlap, the stricter requirement governs (monotonic — the EO layer can only tighten the bar). An EO deviation never waives a base standard, and vice versa.
- **Rule content is sourced from the plugin, never forked here.** The harness MUST NOT invent harness-native EO rules. The EO-aligned standards/rubric content is authored in `claude-tdd-pro` and flows into `.harness/rules/active.json` via `standards-sync.sh` on a pin bump. The harness owns the **enforcement spine**; the plugin owns the **rule content**. The two meet at the contract surface (`active.json` + `applicable_rules`) — neither reaches into the other (prime directive). **Activated (ADR-0055): at pin `6d2fe13`+ the EO content is LIVE under the `security-governance` namespace (`require-provenance` P1 + `no-known-exploited-ingress` P0); `scripts/audit-eo-governance.sh` keys on `eo` + `security-governance`, so the spine is no longer vacuous.**
- **Always-on, not opt-in.** EO-namespaced rules in `active.json` are applicable to every ticket by default — the existing fail-closed default (absent `applicable_rules` ⇒ all rules apply, per `docs/handoff-contract.md`) already enforces this; the EO layer makes it explicit and removes any per-ticket exemption for the EO subset.
- **Gate teeth.** The harness-native EO sub-gates (vulnerability remediation, provenance/signing) are standing `green` requirements per `docs/quality-gate.md`; the EO compliance profile (`docs/eo-2026-ai-innovation-security-alignment.md`) maps them to NIST AI RMF / SSDF / CISA controls.
- **TICKET-043..049 are *instances* of this layer, not the layer itself.** The layer is the standing posture; the tickets are individual capabilities that hang off it.
- **Two-phase enforcement (per ADR-0046).** The EO patterns BOTH the design Claude TDD Pro produces *before* it codes AND the code it then writes. Enforcement at both phases is the **plugin's own** behavior (`tdd-pro-cl-workflow` design→code discipline, its in-flight EO work); the **harness demands + verifies** via the contract — the decision-trail/response MUST attest design-phase EO conformance, and `green` requires EO evidence for both the pre-code design and the code. The harness does not implement the plugin's design-phase enforcement; it requires the attestation.

Design + decision record: `docs/eo-2026-ai-innovation-security-alignment.md` + ADR-0043/0044/0045. This dimension sits **within** the operator-declared-standards TIER-1 regime — it does not outrank the prime directive, the founder-directives, or the TIER-0 corpus.

## Working in this repo

- One ticket per CL. Ticket IDs come from `TICKETS.md`.
- Commit messages reference the ticket: `TICKET-NNN: <verb> <object>`.
- Do not modify `claude-tdd-pro` from this repo. If a harness lesson warrants a feature there, file it as a v1.11 amendment proposal in that repo separately.
- The handoff contract (TICKET-002) is the API boundary. If you find yourself extending it ad-hoc, stop and update the contract first.

## What this repo does NOT do

- Re-implement Red-Green-Refactor. Reuse the three `tdd-pro-*` skills.
- Define a new `tdd-pro-core` SKILL.md. The existing trio is the core.
- Touch `claude-tdd-pro` substrate, specs, or architecture text.

## Cross-tool agent-binding surface

Non-Claude agents (Cursor's chat agent, Codex, Amp, Jules, Factory, Grok Build) read `AGENTS.md` at repo root for their session-start binding context. Claude Code reads this file (`CLAUDE.md`); the two surfaces compose without duplicating each other. See ADR-0012 for the rationale and the eight-section schema.
