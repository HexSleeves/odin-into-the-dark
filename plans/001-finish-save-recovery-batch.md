# Plan 001: Finish and clean the atomic-save `.bak` recovery batch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat bf2a4bd..HEAD -- src/io/save_restore.odin test/io/dbg_test.odin test/io/save_atomic_write_test.odin`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `bf2a4bd`, 2026-06-13

## Why this matters

The atomic-save layer (write `.tmp` → roll prior save to `.bak` → atomic
`rename`, plus a v10 CRC32 header) is already in the working tree, and the
load side now recovers from `.bak` when the primary save is corrupt — the
single biggest data-loss liability the audit found (a mid-write crash on a
permadeath save). The production logic is sound and the new
`save_atomic_write_test.odin` covers it well. But the batch is **uncommitted,
unverified, and carries two debug artifacts that must not ship**: a public
debug wrapper leaked into production source and a `printf`-only scratch test.
This plan removes the cruft, runs the full gate, and leaves the tree
commit-ready so good work doesn't rot or ship with debug scaffolding.

## Current state

Working tree (`git status`) is dirty with this in-flight batch:

```
 M src/io/save_restore.odin
 M test/engine/storage_manager_test.odin
?? test/io/dbg_test.odin
?? test/io/save_atomic_write_test.odin
```

**Cruft 1 — debug wrapper in production source.** `src/io/save_restore.odin`
top of file:

```odin
10 // read_and_decode_save reads one candidate path, validates its header, and
11 // migrates/deserializes the payload into a freshly allocated Save_Data.
12 // Returns nil on any failure so the caller can fall back to the next candidate.
13 read_and_decode_save_dbg :: proc(storage: ^eng.Storage_Manager, path: string) -> ^Save_Data { return read_and_decode_save(storage, path) }
14
15 @(private = "file")
16 read_and_decode_save :: proc(storage: ^eng.Storage_Manager, path: string) -> ^Save_Data {
```

`read_and_decode_save_dbg` exists only to expose the `@(private="file")`
`read_and_decode_save` to a test. It is **dead** — nothing references it
(`grep -rn read_and_decode_save_dbg src/ test/` returns nothing). The
doc-comment on lines 10–12 actually describes `read_and_decode_save`, the real
proc on line 16; it is just visually sitting above the wrapper.

**Cruft 2 — `printf` scratch test.** `test/io/dbg_test.odin` is a single
`@(test) dbg_crc` proc that uses `fmt.printf` to dump CRC values and makes **no
assertions**. It is print-debugging scaffolding, not a regression test, and it
does not even use `read_and_decode_save_dbg` (it inlines its own CRC check). It
should be deleted wholesale.

**Keep as-is (already correct, do not edit):**

- `src/io/save_restore.odin` `load_game_from_storage` — now reads the primary,
  falls back to `<path>.bak` on failure, and removes `<path>`, `<path>.bak`,
  `<path>.tmp` after a successful one-load consume. This is the intended
  recovery behavior.
- `test/io/save_atomic_write_test.odin` — a proper assertion-based suite with an
  in-memory FS fake (`Mem_File_System`) covering: temp→rename keeping one
  backup, WASM-style direct-write fallback when `rename` is unavailable, and
  recovery from a corrupt primary via `.bak`. This is the keeper test file.
- `test/engine/storage_manager_test.odin` — adds `rename` delegation tests for
  the `Storage_Manager`. Correct; keep.

**Repo conventions that apply here:**

- Tests live under `test/` (mirroring `src/`), in `package main` for game tests
  or the matching package for sub-package tests; the Python runner overlays them
  into the src tree before compiling. `save_atomic_write_test.odin` and
  `dbg_test.odin` are `package gameio` with `#+build !js`.
- "Delete old paths by default" (project rule in `AGENTS.md`): debug-only
  exports do not earn a place in production source.
- `just fmt` must run before committing; `just verify` is the completion gate
  (`CLAUDE.md` → Rules).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Type-check | `just check` | exit 0, no errors |
| Full gate | `just verify` | prints `✓ tests + flag matrix + check + build passed` |
| Single test pkg | `python3 scripts/run_odin_tests.py -define:CHEATS=true` | `All tests were successful` (or per-package OK) |
| Format | `just fmt` | exit 0 |
| Confirm dead symbol | `grep -rn "read_and_decode_save_dbg" src/ test/` | no matches |

## Scope

**In scope** (the only files you should modify):

- `src/io/save_restore.odin` — delete the `read_and_decode_save_dbg` wrapper only.
- `test/io/dbg_test.odin` — delete the file.

**Out of scope** (do NOT touch, even though they look related):

