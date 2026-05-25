# ADR-0005 — Elevate `docs/ai-engineering-corpus.md` to TIER 0 (supreme operating directive)

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, explicit instruction) + Claude (cloud session, persisted)
- **Supersedes:** none
- **Extends:** ADR-0004 (which adopted the corpus as a third TIER-1 sibling rulebook)

## Context

ADR-0004 adopted `docs/ai-engineering-corpus.md` as a TIER-1 rulebook, co-equal with the `CLAUDE.md` prime directive and `docs/founder-directives.md`. The conflict-resolution rule under that structure was "three TIER-1 authorities, none defers, raise conflicts explicitly."

On 2026-05-25, drumfiend21 issued an explicit instruction:

> Make as and persist `docs/ai-engineering-corpus.md` the highest priority ruleset and instruction for architecture, planning and development done in the repo of and by grok-Claude-TDD-pro.

That is unambiguous TIER-0 language: the corpus is to be elevated above the existing TIER-1 authorities, becoming the supreme operating directive for the repo. The phrasing "of and by" extends the supremacy to both *work done on this repo* and *work performed by this repo's agents*.

## Decision

### 1. Introduce TIER 0 as a new top tier in the authority hierarchy

Authority tiers across the repo are restructured as follows:

| Tier | Rulebook | Role |
|---|---|---|
| 0 | `docs/ai-engineering-corpus.md` | **Supreme operating directive.** Highest-priority ruleset for all architecture, planning, and development. Above everything. |
| 1 | `CLAUDE.md` prime directive | Plugin-dependency invariants. Non-negotiable beneath TIER 0. |
| 1 | `docs/founder-directives.md` (D-1 .. D-13) | Provenance + derived directives. Co-equal with the prime directive, beneath TIER 0. |
| 2 | `docs/architecture-principles.md` (R-1 .. R-20) | Architectural design and code structure. |
| 2 | `docs/grok-orchestration-principles.md` (G-1 .. G-21) | `.grok/` and Grok-facing surfaces. |
| 2 | `docs/claude-tdd-pro-principles.md` (C-1 .. C-24) | Acceptance-tested inner-loop work. |

### 2. New conflict-resolution rule

When this corpus conflicts with ANY other rulebook in the repo — the prime directive, founder-directives D-rules, R-rules, G-rules, or C-rules — the corpus wins. There is no rulebook above TIER 0; the only legitimate override of the corpus is an explicit, named amendment to the corpus itself landed via the standard ADR process. Silent relaxation, deferred interpretation, or implicit override is forbidden.

The TIER-1 / TIER-1 conflict rule (prime directive vs founder-directives) is unchanged: when they conflict with each other, raise it explicitly. Neither defers to the other.

### 3. `CLAUDE.md` restructuring

The "Authoritative AI engineering corpus rulebook" section that existed in CLAUDE.md after ADR-0004 (positioned between founder-directives and architectural rulebook) is **moved to the top** of CLAUDE.md and **renamed** to "Supreme operating directive (TIER 0): AI engineering corpus." It now appears as the first authority section after the title intro, ahead of the prime directive.

The prime-directive section heading is updated to "Prime directive: plugin-dependency model (TIER 1, non-negotiable beneath TIER 0)" and its closing paragraph is updated to acknowledge that the corpus sits above it. The founder-directives section heading is updated to "Authoritative founder-directives rulebook (TIER 1, co-equal with prime directive beneath TIER 0)" with corresponding body update to its tier statement.

### 4. `docs/ai-engineering-corpus.md` framing updated

The "Authority tier" section in the corpus file now declares TIER 0 supremacy explicitly, names drumfiend21's 2026-05-25 instruction as the elevation source, references this ADR, and reproduces the new tier table.

### 5. `docs/founder-directives.md §5` updated

The authority-tier table in founder-directives §5 is updated to show three tiers (0, 1, 2), the corpus as TIER 0, prime directive + founder-directives as TIER 1, and the R-/G-/C- rulebooks as TIER 2. The conflict-resolution paragraph below the table is updated to encode the new ordering.

### 6. No D-rule changes

D-1 through D-13 are unchanged. The elevation does not alter what any directive *says*; it alters which directive *wins* in a conflict. The founder-directives §3 D-rules continue to govern declarative obligations; the corpus continues to govern procedural playbook; the corpus now beats founder-directives when they conflict (previously: tied, raise to human).

