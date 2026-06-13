# EO-2026 "Promoting Advanced AI Innovation and Security" — Harness Alignment Design

Status: **TIER-2 design document** (composes on the TIER-0 supreme operating directive `docs/ai-engineering-corpus.md`, the TIER-1 prime directive `CLAUDE.md`, the TIER-1 founder-directives rulebook `docs/founder-directives.md`, and the architectural / Grok / Claude-TDD-Pro rulebooks).
Originating ADR: **ADR-0043**.
Date: 2026-06-13.
Drives: **TICKET-043 .. TICKET-049** (see `TICKETS.md`).

This document maps the 2026-06-02 Executive Order *"Promoting Advanced Artificial Intelligence Innovation and Security"* onto the grok-claude-tdd-pro harness: where the harness already aligns, where the gaps are, and the prime-directive-respecting feature set that closes them. It is a **design doc**, not an implementation — implementation lands per-ticket in subsequent disciplined CLs, exactly as every other harness capability has.

---

## §0 Provenance & verification tier (read first)

The EO's primary text at `whitehouse.gov/presidential-actions/2026/06/promoting-advanced-artificial-intelligence-innovation-and-security/` returned **HTTP 403** under this environment's outbound network policy (the `host_not_allowed` / bot-block class in `docs/researcher-discipline.md §2`). Per the §3 fallback procedure, the EO's operative content is reconstructed from **≥ 3 independent indexed secondary sources** that agree on the same section structure and deadlines:

- Wilson Sonsini, Latham & Watkins, Mayer Brown, DLA Piper, WilmerHale, Pillsbury, Crowell & Moring, Greenberg Traurig, Hogan Lovells, Inside Privacy (Covington), Global Policy Watch (Covington), McDermott, CFR, Benton Institute, SecureWorld.

Per `docs/researcher-discipline.md §"≥ 3 indexed secondary sources quoting the same phrasing → T-C"`, the EO facts in §1 below are recorded at **verification tier T-C** (section structure and deadlines corroborated across multiple secondaries; exact statutory phrasing NOT quoted verbatim and NOT relied on). This is a **design input**, not a `docs/founder-directives.md §1` elevation — no §1 provenance entry is created or modified by this work. If/when the primary text becomes fetchable, a follow-on may upgrade specific claims to T-A.

**No claim in the feature designs below depends on phrasing finer than the section-level structure recorded at T-C.**

---

## §1 The EO in operative terms (T-C)

The Order pairs a deliberately **pro-innovation, minimally-burdensome** regulatory posture with three operative thrusts. It is **voluntary** for AI developers — explicitly *not* a licensing or pre-clearance regime.

| EO section | What it directs | Lead agencies | Deadline (T-C) | Named instruments |
|---|---|---|---|---|
| **§2 — Cybersecurity of federal & critical-infrastructure systems** | Expedite cyber defense of federal information systems; expand access to **AI-enabled defensive tools**; facilitate fed/state/local + critical-infrastructure operator access to cyber services (incl. covered frontier models) | CISA (BODs + guidance); Treasury (clearinghouse) | Most actions ≈ **30 days** (≈ 2026-07-02) | **AI Cybersecurity Clearinghouse** (Treasury-led); CISA Binding Operational Directives |
| **§3 — Voluntary frontier-model framework** | Stand up a voluntary framework: (1) developer asks the government whether a model is a **"covered frontier model"**; (2) developer grants up to **30 days pre-release federal access** before other trusted partners; (3) developer co-selects trusted partners. Protections: confidentiality, cybersecurity, **insider-risk**, **IP**. A **classified benchmarking process** for advanced cyber capabilities determines the "covered" designation. | NSA, CISA, NIST, Treasury | Framework by **2026-08-01**; benchmark within **60 days** | "Covered frontier model" designation; classified cyber-capability benchmark; trusted-partner early-access program |
| **§4 — Criminal enforcement** | Prioritize enforcement of existing federal criminal statutes against **AI-enabled cybercrime** | DOJ / Attorney General | (prioritization directive) | — |

Cross-cutting theme: **secure-by-design innovation without new regulation** — exactly the posture the harness already encodes (disciplined TDD, provenance/audit trails, security hooks, multi-lens review, governance-as-code).

---

## §2 Where the harness already aligns (asset inventory)

The harness is already a strong "responsible-AI-adoption" substrate. Mapping existing assets to EO thrusts:

