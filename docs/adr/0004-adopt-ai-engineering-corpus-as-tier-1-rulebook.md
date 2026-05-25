# ADR-0004 — Adopt `docs/ai-engineering-corpus.md` as a third TIER-1 rulebook

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, supplied verbatim corpus) + Claude (cloud session, persisted)
- **Supersedes:** none
- **Extends:** ADR-0001 (the prime-directive structure), ADR-0002 (verification-tier model), ADR-0003 (first T-A capture; established the canonical transcription discipline)

## Context

On 2026-05-25, drumfiend21 supplied a synthesized "AI Software Development Best Practices Corpus" — a compiled procedural playbook drawing from Karpathy's agentic-engineering shift, Musk's 5-step Algorithm, Anthropic's Claude Code best practices and "Building Effective Agents," Amodei's "Machines of Loving Grace," and cross-referenced ancillary sources. The instruction: *"This is a list of primary directives of how grok-Claude-TDD-pro is to plan and engineer software. Persist it and reference it for all work in the repo and by grok-Claude-TDD-pro."*

The corpus differs in shape from prior `docs/founder-directives.md §1` additions in three important ways:

1. **It is a synthesis, not a primary source.** §1 of the founder-directives rulebook is reserved for verbatim primary text from named voices (X posts, blog posts, essays, documentation pages). The corpus draws *from* those §1 sources and re-shapes them into a procedural playbook — a different artifact category.
2. **It is procedural, not declarative.** Where `docs/founder-directives.md §3` is a list of *what TIER-1 sources we operate under* (declarative directives, D-1 .. D-13), the corpus is a list of *what we do when we sit down to engineer* (procedural playbook). Both authorities are needed; conflating them dilutes both.
3. **It is explicitly living.** drumfiend21's framing was *"This corpus is living—prune, test, and evolve it like CLAUDE.md."* That is the opposite of the §1 invariant (immutable, append-only). Treating the corpus as a §1 entry would force a discipline mismatch.

The cleanest resolution is to adopt the corpus as a **new TIER-1 sibling rulebook**, not as an addition to existing files.

## Decision

### 1. Persist as new file `docs/ai-engineering-corpus.md`

The corpus is persisted in a sibling file under `docs/`, parallel to `docs/founder-directives.md` and the three `-principles.md` rulebooks. Filename matches the user's own naming ("corpus") with the repo's lowercase-kebab convention.

The file contains:

- **Framing matter** (authored by Claude in this CL): authority tier statement, scope, provenance chain table cross-referencing the founder-directives §1 sources, amendment process, pre-commit corpus checklist.
- **Verbatim corpus body** (bit-for-bit reproduction of drumfiend21's 2026-05-25 message text, demarcated by horizontal rules). All curly quotes, em dashes, tab+bullet characters, numbered headers, and prose preserved exactly.

### 2. Elevate to TIER-1 authority

The corpus is elevated to TIER 1, sibling to the prime directive in `CLAUDE.md` and to `docs/founder-directives.md`. The authority tier table in `docs/founder-directives.md §5` is updated to include the corpus as a third TIER-1 entry. The conflict-resolution rule generalizes from "two TIER-1 authorities" to "three TIER-1 authorities" — none defers to the others by default.

### 3. Wire into `CLAUDE.md`

A new top-level section, "Authoritative AI engineering corpus rulebook," is added to `CLAUDE.md` between the existing "Authoritative founder-directives rulebook" section and "Authoritative architectural rulebook" section. The section is structurally parallel to the existing TIER-1 references: states authority tier, lists the pre-engineering reading obligation, points at the amendment process, declares the obligation applies to every session type.

### 4. No new D-rules

The corpus reinforces D-1 (draws-from-Claude-Code), D-3 (terminal states), D-8 (Musk's Algorithm — the corpus's §2 IS D-8's operational form), D-9 (simple composable patterns — corpus §4), D-10 (TDD + supervision — corpus §3 "Verification = Highest Leverage"), D-11 (design FOR agent-CLI primitives — corpus §3 "Persistent Knowledge"), and D-13 (context management — corpus §3 "Context is the #1 Constraint"). No new D-rules are derived because the corpus's authority is at the *playbook* level, not the *directive* level. Treating the corpus as source material for further D-rules would conflate the two authority types.

### 5. Amendment discipline

Unlike `docs/founder-directives.md §1`, the corpus body is **editable**. Amendments follow the ADR process in `docs/architecture-principles.md` §19: open an ADR citing the §-section being amended, edit the corpus, merge ADR + edit in one CL. The amendment trail lives in ADRs and `git log` — not in append-only history within the file. This matches drumfiend21's "living document" framing.

## Alternatives considered

- **Add the corpus as Source 9 in `docs/founder-directives.md §1`.** Rejected: corpus is a synthesis, not a primary source from a named voice. Placing it in §1 would corrupt §1's "verbatim primary text" semantics and force a discipline mismatch (§1 is immutable; corpus is living).
- **Add the corpus as a new section (`§7 Corpus`) inside `docs/founder-directives.md`.** Rejected: the rulebook is already 1,000+ lines after Source 8's T-A capture. Adding a multi-section procedural playbook on top mixes two distinct authority categories (declarative directives vs procedural playbook) in one file. Single-responsibility wins.
- **Inline the corpus directly into `CLAUDE.md`.** Rejected: `CLAUDE.md` is the index of TIER-1 references, not the storage for any single TIER-1 rulebook. Inlining would balloon `CLAUDE.md` and break the established pattern of "CLAUDE.md references the rulebooks; the rulebooks contain the rules."
- **Treat the corpus as merely advisory.** Rejected: drumfiend21's explicit instruction was *"Persist it and reference it for all work in the repo."* That is TIER-1 language, not advisory.

## Consequences

### Positive

- The procedural playbook is captured at the right authority tier and in the right artifact category. The corpus governs *how* engineering happens; the founder-directives govern *what TIER-1 sources we operate under*. Both are TIER-1; neither dilutes the other.
- The repo now has explicit, written guidance for: mindset (English-first programming), the 5-step Algorithm in dev terms, context management, verification, agent and workflow pattern selection, scaling, risk awareness, and the Amodei vision frame — all in one place, citable per CL.
- The pre-commit corpus checklist (in the new file) adds six more concrete checks (explore-plan-implement-commit workflow; Algorithm application; verification in place; context discipline; pattern choice; risk awareness). These compose with the founder-directives D-1..D-13 checklist and the R-/G-/C- checklists.
- The amendment process is honest about which parts of the rulebook hierarchy are immutable (founder-directives §1), which are amendable via ADR (D-rules, R-rules, G-rules, C-rules), and which are explicitly living (the corpus). Future maintainers can edit the corpus without violating any provenance rule, because the corpus does not claim primary-source status.

### Negative

- Number of TIER-1 authorities grows from 2 to 3. The conflict-resolution rule generalizes cleanly ("raise it; none defers"), but operators must now mentally check three rulebooks rather than two before declaring an action authorized.
- `CLAUDE.md` grows by another reference section. Five TIER-1/TIER-2 rulebook sections plus the scope/two-harness-rules sections is approaching the size at which CLAUDE.md itself risks the "over-specified CLAUDE.md" failure pattern (per D-13 and corpus §3). Mitigation: every reference section in CLAUDE.md is kept to ~5 short paragraphs; the actual rule text lives in the referenced files.
- The corpus duplicates substantive content with founder-directives D-rules (e.g., D-8 and corpus §2 both encode Musk's Algorithm; D-13 and corpus §3 both encode context discipline). The duplication is intentional — declarative rule vs procedural playbook serve different operational moments — but it does mean some content changes will require updates in two places.

### Neutral

- `docs/founder-directives.md` is updated only at §5 (authority-tier table) and §3 header is unchanged (D-1 .. D-13 count holds because no new D-rules are derived). The append-only invariant on §1 is preserved.
- Amendment process is the same ADR pattern already used for ADR-0001 through ADR-0003.

## Future work

- **Watch the rulebook count.** If the next addition would create a fourth TIER-1 authority, that's a signal that the categories are over-fragmented; consider consolidating before adding.
- **Watch CLAUDE.md size.** If CLAUDE.md grows past ~5 KB of reference sections, prune. The over-specified-CLAUDE.md failure pattern is a known risk.
- **Promote ancillary primary sources to §1 as T-A captures arrive.** The corpus cites Medium articles, X posts, and the Corporate Rebels analysis of Musk's Algorithm — none currently in `docs/founder-directives.md §1`. If drumfiend21 (or a future operator) supplies verbatim primary text for any of them, a follow-up ADR can elevate them under the existing verification-tier model.
- **Hold the line on corpus growth.** The corpus is currently ~150 lines. Future amendments should preferentially refine existing sections rather than add new ones, per Musk-step-2 (delete before adding) inside the corpus itself.

## Implementation references

- New: `docs/ai-engineering-corpus.md` (framing + verbatim corpus body)
- Updated: `CLAUDE.md` (new "Authoritative AI engineering corpus rulebook" section between founder-directives and architectural sections)
- Updated: `docs/founder-directives.md §5` (authority-tier table now lists three TIER-1 rulebooks; conflict-resolution rule generalized)
- Ticket: `TICKET-001.i` in `TICKETS.md`
- Related: `docs/adr/0001-plugin-lockfile-session-sync.md`, `docs/adr/0002-expand-founder-directives.md`, `docs/adr/0003-persist-claude-code-best-practices-source-8.md`
