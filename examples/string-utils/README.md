# examples/string-utils — TICKET-005 toy module

Tiny JavaScript module used to demonstrate the grok-claude-tdd-pro harness end-to-end. The outer-loop pipeline (`.grok/templates/` research → decomposition → dispatch) emits a handoff document; the inner loop (claude-tdd-pro via `.claude/skills/tdd-pro-cl-workflow`) runs Red-Green-Refactor against this module to close the missing behavior.

## Run

```bash
node --test examples/string-utils/test/string-utils.test.mjs
```

**Expected at TICKET-005 commit:** 4 pass, 1 fail, `exit=1`. The failing test is the "obviously-missing behavior" the R-G-R cycle is meant to fix.

## The missing behavior

`slugify('  hello world  ')` should return `'hello-world'`, but currently returns `'-hello-world-'` because the function does not trim leading/trailing whitespace before collapsing internal whitespace runs.

The fix is one line: add `.trim()` after `.toLowerCase()`. That is the **Green** step. The **Refactor** step (if any) might collapse the three chained `.replace`/`.trim` calls into a clearer form, but only if it reduces cognitive load — Musk's Algorithm step 3 says simplify, not embellish.

This particular missing behavior is the same one telegraphed by the worked example in `docs/handoff-contract.md §"Example: happy path"` (TICKET-042 there dispatches the same slugify whitespace gap). That alignment is intentional: the contract example shows the wire format on this exact case, and TICKET-006's smoke script will use this module to make that example real.

## Why this exists

TICKET-005 introduces the first executable artifact in the harness that the inner loop can operate on. The outer-loop substrate (research/decomposition/dispatch templates) and the inner-loop wiring (skill symlinks into the pinned plugin) are complete; this module is what they act *on*.

## D-5 lockdown notice

Per founder-directive **D-5** (production-grade problem instances are the work; toy examples are scaffolding only):

> No CL after TICKET-005 lands purely against the toy module. Once the toy validates the loop, every subsequent CL targets a real ticket, a real repo, a real org. If the loop breaks on a real problem, the fix lands against the real problem; reverting to the toy as a workaround is forbidden without an ADR documenting why.

The TICKET-006 smoke script will dispatch the R-G-R cycle against this module *one time* to prove the loop closes end-to-end. After that, this module is a museum piece. Any later edit to `examples/string-utils/` either documents the demo's history or requires an explicit ADR per D-5.

## Layout

```
examples/string-utils/
├── README.md                              this file
├── src/
│   └── string-utils.mjs                   the slugify implementation (missing .trim())
└── test/
    └── string-utils.test.mjs              5 tests, 4 pass + 1 red
```

No `package.json`, no `node_modules`, no test framework dependency. Node 18+ built-in `node:test` runner is the entire toolchain — the simplest thing that demonstrates the loop.

## Cross-references

- Handoff-contract worked example: [`../../docs/handoff-contract.md §"Example: happy path"`](../../docs/handoff-contract.md)
- D-5: [`../../docs/founder-directives.md §3 D-5`](../../docs/founder-directives.md)
- Smoke script that will close this loop: TICKET-006 (next).