| EO thrust | Existing harness asset | Status |
|---|---|---|
| §2 cyber defense / secure-by-design | `.claude/hooks/post-tool-use-review-gate.sh`; `scripts/audit-hook-security.sh` (S-1..S-6, CWE-mapped); secret-scan + RCE-hardening + file-fence hooks | shipped |
| §2 supply-chain integrity | Standards registry `.harness/rules/active.json` ships **`slsa`** + **`owasp`** namespaces (28 rules / 9 namespaces) | shipped |
| §2/§3 IP protection & tamper-evidence | TICKET-010 provenance manifest trilogy: `scripts/emit-manifest.sh`, schema validator, `--regenerate` re-hash; sha256 source manifests; **`signature: null` field already present** (extension point reserved) | shipped (signing latent) |
| §3 frontier model practices | `aibom.json` AI-Bill-of-Materials artifact (`examples/sample-output/TICKET-042/aibom.json`); multi-agent review lenses; `orchestrating-swarms` skill | shipped (AI-BOM minimal) |
| §3 trusted-partner / red-team collaboration | `orchestrating-swarms` skill (worker fan-out on isolated worktrees); `docs/self-healing-design.md` | shipped (no adversarial mode) |
| §4 misuse prevention | OWASP rule namespace; review-gate hardening; `docs/security-review.md` | partial |
| Governance / compliance | `docs/quality-gate.md` (4 sub-gates); `docs/deviations.md`; manifest + decision-trail; ADR process | shipped |

**Conclusion:** the EO does not demand a new architecture. It demands **(a)** activating reserved extension points (manifest signing, AI-BOM enrichment), **(b)** adding two narrow harness-native gates (vulnerability + misuse-resistance), and **(c)** publishing compliance-mapping docs and frontier-model templates. Everything that is genuinely *inner-loop discipline* (e.g. a "vuln-gated TDD" skill) belongs **upstream in the plugin** and is filed as a proposal, not built here (see §4).

---

## §3 Gap analysis → proposed features

Organized by EO section. Each feature names its **owner loop**, its **prime-directive class** (harness-side / plugin-proposal), and the **ticket** that implements it.

### EO §2 → Cyber defense hardening & vulnerability management

**F-EO-1 — Vulnerability sub-gate (harness-side).** Extend `docs/quality-gate.md` with a fifth, **default-on** sub-gate `vulnerabilities_remediated`: a CL touching app dependencies fails `green` if a manifest dependency carries a high/critical CVE without a documented deviation (`docs/deviations.md` row). Tooling-absent rule mirrors `coverage_delta_min` (vacuous pass + documented exemption). Implemented as a new audit `scripts/audit-vuln-scan.sh` wrapping `npm audit --json` / OSV-style output, wired into the session-start + CI audit chain and the `rules_verified` response field. **No plugin edit** — the gate is harness-native exactly like `tests_must_pass`, `coverage_delta_min`, `lint_clean`. → **TICKET-043**.

**F-EO-2 — Clearinghouse-style remediation report (harness-side).** A new `scripts/emit-cyber-report.sh` aggregates the vuln-gate output + S-1..S-6 hook findings + manifest provenance into a `COMPLIANCE-REPORT`-adjacent `cyber-report.json` (CISA/OMB-shareable shape: finding id, CWE/CVE, severity, remediation status, provenance ref). This is the harness's local analogue of the EO's **AI Cybersecurity Clearinghouse** feed — a report a developer *could voluntarily* share, not a mandatory upload. → **TICKET-044**.

**F-EO-3 — AI-enabled defensive-tooling examples (harness-side, docs+examples).** Add `examples/` scaffolds demonstrating the harness generating/testing defensive code under R-G-R: input-validation hardening, agent-action sandboxing, and prompt-injection resistance. Positions the harness as a tool that *produces* EO-§2 "AI-enabled defensive tools," not merely one that is hardened. → **TICKET-047** (shared with §4).

### EO §2/§3 IP protection → SLSA provenance: signing + SBOM

**F-EO-4 — Activate manifest cryptographic signing (harness-side).** The manifest's `signature: null` field is a reserved extension point. Implement optional **Sigstore/cosign keyless signing** of the manifest, populating `signature` with the bundle ref. Verification step added to `scripts/audit-manifest.sh`. Directly serves the EO's *"protect American ingenuity and IP from exploitation"* and the §3 IP-protection requirement for shared models. Optional (off by default; on when `cosign` present + opted-in) to honor the over-engineering filter for offline/airgapped operators. → **TICKET-045**.

