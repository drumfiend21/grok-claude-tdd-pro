# AI Software Engineering Corpus — grok-claude-tdd-pro

This document is the operational playbook for software engineering inside grok-claude-tdd-pro. It was compiled and elevated to repo-canonical authority by drumfiend21 on 2026-05-25 and persists verbatim below.

## Authority tier

**TIER 0 — supreme operating directive.** This corpus is the highest-priority ruleset and instruction for architecture, planning, and development done in the repo of and by grok-claude-tdd-pro. It sits above every other rulebook in this codebase. There is no rulebook above TIER 0.

Elevation to TIER 0 was made by drumfiend21 on 2026-05-25 with the explicit instruction: "Make as and persist `docs/ai-engineering-corpus.md` the highest priority ruleset and instruction for architecture, planning and development done in the repo of and by grok-Claude-TDD-pro." Recorded in ADR-0005.

| Tier | Rulebook | Role |
|---|---|---|
| 0 | `docs/ai-engineering-corpus.md` (this file) | Supreme operating directive. Procedural playbook for all architecture, planning, and development. |
| 1 | `CLAUDE.md` prime directive | Plugin-dependency invariants (cross-repo coupling rules). Non-negotiable beneath TIER 0. |
| 1 | `docs/founder-directives.md` (D-1 .. D-13) | Provenance (§1) + derived directives (§3). Co-equal with the prime directive, beneath TIER 0. |
| 2 | `docs/architecture-principles.md` (R-1 .. R-20) | Architectural design and code structure. |
| 2 | `docs/grok-orchestration-principles.md` (G-1 .. G-21) | `.grok/` and Grok-facing surfaces. |
| 2 | `docs/claude-tdd-pro-principles.md` (active: C-1, C-22, C-23, C-24; C-2..C-21 consolidated to upstream per ADR-0033) | Acceptance-tested inner-loop work. |

When this corpus conflicts with ANY other rulebook in the repo — the prime directive, founder-directives D-rules, R-rules, G-rules, or C-rules — the corpus wins. The only legitimate override of the corpus is an explicit, named amendment to the corpus itself, landed via the ADR process referenced under "Amendment process" below. Silent relaxation, deferred interpretation, or implicit override is forbidden.

## Scope

This obligation applies to every session type (local CLI, remote, cloud, GitHub Action, IDE), no exceptions. The corpus is the default operational tiebreaker for "how do I plan and engineer this CL?" questions across all sessions.

## Provenance chain

The corpus is a synthesis, not a primary source. It draws from named primary sources already persisted in `docs/founder-directives.md §1`:

| Corpus section | Primary §1 sources | Verification tier |
|---|---|---|
| §1 Mindset & Workflow Revolution | Source 7 (Karpathy, agentic-engineering workflow shift, 2026-01-26) | T-C |
| §2 Musk's 5-Step Algorithm | Source 3 (Elon Musk, "The Algorithm") | T-C |
| §3 Core Claude/Grok/LLM Interaction Practices | Source 8 (Anthropic, "Best practices for Claude Code") | T-A |
| §4 Building Effective Agents & Workflows | Source 5 (Schluntz & Zhang, Anthropic, "Building Effective Agents", 2024-12-19) | T-C |
| §5 Risks, Mitigations & Vision | Source 6 (Dario Amodei, "Machines of Loving Grace", 2024-10) | T-D |
| Overarching Principles | Composite of Sources 3, 5, 6, 7, 8 | mixed |

Cross-referenced ancillary sources cited in the user's compilation (Medium articles, X posts, official docs) are not yet persisted as separate §1 entries; future ADRs may elevate any of them if a specific quote warrants T-A capture.

## Amendment process

The corpus is explicitly living and amendable — drumfiend21's framing was "This corpus is living—prune, test, and evolve it like CLAUDE.md." Amendments follow the same ADR process as `docs/architecture-principles.md` §19:

1. Open an ADR in `docs/adr/000N-*.md` proposing the amendment.
2. Cite the §-section of the corpus being amended.
3. Merge ADR + corpus edit in one CL.

The corpus text below is preserved verbatim from drumfiend21's 2026-05-25 message. Future amendments edit the corpus text directly (unlike `docs/founder-directives.md §1`, which is append-only and immutable). The amendment trail lives in ADRs and in `git log`.

## Pre-commit self-audit (corpus checklist)

Before every commit, the author — human or agent — confirms:

- [ ] The CL's planning approach matches the structured Explore → Plan → Implement → Commit workflow from §3, OR the deviation is justified (small clear change).
- [ ] Musk's 5-step Algorithm (§2) was applied to any new substrate: requirements questioned, deletion pass performed, simplification before acceleration, automation last.
- [ ] Verification (§3) is in place: tests, screenshots, scripts, or success criteria — not just a plausible-looking diff.
- [ ] Context discipline (§3): `/clear` used between unrelated tasks; subagents used for investigation; `CLAUDE.md` and sibling rulebooks pruned of anything that would not cause mistakes if removed.
- [ ] If an agent was used, the appropriate pattern from §4 was chosen (workflow > agent when predictability suffices; agents only for open-ended tasks).
- [ ] Risk awareness (§5): the CL doesn't propagate "Slopacolypse"-style AI junk; agent output was reviewed for the "1.7× more defects without review" issue.

