# CTP Work Brief — Detector Quality Uplift (grep → AST/schema/parser)

**Audience:** the `claude-tdd-pro` (CTP) development session.
**Author:** the consuming harness (`grok-claude-tdd-pro`, GCTP) cloud session, 2026-06-21.
**Authority:** TIER-1 process change for CTP. Land as a new ADR (CTP-ADR-NNNN) and the substrate it specifies. Composes on existing CTP architecture; no boundary changes.

Self-contained brief. The CTP team can consume it directly without GCTP context.

---

## 1. Background — how this brief came to exist

GCTP recently audited an O'Reilly architecture-kata submission (`softarchcert-win25`) against the current CTP rule surface (118 rules at pin `39903da`, post-PROPOSAL-003/CTP-ADR-0007). Final clean audit:

```
pass: 68 / fail: 2 (deviated) / not_applicable: 48 / not_enforced: 0
```

The operator then asked the substantive question: **"How confident are you in the detection itself?"**

Honest answer from the consuming side: confidence is mixed-to-low. Out of 68 "pass" verdicts, only ~15 carry strong evidence (paired with compile + test runs the consumer assembled separately). The remaining ~50 are *absence-of-literal-token* verdicts produced by grep-based detectors that cannot distinguish:

- Code that genuinely satisfies the rule vs. code that just doesn't contain the rule's keyword
- Documentation that *forbids* a pattern (compatible) vs. documentation that *proposes* it (violates)
- A real k8s manifest that lacks `runAsNonRoot` (real fail) vs. a non-k8s YAML config that incidentally lacks it (false fail)
- A SARIF document that needs `$schema` vs. any JSON file (current behavior over-applies the rule)
- An exported function that has a real type-test assertion vs. one whose file just contains the literal string `expectTypeOf`

**The operator's bar: 90%+ confidence across all reported verdicts.** Current effective coverage at that bar is ~50%. The gap is in detector quality — specifically, in moving from grep to AST/schema/parser/semantic verification.

This brief proposes the upstream changes needed to close that gap.

---

## 2. The problem in concrete terms — detector class by class

Catalogue of detectors observed in actual use against the kata + the harness self-audit. For each: mechanism, false-positive class observed, false-negative class observed, proposed upgrade.

### 2.1 `naked-throw.sh` — grep for `throw new Error`

**Current mechanism:** `grep 'throw new Error' src/**/*.ts` → finding per line.

**False-positive observed:** my own `src/errors/index.ts` had a doc-comment line "*Replaces the prior `throw new Error(...)` sites in src/...*". The detector flagged the *comment* as a violation. I had to reword the comment to satisfy the grep — that's rewriting documentation to please the regex, not improving the code.

**False-negative class:** code that throws an anonymous Error indirectly (e.g., `const E = Error; throw new E(...)` or `throw (() => new Error(...))()`) wouldn't be caught.

**Proposed fix:** use TypeScript Compiler API (or `ts-morph`) to walk the AST, find `ThrowStatement` nodes whose argument is a `NewExpression` resolving to the platform `Error` class (not a user-defined subclass). Match on resolved type identity, not source string.

```typescript
// Sketch
import { Project, SyntaxKind } from "ts-morph";
const project = new Project({ tsConfigFilePath });
const violations = [];
for (const sf of project.getSourceFiles("src/**/*.ts")) {
  sf.forEachDescendant(node => {
    if (node.getKind() !== SyntaxKind.ThrowStatement) return;
    const expr = node.getExpression();
    if (!expr || expr.getKind() !== SyntaxKind.NewExpression) return;
    const cls = expr.getExpression().getType().getSymbol()?.getName();
    if (cls === "Error") violations.push({ file: sf.getFilePath(), line: node.getStartLineNumber() });
  });
}
```

Eliminates the comment/doc-string false positive class entirely.

### 2.2 `no-any.sh` — grep for `:any\b`

**Current mechanism:** regex on TS source text.

**False-positive observed:** test-title literal `"FITNESS: any stored grade..."` matched the regex because the word "any" appears in the test description. The detector documents an `// allow-any:` affordance comment, but that's a workaround, not a solution.