**F-EO-5 — SBOM generation (SPDX/CycloneDX) (harness-side).** Enrich the existing `aibom.json` into a full **CycloneDX** SBOM (or SPDX, operator-selectable) for generated artifacts, covering the dependency tree + the AI-BOM (model/fine-tune lineage already stubbed in `aibom.json`). Leverages the already-present `slsa` standards namespace. → **TICKET-045** (paired with signing).

### EO §3 → Secure frontier-model practices (voluntary framework)

**F-EO-6 — "Covered frontier model" self-assessment template (harness-side, docs).** A `docs/frontier-model-readiness.md` checklist + a `.harness/handoffs`-shaped self-assessment template mirroring the EO §3 voluntary steps: (1) self-screen against a *public, non-classified* cyber-capability proxy benchmark; (2) confidentiality / insider-risk / IP controls checklist for sharing with government/trusted partners (NDA posture, sandboxed access, least-privilege); (3) trusted-partner selection rationale. Explicitly framed as enabling a developer to *participate in the voluntary framework*, never as a classified-benchmark replica. → **TICKET-046**.

**F-EO-7 — Red-team / blue-team adversarial swarm mode (harness-side, extends existing skill usage).** A new outer-loop workflow `docs/`-documented pattern that composes the existing `orchestrating-swarms` skill into a paired **red-team (adversarial prompts, model-extraction probes, prompt-injection) vs blue-team (hardening fixes under R-G-R)** exercise on isolated worktrees. Mirrors the EO's trusted-partner collaboration / early-access-for-hardening intent. Uses existing skill primitives — **no plugin edit**, a documented composition (per G-7 composes-on, not replaces). → **TICKET-048**.

**F-EO-8 — Secure-deployment & pre-release checklist (harness-side, docs).** `docs/secure-deployment-checklist.md`: red-team adversarial tests for the TDD agents themselves, insider-risk mitigations, confidentiality controls for handing artifacts to external reviewers. Composes on `docs/security-review.md`. → **TICKET-046** (paired).

### EO §4 → Criminal-misuse prevention

**F-EO-9 — Misuse-resistance review profile (harness-side, rubric mapping).** A harness-side **compliance profile** (NOT a new plugin rule) that filters `.harness/rules/active.json` into an EO-§4-relevant subset (OWASP LLM Top 10-style: prompt injection, model extraction, insecure output handling) and asserts it for tickets flagged as security-sensitive in their `applicable_rules`. The hardening *patterns* (defensive coding examples) ship in `examples/` (F-EO-3). → **TICKET-047**.

### Cross-cutting → Governance, compliance & enterprise readiness

**F-EO-10 — EO compliance-profile + standards mapping (harness-side, docs).** `docs/compliance-profiles/eo-2026.md` mapping harness gates → **NIST AI RMF**, **NIST SSDF**, **CISA BOD**-aligned controls, and the EO's §2/§3/§4 thrusts. A traceability matrix (control → harness asset → enforcing audit/gate) suitable for government/enterprise review. Plus a README §"EO-2026 alignment" pointer and a CHANGELOG entry. → **TICKET-049**.

---

## §4 Prime-directive boundary (the line we do not cross)

The prime directive (`CLAUDE.md` TIER-1) forbids editing `claude-tdd-pro` from this repo. The operator's analysis proposed several **plugin-side skills** ("vulnerability-gated TDD" skill, "cyber red-teaming" skill). Those are **inner-loop discipline** and therefore belong upstream. They are recorded here as **v1.11 plugin amendment proposals**, to be filed *separately* in `claude-tdd-pro` per the prime directive — **never patched in from this repo**.

| Operator-proposed item | Correct home | Why |
|---|---|---|
| "Vulnerability-gated TDD" as a *skill* | **Plugin amendment proposal (v1.11)** | A new inner-loop R-G-R discipline = plugin's job (C-rules consolidated upstream per ADR-0033). The harness instead ships the *gate* (F-EO-1) that consumes a plugin signal. |
| "Cyber red-teaming" as a *skill* | **Plugin amendment proposal (v1.11)** | Inner-loop testing discipline. The harness ships the *orchestration* (F-EO-7) that composes existing swarm primitives. |
| Frontier-eval *benchmark internals* | **Out of scope (classified)** | The EO §3 benchmark is classified/government-run. The harness ships only a *public self-assessment proxy* (F-EO-6); it never replicates the classified benchmark. |
| Vuln-scan *gate*, signing, SBOM, reports, compliance docs, swarm composition, examples | **Harness-side (this repo)** | All are consumer-side: new harness-native gates, audits, docs, and skill *compositions*. None edits the plugin. |

