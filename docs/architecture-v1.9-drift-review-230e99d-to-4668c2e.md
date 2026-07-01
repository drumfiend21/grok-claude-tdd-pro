# CTP `architecture-v1.9.md` drift review — `230e99d` → `4668c2e`

- **Date:** 2026-06-30
- **Author:** Claude Opus 4.8 (local session), for the operator
- **CL:** CL-ε / TICKET-097 (readiness) — feeds the §15 contract-delta analysis of the forthcoming pin-bump **ADR-0072** (`230e99d → 4668c2e`).
- **Method:** blobless clone of `drumfiend21/claude-tdd-pro` to a scratch worktree (the pinned plugin cache at `.harness/plugin-cache/` was **NOT** mutated — prime directive). `git show <pin>:docs/architecture-v1.9.md` for each side; `diff` + section/contract enumeration.
- **Old side verified:** `docs/architecture-v1.9.md` @ `230e99d` hashes `b9051de83bf5a073…`, matching the `contract_surface_files` entry in `docs/claude-tdd-pro.lock.yaml`. Correct baseline.

## Verdict: purely additive; **LOW** bump risk

The only drifted contract-surface file is `docs/architecture-v1.9.md`. The change is **append-only** (Nygard; ADR-0047 additive-only invariant intact): **0 deletions**, `+346` lines (1948 → 2294), all in new §28 appendices. No core (§§1–27) mutation, no contract-registry change, no consumed-skill change.

| Check | Result |
|---|---|
| `architecture-v1.9.md` span | `+346 / −0` lines — **purely additive** |
| New sections | **§28.40 … §28.69** (30 subsections); highest §28 `§28.39 → §28.69` |
| §§1–27 core | **unchanged** |
| §2 contract registry (§2.1…§2.32) | **unchanged** — §2.30/§2.31/§2.32 already present at `230e99d` (10–11 mentions each); this bump adds *implementation* (§28.54), not new contracts |
| New §2.X contracts introduced by the bump | **none** |
| `CLAUDE.md` (contract surface) | **byte-identical** `230e99d`↔`4668c2e` |
| 3 consumed `SKILL.md` (cl-workflow / batch-cl / bash32) | **all byte-identical** — inner-loop discipline unchanged |
| Files/commands removed | **0** |

Consequence for ADR-0072: the contract delta is a **hash change on one file driven entirely by appended §28 subsections that compose already-registered contracts**. The prime-directive text and the inner-loop discipline the harness consumes are unchanged. §15 gating still applies (the hash moved), but the risk surface is capability-adoption, not contract renegotiation.

## What the §28.40–§28.69 appendices add (each marked "no new §2.X contract" unless noted)

Grouped by consumer relevance:

**A. Directly validates existing GCTP work**
- **§28.40 Consumer Compatibility Contract — "schema-additive with epoch + default"** (2026-06-23). This is the **CTP side of P-9** and the exact invariant GCTP's **ADR-0071** (CL-α, this session) is the consumer-side dual of. CTP now epoch-tags every rule (`introduced_in`) and gates on it. Adopting `4668c2e` means the harness's epoch-aware enforcement composes with a plugin that actually emits epoch tags — the pin-keyed-baseline mechanism becomes forward-aligned, not just defensive.

**B. Composite-engine capabilities the CTP handoff names for GCTP wiring (CL-B..N)**
- **§28.42** full FOSS toolchain wired — **80 tools**, generic spec-driven `run-tool.sh`, advisory formatters (copyleft `invoke_only`, never bundled).
- **§28.44–§28.52** the **single config surface**: §16 config plane threaded into enforcement (§28.44), `profiles/standard.yaml` (§28.45), per-rule finding grouping preserving tool IDs (§28.46), config effective on the routed-tool path (§28.47), `ctp.config.yaml` + `ctp config init/print` scaffolder & auto-discovery (§28.48), per-tool **native** options in one config + `tool-option-surfaces` catalog (§28.50), Layer-2 native-config emitters (§28.51–52, all 55 option-bearing tools mapped).
- **§28.56 native-enforcement fallback** (no rule left unenforced when a routed tool is absent) + **§28.57 universal native enforcer** (any SE/architecture rule enforceable natively) — the "no rule unenforced" guarantee.
- **§28.58 config-object intake + universal options projection** (render `fmt+file+flag` OR `method:cli`) + **§28.59 persisted/cached options-view** (cache-if-no-change).
- **§28.60 govern-before-write** (PreToolUse deterministic native gate denies the write in memory) + **§28.68 both-paths pre-write enforcement** (IaC + full-stack rule sets govern in memory before write, partitioned by §28.63 path tags).
- **§28.62 full-stack-for-cloud co-design** + **§28.63 development-path tagging** (every rule `iac`/`fullstack`/`both`) + **§28.64 language/framework agnosticism** (no Node/React bias) + **§28.67** full distributed-system e2e (FE+BE+messaging+SQL+NoSQL+IaC).
- **§28.69 GCTP handoff updated** — the v1.18 capability list (§28.56–§28.68) for the consuming harness. This is the source of the CTP-side handoff pasted into this session.

**C. EO-security build-out (already-registered contracts §2.30/§2.31/§2.32)**
- **§28.54** implements the §28 EO-security cluster: H-14 vuln-scan + remediation gate (**§2.30**), H-15 SBOM + signed-provenance attestation (**§2.31**, additionally accepting in-toto predicate + Sigstore/cosign per the §2.31 refinement), H-16 frontier pre-release governance checklist (**§2.32**), S-54 EO-security source catalog, C-22/C-23/X-10. Maps onto GCTP's always-on EO governance dimension (ADR-0045); the contracts were already visible at `230e99d`.

**D. Test-only / internal (no consumer action)**
- §28.41 (ADR/handoff doc updates), §28.43/§28.49/§28.55/§28.61/§28.65/§28.66 (integration/coverage batteries), §28.53 (scoped eval cache).

## Consumer (GCTP) impact map for ADR-0072 → CL-B..N

| Capability | GCTP action | Where |
|---|---|---|
| Epoch tagging (§28.40) | already handled — ADR-0071 consumer dual is live | done (CL-α) |
| `enforce-file.sh` flags, `composite-dispatch --required`, SARIF 2.1.0 bus | wire (extends ADR-0068) | CL-B..N |
| PreToolUse `enforce-standards-pre-write.sh` + **move tool-based enforcement to pre-write** (operator decision this session) | wire into the pre-write governor | CL-B..N / ADR-0072 §4 decision |
| 80-tool option vocab, `classify-path.sh`, `codesign-build.sh` | wire (new ADR-0073+) | CL-B..N |
| EO §2.30/§2.31/§2.32 (vuln-scan, SBOM/provenance, frontier) | verify `active.json` surfaces them post-`standards-sync`; compose with ADR-0045 | CL-A + wiring |
| `active.json` rule count | expect change on `standards-sync` regen at `4668c2e`; re-baseline via ADR-0071 pin-keyed mechanism | CL-A |

## Recommendation

Proceed with the ADR-0072 pin bump. The §15 contract change is a single-file additive hash move with **no** core/contract/skill mutation and **zero deletions** — the ADR-0047 additive-only invariant and the prime-directive/inner-loop surfaces are preserved. Adopt the exact commit `4668c2e` materialized here (re-verify the SHA immediately before the bump, per the standing "CTP main is a moving target" caveat). Enumerate the deferred wiring (CL-B..N) in the ADR's "Known follow-up", mirroring ADR-0070, and re-baseline the registry-derived audits at the new pin per the ADR-0071 re-baseline step (`docs/plugin-sync.md`).
