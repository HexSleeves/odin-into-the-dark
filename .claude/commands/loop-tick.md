# Loop Tick — One Turn of the Autonomous Loop

Run one full cycle of the loop engineering pattern: **discover → isolate → make → check →
land → remember**. Designed to be run by hand, on a cadence with `/loop`, or from a scheduled
task / CI cron. Each tick is self-contained and idempotent: it reads the loop's memory, does
at most one unit of work, and writes back so the next tick continues.

$ARGUMENTS

- `/loop-tick` — pick the top triaged item automatically
- `/loop-tick 42` — force this tick to work issue #42

## The six steps

### 1. Read memory (the spine)

```bash
cat .claude/LOOP_STATE.md
```

Honor it: skip anything `In progress`, never re-attempt anything in `Tried + failed` the same
way.

### 2. Discover (the heartbeat)

Invoke the **loop-triage** skill. It runs `just verify`, lists open issues, scans
`NEXT_STEPS.md`, and rewrites the `Open` worklist in `.claude/LOOP_STATE.md`. A red
`just verify` becomes the top item — fix the gate before any feature.

### 3. Pick one tick-sized item

Take the top `Open` item (or `$ARGUMENTS` if given). One item per tick. If the top item is
too big to finish-and-verify in one tick, split it: file the pieces with the
`create-work-item` skill and pick the smallest. Move the chosen item to `In progress` in
`.claude/LOOP_STATE.md`. If it maps to a board issue, run `/issue-start <N>`.

### 4. Isolate (worktrees so parallel doesn't become chaos)

Work the item in its own checkout so it can't collide with other ticks:

```bash
git worktree add ../itd-loop-<item> -b loop/<item>
```

Dispatch the **loop-implementer** subagent with `isolation: worktree` pointed at that branch.
Hand it exactly the one item plus the relevant `CLAUDE.md` conventions. It writes code +
tests and stops at a self-claimed done — it does **not** grade itself.

### 5. Check (keep the maker away from the checker)

Dispatch the **loop-verifier** subagent (different instructions, stronger model) on the same
worktree. It runs `just verify` itself and renders PASS/FAIL.

- **FAIL** → record the reason under `Tried + failed` in `.claude/LOOP_STATE.md`. Either send
  one corrective pass back to the implementer (max 2 retries), or, if stuck, leave it for the
  human in the triage notes and move on. Never land red code.
- **PASS** → continue.

### 6. Land + remember (connectors + state)

On PASS only:

```bash
just fmt
git add -A && git commit -m "<type>: <imperative summary> (closes #<N>)"
git push -u origin loop/<item>
gh pr create --repo HexSleeves/odin-into-the-dark --fill --base main
```

Then close out via the existing flow — run `/issue-done <N>` (moves the board card to Done,
updates `NEXT_STEPS.md`). Finally update `.claude/LOOP_STATE.md`: move the item from
`In progress` to `Done this cycle`, and remove the worktree:

```bash
git worktree remove ../itd-loop-<item>
```

Stop. One tick = one item landed (or one honest FAIL recorded). The next tick picks up from
the updated memory.

## Hard rules (the part the blog warns about)

- **Verification is non-negotiable.** A PASS means the verifier ran `just verify` green and
  read the diff. Unattended ≠ unchecked.
- **Never land on a red gate.** A red `just verify` is always the next item, never deferred.
- **One item per tick**, isolated. No parallel edits to the same worktree.
- **You stay the engineer.** Skim every PR the loop opens before merge — comprehension debt
  compounds faster than the loop ships.

## Scheduling this tick (pick one)

```bash
# In-session, this machine, every 30 min — re-runs the tick on a cadence:
/loop 30m /loop-tick

# Run-until-condition instead of fixed cadence (separate model grades the stop):
/goal "just verify is green and the top Open item in .claude/LOOP_STATE.md is empty"
```

For survival past a closed laptop, promote the same `just verify` + triage gate into a
scheduled GitHub Action on `HexSleeves/odin-into-the-dark` (roadmap item #1 in `NEXT_STEPS.md`
already calls for the CI pipeline — the loop's natural home).

## Pieces this loop is built from

| Blog primitive | Here |
| --- | --- |
| Automations / heartbeat | this command + `/loop` / `/goal` / GitHub Action |
| Worktrees | `git worktree` + `isolation: worktree` on the implementer |
| Skills | `loop-triage`, plus existing `create-work-item` / `execute-work-item` / `qa-pass` |
| Connectors | `gh` CLI + GitHub Project board (`forge_extension` MCP in `.mcp.json`) |
| Sub-agents | `loop-implementer` (maker) + `loop-verifier` (checker) |
| Memory | `.claude/LOOP_STATE.md` + the GitHub board + `NEXT_STEPS.md` |
