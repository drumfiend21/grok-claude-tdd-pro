# GCTP → CTP handoff — P-10: `composite-dispatch.sh` bash 3.2 empty-array crash (unblock GCTP's routed-tool enforcement)

**Written:** 2026-07-01 · **From:** GCTP (`grok-claude-tdd-pro`) local session, pin `4668c2e`
**For:** the CTP chat / a `claude-tdd-pro` maintainer session
**Ask:** assess + fix a bash-3.2 portability crash in `rubric/composite-dispatch.sh` that renders
the entire routed-FOSS-tool enforcement path **inert on macOS default bash 3.2** for any consumer
(GCTP included). GCTP cannot fix it — the prime directive forbids GCTP editing the plugin; this is a
CTP-repo change, followed by a GCTP re-pin.

---

## 0. TL;DR
`rubric/composite-dispatch.sh` aborts with `ra[@]: unbound variable` on **bash 3.2** (macOS default)
before emitting any verdict. Because it's the routing engine every routed-tool path flows through,
the ~80-tool FOSS enforcement produces **no verdicts** on bash 3.2. Native enforcement is unaffected.
One-line guard fixes it. GCTP already ships a `tdd-pro-bash32-portability` skill documenting this exact
gotcha — the fix should conform to it.

## 1. The bug (exact site)
`rubric/composite-dispatch.sh`, the per-tool routing loop (at pin `4668c2e`, ~lines 116-119):

```bash
ra=(); is_required "$t" && ra=(--required)          # ra stays EMPTY when the tool is not --required
toa=(); _topt="$(… node …)"                          # toa stays EMPTY when the rule has no tool-options
[ -n "$_topt" ] && toa=(--tool-options "$_topt")
bash "$RUNNER" --tool "$t" --file "$FILE" "${ra[@]}" "${toa[@]}" --json > "$SARIF_DIR/$t.sarif" 2>/dev/null
```

Under `set -uo pipefail` on **bash 3.2**, expanding an **empty array** — `"${ra[@]}"` (and `"${toa[@]}"`)
— throws `ra[@]: unbound variable` and aborts the script (exit 1). This fires in the **common case**
(tool not `--required`, no tool-options), so most `--file` dispatches crash.

- **Symptom:** `composite-dispatch.sh: line 119: ra[@]: unbound variable` on stderr; exit 1; **no**
  `composite-dispatch … status=<green|red>` summary line is emitted.
- **Class:** identical to GCTP proposal **P-1** (`install.sh` `conflicts[@]`) — the classic bash-3.2
  empty-array-under-`set -u` gotcha. bash ≥ 4.4 does not have this behavior; macOS ships 3.2.57 as `/bin/bash`.

## 2. Reproduction (deterministic, from the plugin cache)
```bash
CLAUDE_PLUGIN_ROOT="$PWD" /bin/bash rubric/composite-dispatch.sh --file <any-routed-file>
# → rubric/composite-dispatch.sh: line 119: ra[@]: unbound variable ; exit 1 ; no status= line
```
(Confirmed on Darwin arm64, `/bin/bash` 3.2.57, against `4668c2e`.)

## 3. Impact on the consumer (GCTP), and why the harness stays safe
GCTP wired the composite engine across three phases; all three flow through `composite-dispatch`:
- **Pre-write governor** (GCTP ADR-0075, §28.60 tools half), **on-save** (GCTP ADR-0076 / W-C),
  **audit-time whole-tree** (GCTP ADR-0077, via `composite-audit.sh` → `composite-dispatch`).

On bash 3.2 each gets a bare exit-1 crash with no verdict → GCTP's **parse-then-block** discipline
(act only on an authoritative `status=red` line) correctly treats it as "no verdict," so there are
**no false reds** — but also **no routed-tool verdicts at all**. So the ~80-tool FOSS enforcement is
**wired but dark** on bash 3.2. **Native** enforcement (`enforce-file.sh`, `enforce-standards-pre-write.sh`)
is a separate path and works — pre-write/on-save/audit still enforce natively.

## 4. Proposed fix (CTP to assess; conform to the bash32 skill)
Guard the empty-array expansions — the standard bash-3.2-safe pattern:
```bash
bash "$RUNNER" --tool "$t" --file "$FILE" "${ra[@]+"${ra[@]}"}" "${toa[@]+"${toa[@]}"}" --json > …
```
(or seed / length-test the arrays before expansion). Sweep the file (and siblings — `run-tool.sh`,
`composite-audit.sh`, `sarif-aggregate.sh`) for the same `"${arr[@]}"`-on-possibly-empty pattern; the
`tdd-pro-bash32-portability` skill's checklist (associative arrays, `set -u` + empty arrays, …) is the
authority. A regression test should invoke `composite-dispatch --file` on a routed file whose tool is
neither `--required` nor option-bearing, under bash 3.2, and assert a clean `status=` line + no
`unbound variable`.

## 5. Coordination back to GCTP (after the CTP fix lands)
1. CTP fixes + tests + tags/pushes a commit on `claude-tdd-pro`.
2. Notify GCTP of the new commit SHA.
3. GCTP re-pins `docs/claude-tdd-pro.lock.yaml` `230e99d`→…→`<fixed>` via an **ADR-gated pin bump**
   (the ADR-0072 procedure) — no other GCTP change needed; the already-wired tools paths (pre-write /
   on-save / audit-time) **activate automatically** once `composite-dispatch` emits real verdicts.
4. GCTP's `docs/upstream-ctp-proposals.md` §P-10 flips 🟥 OPEN → ✅ ADOPTED at that pin.

## 6. Context / cross-refs
- GCTP proposal record: `docs/upstream-ctp-proposals.md` §P-10 (OPEN, filed 2026-06-30).
- GCTP consumers depending on this: ADR-0075 (pre-write), ADR-0076 (on-save), ADR-0077 (audit-time).
- GCTP current pin: `4668c2e`. Prime directive: GCTP consumes CTP by pinned reference only and does
  not edit the plugin — hence this handoff rather than a cross-repo patch.
- Precedent: P-1 (same class, ADOPTED in CTP CL-476 / §28.16).
