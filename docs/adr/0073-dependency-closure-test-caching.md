# ADR-0073 — Dependency-closure test-result caching (cache a suite until its code-under-test changes)

- **Status:** Accepted
- **Date:** 2026-06-30
- **Deciders:** operator (`drumfiend21`; 2026-06-30 directive: *"unit tests should be cached after the first run until the function(s) it tests are updated or deleted; same for integration tests"*) + Claude Opus 4.8 (local session).
- **Trigger:** `tests/test-all.sh` re-runs all 37 suites every invocation; several (standards-enforced, standards-sync, sync-plugin, smoke, generative-integration) re-run detectors / clone the plugin and are slow. Re-running a suite whose code-under-test is unchanged is wasted work.
- **Analog:** CTP §28.53 "scoped eval cache — per-spec dependency-closure hashing" (the plugin-side equivalent, adopted at pin `4668c2e`). This ADR is the harness-side version over shell test suites.

## Decision

Add `scripts/_lib/test-cache.sh` and wire it into `tests/test-all.sh`. A suite that **passed** and whose **closure hash** is unchanged is served from cache instead of re-run.

### Closure hash (what invalidates a cached result)

At **file granularity** (a function edit is a file edit — function-level caching is impractical and unnecessary in shell), the closure of a suite `tests/test-<X>.sh` is:

1. the test file itself;
2. every `.sh` file under `scripts/` the test references (its code-under-test), discovered by scanning the test for script paths;
3. every `scripts/_lib/*.sh` those scripts source (transitive deps, one level);
4. the **external epoch** — the plugin **pin** (`epoch_current_pin`, from the tracked lockfile).

Any change to those inputs changes the hash and forces a re-run — satisfying "until the function(s) it tests are updated or deleted."

### Why the pin, and why NOT `active.json`

A suite can flip verdict with **unchanged test/script code** when the plugin changes — observed directly this session: `test-audit-design-phase-md` passed at `230e99d` and failed at `4668c2e` on the pin bump alone (the plugin wired the `.md` bundle). So the plugin pin **must** be in the closure; a pin bump then invalidates every entry.

`active.json` is deliberately **excluded**, despite tests depending on it: `standards-sync.sh` regenerates it **non-deterministically** (byte-unstable for the same pin — proven this session: the closure hash changed across a no-op `standards-sync` run). Including it makes the hash unstable, so the cache never hits — defeating the feature. The pin captures the plugin version that drives rule content. **Residual limitation:** a mid-session standards *refresh* that changes rules WITHOUT a pin bump would not invalidate the cache; this is rare (default 1d cadence) and the operator escapes with `--no-cache` / `--clear-cache`.

### Safety

- **Only passing results are cached.** A failing suite is never skipped — it re-runs every invocation until it passes, and any stale entry is dropped on failure. A cache HIT therefore means "this exact closure passed before," which remains true while the hash matches.
- **Default-on**, with `--no-cache` (full run, ignore + do not update the cache — CI-safe escape) and `--clear-cache` (wipe then run fresh).
- Cache store: `.harness/test-cache/<suite>.hash` — operator-local (`.harness/` is gitignored); test results are environment-specific and not shared via git.

## Consequences

### Positive
- Warm runs skip every unchanged passing suite — the slow detector/clone suites stop re-running when their code hasn't changed.
- The closure ties invalidation to the actual code-under-test + plugin pin, so a real change (script, lib, or pin bump) always re-runs the affected suites.

### Neutral / limitations (documented, not hidden)
- File-granularity, not function-granularity (a function edit re-runs the whole suite — correct, just not minimal).
- Closure discovery is by script-path scan of the test file; a suite that exercises a script it doesn't name textually would under-capture. Mitigations: the pin component + the fact that only passing+unchanged suites are skipped; `--no-cache` for a trusted full run.
- The `active.json`-refresh residual case above.

### Negative
- A new gitignored cache dir + a small amount of hashing per suite per run.

## Verification
- `tests/test-test-cache.sh` — 13/13 hermetic (determinism; sensitivity to test-file / script / transitive-lib / **pin** changes; `active.json` proven NOT to affect the hash; lookup/store/clear).
- End-to-end: two `test-all.sh` runs — the second serves every unchanged passing suite from cache; the one documented failing suite (`test-audit-design-phase-md`, ADR-0072 deferred red) re-runs each time.
- Prime directive: no `claude-tdd-pro` path touched. D-6: `docs/founder-directives.md` unchanged.

## Implementation references
- Library: `scripts/_lib/test-cache.sh` (reuses `epoch_current_pin` from `scripts/_lib/epoch-gate.sh`, ADR-0071) · Tests: `tests/test-test-cache.sh`
- Runner integration: `tests/test-all.sh` (`--no-cache` / `--clear-cache`)
