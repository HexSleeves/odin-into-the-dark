---
name: loop-triage
description: Discover and rank the highest-value next work for the autonomous loop. Reads CI/verify status, open GitHub issues, and the roadmap, then writes a prioritized worklist into .claude/LOOP_STATE.md. Run at the start of every loop cycle.
---

# Loop Triage

The discovery heartbeat of the loop. Surfaces work; does not do the work. A separate tick
acts on what this surfaces.

## Use When

- Starting a fresh loop cycle (`/loop-tick`, a scheduled task, or CI cron)
- The "Open" section of `.claude/LOOP_STATE.md` is empty or stale
- You want a ranked snapshot of "what is most worth doing right now"

## Steps

### 1. Read current loop memory

```bash
cat .claude/LOOP_STATE.md
```

Note what is `In progress` (don't re-surface it) and what is in `Tried + failed` (don't
re-suggest the same failed approach).

### 2. Check the gate — is the repo green?

```bash
just verify 2>&1 | tail -40
```

A red `just verify` is **always the top finding**. Capture the exact failing test name or
build error. Nothing else matters until the gate is green.

### 3. Pull open tracked work from the board

```bash
gh issue list --repo HexSleeves/odin-into-the-dark --state open \
  --json number,title,labels,milestone --limit 30
```

Prefer issues already on the board / in a milestone. Bugs outrank features.

### 4. Read the roadmap for untracked candidates

```bash
sed -n '/## Remaining work/,$p' NEXT_STEPS.md
```

If a roadmap item is worth doing but has no issue, note it as a candidate to file (via the
`create-work-item` skill) rather than starting it untracked.

### 5. Rank and write the worklist

Rank by: **broken gate > regression/bug > small high-value feature > roadmap polish**.
Each item must be small enough for one tick to finish and verify. Split anything bigger.

Overwrite the `## Open — triaged, ready to pick` section of `.claude/LOOP_STATE.md` with the
ranked list. Each entry, one line:

```
- [#42] <title> — <why it's worth doing> — <first file/test to touch>
```

For a red gate, write it as the first entry with the exact error:

```
- [GATE RED] combat_rolls_test failing: `expected 12, got 8` in test/combat_rolls_test.odin — fix before anything else
```

### 6. Report

Print the top 3 findings and stop. Do not start implementing — that is the tick's job, with
isolation and a separate verifier.

## Rules

- Surface, don't fix. This skill is read-mostly; its only write is the worklist.
- Never surface something already `In progress` or in `Tried + failed`.
- Items must be tick-sized (one fix, one feature slice) — split big work.
- A red `just verify` always wins.
