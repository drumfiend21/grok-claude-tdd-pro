# Grok Orchestration Principles

Authoritative reference for how Grok is used in this repo. Grok plays the **outer-loop orchestrator** role specified in `docs/architecture.md`: research, decomposition, ticket spawning, dispatch to the inner loop (Claude TDD Pro via the handoff contract), deploy coordination, long-running monitoring, and self-healing triggers. Grok does NOT edit files inside acceptance-tested scope.

This document is the binding rulebook for that role. Synthesized from xAI's official Grok and Grok Build CLI guidance, Anthropic's *Building Effective Agents*, canonical multi-agent orchestration patterns (orchestrator-worker, hierarchical supervisor, LangGraph supervisor), the AGENTS.md and Agent Client Protocol (ACP) open standards, the self-healing agent pattern, and the production HITL approval-gate literature.

This document complements (does not replace):

- `CLAUDE.md` — the prime directive (plugin-dependency model)
- `docs/architecture-principles.md` — the cross-cutting microservice rules (R-1 .. R-20)
- `docs/architecture.md` — the harness-specific architecture
- `docs/handoff-contract.md` — the API boundary between Grok and Claude TDD Pro

If a request, design, or code change in this repo conflicts with a rule below, raise it before proceeding. The rules in §15 are the operational form.

---

## How to use this document

1. **Before designing a Grok orchestration flow** (research prompt, decomposition template, dispatch routine, monitor): read §15 first; consult the relevant authority section for the underlying principle.
2. **Before committing** any change that touches `.grok/`, AGENTS.md, the handoff layer, or any Grok-facing config: run the self-audit checklist in §16.
3. **When a rule is in tension with a request**: defer to the rule. Surface the tension. Do not silently relax it.
4. **Amendments** follow the ADR process documented in `architecture-principles.md` §19. Rules above are immutable in spirit; supersession is explicit, not in-place editing.

---

## §1. xAI Grok Build CLI — Official conventions [1]

Grok Build is xAI's headless-capable terminal coding agent. The official launch material defines the conventions this repo treats as binding:

- **Headless mode (`-p`)** — accepts a single prompt, returns structured output. Scriptable for CI/CD, scheduled jobs, internal automations. Auth is via an `XAI_API_KEY` environment variable; browser sign-in MUST NOT be on the critical path for headless flows.
- **Plan mode** — for interactive work: developer states a high-level objective, Grok emits a numbered plan with files to touch, commands to run, and tests to write, then **pauses for approve / edit / discard** before executing.
- **Parallel sub-agents** — up to 8 sub-agents per launch by default, each running in **its own git worktree** (isolated branch, separate working directory, mergeable output).
- **Foreground vs. background delegation** — foreground sub-agents (`explore`, `general`, `computer`) for tasks whose results gate the parent; background `delegate` for read-only deep dives the parent can proceed without.
- **Conventions auto-detected** — Grok Build automatically picks up `AGENTS.md`, plugins, hooks, skills, and MCP servers in the repo. No reconfiguration needed to slot into an existing project.
- **Hooks** — shell commands executed at agent lifecycle events. Use them for pre-dispatch checks, post-completion verification, and audit-trail emission.
- **Full ACP support** — Grok Build speaks the Agent Client Protocol natively, so it can be embedded behind a custom orchestrator or composed with other ACP-speaking agents (Claude Code, Gemini CLI, Codex CLI) in the same pipeline.

## §2. xAI Grok API — Best practices [2]

For programmatic use of Grok via the xAI API (the substrate Grok Build CLI sits on top of):

