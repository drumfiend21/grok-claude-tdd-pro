# Claude TDD Pro Principles

Authoritative reference for how `claude-tdd-pro` (the plugin) is consumed in this repo. Claude TDD Pro plays the **inner-loop quality core** role specified in `docs/architecture.md`: Red-Green-Refactor enforcement on one ticket at a time, decision-trail emission, and substrate-touch hygiene. Claude TDD Pro does NOT do its own research and never triggers deploy.

This document is the binding rulebook for that role. Synthesized from the canonical TDD literature (Kent Beck, Uncle Bob's Three Laws, Martin Fowler's Refactoring, Michael Feathers' legacy-code work, Mike Cohn's test pyramid, the London/Chicago schools, the mutation/property-based testing literature) and from Anthropic's official Claude Code and Claude Skills documentation (headless `-p` mode, the Skills system anatomy, progressive disclosure, the Agent SDK), plus the DORA delivery metrics from *Accelerate*.

This document complements (does not replace):

- `CLAUDE.md` — the prime directive (plugin-dependency model)
- `docs/architecture-principles.md` — cross-cutting microservice rules (R-1 .. R-20)
- `docs/grok-orchestration-principles.md` — Grok outer-loop rules (G-1 .. G-21)
- `docs/architecture.md` — the harness-specific architecture
- `docs/handoff-contract.md` — the API boundary between Grok and Claude TDD Pro

If a request, design, or code change in this repo conflicts with a rule below, raise it before proceeding. The rules in §16 are the operational form.

---

## How to use this document

1. **Before designing any inner-loop flow** (skill invocation, test plan, refactor strategy, decision-trail format): read §16 first; consult the relevant authority section.
2. **Before committing** any code change inside acceptance-tested scope: run the self-audit checklist in §17 alongside the architectural and Grok checklists.
3. **When a rule is in tension with a request**: defer to the rule. Surface the tension. Do not silently relax it.
4. **Amendments** follow the ADR process documented in `architecture-principles.md` §15/§19. Rules above are immutable in spirit; supersession is explicit, not in-place editing.

---

## §1. Kent Beck — TDD origin and the Red-Green-Refactor rhythm [1]

*Test-Driven Development: By Example* (2002) is the foundational reference text. Beck formalized the deterministic three-phase loop that defines the discipline:

- **Red** — write a small test that doesn't work yet, and perhaps doesn't even compile. Stating the desired behavior comes first; the test FAILS before any production code exists.
- **Green** — make the test pass quickly, committing whatever sins necessary in the process. Correctness is the only criterion at this phase; elegance is forbidden.
- **Refactor** — eliminate all the duplication created in merely getting the test to work. Tests stay green throughout; the structure improves.

Cycle properties:
- The loop is **deterministic** and **small**. Beck described it as "rhythm" — Red-Green-Refactor in seconds-to-minutes, not days.
- Each cycle is **provably small**: write the next failing test, write the minimum code to pass it, refactor what duplication that created, repeat.
- **Code at the Green phase is permitted to be ugly.** Refactor is where it becomes good. Skipping Refactor is one of the two cardinal failure modes; skipping Red (writing code first, then tests) is the other.

## §2. Uncle Bob — The Three Laws of TDD [2]

Robert C. Martin's distillation of the discipline, paired with Kent Beck in 1999 to learn it line-by-line. These three laws define the **nano-cycle** of TDD — the second-by-second discipline iterated a dozen times per unit test:

1. **You must write a failing test before you write any production code.**
2. **You must not write more of a test than is sufficient to fail, or fail to compile.**
3. **You must not write more production code than is sufficient to make the currently failing test pass.**

Properties:
- Granularity is **line-by-line**. Write one line of failing test; write the one line of production code that makes it pass; repeat. Beck and Uncle Bob explicitly demonstrated this at this scale.
- The laws **enforce minimum increment**. Any deviation (writing more test than needed, writing speculative production code) breaks the discipline and is a smell.
- The laws are how TDD prevents over-engineering and how the test suite becomes complete by construction.

