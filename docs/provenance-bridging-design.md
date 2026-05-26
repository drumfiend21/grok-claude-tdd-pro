# Provenance + decision-trail bridging — design (TICKET-010 / ADR-0018)

Status: TIER-2 operational rulebook (companion to `docs/quality-gate.md`, `docs/self-healing-design.md`, `docs/cursor-integration.md`).
Authority: composes on the TIER-0 supreme operating directive (`docs/ai-engineering-corpus.md`), the TIER-1 prime directive (`CLAUDE.md`), and TIER-1 founder-directives.
Implementation: deferred to TICKET-010.a (manifest emitter wired into smoke-e2e + inner-loop driver) per §13 below.

## §1 Purpose

Today the harness's per-ticket audit evidence lives in three separate surfaces — Grok's outer-loop `research_refs` (carried inside `.harness/handoffs/TICKET-NNN.req.json`), Claude's inner-loop decision trail (`.harness/trails/TICKET-NNN.md`), and the inner-loop response handoff (`.harness/handoffs/TICKET-NNN.res.json` containing `gate_results`, `changed_files`, `test_results`, `decision_trail_ref`). An auditor reconstructing "what happened to this ticket" must know which three files to walk and how they relate. The harness's value proposition is production-grade trustability (D-12); reconstructing provenance from three separate file conventions is fragile.

This doc designs the **provenance manifest** — a single per-ticket file that indexes the three sources, records their content hashes for tamper detection, and gives an auditor exactly one entry point per ticket. The manifest is INDEX-ONLY (R-3 — no content duplication); the three source surfaces remain the canonical content holders.

The design composes on (does not replace) the upstream `claude-tdd-pro/docs/architecture-v1.9.md §2.8 AI Provenance Manifest` pattern — the upstream contract is a per-commit, per-plugin-internal manifest with rubric/standards/PR-corpus/compliance/cost-telemetry fields appropriate to the plugin's quality-core role. The harness's per-ticket manifest is the lean cross-tool bridge; the upstream §2.8 manifest is the plugin's internal compliance manifest. When a harness ticket lands a plugin-consuming commit, the harness manifest cites the upstream §2.8 manifest by path; no field-level duplication.

**Acceptance criterion from TICKETS.md** — *"Design doc; defines the merged artifact's shape."* This doc is the design; the implementation (manifest emitter) is deferred to TICKET-010.a per §13.

**Ticket-text correction** — the TICKET-010 row in TICKETS.md historically referenced `claude-tdd-pro's §2.2 provenance manifest`. The actual upstream contract is `§2.8 AI Provenance Manifest`; §2.2 is the unrelated "Detector contract". The TICKETS.md row is corrected in this CL to point at §2.8.

## §2 Architecture (composed from existing primitives)

```
Outer loop                Inner loop                 Manifest (this design)
.grok/templates/          .claude/skills/             .harness/audit/
  research.md                 tdd-pro-cl-workflow/      TICKET-NNN.manifest.json
       │                          │                          │
       │ research_refs              │ R-G-R discipline         │ index-only:
       ▼                          ▼                          │  ticket_id,
.harness/handoffs/         .harness/handoffs/                │  status,
  TICKET-NNN.req.json        TICKET-NNN.res.json             │  sources[],
       │                     +                                │  sha256 per src,
       │                     .harness/trails/                 │  upstream_§2.8_ref
       └──── input  ─────────► TICKET-NNN.md                  │
                                  │                            │
                                  └──── status + decision ─────┘
```