- **Statelessness** — the chat API has no memory between calls. The caller is responsible for sending the full conversation (system + user + assistant + tool turns) on every request.
- **Structured prompts** — use labeled markup (XML tags, Markdown headings) to separate task, constraints, context, and expected output structure. Grok's retrieval accuracy on long/multi-part prompts depends on this.
- **Structured outputs** — for any output that flows into another system, use the Structured Outputs API (Pydantic / Zod / JSON Schema). Do not parse free-form text downstream.
- **Tool/function calling** — agentic prompts succeed on three things: (a) well-specified function schemas, (b) explicit instructions about which tool for which sub-task, (c) explicit output-format constraints at each step.
- **Reasoning effort** — `none | low | medium | high`. Pick by **workflow latency budget**, not capability ceiling. High effort can inflate time-to-first-token 5–60×; usable for batch/async, painful for chat.
- **Model selection** — Grok 4.3 for general agentic reasoning and tool use; Grok 4.1 Fast / Grok 4 Fast for high-throughput chat/RAG/agent loops at ~1/15th the cost; Grok Code Fast (`grok-code-fast-1`) for code-focused workloads.
- **Prompt caching** — cached input tokens are ~$0.20 / 1M (much cheaper than uncached). System prompts, policy blocks, and contract templates SHOULD be stable across requests to maximize cache hits.
- **Deep Search** — xAI's first agent; synthesizes across the web/X corpus with reasoning over conflicting sources. Use for genuinely novel external research, not as a default lookup.

## §3. Anthropic — Building Effective Agents (the five patterns) [3]

The canonical taxonomy of LLM workflow patterns. Every Grok orchestration in this repo MUST be built from one or a composition of these five:

1. **Prompt Chaining** — break a complex task into a fixed sequence of steps; each step's output feeds the next.
2. **Routing** — classify the input, dispatch to a specialist (specialist prompt, specialist model, or specialist sub-agent). Avoids overloading a single prompt.
3. **Parallelization** — independent subtasks run concurrently. Two flavors: **sectioning** (different subtasks) and **voting** (same task, diverse outputs, aggregate).
4. **Orchestrator-Workers** — a central LLM dynamically decomposes the task, delegates each subtask to a worker LLM, and synthesizes the results. Used when the subtask shape can't be predicted up front (the canonical pattern for software changes where the number/nature of files to edit depends on the task).
5. **Evaluator-Optimizer** — the Optimizer proposes a solution; the Evaluator critiques; loop until acceptance criteria are met or escalation triggers.

In this repo's harness: **Grok is the Orchestrator** in pattern #4; **Claude TDD Pro is the Worker**; the self-healing monitor uses pattern #5.

## §4. The Orchestrator-Worker Pattern (canonical form) [4]

A single orchestrator agent **plans, routes, supervises**, and **synthesizes**. It does not do the leaf work itself.

- The orchestrator decomposes the parent task into subtasks.
- It dispatches each subtask to a specialized worker with a focused prompt and a narrow tool set.
- The worker returns a typed result.
- The orchestrator synthesizes the workers' results into the parent deliverable.

Specialists make the orchestrator dumber and the workers sharper — which is the whole point. Avoid letting the orchestrator drift into worker territory ("I'll just patch this one file"). Drift breaks the abstraction and the audit trail.

## §5. Hierarchical Multi-Agent Orchestration [5]

When a flat orchestrator-worker tree exceeds practical fan-out (~5–10 workers per supervisor), introduce **mid-level supervisors**. Top-level supervisor sets objectives; mid-level supervisors own domains; leaf workers execute.

- Coordination overhead grows with depth — keep the tree as shallow as the work allows.
- Each supervisor publishes a typed contract (input schema, output schema, error mode) — supervisors don't introspect their subordinates' internals.
- Hierarchical orchestration buys centralized control + decentralized scalability; the cost is more layers to debug.

## §6. LangGraph Supervisor Pattern — state, checkpoints, HITL [6]

LangGraph's production-grade implementation of the supervisor pattern adds three durable mechanisms this repo treats as required for any long-running Grok flow:

- **State as a typed object** — every node sees and updates a shared, schema-validated state. No ad-hoc dictionaries.
- **Checkpoints** — every state transition is persisted (Postgres / Redis in prod). If a run crashes at step N, resume from step N-1; do not re-run the whole pipeline.
- **Human-in-the-loop** — specific edges can be marked as `requires_approval`. The runtime pauses, persists state, releases the thread, and resumes from the exact pause point when the human approves.