## §3. The Cycles of TDD (Uncle Bob)

Beyond the nano-cycle, the discipline operates at three nested scales:

- **Nano-cycle (seconds):** the Three Laws — one failing-test-line ↔ one production-line.
- **Micro-cycle (minutes):** full Red → Green → Refactor for one behavior. This is the "Red-Green-Refactor" most engineers learn.
- **Macro-cycle (hours):** vertical-slice or use-case feature. Many micro-cycles compose into a deliverable.

Rule: every cycle level has a **green checkpoint**. You may pause at green; you may not pause at red. Walking away from a red test (commit, lunch break, end of day) is an anti-pattern.

## §4. Martin Fowler — Refactoring (smells + safe step-by-step refactorings) [3]

*Refactoring: Improving the Design of Existing Code* (2nd ed., 2018; co-authored with Beck) is the canonical refactoring reference. Two surfaces this repo treats as binding:

**Code Smells Catalog (Chapter 3).** A short list of named anti-patterns that signal refactoring opportunity. Highlights:
- **Mysterious Name** — name doesn't communicate intent.
- **Duplicated Code** — same logic in multiple places.
- **Long Function** — function does too much.
- **Long Parameter List** — too many arguments; usually means a missing concept.
- **Global / Mutable Data** — change at a distance.
- **Divergent Change / Shotgun Surgery** — one module changes for many reasons / one change touches many modules.
- **Feature Envy** — method uses another object's data more than its own.
- **Data Clumps** — same group of variables appearing together.
- **Primitive Obsession** — using primitives where a named type belongs.
- **Repeated Switches**, **Loops**, **Lazy Element**, **Speculative Generality**, **Temporary Field**, **Message Chains**, **Middle Man**, **Insider Trading**, **Large Class**, **Alternative Classes with Different Interfaces**, **Data Class**, **Refused Bequest**, **Comments** (overused as deodorant).

**The Refactoring Catalog (Chapters 5–12).** 70+ named refactorings with:
- when to apply (the smell that motivates it),
- step-by-step mechanics (the safe sequence),
- a worked example (the before/after).

Rule: refactorings are **named, atomic, and applied one at a time with the test suite green between each step**. "Just clean this up" is not a refactoring — it's a risk.

## §5. Michael Feathers — Working Effectively with Legacy Code [4]

The canonical reference for changing code that lacks tests. Three core constructs:

- **Legacy code = code without tests.** Feathers' operational definition. Age and ugliness are irrelevant; the absence of a passing test suite is the diagnostic.
- **Seams.** A seam is "a place where you can alter behavior without editing that place." Find seams (object, link, preprocessing) to inject testability without touching the production path.
- **Characterization tests.** Tests written to pin down what code currently does, not what it should do. The point is to lock in behavior before refactoring, so changes are detectable.

Two safe-change patterns this repo applies:
- **Sprout Method / Sprout Class.** Add new behavior as a new method or class, fully test it, then wire it in from the legacy code. Never edit untested legacy code in place.
- **Wrap Method / Wrap Class.** Add behavior by wrapping the existing call, so the old code is unchanged and the new behavior is testable.

24 dependency-breaking techniques (Chapter 25) are the toolbox for making untestable code testable.

## §6. The Test Pyramid (Mike Cohn / Martin Fowler) [5]

Cohn's *Succeeding with Agile* (2009, first described 2003-4) and Fowler's *Practical Test Pyramid* are the canonical references. The pyramid has three layers, sized in proportion:

```
        /\        E2E tests        — few, slow, brittle
       /  \
      /    \      Integration      — moderate, focused on collaborations
     /      \
    /________\    Unit tests       — many, fast, deterministic
```