- `src/io/save_write.odin`, `src/io/file_system_desktop.odin`,
  `src/engine/file_system.odin`, `src/engine/storage_manager.odin` — the
  production atomic-write changes are already in tree and correct. Do not
  re-apply or "improve" them.
- `test/io/save_atomic_write_test.odin` and
  `test/engine/storage_manager_test.odin` — already-correct tests; leave them.
- The recovery loop / artifact-removal logic in `load_game_from_storage` — keep.
- The save format, CRC, or migration logic — that is Plan 002, not this one.

## Git workflow

- Work on the current branch (`main`) unless the operator says otherwise; this
  is a cleanup of already-staged work, not a feature.
- Conventional Commits style (see `git log`: `feat(enemies): ...`,
  `refactor: ...`). Suggested message:
  `feat(io): atomic save writes with .bak recovery + tests`.
- Do NOT push or open a PR. After the tree is verified and formatted, **stop and
  report that it is commit-ready** — only commit if the operator authorized it
  in this run.

## Steps

### Step 1: Remove the dead debug wrapper from production source

In `src/io/save_restore.odin`, delete the single line defining
`read_and_decode_save_dbg` (line 13 in the excerpt above) and the blank line
that follows it, so the doc-comment on lines 10–12 sits directly above
`@(private = "file")` / `read_and_decode_save`. Do not change
`read_and_decode_save` itself or any other proc.

**Verify**: `grep -rn "read_and_decode_save_dbg" src/ test/` → no matches.
Then `just check` → exit 0.

### Step 2: Delete the scratch debug test

Delete the file `test/io/dbg_test.odin` entirely (`git rm test/io/dbg_test.odin`
if it were tracked; it is untracked, so `rm test/io/dbg_test.odin`).

**Verify**: `test -e test/io/dbg_test.odin && echo EXISTS || echo GONE` → `GONE`.

### Step 3: Format

Run `just fmt`.

**Verify**: `just fmt` → exit 0; `git diff --stat` shows only the in-scope files
(plus any formatter-driven whitespace in the already-staged files, which is
acceptable).

### Step 4: Run the full gate

Run `just verify`.

**Verify**: ends with `✓ tests + flag matrix + check + build passed`. The three
keeper tests in `save_atomic_write_test.odin`
(`save_game_writes_to_temp_then_renames_over_target_keeping_one_backup`,
`save_game_falls_back_to_direct_write_when_rename_is_unavailable`,
`load_game_recovers_from_backup_when_primary_save_is_corrupt`) and the two
`storage_manager_rename_*` tests must all pass.

### Step 5: Report commit-ready

Summarize: files changed, `just verify` result, and the proposed commit message.
Do not commit unless the operator authorized committing in this run.

## Test plan

- No new tests needed — `save_atomic_write_test.odin` already provides the
  regression coverage (atomic write, WASM fallback, `.bak` recovery) and
  `storage_manager_test.odin` covers `rename` delegation.
- Removing `dbg_test.odin` removes a non-assertion test; this is intended.
- Verification: `just verify` → all pass; the save-atomic and rename tests are
  the proof the batch is complete.

## Done criteria

ALL must hold:

- [ ] `grep -rn "read_and_decode_save_dbg" src/ test/` returns no matches
- [ ] `test/io/dbg_test.odin` does not exist
- [ ] `test/io/save_atomic_write_test.odin` still exists and its 3 tests pass
- [ ] `just verify` prints `✓ tests + flag matrix + check + build passed`
- [ ] `git status` shows only `src/io/save_restore.odin`,
      `test/engine/storage_manager_test.odin`, and
      `test/io/save_atomic_write_test.odin` as the change set (dbg_test gone)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows `save_restore.odin` changed since `bf2a4bd` and the
  `read_and_decode_save_dbg` excerpt no longer matches.
- `grep` finds `read_and_decode_save_dbg` referenced by any non-test production
  file — that would mean it is not dead; do not delete it blindly.
- `just verify` fails after removing the wrapper/test, and the failure is in the
  save/storage tests (it should not be — the wrapper is unused).
- You find yourself wanting to change `save_write.odin` or the format/CRC code
  to make a test pass — that is out of scope; stop.

## Maintenance notes

- After this lands, Plan 002 (save-format diet, v11) will rewrite much of the
  save layer. 001 must be committed first so 002 starts from a clean,
  recovery-capable baseline and its drift check is meaningful.
- A reviewer should confirm: (1) no debug symbol remains in `src/io/`, (2) the
  `.bak` recovery path is exercised by
  `load_game_recovers_from_backup_when_primary_save_is_corrupt`, (3) artifacts
  (`.dat`/`.bak`/`.tmp`) are all removed after a normal load.
- Deferred out of this plan: directory `fsync` for power-loss durability, and a
  full package-`main` `Game` save→load round-trip test (belongs with 002).
