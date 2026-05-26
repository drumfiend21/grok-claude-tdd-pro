# ADR-0024 — Elevate "Grok Build Beta" (x.ai/cli) as `docs/founder-directives.md §1` Source 9 (TICKET-017)

- **Status:** Accepted
- **Date:** 2026-05-26
- **Deciders:** drumfiend21 (architect, 2026-05-26 direction: *"proceed extending the current architecture with the new grok build cli docs informed architecture"*) + Claude (cloud session, implementer)
- **Supersedes:** none
- **Extends:** ADR-0002 (verification-tier model); ADR-0003 (T-A capture pattern, not used here); ADR-0023 (researcher-discipline procedure — THIS is the first §1 entry to cite the procedure doc by path); composes on Source 4 (`x.ai/news/grok-build-cli` launch announcement) — Source 9 is the post-launch product surface, distinct evidence chain

## Context

The user provided two URLs on 2026-05-26 with the instruction "inform architecture":

1. **https://x.ai/cli** — xAI canonical Grok Build product/docs page
2. **https://x.com/Daniel_Farinax/status/2059002180481204461** — Dan (@Daniel_Farinax) X post + video, 2026-05-25, beginner-onboarding demo

Both URLs returned HTTP 403 in the harness capture session (`x-deny-reason: host_not_allowed` — the harness's outbound network policy blocks `x.ai` and `x.com`). This is the standard `host_not_allowed` recovery situation per `docs/researcher-discipline.md §2` (shipped in TICKET-016 immediately prior to this CL).

The §3 fallback chain was applied:

1. WebFetch attempted on both URLs; both returned 403 with `x-deny-reason: host_not_allowed`.
2. WebSearch ran with topical queries; recovered substantial indexed content from the xAI canonical page + 10+ secondary sources.
3. Cross-attribution verified per `docs/researcher-discipline.md §5`: 11 indexed secondary sources for the x.ai/cli content (including `docs.x.ai/build/modes-and-commands` as the primary-operated anchor), all citing the same verbatim phrasing. The Farinax X post yielded only 1 secondary source (the post itself indirectly via search-result snippet), insufficient for T-C.
4. T-C tier applied to x.ai/cli; T-D supplementary reference (not elevated as separate Source 10) for the Farinax post.

Source 4 (`x.ai/news/grok-build-cli`, 2026-05-14) captured the launch ANNOUNCEMENT — one-time event. Source 9 (`x.ai/cli`, 2026-05-26) is the POST-LAUNCH product surface — living documentation with installer command, slash commands, plan-mode rules, extensions composition. Both entries are valid and distinct; Sources 4 and 9 are not redundant.

The new content RATIFIES existing G-rules + the harness composition strategy. It does NOT introduce new architectural patterns warranting new D-rules. Source 9 strengthens existing rule evidence rather than extending the rulebook.

Four design questions had to be resolved:

1. **Source 9 vs. Source 10 framing for the Farinax X post.**
2. **Should new D-rules be derived from Source 9's content?**
3. **Verification tier — T-C or T-D?**
4. **Should `docs/grok-orchestration-principles.md` body be amended to cite Source 9 alongside the existing Source 4 citations?**

## Decision

### 1. Single Source 9; Farinax X post folded as supplementary, not elevated as Source 10

The Farinax X post demos Source 9's installer command + workflow; it has no INDEPENDENT architectural content. Per `docs/researcher-discipline.md §5`, single-secondary-source content is T-D not T-C; elevating it as its own Source 10 would require either fabricating a T-C tier (anti-pattern §8) or accepting a T-D entry with no independent architectural weight (D-13 kitchen-sink).

Solution: document the URL inside Source 9's verification block as a supplementary reference with explicit T-D paraphrase tier. The URL stays in the architectural record; the lower evidence weight is honest; no Source 10 inflation.

### 2. No new D-rules

Source 9's content ratifies these existing rules:

- **G-7** (Orchestrator-Worker — *"specialized subagents, with each child running in parallel with its own context window"*).
- **G-8** (Parallel via git worktrees — implied by parallel subagents; consistent with existing Source 4 detail).
- **G-9** (Bounded fan-out — implied; not explicitly contradicted).
- **G-10** (AGENTS.md is normative — *"Your AGENTS.md, plugins, hooks, skills, and MCP servers all work out of the box"*).
- **G-12** (Plan-first for non-trivial work — *"Plan mode is for planning first. When it is active, write tools are blocked except for the session plan file"*).
- **D-11** (Design FOR existing primitives — confirmed by cross-tool composition).

None of the above are NEW. The §3 D-rule bodies remain at D-1..D-13. Source 9 is evidence-strengthening, not rule-extending. Future D-rule derivations wait for genuinely new architectural patterns from a subsequent source.

### 3. T-C tier

Per `docs/researcher-discipline.md §4 + §5` acceptance bar:

- ≥ 3 secondary sources: **11 sources captured**, including `docs.x.ai/build/modes-and-commands`, `skywork.ai/clihub/keywords/grok-cli.html`, `aimadetools.com/blog/grok-build-complete-guide`, `basenor.com/blogs/news/xai-launches-grok-build-beta-agentic-coding-cli-explained`, `pasqualepillitteri.it/en/news/2584/grok-build-xai-cli-2026`, `releasebot.io/updates/xai`, `codersera.com/blog/how-to-install-grok-build-cli-2026/`, `chatforest.com/reviews/xai-grok-build-coding-agent-cli-review-2026/`, `verdent.ai/guides/grok-for-coding-2026`, `cryptobriefing.com/xai-grok-cli-windows-powershell/`, `digitalapplied.com/blog/xai-grok-build-cli-parallel-coding-agents`. ✓
- At least one primary-operated domain: **docs.x.ai is primary-operated** (xAI's own docs subdomain). ✓
- Reject SEO-spam: each secondary source has editorial signal (industry blog, tech news, vertical-specific guide). No aggregator-spam rejected by reputation. ✓
- Consistent verbatim phrasing across sources: ✓ for the four key passages quoted (positioning, install command, plan-mode wording, extensions composition wording).

All four bars cleared; T-C is the appropriate tier.

### 4. No `docs/grok-orchestration-principles.md` body amendment

The G-rules already cite Source 4 (`x.ai/news/grok-build-cli`) in their §1 references. Adding Source 9 citations alongside is technically possible but operationally unnecessary at v1: the existing G-rule bodies are byte-stable; Source 9 strengthens evidence without changing the rule text. Per D-8 (delete the part), the G-rules' §1 reference table can be extended in a future ADR if and only if operationally bitten. For now, the G-rules' authority is unchanged; Source 9's evidence is discoverable via `docs/founder-directives.md §1`.

## Alternatives considered

- **Elevate the Farinax X post as Source 10.** Rejected per Decision-1. T-D evidence with no independent architectural weight; would inflate §1 without earning the elevation per D-13.
- **Derive a new D-rule for "convergence with Grok Build's slash commands"** (`/hooks`, `/plugins`, `/skills`, `/mcps`). Rejected. Convergence is evidence of D-1 (cross-tool patterns inform each other), already covered. The harness's own `.cursor/commands/` surface (TICKET-014) uses different command names; this is healthy cross-tool diversity, not a D-rule trigger.
- **T-D for Source 9** (more conservative than T-C). Rejected. The cross-source acceptance bar per `docs/researcher-discipline.md §5` is met (11 sources, primary-operated anchor, consistent verbatim phrasing); downgrading to T-D would misrepresent the actual evidence base.
- **Edit Source 4 to add a "see Source 9 for post-launch detail" cross-reference.** Rejected per D-6 (§1 immutability). Source 4 stays byte-stable; Source 9 references Source 4 by way of distinction in its own opening paragraph; the cross-reference flows Source 9 → Source 4, never the reverse.
- **Skip CLAUDE.md update** (don't re-list sources). Rejected per D-7 (CLAUDE.md still references the rulebook + its sources). The Sources list in CLAUDE.md is the discoverability surface; new sources need to appear there or future readers won't know the elevation happened.
- **Add the slash commands (`/hooks`, `/plugins`, `/skills`, `/mcps`) to the harness's own `.cursor/commands/` set.** Rejected per D-13 (kitchen-sink resistance). The harness has its own slash-command surface (TICKET-014); convergence with Grok Build's naming is cross-tool composability evidence (D-1), not a directive to reimplement.

## Consequences

### Positive

- **TICKET-017 acceptance criterion met.** Source 9 lands as a single §1 append; verification block explicit at T-C; CLAUDE.md updated; AUTOMATION_INTEL.md logged.
- **First §1 entry to cite `docs/researcher-discipline.md` by path.** Establishes the procedural citation pattern for all subsequent §1 entries. Future researchers can cite the procedure rather than re-asserting it inline.
- **The user's "inform architecture" direction operationally honored.** Both URLs are now in the architectural record (x.ai/cli at T-C; Farinax X post at T-D supplementary). Neither URL was fabricated; both have explicit evidence-tier records.
- **R-3 (single source of truth) preserved.** Source 9's content is verbatim where possible; the procedure for capture is cited by path to `docs/researcher-discipline.md`, not re-inlined.
- **R-2 (versioned consumption) preserved.** No upstream `claude-tdd-pro/` edits; no vendoring; the §1 elevation is harness-side documentation only.
- **D-6 (§1 immutable + append-only) honored.** Sources 1-8 byte-identical post-CL (verifiable via `git diff`). Only Source 9 lines added.
- **D-7 (CLAUDE.md references the rulebook + sources)** honored and extended (Source 9 added to the sources list).
- **D-8 (deletion pass)** honored: 5 named rejections in §Alternatives (Source 10 elevation, new D-rule derivation, T-D downgrade, Source 4 edit, slash-command-import).
- **D-12 (production-grade trust)** strengthened. T-C tier honestly recorded; supplementary T-D content honestly labeled.
- **D-2 (enterprise context)** evidence broadened. Grok Build Beta GA distribution (SuperGrok + X Premium Plus subscribers) is enterprise-scale signal; Source 9's installer command + extensions-out-of-the-box are operationally relevant to >1,000-IC orgs.

### Negative

- **T-C tier remains lower-fidelity than T-A.** If the harness's outbound network policy is later updated to allow `x.ai`, a T-A supplement can be added per `docs/researcher-discipline.md §7` future-de-blocking-path. Until then, T-C is the accurate record.
- **Farinax X post at T-D is the weakest evidence in §1.** Mitigation: the entry is supplementary (inside Source 9's verification block, not a standalone Source). T-D phrasing makes the evidence weight explicit.
- **Source 9 ratifies G-rules without extending them.** A future reader expecting D-rule expansion from a new §1 source may be surprised. Mitigation: ADR-0024 explicitly records "no new D-rules; evidence-strengthening only"; future D-rule expansion can cite the gap if a new source eventually justifies it.
- **`docs/grok-orchestration-principles.md` body still cites only Source 4.** Not updated in this CL. Mitigation: explicit deferral per Decision-4 + §Out-of-scope.

### Neutral

- **D-rule count unchanged** (D-1 .. D-13).
- **TIER-0 corpus untouched.**
- **§3 D-rule bodies untouched.**
- **§4 D-checklist untouched** (D-1 reverse from ADR-0013 already covers this CL).
- **§5 authority-tier table unchanged.**
- **`schema_version` of the handoff contract unchanged.**
- **AGENTS.md unchanged** in this CL (the prior TICKET-016 CL added the discipline doc to AGENTS.md §5; this CL is §1 elevation only, doesn't touch AGENTS.md).
- **`.cursor/rules/` unchanged** (this CL doesn't touch the generator).

## Verification (executed before commit)

- Source 9 present in §1: `grep -q "^### Source 9 — xAI" docs/founder-directives.md` exits 0.
- Sources 1-8 untouched: `git diff docs/founder-directives.md | grep -E "^[+-]### Source [1-8]"` returns empty.
- §2 boundary preserved: Source 9 inserted between Source 8's closing horizontal-rule and `## §2 Scope`.
- Verification tier explicit: `grep -q "T-C" docs/founder-directives.md` succeeds within the Source 9 block.
- T-D supplementary tag explicit for the Farinax X post: grep for "T-D paraphrase" inside Source 9 block.
- CLAUDE.md updated: `grep -q "x.ai/cli" CLAUDE.md` exits 0.
- ADR-0024 follows the numbered template.
- AUTOMATION_INTEL.md gains a 2026-05-26 entry for Source 9 + installer command.
- `./scripts/audit-doc-drift.sh` exits 0 (F-1..F-6 clean — no F-3 triggered because Source 9 is a new APPEND, not a future-tense reference to a DONE ticket).
- `./scripts/smoke-e2e.sh` exits 0.
- `./scripts/export-cursor-rules.sh --check` exits 0.
- `./scripts/audit-manifest.sh` exits 0.
- TICKETS.md gains TICKET-017 row marked DONE.

## Out of scope (deferred)

- **`docs/grok-orchestration-principles.md` body amendment** to cite Source 9 alongside Source 4. Defer per Decision-4 / D-8 until operationally bitten.
- **T-A re-verification of Source 9** when the harness outbound network policy allows `x.ai`. Per `docs/researcher-discipline.md §7`, the original T-C entry stays + a T-A supplement appends as a separate sub-block.
- **Source 10 elevation for the Farinax X video.** Folded as T-D supplementary in Source 9; ADR amendment can elevate if it ever gains independent architectural weight.
- **New D-rules from Grok Build Beta features.** Source 9 ratifies; defer until a genuinely new pattern emerges.
- **Harness adoption of Grok Build's `/hooks` / `/plugins` / `/skills` / `/mcps` slash commands.** D-1 cross-tool composability is the right framing; the harness's own `.cursor/commands/` surface stays per TICKET-014. No D-13 kitchen sink.
- **Plugin pin bump ADR** (separate concern from Source 9; the pin drift WARN is its own deferred decision).
- **Promotion of `provenance_complete` quality-gate sub-gate to REQUIRED.** Independent quality-gate v2 ADR per TICKET-010.a/b/c trilogy.

## Implementation references

- Modified: `docs/founder-directives.md §1` — APPEND Source 9 between Source 8 closing and `## §2 Scope`. Sources 1-8 untouched per D-6.
- Modified: `CLAUDE.md` — Sources list extended to include Source 9 + procedural cross-reference to `docs/researcher-discipline.md`.
- Modified: `AUTOMATION_INTEL.md` — append 2026-05-26 entry noting Source 9 elevation + Grok Build Beta GA distribution + installer command.
- Modified: `TICKETS.md` — TICKET-017 row marked DONE.
- New: this ADR.
- Related: ADR-0002 (verification-tier model), ADR-0023 (researcher discipline — Source 9 is the first §1 entry to cite the procedure doc by path), ADR-0006 (Grok templates — composes on the AGENTS.md normative claim Source 9 ratifies via G-10), ADR-0013 (D-1 bidirectional attribution — Source 9 is a Grok-side ratification; the reverse Cursor/Claude analog is documented in `AGENTS.md §6` outer-loop pointers), Source 4 (the launch announcement Source 9 distinguishes from).