Rules:
- **Default to unit tests.** They are fast (sub-second per test), deterministic, isolated, and the cheapest to maintain.
- **Integration tests are a thin middle layer** for testing how components fit together — focused, not exhaustive.
- **E2E tests are a "second line of defense"** (Fowler) — sparingly used for end-user-visible flows; expensive, slow, fragile.
- **Inverted pyramids are rejected.** Heavy E2E + thin units = slow feedback + flaky CI + high maintenance cost. This is a well-documented anti-pattern.

The pyramid is about **feedback speed**: fast units catch most regressions in the inner loop; integration and E2E catch what units can't.

## §7. The London vs Chicago Schools of TDD [6]

Two complementary traditions, both legitimate, used deliberately per context:

**Chicago / Detroit School (Classicist, state-based, inside-out)**
- Rooted in Kent Beck's original teachings.
- Test by exercising the unit and asserting on return values / final state.
- Mocks only when real collaborators are unattractive (slow, non-deterministic, irrelevant).
- Strength: tests are robust to refactoring; design emerges bottom-up.

**London School (Mockist, interaction-based, outside-in)**
- Popularized by Freeman & Pryce in *Growing Object-Oriented Software, Guided by Tests*.
- Test by specifying which collaborators a unit calls and how.
- Focus on roles, responsibilities, interactions; design starts from the outermost API and works in.
- Strength: forces explicit collaboration contracts; well-suited to message-passing / service-oriented design.

Rule: **choose deliberately, per module**, based on what the unit's value is:
- If the unit's value is its **output / state transition** → Classicist.
- If the unit's value is its **interaction contract** with collaborators → Mockist.
- The choice is recorded in the decision trail (§15) so reviewers know which strain of TDD they are reading.

Anti-pattern: mocking the system under test (the unit you are exercising). Mocks are for collaborators only. Mocking the SUT hides design problems.

## §8. Mutation Testing + Property-Based Testing (beyond line coverage) [7]

Line coverage tells you **which lines ran**, not **which bugs your tests catch**. The literature has two well-developed mitigations:

**Mutation Testing** (PIT, Stryker): the framework introduces small, deterministic mutations to the production code (flip `<` to `<=`, change `return x` to `return null`) and re-runs the tests. A surviving mutant is a test gap. Industry-standard tools: PIT (Java), Stryker (JS/TS/C#/Scala).

**Property-Based Testing** (QuickCheck, Hypothesis, fast-check): instead of (or alongside) example-based tests, specify a property the code must satisfy for all inputs in a domain; the framework generates inputs to try to falsify it. Excels at finding edge cases humans don't think to write.

Rule: **coverage is a leading indicator, not a goal** (Goodhart's law applies). For modules where correctness matters disproportionately (security-relevant, billing, contract-validation), require either property-based tests or a mutation-testing pass with a stated mutation-survival threshold.

## §9. Anthropic — Claude Code best practices [8]

The official guidance for using Claude Code well. Highlights this repo treats as binding:

- **Context window is the constraint.** Performance degrades as the window fills. Most other best practices flow from this one.
- **CLAUDE.md is the persistent context surface.** It is read at the start of every conversation. Include bash commands, code-style rules, workflow conventions, files-never-to-touch. Keep it tight; rot kills it.
- **Claude is agentic.** It explores, plans, implements, runs commands, makes changes. You describe what you want; Claude figures out how. Treat it like a senior engineer, not a code-completer.
- **Use Claude for codebase exploration**, not just code-writing. "What does X do?", "What edge cases does Y handle?", "Where is Z called from?" are first-class uses.
- **Writer/Reviewer multi-agent pattern.** One Claude session writes tests; a separate session writes code to pass them. Forces honest test-first discipline.
- **Loop with `claude -p`.** For batch operations, iterate over tasks with `claude -p` calls; scope tool access with `--allowedTools`.
- **Code-intelligence plugins.** For typed languages, install a code-intelligence plugin to give Claude precise symbol navigation and automatic error detection after edits.

## §10. Claude Code headless mode — the inner-loop contract surface [9]

Claude Code's `-p` (or `--print`) flag is the non-interactive invocation. This is the contract surface for inner-loop dispatch from the harness:

- **Three output formats.** `text` (raw response on stdout, default), `json` (response wrapped with metadata), `stream-json` (NDJSON; one event per line — `type: assistant | tool_use | result`). Most CI integrations (~85%) use `json` and parse with `jq`.
- **`--bare` mode** is the recommended form for scripted / SDK calls; it will become the default for `-p` in a future release.
- **`--allowedTools`** scopes which tools the agent may call. **Default-allow is a permission leak.** Per-invocation allowlists are mandatory.
- **The Claude Agent SDK** exposes the same agent loop, tools, and context management as Claude Code, via Python or TypeScript packages — for richer programmatic control beyond the CLI.
- The headless invocation is the **contract surface for automation**. Anything dependent on TUI-only behavior is non-portable and out of contract.

## §11. Claude Skills system — anatomy and progressive disclosure [10]

Skills are the Anthropic-stewarded mechanism for packaging reusable agent capability. The three `tdd-pro-*` skills are consumed via this system.

**SKILL.md anatomy:**
- A skill is a directory containing a `SKILL.md` file.
- `SKILL.md` opens with **YAML frontmatter** with required `name` (lowercase + hyphens, ≤64 chars) and `description` (third-person; "This skill should be used when …").
- The `name`/`description` are the **matching surface** — Claude scans them to decide whether to load the skill.
- The body of `SKILL.md` is the full instructions, loaded only on match.
- Optional bundled resources (scripts, references, assets) live alongside `SKILL.md` and are loaded on demand.

**Progressive disclosure architecture:**
- **Metadata only at startup** (~60-100 tokens per skill) — Claude scans frontmatter to identify relevant matches.
- **Full SKILL.md loaded on match** (typically <5k tokens) — only when the skill applies to the current task.
- **Deeper bundled resources loaded on demand** — only when the agent specifically navigates to them.

**Plugin marketplace:** skills install via `/plugin marketplace add <repo>` or `/plugin add /path/to/skill-dir`. Skills are also accessible via the `/v1/skills` API endpoint.

Rules for this repo:
- We **consume** Claude Skills; we do not author new ones here. The three `tdd-pro-*` skills are authored in `claude-tdd-pro` and imported by reference.
- Bypassing progressive disclosure (inlining a skill's body into a prompt) is a contract violation — it defeats the token economics and breaks the version boundary.

## §12. Claude TDD Pro's three skills — what we consume [11]

The plugin exposes exactly three skills. Each has a defined role; this repo invokes them by name. Nothing in this repo redefines or re-implements them.

| Skill                          | Role                                                                                                                          | Invoked when                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `tdd-pro-cl-workflow`          | The per-CL loop: pre-flight architecture quote → spec-write (test) → audit → commit. This is the Red-Green-Refactor enforcement gate. | Every inner-loop invocation against acceptance-tested scope.                       |
| `tdd-pro-batch-cl`             | The decision rule for whether substrate-touch changes (build, lint, CI, hooks) collapse into one CL or split into many.       | Whenever a ticket touches the substrate (build/CI/hooks/lint) as opposed to feature code. |
| `tdd-pro-bash32-portability`   | The bash 3.2 / BSD-tool portability checklist for shell substrate the harness emits.                                          | Whenever a ticket adds or modifies shell scripts.                                  |

Rules:
- **Skills are referenced by name** in the handoff payload's `skills_invoked` field on the response side. The orchestrator surfaces which skill ran in the audit trail.
- **No skill substitution.** If a ticket would need a TDD discipline the existing trio doesn't cover, the right move is to **propose a v1.11 amendment in `claude-tdd-pro`**, not to bolt a fourth skill into this repo (architectural rule R-1, R-2).
- The trio is **deliberately minimal**. The plugin's own architecture rejects a fourth `tdd-pro-core` skill as a thin wrapper. We honor that choice on the consumer side.

## §13. Atomic commits — one ticket, one CL, one purpose [12]

The commit hygiene literature is consistent: each commit is the smallest self-contained change that cannot be broken down further.

Rules:
- **One ticket = one CL = one commit.** Commit message references `TICKET-NNN`. If scope grows mid-ticket, split into `TICKET-NNN.a` / `.b` rather than expanding the original (per this repo's `TICKETS.md` conventions).
- **Single-purpose commits.** Refactor + feature in one commit is a smell. Substrate-touch + feature in one commit is a smell (handled by `tdd-pro-batch-cl`).
- **Commit messages explain WHY**, not WHAT. The diff is the WHAT; the message is the rationale.
- **Atomic commits enable bisect.** A non-atomic history makes `git bisect` unable to localize a regression to one change.

## §14. DORA metrics — measuring quality without sacrificing throughput [13]

From *Accelerate* (Forsgren, Humble, Kim, 2018) — the empirically validated four-key metric for software-delivery performance. Elite teams score high on **both** velocity and stability; the data refutes the throughput-vs-quality trade-off.

| Metric                       | What it measures                                  | Elite-performer benchmark            |
| ---------------------------- | ------------------------------------------------- | ------------------------------------ |
| Deployment Frequency         | How often code reaches production                 | Multiple times per day               |
| Lead Time for Changes        | Commit → production duration                      | < 26 hours                           |
| Change Failure Rate          | % of deploys that cause a production incident     | < 1 %                                |
| Mean Time to Restore (MTTR)  | How long an incident takes to resolve             | < 6 hours                            |

Rules:
- The harness's success is measured by DORA. The whole point of the inner-loop quality gate is to keep change-failure-rate down WITHOUT sacrificing deployment-frequency or lead-time.
- An optimization that improves one DORA metric at the expense of another requires an **ADR** documenting the trade-off.
- Throughput-vs-quality is **not** a legitimate trade-off framing. If the framing arises, the right answer is to find the root-cause inefficiency, not to pick a side.

## §15. Decision-trail emission — audit-quality provenance per CL

Every inner-loop completion writes a **decision-trail artifact** that the outer loop and human reviewers can read.

Path: `.harness/trails/TICKET-NNN.md` (matches `decision_trail_ref` in the handoff response).

Required content:
- **Ticket ID, completion timestamp.**
- **Tests added** — paths and what behavior each pins.
- **Production code changes** — files modified, lines added/removed.
- **Refactorings applied** — named (Fowler-catalog form), with the smell each addressed.
- **TDD school chosen for this CL** — Classicist or Mockist, with a one-line reason if not the default.
- **Skills invoked** — at minimum `tdd-pro-cl-workflow`; plus `tdd-pro-batch-cl` and/or `tdd-pro-bash32-portability` if triggered.
- **Quality-gate result** — tests pass count, lint clean (y/n), coverage delta.
- **Deviations** — any rule (R-, G-, C-) that this CL relaxed, with the justification and the ADR ID if applicable.

The decision trail is the **provenance side of the audit story**. It pairs with Grok's research-refs on the outer-loop side to give one auditable trail per ticket end-to-end (foreshadows TICKET-010).

---

## §16. Synthesized rules this repo enforces (Claude-TDD-Pro consumption)

These are the operational rules for consuming Claude TDD Pro in this repo. Numbered `C-N` to keep them distinct from the architectural rules (`R-N`) and the Grok-orchestration rules (`G-N`). Every change inside acceptance-tested scope is checked against this list.

| Rule   | Statement                                                                                                                                                            | Source |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| C-1    | **TDD discipline is non-negotiable.** Every code change inside acceptance-tested scope follows Red → Green → Refactor. Failing test first; minimum code to pass; refactor with tests green. | §1     |
| C-2    | **Three Laws of TDD (nano-cycle).** No production code without a failing test. No more test than is sufficient to fail. No more production code than is sufficient to pass. | §2     |
| C-3    | **Cycles have green checkpoints, never red ones.** You may pause at green; you may not commit, leave the desk, or hand off at red.                                  | §3     |
| C-4    | **Tests are written via `claude-tdd-pro`, not free-hand.** The inner-loop invocation is `claude -p` with the `tdd-pro-cl-workflow` skill enforcing pre-flight → spec → audit → commit. | §11, §12 |
| C-5    | **"Green" is the full gate, not just passing tests.** Green = all tests pass + lint clean + coverage delta ≥ 0 + skill-enforced audit passes. A passing test alone is NOT green. | §12, handoff-contract §quality_gate |
| C-6    | **Refactor only on green.** Fowler-catalog refactorings, one at a time, with the test suite green between each step. No refactor on red, ever.                       | §1, §4 |
| C-7    | **Smells drive refactor priority.** Fowler's smells catalog is the canonical priority list — name the smell before naming the refactoring.                            | §4     |
| C-8    | **Legacy code requires characterization tests first.** When touching code without tests, write characterization tests (Feathers) before any change. Use Sprout/Wrap to add new code in tested isolation. | §5     |
| C-9    | **Test pyramid is honored.** Unit tests dominate; integration tests are a thin middle; E2E is a sparingly-used second line of defense. Inverted pyramids are rejected. | §6     |
| C-10   | **TDD school is chosen explicitly per CL.** Classicist (state-based) is the default; Mockist (interaction-based) is used when the unit's value IS its collaboration contract. Choice is recorded in the decision trail. | §7     |
| C-11   | **No mocking of the system under test.** Mocks are for collaborators only. Mocking the SUT is a test smell that hides design problems.                                | §7     |
| C-12   | **Test names express behavior, not implementation.** Given-When-Then or "should X when Y" form. If a test can't be named cleanly, the design is wrong.               | §7     |
| C-13   | **Coverage is a leading indicator, not a goal.** For high-stakes modules require property-based tests or a mutation-testing pass with a stated survival threshold.   | §8     |
| C-14   | **Headless `claude -p` is the inner-loop contract surface.** Invocations use a structured output format (`json` or `stream-json`); the orchestrator never depends on TUI-only behavior. | §10    |
| C-15   | **`--allowedTools` is scoped per invocation.** Headless calls restrict tool access to what the ticket requires. Default-allow is a permission leak.                  | §10    |
| C-16   | **Skills are consumed by reference, never copied.** The three `tdd-pro-*` skills are imported from `claude-tdd-pro/.claude/skills/`. Vendoring, forking, or inlining is a prime-directive violation (R-1, R-2). | §11, §12 |
| C-17   | **SKILL.md frontmatter is the activation surface.** Rely on `name`/`description` for skill matching. Bypassing progressive disclosure by inlining a skill body is a contract violation. | §11    |
| C-18   | **No skill substitution.** If the TDD trio doesn't cover a discipline a ticket needs, propose a v1.11 amendment in `claude-tdd-pro` — do not add a fourth skill here. | §12, R-1 |
| C-19   | **One ticket = one CL = one atomic, single-purpose commit.** Commit message references `TICKET-NNN`. Scope-creep mid-ticket → split into `.a`/`.b`, never expand the original. | §13    |
| C-20   | **Decision trail is emitted per CL.** Every inner-loop completion writes `.harness/trails/TICKET-NNN.md` with tests added, refactorings, smells addressed, TDD school chosen, skills invoked, gate result, deviations. | §15    |
| C-21   | **Inner loop does NO research and NO deploy.** All research happens in the outer loop; the inner loop rejects (`status: "blocked"`, `error.code: "context_stale"`) past `context_ttl_seconds`. Deploy is never triggered from the inner loop. | architecture.md, handoff-contract.md |
| C-22   | **Substrate touches use `tdd-pro-batch-cl`.** Cross-cutting infrastructure changes (build, lint, CI, hooks) are batched per that skill's rules — never sprinkled into feature commits. | §12    |
| C-23   | **Shell substrate honors `tdd-pro-bash32-portability`.** Any shell script the harness emits passes the bash 3.2 / BSD-tool portability checklist before commit.       | §12    |
| C-24   | **DORA metrics are the scoreboard.** Optimizations that improve deployment frequency, lead time, change failure rate, or MTTR at the expense of another require an ADR. Throughput-vs-quality is not a legitimate trade-off framing. | §14    |

---

## §17. Self-audit checklist (inner-loop changes)

A change is in contract if every answer is YES. Run alongside the architectural checklist (`architecture-principles.md` §17) and the Grok checklist (`grok-orchestration-principles.md` §16).

- [ ] Was the change driven by a failing test that existed BEFORE any production code was written? (C-1, C-2)
- [ ] At every commit/handoff point, are tests GREEN (not just compiling, not just passing some)? (C-3, C-5)
- [ ] Was the inner-loop invocation made through `claude -p` with the `tdd-pro-cl-workflow` skill — not via free-hand editing? (C-4)
- [ ] Is "green" defined as the full quality gate (tests + lint + coverage + audit), and does this change satisfy all of it? (C-5)
- [ ] Were refactorings applied only with tests green, one Fowler-catalog refactoring at a time? (C-6, C-7)
- [ ] If existing untested code was touched, were characterization tests written first, and Sprout/Wrap used to isolate new code? (C-8)
- [ ] Does the resulting test mix honor the pyramid (units dominate; E2E is sparse)? (C-9)
- [ ] Is the TDD school (Classicist vs Mockist) chosen deliberately and recorded in the decision trail? (C-10)
- [ ] Are mocks used only for collaborators — never for the system under test? (C-11)
- [ ] Are test names expressive of behavior (Given-When-Then / "should X when Y"), not of implementation details? (C-12)
- [ ] For high-stakes modules, are property-based or mutation-testing measures in place to backstop line coverage? (C-13)
- [ ] Was the inner-loop call headless (`-p`), with `--allowedTools` scoped to what the ticket needs? (C-14, C-15)
- [ ] Are the three `tdd-pro-*` skills consumed by reference from `claude-tdd-pro`, not vendored or inlined? (C-16, C-17)
- [ ] If a TDD need surfaced that the trio doesn't cover, was it filed as a `claude-tdd-pro` v1.11 amendment proposal rather than bolted on here? (C-18)
- [ ] Is the commit atomic, single-purpose, and tagged with `TICKET-NNN`? Was scope-creep handled by splitting (`.a`/`.b`), not expanding? (C-19)
- [ ] Was a `.harness/trails/TICKET-NNN.md` decision-trail artifact written with all required fields? (C-20)
- [ ] Did the inner loop refrain from any research or deploy action? Was a stale context rejected with `context_stale`? (C-21)
- [ ] If the ticket touched substrate (build/CI/lint/hooks), was `tdd-pro-batch-cl` invoked to govern batching? (C-22)
- [ ] If the ticket touched shell substrate, was `tdd-pro-bash32-portability` satisfied? (C-23)
- [ ] Does this change preserve DORA-metric balance (no velocity sacrificed for stability or vice versa without an ADR)? (C-24)

---

## §18. Authoritative sources

[1] Beck, K. (2002). *Test-Driven Development: By Example.* Addison-Wesley. https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530 · Fowler, M. *bliki: TestDrivenDevelopment.* https://martinfowler.com/bliki/TestDrivenDevelopment.html · Notes: https://stanislaw.github.io/2016-01-25-notes-on-test-driven-development-by-example-by-kent-beck.html
[2] Martin, R. C. *The Three Rules of TDD.* http://www.butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd · *The Cycles of TDD.* https://blog.cleancoder.com/uncle-bob/2014/12/17/TheCyclesOfTDD.html
[3] Fowler, M. (2018). *Refactoring: Improving the Design of Existing Code* (2nd ed., with Kent Beck). Addison-Wesley. https://martinfowler.com/books/refactoring.html · Chapter 3 (Bad Smells) reading sample: http://www.laputan.org/pub/patterns/fowler/smells.pdf
[4] Feathers, M. (2004). *Working Effectively with Legacy Code.* Prentice Hall (Robert C. Martin Series). https://www.amazon.com/Working-Effectively-Legacy-Michael-Feathers/dp/0131177052 · Key points summary: https://understandlegacycode.com/blog/key-points-of-working-effectively-with-legacy-code/
[5] Cohn, M. (2009). *Succeeding with Agile.* (Test Pyramid origin.) · Fowler, M. *The Practical Test Pyramid.* https://martinfowler.com/articles/practical-test-pyramid.html · Fowler, M. *bliki: TestPyramid.* https://martinfowler.com/bliki/TestPyramid.html
[6] Freeman, S. & Pryce, N. (2009). *Growing Object-Oriented Software, Guided by Tests.* Addison-Wesley. · Schools of TDD overview: https://medium.com/geekculture/london-vs-chicago-in-tdd-77067077d0cc · http://codemanship.co.uk/parlezuml/blog/?postid=987
[7] Mutation testing: PIT (Java) https://javapro.io/2026/01/21/test-your-tests-mutation-testing-in-java-with-pit/ · Stryker (JS/TS/C#/Scala) https://oneuptime.com/blog/post/2026-01-25-mutation-testing-with-stryker/view · Comparison with coverage: https://svenruppert.com/2024/05/31/comparing-code-coverage-techniques-line-property-based-and-mutation-testing/ · Property-based testing (Hypothesis): https://www.researchgate.net/publication/337429879_Hypothesis_A_new_approach_to_property-based_testing
[8] Anthropic. *Best practices for Claude Code.* https://code.claude.com/docs/en/best-practices · *How Anthropic teams use Claude Code.* https://www-cdn.anthropic.com/58284b19e702b49db9302d5b6f135ad8871e7658.pdf
[9] Anthropic. *Run Claude Code programmatically (headless mode).* https://code.claude.com/docs/en/headless · CI/CD playbook: https://www.codewithseb.com/blog/claude-code-headless-mode-cicd-automation-playbook
[10] Anthropic. *Agent Skills — overview.* https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview · *Skill authoring best practices.* https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices · *Equipping agents for the real world with Agent Skills.* https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills · Deep dive: https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/
[11] The `tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, and `tdd-pro-bash32-portability` skills are defined in the sibling `claude-tdd-pro` repository at `claude-tdd-pro/.claude/skills/`. Their authoritative documentation is `claude-tdd-pro/CLAUDE.md` and `claude-tdd-pro/docs/architecture-v1.9.md`; this repo does not redefine them.
[12] Atomic-commits literature: https://www.phparch.com/2025/06/atomic-commits-explained-stop-writing-useless-git-messages/ · https://gitbybit.com/gitopedia/best-practices/atomic-commits · https://engineering.leanix.net/blog/atomic-commit/
[13] Forsgren, N., Humble, J., & Kim, G. (2018). *Accelerate: The Science of Lean Software and DevOps.* IT Revolution Press. · DORA Four Keys: https://cloud.google.com/blog/products/devops-sre/using-the-four-keys-to-measure-your-devops-performance · Elite-performer benchmarks: https://linearb.io/blog/dora-metrics · https://www.swarmia.com/blog/dora-metrics/

---

## §19. Amendments

Rules above are immutable in spirit. To revise a rule:

1. Open an ADR in `docs/adr/` (per `architecture-principles.md` §15) that proposes the change, in Nygard format, status `Proposed`.
2. On acceptance, append an entry to this section noting the date, ADR ID, and rules amended.
3. Update the affected rule rows in §16 in the same commit, with a footnote pointing to the ADR.
4. Do not delete prior rule text; if a rule is superseded, mark it `Superseded by ADR-NNNN` rather than removing it.

*(No amendments yet.)*