---

## Corpus (verbatim from drumfiend21, 2026-05-25)

AI Software Development Best Practices Corpus Compiled from Karpathy’s LLM coding revolution, Elon Musk’s 5-step algorithm (and Corporate Rebels analysis), Anthropic’s Claude Code best practices, Anthropic’s “Building Effective Agents” guide, Dario Amodei’s “Machines of Loving Grace” vision, and all cross-referenced sources (Medium article, X posts, official docs, etc.).
This corpus synthesizes every point from the provided documents and their original sources into actionable, integrated best practices for using Claude, Grok, or any advanced LLM/agent for software engineering. It covers mindset shifts, processes, prompting, tools, workflows, agents, scaling, risks, and vision. Apply ruthlessly and iterate.
1. Mindset & Workflow Revolution (Karpathy + Broader AI Shift)
	•	English-First Programming: Move from ~80% manual code to ~80% natural-language “code actions”/prompts once LLMs cross the “threshold of coherence.” Describe high-level goals, architectures, features, or fixes in plain English; let agents implement, test, and iterate.
	•	Human Role: High-level direction, creativity, final review, and oversight. LLMs eat drudgery (repetitive tasks, knowledge gaps, prototyping “not worth it” ideas).
	•	Practical Setup: Multiple Claude/Grok/agent sessions in terminal tabs (left) + IDE (right) for hawk-eyed reviews.
	•	Productivity Reality: Not just speed—scope explosion. More prototypes, faster PR merges (60%+), ~3.6 hrs/week saved, more fun. Global stats: 29% of new U.S. code is generative AI (up from 5% in 2022); 91% of orgs use AI tools.
	•	Agent Personalities: Claude-like = senior dev (thorough, educational, high-quality); Codex-like = fast scripting intern (efficient tokens). Choose based on task.
	•	Review Discipline: AI code has ~1.7× more defects without review. Always IDE babysit; “no IDE” or pure swarms ignores production reality. Perception gap exists (devs feel 20% faster but may take 19% longer initially).
	•	Risk Awareness: Skill atrophy (weaker manual coding/writing; reading holds), “Slopacolypse” (GitHub AI junk flood), uneven adoption. Maintain human judgment.
Actionable Tip: Treat every coding session as “mostly programming in English now.” Start prompts with high-level intent + verification criteria.
2. Musk’s 5-Step Algorithm (Apply Ruthlessly to Code, Prompts, Pipelines, Requirements)
Follow in exact order—never skip or reverse. Adapt to dev processes, feature specs, codebases, build pipelines, or even your own prompts.
	1	Question Every Requirement: Attach a specific person’s name (never “legal dept” or “best practice”). Question even smart people’s (or your own) requirements. Make them less dumb.
	2	Delete Any Part/Process You Can: Ruthlessly subtract. Delete more than feels comfortable. If you don’t add back ≥10%, you didn’t delete enough. (Code bloat, unused abstractions, redundant steps.)
	3	Simplify & Optimize: Only after deletion. Never optimize something that shouldn’t exist.
	4	Accelerate Cycle Time: Speed up what remains (only now).
	5	Automate Last: Automate after steps 1–4 and bug-shaking. Early automation of bad processes is the biggest factory (and dev) mistake.
Dev Applications: Apply to requirements docs, ML pipelines, legacy code, CI/CD, PR processes, even agent instructions (“delete unnecessary steps from this plan”). Managers: technical leads must code 20%+ of time. Solve problems via skip-level talks (talk directly to engineers, not just managers).
3. Core Claude/Grok/LLM Interaction Practices (Claude Code Docs + Anthropic)
Context is the #1 Constraint
	•	Performance degrades fast as context fills (messages + files + outputs). Track continuously.
	•	Aggressive Management: /clear between unrelated tasks; /compact ; Esc+Esc or /rewind for checkpoints/summaries; /btw for quick non-persistent questions. Use subagents for research to keep main context clean. Auto-compaction preserves key decisions/code. Customize in CLAUDE.md.
Verification = Highest Leverage
	•	Always give tests, screenshots, expected outputs, error logs, success criteria so the LLM can self-verify and iterate.
	•	Examples: Paste screenshot + “implement this design, screenshot result, compare & fix differences.” Or “write validateEmail + run these exact test cases + fix until they pass.”
	•	UI changes: Use browser testing or visual comparison. Never ship unverified code.