For Grok Build flows: hooks + structured outputs + a small state file in `.harness/` give us the same semantics without LangGraph itself — but the model is the same.

## §7. Agent Client Protocol (ACP) [7]

ACP is the open standard (Zed Industries, 2025) for cross-agent communication: JSON-RPC 2.0 over stdin/stdout. Adopted by JetBrains, Google, GitHub, xAI Grok Build (native), and 25+ agents. Claude Code participates via a Zed-built bridge.

Rules:
- When Grok hands off to another agent on the same machine/process boundary, **prefer ACP** over ad-hoc bridges where both sides support it.
- The JSON handoff contract in `docs/handoff-contract.md` is the cross-process / cross-machine / over-time fallback.
- Do not invent new agent-to-agent transports. ACP or the contract — that is the menu.

## §8. AGENTS.md — the project context file for agents [8]

AGENTS.md is the open, vendor-neutral convention (stewarded by the Agentic AI Foundation under the Linux Foundation; adopted by OpenAI Codex, Amp, Jules, Cursor, Factory, xAI Grok Build) for project context aimed at coding agents — what README is to humans, AGENTS.md is to agents.

Rules:
- AGENTS.md lives at the **repo root**. Subprojects MAY ship their own AGENTS.md; the nearest file in the directory tree wins.
- Contents are **agent-binding**: build commands with exact flags, test procedures, code-style rules that differ from defaults, architectural constraints, files the agent must never touch.
- AGENTS.md does NOT replace `CLAUDE.md` — CLAUDE.md is Claude-Code-specific and carries the prime directive. AGENTS.md is the cross-tool surface (Grok Build, OpenAI Codex, Cursor, etc.).
- Where both files exist, they MUST agree. If they drift, this is an architecturally significant inconsistency — fix it via ADR.
- Empirically (124-PR controlled study): a good AGENTS.md cuts agent runtime ~29% and token use ~17%. Keep it tight, current, and accurate.

## §9. Task Decomposition Strategies [9]

How Grok turns a feature request into ordered tickets the inner loop can absorb:

- **Hierarchical decomposition** — top-level goal → top-level steps → recurse until each leaf is **atomic** (directly executable by one tool call or one inner-loop CL).
- **Atomic vs. composite** — atomic = leaf, executable, single tool/CL; composite = needs further decomposition. Grok never dispatches a composite ticket.
- **Few-shot decomposition** — for a recurring decomposition shape (e.g., "feature → tickets in this repo's convention"), provide 1–3 in-context examples to anchor style, granularity, and structure.
- **Decomposed Prompting (DecomP)** — formalize the decomposition itself as a sub-task; delegate sub-tasks to specialized handlers (one for research, one for ticket schema, one for file-scope inference).
- **Tree-of-Thoughts** when the decomposition has branching alternatives — explore multiple decomposition paths, pick the one with the best evaluator score.
- **Single-prompt failure mode** — the cardinal sin is asking one prompt to do research + decomposition + dispatch in one shot. Each gets its own prompt, its own model setting, its own structured output.

## §10. Parallel Sub-Agents in Git Worktrees [10]

Grok Build's "up to 8 parallel sub-agents, each in its own worktree" is the operational pattern; the literature backs it.

- **Pre-decomposition prevents conflicts.** Before any sub-agent starts, the orchestrator maps which files each sub-agent will touch. Overlap is reworked into a serial schedule, not papered over.
- **Decompose by feature/domain boundary**, not by random task split. Splitting work that touches the same files from different directions is the predictable failure mode.
- **One sub-agent → one worktree → one branch → one PR.** No multi-purpose branches.
- **Merge is sequential.** Merge one worktree at a time into the integration branch; resolve conflicts; run tests; only then merge the next.
- For larger fleets (>8): integrate via a staging branch — merge all feature branches there first, run full tests, fix conflicts, then merge the clean result to main.
- Benchmarks: well-decomposed worktree parallelism cuts total build time ~63%.

## §11. The Self-Healing Agent Pattern [11]