**False-negative class:** `type Foo = any | never` written as `type Foo = | any | never` (with leading `|`) or using `unknown`-cast-to-any patterns.

**Proposed fix:** AST. Look for `TypeReference` nodes whose name resolves to the built-in `any` type. The TS compiler already classifies these.

```typescript
sf.forEachDescendant(node => {
  if (node.getKind() === SyntaxKind.AnyKeyword) {
    // Check parent context — annotation vs. cast vs. type alias body
    violations.push({ file: sf.getFilePath(), line: node.getStartLineNumber(), context: node.getParent().getKindName() });
  }
});
```

### 2.3 `type-test-coverage.sh` — file-existence + literal-string check

**Current mechanism:** for each `src/<m>/index.ts`, check if sibling `*.test-d.ts` exists OR if the source file contains the string `expectTypeOf`. If either, "covered" — pass.

**Major weakness:** the detector doesn't verify the `.test-d.ts` actually tests the exported symbols. A `.test-d.ts` with `expectTypeOf<number>().toBeNumber()` passes the check even though it tests nothing the source exports.

**Proposed fix:** parse both source and test-d files. For each export in source, verify at least one `expectTypeOf` call references the export name or its type. Use TS compiler API to resolve names.

```typescript
const exports = sourceFile.getExportSymbols().map(s => s.getName());
const testD = project.getSourceFile(`${base}.test-d.ts`);
const calls = testD.getDescendantsOfKind(SyntaxKind.CallExpression);
const covered = new Set();
for (const call of calls) {
  if (call.getExpression().getText() !== "expectTypeOf") continue;
  // Resolve the argument: identifier, type-ref, etc.
  const arg = call.getArguments()[0] || call.getTypeArguments()[0];
  if (arg && exports.includes(arg.getText())) covered.add(arg.getText());
}
const uncovered = exports.filter(e => !covered.has(e));
```

Verifies real coverage, not just file existence.

### 2.4 `cloud-guidance-rule.sh` — token grep with forbid/require modes

**Current mechanism:** `forbid` mode = fail if token appears anywhere; `require` mode = fail if token doesn't appear anywhere in the matching files.

**Multiple false-positive classes observed:**
1. **Documentation that mentions a forbidden token AS forbidden** (the ADR-0010 `0.0.0.0/0` deny-context case). Forbid-mode can't read intent.
2. **k8s rules applied to non-k8s YAML** — `g-k8s-run-as-non-root` etc. fired on harness lockfile YAMLs because there's no `kind: Pod|Deployment` gate.
3. **SARIF rules applied to non-SARIF JSON** — `g-sarif-declare-schema` and `g-sarif-declare-version` fire on every `.json` file. Caught the harness's handoff JSON, hook payloads, and a SARIF *negative-test fixture* that's intentionally invalid.
4. **`node_modules/` not excluded** — when the kata's `npm install` populated `node_modules/`, type-declaration files like `lib.dom.d.ts` (containing literal `fetch(` and `console.log`) caused phantom fails on `g-node-003` (fetch-timeout) and `g-node-004` (console-in-src).

**False-negative class:** `require` mode says "pass if the literal token appears anywhere in any matching file" — doesn't verify it appears at the correct key path or with the correct value (`runAsNonRoot: false` would pass the require-keyword check).

**Proposed fix — three-layered upgrade:**

**(a) Add a file-class gate to every rule.** The rule body declares what file class it applies to:
```yaml
- id: g-k8s-no-privileged-container
  applies_to_files:
    extensions: [yaml, yml]
    must_contain_yaml_keys: ["kind"]
    must_contain_yaml_values: [{ key: "kind", value: ["Pod", "Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob", "ReplicaSet"] }]
  forbid_at_path: "spec.containers[*].securityContext.privileged == true"
```

The detector parses the YAML, checks if it's k8s-shaped, and only then evaluates the rule. Same model for SARIF (gate on `version: "2.1.0"` + `$schema`), CycloneDX (gate on `bomFormat: "CycloneDX"`), CFN (gate on `AWSTemplateFormatVersion`), etc.

