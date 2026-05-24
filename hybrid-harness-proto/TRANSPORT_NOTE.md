# TRANSPORT NOTE

This directory is **NOT a claude-tdd-pro feature**. It is the scaffold for a separate prototype repo (`hybrid-harness-proto`) being transported between two cloud sessions and a local machine.

## What to do with it

1. Pull the branch `claude/zealous-keller-FqKZA`.
2. Copy this entire `hybrid-harness-proto/` directory to a new location outside this repo (e.g. `~/projects/hybrid-harness-proto/`).
3. In that new location: `git init`, add your new GitHub remote, commit, push.
4. Delete this branch from claude-tdd-pro after extraction — it should never merge to `main`.

## Why it's living here temporarily

The cloud session that produced this scaffold is ephemeral and has GitHub MCP scope restricted to `drumfiend21/claude-tdd-pro` only — it can't create or push to a new repo directly. Riding on a throwaway branch of this repo is the transport mechanism.

## Drift discipline

This directory MUST NOT be:

- merged to `main`
- referenced from any claude-tdd-pro spec, architecture doc, or skill
- counted toward any feature ID in `docs/architecture-v1.9.md`

It exists to be extracted and deleted.

## Contents

See `README.md` in this directory for the prototype repo's own readme, and `TICKETS.md` for the work backlog. Sessions inside the prototype repo follow `CLAUDE.md` in this directory (which itself defers to claude-tdd-pro's CLAUDE.md for TDD discipline).
