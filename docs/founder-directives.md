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

### Source 8 — Anthropic, "Best practices for Claude Code" (code.claude.com/docs, accessed 2026-05-25)

**Verification:** T-A (direct primary, supplied verbatim by drumfiend21 on 2026-05-25 from the official Anthropic docs site at `code.claude.com/docs/...`). Primary URL not directly fetched from this session (WebFetch 403 wall), but the full text was supplied by the user from a direct read of the primary; this is the strongest verification tier in the model and serves as the canonical T-A example for future entries.

**Capture date:** 2026-05-25. **Elevated by:** drumfiend21.

**Transcription note:** The article's heading levels are demoted by two levels relative to the original (the article's `#` title becomes `###` as part of this Source heading metadata, the article's `##` section headings become `####`, the article's `###` subsection headings become `#####`, etc.) so the article nests cleanly under §1 without colliding with the rulebook's `##`-level section structure. All other content — prose, tables, code blocks, MDX components (`<Tip>`, `<Steps>`, `<Step>`, `<Callout>`, `<Warning>`), hyperlinks, list items — is preserved verbatim. The demarcation between the rulebook's own commentary and the verbatim article text is the horizontal rule (`---`) below.

---

> #### Documentation Index
> Fetch the complete documentation index at: https://code.claude.com/docs/llms.txt
> Use this file to discover all available pages before exploring further.

#### Best practices for Claude Code

> Tips and patterns for getting the most out of Claude Code, from configuring your environment to scaling across parallel sessions.

Claude Code is an agentic coding environment. Unlike a chatbot that answers questions and waits, Claude Code can read your files, run commands, make changes, and autonomously work through problems while you watch, redirect, or step away entirely.

This changes how you work. Instead of writing code yourself and asking Claude to review it, you describe what you want and Claude figures out how to build it. Claude explores, plans, and implements.

But this autonomy still comes with a learning curve. Claude works within certain constraints you need to understand.

This guide covers patterns that have proven effective across Anthropic's internal teams and for engineers using Claude Code across various codebases, languages, and environments. For how the agentic loop works under the hood, see [How Claude Code works](/en/how-claude-code-works).

***

Most best practices are based on one constraint: Claude's context window fills up fast, and performance degrades as it fills.

Claude's context window holds your entire conversation, including every message, every file Claude reads, and every command output. However, this can fill up fast. A single debugging session or codebase exploration might generate and consume tens of thousands of tokens.