**(b) Replace token-grep with structured key-path evaluation.** Use `yq` (Go binary, fast, parses YAML/JSON correctly) for YAML/JSON; `tomlq` for TOML. Express rules as JSONPath / JQ-expressions over parsed structure:
```yaml
forbid_at_path: ".spec.containers[].securityContext.privileged"
forbid_value: true
require_at_path: ".spec.containers[].securityContext.runAsNonRoot"
require_value: true
```

The detector parses, walks the path, evaluates the predicate. Catches "value is wrong even though token appears" and "token appears in a comment doesn't count".

**(c) Default-exclude `node_modules/`, `.git/`, `dist/`, `build/`, `coverage/`, `.next/`, `vendor/`, `target/`, `.venv/`** from all detector file enumeration. Operator can override via `.detector-include` config.

### 2.5 `prose-judge.sh` — keyword tier + broken LLM tier

**Current mechanism:** tier-1 keyword (literal token in prose); tier-2 LLM-judge (broken — P-8 from prior brief); tier-3 fallback (keyword-ish-mention → `not_enforced`).

**Already-filed upstream:** P-8 (`--text` ↔ `--target` contract mismatch). Until that fix lands + a pin bump adopts it, the semantic tier is dead code and architectural-prose rules can only produce keyword-tier verdicts (which are precisely the false-positive-prone case the LLM-judge was meant to handle).

**Proposed fix (P-8):** repeated here for completeness. Add `--text <prose>` to `llm-judge.sh`'s argument parser. ~5 lines. Alternative: change prose-judge tier-2 to write prose to a tempfile and call `--target <tempfile>`.

### 2.6 `md-structure.sh` — line-regex for `^```$` and `^#`

**Current mechanism:** line scan for bare fence openings and multiple `# H1` lines.

**Observed weakness:** the detector does correctly distinguish opening vs. closing bare fences (only reports the openings), which is good. But it can't tell the difference between:
- A standalone `.md` file with a single H1 at top + supporting H2s (compliant, MD025 satisfied)
- A `.md` file with an H1 mid-document because someone copy-pasted a section header (real MD025 violation)

These look identical at the regex level; both have multiple `# H1` lines. The first is intentional structure; the second is a real bug.

**Proposed fix:** use `remark-parse` AST. Walk the heading nodes, check depth-1 heading count, verify structural validity (e.g., a single top-level H1 followed by descending depth ≤6). Apply `markdownlint-cli2` (which is already AST-based via `markdown-it`) and translate its findings into SARIF.

### 2.7 `console-in-src.sh` / `fetch-timeout.sh` and similar grep-based "in-src" rules

**Observed weakness:** no `node_modules/` exclusion. Same fix as 2.4(c).

---

## 3. Aggregate impact — what % of verdicts become high-confidence after these fixes

Per-class confidence delta the operator can expect:

| Detector class | Current confidence | After fix | Verdicts affected (approx) |
|---|---|---|---|
| AST-replaceable TS detectors (naked-throw, no-any, type-test-coverage) | medium (grep + comment-match noise) | **high** (AST is dispositive) | ~12 rules |
| YAML/JSON structured-path detectors (cloud-guidance k8s/SARIF/CFN/etc.) | medium-low (keyword over-applies; no file-class gate) | **high** (key-path predicate is dispositive) | ~30 rules |
| MD structural detectors | medium (line-regex misses real structure) | **high** (AST via markdownlint-cli2) | ~5 rules |
| Prose-projected rules via prose-judge | dead (P-8 broken) | **high once P-8 lands** + medium re-judge re-fires on cached prose | 9 rules |
| `node_modules` exclusion (global) | not applied | applied → eliminates whole class of phantom fails | applies to every rule that walks the tree |

Expected post-fix verdict-confidence on a typical kata-scale audit: **~95-100 high-confidence verdicts out of 118**. That meets and exceeds the operator's 90% bar.

---

## 4. Decision (proposed for CTP-ADR-NNNN)