The four-phase loop every long-running Grok monitor in this repo MUST implement:

1. **Detect** — telemetry from the system (failing tests, debt thresholds, coverage drop, error rate spike) reaches a defined threshold.
2. **Diagnose** — Grok reasons about root cause. No retry without diagnosis. Diagnosis output is structured and persisted.
3. **Heal** — pick a recovery strategy: `retry with refreshed context` / `simplify the task` / `dispatch inner-loop refactor` / `escalate to human`. Execute via the standard dispatch path (the handoff contract), not a side channel.
4. **Verify** — re-run the telemetry that triggered the cycle. If the trigger condition is no longer met, close the loop; if it persists, escalate or change strategy. **A "heal" without a "verify" is a hope, not a fix.**

Layered architecturally: **observability layer** (collects telemetry) → **analysis layer** (anomaly detection + Grok diagnosis) → **action layer** (dispatch + execute) → **learning layer** (refines the threshold/strategy from the outcome).

Monitoring alone is not self-healing. Self-healing requires the action layer to be closed-loop and the verify step to be enforced.

## §12. Human-in-the-Loop Approval Gates [12]

HITL is the production safety mechanism for non-reversible actions. The rule is: **bounded autonomy for safe operations; mandatory gate for high-risk ones.**

- **Synchronous gate required** for: deploys, rollbacks, schema migrations, secret rotations, data deletion, any external-state mutation, any spend over a stated threshold.
- **Asynchronous gate (post-hoc review) acceptable** for: read-only research, ticket drafting, comment posting on internal channels, low-risk reversible changes.
- **Plan-mode-first**: for any non-trivial work, Grok emits a numbered plan and pauses for `approve | edit | discard` before execution. The plan IS the gate.
- **Escalation triggers** — out-of-bounds scenarios (cost overrun, unexpected dependency, ambiguous instruction) MUST escalate, not improvise.
- **Policy-as-code** — pre-authorized action buckets ("Grok may roll-forward deploys to staging without a gate") are explicit and version-controlled. No silent default permissions.

## §13. Reasoning Effort Tuning [13]

Grok's reasoning effort knob is real spend with real latency. Match the tier to the task:

| Tier   | Use for                                                                                  | Avoid for                                            |
| ------ | ---------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| none   | Pure formatting / passthrough where reasoning adds nothing                               | Anything with branching logic                        |
| low    | Routine routing, status emission, tool dispatch with one obvious choice                  | Multi-step planning, ambiguous classification        |
| medium | Default for ticket drafting, ordinary decomposition, dispatch synthesis                  | Cheap calls that don't need it                       |
| high   | Architecture decomposition, novel feature breakdown, self-healing diagnosis              | Latency-sensitive UI/chat paths (5–60× TTFT inflation) |

Deep Search is reserved for **genuinely novel external research** (a new dependency, an unfamiliar regulatory regime, a market signal). It is not a default lookup — local context first, RAG second, Deep Search third.

## §14. Headless `-p` Mode — CI/CD Integration [14]

The harness is built on the assumption that Grok runs headless. Rules:

- Auth via `XAI_API_KEY` env var only. No interactive sign-in on the critical path. CI runners, remote containers, GitHub Actions all use the env variable.
- One prompt per `-p` invocation. The prompt is fully self-contained — system prompt + context + task — because Grok is stateless across invocations.
- Output is **structured** (JSON via Structured Outputs). Downstream parsers do not regex over free-form text.
- Exit codes are meaningful: 0 = success-with-structured-output; non-zero = failure with diagnosable stderr.
- Hooks emit audit-trail entries on `pre-run`, `post-run`, `error`. The audit trail is the operator's view into what Grok did.
- The headless invocation is the **contract surface for automation**. Anything that depends on TUI-only behavior is non-portable and out of contract.

---

## §15. Synthesized rules this repo enforces (Grok-specific)

These are the operational rules for Grok orchestration in this repo. Numbered `G-N` to keep them distinct from the architectural rules (`R-N`) in `architecture-principles.md`. Every change that touches `.grok/`, AGENTS.md, the handoff layer, or any Grok-facing config is checked against this list.

