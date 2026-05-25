# Research template — Grok outer-loop

**Purpose.** Outer-loop research with auditable provenance. Output feeds `decomposition.md`. This template runs Grok in headless `-p` mode (G-2) with `XAI_API_KEY` and produces Structured Output (G-3).

**Drawn from** (per D-1): Claude Code's plan-mode read-only investigation pattern and Cursor's ask-mode context gather. Difference here: Grok is outer-loop, so research persists to disk (not just a session-local context window) and carries provenance refs the inner loop will trust.

**G-rules touched.** G-2 headless. G-3 structured output. G-4 reasoning effort `medium` (escalate to `high` only if input scope ≥ 3 systems). G-5 cache-stable system prompt (this template is byte-stable across runs). G-15 observability (every run emits `run-id`, `prompt-hash`, sources, token cost). G-17 research belongs to outer loop.

**Corpus §3 anchors.** Context is the #1 constraint — research output is bounded by the schema below, not free prose. Verification = highest leverage — every claim carries a citable ref.

## Input variables

| Name | Required | Description |
|---|---|---|
| `feature_id` | yes | `FEATURE-NNN`. Used as the decomposition parent in subsequent handoffs. |
| `research_brief` | yes | One paragraph: what question must this research answer, and what does "answered" look like. |
| `time_box_seconds` | yes | Soft wall-clock budget. After this, return what you have with `complete: false`. |
| `prior_tickets` | optional | List of `TICKET-NNN` ids whose decision trail Grok should read first. |

## Output shape (JSON Schema fragment)

```json
{
  "schema_version": "1",
  "feature_id": "FEATURE-NNN",
  "completed_at": "2026-05-25T...Z",
  "complete": true,
  "summary": "two-sentence answer to the brief",
  "research_refs": [
    {"kind": "url|doc-id|file", "ref": "<id>", "summary": "<one line>"}
  ],
  "open_questions": ["<one line per unresolved question>"],
  "recommended_decomposition_count": 1,
  "reasoning_effort_used": "medium",
  "run_id": "<grok-run-uuid>"
}
```

`research_refs` is the unit of provenance. It flows into `dispatch.md`'s output field of the same name without transformation (G-17, R-11 tolerant reader).

## System prompt skeleton (cache-stable per G-5)

> You are Grok, the outer-loop orchestrator for grok-claude-tdd-pro. Your job in this run is research only — you do not edit files, you do not dispatch tickets, you do not propose code changes. You produce structured research output conforming to the schema below. Cite every claim with a `research_refs` entry. If you cannot answer within the time box, return `complete: false` with the partial result and an `open_questions` list. If the brief asks for code edits or deploy actions, refuse and emit a single-entry `open_questions` saying "brief out of scope — research mode only."

## Sample invocation

```bash
grok -p research \
  --reasoning-effort medium \
  --output-format json \
  --feature-id FEATURE-007 \
  --brief "Find prior tickets / public guidance on slugify edge cases. Answered = list of known edge cases + one recommended decomposition." \
  --time-box-seconds 600
```

## Pre-emit checks (this template performs them before returning)

- [ ] `research_refs` non-empty, OR `open_questions` non-empty (one of the two MUST have content).
- [ ] No `research_refs.ref` is a stale URL the system flagged as 404.
- [ ] `summary` ≤ 2 sentences.
- [ ] `recommended_decomposition_count` ≥ 1 if `complete: true`.
- [ ] `reasoning_effort_used` matches G-4 banding.
