# tests/integration/ — generative-function integration tests

> 📖 **Prose companion:** for a narrated, stepwise walk-through of one of these flows
> (the Shop-owner / multi-region order pipeline — elicitation → guided decisions →
> architecture → handoff), see [`docs/end-to-end-demo/`](../../docs/end-to-end-demo/README.md).
> This page is the *executable* version of that story.

Per TICKET-052 / ADR-0050. This tier answers one question: **when a non-technical
user describes software in plain English, does the harness deliver world-class
software for their unique use case — across cloud architecture AND fullstack
development?**

"World-class delivery" is concrete and asserted: for the user's *detected stack*,
**every** authoritative-source standard in `.harness/rules/active.json` is enforced
via the handoff's `applicable_rules` — fullstack (`react`, `typescript`, `node`,
`web-vitals`, `w3c`) and cloud/security (`owasp`, `slsa`) — plus the non-exemptible,
two-phase EO governance layer. That includes standards a layperson can never name:
accessibility (WCAG 2.2), Core Web Vitals, OWASP boundary validation, SLSA provenance.

## What's real vs. simulated

- **Simulated (stub mode):** the inner-loop generation. `simulate.mjs` stands in for a
  live `tdd-pro-cl-workflow` R-G-R run. Live-LLM end-to-end is deferred per ADR-0008
  (non-deterministic, needs credentials, not CI-reproducible).
- **Real and asserted:** the Grok→Claude→Grok **wire contract** (`docs/handoff-contract.md`),
  the **world-class-coverage definition**, and the **harness gates** — the suite runs the
  actual `scripts/audit-eo-governance.sh` and `scripts/audit-source-citations.sh` over the
  emitted handoff artifacts.

The harness does not own code generation (prime directive — the plugin does). This tier
asserts the **contract + gates**, never plugin internals.

## Scenarios (`scenarios/*.json`)

| Persona (no technical experience) | Domain | Critical standard they can't name |
|---|---|---|
| Home cook — recipe-sharing web app | fullstack | `w3c` (accessibility) |
| Bakery owner — budget-tracker SPA | fullstack | `web-vitals` (mobile speed) |
| Community volunteer — event board | fullstack | `node` (backend correctness) |
| Photographer — serverless photo-resize API | cloud | `owasp` (input/secret security) |
| Craft-shop owner — multi-region order pipeline | cloud | `slsa` (supply-chain provenance) |
| Nonprofit director — static site + CDN + auth | cloud | `owasp` (auth boundary) |

## Negative scenarios (the gates must BITE)

A green run is only a signal if the gates reject *sub*-world-class delivery:

- **`drop-stack`** — omit the scenario's critical standard family → the stack-coverage
  check rejects it (fullstack a11y AND cloud security cases).
- **`omit-eo-attestation`** — green code with no design-phase EO attestation → the EO
  two-phase gate rejects it.
- **`omit-eo-rule`** — drop the non-exemptible EO rule from `applicable_rules` → the EO
  non-exemptibility gate rejects it.

## Run

```bash
./tests/integration/test-generative-integration.sh            # verbose
./tests/integration/test-generative-integration.sh --quiet    # CI

# Inspect a single delivery (prints a JSON delivery report):
node tests/integration/simulate.mjs \
  tests/integration/scenarios/recipe-sharing-web-app.json \
  .harness/rules/active.json /tmp/out world-class eo-cyber-001
```

`tests/test-all.sh` also discovers this suite, so a single command runs unit + integration.

## Adding a scenario

1. Drop a `scenarios/<id>.json` with `persona`, `plain_request`, `domain`
   (`cloud`|`fullstack`), `detected_stack`, `expected_namespaces`, `critical_namespace`,
   plain-English `acceptance_criteria`, and `file_scope.may_edit`.
2. It is picked up automatically by the runner's `scenarios/*.json` glob.
3. Keep it bash 3.2 + BSD portable; node is the only extra dependency (as for `smoke-e2e`).