| Rule  | Statement                                                                                                                                                              | Source |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| G-1   | **Outer loop only.** Grok never edits files inside acceptance-tested scope. All such edits dispatch through the handoff contract.                                      | §1, §4 |
| G-2   | **Headless-first.** Every Grok invocation MUST work in `-p` mode with `XAI_API_KEY` env-var auth. Interactive features may be added; the headless path is the contract. | §1, §14 |
| G-3   | **Structured output.** Any Grok output that flows into another system (handoff, dispatch, status, monitor) uses xAI Structured Outputs (JSON Schema). Never free-form text. | §2, §14 |
| G-4   | **Tuned reasoning effort.** Routine routing/status uses `low`; ticket drafting and ordinary decomposition use `medium`; architecture decomposition and self-healing diagnosis use `high`. Match by latency budget, not capability ceiling. | §2, §13 |
| G-5   | **Cache-stable system prompts.** System prompts, contract templates, and policy blocks are structured to be byte-identical across requests so prompt caching applies. | §2 |
| G-6   | **One ticket = one handoff document.** No batched dispatch. One JSON request file, one JSON response file, per ticket. (Reinforces handoff-contract.md.)                | §1, §4 |
| G-7   | **Orchestrator-Worker.** Grok is the orchestrator; Claude TDD Pro instances are workers. Synthesis happens in Grok. The orchestrator does not drift into worker territory. | §3, §4 |
| G-8   | **Parallel via git worktrees.** Sub-agents dispatched in parallel each get their own git worktree, branch, and PR. Decomposition is along file/feature boundaries to minimize file overlap. | §1, §10 |
| G-9   | **Bounded fan-out.** No supervisor (Grok or sub-orchestrator) manages more than 8 active workers at once. Beyond 8, introduce a mid-level supervisor. Keep the tree shallow. | §5, §1 |
| G-10  | **AGENTS.md is normative.** AGENTS.md lives at the repo root; it is the cross-tool agent context surface. CLAUDE.md remains the Claude-Code prime-directive carrier. Where both exist, they MUST agree. | §8 |
| G-11  | **ACP for agent-to-agent on the same boundary; handoff contract otherwise.** Do not invent new agent-to-agent transports.                                              | §7 |
| G-12  | **Plan-first for non-trivial work.** Grok emits a numbered plan and pauses for `approve / edit / discard` before any non-reversible action, unless that action is in a pre-authorized policy bucket. | §1, §12 |
| G-13  | **HITL gates on production-impacting actions.** Deploys, rollbacks, schema migrations, secret rotations, data deletion, any external-state mutation, and any spend over the stated threshold require explicit human approval. | §12 |
| G-14  | **Self-healing follows Detect → Diagnose → Heal → Verify.** Every long-running Grok monitor implements all four phases. No retry without diagnosis. No "heal" without a follow-up "verify." | §11 |
| G-15  | **Observability is non-optional.** Every Grok run emits structured logs: `run-id`, `prompt-hash`, tool calls + arguments, token cost, decisions, dispatch IDs. Persisted for the audit trail. | §6, §11 |
| G-16  | **Atomic tickets.** Every ticket Grok dispatches is sized to one CL, with concrete acceptance criteria and a `file_scope`. Composite tickets are decomposed further before dispatch. | §9 |
| G-17  | **Research belongs to the outer loop.** Grok performs all research with provenance; the handoff carries `research_refs`. The inner loop does not re-research and rejects requests past `context_ttl_seconds`. | §1, §13 |
| G-18  | **Evaluator-Optimizer for self-healing refactor.** Grok proposes → Claude TDD Pro implements → Grok evaluates against the debt metric → loop until threshold clears or escalation triggers. | §3, §11 |
| G-19  | **Idempotent dispatch.** Re-running a Grok prompt with the same context produces an equivalent handoff or detects an existing one. Never duplicates a dispatch.        | §6, §11 |
| G-20  | **Explicit model escalation.** If a faster/cheaper model (Grok 4 Fast / Grok Code Fast) fails to produce valid structured output or returns low confidence, escalate to a stronger model with a recorded reason. No silent escalation. | §2 |
| G-21  | **Tolerant reader on agent output.** Consumers of Grok output (handoff validator, dispatcher, monitor) ignore unknown fields, default missing optional fields, and fail loudly only on missing required fields. Reinforces architectural rule R-11 for this surface. | §2, architecture-principles §10 |

