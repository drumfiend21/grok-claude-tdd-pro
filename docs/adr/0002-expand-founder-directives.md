# ADR-0002 — Expand founder-directives rulebook with publicly available xAI / Anthropic / Musk-orbit sources

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect) + Claude (cloud session)
- **Supersedes:** none
- **Extends:** ADR-0001 (founder-directives rulebook structure was created in TICKET-001.f; this ADR amends the §1 provenance and §3 D-rules under that structure)

## Context

`docs/founder-directives.md` was established in TICKET-001.f with two §1 provenance entries (the @teslayoda + @elonmusk X posts from 2026-05-24) and seven derived D-rules (D-1 .. D-7). The user, on 2026-05-25, directed the rulebook to be expanded with publicly available statements from:

- Elon Musk's personal X account and interviews
- Elon's companies' (xAI, Tesla, SpaceX, etc.) X accounts and publications
- Employees (and ex-employees) of those companies
- Their websites
- Anthropic / Claude publications

— restricted to material providing direction on software engineering with Grok, Claude, and AI.

D-6 stipulates that §1 entries are immutable and append-only, and that new §1 entries land via ADR. This ADR is the formal record of the expansion.

## Constraint discovered during capture

The capture session encountered a tooling constraint: `WebFetch` returned HTTP 403 (anti-bot) on every primary source attempted — `anthropic.com`, `x.ai`, `darioamodei.com`, `lesswrong.com`, `forum.effectivealtruism.org`, `simonwillison.net`, `engadget.com`, and `web.archive.org` (explicitly blocked at the tool layer). `WebSearch` returned indexed snippets containing verbatim fragments lifted from the primary pages, but not the full primary text.

D-6 demands verifiable provenance. Committing search-engine-indexed extracts *as if* they were direct-primary quotes would corrupt §1. The resolution was to introduce a **verification-tier model** to §1 itself, so each entry's verification status is part of the immutable record.

## Decision

### 1. Introduce a verification-tier model in §1

Four tiers, ordered strongest to weakest:

- **T-A — Direct primary**: text fetched from the primary URL within the capture session and quoted verbatim.
- **T-B — Screenshot of primary**: text transcribed from a user-supplied screenshot of the primary source.
- **T-C — Search-engine-indexed extract**: text appearing inside quotation marks in one or more search-engine result snippets indexed from the primary URL; primary URL inaccessible at capture session.
- **T-D — Substantive paraphrase**: substance attested by multiple secondary sources, but exact verbatim wording not verified at capture.

The tier is itself part of the immutable record. A T-C or T-D entry remains at that tier in the historical layer even after a T-A upgrade is added by a future ADR.

### 2. Add five new §1 sources

| # | Author / Title | Date | Tier |
|---|---|---|---|
| 3 | Elon Musk — "The Algorithm" (5-step engineering process) | ~2021 | T-C |
| 4 | xAI — "Introducing Grok Build" (`x.ai/news/grok-build-cli`) | 2026-05-14 | T-C |
| 5 | Erik Schluntz & Barry Zhang (Anthropic) — "Building Effective Agents" | 2024-12-19 | T-C |
| 6 | Dario Amodei — "Machines of Loving Grace" | 2024-10 | T-D |
| 7 | Andrej Karpathy — agentic-engineering workflow shift | 2026-01-26 | T-C |

### 3. Derive five new D-rules

| # | Headline | Anchored to |
|---|---|---|
| D-8 | Apply Musk's Algorithm: question requirements, delete before optimizing | Source 3 |
| D-9 | Choose simple, composable patterns over complex frameworks | Source 5 |
| D-10 | TDD is the strongest pattern for agentic coding; supervise when code matters | Sources 5 + 7 |
| D-11 | Design FOR the agent-CLI primitives (plan/diff/sub-agents/worktree/headless/ACP), not AROUND them | Source 4 |
| D-12 | The harness's value is production-grade trustability of AI-generated code, not faster generation | Source 6 |

### 4. Broaden the rulebook's scope statement

The introductory paragraph in `docs/founder-directives.md` was widened from "named-source statements from xAI leadership and figures engaged with directly in public by xAI leadership" to also cover Anthropic leadership and ex-Musk-company AI leadership voices (Karpathy). The user explicitly authorized this broadening on 2026-05-25.

### 5. Update `CLAUDE.md`

The "Authoritative founder-directives rulebook" section count was updated from "seven numbered directives (D-1 .. D-7)" to "twelve numbered directives (D-1 .. D-12)," and the §1 provenance summary now lists all seven elevated sources plus a pointer to the verification-tier model.

## Consequences

### Positive

- The rulebook now reflects the broader landscape of leadership voices steering AI-assisted engineering, rather than a single snapshot pair of X posts.
- Verification tiers make uncertainty in provenance *visible* rather than hidden — future maintainers can immediately see which entries are weakest and prioritize verbatim upgrades.
- D-8 through D-12 close concrete gaps that the original D-1..D-7 set didn't address (deletion discipline, pattern-taxonomy choice, supervision discipline, agent-CLI primitive composition, harness-value positioning).

### Negative

- Some §1 entries (notably Source 6 at T-D) carry weaker provenance than ideal. The verification-tier label is honest about this, but a maintainer relying on the immutable layer must check the tier before quoting an entry as authoritative.
- The total D-rule count is now 12. This is still within the healthy 10–16 range observed in mature tenets documents (Amazon Leadership Principles: 16; Stripe Operating Principles: ~10), but additional expansion should be resisted unless a new source materially adds an unaddressed dimension.
- The verification-tier model adds a small amount of structural overhead to §1. Worth it for the honesty gain.

### Neutral

- The append-only invariant on §1 is preserved. No entry was edited or removed; tier labels are inherent to each entry from its creation.
- The amendment process (this ADR) is exactly the mechanism D-6 specified.

## Future work

- **T-C → T-A verbatim upgrades.** Once `WebFetch` access to `anthropic.com`, `x.ai`, `darioamodei.com`, etc. becomes available (network policy change, MCP fetch tool, or user-supplied verified quotes), open a follow-up ADR that adds a T-A footnote to each upgraded entry. The original T-C/T-D entry text stays intact.
- **Tesla AI / SpaceX engineering publications.** The user-named scope included these surfaces. No sources from Tesla's `tesla.com/AI` or SpaceX's published engineering material made it into this expansion because no high-signal direction-setting statement on AI-assisted software engineering surfaced in the searches. A future search pass targeting Tesla AI Day, SpaceX raptor-iteration cadence, or recent xAI blog posts on agent infrastructure could land additional §1 entries.
- **Hold the line on D-rule count.** Treat D-12 as the soft ceiling. Future additions should preferentially fold into existing D-rules rather than adding new ones, unless a genuinely new dimension surfaces.

## Implementation references

- Updated: `docs/founder-directives.md` (§1 expanded, §3 D-8..D-12 added, §4 checklist extended)
- Updated: `CLAUDE.md` ("Authoritative founder-directives rulebook" section count and source summary)
- Ticket: `TICKET-001.g` in `TICKETS.md`
- Related: `docs/adr/0001-plugin-lockfile-session-sync.md`