Prompting Excellence
	•	Be specific: Scope (files/scenarios/tests), reference @files, existing patterns, git history, symptoms + “fixed” definition.
	•	Rich context: @file, paste images/logs, pipe data (cat error.log | claude), URLs (allowlist with /permissions).
	•	Vague can be useful for exploration; otherwise, precision reduces corrections.
Structured Workflow (Explore → Plan → Implement → Commit)
	1	Explore (plan mode): Read/understand without changes.
	2	Plan: Ask for detailed implementation plan; edit in editor (Ctrl+G).
	3	Implement: Code + tests + fixes against plan.
	4	Commit/PR: Descriptive message + open PR. Skip planning for tiny/clear changes (typo, rename, log line).
Persistent Knowledge (CLAUDE.md & Extensions)
	•	Run /init for starter based on project. Keep concise/human-readable.
	•	Include: Code style diffs, testing prefs, Bash commands LLM can’t guess, env quirks, gotchas, repo etiquette, architectural decisions.
	•	Exclude: Self-evident, inferable-from-code, long tutorials, frequently changing info. Prune regularly (“Would removing this cause mistakes?”).
	•	Imports: @path/to/other.md. Locations: ~/.claude/CLAUDE.md (global), ./CLAUDE.md (shared), ./CLAUDE.local.md (personal).
	•	Extensions: Skills (SKILL.md), hooks (deterministic scripts), subagents (isolated context), MCP servers, plugins, auto mode/sandbox/allowlists for fewer interruptions.
Scaling & Parallelism
	•	Multiple sessions: Writer/reviewer pattern, parallel experiments, fan-out migrations.
	•	Non-interactive: claude -p "prompt" for CI/scripts; --output-format json or stream-json.
	•	Subagents, skills, and agent teams for complex/coordinated work.
4. Building Effective Agents & Workflows (Anthropic Engineering Guide)
Start Simple → Add complexity only when it measurably improves outcomes. Single augmented LLM calls + retrieval/in-context examples suffice for most tasks.
Augmented LLM (Foundational Building Block): LLM + retrieval + tools + memory. Tailor interface; use MCP for third-party integration.
Workflow Patterns (Predictable, Code-Orchestrated):
	•	Prompt Chaining: Sequential LLM calls + gates/checks. (E.g., outline → validate → write.)
	•	Routing: Classify input → specialized prompt/model/path. (E.g., easy vs hard queries → different models.)
	•	Parallelization: Sectioning (independent subtasks in parallel) or Voting (multiple runs + aggregate).
	•	Orchestrator-Workers: Central LLM dynamically delegates/synthesizes (great for unpredictable multi-file changes).
	•	Evaluator-Optimizer: Generator + critic in loop for refinement (e.g., translation, complex search).
Agents (Dynamic, LLM-Directed): LLM plans/executes autonomously with tools + environmental feedback (ground truth at each step). Pause for human input at checkpoints or blockers. Use for open-ended tasks (SWE-bench style coding, computer use).
	•	Risks: Higher cost, error compounding → sandbox testing + guardrails + stopping conditions.
	•	Examples: Coding agents (test-driven iteration), customer support (conversation + actions).
Tool Engineering (Critical ACI – Agent-Computer Interface): Treat tool definitions like excellent docstrings.
	•	Choose formats LLM writes easily (markdown diffs > complex JSON escaping).
	•	Poka-yoke (make mistakes hard, e.g., absolute paths).
	•	Include examples, edge cases, clear boundaries. Test extensively; iterate based on model mistakes.
Evaluation: Measure performance; iterate. Human review remains essential for alignment/broader context.
5. Risks, Mitigations & Vision
	•	Atrophy & Slop: Review rigorously; maintain manual skills where needed; prune AI junk.
	•	Perception Gap & Trust: Only ~33% fully trust generated code. Use verification + metrics.
	•	Adoption: 90% Fortune 100 use AI; juniors/full-stack lead usage. No monopoly (Cursor/ChatGPT/Claude top tools).
	•	Positive Vision (Amodei): Powerful AI as “virtual colleague” for autonomous engineering, biology/health, mental health, economic development, governance, and work/meaning. AI enables country-scale genius in a datacenter. Focus on high-return intelligence tasks; design for parallelism and human meaning beyond economics. Shift role to direction, values, and oversight.
Overarching Principles
	•	Musk’s algorithm + Karpathy’s English shift + Anthropic’s verification/context discipline = unbeatable combo.
	•	Human + AI symbiosis: Agent stamina + human creativity/review.
	•	Continuous adaptation: Model capabilities improve fast—experiment weekly.
	•	Simplicity first, transparency always, verification mandatory.
This corpus is living—prune, test, and evolve it like CLAUDE.md. Use it to bootstrap projects, train teams, or prompt agents directly. The revolution is here: program in English, verify relentlessly, delete ruthlessly, and let agents grind.