---

## §16. Self-audit checklist (Grok-orchestration changes)

A change is in contract if every answer is YES. Run alongside the cross-cutting checklist in `architecture-principles.md` §17.

- [ ] Is Grok kept strictly in the outer loop — research, decomposition, dispatch, monitoring, deploy — with all in-scope code edits dispatched through the handoff contract? (G-1, G-7)
- [ ] Does the change preserve a fully headless `-p` execution path with env-var auth? (G-2, G-14)
- [ ] Is every Grok-produced output that crosses a process/system boundary a Structured Output (JSON Schema), not free-form text? (G-3)
- [ ] Is reasoning effort matched to the task class (low / medium / high) rather than defaulted to max? (G-4, G-13)
- [ ] Are system prompts and contract templates kept stable across calls to maximize prompt caching? (G-5)
- [ ] Is the dispatch unit one ticket per handoff document — never a batched or streamed dispatch? (G-6)
- [ ] Is fan-out per supervisor capped at ≤8 workers, with mid-level supervisors introduced beyond that? (G-9)
- [ ] If sub-agents run in parallel, does each get its own git worktree and branch, with the decomposition mapped along file boundaries to prevent overlap? (G-8)
- [ ] Is AGENTS.md present at the repo root, current, and consistent with CLAUDE.md? (G-10)
- [ ] Is agent-to-agent communication via ACP (same-boundary) or the JSON handoff contract (cross-boundary) — and not via an ad-hoc bridge? (G-11)
- [ ] Does any non-reversible / production-impacting action sit behind plan-mode + an explicit HITL gate (or a documented pre-authorized policy bucket)? (G-12, G-13)
- [ ] If this change adds or modifies a long-running monitor, does it implement all four phases — Detect, Diagnose, Heal, Verify — with no shortcut? (G-14)
- [ ] Does the run emit a complete structured audit-trail entry (run-id, prompt-hash, tool calls, token cost, decisions, dispatch IDs)? (G-15)
- [ ] Are dispatched tickets atomic (one CL, concrete acceptance criteria, explicit `file_scope`), and is composite work decomposed further before dispatch? (G-16)
- [ ] Is all research performed by the outer loop and passed via `research_refs`, with `context_ttl_seconds` honored on the inner side? (G-17)
- [ ] If the change uses self-healing refactor, is it shaped as Evaluator-Optimizer with explicit termination conditions? (G-18)
- [ ] Are dispatch primitives idempotent — same context produces equivalent handoff, never a duplicate? (G-19)
- [ ] Is model selection / escalation explicit and recorded, never silently upgraded? (G-20)
- [ ] Do downstream consumers of Grok output read tolerantly (ignore unknown, default missing optional, fail loudly only on missing required)? (G-21)

---

## §17. Authoritative sources