Every harness-side feature above is additive, reversible, and touches only harness-owned surfaces (`scripts/`, `docs/`, `examples/`, `.claude/hooks/`, `docs/quality-gate.md`, `TICKETS.md`). No `claude-tdd-pro` file is touched. No in-place edit of any D-/R-/G-/C-rule, the TIER-0 corpus, or any §1 provenance entry. The plugin pin (`bba77df`) is **unchanged** — none of these features require a pin bump.

---

## §5 Roadmap (mapped to operator's short/medium-term framing)

| Horizon | Tickets | Deliverables |
|---|---|---|
| **Short-term (quick wins)** | TICKET-043, 044, 045, 049 | Vuln sub-gate + audit; cyber-report emitter; manifest signing + SBOM; EO compliance profile + README/CHANGELOG. |
| **Medium-term** | TICKET-046, 047, 048 | Frontier-model readiness + secure-deployment checklist; misuse-resistance profile + defensive examples; red/blue-team swarm composition. |
| **Plugin track (separate repo, separate cadence)** | (proposals) | File v1.11 amendment proposals in `claude-tdd-pro` for the "vuln-gated TDD" and "cyber red-team" *skills*. Per the prime directive these are NOT implemented from here. |

Each ticket follows the harness's existing discipline: one CL, substrate test (`tests/test-<base>.sh`), full audit chain green, an ADR if architecturally significant, `git diff docs/founder-directives.md` == 0 lines (D-6).

---

## §6 What this design explicitly does NOT do (over-engineering filter)

- **Does not replicate the EO's classified cyber-capability benchmark.** Out of scope, classified; F-EO-6 ships only a public self-assessment proxy.
- **Does not make the harness a CISA/OMB upload client.** F-EO-2/F-EO-10 produce *shareable reports*; voluntary sharing is the operator's action, not an automated outbound push.
- **Does not add a mandatory frontier-model gate.** The EO framework is voluntary; the harness templates are opt-in.
- **Does not edit `claude-tdd-pro`.** All inner-loop discipline items are filed as proposals (§4).
- **Does not bump the plugin pin.** No feature here depends on a pin change.
- **Does not edit any rulebook in place.** Rule changes (e.g. promoting the vuln sub-gate to Required) land via ADR per `architecture-principles.md §19`.

---

## §7 Verification & cross-references

This design CL is verified by: design doc + ADR-0043 follow the numbered template; `TICKETS.md` extended with TICKET-043..049 in the existing table format; `git diff docs/founder-directives.md` returns 0 lines (D-6 honored); no `claude-tdd-pro` path touched (prime directive); plugin pin unchanged.

Cross-references:
- `CLAUDE.md` — prime directive (§4 boundary), TIER-0 corpus, founder-directives.
- `docs/quality-gate.md` — the 4 sub-gates F-EO-1 extends.
- `docs/provenance-bridging-design.md` + `scripts/emit-manifest.sh` — the `signature: null` extension point F-EO-4 activates.
- `examples/sample-output/TICKET-042/aibom.json` — the AI-BOM F-EO-5 enriches.
- `.harness/rules/active.json` — the `slsa`/`owasp` namespaces F-EO-5/F-EO-9 build on.
- `docs/researcher-discipline.md` — the verification-tier procedure §0 applies.
- `docs/security-review.md`, `docs/self-healing-design.md`, `orchestrating-swarms` skill — composed by F-EO-7/F-EO-8.
- ADR-0043 — the decision record for this design.
- ADR-0044 — review-driven refinements (the §8 triage below).

---

## §8 Review-driven refinements (multi-perspective second-voice triage)

On 2026-06-13 the operator supplied four simulated engineering-leadership reviews (Musk/xAI, Gates/Microsoft, Bezos/Amazon, Cook/Apple) of the §1–§7 design. Per the ADR-0029 `Second voice` pattern, each review is a second voice. This section triages every concrete suggestion into **ADOPT** (folded into a named ticket now), **DEFER** (named trigger; the over-engineering filter says wait for an operator-bitten signal), or **REJECT** (permanent). Recorded in ADR-0044.

