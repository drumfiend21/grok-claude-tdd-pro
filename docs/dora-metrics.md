# DORA Metrics — grok-claude-tdd-pro

**Authority tier:** TIER 2 (operational rulebook). Composes on the TIER-0 corpus, the TIER-1 prime directive, the founder-directives D-rules, and C-24 (DORA metrics are the scoreboard). Amendments via ADR per `docs/architecture-principles.md §19`.

**Trigger:** Per Musk Engineering Leadership letter (2026-05-26) §3 *"Add Metrics — DORA-style scoreboard with real numbers, not principle citations."* The B-grade regrade in this session's review explicitly named C-24's principle-only framing as insufficient — the trigger condition documented in `AUTOMATION_INTEL.md` 2026-05-26 entry was met within the same session, lifting #3 from deferred to ship.

**Status:** v1 — computes 4 of the 4 DORA "Four Keys" metrics from the existing manifest corpus. Time-to-restore is reported as `n/a` at v1 (no restore-event corpus exists; trigger for v2 is the first ticket whose manifest captures a restore-from-incident event).

## 1. Four Keys mapping

The DORA "Four Keys" (Forsgren / Humble / Kim, *Accelerate*, 2018) are:

| DORA key | This harness's mapping | Data source | v1 status |
|---|---|---|---|
| Deployment frequency | Green manifests per week over the observation window | `.harness/audit/TICKET-*.manifest.json` — `status == "green"`, `created_at` extents | SHIPPED |
| Lead time for changes | Median seconds from first-commit-mentioning-ticket to manifest `created_at` | `.manifest.json` + `git log --grep="$ticket_id" --format="%cI"` | SHIPPED |
| Change failure rate | (red + blocked) / total tickets, as percentage | `.manifest.json` — `status` field distribution | SHIPPED |
| Time to restore | n/a at v1 | no restore-event corpus exists; deferred | DEFERRED (v2 trigger: first restore-event manifest) |

**No fabrication.** Every number traces to a manifest field (`status`, `created_at`, `ticket_id`) or a `git log` query against the ticket ID. The harness does not invent numbers it cannot derive from real artifacts.

## 2. Operator procedure

Run the metrics any time:

```bash
./scripts/audit-metrics.sh                 # human-readable summary
./scripts/audit-metrics.sh --json          # JSON output for downstream parse
./scripts/audit-metrics.sh --quiet         # exit code only (CI mode)
./scripts/audit-metrics.sh --dir=<path>    # alternative manifest dir (testing)
```

Sample output (against the current corpus):

```
[audit-metrics] DORA-style metrics from .harness/audit manifest corpus
  Ticket counts:
    total              N
    green              X
    red                Y
    blocked            Z
  Deployment frequency: <real number> green tickets/week  (window: <real> days)
  Change failure rate:  <real>%  (red+blocked / total)
  Lead time (median):   <real> seconds  (first-commit-mentioning-ticket -> manifest created_at)
  Time to restore:      n/a  (no restore-event corpus at v1)
```

JSON mode emits a single line suitable for pipeline parsing:

```json
{"total":N,"green":X,"red":Y,"blocked":Z,"deployment_frequency_per_week":...,"change_failure_rate_pct":...,"lead_time_median_seconds":...,"observation_window_days":...,"audit_dir":".harness/audit"}
```

## 3. Caveats (the v1 honesty section)

- **Small N.** The harness corpus is small at v1 (1+ manifests). Statistical confidence intervals are not meaningful. Numbers should be read as "what the corpus contains right now," not as production benchmarks.
- **Lead time is a proxy.** "First commit mentioning the ticket ID" is an approximation of when work began; if a ticket was scoped (decomposed, planned) before the first commit, the real lead time is longer than reported.
- **Deployment frequency assumes manifest = deployment.** In this harness, each `green` manifest IS a CL-ready change. In a pipeline that batches multiple manifests per deployment, the mapping would need adjustment.
- **Smoke-test manifests count.** The `TICKET-042` manifest produced by `smoke-e2e.sh` is in the corpus and counts toward totals. This is a feature (smoke runs are real exercises of the green path) but operators should know the smoke fixture's contribution is non-zero.
- **No restore-event data.** Time-to-restore stays `n/a` until a ticket manifest captures a restore-from-incident event. v2 trigger: the first such manifest.

## 4. Pre-commit integration policy (deferred)

Per the over-engineering filter, `audit-metrics.sh` is NOT wired into pre-commit at v1. The audit is on-demand + run by `tests/test-all.sh` to verify exit-code contract; metric outputs are not gated. Trigger for pre-commit wiring: operator wants regression alerts on CFR or DF deltas.

## 5. Test discipline

`tests/test-audit-metrics.sh` runs as part of `tests/test-all.sh`. Asserts:

- `--help` exits 0; unknown flag exits 2; default mode exits 0.
- Empty manifest dir produces "no manifests" message and exits 0.
- Synthetic fixture corpus (5 manifests: 3 green + 1 red + 1 blocked) produces total=5, green=3, red=1, blocked=1, CFR=40.0%.
- `--json` mode produces parseable single-line output with the expected fields.
- Default output mentions "DORA" and "ADR-0035".

Uses the **restore-before-assert** pattern (per ADR-0028 §3): tempdir fixtures are removed BEFORE the assertion fires so a failing test cannot leave the tree dirty.

## 6. Authority and amendment

This doc is TIER 2. Amendments follow the ADR process in `docs/architecture-principles.md §19`. New metric additions (e.g., MTTR when the restore-event corpus exists) require an ADR documenting the data source + the DORA / Accelerate canonical mapping. Numeric defaults / thresholds (e.g., "alert when CFR exceeds X%") would land in a future v2 with explicit operator threshold-setting.

## 7. Composition (cited, not duplicated, per R-3)

- `docs/claude-tdd-pro-principles.md §16` C-24 — the principle ("DORA metrics are the scoreboard"); this doc operationalizes it.
- ADR-0019 / ADR-0020 / ADR-0021 — the provenance manifest trilogy that produces the data this script aggregates.
- ADR-0027 §Decision-1 C2 — the prior deferral of `scripts/audit-metrics.sh` (trigger named: "operator reports the one-liners insufficient"). This ADR (0035) records the trigger-firing.
- *Accelerate* (Forsgren, Humble, Kim, 2018) — the DORA Four Keys canonical reference.

## 8. Verification (this doc + script)

| Check | Command |
|-------|---------|
| Script present + executable | `test -x scripts/audit-metrics.sh` |
| Script exits 0 against current corpus | `./scripts/audit-metrics.sh --quiet` exit 0 |
| Test suite passes | `./tests/test-audit-metrics.sh --quiet` exit 0 |
| Doc grep-discoverable | `grep -q '^# DORA Metrics' docs/dora-metrics.md` |
| Doc in TIER-2 enumeration | `grep -q 'docs/dora-metrics.md' AGENTS.md` |
| ADR present | `test -f docs/adr/0035-musk-letter-3-metrics-closure.md` |