## Alternatives considered

- **Keep TIER-1 with explicit precedence rule ("corpus wins over the other two TIER-1 authorities in conflict").** Rejected: that is functionally equivalent to TIER 0, but obscures the hierarchy in prose rather than naming it. The user's instruction was supremacy; supremacy is a tier-level concept and should be named at the tier level.
- **Make the corpus TIER 0 *only* for architecture / planning / development, leaving the prime directive supreme for plugin-coupling questions.** Rejected: the user said "architecture, planning and development" — a phrasing broad enough to cover plugin-coupling decisions (which are themselves architectural choices). The cleaner model is one supreme authority with the prime directive surviving as TIER 1 within its narrower scope (plugin coupling questions virtually never appear in the corpus's content surface, so the practical conflict surface is small).
- **Demote the prime directive and founder-directives to TIER 2.** Rejected: those rulebooks still encode invariants and directives that are not procedural-playbook content. Demoting them would conflate authority and content type. Keeping them at TIER 1 beneath TIER 0 preserves clean role separation.

## Consequences

### Positive

- The authority hierarchy now matches the user's stated intent unambiguously. The corpus is supreme; no ambiguity about which rulebook to defer to.
- Conflict resolution is simpler than under the prior "three co-equal TIER-1 authorities, raise on conflict" model. Most conflicts now have a written winner.
- The TIER 0 / TIER 1 / TIER 2 tiering is more honest about the practical role separation: a procedural playbook (corpus) outranks invariants (prime directive) and provenance-driven directives (founder-directives) for day-to-day architectural and engineering work.

### Negative

- Theoretically, the corpus could be amended in a way that conflicts with the plugin-dependency invariants (e.g., a future corpus edit could conceivably authorize cross-repo edits to claude-tdd-pro). The amendment ADR process is the safeguard: any such corpus edit would require an ADR that explicitly addresses the conflict with the prime directive. In practice, the corpus's content surface (mindset, Musk's Algorithm, Claude/Grok interaction practices, agent patterns, scaling, risk awareness) does not overlap with the prime directive's content surface (plugin coupling, vendoring, contract surface, release cadence).
- The supremacy framing increases the weight of every future corpus amendment. Future maintainers must treat corpus edits as architecturally significant (which is correct; the corpus IS architecturally significant).
- Three tier labels (0/1/2) is one more than the previous two (1/2). Slightly more cognitive overhead, but the tier names are short and the table is small.

### Neutral

- D-rule count remains 13. No content edits to D-rules.
- §1 of founder-directives remains untouched. The append-only invariant is preserved.
- ADR-0004's adoption of the corpus as a TIER-1 sibling stands as the historical record of the initial adoption; this ADR amends the tier label without retracting ADR-0004's decision to adopt.

## Future work

- **Watch corpus-vs-prime-directive collisions.** If future corpus amendments approach plugin-coupling territory, raise the ADR-required signal early. Corpus content should stay within its declared scope (mindset, procedural playbook, agent patterns, scaling, risks, vision).
- **Watch CLAUDE.md size.** With TIER 0 section now at the top, prime directive at TIER 1, founder-directives at TIER 1, three TIER-2 references, scope section, two-harness-rules, working-in-this-repo, and what-this-repo-does-NOT-do sections, CLAUDE.md is approaching the "over-specified" boundary. Consider a prune pass in a future CL.
- **Hold the tier count at 0/1/2.** Introducing a TIER 3 or TIER -1 would signal over-fragmentation. Future authority additions should fit within the existing three tiers.

## Implementation references

- Updated: `CLAUDE.md` ("Supreme operating directive (TIER 0)" section added at top; original "Authoritative AI engineering corpus rulebook" TIER-1 section deleted; prime-directive and founder-directives section headings + tier statements updated)
- Updated: `docs/ai-engineering-corpus.md` ("Authority tier" section rewritten to declare TIER 0 supremacy and reference this ADR)
- Updated: `docs/founder-directives.md §5` (tier table now shows three tiers; conflict-resolution paragraph updated)
- Ticket: `TICKET-001.j` in `TICKETS.md`
- Related: `docs/adr/0001-plugin-lockfile-session-sync.md`, `docs/adr/0002-expand-founder-directives.md`, `docs/adr/0003-persist-claude-code-best-practices-source-8.md`, `docs/adr/0004-adopt-ai-engineering-corpus-as-tier-1-rulebook.md`
