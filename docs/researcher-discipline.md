# Researcher discipline for `docs/founder-directives.md §1` source verification

Status: TIER-2 operational rulebook (companion to `docs/self-healing-design.md`, `docs/quality-gate.md`, `docs/cursor-integration.md`, `docs/provenance-bridging-design.md`).
Authority: composes on the TIER-0 supreme operating directive (`docs/ai-engineering-corpus.md`), the TIER-1 prime directive (`CLAUDE.md`), the TIER-1 founder-directives rulebook (`docs/founder-directives.md`). The verification-tier MODEL lives in `docs/founder-directives.md §1` (immutable); this doc operationalizes USE of the model — a strictly TIER-2 procedural sibling.
Originating ADR: ADR-0023.

## §1 Purpose

When a researcher (human operator or coding agent) attempts to elevate a new primary source to `docs/founder-directives.md §1` and the harness's outbound network policy returns `host_not_allowed`, this doc names the canonical recovery procedure. The procedure produces a defensible T-A / T-B / T-C / T-D verification tier per ADR-0002, NOT a fabricated entry.

This is a recurring class of problem. As of 2026-05-26, six §1 sources have hit it: Source 4 (`x.ai/news/grok-build-cli`), Source 5 (`anthropic.com/research/building-effective-agents`), Source 6 (Amodei "Machines of Loving Grace"), Source 7 (Karpathy agentic shift), Source 8 (Anthropic Best Practices for Claude Code — though Source 8 succeeded at T-A via persistence), and Source 9 (`x.ai/cli` per TICKET-017). Without a discoverable procedure, every future researcher rediscovered the workaround from ADR-0002's prose. This doc extracts the procedure into an operator-facing rulebook so the rediscovery cost is zero.

The doc explicitly does NOT:

- Edit `docs/founder-directives.md §1` (immutable per D-6).
- Replace the verification-tier MODEL (lives in §1; immutable).
- Promise the recovery procedure will always succeed (some URLs are unrecoverable; T-D paraphrase or deferral are documented outcomes).

## §2 Diagnosis — identify the block class

Before applying the fallback chain, identify WHY the URL failed. Different block classes warrant different procedures.

Run a header probe (read-only; consistent with the existing `scripts/sync-plugin.sh --check` header-inspection pattern):

```sh
curl -sIL -A "Mozilla/5.0 (compatible; ClaudeBot/1.0)" "<URL>" 2>&1 | head -20
```

Map the response:

| Header signal | Block class | Action |
|---|---|---|
| `HTTP/2 403` with `x-deny-reason: host_not_allowed` | **Harness outbound policy** | Apply §3 fallback chain. Most common case. |
| `HTTP/2 403` with no `x-deny-reason` (Cloudflare-style) | **Upstream bot protection** | Apply §3 fallback chain. WebSearch backend may bypass. |
| `HTTP/2 401` or `HTTP/2 403` with `WWW-Authenticate: ...` | **Authenticated resource** | Out of scope for §1 elevation; primary sources should be public. Defer / mark T-D / use authenticated MCP tool if available. |
| `HTTP/2 404` | **URL invalid or moved** | Verify URL with the operator before any elevation attempt. |
| `HTTP/2 5xx` | **Upstream outage** | Retry after delay; if persistent, switch to §3 fallback. |
| `HTTP/2 200` but WebFetch still failed | **Tool issue, not block** | Re-attempt WebFetch with a refined prompt; usually succeeds on retry. |

The `x-deny-reason: host_not_allowed` signal is the harness's proxy explicitly refusing the host. As of 2026-05-26, observed for: `x.ai/*`, `x.com/*`, `anthropic.com/*` (some paths), `darioamodei.com/*`, `karpathy.ai/*` (when applicable). The list is not enumerated anywhere in the codebase by design — the network policy is operator-configurable per environment and this doc must remain stable across policy changes.

## §3 Fallback chain — WebFetch → WebSearch → indexed secondary sources

When the URL is blocked at the harness's outbound proxy (the most common case per §2):

### Step 3.1 — Attempt WebFetch first

WebFetch's purpose is direct content recovery; it is the highest-fidelity path. Even when policy blocks the host, the failure mode is informative (the error message often reveals the block class). Always attempt WebFetch first; never skip it on assumption.

### Step 3.2 — Fall back to WebSearch (different backend)

WebSearch uses a search-engine API backend, not direct fetch. It routinely succeeds for `host_not_allowed`-blocked hosts because the search engine indexed the page from outside the harness's proxy.

```
WebSearch query: "<canonical URL slug>" OR "<exact phrase from page title>"
```

Or broader:

```
WebSearch query: <product/topic> <author/org> <date>
```

WebSearch returns indexed snippets + secondary-source URLs that cite the primary. The snippets often contain verbatim quotes from the primary page.

### Step 3.3 — Cross-attribute across multiple secondary sources

