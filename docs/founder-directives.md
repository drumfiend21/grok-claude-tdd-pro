# Founder Directives — grok-claude-tdd-pro

This document is the operational rulebook for grok-claude-tdd-pro's response to **founder-level directives** — named-source statements from xAI leadership and figures engaged with directly in public by xAI leadership, which the architecture team has elevated to repo-canonical authority.

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

## §2 Scope

These directives apply to **every** session type (local CLI, remote, cloud, GitHub Action, IDE) and **every** component of the harness — this repo, the consumption pattern around the `claude-tdd-pro` plugin, the `.grok/` orchestration layer, the `.claude/` consumption layer, the handoff contract, all skills, all hooks, all sub-agents, all monitors.

They override default Claude behavior and any contradictory instruction not explicitly marked as superseding these directives. Amendments follow the ADR process in `docs/architecture-principles.md` §19 — never edit a D-rule in place, and never edit a §1 provenance entry under any circumstance.

## §3 Directives (D-1 .. D-7)

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

## §4 Self-audit checklist (pre-commit)

Before every commit, the author — human or agent — confirms:

- [ ] (D-1) If a new Grok-side primitive was added, its Claude Code and/or Cursor analog is documented in the PR description or an accompanying ADR.
- [ ] (D-2) The change is sane for a >1,000-IC enterprise deployment context, or its gap is filed as an ADR with a stated path to closing it.
- [ ] (D-3) Every loop touched by the change has a written, machine-checkable terminal condition.
- [ ] (D-4) The commit message states the difficulty metric and how this CL is strictly harder than the previous.
- [ ] (D-5) If post-TICKET-005, the change targets a real (non-toy) problem instance.
- [ ] (D-6) §1 of this document remains untouched. New §1 entries (if any) landed via ADR.
- [ ] (D-7) `CLAUDE.md` still references this document under "Authoritative founder-directives rulebook."

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
