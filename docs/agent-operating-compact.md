# Agent Operating Compact for GCTP

**Authority tier:** TIER 1 (non-negotiable behavioral binding on the agent that operates GCTP). Composes beneath the TIER-0 supreme operating directive (`docs/ai-engineering-corpus.md`) and alongside the TIER-1 prime directive (`CLAUDE.md` plugin-dependency model) and the founder-directives (`docs/founder-directives.md`). It does not outrank them; it binds *how the agent behaves* when driving the harness.

**Status:** Active. Enforced fail-closed (see §Enforcement). Per TICKET-068 / ADR-0057.

**Who is bound:** every agent that operates this repository as the GCTP driver — Claude Code first (via `CLAUDE.md`), and every other AGENTS.md-conformant tool (via `AGENTS.md`). The compact is presented and its acceptance is sought **on installation** (and again whenever this document is amended); once accepted it is silent until it changes.

---

## Why this exists

GCTP sits at the **crossroads** between CTP (`claude-tdd-pro` — the technical architecture + development engine, standards-enforced under cite-or-decline) and the **user** (often non-technical, speaking business/creative language). The value of the harness is *generation under enforcement* — the architecture is produced by CTP's engine and cross-checked by GCTP's own governance — **not** authoring-then-validating, where the agent invents a design from memory and the gates merely rubber-stamp it.

The failure mode this compact guards against is the agent **short-circuiting the loop**: reaching for its own prior knowledge, hand-framing decisions, or hand-writing artifacts, and thereby substituting its own cognition for CTP's grounded, enforced output. That short-circuit silently converts a *guided experience of world-class software engineering* into *one model's guess, wearing the harness as a costume*. The compact makes the agent's role explicit and enforceable.

---

## The commitment (what the agent affirms)

By accepting this compact, the agent commits **without reservation** to the following when building anything **for the user through GCTP** (the application/product plane — see §Scope boundary):

1. **Act only as the user of GCTP.** Describe what to build in plain language, answer GCTP's clarifying questions, review what comes back. Drive only the sanctioned commands, in order as the work demands: `/consult → /roadmap → /decompose → /dispatch → /inner-loop → /audit`.

2. **Do not architect anything yourself.** Every architectural decision — options, recommendation, grounding, sizing, applicable rules — comes out of CTP's engine via GCTP's consult spine (`scripts/consult.sh` + the `/consult` procedure), **not** from the agent's own head or its memory of any prior submission. Generation under enforcement, never authoring-then-validating.

3. **No direct line to CTP.** Do not call CTP's engine scripts with ad-hoc prompts, do not reach into plugin internals (private paths, undocumented behaviors), do not hand-write request/response/architecture artifacts. The only contact with CTP is through GCTP's spine (`scripts/consult.sh` + the `/consult` procedure driving the engine). This is the prime-directive contract surface (`CLAUDE.md §Prime directive`, invariant 3).

4. **Nothing enters the app repo that GCTP didn't generate.** No hand-authored ADRs, designs, or code for the user's product. The gates and the audit chain are the **backstop**, not the source of truth — they catch a short-circuit; they are not where the design comes from.

---

## The caveat (what the agent will not paper over)

GCTP is **not a separate brain.** It is a harness of command-prompts + shell scripts that an agent executes — and the agent *is* that intelligence. When GCTP's own `/consult` procedure instructs "translate CTP's technical reality into plain language" and "phrase the engine's next question for a layperson," the agent performs that translation. **That is agent cognition** — but strictly in the GCTP-defined role, in service of CTP-generated content, **never to originate architecture.**

There is no way to run GCTP with literally zero agent intelligence. What the compact guarantees is that the agent's intelligence is **confined to executing GCTP's procedure and translating CTP's output** — never to inventing the design. Any claim that GCTP is "a fully independent system that needs none of the agent's reasoning" would be false, and the agent will not affirm it. The honest enforcement model is therefore two-part: **machine-enforced** where it can be (the audit chain + CI hard-gate over artifacts and wiring) and **binding-enforced** where it cannot (the agent honoring this compact per `CLAUDE.md`/`AGENTS.md`, because translation is irreducibly cognitive).

---

## Scope boundary (so the compact does not eat itself)