Per ADR-0002's T-C tier definition: a single secondary source is paraphrase (T-D); verbatim phrasing is recovered when multiple secondary sources cite the SAME phrasing from the primary. Use this rule:

- **≥ 3 indexed secondary sources** quoting the same phrase, attributed to the same primary URL → T-C.
- **1-2 secondary sources** quoting consistently → T-D paraphrase, NOT T-C.
- **Inconsistent secondary quotes** → T-D or deferral.

Acceptance bar per §5 below.

### Step 3.4 — Operator-provided content (escalate to T-A or T-B)

If the operator pastes verbatim text from the primary (e.g., via the chat interface): T-A. If the operator attaches or describes a screenshot: T-B. Both supersede T-C; both are higher fidelity.

The architect's role is to recognize when escalation is possible and prompt the operator for paste/screenshot when T-A / T-B is reachable without the harness's proxy.

### Step 3.5 — Deferral when none of the above work

If WebFetch, WebSearch, secondary cross-attribution, and operator escalation all fail to produce recoverable content: defer the §1 elevation. Log the URL + capture date + reason in `AUTOMATION_INTEL.md`. Do NOT fabricate content to ship the entry.

## §4 Verification-tier mapping (cross-reference to `docs/founder-directives.md §1`)

The verification-tier MODEL is canonical in `docs/founder-directives.md §1` "Verification tiers used in §1" sub-section. This is the operational mapping per §3 fallback outcome:

| §3 outcome | Tier | Verification-block phrasing |
|---|---|---|
| WebFetch succeeded → verbatim text directly | **T-A** | *"T-A. Direct primary capture via WebFetch on <date>. Verbatim text below."* |
| Operator pasted full text from primary | **T-A** | *"T-A. Operator-paste capture on <date>. Verbatim text below."* |
| Operator attached/described a screenshot | **T-B** | *"T-B. Screenshot capture on <date>. Verbatim phrasing extracted below; secondary citations corroborate."* |
| WebSearch + ≥ 3 secondary sources with consistent quotes | **T-C** | *"T-C. Primary URL (`<url>`) returned <status> in capture session. Verbatim phrasing recovered from indexed snippets across <N> secondary sources (<list>), all citing the same primary."* |
| WebSearch + 1-2 secondary sources OR substantive paraphrase from architect knowledge | **T-D** | *"T-D. Primary URL inaccessible; substantive paraphrase from <basis>. Not verbatim."* |

The tier is the auditor's trust calibration. Future readers calibrate quotation weight against the tier; this is the canonical use of D-12 (production-grade trustability) at the §1 surface.

## §5 Cross-source acceptance bar (for T-C)

T-C is the most common recovery tier in practice. To prevent T-C from collapsing into "I found one blog post" sloppiness, the bar is:

1. **Minimum 3 indexed secondary sources** quoting the same exact phrase, attributed to the same primary URL.
2. **At least one primary-operated domain in the citation chain.** For an xAI source, at least one citation must reference `x.ai` / `docs.x.ai`. For Anthropic, at least one `anthropic.com` / `docs.anthropic.com` / `code.claude.com`. For Karpathy, `karpathy.ai` or his X account. The primary-operated citation is the anchor; secondary blog citations corroborate.
3. **Reject SEO-spam sites by reputation.** If the only sources are aggregator-spam-quality (auto-generated, no editorial signal), the tier collapses to T-D regardless of count.
4. **Capture date is the capture session date, not the source's publication date.** Both are recorded in the verification block; the capture date is when the researcher's fallback chain ran.
5. **Elevator name is required** for accountability. Per existing §1 verification-block convention, every entry names the elevator (e.g., "Elevated by: drumfiend21").

## §6 Verification block — what to record

Every §1 entry that used the fallback chain MUST include a Verification block with:

- **Tier:** T-A / T-B / T-C / T-D — per §4.
- **Capture session evidence:** "Primary URL `<url>` returned <status> in capture session" (when applicable).
- **Recovery method:** WebFetch / WebSearch / operator-paste / cross-attribution. Be explicit.
- **Secondary sources list (for T-C / T-D):** enumerate each cited URL. The reader can independently verify each.
- **Capture date:** ISO-8601 date when the researcher's chain ran.
- **Elevator:** the named person or agent who lead the elevation.

Example (from existing Source 4 at line 67 of `docs/founder-directives.md`):

> **Verification:** T-C. Primary URL (`x.ai/news/grok-build-cli`) returned 403 in capture session. Verbatim phrases recovered from consistent attribution across multiple secondary sources covering the launch (Engadget, eweek, AlternativeTo, basenor, pasqualepillitteri, releasebot, webpronews, codersera, kingy.ai, beginnersinai), all citing the same xAI announcement page and dating it to 2026-05-14.
>
> **Capture date:** 2026-05-25. **Elevated by:** drumfiend21.

This shape is canonical. New entries match.

