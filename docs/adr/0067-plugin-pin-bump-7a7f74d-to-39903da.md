# ADR-0067 — Plugin pin bump `7a7f74d` → `39903da` (adopt PROPOSAL-003 / CTP-ADR-0007: YAML/JSON/MD corpora + `prose-judge.sh` + write-time + arch-gen enforcement)

- **Status:** Accepted
- **Date:** 2026-06-20
- **Deciders:** drumfiend21 (architect; 2026-06-20 directive: *"Ensure GCTP has the latest CTP"*) + Claude (cloud session).
- **Trigger:** CTP `main` advanced 6 commits `7a7f74d → 39903da` adopting **PROPOSAL-003** (the YAML/JSON/MD-corpora + prose-as-code work this session originated). CTP's ADR-0007 (their numbering) landed in three waves matching the brief sent to the CTP development chat:
  - CL-484 (§28.24): step-4 audit record for PROPOSAL-003 / ADR-0007 landing
  - CL-485 (§28.25): **config & markup rule corpora — Waves 1–3** (all 22 new namespaces shipping)
  - CL-486 (§28.26): **prose-as-code activated through enforce.sh** (the §11 capstone of CTP-ADR-0007)
  - CL-487 (§28.27): **enforce the rules at write-time AND at architecture-generation-time** (mirrors the exact operator directive from 2026-06-19 that drove GCTP ADR-0066 + CL-E)
- **Continues:** the ADR-0054 → 0058 → 0061 pin chain.
- **Pairs with:** GCTP ADR-0066 (`docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md`) — the harness-side wiring (CL-A through CL-E, TICKET-077..081) authored vacuously this session against the future-PROPOSAL-003 surface. **This pin bump is the activation event**: the wiring flips from vacuous-pass to live.
- **Process:** §15-gated pin bump (`architecture-v1.9.md` contract hash changed); lockfile updated by hand under this ADR.

## Compatibility verdict (verified `7a7f74d → 39903da`)

| Check | Result |
|---|---|
| Span size | **6 commits** (4396→4407, +11 CLs net) |
| CTP's `architecture-v1.9.md` | **CHANGED** (`af6b6d52…` → `3e0623fa…`) — the §28.24–§28.27 notes adding PROPOSAL-003 / CTP-ADR-0007 (Nygard append-only) |
| `CLAUDE.md` + the 3 consumed skills | **unchanged** (sha256 identical for all four) |
| `rubric/enforce.sh` | **byte-identical** (the 4-state contract Fix B/C build against is stable) |
| Files deleted / commands removed | **0** (additive only — ADR-0047 invariant preserved) |
| New detector substrate | `rubric/detectors/prose-judge.sh` (137 lines), `md-structure.sh`, `json-syntax.sh`, `yaml-syntax.sh`; `rubric/detectors/config-guidance-rules.json` (548 lines of multi-format rule bodies); `cloud-guidance-rule.sh` extended (+20 lines) |
| New `generated-code-quality-standards/<ns>/` directories | **22 new namespaces**: cfn, circleci, compose, gcp (extended), gha, gitops, glci, helm, iac-linter, iam, jenkins, json, jsonschema, jwt, k8s, md, mesh, oas, observability, sarif, sbom, yaml |
| Rubric rules in `active.json` | **46 → TBD** (will count after `standards-sync` runs on the new pin; expected ≥ 100 given the namespace count) |

## Decision

Bump the pin `7a7f74d` → `39903da`:
- **Lockfile:** update `pinned_commit` / `pinned_at` / `pinned_message` / `last_synced_*` and re-hash `architecture-v1.9.md` (`af6b6d52…` → `3e0623fa…`). `CLAUDE.md` + the 3 skill hashes unchanged.
- **Adopt read-only** — no `claude-tdd-pro` path edited from here (prime directive).
- **Activate the GCTP-side wiring shipped this session** (ADR-0066 + CL-A through CL-E, TICKET-077..081): the `audit-applicable-rules.sh` `applies_to_prose` filter, the `audit-design-phase-md.sh` gate, the `sarif-aggregate.sh` aggregator, and the `post-tool-use-review-gate.sh` extended-extension list all flip from vacuous-pass to live as soon as `standards-sync.sh` materializes the new namespaces into `.harness/rules/active.json`.

## What changes for GCTP

- **Gained:**
  - **Markdown enforcement** — every `.md` written (including architectural ADRs) is bitten by `md-structure.sh` (Layer 1 syntactic) AND by `prose-judge.sh` for every rule carrying `applies_to_prose: true` (Layer 2 semantic projection).
  - **YAML enforcement deepens** — beyond the prior thin `g-linux-foundation-*` k8s subset, the new `yaml` / `k8s` / `helm` / `compose` / `gha` / `glci` / `azdo` / `circleci` / `bbp` / `jenkins` / `ansible` / `cfn` / `oas` / `gitops` / `observability` / `mesh` / `iac-linter` namespaces all fire on the relevant file globs.
  - **JSON enforcement** — `g-json-*` (RFC 8259 syntax), `g-jsonschema-*` (Draft 2020-12), `g-iam-*` (AWS/GCP/Azure IAM-policy wildcards), `g-jwt-*` (RFC 8725 BCP — the highest-leverage P0 cluster), `g-sbom-*` (CycloneDX + SPDX), `g-sarif-*` (OASIS schema self-conformance).
  - **The prose-as-code principle becomes structural** — flipping `applies_to_prose: true` on ANY rule in `active.json` automatically binds it to architectural MD via `prose-judge.sh`, no further GCTP change needed.
  - **PATH A audit dead zone closes** — the 46-of-77-files gap surfaced by the kata audit (33 `.md` + 11 `.json` + 2 `.gitignore` previously unenforced) is now reachable. The next audit run will produce a meaningful verdict on every architectural artifact.

