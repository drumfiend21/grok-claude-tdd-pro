# GCTP → CTP handoff — P-19 + P-20 — two contract-design gaps surfaced by KA-3 (2026-07-10): probe-answer key nomenclature mismatch between `--list-questions` and `--answer` acceptance (P-19), and the `architect-recommend options[] → invariant-4 decisions[]` pipeline seam (P-20)

**Written:** 2026-07-10 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `724fc4c`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Status:** 🟡 **CONTRACT-DESIGN HANDOFF** — two gaps discovered while KA-3 pushed the kata iteration from depth 5 to depth 8. Both are cross-plugin contract seams (touch CTP command surfaces AND GCTP consumer wiring) that the operator has directed be designed *between both plugins in this single chat*. Neither blocks a next KA attempt (workarounds exist), but both prevent a clean end-to-end kata run — the operator UX has two rough edges.
**Prior turns:**
- KA-3 findings + KA-4 self-improvement verification: `.harness/consult-work/FEATURE-003/gaps-log.md` KA-3 section (TICKET-129 `dcec58a`).
- Pattern established across P-14/P-15/P-18: split each contract into "CTP owns capability" + "GCTP owns consumer wiring" + a clean contract surface between them.

---

## 0. TL;DR

Two gaps, both discovered at KA-3 depth 6–8, both requiring cross-plugin contract design:

| # | Gap | Symptom | Impact | Priority |
|---|---|---|---|---|
| **P-19** | Probe-answer key nomenclature mismatch | `full-surface-intake.sh --list-questions` emits probe key `documentation_audience` with `allowed:[internal,external,both]`; passing `--answer documentation_audience=external` returns `invalid=documentation_audience reason=unknown-question` | Blocks Stage 2 (per-namespace probe answers) — operator can only answer universal-9; probe answers must go through the interactive `/consult` flow | **medium** — Stage 2 can be skipped and design still runs on partial profile |
| **P-20** | `architect-recommend options[]` → invariant-4 `decisions[]` seam | `architect-recommend.sh` emits `options[]` (4 candidate architectures with `recommended_option_id`); GCTP's `audit-architecture-crosscheck.sh` walks `decisions[]` per §Architecture-Consult-Loop; the operator-picks-option-N transform is missing | Cross-check reports "no propagation" for every activated probe namespace (10 violations on KA-3's Vue + SoftArchCert vision) — genuine, not spurious, but blocks a clean end-to-end kata run | **higher** — blocks the last two depths (design commit + decompose to tickets) |

**Additive per ADR-0047 by construction**: P-19 tightens an existing surface (key acceptance); P-20 adds a NEW command (or a NEW GCTP transform step) — neither removes or reshapes an existing contract.

---

## 1. P-19 — Probe-answer key nomenclature mismatch

### 1.1. The gap (empirical from KA-3)

At CTP pin `724fc4c`, running:

```bash
CLAUDE_PLUGIN_ROOT=<cache> bash commands/full-surface-intake.sh --list-questions
```

emits (inside `probe_groups.documentation[]`):

```json
{
  "key": "documentation_audience",
  "type": "enum",
  "allowed": ["internal", "external", "both"],
  "prompt": "Who reads the docs — internal engineers, external users, or both?",
  "source_id": "google-eng-practices"
}
```

But passing the exact same key back:

```bash
CLAUDE_PLUGIN_ROOT=<cache> bash commands/full-surface-intake.sh \
  --answer workload=<vision> \
  --answer motivation=revenue ... \
  --answer documentation_audience=external \
  --partial --out <path>
```

returns on stderr:

```
invalid=documentation_audience reason=unknown-question
```

The same behavior was observed for all Stage-2 probe keys I tried (`observability_signal_depth`, `owasp_threat_posture`, `owasp_input_exposure`).

### 1.2. Impact

Stage 2 (per-namespace probe answers) via the non-interactive `--answer <key>=<value>` surface is currently unusable. The operator can only complete universal-9 answers non-interactively; probe answers must go through the interactive `/consult` flow. This blocks: (a) automated kata drivers passing all answers in one non-interactive call, (b) probe-answer scaffolding in the kata gap loop, (c) any batch-testing of probe combinations.

### 1.3. Ask (CTP-side)

Root cause is either that `--list-questions` emits keys the intake command doesn't accept, or that `--answer` has a resolver that doesn't recognize probe keys. **Either way, the two surfaces should agree**:
- Option A: fix `--list-questions` to emit the keys `--answer` actually accepts.
- Option B: fix `--answer` acceptance to accept the keys `--list-questions` emits.
- Option C: add a passthrough — any key in `--list-questions` output MUST be an accepted `--answer` key.

### 1.4. GCTP-side consumer wiring (no change needed pre-CTP-ship)

`.harness/consult-work/_tools/kata.sh intake` currently passes only universal-9 answers (works). Once P-19 lands, `kata intake` can accept `--probe <key>=<value>` flags that pass through to `--answer`, unblocking Stage 2 automation.

---

## 2. P-20 — `architect-recommend options[]` → invariant-4 `decisions[]` seam

### 2.1. The gap (empirical from KA-3)

At CTP pin `724fc4c`, `architect-recommend.sh --requirements <> --profile <> --out architecture.json` produces:

```json
{
  "schema_version": "1",
  "generated_at": "...",
  "option_count": 4,
  "recommended_option_id": "opt-balanced",
  "needs_grounding": 0,
  "options": [
    { "id": "opt-cost-optimized", "...": "..." },
    { "id": "opt-balanced",       "...": "..." },
    { "id": "opt-most-resilient", "...": "..." },
    { "id": "opt-fastest",        "...": "..." }
  ]
}
```

But GCTP's `scripts/audit-architecture-crosscheck.sh` walks `decisions[].applicable_rules[]` per `docs/handoff-contract.md §Architecture-Consult-Loop`:

```javascript
const decisions = Array.isArray(art.decisions) ? art.decisions : [];
for (const d of decisions) {
  for (const rid of d.applicable_rules) { ... }
}
```

So `decisions[]` is empty → invariant-4 reports "no rule with source_namespace=<ns> referenced" for every activated probe namespace. On KA-3's FEATURE-003 (Vue + SoftArchCert vision + 10 activated probes): **10 legitimate violations, cross-check exits 1**.

### 2.2. Impact

The genuine intent is: operator sees 4 options → picks one → picked option becomes `decisions[]` with each juncture's `applicable_rules` populated from the option's technical decisions → cross-check runs on the picked design. But there is no command that performs `pick option → emit decisions[]`. That step is currently manual and undocumented.

### 2.3. Contract-design proposal — three shapes to consider

**Shape A — CTP adds `architect-commit`** (recommended):

New command `commands/architect-commit.sh --architecture <options.json> --option <id> --out <decisions.json>` that transforms the picked option into a `decisions[]` artifact conforming to `§Architecture-Consult-Loop`. Each `decisions[i]` carries `{juncture, user_choice, complexity, applicable_rules, depends_on, grounded_in}`. Populates `applicable_rules` from the option's technical choices + the profile's `activated_probe_namespaces ∪ stack[].namespace ∪ project_overlay_namespaces` (the invariant-4 target).

Pros: clean single-command commit step; CTP owns the transform since it owns the option semantics; GCTP consumer surface unchanged.

Cons: adds a NEW command.

**Shape B — GCTP wires the transform in `/consult` skill**:

The `/consult` skill (agent-driven) reads `architecture.json`, prompts the operator "pick option 1 / 2 / 3 / 4", and emits `decisions[]` locally by walking the picked option's technical decisions and populating `applicable_rules` from the profile.

Pros: no new CTP command; keeps agent as translator (per compact discipline); operator-visible prompt.

Cons: skill duplicates transform logic that's naturally CTP-owned; if CTP evolves the option schema, GCTP has to track it.

**Shape C — hybrid**:

CTP adds a `--emit-decisions <id>` flag on `architect-recommend.sh` that produces a `decisions[]`-shaped artifact when the operator has already picked. Operator flow: run `architect-recommend` → view options → re-run with `--emit-decisions opt-balanced` → get decisions.

Pros: reuses the existing command; no new command file.

Cons: two-invocation pattern is slightly awkward compared to a dedicated commit command.

**GCTP's leaning: Shape A** (dedicated `architect-commit.sh`). Cleaner separation, operator-facing verb matches the "commit to a design" semantic, GCTP's cross-check consumer surface is unchanged.

### 2.4. Additive per ADR-0047

None of the three shapes remove or reshape an existing contract. Shape A adds a new command file; Shape B is entirely GCTP-side (no CTP change); Shape C adds an additive flag. Cite-or-decline preserved: if operator picks an unknown option ID, exit non-zero with a diagnostic.

### 2.5. Ask (CTP-side, if Shape A or C)

Choose one of the three shapes. Ship. GCTP re-pins per §15 ADR following ADR-0092/0093/0094 precedent. GCTP-side consumer wiring lands in the same or subsequent CL under `TICKET-130` (once the shape is confirmed): either `/consult` skill invokes `architect-commit`, OR the skill does the transform locally (Shape B).

---

## 3. What GCTP is doing NOW (parallel work)

- **KA loop is operational** at depth 8 (up from KA-2's depth 5). `kata intake / fetch / acquire / sufficiency / cross-check / reset-project` all work; full cycle end-to-end in ~2.5 seconds against real live canonical content.
- **G-1 KA-3 FIXED same session**: `scripts/consult.sh --validate-profile` schema-tolerance now accepts top-level `families_active[]` (shipped location).
- **G-2 KA-3 BAKED into `kata intake` verb**: driver always passes `--answer workload=<vision>` so §30.4 haystack fires ai-governed and regulated workload_types.
- **P-19 workaround**: kata driver skips probe answers via `--answer`; operator-friendly `--probe` flag lands post-P-19 CTP ship.
- **P-20 workaround**: kata driver could synthesize a `decisions[]` from the recommended option — feasible as GCTP-side Shape B pending CTP's shape choice.

---

## 4. What GCTP is asking of CTP

1. **P-19: fix probe-answer key acceptance** to match `--list-questions` output. Priority: medium (Stage 2 automation unblocker).
2. **P-20: choose one of the three shapes** (A/B/C in §2.3) for the options→decisions transform. Priority: higher (blocks clean end-to-end kata run).
3. **Return with a shaped proposal** — either "file as P-19 + P-20 with §31.x amendments" or a counter-shape. GCTP files tickets on CTP's proposed shape and re-pins per §15 ADR following ADR-0092/0093/0094 precedent.

Filed as **P-19** and **P-20** in `docs/upstream-ctp-proposals.md`. Awaiting CTP consult.

Ready when you are.
