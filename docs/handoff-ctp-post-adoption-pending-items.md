# GCTP → CTP handoff — post-P-15-adoption pending items: production-fetch wrapper (unblocks real KA-2 acquisition) + `--explain` mode on the four shipped commands + P-14 §30.7 non-committing full-surface reveal at Stage 0

**Written:** 2026-07-10 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `b886658`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟢 **UPDATED 2026-07-10** — Items 1 and 2 both **BUILT and ADOPTED** at CTP pin `16e9623` (CL-561 §31.8) per GCTP ADR-0093 / TICKET-125. Item 3 (P-14 §30.7) remains FILED — genuinely on CTP's plate.
**Prior turns:**
- CTP → GCTP (post-adoption confirmation, 2026-07-10): "P-15 is fully adopted — that closes the entire arc." Flagged one command-name correction (`acquire-technology-rules.sh` not `acquire-tech-rules.sh` etc. — GCTP fixed at TICKET-122.a `7275535`). Offered (1) production-fetch wrapper on the CTP side that runs `standards/fetchers/*` against umbrella-matched URLs so `acquire-technology-rules.sh` pulls live content without `--source-file`; (2) `--explain` mode on the four commands to emit operator-friendly output.
- GCTP → CTP (operator-relayed message, TICKET-122.a body, 2026-07-10): both offers **accepted**.
- GCTP → CTP (this doc): the formal handoff enumerating what's pending on CTP side, GCTP's readiness on each, and the reason each matters for KA-2.

---

## 0. TL;DR

Three items on CTP's plate:

| # | Item | Origin | Blocks | GCTP readiness |
|---|---|---|---|---|
| **1** | ✅ **BUILT + ADOPTED** at pin `16e9623` (CL-561 §31.8) via GCTP ADR-0093 / TICKET-125 — CTP shipped `commands/acquire-technology-live.sh` orchestrating resolve → select umbrella-matched sources → read each source from `--cache <dir>` → feed to `acquire --only-mentioning <tech>` (only tech-mentioning lines from a general source become rules). **Boundary preserved**: the plugin does NOT itself download URLs; harness populates the cache | CTP's post-adoption offer 2b (2026-07-10) | KA-2 acquisition path now open; GCTP-side fetch orchestrator (TICKET-125.a scope) populates the `--cache` dir from umbrella-matched source URLs via the plugin's `standards/fetchers/*` | A5–A10 E2E tests queued as TICKET-125.a; kata driver TICKET-124 queued |
| **2** | ✅ **BUILT + ADOPTED** at pin `16e9623` (CL-561 §31.8) via GCTP ADR-0093 / TICKET-125 — CTP shipped `--explain` mode on all four commands emitting `EXPLAIN:` narrative lines alongside the terse `key=value` markers. Additive: existing terse output is preserved as default (GCTP's TICKET-123.a A1–A4 assertions in `tests/test-p15-family-activation.sh` verified 41/41 green at new pin) | CTP's post-adoption offer (2026-07-10) | `/consult` skill plain-language quality improves once TICKET-124.a wires `--explain` into loop-level narrative | GCTP `/consult` skill quotes `--explain` output verbatim (TICKET-124.a queued); no schema change needed |
| **3** | **P-14 (§30.7) non-committing full-surface reveal at Stage 0** — additive `available_menu` block on `--classify` output enumerating every namespace in `active.json` grouped by family (frontend/backend/IaC/cloud/CI/data/supply-chain/regulatory), non-committing (reveal ≠ commit) | GCTP FILED 2026-07-09 as P-14 (KA-1's G-1); awaits CTP consult on §30.7 | KA-2 Stage-0 reveal completeness for tech-agnostic visions (currently activates only 6 always-on regulatory/AI-governance namespaces without a `--stack-add`) | GCTP `--validate-profile` already tolerates unknown Stage-0 shape by structural check (no fixture assumes reveal cardinality); TICKET-119.b amendment queued to convert P-14 corpus from hardcoded 44 → structural `count(official) ∪ count(_project/<id>/*)` |

Items 1 and 2 both **BUILT and ADOPTED same-day** — CTP built CL-561 §31.8 hours after receiving this handoff; GCTP pinned at ADR-0093 (`b886658 → 16e9623`) with all consumer-side tests unchanged and green. Item 3 (P-14 §30.7) remains genuinely FILED — the P-14 handoff sits at `docs/handoff-ctp-p14-stage-0-full-surface-reveal-non-committing.md` for CTP's consult. Nothing blocks GCTP; TICKET-125.a (E2E acquisition), TICKET-124 (kata.sh update), and TICKET-124.a (`/consult` skill `--explain` consumption) are all startable now.

The subsections below preserve the original per-item rationale from the initial 2026-07-10 handoff; sections §1 and §2 are historical record of what was asked and delivered.

---

## 1. Item — Production-fetch wrapper (CTP's offer 2b)

### 1.1. Why it matters

At CTP pin `b886658`, `acquire-technology-rules.sh` stubs the fetch at the `--source-file <pre-fetched-content>` boundary — the acquire pipeline extracts + 4-axis-tags + writes rules under `generated-code-quality-standards/_project/<project-id>/<namespace>/`, but the operator has to hand-fetch the canonical source (e.g. `curl https://vuejs.org/guide/introduction.html`) and pass the file path in. This is fine for pre-wire and for CTP's internal 5013-assertion suite (which uses stubbed source-file inputs), but it means the real KA-2 kata acquisition is not truly end-to-end: the "acquire Vue rules from the actual Vue docs" step requires the operator to manually fetch — friction that undercuts the "single command per tech" promise.

CTP already ships `standards/fetchers/*` — the same fetcher pipeline used for React and the other already-globally-provisioned technologies. The offered wrapper composes those fetchers with the umbrella-matched source URLs from the registry (e.g. Vue's canonical docs URL declared in the umbrella-matched source registry entry), so `acquire-technology-rules.sh --tech vue --project FEATURE-003` pulls live content itself.

### 1.2. What GCTP is ready to consume

The moment CTP ships:

- **A5–A10 assertion suite** (`tests/test-p15-acquisition.sh`, to be written): exercises `acquire-technology-rules.sh --tech vue --project FEATURE-003` with **no** `--source-file` flag against live Vue docs; asserts (A5) YAML written under the shipped nested path `generated-code-quality-standards/_project/FEATURE-003/vue/*.yaml` with `origin: project` + `project_id: FEATURE-003` + provenance; (A6) unreachable-URL exit-2 vs. budget-exhausted `needs_source` distinguished non-silently; (A7) already-globally-provisioned no-op (matching CTP's boundary); (A8) aggregator `--project FEATURE-003` returns effective set `active.json ∪ _project/FEATURE-003/`; (A9) byte-identical `active.json` without `--project` (the no-silent-globalization spine — the load-bearing test); (A10) `promote-project-rule.sh --release --tech vue --project FEATURE-003` reverts cleanly.

- **KA-2 kata run**: `.harness/consult-work/FEATURE-003/` kata driver invokes acquisition live for the SoftArchCert kata's Vue frontend; the acquired Vue rules grade FEATURE-003's design decisions at official rigor for that project (invariant-4 via `XC_PROJECT_ID=FEATURE-003`); GCTP feeds any gaps back via `.harness/consult-work/FEATURE-003/gaps-log.md` as KA-2 G-N entries.

- **TICKET-124 kata.sh update**: adds `--project` awareness and acquire/promote/recommend routing paths to the kata driver.

### 1.3. Ask

**Build and ship the wrapper.** No schema changes needed on GCTP; the acquire command's contract already carries `--tech <name> --project <id>` and reads the umbrella-matched source URLs from the registry. The wrapper is purely a `standards/fetchers/*` invocation composed inside the acquire command's fetch step, replacing the `--source-file` mandatory-input branch with a fetcher-driven default (`--source-file` remains valid as an override for testing/air-gapped runs).

---

## 2. Item — `--explain` mode on the four commands

### 2.1. Why it matters

At `b886658` the four shipped commands emit terse machine-parsable output (`resolve=vue umbrellas=frontend activated=md,node,owasp,typescript,w3c,web-vitals status=needs_source` on the summary line, then a JSON body). This is ideal for the GCTP `/consult` skill's structured consumption path and for GCTP's E2E assertion suite (TICKET-123.a at `f8f8cdb` keys on exact tokens like `resolve=vue`, `umbrellas=frontend`, etc.). But when an operator wants to understand "why did Vue activate these six namespaces and not the react one?" the terse output is opaque.

CTP's offered `--explain` mode surfaces the same information in an operator-friendly narrative shape (one paragraph per moved-decision, source-cited), keeping the operator-facing paraphrase co-located with the command that owns the shipped behavior. GCTP's `/consult` skill still does loop-level narrative (design juncture / roadmap / cross-check translation), but per-command explanations belong on the command side.

### 2.2. What GCTP is ready to consume

- **Both output modes coexist by construction**: existing terse output stays default (E2E assertion suite unchanged); `--explain` adds a stderr or trailing block that the `/consult` skill quotes verbatim into its operator-facing narrative.

- **No schema change on GCTP**: the terse `key=value` markers remain the machine surface; `--explain` is human-facing text.

- **`/consult` skill translation, refined**: GCTP `/consult` skill picks up `--explain` output on each acquire/promote/recommend invocation and threads it into the loop-level narrative alongside the design-juncture translation. TICKET-124.a (queued) wires this into the skill.

### 2.3. Ask

**Add `--explain` to the four commands** (`resolve-technology.sh`, `acquire-technology-rules.sh`, `promote-project-rule.sh`, `recommend-technology.sh`). Additive — the flag is opt-in; absence preserves current terse output. Output shape suggestion: one paragraph per surfaced decision, citing the umbrella registry entry + source URL + any applicable acceptance-test spec.

---

## 3. Item — P-14 (§30.7) non-committing full-surface reveal at Stage 0

### 3.1. Status recap

GCTP filed **P-14** on 2026-07-09 (`docs/handoff-ctp-p14-stage-0-full-surface-reveal-non-committing.md`, KA-1's G-1). Status: 📋 **FILED** — awaits CTP consult. The proposal came out of KA-1 (SoftArchCert kata attempt on FEATURE-003): a tech-agnostic vision at pin `11126a8` activated only the 6 always-on regulatory/AI-governance namespaces (`documentation`, `european-union`, `observability`, `owasp`, `security-governance`, `us-government`). Frontend/backend/IaC/cloud/CI namespaces stayed latent until Stage-1 answers or design-junctures fired `--stack-add`. The operator's directive under-satisfied: *"entire expertise of the entire plug-in interfacing with the user from the very beginning."*

The proposed fix (P-14 §30.7): additive `available_menu` block on `--classify` output listing every namespace in `active.json` grouped by family (frontend / backend / IaC / cloud / CI / data / supply-chain / regulatory), non-committing — the operator sees the full plug-in expertise at Stage 0 without any premature stack commitment. Compact-safe: **reveal ≠ commit**. Composes cleanly with §30.5's stack-driven progressive activation (§30.7 reveals what could activate; §30.5 fires activation on explicit commitment).

### 3.2. Why it still matters now (post-P-15 adoption)

P-15 broadened *what* `active.json` covers (family umbrella activation + per-project acquisition + PR-gated promotion). But P-15 did not touch Stage-0 reveal completeness — a tech-agnostic vision still activates only the 6 always-on namespaces at Stage 0. P-14 and P-15 compose orthogonally:

- **P-14 fixes the reveal at Stage 0**: operator sees the whole map (family-grouped `available_menu`), including P-15's family umbrellas and any per-project overlay entries under `--project`.
- **P-15 fixes the map itself**: family umbrella activation for non-React frontends; per-project acquisition; PR-gated promotion.

Together, P-14's reveal displays P-15's growing surface (§31/§31.1 umbrellas + `_project/<id>/*` overlays) side by side with origin labels, matching GCTP's B5 growing-surface reveal decision (`docs/handoff-ctp-p15-b1-b5-decisions-and-assertion-map.md §2.5`).

### 3.3. What GCTP is ready to consume

- **P-14 acceptance corpus already tolerates non-hardcoded cardinality** — GCTP-side TICKET-119.b (queued) converts any hardcoded namespace-count assertion to structural form `count(official) + count(_project/<current-project-id>/*)`. Ready to wire when §30.7 lands.

- **GCTP consumer surface unchanged for §30.7 tolerance** — `--classify` reveal output is a new additive field on the `--classify` result envelope; `scripts/consult.sh --validate-profile` already treats unrecognized top-level fields as additive-optional (pre-P-15 pattern). No schema-tolerance edit needed until §30.7 shape lands.

- **A17 assertion** (`docs/handoff-ctp-p15-convergence-ack-and-final-shapes.md §4`) formalizes the reveal shape when project scope is present: `origin=official` vs `origin=project` distinguished with `scope: global` vs `scope: project:<current-project-id>` — this is P-14's growing-surface property under P-15's overlay semantics. When §30.7 ships, A17 wires into `tests/test-p15-family-activation.sh` (or a sibling) to exercise the reveal end-to-end.

### 3.4. Ask

**Consult on the P-14 §30.7 proposal** (originally at `docs/handoff-ctp-p14-stage-0-full-surface-reveal-non-committing.md`). Post-P-15 the design surface is cleaner: family grouping is the same taxonomy §31.3's family registry declares (frontend / backend-web / backend-language / data / iac / orchestration / cicd / ai-governance), so the reveal groups map 1:1 to the shipped umbrellas. If the design confirms, please tag as a §30.7 CL — GCTP re-pins per §15 ADR following ADR-0092 precedent.

---

## 4. GCTP-side companion tickets — status snapshot

| Ticket | Scope | Depends on |
|---|---|---|
| **TICKET-124** | Update `.harness/consult-work/_tools/kata.sh` for P-15 awareness (`--project`, acquire/promote/recommend routing, KA-1 two-pass discipline preserved) | Independent (startable now); refined once `--explain` lands |
| **TICKET-124.a** | `/consult` skill picks up `--explain` output from the four commands and threads into loop-level narrative | CTP item 2 (`--explain`) |
| **TICKET-125.a** | `tests/test-p15-acquisition.sh` — A5–A10 E2E assertions exercising `acquire-technology-rules.sh` live against Vue docs (no `--source-file`) | CTP item 1 (production-fetch wrapper) |
| **TICKET-125.b** | `tests/test-p15-promotion.sh` — A11–A14 E2E assertions exercising `promote-project-rule.sh --dry-run` against a live-acquired Vue overlay | CTP item 1 (live overlay from acquisition) |
| **TICKET-125.c** | `tests/test-p15-recommender.sh` — A18 E2E assertions exercising `recommend-technology.sh` against operator criteria | Independent (startable now); refined by `--explain` |
| **TICKET-126** | KA-2 kata attempt on FEATURE-003 (Vue frontend acquisition + design-juncture cross-check + optional promotion PR) | CTP item 1 (acquisition wrapper) |
| **TICKET-119.b** | P-14 acceptance corpus amendment: hardcoded 44 → structural `count(official) + count(_project/<id>/*)` | CTP item 3 (P-14 §30.7 CL) |

---

## 5. What GCTP is asking of CTP (summary)

1. **Build + ship the production-fetch wrapper** (item 1). Unblocks real KA-2 acquisition and A5–A10 E2E tests. Priority: **highest** — this is the last piece to make the P-15 acquisition path truly end-to-end.
2. **Add `--explain` mode** to `resolve-technology.sh` / `acquire-technology-rules.sh` / `promote-project-rule.sh` / `recommend-technology.sh` (item 2). Additive; existing terse output preserved. Priority: **medium** — UX improvement; not blocking.
3. **Consult on P-14 §30.7** (item 3, still FILED since 2026-07-09). Post-P-15 the design surface is cleaner. Priority: **medium** — Stage-0 reveal completeness for tech-agnostic visions; needed for KA-2 discoverability but not blocking KA-2 completion.

GCTP is standing by on all three. Nothing blocks CTP's timing; ship in whatever order fits the CTP cadence best. GCTP re-pins per §15 ADR following ADR-0092 precedent on each CTP tag.

Ready when you are.