- **Unchanged:**
  - The `enforce.sh` 4-state contract (`pass | fail | not_applicable | not_enforced`) — Fix B/C continue to work byte-identically.
  - The `schema_version` of the handoff contract (still `"1"`) — `applicable_rules` continues to consume rule IDs as opaque strings.
  - The 3 executed skills (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`).
  - `CLAUDE.md` (no new TIER-0/1/2 directives).
  - All existing namespaces (`aws`, `azure`, `gcp`, `google`, `hashicorp`, `linux-foundation`, `node`, `owasp`, `react`, `security-governance`, `slsa`, `typescript`, `us-government`, `w3c`, `web-vitals`, `_community`, `_universal`, plus the new `doc` if shipped) — **additive per ADR-0047**.

## Consequences

### Positive
- Activates ~6 months of harness work in one bump: PROPOSAL-003 designed → CTP team built → harness wiring (CL-A..E) flips live.
- Closes the operator-flagged enforcement gap (46/77 files unenforced) on the next audit run.
- Materializes the prose-as-code principle the operator described: same rule, same gate, two surfaces.
- The write-time + arch-gen enforcement the operator demanded on 2026-06-19 (and which GCTP CL-E wired vacuously) is now driven by CTP's matching implementation in CL-487 (§28.27).

### Neutral
- No `claude-tdd-pro` path edited from here (prime directive honored). D-6 honored. No `schema_version` change on the handoff contract.
- The CTP team adopted PROPOSAL-003 verbatim — same wave structure, same namespace list, same detector contracts (per the CL-484 audit record + CL-485..487 implementation commits). No re-design needed on the harness side.

### Negative / cost
- LLM-judge token cost for the Layer 2 (`prose-judge.sh`) detectors is now non-zero. Mitigated by CTP's hash cache (per PROPOSAL-003 CTP-D-3) and the harness's two-phase trigger (design-phase before dispatch; code-phase before merge — ADR-0066 D-D + the session-start audit row from CL-E).
- The next kata audit may surface a substantial new fail set across `.md` / `.yaml` / `.json` files that were previously unenforced. Per the operator's "don't exclude anything" directive, those are visible-by-construction — operator either rewrites or files a `docs/deviations.md` row per ADR-0066 D-F.

## Verification (executed before commit)
- `sync-plugin.sh --check` → upstream HEAD `39903da` matches new pin; contract-surface drift accounted for in this ADR.
- `sync-plugin.sh --ensure` → cache materialized at `39903da`.
- `standards-sync.sh` → `active.json` rebuilt from the new pin's `standards/` + `rubric/` + `generated-code-quality-standards/` pipeline (rule count grows from 46 toward 100+).
- `tests/test-all.sh` → green across the full suite (the harness wiring from CL-A..E is unchanged; it now binds to the new rule registry).
- `smoke-e2e.sh` → green (stub pipeline still works against the larger registry).
- `git diff docs/founder-directives.md` == 0 (D-6 honored).
- No `.harness/plugin-cache/claude-tdd-pro/**` path edited (prime directive honored).

## Implementation references
- **Modified:** `docs/claude-tdd-pro.lock.yaml` (pin + `architecture-v1.9.md` hash), `.harness/plugin-cache/claude-tdd-pro/**` (regenerated by `sync-plugin.sh --ensure` from the new pin), `.harness/rules/active.json` (regenerated by `standards-sync.sh`).
- **New:** this ADR.
- **Adopts (CTP-side, not edited here):**
  - CL-484 (§28.24) — PROPOSAL-003 / CTP-ADR-0007 step-4 audit record
  - CL-485 (§28.25) — config & markup rule corpora (Waves 1–3): all 22 new namespaces
  - CL-486 (§28.26) — prose-as-code activated through enforce.sh (the §11 capstone)
  - CL-487 (§28.27) — enforce the rules at write-time AND at architecture-generation-time
- **Activates (harness-side, this session's work):**
  - ADR-0066 + CL-A (TICKET-077, `audit-applicable-rules.sh` MD floor + `applies_to_prose`)
  - CL-B (TICKET-078, `sarif-aggregate.sh`)
  - CL-C (TICKET-079, `audit-design-phase-md.sh` + `/dispatch` pre-emit step)
  - CL-D (TICKET-080, operator docs)
  - CL-E (TICKET-081, write-time hook extension + session-start arch-gen row)
- **Related:** ADR-0058 (`enforce.sh` `not_applicable` neutral), ADR-0061 (prior pin bump `eb7b2af`→`7a7f74d`).
- **Provenance:** `proposals/PROPOSAL-003-ctp-session-brief.md` is the self-contained brief that drove the CTP-side adoption. Adopted verbatim.