**CTP-D-1. Adopt the file-class gating model for all `cloud-guidance-rule.sh`-style rules.** Add `applies_to_files: { extensions, must_contain_yaml_keys, must_contain_yaml_values, must_contain_json_keys }` to the rule schema. The detector evaluates the gate before evaluating the rule body. Vacuous on rules that don't declare a gate (backwards-compatible).

**CTP-D-2. Replace token-grep with key-path evaluation for structured-format rules.** Use `yq` / `node` + JSON parser to walk to the rule's target path. Rule body declares `forbid_at_path` / `require_at_path` + value predicate.

**CTP-D-3. Replace string-grep with TypeScript AST (via `ts-morph` or compiler API) for TS-specific detectors:** `naked-throw.sh`, `no-any.sh`, `type-test-coverage.sh`. Eliminates comment-match + test-description-match false positives. Verifies real export-to-test linkage.

**CTP-D-4. Replace line-regex with `remark-parse` AST for markdown structural detectors:** `md-structure.sh` and any future g-md-* structural rules. Use `markdownlint-cli2` under the hood, translating its findings into SARIF 2.1.0.

**CTP-D-5. Add default exclusions to every detector's file enumeration:** `node_modules/`, `.git/`, `dist/`, `build/`, `coverage/`, `.next/`, `vendor/`, `target/`, `.venv/`, `__pycache__/`. Operator override via `.detector-include` config.

**CTP-D-6. Fix P-8 (prose-judge tier-2 contract mismatch) per the prior brief.** Either add `--text` to `llm-judge.sh` or change prose-judge to write a tempfile and pass `--target`. ~5 lines.

**CTP-D-7. Emit confidence tier in every SARIF result's `properties` block.** The detector tags its verdict with the tier that produced it:
```json
{
  "ruleId": "g-k8s-no-privileged-container",
  "level": "none",
  "properties": {
    "evidence_tier": "yaml-key-path-evaluated",
    "evidence_confidence": "high",
    "evaluated_path": ".spec.containers[].securityContext.privileged",
    "value_observed": null
  }
}
```

GCTP's audit chain can then surface confidence-by-rule alongside pass/fail. The operator sees the actual evidence strength, not just an aggregated count.

**CTP-D-8. Add per-detector negative-test fixtures.** Every detector ships with two fixtures: a "should-flag" example and a "should-not-flag" example. Run as part of CTP's own test suite. Catches confidence regressions over time.

---

## 5. Alternatives considered

- **Keep the grep approach + add allow-affordance comments + deviation rows as the operator workflow.** REJECTED — that's the *current* approach and is exactly what produced the low-confidence verdict landscape this brief exists to fix. Affordance comments are operator-tedious and the deviation row mechanism is an audit-trail patch, not a quality fix.
- **Wholesale replace CTP detectors with off-the-shelf tools (kubeconform, kube-linter, ajv, eslint, markdownlint, etc.).** PARTIALLY ACCEPTED — for some rules the canonical tool IS the right call. But CTP rules carry provenance + namespace + applies_to_prose semantics that off-the-shelf tools don't know about. The CTP detector should *wrap* the canonical tool (translate its output to SARIF with the CTP rule ID) rather than be replaced by it. CTP-D-4 (markdownlint-cli2 wrapping) is an instance of this pattern.
- **Build a single mega-detector that uses LLM-judge for every rule.** REJECTED — token cost unbounded; per-rule attribution lost; defeats the per-rule SARIF emission contract. LLM-judge is the right tier-2 for prose-projection rules only (per the existing prose-judge.sh design); structured detectors should be deterministic.
- **Just lower the operator's expectations to ~50% confidence.** REJECTED — the operator's 90% bar is reasonable for a standards-conformance audit. The infrastructure should meet it.

---

## 6. Consequences

