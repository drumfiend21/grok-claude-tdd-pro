# tests/fixtures/hook-payloads/

Golden JSON fixtures matching Anthropic's Claude Code hook payload schema as observed in the supported_range declared by `docs/claude-code-compat.yaml`. Per TICKET-031 / ADR-0036, these fixtures pin the contract between Claude Code's hook emitter and this harness's hook consumers.

`tests/test-hook-contracts.sh` feeds each fixture to the matching hook script and asserts the hook produces the documented exit code + output shape. If Anthropic changes a hook payload field, the fixtures stay frozen and the test fails — surfacing the breakage in CI rather than at runtime.

Per `docs/claude-code-compat.yaml` schema: when bumping the supported range, the operator must re-capture fixtures from the candidate Claude Code version and verify the contract test still passes. Stale fixtures = stale contract = silent breakage.

## Fixture index

| File | Hook | Scenario | Expected behavior |
|---|---|---|---|
| `post-tool-use-edit.json` | `post-tool-use-review-gate.sh` | Edit on an allowed path | exit 0 (no violation) |
| `post-tool-use-write.json` | `post-tool-use-review-gate.sh` | Write on an allowed path | exit 0 (no violation) |
| `post-tool-use-forbidden.json` | `post-tool-use-review-gate.sh` | Edit on `.cursor/rules/agent-context.mdc` (generator output per ADR-0014) | exit 2 (violation) |
| `post-tool-use-non-edit.json` | `post-tool-use-review-gate.sh` | Read tool (non-edit; hook is a no-op) | exit 0 (no violation) |

## Re-capture procedure

1. Install candidate Claude Code version.
2. Trigger the hook event in a live session with a known input.
3. Capture stdin via a temporary `tee` shim.
4. Sanitize PII (session_id can be rewritten to a placeholder).
5. Update the fixture file + bump `docs/claude-code-compat.yaml` tested_versions list.
6. Run `./tests/test-hook-contracts.sh` to verify the new fixtures.
7. If green, write ADR bumping `supported_range`.