This matters since LLM performance degrades as context fills. When the context window is getting full, Claude may start "forgetting" earlier instructions or making more mistakes. The context window is the most important resource to manage. To see how a session fills up in practice, [watch an interactive walkthrough](/en/context-window) of what loads at startup and what each file read costs. Track context usage continuously with a [custom status line](/en/statusline), and see [Reduce token usage](/en/costs#reduce-token-usage) for strategies on reducing token usage.

***

#### Give Claude a way to verify its work

<Tip>
  Include tests, screenshots, or expected outputs so Claude can check itself. This is the single highest-leverage thing you can do.
</Tip>

Claude performs dramatically better when it can verify its own work, like run tests, compare screenshots, and validate outputs.

Without clear success criteria, it might produce something that looks right but actually doesn't work. You become the only feedback loop, and every mistake requires your attention.

| Strategy                              | Before                                                  | After                                                                                                                                                                                                   |
| ------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Provide verification criteria**     | *"implement a function that validates email addresses"* | *"write a validateEmail function. example test cases: [user@example.com](mailto:user@example.com) is true, invalid is false, [user@.com](mailto:user@.com) is false. run the tests after implementing"* |
| **Verify UI changes visually**        | *"make the dashboard look better"*                      | *"\[paste screenshot] implement this design. take a screenshot of the result and compare it to the original. list differences and fix them"*                                                            |
| **Address root causes, not symptoms** | *"the build is failing"*                                | *"the build fails with this error: \[paste error]. fix it and verify the build succeeds. address the root cause, don't suppress the error"*                                                             |

UI changes can be verified using the [Claude in Chrome extension](/en/chrome). It opens new tabs in your browser, tests the UI, and iterates until the code works.

Your verification can also be a test suite, a linter, or a Bash command that checks output. Invest in making your verification rock-solid.

***

#### Explore first, then plan, then code

<Tip>
  Separate research and planning from implementation to avoid solving the wrong problem.
</Tip>

Letting Claude jump straight to coding can produce code that solves the wrong problem. Use [plan mode](/en/permission-modes#analyze-before-you-edit-with-plan-mode) to separate exploration from execution.

The recommended workflow has four phases:

<Steps>
  <Step title="Explore">
    Enter plan mode. Claude reads files and answers questions without making changes.

    ```txt claude (plan mode) theme={null}
    read /src/auth and understand how we handle sessions and login.
    also look at how we manage environment variables for secrets.
    ```
  </Step>

  <Step title="Plan">
    Ask Claude to create a detailed implementation plan.

    ```txt claude (plan mode) theme={null}
    I want to add Google OAuth. What files need to change?
    What's the session flow? Create a plan.
    ```

    Press `Ctrl+G` to open the plan in your text editor for direct editing before Claude proceeds.
  </Step>

  <Step title="Implement">
    Switch out of plan mode and let Claude code, verifying against its plan.

    ```txt claude (default mode) theme={null}
    implement the OAuth flow from your plan. write tests for the
    callback handler, run the test suite and fix any failures.
    ```
  </Step>

  <Step title="Commit">
    Ask Claude to commit with a descriptive message and create a PR.

    ```txt claude (default mode) theme={null}
    commit with a descriptive message and open a PR
    ```
  </Step>
</Steps>

<Callout>
  Plan mode is useful, but also adds overhead.

  For tasks where the scope is clear and the fix is small (like fixing a typo, adding a log line, or renaming a variable) ask Claude to do it directly.

  Planning is most useful when you're uncertain about the approach, when the change modifies multiple files, or when you're unfamiliar with the code being modified. If you could describe the diff in one sentence, skip the plan.
</Callout>

***

#### Provide specific context in your prompts

<Tip>
  The more precise your instructions, the fewer corrections you'll need.
</Tip>

Claude can infer intent, but it can't read your mind. Reference specific files, mention constraints, and point to example patterns.

| Strategy                                                                                         | Before                                               | After                                                                                                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------ | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scope the task.** Specify which file, what scenario, and testing preferences.                  | *"add tests for foo.py"*                             | *"write a test for foo.py covering the edge case where the user is logged out. avoid mocks."*                                                                                                                                                                                                                                                                    |
| **Point to sources.** Direct Claude to the source that can answer a question.                    | *"why does ExecutionFactory have such a weird api?"* | *"look through ExecutionFactory's git history and summarize how its api came to be"*                                                                                                                                                                                                                                                                             |
| **Reference existing patterns.** Point Claude to patterns in your codebase.                      | *"add a calendar widget"*                            | *"look at how existing widgets are implemented on the home page to understand the patterns. HotDogWidget.php is a good example. follow the pattern to implement a new calendar widget that lets the user select a month and paginate forwards/backwards to pick a year. build from scratch without libraries other than the ones already used in the codebase."* |
| **Describe the symptom.** Provide the symptom, the likely location, and what "fixed" looks like. | *"fix the login bug"*                                | *"users report that login fails after session timeout. check the auth flow in src/auth/, especially token refresh. write a failing test that reproduces the issue, then fix it"*                                                                                                                                                                                 |

Vague prompts can be useful when you're exploring and can afford to course-correct. A prompt like `"what would you improve in this file?"` can surface things you wouldn't have thought to ask about.

##### Provide rich content

<Tip>
  Use `@` to reference files, paste screenshots/images, or pipe data directly.
</Tip>

You can provide rich data to Claude in several ways:

* **Reference files with `@`** instead of describing where code lives. Claude reads the file before responding.
* **Paste images directly**. Copy/paste or drag and drop images into the prompt.
* **Give URLs** for documentation and API references. Use `/permissions` to allowlist frequently-used domains.
* **Pipe in data** by running `cat error.log | claude` to send file contents directly.
* **Let Claude fetch what it needs**. Tell Claude to pull context itself using Bash commands, MCP tools, or by reading files.

***

#### Configure your environment

A few setup steps make Claude Code significantly more effective across all your sessions. For a full overview of extension features and when to use each one, see [Extend Claude Code](/en/features-overview).

##### Write an effective CLAUDE.md

<Tip>
  Run `/init` to generate a starter CLAUDE.md file based on your current project structure, then refine over time.
</Tip>

CLAUDE.md is a special file that Claude reads at the start of every conversation. Include Bash commands, code style, and workflow rules. This gives Claude persistent context it can't infer from code alone.

The `/init` command analyzes your codebase to detect build systems, test frameworks, and code patterns, giving you a solid foundation to refine.

There's no required format for CLAUDE.md files, but keep it short and human-readable. For example:

```markdown CLAUDE.md theme={null}
# Code style
- Use ES modules (import/export) syntax, not CommonJS (require)
- Destructure imports when possible (eg. import { foo } from 'bar')

# Workflow
- Be sure to typecheck when you're done making a series of code changes
- Prefer running single tests, and not the whole test suite, for performance
```

CLAUDE.md is loaded every session, so only include things that apply broadly. For domain knowledge or workflows that are only relevant sometimes, use [skills](/en/skills) instead. Claude loads them on demand without bloating every conversation.

Keep it concise. For each line, ask: *"Would removing this cause Claude to make mistakes?"* If not, cut it. Bloated CLAUDE.md files cause Claude to ignore your actual instructions!

| ✅ Include                                            | ❌ Exclude                                          |
| ---------------------------------------------------- | -------------------------------------------------- |
| Bash commands Claude can't guess                     | Anything Claude can figure out by reading code     |
| Code style rules that differ from defaults           | Standard language conventions Claude already knows |
| Testing instructions and preferred test runners      | Detailed API documentation (link to docs instead)  |
| Repository etiquette (branch naming, PR conventions) | Information that changes frequently                |
| Architectural decisions specific to your project     | Long explanations or tutorials                     |
| Developer environment quirks (required env vars)     | File-by-file descriptions of the codebase          |
| Common gotchas or non-obvious behaviors              | Self-evident practices like "write clean code"     |

If Claude keeps doing something you don't want despite having a rule against it, the file is probably too long and the rule is getting lost. If Claude asks you questions that are answered in CLAUDE.md, the phrasing might be ambiguous. Treat CLAUDE.md like code: review it when things go wrong, prune it regularly, and test changes by observing whether Claude's behavior actually shifts.

You can tune instructions by adding emphasis (e.g., "IMPORTANT" or "YOU MUST") to improve adherence. Check CLAUDE.md into git so your team can contribute. The file compounds in value over time.

CLAUDE.md files can import additional files using `@path/to/import` syntax:

```markdown CLAUDE.md theme={null}
See @README.md for project overview and @package.json for available npm commands.

# Additional Instructions
- Git workflow: @docs/git-instructions.md
- Personal overrides: @~/.claude/my-project-instructions.md
```

You can place CLAUDE.md files in several locations:

* **Home folder (`~/.claude/CLAUDE.md`)**: applies to all Claude sessions
* **Project root (`./CLAUDE.md`)**: check into git to share with your team
* **Project root (`./CLAUDE.local.md`)**: personal project-specific notes; add this file to your `.gitignore` so it isn't shared with your team
* **Parent directories**: useful for monorepos where both `root/CLAUDE.md` and `root/foo/CLAUDE.md` are pulled in automatically
* **Child directories**: Claude pulls in child CLAUDE.md files on demand when working with files in those directories

##### Configure permissions

<Tip>
  Use [auto mode](/en/permission-modes#eliminate-prompts-with-auto-mode) to let a classifier handle approvals, `/permissions` to allowlist specific commands, or `/sandbox` for OS-level isolation. Each reduces interruptions while keeping you in control.
</Tip>

By default, Claude Code requests permission for actions that might modify your system: file writes, Bash commands, MCP tools, etc. This is safe but tedious. After the tenth approval you're not really reviewing anymore, you're just clicking through. There are three ways to reduce these interruptions:

* **Auto mode**: a separate classifier model reviews commands and blocks only what looks risky: scope escalation, unknown infrastructure, or hostile-content-driven actions. Best when you trust the general direction of a task but don't want to click through every step
* **Permission allowlists**: permit specific tools you know are safe, like `npm run lint` or `git commit`
* **Sandboxing**: enable OS-level isolation that restricts filesystem and network access, allowing Claude to work more freely within defined boundaries

Read more about [permission modes](/en/permission-modes), [permission rules](/en/permissions), and [sandboxing](/en/sandboxing).

##### Use CLI tools

<Tip>
  Tell Claude Code to use CLI tools like `gh`, `aws`, `gcloud`, and `sentry-cli` when interacting with external services.
</Tip>

CLI tools are the most context-efficient way to interact with external services. If you use GitHub, install the `gh` CLI. Claude knows how to use it for creating issues, opening pull requests, and reading comments. Without `gh`, Claude can still use the GitHub API, but unauthenticated requests often hit rate limits.

Claude is also effective at learning CLI tools it doesn't already know. Try prompts like `Use 'foo-cli-tool --help' to learn about foo tool, then use it to solve A, B, C.`

##### Connect MCP servers

<Tip>
  Run `claude mcp add` to connect external tools like Notion, Figma, or your database.
</Tip>

With [MCP servers](/en/mcp), you can ask Claude to implement features from issue trackers, query databases, analyze monitoring data, integrate designs from Figma, and automate workflows.

##### Set up hooks

<Tip>
  Use hooks for actions that must happen every time with zero exceptions.
</Tip>

[Hooks](/en/hooks-guide) run scripts automatically at specific points in Claude's workflow. Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens.

Claude can write hooks for you. Try prompts like *"Write a hook that runs eslint after every file edit"* or *"Write a hook that blocks writes to the migrations folder."* Edit `.claude/settings.json` directly to configure hooks by hand, and run `/hooks` to browse what's configured.

##### Create skills

<Tip>
  Create `SKILL.md` files in `.claude/skills/` to give Claude domain knowledge and reusable workflows.
</Tip>

[Skills](/en/skills) extend Claude's knowledge with information specific to your project, team, or domain. Claude applies them automatically when relevant, or you can invoke them directly with `/skill-name`.

Create a skill by adding a directory with a `SKILL.md` to `.claude/skills/`:

```markdown .claude/skills/api-conventions/SKILL.md theme={null}
---
name: api-conventions
description: REST API design conventions for our services
---
# API Conventions
- Use kebab-case for URL paths
- Use camelCase for JSON properties
- Always include pagination for list endpoints
- Version APIs in the URL path (/v1/, /v2/)
```

Skills can also define repeatable workflows you invoke directly:

```markdown .claude/skills/fix-issue/SKILL.md theme={null}
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---
Analyze and fix the GitHub issue: $ARGUMENTS.

1. Use `gh issue view` to get the issue details
2. Understand the problem described in the issue
3. Search the codebase for relevant files
4. Implement the necessary changes to fix the issue
5. Write and run tests to verify the fix
6. Ensure code passes linting and type checking
7. Create a descriptive commit message
8. Push and create a PR
```

Run `/fix-issue 1234` to invoke it. Use `disable-model-invocation: true` for workflows with side effects that you want to trigger manually.

##### Create custom subagents

<Tip>
  Define specialized assistants in `.claude/agents/` that Claude can delegate to for isolated tasks.
</Tip>

[Subagents](/en/sub-agents) run in their own context with their own set of allowed tools. They're useful for tasks that read many files or need specialized focus without cluttering your main conversation.

```markdown .claude/agents/security-reviewer.md theme={null}
---
name: security-reviewer
description: Reviews code for security vulnerabilities
tools: Read, Grep, Glob, Bash
model: opus
---
You are a senior security engineer. Review code for:
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication and authorization flaws
- Secrets or credentials in code
- Insecure data handling

Provide specific line references and suggested fixes.
```

Tell Claude to use subagents explicitly: *"Use a subagent to review this code for security issues."*

##### Install plugins

<Tip>
  Run `/plugin` to browse the marketplace. Plugins add skills, tools, and integrations without configuration.
</Tip>

[Plugins](/en/plugins) bundle skills, hooks, subagents, and MCP servers into a single installable unit from the community and Anthropic. If you work with a typed language, install a [code intelligence plugin](/en/discover-plugins#code-intelligence) to give Claude precise symbol navigation and automatic error detection after edits.

For guidance on choosing between skills, subagents, hooks, and MCP, see [Extend Claude Code](/en/features-overview#match-features-to-your-goal).

***

#### Communicate effectively

The way you communicate with Claude Code significantly impacts the quality of results.

##### Ask codebase questions

<Tip>
  Ask Claude questions you'd ask a senior engineer.
</Tip>

When onboarding to a new codebase, use Claude Code for learning and exploration. You can ask Claude the same sorts of questions you would ask another engineer:

* How does logging work?
* How do I make a new API endpoint?
* What does `async move { ... }` do on line 134 of `foo.rs`?
* What edge cases does `CustomerOnboardingFlowImpl` handle?
* Why does this code call `foo()` instead of `bar()` on line 333?

Using Claude Code this way is an effective onboarding workflow, improving ramp-up time and reducing load on other engineers. No special prompting required: ask questions directly.

##### Let Claude interview you

<Tip>
  For larger features, have Claude interview you first. Start with a minimal prompt and ask Claude to interview you using the `AskUserQuestion` tool.
</Tip>

Claude asks about things you might not have considered yet, including technical implementation, UI/UX, edge cases, and tradeoffs.

```text theme={null}
I want to build [brief description]. Interview me in detail using the AskUserQuestion tool.

Ask about technical implementation, UI/UX, edge cases, concerns, and tradeoffs. Don't ask obvious questions, dig into the hard parts I might not have considered.

Keep interviewing until we've covered everything, then write a complete spec to SPEC.md.
```

Once the spec is complete, start a fresh session to execute it. The new session has clean context focused entirely on implementation, and you have a written spec to reference.

***

#### Manage your session

Conversations are persistent and reversible. Use this to your advantage!

##### Course-correct early and often

<Tip>
  Correct Claude as soon as you notice it going off track.
</Tip>

The best results come from tight feedback loops. Though Claude occasionally solves problems perfectly on the first attempt, correcting it quickly generally produces better solutions faster.

* **`Esc`**: stop Claude mid-action with the `Esc` key. Context is preserved, so you can redirect.
* **`Esc + Esc` or `/rewind`**: press `Esc` twice or run `/rewind` to open the rewind menu and restore previous conversation and code state, or summarize from a selected message.
* **`"Undo that"`**: have Claude revert its changes.
* **`/clear`**: reset context between unrelated tasks. Long sessions with irrelevant context can reduce performance.

If you've corrected Claude more than twice on the same issue in one session, the context is cluttered with failed approaches. Run `/clear` and start fresh with a more specific prompt that incorporates what you learned. A clean session with a better prompt almost always outperforms a long session with accumulated corrections.

##### Manage context aggressively

<Tip>
  Run `/clear` between unrelated tasks to reset context.
</Tip>

Claude Code automatically compacts conversation history when you approach context limits, which preserves important code and decisions while freeing space.

During long sessions, Claude's context window can fill with irrelevant conversation, file contents, and commands. This can reduce performance and sometimes distract Claude.

* Use `/clear` frequently between tasks to reset the context window entirely
* When auto compaction triggers, Claude summarizes what matters most, including code patterns, file states, and key decisions
* For more control, run `/compact <instructions>`, like `/compact Focus on the API changes`
* To compact only part of the conversation, use `Esc + Esc` or `/rewind`, select a message checkpoint, and choose **Summarize from here** or **Summarize up to here**. The first condenses messages from that point forward while keeping earlier context intact; the second condenses earlier messages while keeping recent ones in full. See [Restore vs. summarize](/en/checkpointing#restore-vs-summarize).
* Customize compaction behavior in CLAUDE.md with instructions like `"When compacting, always preserve the full list of modified files and any test commands"` to ensure critical context survives summarization
* For quick questions that don't need to stay in context, use [`/btw`](/en/interactive-mode#side-questions-with-%2Fbtw). The answer appears in a dismissible overlay and never enters conversation history, so you can check a detail without growing context.

##### Use subagents for investigation

<Tip>
  Delegate research with `"use subagents to investigate X"`. They explore in a separate context, keeping your main conversation clean for implementation.
</Tip>

Since context is your fundamental constraint, subagents are one of the most powerful tools available. When Claude researches a codebase it reads lots of files, all of which consume your context. Subagents run in separate context windows and report back summaries:

```text theme={null}
Use subagents to investigate how our authentication system handles token
refresh, and whether we have any existing OAuth utilities I should reuse.
```

The subagent explores the codebase, reads relevant files, and reports back with findings, all without cluttering your main conversation.

You can also use subagents for verification after Claude implements something:

```text theme={null}
use a subagent to review this code for edge cases
```

##### Rewind with checkpoints

<Tip>
  Every prompt you send creates a checkpoint. You can restore conversation, code, or both to any previous checkpoint.
</Tip>

Claude automatically snapshots files before each change so a checkpoint can restore them. Double-tap `Escape` or run `/rewind` to open the rewind menu. You can restore conversation only, restore code only, restore both, or summarize from a selected message. See [Checkpointing](/en/checkpointing) for details.

Instead of carefully planning every move, you can tell Claude to try something risky. If it doesn't work, rewind and try a different approach. Checkpoints persist across sessions, so you can close your terminal and still rewind later.

<Warning>
  Checkpoints only track changes made *by Claude*, not external processes. This isn't a replacement for git.
</Warning>

##### Resume conversations

<Tip>
  Name sessions with `/rename` and treat them like branches: each workstream gets its own persistent context.
</Tip>

Claude Code saves conversations locally, so when a task spans multiple sittings you don't have to re-explain the context. Run `claude --continue` to pick up the most recent session, or `claude --resume` to choose from a list. Give sessions descriptive names like `oauth-migration` so you can find them later. See [Manage sessions](/en/sessions) for the full set of resume, branch, and naming controls.

***

#### Automate and scale

Once you're effective with one Claude, multiply your output with parallel sessions, non-interactive mode, and fan-out patterns.

Everything so far assumes one human, one Claude, and one conversation. But Claude Code scales horizontally. The techniques in this section show how you can get more done.

##### Run non-interactive mode

<Tip>
  Use `claude -p "prompt"` in CI, pre-commit hooks, or scripts. Add `--output-format stream-json` for streaming JSON output.
</Tip>

With `claude -p "your prompt"`, you can run Claude non-interactively, without a session. [Non-interactive mode](/en/headless) is how you integrate Claude into CI pipelines, pre-commit hooks, or any automated workflow. The output formats let you parse results programmatically: plain text, JSON, or streaming JSON.

```bash theme={null}
# One-off queries
claude -p "Explain what this project does"

# Structured output for scripts
claude -p "List all API endpoints" --output-format json

# Streaming for real-time processing
claude -p "Analyze this log file" --output-format stream-json
```

##### Run multiple Claude sessions

<Tip>
  Run multiple Claude sessions in parallel to speed up development, run isolated experiments, or start complex workflows.
</Tip>

Pick the parallel approach that fits how much coordination you want to do yourself:

* [Worktrees](/en/worktrees): run separate CLI sessions in isolated git checkouts so edits don't collide
* [Desktop app](/en/desktop#work-in-parallel-with-sessions): manage multiple local sessions visually, each in its own worktree
* [Claude Code on the web](/en/claude-code-on-the-web): run sessions on Anthropic-managed cloud infrastructure in isolated VMs
* [Agent teams](/en/agent-teams): automated coordination of multiple sessions with shared tasks, messaging, and a team lead

Beyond parallelizing work, multiple sessions enable quality-focused workflows. A fresh context improves code review since Claude won't be biased toward code it just wrote.

For example, use a Writer/Reviewer pattern:

| Session A (Writer)                                                      | Session B (Reviewer)                                                                                                                                                     |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Implement a rate limiter for our API endpoints`                        |                                                                                                                                                                          |
|                                                                         | `Review the rate limiter implementation in @src/middleware/rateLimiter.ts. Look for edge cases, race conditions, and consistency with our existing middleware patterns.` |
| `Here's the review feedback: [Session B output]. Address these issues.` |                                                                                                                                                                          |

You can do something similar with tests: have one Claude write tests, then another write code to pass them.

##### Fan out across files

<Tip>
  Loop through tasks calling `claude -p` for each. Use `--allowedTools` to scope permissions for batch operations.
</Tip>

For large migrations or analyses, you can distribute work across many parallel Claude invocations:

<Steps>
  <Step title="Generate a task list">
    Have Claude list all files that need migrating (e.g., `list all 2,000 Python files that need migrating`)
  </Step>

  <Step title="Write a script to loop through the list">
    ```bash theme={null}
    for file in $(cat files.txt); do
      claude -p "Migrate $file from React to Vue. Return OK or FAIL." \
        --allowedTools "Edit,Bash(git commit *)"
    done
    ```
  </Step>

  <Step title="Test on a few files, then run at scale">
    Refine your prompt based on what goes wrong with the first 2-3 files, then run on the full set. The `--allowedTools` flag restricts what Claude can do, which matters when you're running unattended.
  </Step>
</Steps>

You can also integrate Claude into existing data/processing pipelines:

```bash theme={null}
claude -p "<your prompt>" --output-format json | your_command
```

Use `--verbose` for debugging during development, and turn it off in production.

##### Run autonomously with auto mode

For uninterrupted execution with background safety checks, use [auto mode](/en/permission-modes#eliminate-prompts-with-auto-mode). A classifier model reviews commands before they run, blocking scope escalation, unknown infrastructure, and hostile-content-driven actions while letting routine work proceed without prompts.

```bash theme={null}
claude --permission-mode auto -p "fix all lint errors"
```

For non-interactive runs with the `-p` flag, auto mode aborts if the classifier repeatedly blocks actions, since there is no user to fall back to. See [when auto mode falls back](/en/permission-modes#when-auto-mode-falls-back) for thresholds.

***

#### Avoid common failure patterns

These are common mistakes. Recognizing them early saves time:

* **The kitchen sink session.** You start with one task, then ask Claude something unrelated, then go back to the first task. Context is full of irrelevant information.
  > **Fix**: `/clear` between unrelated tasks.
* **Correcting over and over.** Claude does something wrong, you correct it, it's still wrong, you correct again. Context is polluted with failed approaches.
  > **Fix**: After two failed corrections, `/clear` and write a better initial prompt incorporating what you learned.
* **The over-specified CLAUDE.md.** If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise.
  > **Fix**: Ruthlessly prune. If Claude already does something correctly without the instruction, delete it or convert it to a hook.
* **The trust-then-verify gap.** Claude produces a plausible-looking implementation that doesn't handle edge cases.
  > **Fix**: Always provide verification (tests, scripts, screenshots). If you can't verify it, don't ship it.
* **The infinite exploration.** You ask Claude to "investigate" something without scoping it. Claude reads hundreds of files, filling the context.
  > **Fix**: Scope investigations narrowly or use subagents so the exploration doesn't consume your main context.

***

#### Develop your intuition

The patterns in this guide aren't set in stone. They're starting points that work well in general, but might not be optimal for every situation.

Sometimes you *should* let context accumulate because you're deep in one complex problem and the history is valuable. Sometimes you should skip planning and let Claude figure it out because the task is exploratory. Sometimes a vague prompt is exactly right because you want to see how Claude interprets the problem before constraining it.

Pay attention to what works. When Claude produces great output, notice what you did: the prompt structure, the context you provided, the mode you were in. When Claude struggles, ask why. Was the context too noisy? The prompt too vague? The task too big for one pass?

Over time, you'll develop intuition that no guide can capture. You'll know when to be specific and when to be open-ended, when to plan and when to explore, when to clear context and when to let it accumulate.

#### Related resources

* [How Claude Code works](/en/how-claude-code-works): the agentic loop, tools, and context management
* [Extend Claude Code](/en/features-overview): skills, hooks, MCP, subagents, and plugins
* [Common workflows](/en/common-workflows): step-by-step recipes for debugging, testing, PRs, and more
* [CLAUDE.md](/en/memory): store project conventions and persistent context

---

### Source 9 — xAI, "Grok Build Beta" (xAI canonical product surface, x.ai/cli, accessed 2026-05-26)

Distinct from Source 4 (the 2026-05-14 launch announcement at `x.ai/news/grok-build-cli`). Source 4 = one-time launch event; Source 9 = living product surface with installer, slash commands, plan-mode rules, extensions composition.

> *"Grok Build is a powerful new coding agent and CLI for professional software engineering and complex coding work."*

(Verbatim positioning consistent across Source 4 + Source 9 — confirming `x.ai/cli` is the canonical product page for the same product.)

**Distribution.** Available to all SuperGrok and X Premium Plus subscribers.

**Installation** (verbatim):

```
curl -fsSL https://x.ai/cli/install.sh | bash
```

**Architecture** (verbatim, ratifying G-7 / G-8 / G-9):

> *"Grok Build delegates larger tasks to specialized subagents, with each child running in parallel with its own context window."*

**Plan Mode** (verbatim, ratifying G-12):

> *"Plan mode is for planning first. When it is active, write tools are blocked except for the session plan file. Use it when you want Grok to sketch the approach before it starts making changes."*

Plan mode → approve / comment-on-step / rewrite → clean diffs once approved.

**Extensions composition** (verbatim, ratifying G-10 + the harness composition strategy):

> *"Your AGENTS.md, plugins, hooks, skills, and MCP servers all work out of the box. Start Grok Build in your repo and it picks up your conventions instantly."*

**Slash commands.** `/hooks`, `/plugins`, `/skills`, `/mcps` all open the same extensions modal (pre-selecting a tab). `/feedback` sends bugs / requests / reactions to the team.

**Workflow positioning** (verbatim): *"one tool for the entire development workflow — plan, build, test, and deploy."*

**Verification:** T-C. Primary URL (`x.ai/cli`) returned 403 in capture session (`x-deny-reason: host_not_allowed` per the harness's outbound network policy). Verbatim phrasing recovered per `docs/researcher-discipline.md §3` fallback chain: WebFetch → WebSearch → cross-attribute across ≥ 3 indexed secondary sources with a primary-operated anchor (`docs.x.ai/build/modes-and-commands`). Cross-attribution citations: `docs.x.ai/build/modes-and-commands`, `skywork.ai/clihub/keywords/grok-cli.html`, `aimadetools.com/blog/grok-build-complete-guide`, `basenor.com/blogs/news/xai-launches-grok-build-beta-agentic-coding-cli-explained`, `pasqualepillitteri.it/en/news/2584/grok-build-xai-cli-2026`, `releasebot.io/updates/xai`, `codersera.com/blog/how-to-install-grok-build-cli-2026/`, `chatforest.com/reviews/xai-grok-build-coding-agent-cli-review-2026/`, `verdent.ai/guides/grok-for-coding-2026`, `cryptobriefing.com/xai-grok-cli-windows-powershell/`, `digitalapplied.com/blog/xai-grok-build-cli-parallel-coding-agents`. Acceptance bar honored per `docs/researcher-discipline.md §5`: ≥ 3 secondary sources, primary-operated domain anchor (`docs.x.ai`), SEO-spam sources rejected.

**Supplementary reference (NOT elevated as a separate Source):** Dan (@Daniel_Farinax) X post at `x.com/Daniel_Farinax/status/2059002180481204461` (2026-05-25). Beginner-onboarding video demoing Source 9's installer and workflow for non-technical SuperGrok / X Premium+ users. Also 403 in capture session; T-D paraphrase recovered. Community-adoption evidence; demos Source 9 content rather than carrying independent architectural weight, hence folded here rather than elevated as Source 10. Per `docs/researcher-discipline.md §5`, single-source secondary content is T-D not T-C; documented as supplementary so the URL remains in the architectural record.

**Capture date:** 2026-05-26. **Elevated by:** drumfiend21. **Procedure cited:** `docs/researcher-discipline.md` (first §1 entry to cite the procedure doc by path rather than open-coded prose).

---

## §2 Scope

These directives apply to **every** session type (local CLI, remote, cloud, GitHub Action, IDE) and **every** component of the harness — this repo, the consumption pattern around the `claude-tdd-pro` plugin, the `.grok/` orchestration layer, the `.claude/` consumption layer, the handoff contract, all skills, all hooks, all sub-agents, all monitors.

They override default Claude behavior and any contradictory instruction not explicitly marked as superseding these directives. Amendments follow the ADR process in `docs/architecture-principles.md` §19 — never edit a D-rule in place, and never edit a §1 provenance entry under any circumstance.

## §3 Directives (D-1 .. D-13)

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

### D-13 — Context is the fundamental constraint; manage it aggressively and exit named failure patterns early.

Source 8 declares the foundational constraint behind all Claude Code best practices in a single sentence: "the context window is the most important resource to manage." Performance degrades as context fills; agents start "forgetting" earlier instructions and making more mistakes. The named techniques: `/clear` between unrelated tasks, subagents for investigations that read many files, `/compact` for selective summarization, `/rewind` for restoring to a checkpoint, and ruthless pruning of `CLAUDE.md` so important rules don't get lost in noise. Source 8 also names five common failure patterns — recognize and exit them rather than push through.

The five named failure patterns from Source 8 (verbatim):

1. **The kitchen sink session** — start with one task, drift to another, return to the first; context fills with irrelevant information. *Fix: `/clear` between unrelated tasks.*
2. **Correcting over and over** — context pollutes with failed approaches. *Fix: after two failed corrections, `/clear` and write a better initial prompt.*
3. **The over-specified `CLAUDE.md`** — important rules get lost in noise; agent ignores half of it. *Fix: ruthlessly prune; if the agent already does it correctly without the instruction, delete the instruction.*
4. **The trust-then-verify gap** — plausible-looking implementation doesn't handle edge cases. *Fix: always provide verification — tests, scripts, screenshots; if you can't verify, don't ship.*
5. **The infinite exploration** — agent reads hundreds of files filling context. *Fix: scope investigations narrowly or delegate to subagents.*

**Source:** §1 / Source 8 (Anthropic, "Best practices for Claude Code"). Reinforces and operationalizes D-3 (terminal states), D-10 (verification), and D-12 (production-grade trust) inside the inner-loop session itself.

**Operational consequence:** Every session in this repo treats context as a budgeted resource, not a free background. When a session crosses ~50% of its context budget on exploration, the agent switches to subagent delegation or `/compact` before continuing. When the same correction has been applied twice without converging, the agent calls a halt and proposes either `/clear` with a sharper prompt or escalation to the human. CLAUDE.md and its sibling rulebooks are reviewed for prunability at every CL that touches them — the question "would removing this line cause the agent to make mistakes?" is asked, and if no, the line goes. Watching for the five named failure patterns is part of the pre-commit audit.

## §4 Self-audit checklist (pre-commit)

Before every commit, the author — human or agent — confirms:

- [ ] (D-1) If a new Grok-side primitive was added, its Claude Code and/or Cursor analog is documented in the PR description or an accompanying ADR.
- [ ] (D-1 reverse, ADR-0013) If a new Cursor-side or Claude Code-side primitive was added, its Grok analog (or rationale for absence) is documented in the PR description or an accompanying ADR. Symmetric reading of D-1 per ADR-0013.
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
- [ ] (D-13) The session producing this CL did not exhibit any of the five named failure patterns (kitchen-sink, correction-loop, over-specified-CLAUDE.md, trust-then-verify gap, infinite exploration). If one appeared and was corrected mid-session, document it briefly in the commit body.
- [ ] (D-12 + D-13, Q-DOC-DRIFT) **Operator-visible surface consistency.** If this CL changes any operator-visible surface — CLI flag, help text, JSON schema, hook, setting, README claim, example invariant, or any doc that describes the surface — every downstream operator-facing doc has been updated to match in this same CL. Verified by `./scripts/audit-doc-drift.sh` exiting 0 (or by inspection if the script's four pattern checks do not apply to this CL's surface). Stale operator docs are a D-12 trustability violation; not running the audit is a D-13 "trust-then-verify gap." Added in TICKET-006.b after the TICKET-006.a audit found six drift items the existing checklist did not catch; rationale in ADR-0009.

## §5 Authority tier and rule-ordering

When D-rules conflict with rules in the other rulebooks, this is the ordering:

| Tier | Rulebook | Scope |
|---|---|---|
| 0 | `docs/ai-engineering-corpus.md` (supreme operating directive) | Repo-wide; highest-priority ruleset for architecture, planning, and development. Above everything. |
| 1 | `CLAUDE.md` prime directive (plugin-dependency model) | Repo-wide; non-negotiable beneath TIER 0. |
| 1 | This document (founder directives, D-1 .. D-13) | Repo-wide; provenance + derived directives. Co-equal with the prime directive, beneath TIER 0. |
| 2 | `docs/architecture-principles.md` (R-1 .. R-20) | Architectural design and code structure. |
| 2 | `docs/grok-orchestration-principles.md` (G-1 .. G-21) | `.grok/` and all Grok-facing surfaces. |
| 2 | `docs/claude-tdd-pro-principles.md` (active harness-side C-rules: C-1, C-22, C-23, C-24; C-2..C-21 consolidated to upstream per ADR-0033) | Acceptance-tested inner-loop work (harness-side rules + upstream plugin SKILL.md trio). |

When a D-rule and an R- / G- / C- rule conflict, the D-rule wins. When a D-rule conflicts with the TIER-0 supreme operating directive (the AI engineering corpus), the corpus wins. Raise the conflict in the CL (or before, via clarification) rather than silently relaxing either. When the two TIER-1 authorities (prime directive and founder directives) conflict with each other, raise it explicitly — neither defers to the other by default. There is no rulebook above TIER 0; the corpus is the supreme operating directive.

## §6 Amendment process

Amendments follow the ADR process documented in `docs/architecture-principles.md` §19:

1. Open an ADR in `docs/adr/000N-*.md` proposing the amendment.
2. The ADR cites the relevant §1 source. If the amendment requires a new §1 entry, the ADR includes the source text verbatim, with attribution (author, date, capture method — URL or screenshot reference).
3. The amendment merges with the ADR in a single CL.
4. The §3 D-rule is updated (or a new D-rule appended); §1 provenance entries are never edited.

Never edit a D-rule in place without an ADR. Never edit a §1 entry, ever — even to fix a typo. The whole point of the immutable §1 layer is that future maintainers can re-interpret from the original, not inherit a stale (or sanitized) reading of it.