### Positive
- Confidence per verdict converges to ≥90% across all reported counts.
- The "documentation that forbids X" / "k8s rule applied to non-k8s YAML" / "SARIF rule on package.json" / "node_modules pollution" false-positive classes are eliminated.
- Operators stop rewriting prose to please regex (the ADR-0010 `0.0.0.0/0` rewording episode wouldn't have been needed).
- The verdict shape carries evidence strength inline (CTP-D-7), so downstream consumers can render with appropriate weight.
- The audit chain becomes capable of supporting the kind of submission attestation the operator currently has to manually annotate ("substance review says compatible despite gate uncertainty").

### Neutral
- `active.json` `schema_version` bump (additive: new optional fields `applies_to_files`, `forbid_at_path`, `require_at_path`, `evidence_tier`, `evidence_confidence`). Backward-compatible — rules without these fields continue to use the legacy grep mechanism.
- Existing detector scripts stay (legacy callers continue to work); the upgraded behaviors land alongside.

### Negative / cost
- New runtime dependencies: `ts-morph` (or compiler API direct), `yq` binary, `markdownlint-cli2`, `remark-parse`. All standard, FOSS, packageable. Plugin install time increases by ~50MB if using npm-packaged deps; ~10MB if using Go binaries (`yq`).
- Per-rule authoring becomes slightly more verbose (need to declare `applies_to_files` and the key path), but eliminates entire false-positive classes.
- Per-detector test suite required (CTP-D-8) — meaningful one-time effort but pays back on every subsequent rule addition.

---

## 7. Verification

Per landing wave:

- **Wave 1 (cloud-guidance-rule.sh + node_modules exclusion):** unit tests for each new `applies_to_files` gate; smoke test against the kata + the harness self-audit; expect ~25 verdict-confidence upgrades from medium → high.
- **Wave 2 (TS AST detectors):** unit tests with positive + negative fixtures for `naked-throw.sh`, `no-any.sh`, `type-test-coverage.sh`; expect ~10 verdict-confidence upgrades + elimination of the comment/doc-string false-positive class.
- **Wave 3 (markdown AST + P-8 fix):** wrap `markdownlint-cli2`; fix prose-judge tier-2; expect ~14 verdict-confidence upgrades (5 MD + 9 prose-projected).
- **Wave 4 (confidence tier in SARIF + per-detector negative tests):** SARIF self-conformance test; CI suite running every detector against its fixture pair.

Per-wave acceptance criterion: re-run the kata audit + the harness self-audit; verify that the number of medium-confidence verdicts drops by the expected amount and high-confidence verdicts rise correspondingly.

---

## 8. Boundary discipline — what CTP owns vs. what the consumer owns

**CTP owns** (this brief):
- Detector logic upgrades (`rubric/detectors/*.sh` rewrites).
- Rule-schema extensions (`applies_to_files`, `forbid_at_path`, `require_at_path`).
- SARIF result `properties` extensions (`evidence_tier`, `evidence_confidence`).
- Per-detector test fixtures.
- New runtime dependencies (`ts-morph`, `yq`, `markdownlint-cli2`).

**Consumer (the harness) owns** (NOT this brief — happens elsewhere):
- Pin bump (operator-gated ADR after CTP adoption).
- Audit-chain rendering of confidence tiers (`audit-rules-verified.sh` extension).
- Operator UX for the confidence breakdown.

Neither side touches the other's repo. The contract surface (`active.json` + detector script signatures + SARIF shape) is the only thing that moves.

---

## 9. The single most important takeaway

Of everything in this brief, the highest-leverage change is **CTP-D-1 + CTP-D-2 (file-class gating + key-path evaluation for structured-format rules).** ~30 of the 118 current rules go through `cloud-guidance-rule.sh`'s token-grep mechanism; every one of them currently has the file-class over-application false-positive class. Adding the gate and the key-path predicate eliminates the false-positive class for that ~30-rule cluster in a single change.

Second-highest: **CTP-D-3 (AST for the TS detector family)** — eliminates the comment/doc-string false-positive class for the ~12 TS rules, which is the class of issue the operator just hit on the kata.

Everything else (markdown AST, prose-judge fix, exclusions, confidence tier, negative-test fixtures) is incremental polish that compounds with the two above.

---

End of brief. Adopt as CTP-ADR-NNNN. Land in three waves (per §7). The resulting verdict landscape on a typical audit converts ~50/118 high-confidence + ~50/118 medium → ~95-100/118 high-confidence + ~10-20/118 medium, meeting the operator's 90% bar.