## §7 Future de-blocking path (when the proxy opens up)

If the harness's outbound network policy is later updated to allow a previously-blocked host (e.g., `x.ai` becomes allowed), the operator can re-fetch and SUPPLEMENT the existing entry. Per D-6 (§1 immutable, append-only):

- **DO NOT** edit the original verification block. The T-C entry stays as the historical record of how the elevation occurred.
- **DO** append a "T-A supplement" sub-block under the same Source entry citing the post-deblock direct-fetch with capture date.
- **DO** record the policy change date in `AUTOMATION_INTEL.md` so future researchers know the host's allowed-status changed.

The original T-C entry remains canonical as of its capture date; the T-A supplement adds higher-fidelity evidence without invalidating the historical record.

## §8 Anti-patterns

Forbidden under any circumstance:

1. **Fabricate verbatim text** when the primary URL was inaccessible. If you didn't read it (or recover it via ≥ 3 cross-attributing secondary sources), it is NOT verbatim. The harness's value proposition is D-12 production-grade trust; fabricated quotes are a structural violation.
2. **Claim T-A when you used WebSearch.** T-A is direct primary capture. WebSearch is T-C at best. The tier is a load-bearing claim about evidence; lying about it corrupts every downstream consumer.
3. **Edit a prior §1 source** even if WebSearch reveals new content. §1 is immutable per D-6. New content APPENDS as a new Source or supplement, never overwrites a prior entry.
4. **Cite a primary URL you didn't probe yourself.** If WebFetch wasn't attempted, you don't know its block class. Run the header probe (§2) before falling back; record the actual response in the verification block.
5. **Skip the verification block** "to save space." The verification block IS the entry's auditability — without it, future readers have no trust calibration.
6. **Single-source T-C.** ≥ 3 secondary sources is the bar (§5). One blog post is T-D paraphrase, never T-C.
7. **Use SEO-spam-quality secondary sources** to inflate the count. Aggregator pages with no editorial signal don't corroborate; they regurgitate.

## §9 Authority and amendment

This doc is **TIER-2** — operational rulebook. It composes on (does not supersede) the TIER-0 corpus, the TIER-1 prime directive, and the TIER-1 founder-directives rulebook.

The verification-tier MODEL is canonical in `docs/founder-directives.md §1`. This doc operationalizes USE of the model — it is procedural, not foundational.

Amendments follow the ADR process in `docs/architecture-principles.md §19`. ADR-0023 is the originating decision; future amendments cite ADR-0023.

Per D-6: §1 (which carries the verification-tier MODEL) is immutable; this doc (which carries the verification-tier PROCEDURE) is amendable via ADR. The two surfaces are intentionally separated to honor the model/procedure distinction.

## §10 Verification (this CL)

- `test -f docs/researcher-discipline.md` exits 0.
- §1–§10 section markers grep-detectable.
- Every cited primitive resolves: `docs/founder-directives.md §1`, `docs/architecture-principles.md §19`, `scripts/sync-plugin.sh`, ADR-0002, ADR-0023.
- `AGENTS.md §5` lists this doc in the TIER-2 enumeration.
- `scripts/export-cursor-rules.sh` updated to include this doc in `.cursor/rules/agent-context.mdc` TIER-2 list; regenerated.
- `./scripts/export-cursor-rules.sh --check` exit 0.
- `./scripts/audit-doc-drift.sh` exit 0 (F-1..F-6 clean).
- `./scripts/smoke-e2e.sh` exit 0.
- ADR-0023 follows the numbered ADR template.

History: introduced in TICKET-016 (ADR-0023). Subsequent §1 entries cite this doc by path in their verification blocks instead of open-coding the procedure.

## Composition + provenance

This doc composes on:

- `docs/founder-directives.md §1` Sources 4 + 5 — the existing T-C entries this procedure was retroactively extracted from. (Per D-6 those entries are unchanged; this doc didn't exist when they were captured, but their verification-block shape IS this doc's §6 template.)
- ADR-0002 — verification-tier model that this doc operationalizes.
- ADR-0003 — the canonical T-A capture pattern (when WebFetch succeeds + when the operator pastes).
- `docs/architecture-principles.md §19` — ADR amendment process governing this doc's evolution.
- `scripts/sync-plugin.sh` — the existing header-inspection pattern (`--check`) this doc's §2 mirrors.

D-1 reverse attribution per ADR-0013: this researcher-discipline rulebook is a cross-tool primitive (applies to Claude Code, Cursor, Grok Build, headless `claude -p` / `grok -p` equally — the verification-tier model is tool-agnostic). It has no exclusive Grok-side or Claude-side analog because the discipline is RESEARCH METHODOLOGY, not orchestration. The closest analog is Grok-orchestration's `research_refs` provenance per `.grok/templates/research.md` — both surface "evidence with tiers"; this doc surfaces the OPERATOR procedure that produces the evidence.