The manifest is generated AT THE END of the inner loop (after `.res.json` + trail are written) by the inner-loop driver (Claude Code, Cursor's chat agent, or headless `claude -p`). It is generated ONCE per ticket; immutable thereafter. Re-generation requires explicit `--regenerate` (auditor-only path; documented in §6).

## §3 The merged artifact's shape

`.harness/audit/TICKET-NNN.manifest.json`:

```json
{
  "schema_version": "1",
  "ticket_id": "TICKET-NNN",
  "created_at": "2026-05-26T12:00:00Z",
  "status": "green",
  "sources": [
    {
      "kind": "request",
      "path": ".harness/handoffs/TICKET-NNN.req.json",
      "sha256": "abc123...",
      "size_bytes": 1234
    },
    {
      "kind": "response",
      "path": ".harness/handoffs/TICKET-NNN.res.json",
      "sha256": "def456...",
      "size_bytes": 2345
    },
    {
      "kind": "decision_trail",
      "path": ".harness/trails/TICKET-NNN.md",
      "sha256": "789abc...",
      "size_bytes": 567
    }
  ],
  "upstream_provenance_manifest_ref": null,
  "manifest_generator": {
    "tool": "<inner-loop driver name>",
    "version": "<tool version or sha>"
  },
  "signature": null
}
```

### Field-by-field

- **`schema_version`** — `"1"` at v1. Future amendments increment per the same versioning policy as `docs/handoff-contract.md`.
- **`ticket_id`** — same identifier the handoff contract uses (`TICKET-NNN` or `SELF-HEAL-<utc-date>-<seq>` per `docs/self-healing-design.md`).
- **`created_at`** — ISO-8601 UTC timestamp of manifest generation.
- **`status`** — copy of the response's `status` field (`green` / `red` / `blocked`). Surfaced here so auditors see the outcome without opening any source file.
- **`sources`** — array of source-file index entries. Three at v1: `request`, `response`, `decision_trail`. Each entry has:
  - `kind` — enum: `request` | `response` | `decision_trail`. Extensible in future schemas (e.g., `swarm_lead_summary` per ADR-0017).
  - `path` — repo-relative path.
  - `sha256` — content hash of the source file at manifest-generation time. Tamper detection.
  - `size_bytes` — file size at generation time. Defense in depth (cheap mismatch indicator).
- **`upstream_provenance_manifest_ref`** — string path to `claude-tdd-pro/<...>/provenance/<commit-sha>.json` (or `null` if no plugin-consuming commit was produced). When non-null, the auditor walks BOTH manifests (harness-level for the ticket bridge; upstream §2.8 for the commit's full provenance). No content overlap by design.
- **`manifest_generator`** — identifies the tool that produced the manifest. Allows future forensic distinction between operator-driven (`/inner-loop`), headless (`claude -p`), and swarm-driven (`orchestrating-swarms` SKILL.md per ADR-0017) manifests.
- **`signature`** — `null` at v1; reserved for future cryptographic signing (e.g., commit-author GPG signature or sigstore). Adding signing is a future ADR.

### Why INDEX-ONLY (not content-merged)

Per R-3 (single source of truth):

- `research_refs` lives in `.req.json`. The manifest does NOT copy `research_refs`. To inspect them, the auditor reads the request file.
- `gate_results`, `changed_files`, `test_results` live in `.res.json`. The manifest does NOT copy them.
- R-G-R steps live in the decision trail markdown. The manifest does NOT copy them.

A content-merging manifest would either drift from its sources (when a source file is later regenerated and the manifest isn't) or force re-emission on every source change. An index-only manifest is small, immutable post-generation, and detects tampering via sha mismatch — the auditor knows whether to trust the sources without reading them.

### Why `.harness/audit/` (a new directory)

`.harness/handoffs/` holds wire-format JSON (request + response). `.harness/trails/` holds decision-trail markdown. Both are already gitignored at runtime per existing convention. The manifest is logically different — it is the audit-trail entry point, not a wire-format and not a trail. A separate `.harness/audit/` directory makes the manifest's role discoverable.

`.harness/audit/` joins `.harness/handoffs/` + `.harness/trails/` in the runtime-artifact set; it is gitignored at runtime per the same pattern (TICKET-010.a adds the gitignore entry alongside the emitter).

## §4 Source-of-truth map (what comes from where)

| Manifest field | Source-of-truth | Generation rule |
|---|---|---|
| `schema_version` | This design doc (v1). | Literal `"1"`. |
| `ticket_id` | `.req.json` and `.res.json` (must match). | Copied verbatim. Manifest emitter rejects if they disagree. |
| `created_at` | Inner-loop driver clock. | ISO-8601 UTC at emission. |
| `status` | `.res.json` `status` field. | Copied verbatim. If `.res.json` missing (worker crashed mid-inner-loop), `status` is `"blocked"` and `sources[response]` is absent with a `kind: response_missing` placeholder. |
| `sources[*].path` | Repo-relative convention. | Computed; no I/O. |
| `sources[*].sha256` | `sha256sum` / `shasum -a 256` of the source file. | Computed at emission; stored as 64-char hex string. |
| `sources[*].size_bytes` | `stat -c %s` / `stat -f %z`. | Computed at emission. |
| `upstream_provenance_manifest_ref` | Inner-loop driver (knows if a plugin commit landed). | `null` if no plugin-consuming commit; else the upstream manifest path. |
| `manifest_generator.tool` | Inner-loop driver name. | `"claude-code-cli"` / `"cursor-chat-agent"` / `"claude-p-headless"` / `"orchestrating-swarms-lead"` / etc. |
| `signature` | (reserved) | Always `null` at v1. |

## §5 Format / storage location

- **File:** `.harness/audit/TICKET-NNN.manifest.json`.
- **Encoding:** UTF-8 JSON, 2-space indent, trailing newline (consistent with existing handoff JSON formatting).
- **Lifecycle:** generated ONCE at the end of each inner-loop invocation; immutable thereafter. `--regenerate` is the only sanctioned re-emission path; documented in §6.
- **Gitignored at runtime** per `.gitignore` (added in TICKET-010.a). The manifest is per-session evidence, not durable repo state.
- **Size budget:** 200 bytes – 2 KB typical. Index-only, no content; bounded by ticket-id length + source-file count + paths.

Self-heal dispatches (`SELF-HEAL-<utc-date>-<seq>` per `docs/self-healing-design.md`) produce manifests at `.harness/audit/SELF-HEAL-<utc-date>-<seq>.manifest.json` — same schema, same path pattern, different ticket-id prefix. No second schema; one manifest format, two producers (operator-driven + self-heal-driven), matching the handoff contract's one-schema-two-producers factoring per ADR-0011.

## §6 Generation procedure

Pseudocode for the manifest emitter (shipped in TICKET-010.a / ADR-0019 as `scripts/emit-manifest.sh`):

```
input: ticket_id (string)

req_path  = ".harness/handoffs/" + ticket_id + ".req.json"
res_path  = ".harness/handoffs/" + ticket_id + ".res.json"
trail_path = ".harness/trails/"  + ticket_id + ".md"

assert exists(req_path)                # else: dispatch never happened; refuse
assert exists(trail_path) or res_status == "blocked"

status = read_json(res_path).status if exists(res_path) else "blocked"

sources = [
  { kind: "request",        path: req_path,   sha256: sha256(req_path),   size_bytes: filesize(req_path)   },
]
if exists(res_path):
  sources += [ { kind: "response", path: res_path, sha256: sha256(res_path), size_bytes: filesize(res_path) } ]
else:
  sources += [ { kind: "response_missing", path: res_path, sha256: null, size_bytes: 0 } ]
if exists(trail_path):
  sources += [ { kind: "decision_trail", path: trail_path, sha256: sha256(trail_path), size_bytes: filesize(trail_path) } ]

manifest = {
  schema_version: "1",
  ticket_id: ticket_id,
  created_at: now_utc_iso8601(),
  status: status,
  sources: sources,
  upstream_provenance_manifest_ref: null,    # populated only if a plugin-consuming commit landed
  manifest_generator: { tool: driver_name(), version: driver_version() },
  signature: null
}

write_json(".harness/audit/" + ticket_id + ".manifest.json", manifest)
```

**`--regenerate` path** (shipped in TICKET-010.c / ADR-0021):

The manifest is logically immutable. If an auditor needs a fresh manifest for an old ticket (e.g., to detect post-hoc tampering), they invoke `scripts/emit-manifest.sh --ticket TICKET-NNN --regenerate`; the script re-hashes the current source files and writes the result to `.harness/audit/TICKET-NNN.manifest.regenerated.json` — the original `.manifest.json` is NEVER overwritten. The script then diffs `sha256` per source between original and regenerated; any mismatch is surfaced (with original + current sha lines) and the exit code is 1 (source drift detected). All-clean = exit 0.

## §7 Composition with existing contracts

The manifest composes on (does not duplicate) these existing surfaces:

- **`docs/handoff-contract.md §Grok→Claude`** — defines `.req.json` schema; the manifest references the file by path + hash.
- **`docs/handoff-contract.md §Claude→Grok`** — defines `.res.json` schema; the manifest copies `status` (the only non-index field) and references the rest by path + hash. `decision_trail_ref` in `.res.json` is the bridge today; the manifest is a stricter, hash-bound version of the same bridge.
- **`.claude/skills/tdd-pro-cl-workflow/SKILL.md`** — the inner-loop discipline; this skill writes the trail. The manifest indexes the trail.
- **`docs/quality-gate.md §Sub-gate 4 provenance_complete`** — RECOMMENDED at v1; will be REQUIRED at v2. Once the manifest emitter (TICKET-010.a) ships, `provenance_complete` can promote to REQUIRED with the manifest's presence + sha-validation as the concrete bar. This design doc names the future promotion path; the promotion itself is a separate quality-gate v2 ADR.
- **`docs/self-healing-design.md §6` (Dispatch policy)** — self-heal dispatches use the same ticket-id schema and reuse the same handoff contract; per §5 above, they reuse the same manifest format with the `SELF-HEAL-` prefix.
- **`claude-tdd-pro/docs/architecture-v1.9.md §2.8 AI Provenance Manifest`** — the upstream per-commit manifest. The harness-side manifest references via `upstream_provenance_manifest_ref` when a plugin-consuming commit lands. No field duplication; the upstream manifest's rubric/standards/compliance/cost-telemetry fields are out-of-scope for the harness's per-ticket bridge.
- **`.claude/skills/orchestrating-swarms/SKILL.md` (ADR-0017)** — each parallel worker in a swarm produces its own `.res.json` + trail per worktree. The swarm's lead agent calls the manifest emitter per worker (Step 5 of the swarm skill). N parallel workers → N manifests, one per ticket.
- **`scripts/smoke-e2e.sh`** — the smoke script's terminal step (after writing trail) will call the manifest emitter in TICKET-010.a, producing `TICKET-042.manifest.json` per the demo ticket-id.

## §8 Failure modes

Seven failure modes named; each with structural mitigation or explicit deferral.

1. **Source file missing at emission time (e.g., trail not written because worker crashed mid-Refactor).** Mitigation: §6 pseudocode handles missing `.res.json` (`status: "blocked"`, `response_missing` placeholder); missing trail with response present is logged as a finding rather than a hard failure. The auditor sees the gap explicitly in the manifest.
2. **Source file tampered AFTER manifest emission.** Mitigation: `--regenerate` path (§6) detects sha mismatch; original manifest is never overwritten; tamper is surfaced as new vs. original sha divergence.
3. **Concurrent manifest emission for the same ticket (e.g., two inner-loop drivers race).** Mitigation: manifest writes use atomic rename (`write to .manifest.json.tmp; rename to .manifest.json`). Last-writer-wins; the loser's manifest is overwritten but never partially written. Concurrent inner-loop drivers for the same ticket-id are themselves a discipline violation (G-16 atomic-ticket rule); the manifest does not paper over the discipline failure.
4. **`upstream_provenance_manifest_ref` points at a missing file.** Mitigation: emitter validates existence at write time; if the upstream path doesn't exist when the ref is set, emitter logs a finding and sets the ref to `null` rather than emit a dangling reference.
5. **Manifest's own format drifts from this design.** Mitigation: a future TICKET-010.b can add `scripts/audit-manifest.sh` (a Q-DOC-DRIFT cousin) that validates every `.harness/audit/*.manifest.json` against the v1 schema. Deferred per D-8 until evidence justifies.
6. **Manifest contains private content via copied `status` field (e.g., a `status: "red"` with a secret in `error.message`).** Mitigation: only `status` (an enum) is copied — never error details, never message text. The strictest "no content copy" discipline is for this reason.
7. **Driver doesn't know its own version (e.g., headless `claude -p` invoked without identifying metadata).** Mitigation: `manifest_generator.version` is permitted to be `null` when not determinable; the field is informative, not normative. Audit conclusions never depend on the driver-version field alone.

## §9 Audit consumption (who reads it, for what)

The manifest's primary readers:

- **Internal auditor / engineering manager.** "What happened to TICKET-NNN?" — reads `.harness/audit/TICKET-NNN.manifest.json`, sees status + 3 source paths + sha hashes, walks sources for detail.
- **Compliance reviewer.** "Was this change AI-assisted, and what was the provenance?" — reads manifest, follows `upstream_provenance_manifest_ref` if present for upstream §2.8 fields (models used, ADRs referenced, signature).
- **Post-incident reviewer.** "Did our agentic process produce this outcome?" — reads manifest's status + decision_trail, then walks trail's R-G-R record.
- **Self-healing monitor (`docs/self-healing-design.md`).** Will read manifest's `gate_results` (via the response source) to detect threshold breaches; manifest serves as the per-ticket index so the monitor doesn't have to walk handoffs + trails separately.
- **Future automated audit pipelines (TICKET-010.b candidate).** Could parse N manifests to produce cross-ticket reports (e.g., monthly green-rate metrics, manifest-coverage rate, ticket-throughput).

The manifest is NOT for:

- Replacing the response / trail content. (The manifest is index-only.)
- Storing secrets or PII. (Only ticket-id + status + path + hash are stored.)
- Cross-repo coordination. (One repo, one manifest set; multi-repo correlation is a future concern.)

## §10 Cross-tool readability

The manifest is JSON — universally readable. Per AGENTS.md §3 (handoff-contract pointer), the manifest is announced as a future field in TIER-2 enumeration once TICKET-010.a ships. Until then:

- **Claude Code** — reads the manifest if the operator invokes a future `/audit-ticket TICKET-NNN` command (deferred; not in this CL).
- **Cursor's chat agent** — same; reads the JSON when asked to summarize a ticket.
- **Grok CLI / outer-loop monitors** — reads the manifest to detect aggregate status across tickets (future self-heal observer per `docs/self-healing-design.md §3`).
- **Other AGENTS.md consumers** — read per AGENTS.md §3 wire-format pointer once the manifest path is registered.

## §11 Authority and amendment

This design doc is TIER-2 — operational rulebook level. Amendments follow the ADR process in `docs/architecture-principles.md §19`. ADR-0018 is the originating decision; future amendments cite ADR-0018 as the predecessor.

The manifest schema (`schema_version: "1"`) follows the same SemVer discipline as `docs/handoff-contract.md`:
- Tolerant reader on consumers (per R-11): unknown fields ignored, missing optional fields defaulted.
- Schema increments on breaking changes: deprecating a field, changing a field's type, removing a field.
- Schema field additions are non-breaking and do not increment.

## §12 Out of scope (deferred)

1. **Manifest emitter implementation.** Deferred to **TICKET-010.a** (`scripts/emit-manifest.sh` + integration with `smoke-e2e.sh` + `.cursor/commands/inner-loop.md` + `.claude/skills/orchestrating-swarms/SKILL.md` Step 5).
2. **Manifest schema validator** (`scripts/audit-manifest.sh`). Deferred to TICKET-010.b.
3. **Cryptographic signing of manifests** (`signature` field). Deferred per D-8 — `null` at v1; future ADR if compliance demands.
4. **`--regenerate` CLI for audit-time re-hashing.** Deferred to TICKET-010.c.
5. **Cross-ticket aggregation reports** (monthly green-rate, manifest-coverage). Deferred per D-8.
6. **Promotion of `provenance_complete` quality-gate sub-gate from RECOMMENDED to REQUIRED.** Quality-gate v2 ADR; depends on TICKET-010.a landing first.
7. **`.harness/audit/` runtime-artifact gitignore entry.** Lands with TICKET-010.a alongside the emitter.
8. **Manifest format extensions for swarm-aggregated outcomes** (e.g., a swarm-level manifest indexing N worker manifests). Defer to a future swarm-audit ADR if operationally needed.
9. **Manifest format extensions for upstream `claude-tdd-pro` §2.8 field-level copy-down** (e.g., embedding `models_used` from upstream). Rejected per R-3 — upstream §2.8 manifest is referenced by path, never duplicated. Deferral is permanent unless R-3 is amended.
10. **Per-author / per-reviewer audit fields.** Out-of-scope per D-13 (kitchen-sink resistance); harness-internal scope is ticket-level, not session-author-level.

## §13 Verification (this CL)

- `test -f docs/provenance-bridging-design.md` exits 0.
- 13 numbered sections (§1–§13) grep-detectable.
- Every cited primitive resolves to a real path:
  - `docs/handoff-contract.md`
  - `docs/quality-gate.md`
  - `docs/self-healing-design.md`
  - `.claude/skills/tdd-pro-cl-workflow/SKILL.md`
  - `.claude/skills/orchestrating-swarms/SKILL.md`
  - `.grok/templates/research.md`
  - `scripts/smoke-e2e.sh`
  - Upstream `claude-tdd-pro/docs/architecture-v1.9.md §2.8` (via plugin cache).
- `./scripts/audit-doc-drift.sh` exit 0 (no F-1..F-5 triggered).
- `./scripts/smoke-e2e.sh` exit 0 (toy at Red baseline; this CL touched no executable beyond docs / AGENTS.md / generator).
- `./scripts/export-cursor-rules.sh --check` exit 0 after regenerating to include the new TIER-2 doc.
- ADR-0018 follows the numbered ADR template.
- No code shipped; design only per the TICKET-010 acceptance criterion.
- Q-DEMO N/A — this is a design CL; implementation Q-DEMO is owned by TICKET-010.a.

History: introduced in TICKET-010 (ADR-0018). Implementation deferred to TICKET-010.a per §12.

## Composition + provenance

This doc composes on:

- `docs/handoff-contract.md` (the two schemas the manifest indexes).
- `docs/quality-gate.md §Sub-gate 4: provenance_complete` (the RECOMMENDED-at-v1 sub-gate this design will promote to REQUIRED post-TICKET-010.a).
- `docs/self-healing-design.md` (the long-loop consumer of manifests).
- `.claude/skills/tdd-pro-cl-workflow/SKILL.md` (the inner-loop discipline that writes the trail one of the indexed sources).
- `.claude/skills/orchestrating-swarms/SKILL.md` (the swarm lead that emits one manifest per worker per ADR-0017).
- `.grok/templates/research.md` (the producer of `research_refs`, indirectly indexed via the request source).
- `claude-tdd-pro/docs/architecture-v1.9.md §2.8 AI Provenance Manifest` (the upstream per-commit manifest the harness manifest cross-references via `upstream_provenance_manifest_ref`).

This doc does NOT duplicate the content it points at (R-3).

D-1 reverse attribution per ADR-0013: this Cursor / Claude-side audit-bridge design's Grok-side analog is the `research_refs` field already carried in the handoff contract per `.grok/templates/dispatch.md` (the outer loop already serializes provenance into the wire format); the manifest is the cross-tool index that makes the existing wire-format provenance auditable in one read.
