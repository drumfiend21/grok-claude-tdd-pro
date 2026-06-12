# examples/sample-output/detector-coverage/

Evidence the rubric supports more than just JS/TS. Captured from the pinned plugin cache (`bba77df`) without re-execution required.

## Why this directory exists

External review flagged the "not proven across languages / projects" gap. The harness's standards pipeline supports multi-language enforcement via the rubric's per-language detector dispatch, but that breadth wasn't visible at the README level. These captured files make it inspectable.

## Files

- **`detectors.txt`** — full list of 50 detector identifiers shipped by the pinned plugin's `rubric/detectors/` directory. Captured via the plugin's own `rubric/list-detectors.sh` script. The dispatcher in `rubric/runner.sh` routes each rule to its named detector. Detector kinds include ESLint wrappers, tsc, ruff (Python), mypy (Python), pylint (Python), and pure-shell-script detectors. Some are documented in the rubric `kind:` taxonomy as `lint` / `tsc` / `ruff` / `mypy` / `pylint` / `script` / `llm`.

- **`namespaces.txt`** — rule count per namespace from `.harness/rules/active.json` at the current pin. 28 active rules across 9 namespaces.

## Language coverage in the active rule set

At the current pin, the 28 active rules tag the following languages via `applies_to`:

| Language / Domain | Source namespaces | Detector examples |
|---|---|---|
| TypeScript | `google` (tsguide), `typescript` (handbook) | `no-any.sh`, `type-test-coverage.sh`, `exhaustive-unions.sh` |
| JavaScript | `google` (jsguide) | shared with TypeScript detectors via wrap_method E-15 |
| Python | `google` (pyguide) | pyink-check (formatter), pylint integration via wrap_method (when ruff config present) |
| React / Next.js | `react` (react-docs, rsc-rfc, nextjs-docs) | `rsc-boundary.sh`, `exhaustive-deps.sh`, `a11y-axe.sh` |
| Node.js | `node` (node-docs, node-best-practices) | `naked-throw.sh`, `console-in-src.sh`, `fetch-timeout.sh`, `boundary-schema.sh` |
| Accessibility | `w3c` (WCAG 2.2) | `a11y-axe.sh` with WCAG §1.3.1 / §2.4.7 / §4.1.2 |
| Performance | `web-vitals` (LCP, INP, CLS) | `bundle-budget.sh`, image/font optimization |
| Supply chain | `slsa` (build provenance) | `supply-chain.sh` for SLSA attestation level 2+ |
| Security boundary | `owasp` (ASVS V5.1, V2.10) | `boundary-schema.sh`, `secret-scan` detector |

## How the dispatch model works

The plugin's `rubric/runner.sh` reads each rule's `detector:` field. For ESLint-wrappable rules, the rule's `detector_config` carries `eslint_rule`, `eslint_plugin_npm`, `wrap_method: E-15` — the runner dispatches through the operator's local ESLint with those flags. For Python rules, it dispatches via ruff / mypy / pylint with the rule's flags. For pure-script detectors, it executes the named shell script under `rubric/detectors/`.

When a tool isn't installed (e.g., no ESLint in the project), the runner produces a `severity: SKIP` finding rather than an error — the operator sees what would have run.

## How to regenerate

```bash
./scripts/sync-plugin.sh --ensure
./scripts/standards-sync.sh    # ensures .harness/rules/active.json is fresh
CLAUDE_PLUGIN_ROOT=.harness/plugin-cache/claude-tdd-pro \
  bash .harness/plugin-cache/claude-tdd-pro/rubric/list-detectors.sh \
  > examples/sample-output/detector-coverage/detectors.txt
cat .harness/rules/active.json | grep -oE '"source_namespace":"[^"]+"' | sort | uniq -c | sort -rn \
  > examples/sample-output/detector-coverage/namespaces.txt
```

## Why this honors the D-5 lockdown

Per founder-directive D-5 (production-grade problem instances are the work; toy examples are scaffolding only), this directory does NOT introduce a new toy module. It only captures evidence from the **existing** standards pipeline. The Node `examples/string-utils/` remains the canonical toy per TICKET-005; nothing in this directory is intended to be R-G-R'd against.