[1] xAI. *Introducing Grok Build.* https://x.ai/news/grok-build-cli  ·  Coverage of the launch (sub-agents, plan mode, ACP, AGENTS.md detection): https://kingy.ai/ai/xai-drops-grok-build-an-agentic-cli-that-wants-to-live-in-your-terminal/ , https://www.digitalapplied.com/blog/xai-grok-build-cli-parallel-coding-agents
[2] xAI Docs. *Overview, Structured Outputs, Multi-turn Conversations.* https://docs.x.ai/overview , https://docs.x.ai/developers/model-capabilities/text/structured-outputs , https://docs.x.ai/cookbook/examples/multi_turn_conversation  ·  *Grok 3 — The Age of Reasoning Agents.* https://x.ai/news/grok-3
[3] Anthropic. *Building Effective Agents.* https://www.anthropic.com/research/building-effective-agents  ·  *Building Effective AI Agents (resources).* https://resources.anthropic.com/building-effective-ai-agents  ·  Cookbook: https://github.com/anthropics/anthropic-cookbook/blob/main/patterns/agents/orchestrator_workers.ipynb
[4] Orchestrator-Worker canonical descriptions: https://www.augmentcode.com/guides/multi-agent-orchestration-architecture-guide , https://build5nines.com/6-multi-agent-orchestration-design-patterns-every-developer-should-know/
[5] Hierarchical multi-agent orchestration: https://gurusup.com/blog/agent-orchestration-patterns , https://www.softwareseni.com/understanding-orchestration-patterns-for-multi-agent-systems-and-how-they-affect-performance-coordination-and-reliability/
[6] LangGraph. *Multi-Agent Supervisor & Production Patterns.* https://www.langchain.com/langgraph , https://reference.langchain.com/python/langgraph-supervisor , https://www.alphabold.com/langgraph-agents-in-production/
[7] Zed Industries. *Agent Client Protocol.* https://zed.dev/acp  ·  ACP introduction: https://blog.marcnuri.com/agent-client-protocol-acp-introduction  ·  ACP vs MCP, editor support: https://www.morphllm.com/agent-client-protocol
[8] AGENTS.md Specification. https://agents.md/  ·  https://github.com/agentsmd/agents.md  ·  OpenAI Codex on AGENTS.md: https://developers.openai.com/codex/guides/agents-md  ·  Research-backed guide: https://asdlc.io/practices/agents-md-spec/
[9] Task decomposition for LLM agents: https://apxml.com/courses/agentic-llm-memory-architectures/chapter-4-complex-planning-tool-integration/task-decomposition-strategies , https://mbrenndoerfer.com/writing/planning-task-decomposition-goal-directed-llm-agents  ·  Decomposed Prompting (DecomP): https://learnprompting.org/docs/advanced/decomposition/decomp
[10] Git worktrees for parallel AI agents: https://developer.upsun.com/posts/ai/git-worktrees-for-parallel-ai-coding-agents , https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution , https://zylos.ai/research/2026-02-22-git-worktree-parallel-ai-development
[11] Self-healing agent pattern: https://dev.to/the_bookmaster/the-self-healing-agent-pattern-how-to-build-ai-systems-that-recover-from-failure-automatically-3945 , https://claudelab.net/en/articles/api-sdk/claude-api-self-healing-agent-production-patterns , https://impalaintech.com/blog/self-healing-software-systems/  ·  Academic background: https://arxiv.org/pdf/2504.20093
[12] Human-in-the-loop approval frameworks: https://agentic-patterns.com/patterns/human-in-loop-approval-framework/ , https://galileo.ai/blog/human-in-the-loop-agent-oversight , https://towardsdatascience.com/building-human-in-the-loop-agentic-workflows/
[13] Reasoning effort tuning and Grok model selection: https://www.digitalapplied.com/blog/reasoning-effort-cost-vs-quality-benchmarks-2026 , https://x.ai/news/grok-4-fast , https://artificialanalysis.ai/models/grok-4-fast-reasoning
[14] Grok Build headless `-p` mode and CI integration: https://codersera.com/blog/how-to-install-grok-build-cli-2026/ , https://byteiota.com/grok-build-xai-cli-coding-agent/

---

## §18. Amendments

Rules above are immutable in spirit. To revise a rule:

1. Open an ADR in `docs/adr/` (per `architecture-principles.md` §15) that proposes the change, in Nygard format, status `Proposed`.
2. On acceptance, append an entry to this section noting the date, ADR ID, and rules amended.
3. Update the affected rule rows in §15 in the same commit, with a footnote pointing to the ADR.
4. Do not delete prior rule text; if a rule is superseded, mark it `Superseded by ADR-NNNN` rather than removing it.

*(No amendments yet.)*
