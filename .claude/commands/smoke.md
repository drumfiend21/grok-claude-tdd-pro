---
description: Run the end-to-end harness smoke test (4-artifact stub pipeline)
---

Run the end-to-end smoke (Claude Code mirror of `.cursor/commands/smoke.md`).

Run `./scripts/smoke-e2e.sh` and report the result. It drives one full Red→Green→Refactor cycle against the `examples/string-utils/` toy through the real wire format, emitting `.harness/handoffs/TICKET-042.{req,res}.json` + the decision trail + manifest (+ AIBOM). Expect `smoke OK` and exit 0; the trap reverts the toy to its Red baseline so the run is idempotent.
