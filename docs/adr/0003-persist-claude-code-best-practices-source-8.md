# ADR-0003 — Persist Anthropic "Best practices for Claude Code" as Source 8 (first T-A direct-primary entry)

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** drumfiend21 (architect, supplied verbatim primary text) + Claude (cloud session, persisted)
- **Supersedes:** none
- **Extends:** ADR-0002 (introduced the verification-tier model; this ADR adds the first T-A entry under that model)

## Context

ADR-0002 introduced a four-tier verification model (T-A direct primary / T-B screenshot / T-C search-engine-indexed extract / T-D substantive paraphrase) because every primary URL returned HTTP 403 to WebFetch in the capture session. Sources 3-7 landed at T-C or T-D as a result.

On 2026-05-25, drumfiend21 supplied the verbatim primary text of Anthropic's "Best practices for Claude Code" documentation page (`code.claude.com/docs/...`) directly in the conversation. This is the first opportunity to land a Source at T-A under the verification-tier model — the strongest tier, where the full primary text is captured intact rather than extracted from snippets.

drumfiend21 also signaled that more primary texts are forthcoming ("I am getting the others"), so this ADR doubles as the canonical pattern that subsequent T-A captures will follow.

## Decision

### 1. Add Source 8 to §1 as T-A direct-primary

Source 8: Anthropic, "Best practices for Claude Code" (code.claude.com/docs, accessed 2026-05-25), captured at tier T-A. The full article text is persisted verbatim inline in §1 of `docs/founder-directives.md` per the user's explicit instruction ("Add it to and persist it in the founders file").

### 2. Transcription discipline

The article's heading levels are demoted by two levels relative to the original (article's `#` → §1's `###` source heading; article's `##` → `####`; article's `###` → `#####`) so the article nests cleanly under §1 without colliding with the rulebook's `##`-level section structure. All other content — prose, tables, code blocks, MDX components (`<Tip>`, `<Steps>`, `<Step>`, `<Callout>`, `<Warning>`), hyperlinks, list items — is preserved verbatim. The single heading-demotion transformation is the only departure from bit-for-bit fidelity, and is recorded as such in the Source 8 entry's metadata. This transcription discipline becomes the canonical pattern for all future T-A entries.

### 3. Add D-13

A new directive D-13 — "Context is the fundamental constraint; manage it aggressively and exit named failure patterns early" — is derived from Source 8. It captures the dimension Source 8 opens that D-1..D-12 did not yet cover: context-as-budgeted-resource discipline, and the five named failure patterns (kitchen-sink session, correcting over and over, over-specified `CLAUDE.md`, trust-then-verify gap, infinite exploration).

D-13 is the only new directive derived from Source 8 in this ADR. Other content in Source 8 reinforces existing directives:

- D-1 (Grok-side draws from Claude Code analogs) — reinforced by Source 8's entire CLI primitive catalog.
- D-9 (simple composable patterns) — reinforced by Source 8's CLAUDE.md / skill / subagent / plugin model.
- D-10 (TDD + supervision) — reinforced by Source 8's "Give Claude a way to verify its work" being declared "the single highest-leverage thing you can do."
- D-11 (design FOR agent-CLI primitives) — reinforced by Source 8's "plan mode," "auto mode," `/clear`, `/compact`, `/rewind`, `/init`, `/permissions`, `/sandbox`, `--allowedTools`, headless `-p`, subagents, hooks, skills, MCP, plugins inventory.

These reinforcements are not new D-rules. They are accreted authority for existing D-rules now grounded in a T-A primary instead of T-C/T-D fragments. Future maintainers can quote Source 8 verbatim when defending D-1, D-9, D-10, or D-11 in design review.

### 4. Update `CLAUDE.md`

The "Authoritative founder-directives rulebook" section's count is updated from "twelve numbered directives (D-1 .. D-12)" to "thirteen numbered directives (D-1 .. D-13)" and the §1 provenance summary is extended to include Source 8 with its T-A tier label.

### 5. Self-audit checklist extended

§4 of the rulebook gains a D-13 audit item: "The session producing this CL did not exhibit any of the five named failure patterns. If one appeared and was corrected mid-session, document it briefly in the commit body."

## Consequences

### Positive

- The first T-A entry exists. Future maintainers have a complete primary text — not a fragment — to re-interpret from when reviewing or amending D-rules derived from Source 8.
- The verification-tier model is no longer hypothetical at its strongest tier. T-A has a concrete instance with documented transcription discipline.
- D-13 closes a real gap. Context management was implicit across D-3 / D-10 but never named as a TIER-1 directive in its own right; Source 8 makes it explicit.
- D-1 / D-9 / D-10 / D-11 gain T-A backing without being edited (the §1 entry is new; the D-rules' textual source citations stay as written, but Source 8 is now available as reinforcing authority for design-review defense).
- The pattern is established for "I am getting the others" — subsequent T-A captures land via the same heading-demotion-by-two transcription discipline and the same ADR-per-source amendment process.

### Negative

- §1 of `docs/founder-directives.md` is now substantially larger (Source 8 is multi-thousand-word). The file is now ~50KB+ of text. Still navigable via the §-headings, but no longer the few-screens-of-rulebook it was at TICKET-001.f.
- The heading-demotion-by-two convention is a tiny departure from bit-for-bit fidelity. The verbatim claim is preserved on prose content but the heading hierarchy is altered. This is documented in the Source 8 metadata and was the least-bad option among the considered alternatives (no demotion = §1 structure collision; full code-block wrapping = lost markdown rendering of tables, code blocks, hyperlinks).
- Total D-rule count is now 13, near the soft ceiling of 12 noted in ADR-0002. Additional T-A captures should preferentially reinforce existing D-rules rather than spawn new ones.

### Neutral

- The append-only invariant on §1 is preserved. No prior entry was edited.
- The amendment process (this ADR) is exactly the mechanism D-6 specified.

## Future work

- **More T-A captures.** drumfiend21 has signaled additional primary texts are forthcoming. Each subsequent capture lands via its own ADR, using the same transcription discipline (verbatim prose; heading-demotion-by-two; MDX components and tables preserved as written).
- **T-C → T-A upgrades for Sources 3-7.** When primary URLs become fetchable (network policy change, MCP fetch tool, or user-supplied verified text), open follow-up ADRs that append T-A footnotes. Original T-C / T-D entries stay intact.
- **Hold D-rule count.** Treat D-13 as the new soft ceiling. Subsequent additions preferentially fold into existing rules rather than adding new ones.
- **§1 file-size review.** If §1 crosses a navigation pain threshold after the next few T-A captures, consider an ADR that splits T-A bodies out to `docs/founder-directives-sources/NNN-<slug>.md` and references them from §1. This ADR explicitly does *not* preempt that split because the user's instruction was "in the founders file," and the file size is not yet a problem.

## Implementation references

- Updated: `docs/founder-directives.md` (Source 8 appended to §1 with full verbatim article; §3 header bumped to "D-1 .. D-13"; D-13 appended; §4 checklist extended)
- Updated: `CLAUDE.md` ("Authoritative founder-directives rulebook" count and source summary)
- Ticket: `TICKET-001.h` in `TICKETS.md`
- Related: `docs/adr/0001-plugin-lockfile-session-sync.md`, `docs/adr/0002-expand-founder-directives.md`