The Bezos review's "strict scoping to avoid backlog bloat" is itself **ADOPTED as the governing meta-rule for this triage** — which is precisely why the five heavyweight suggestions below are deferred, not ticketed.

### Adopted (folded into existing tickets — no new tickets, no scope bloat)

| Suggestion | Source | Disposition | Target |
|---|---|---|---|
| CISA **KEV** (Known-Exploited-Vulnerabilities) prioritization — rank known-exploited CVEs first | Gates | ADOPT | TICKET-043 (vuln gate ranks KEV-listed CVEs ahead of generic high/critical) |
| **Security-score + vuln-MTTR** quantifiable metric | Bezos | ADOPT | TICKET-044 (cyber-report adds a score + MTTR field; **reuses existing `audit-metrics.sh` / `docs/dora-metrics.md`** — no new metrics substrate) |
| **in-toto attestations** + target **SLSA Build L3+** when signing enabled | Gates, Musk | ADOPT | TICKET-045 (cosign stays opt-in/off-by-default for airgapped portability — documented rationale; in-toto attestation emitted when enabled) |
| **Data-minimization / on-device-edge / insider-risk** checklist lines; lighter critical-infra posture | Cook, Gates | ADOPT | TICKET-046 (checklist line-items; doc-only) |
| **WCAG 2.2 accessibility + ethical** section in compliance profile | Cook | ADOPT | TICKET-049 (**reuses existing `w3c` / `web-vitals` namespaces** in `active.json`) |
| **Model-extraction + sandboxed-agent-action + prompt-injection** defenses | Cook, Musk | REAFFIRM (already in scope) | TICKET-047 (defenses) + TICKET-048 (red/blue swarm); the *skills* remain plugin-amendment proposals per §4 |
| Auto-generated **trusted-partner SBOM/provenance pack** (a signed bundle) | Bezos | ADOPT | TICKET-045/046 (the SBOM + signature *is* the pack; bundle them) |

### Deferred (named trigger — over-engineering filter applies)

| Suggestion | Source | Why deferred | Trigger to revisit |
|---|---|---|---|
| **Fast-track / spike mode** (post-hoc gate reconciliation) | Musk | No operator-bitten process-drag signal yet. Hard constraint: a mode that *bypasses* the `green` gate conflicts with the non-negotiable quality gate (`docs/quality-gate.md`); the only defensible form **defers gates to merge-time, never removes them**. Designing that safely is its own ADR. | Operator hits real process drag on a spike and directs it (ADR-0031 override pattern). |
| **STRIDE threat-modeling audit** | Gates | A new structured-analysis capability; premature without a ticket that needs it. | A ticket requires formal threat modeling of a shipped surface. |
| **Exportable compliance dashboard** (UI) | Gates, Bezos | The JSON cyber-report (TICKET-044) is the data substrate; a visual layer is a separate heavyweight surface. | An external buyer/reviewer asks for a visual artifact. |
| **Chaos-style swarm testing** | Bezos | No critical-infra scaffold ships yet to chaos-test. | A utilities/finance/healthcare scaffold lands (would pair with TICKET-047). |
| **Real-time CISA feed monitoring** automation | Bezos | Live outbound monitoring is a new always-on automation surface; the vuln gate (043) already pulls advisories at CL-time. | Operator wants live alerting between CLs. |
| **Differential-privacy evals** in swarms | Cook, Gates | Specialized; no model-training surface in the harness today. | A ticket processes sensitive data through an eval. |

### Rejected (permanent)

| Suggestion (or its strong form) | Why rejected |
|---|---|
| Auto-**upload** reports to CISA/OMB | EO framework is **voluntary**; harness produces shareable reports, the operator chooses to share. Restates §6. |
| Replicate the EO **classified** cyber-capability benchmark | Classified/government-run; harness ships only a public self-assessment proxy (F-EO-6). Restates §4/§6. |
| Sigstore/cosign **on by default** (Musk's strong form) | Conflicts with airgapped/offline-operator portability (over-engineering filter for the default path). Kept opt-in; SLSA L3+ is the target *when enabled*. |

### Out of band (not a design change)

- **Recruiting/portfolio positioning** (logging this in a `RECRUITING.md`): there is no `RECRUITING.md` in this repo, and creating one is outside EO-alignment design scope. Noted for the operator; not actioned here.