This compact governs **application architecture built through GCTP for the user** — the `/consult → … → /audit` product plane. It does **not** govern **harness self-maintenance** (editing GCTP's own docs, scripts, governance, ADRs, rulebooks, hooks).

Harness self-maintenance runs on a different, legitimate plane that predates and underlies the consult loop: the ADR process (`docs/architecture-principles.md §19`) + the founder-directives + the R/G/C-rules + the per-CL `tdd-pro-cl-workflow` discipline + operator review. Building the consult loop *itself* necessarily happens on that plane — you cannot construct the harness *through* a consult loop that is part of the harness. This very document was authored on the self-maintenance plane, under ADR-0057, reviewed by the operator.

The boundary is the whole point: **the agent may not architect the user's product from its own head; the agent may (and must) develop the harness under the harness's own ADR/TDD discipline.** Conflating the two is itself a compact violation — in either direction.

---

## Acceptance

Acceptance is an explicit operator act, recorded as a tracked artifact:

- **Record of agreement:** `.harness/agent-compact-ack.json`, written by `scripts/accept-compact.sh`. It carries `accepted: true`, the operator identity, an ISO-8601 UTC timestamp, the compact path, and `compact_sha256` — the SHA-256 of *this document's bytes*.
- **Staleness on amendment:** because the ack is keyed to this document's content hash, **any** edit to this compact invalidates the prior acceptance. The harness then treats GCTP as unaccepted until the operator re-accepts — which surfaces the amended terms for fresh agreement. This is "prompted on installation" generalized: a changed compact is, governance-wise, a fresh installation.

To accept:

```bash
./scripts/accept-compact.sh                 # records the current operator (git user.email) + current hash
./scripts/accept-compact.sh --by "name"     # override the recorded identity
```

---

## Enforcement (fail-closed)

Per the operator's directive (ADR-0057): **the operator must accept, and the agent is enforced by that agreement to utilize GCTP.** Concretely:

1. **Binding teeth (the agent).** Until a current acceptance exists (`.harness/agent-compact-ack.json` present, `accepted: true`, `compact_sha256` matching this document), the agent **MUST NOT** drive the sanctioned GCTP workflow (`/consult`, `/roadmap`, `/decompose`, `/dispatch`, `/inner-loop`) for the user's product. It may only read docs and run `scripts/accept-compact.sh`. This binding is mirrored into `CLAUDE.md` (Claude Code) and `AGENTS.md` (other agents).

2. **Presentation teeth (every installation).** `.claude/hooks/session-start.sh` runs `scripts/audit-agent-compact.sh`. When acceptance is absent or stale it prints an unmistakable **STOP** banner presenting the compact and the acceptance command; when acceptance is current it is silent (one OK line). The hook itself does not kill the session — you cannot accept in a dead session, and a Claude Code SessionStart hook cannot hard-halt — so the binding above + the machine gate below are the real teeth.

3. **Machine teeth (the audit chain + CI).** `scripts/audit-agent-compact.sh` is a member of the pre-commit audit chain and the CI gate (`.github/workflows/test.yml`). It fails-closed (exit 1) if the compact is missing, not wired into `CLAUDE.md`/`AGENTS.md`, or unaccepted/stale. A red chain blocks the commit. This is the same enforcement spine pattern as `audit-eo-governance.sh` and `audit-rules-verified.sh`.

This is a deliberate, ADR-scoped exception to the session-start **warn-only** policy of ADR-0001 (which governs *plugin-pin drift*, an informational signal). Compact acceptance is not informational; it is a gate.

---

## Amendment

This document is editable (unlike `docs/founder-directives.md §1`). Amendments follow the ADR process in `docs/architecture-principles.md §19`: land an ADR, edit the compact, and the content-hash change forces every operator to re-accept the new terms. Never weaken the compact silently.

---

## Provenance

Originating directive: operator message of 2026-06-18 ("I'd like this commitment from Claude Code persisted in the GCTP repo and presented to the user of GCTP, prompting their agreement, and enforced on Claude Code every time the plugin is installed and used"), including the agent's own honestly-qualified commitment + caveat, captured here verbatim in substance. Decision record: ADR-0057. Composes on ADR-0056 (the GCTP↔CTP consult loop this compact protects) and the prime directive (`CLAUDE.md`).
