# Founder Directives — grok-claude-tdd-pro

This document is the operational rulebook for grok-claude-tdd-pro's response to **founder-level directives** — named-source statements from xAI leadership, Anthropic leadership, and figures elevated by the architecture team for their direction-setting authority on AI-assisted software engineering. The scope was broadened from the original two X posts to include publicly available statements from Elon Musk and his companies' (and ex-employees') publications, and from Anthropic's publications on Claude Code and AI engineering, per user instruction on 2026-05-25.

Where `docs/architecture-principles.md`, `docs/grok-orchestration-principles.md`, and `docs/claude-tdd-pro-principles.md` synthesize twenty-plus canonical sources into numbered rules, this document elevates a small set of explicit, named-source directives to override default behaviors. The other rulebooks are inferred guardrails; the directives in this document are explicit instructions from the leadership voices steering the platforms this harness depends on.

Authority tier: **TIER 1**, co-equal with the prime directive in `CLAUDE.md`. See §5 for ordering with the R- / G- / C- rulebooks.

## §1 Provenance (immutable, append-only)

Entries in this section are immutable historical record. They are never edited, retired, or removed — even for typos in the original source. Interpretation lives in §3 (which IS amendable via ADR); the source text stays verbatim.

### Source 1 — @teslayoda (X, 2026-05-24, ~38 min before Source 2)

> Grok Build should watch and learn from Claude Code and Cursor inside Marcohard.

Engagement metrics at capture time: 4 replies, 1 repost, 24 likes, 1.4K views. Captured via screenshot, elevated to repo-canonical directive by drumfiend21 on 2026-05-25.

### Source 2 — @elonmusk (X, 2026-05-24, 8:59 PM)

> The key is just closing the loop on solving progressively harder problems, which we have plenty of at my companies

Posted as a reply to Source 1. Engagement metrics at capture time: 944 views. Captured via screenshot, elevated to repo-canonical directive by drumfiend21 on 2026-05-25.

---

#### Verification tiers used in §1

Each §1 entry carries a **Verification** field declaring how the source text was obtained at capture time. Entries are never edited; if a higher-verification tier becomes available later, a new ADR records the upgrade (e.g., upgrading a snippet-verified entry to direct-primary by re-fetch from the primary URL once network access permits) and a footnote here points to it. Tiers, ordered strongest to weakest:

- **T-A — Direct primary**: text fetched from the primary URL within the capture session and quoted verbatim.
- **T-B — Screenshot of primary**: text transcribed from a user-supplied screenshot of the primary source (Sources 1 and 2 are T-B).
- **T-C — Search-engine-indexed extract**: text appearing inside quotation marks in one or more search-engine result snippets indexed from the primary URL; primary URL inaccessible at capture session (typically due to anti-bot 403). Sources 3, 4, 5, and 7 below are T-C.
- **T-D — Substantive paraphrase**: substance attested by multiple secondary sources, but exact verbatim wording not verified at capture; entry preserved for the substantive claim, deferred for verbatim upgrade. Source 6 below is T-D.

The Verification tier is itself part of the immutable record. A T-C or T-D entry stays at that tier in the historical record even after a T-A upgrade is added by ADR.

---

### Source 3 — Elon Musk, "The Algorithm" (5-step engineering algorithm; widely-reproduced interview, ~2021)

> First, make your requirements less dumb. Your requirements are definitely dumb… It's particularly dangerous if a smart person gave you the requirements because you might not question them enough.

The algorithm in full, attested across multiple secondary sources: (1) make your requirements less dumb; (2) try very hard to delete the part or process; (3) simplify or optimize; (4) accelerate cycle time; (5) automate. Musk's framing of step 3: "possibly the most common error of a smart engineer is to optimise a thing that should not exist." Musk's framing of step 1's underlying rule: question every requirement, and never accept that a requirement came from "a department" — track it to a named person and question it regardless of how smart that person is.

**Verification:** T-C. Primary fetch returned 403 in capture session. Verbatim fragment above sourced from @StartupArchive_ X post (`x.com/StartupArchive_/status/1872625977672831146`) which reproduces a clip from the original Walter Isaacson interview era. Substance confirmed across modelthinkers.com, evannex.com, cleantechnica.com, insideevs.com, corporate-rebels.com.

**Capture date:** 2026-05-25. **Elevated by:** drumfiend21.

### Source 4 — xAI, "Introducing Grok Build" (xAI official announcement, x.ai/news/grok-build-cli, 2026-05-14)

> [Grok Build is] a powerful new coding agent and CLI for professional software engineering and complex coding work.

Additional verbatim phrasing recovered from the announcement (per consistent cross-source attribution): For complex tasks, users can start Grok Build in **plan mode** and "approve the plan, comment on individual steps, or rewrite it entirely before execution begins." For larger tasks, Grok Build "delegates work to specialized subagents that run in parallel" and "supports deep worktree integrations where you can launch subagents in their own worktrees." The CLI is positioned as providing "terminal-based planning, clean diffs, parallel subagents, worktree support, headless mode, and ACP support for professional software engineering and complex coding work."

**Verification:** T-C. Primary URL (`x.ai/news/grok-build-cli`) returned 403 in capture session. Verbatim phrases recovered from consistent attribution across multiple secondary sources covering the launch (Engadget, eweek, AlternativeTo, basenor, pasqualepillitteri, releasebot, webpronews, codersera, kingy.ai, beginnersinai), all citing the same xAI announcement page and dating it to 2026-05-14.

**Capture date:** 2026-05-25. **Elevated by:** drumfiend21.

### Source 5 — Erik Schluntz & Barry Zhang (Anthropic), "Building Effective Agents" (anthropic.com, 2024-12-19)

> The most successful LLM agent implementations weren't using complex frameworks or specialized libraries, but instead were building with simple, composable patterns.

The post draws a foundational distinction between **workflows** (systems where multiple LLMs are orchestrated together using pre-defined paths) and **agents** (systems where LLMs "dynamically direct their own processes and tool usage"). The five named composable patterns are: prompt chaining, routing, parallelization, orchestrator-workers, and evaluator-optimizer. The basic building block is "an LLM enhanced with augmentations such as retrieval, tools, and memory."

**Verification:** T-C. Primary URLs (`anthropic.com/research/building-effective-agents` and `anthropic.com/engineering/building-effective-agents`) returned 403 in capture session. Verbatim "simple, composable patterns" phrasing and the workflows/agents distinction recovered from indexed snippets across multiple secondary sources; both phrases are the central thesis of the post and appear with consistent wording.

**Capture date:** 2026-05-25. **Elevated by:** drumfiend21.

### Source 6 — Dario Amodei (Anthropic CEO), "Machines of Loving Grace" (darioamodei.com, October 2024)

Substantive claim (verbatim primary text deferred): AI is now writing much of the code at Anthropic, substantially accelerating the rate of progress in building the next generation of AI systems. Amodei has stated that the current generation of AI may be only 1–2 years from a point where it can autonomously build the next generation. The essay sketches a vision of AI-accelerated progress across coding, scientific research, and biological research, with the recurring frame that the *upside* of powerful AI is what humanity should be designing for, while the risks are not predetermined and can be shaped by action.

**Verification:** T-D. Primary URL (`darioamodei.com/essay/machines-of-loving-grace`) returned 403 in capture session. The substantive claim above is attested across multiple secondary sources (futureofbeinghuman.com, davidborish.com, madplay.github.io, EA Forum, LessWrong reproduction), but the exact verbatim wording differs across paraphrases and could not be reconciled to a single primary quote in this session. Entry preserved at T-D for the substantive claim; verbatim upgrade deferred to a future ADR when primary URL becomes accessible.

**Capture date:** 2026-05-25. **Elevated by:** drumfiend21.

### Source 7 — Andrej Karpathy (former Director of AI, Tesla; co-founder, OpenAI; independent voice on AI engineering), agentic engineering workflow shift (2026-01-26)

> Easily the biggest change to my basic coding workflow in 2 decades of programming, and it happened over the course of a few weeks.

> If the code really matters, you need to watch them like a hawk.

Karpathy's reported workflow ratio "flipped from 80-20 to 20-80" between November 2025 and December 2025 — meaning the ratio of code he wrote himself versus delegated to AI agents inverted in roughly one month. His characterization of agent errors: comparable to "a slightly careless and rushed junior developer" — models make incorrect assumptions, build solutions on them, fail to ask clarifying questions, miss contradictions, and over-complicate. He framed this shift as the inflection point of "Software 3.0," where developers increasingly direct, supervise, and edit agent output rather than write each line manually.

**Verification:** T-C. Primary post URL not recovered in this session (likely an X post and/or accompanying long-form). Verbatim "biggest change to my basic coding workflow in 2 decades" and "watch them like a hawk" phrasings recovered from indexed snippets across multiple secondary sources (devby.io, theaiopportunities.com, the-ai-corner.com, shiftmag.dev, travis.media, asatunews.co.id, nextbigfuture.com, miraflow.ai, aiagentssimplified.substack.com). Karpathy is included as an "ex-Tesla AI leadership voice" under the broadened scope of this rulebook; he is not currently a Musk-company employee.

**Capture date:** 2026-05-25. **Elevated by:** drumfiend21.

## §2 Scope

These directives apply to **every** session type (local CLI, remote, cloud, GitHub Action, IDE) and **every** component of the harness — this repo, the consumption pattern around the `claude-tdd-pro` plugin, the `.grok/` orchestration layer, the `.claude/` consumption layer, the handoff contract, all skills, all hooks, all sub-agents, all monitors.

They override default Claude behavior and any contradictory instruction not explicitly marked as superseding these directives. Amendments follow the ADR process in `docs/architecture-principles.md` §19 — never edit a D-rule in place, and never edit a §1 provenance entry under any circumstance.

## §3 Directives (D-1 .. D-12)

### D-1 — Grok-side orchestration is informed by Claude Code and Cursor enterprise deployment patterns.

The Grok-outer-loop in this harness is not invented from scratch. Before introducing a new Grok-side primitive — skill, prompt template, monitor, hook, headless invocation pattern, sub-agent dispatch shape — document the analogous Claude Code and/or Cursor primitive it draws from. The harness's job is to make Grok composable with the patterns observed in enterprise deployments of Claude Code and Cursor, not to reinvent orchestration in a vacuum.

**Source:** §1 / Source 1 (@teslayoda).

**Operational consequence:** Every PR introducing a new Grok-side primitive includes a "Drawn from" section in the description or in an accompanying ADR, citing (a) the Claude Code and/or Cursor analog, (b) the enterprise context in which that analog has been observed, and (c) the gap this primitive fills.

### D-2 — Enterprise-scale deployment patterns are the design target.

Where Claude Code and Cursor have visible deployment patterns at organizations of >1,000 ICs, those patterns are the design target for Grok-side equivalents in this harness. The dimensions that matter: audit trails, permission systems, multi-repo coordination, code review integration, MCP scope management, hook discipline, skill packaging, headless invocation, secrets handling, observability. Toy-scale ergonomics are nice; enterprise-scale survivability is the bar.

**Source:** §1 / Source 1 (@teslayoda, the "inside Marcohard" qualifier — preserved verbatim as a stand-in for "inside a large-enterprise deployment context").

**Operational consequence:** Before merging a CL, the author asks: "Would this survive being run by an IC at a 5,000-person engineering org with mandatory audit logging, per-repo permission scoping, and a Director-level approval gate on production changes?" If no, either fix it or file the gap as an ADR with a stated path to closing it.

### D-3 — Every loop in the harness has a defined terminal state.

The harness is a system of loops: outer (Grok research → decompose → dispatch → verify → deploy), inner (Claude Red-Green-Refactor), monitor (self-healing on debt thresholds), session (open → drift-check → work → commit). Every one of these loops has a **written, machine-checkable terminal condition**. "I think we're done" is never a terminal state. Acceptable terminal states: tests green + lint clean + lock file in sync + commit pushed + exit code 0; or, for human-gated loops, a written timeout / fallback / explicit-yield exit.

**Source:** §1 / Source 2 (@elonmusk, "closing the loop").

**Operational consequence:** Every loop introduced or modified in a CL points to a written terminal-condition definition — in code, in a doc, or in the commit message. Loops that wait for human review carry a written escape mechanism. Polling loops without termination conditions are forbidden.

### D-4 — Each CL attacks a problem strictly harder than the previous.

The harness is built CL by CL. Each subsequent CL must attack a problem **strictly harder** than the previous by at least one stated metric: code surface touched, integration boundaries crossed, latency budget, correctness invariants enforced, blast radius of failure, real-world traffic exposure. Polishing the same problem in two consecutive CLs is anti-pattern. If a polish CL is genuinely required (correctness regression, missed acceptance criterion), it is split out as a maintenance ticket and labeled as such — not slipped in as forward progress.

**Source:** §1 / Source 2 (@elonmusk, "progressively harder problems").

**Operational consequence:** Each commit message states the difficulty metric and how this CL is harder than the previous. If the author cannot articulate the difficulty delta, the CL is either premature (previous loop not actually closed — see D-3) or unnecessary (no progress on the difficulty axis — defer or merge into a later, real CL).

### D-5 — Production-grade problem instances are the work; toy examples are scaffolding only.

The `examples/` toy module (cf. TICKET-005) exists to validate the first full turn of the inner loop end-to-end. Once that validation is complete, the work pivots — permanently — to production-grade problem instances. The harness's value is proven on real problems at real organizations, not on indefinite refinements of the toy. Falling back to the toy as a comfort zone is a tell that D-4 isn't being honored.

**Source:** §1 / Source 2 (@elonmusk, "which we have plenty of at my companies").

**Operational consequence:** No CL after TICKET-005 lands purely against the toy module. Once the toy validates the loop, every subsequent CL targets a real ticket, a real repo, a real org. If the loop breaks on a real problem, the fix lands against the real problem; reverting to the toy as a workaround is forbidden without an ADR documenting why.

### D-6 — Directives have full provenance and §1 entries are immutable.

The provenance entries in §1 are append-only and never edited. The interpretive D-rules in §3 are amendable via ADR — but §1 stays intact even when D-rules are revised, superseded, or retired. This means future maintainers can always re-interpret the source directly rather than inheriting a stale interpretation. Typos in the original source (e.g., "Marcohard") are preserved verbatim; if disambiguation is needed, it lands as a footnote on the relevant §3 entry, never as an edit to §1.

**Source:** Meta-rule for this document.

**Operational consequence:** §1 is append-only. New §1 entries land via ADR (with the source cited: author, date, URL or screenshot reference). An entry is never edited or removed. If a §3 D-rule's interpretation changes, the change lands as an ADR that either amends the D-rule or supersedes it with a new one, cross-referencing the original.

### D-7 — Directives are referenced from `CLAUDE.md` and apply to every session type.

The prime directive in `CLAUDE.md` (the plugin-dependency model) is one TIER-1 authority. This document is the other. `CLAUDE.md` MUST contain a top-level reference to this document under "Authoritative founder-directives rulebook," structurally parallel to the references to the R-/G-/C- rulebooks, so every session opens with these rules loaded into context.

**Source:** User instruction (2026-05-25) elevating the §1 X posts to repo-canonical rulebook status.

**Operational consequence:** If `grep -l founder-directives CLAUDE.md` returns nothing, this rulebook is offline and any session is operating outside its authority. The fix is structural (re-wire `CLAUDE.md`), not procedural.

### D-8 — Apply Musk's Algorithm: question requirements, delete before optimizing.

The five steps of Musk's Algorithm (in order, non-skippable): (1) make your requirements less dumb — track every requirement to a *named person*, never accept "a department made it," and question it regardless of how smart that person is; (2) try very hard to delete the part or process — if you are not adding things back ~10% of the time, you are not deleting enough; (3) simplify and optimize, but only after step 2 (the most common error of a smart engineer is to optimize a thing that should not exist); (4) accelerate cycle time; (5) automate, and only then. Applies to every architectural decision, every feature, every line of harness substrate.

**Source:** §1 / Source 3 (Elon Musk, "The Algorithm").

**Operational consequence:** Every CL that introduces new harness substrate (a new directory, a new doc, a new skill, a new monitor, a new gate) is preceded by an explicit deletion pass: "what could I remove from the existing harness that this CL would otherwise accumulate alongside?" If nothing can be removed, document why in the commit body. Premature optimization in the harness (caching layers, abstraction wrappers, generic plug-points) is forbidden until the thing being optimized has survived a deletion attempt.

### D-9 — Choose simple, composable patterns over complex frameworks.

The successful pattern for building agentic systems is **simple, composable patterns**, not heavyweight frameworks. Distinguish carefully between **workflows** (LLMs orchestrated through pre-defined paths — predictable, structured, auditable) and **agents** (LLMs that dynamically direct their own processes and tool usage — open-ended, expensive, harder to bound). Use the simplest pattern that fits the problem. Reach for prompt chaining, routing, parallelization, orchestrator-workers, or evaluator-optimizer before reaching for a bespoke agent loop.

**Source:** §1 / Source 5 (Schluntz & Zhang, Anthropic, "Building Effective Agents").

**Operational consequence:** When designing a new outer- or inner-loop component, document which named pattern from the Schluntz/Zhang taxonomy it instantiates. If the component is "an agent" (dynamic self-direction), document why a workflow won't suffice — bias toward workflow. Custom frameworks built atop primitive HTTP/SDK calls are forbidden without an ADR justifying the framework's existence.

### D-10 — TDD is the strongest pattern for agentic coding; supervision is required when the code matters.

Test-driven development is the single strongest pattern for working with agentic coding tools — each red-to-green cycle gives the agent unambiguous feedback and lets it iterate without human intervention. The recipe: give the agent (a) tests, (b) clear constraints, (c) a structured `CLAUDE.md` (and equivalents for other agents), then let the loop run. Simultaneously: agents make junior-developer-class mistakes — incorrect assumptions, unasked clarifying questions, missed contradictions, over-complication. When the code matters, supervise; do not conflate agent fluency with agent correctness.

**Source:** §1 / Source 5 (Anthropic Claude Code best practices via search-engine attribution) and §1 / Source 7 (Karpathy, "watch them like a hawk"). Reinforces and binds together the C-rulebook (`docs/claude-tdd-pro-principles.md`) within the founder-directives tier.

**Operational consequence:** No CL inside acceptance-tested scope lands without a red-then-green test cycle visible in the commit history (or referenced from it). Agent-authored code on a critical path (failure mode that affects users, data, or production traffic) is paired with explicit reviewer sign-off — human reviewer named in the commit body, not implied. If the loop runs without supervision on critical-path code, the CL is non-compliant regardless of test results.

### D-11 — Design FOR the agent-CLI primitives, not AROUND them.

The frontier coding CLIs (Grok Build, Claude Code) expose a common primitive set: **plan mode** (approve / comment / rewrite before execution), **clean diffs** (every change as reviewable atomic units), **parallel sub-agents** (delegation to specialized workers), **worktree integration** (isolated parallel work), **headless mode** (`-p` / scriptable invocation), and **ACP support** (Agent Client Protocol cross-tool interop). These primitives ARE the inner-loop interface this harness consumes. Design new harness features to use them; never re-implement them; never bypass them.

**Source:** §1 / Source 4 (xAI Grok Build announcement). Aligns with `docs/grok-orchestration-principles.md` (G-rules) and `docs/claude-tdd-pro-principles.md` (C-rules) inside the TIER-1 directive frame.

**Operational consequence:** Any new harness primitive must declare which agent-CLI primitive(s) it composes on top of. If a proposed primitive would re-implement plan / diff / sub-agent / worktree / headless / ACP behavior locally, the CL is non-compliant — the agent CLI's native primitive is the implementation, the harness is the composer.

### D-12 — AI is already writing much of the code; the harness's value is making that output production-grade.

Frontier AI labs (per Source 6) report that AI is now writing much of their own code, substantially accelerating the rate of progress on the next generation of AI systems. The expected near-future trajectory (1–2 years) is autonomous next-generation construction by current-generation systems. The implication for this harness: the harness's value is *not* substituting for AI-authored code generation. It is making that AI-authored output **production-grade, auditable, and survivable at enterprise scale** — exactly the gaps D-1 and D-2 already flag. Code generation is no longer the bottleneck; trustable production deployment of generated code is.

**Source:** §1 / Source 6 (Amodei, "Machines of Loving Grace"). Substance-paraphrase tier (T-D) — verbatim primary upgrade deferred.

**Operational consequence:** Harness CLs that aim to "help generate code faster" are mis-prioritized — that problem is already being solved by the agent CLIs themselves. CLs that aim to make generated code reviewable, auditable, testable, rollback-able, permission-scoped, and contract-honoring are on-mission. When in doubt about a proposed CL's priority, ask: "Does this make AI-generated code more trustworthy in a production context, or does it make AI-generated code easier to generate?" The former is harness work; the latter is agent-CLI work.

## §4 Self-audit checklist (pre-commit)

Before every commit, the author — human or agent — confirms:

- [ ] (D-1) If a new Grok-side primitive was added, its Claude Code and/or Cursor analog is documented in the PR description or an accompanying ADR.
- [ ] (D-2) The change is sane for a >1,000-IC enterprise deployment context, or its gap is filed as an ADR with a stated path to closing it.
- [ ] (D-3) Every loop touched by the change has a written, machine-checkable terminal condition.
- [ ] (D-4) The commit message states the difficulty metric and how this CL is strictly harder than the previous.
- [ ] (D-5) If post-TICKET-005, the change targets a real (non-toy) problem instance.
- [ ] (D-6) §1 of this document remains untouched. New §1 entries (if any) landed via ADR.
- [ ] (D-7) `CLAUDE.md` still references this document under "Authoritative founder-directives rulebook."
- [ ] (D-8) If the CL adds new substrate, the deletion-pass question is asked and answered in the commit body.
- [ ] (D-9) Any new agentic-systems component declares the simple, composable pattern it instantiates (or justifies why a custom design is required).
- [ ] (D-10) Code inside acceptance-tested scope has a red→green cycle visible in history; agent-authored code on critical paths has a named human reviewer.
- [ ] (D-11) New harness features declare which agent-CLI primitive(s) they compose on top of; nothing re-implements plan / diff / sub-agent / worktree / headless / ACP.
- [ ] (D-12) The CL is positioned on the "production-grade trust" side of the line, not the "faster generation" side, or its rationale is documented.

## §5 Authority tier and rule-ordering

When D-rules conflict with rules in the other rulebooks, this is the ordering:

| Tier | Rulebook | Scope |
|---|---|---|
| 1 | `CLAUDE.md` prime directive (plugin-dependency model) | Repo-wide; non-negotiable. |
| 1 | This document (founder directives, D-1 .. D-7) | Repo-wide; co-equal with the prime directive. |
| 2 | `docs/architecture-principles.md` (R-1 .. R-20) | Architectural design and code structure. |
| 2 | `docs/grok-orchestration-principles.md` (G-1 .. G-21) | `.grok/` and all Grok-facing surfaces. |
| 2 | `docs/claude-tdd-pro-principles.md` (C-1 .. C-24) | Acceptance-tested inner-loop work. |

When a D-rule and an R- / G- / C- rule conflict, the D-rule wins. Raise the conflict in the CL (or before, via clarification) rather than silently relaxing either. When the two TIER-1 authorities conflict, raise it explicitly — neither defers to the other by default.

## §6 Amendment process

Amendments follow the ADR process documented in `docs/architecture-principles.md` §19:

1. Open an ADR in `docs/adr/000N-*.md` proposing the amendment.
2. The ADR cites the relevant §1 source. If the amendment requires a new §1 entry, the ADR includes the source text verbatim, with attribution (author, date, capture method — URL or screenshot reference).
3. The amendment merges with the ADR in a single CL.
4. The §3 D-rule is updated (or a new D-rule appended); §1 provenance entries are never edited.

Never edit a D-rule in place without an ADR. Never edit a §1 entry, ever — even to fix a typo. The whole point of the immutable §1 layer is that future maintainers can re-interpret from the original, not inherit a stale (or sanitized) reading of it.
