# Plan 003: Enemy occupancy grid (P9) + Dijkstra flow-field cache (P7), profile-gated

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat bf2a4bd..HEAD -- src/core/game_utils.odin src/core/types.odin src/ai/enemy_pathfinding.odin src/ai/enemy_turns.odin src/engine/distance_map.odin`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.
>
> **Measure first**: this plan is performance work. Step 0 establishes a
> baseline with the existing `perf` log channel. If the baseline shows these
> paths are not hot at realistic entity counts, STOP and report — the audit
> explicitly says "profile before optimizing".

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (independent of save plans; can run in parallel with 002/004)
- **Category**: perf
- **Planned at**: commit `bf2a4bd`, 2026-06-13

## Why this matters

Two structural costs in the enemy turn loop. (P9) `enemy_at`
(`src/core/game_utils.odin:170-177`) is a linear scan of `game.enemies`; it is
called per cell by occupancy checks and pathfinding, giving O(cells × enemies)
or O(N²) behavior. (P7) `compute_dijkstra_map` (`src/ai/enemy_pathfinding.odin:6`)
runs a full BFS over the whole 80×50 grid, and `process_enemy_turns`
(`src/ai/enemy_turns.odin:8-12`) recomputes it **every enemy round** — a slow
player (multiple enemy rounds per input) pays the BFS cost N times for a flow
field that only changes when the player moves or terrain changes. Both are
bounded today (N≤~30) but are the first things to bite as content grows. This
plan adds an O(1) occupancy grid and a per-input flow-field cache, **gated on a
profiling baseline** so the work is justified by measurement, not vibes.

## Current state

**`enemy_at` — linear scan** (`src/core/game_utils.odin:170-177`):

```odin
enemy_at :: proc(game: ^Game, x, y: int) -> ^Enemy {
 for &enemy in game.enemies {
  if enemy.alive && enemy.pos.x == x && enemy.pos.y == y {
   return &enemy
  }
 }
 return nil
}
```

Re-exported as `gcore.enemy_at` in several packages (`src/input/common.odin:64`,
`src/gen/common.odin:29`, `src/gameplay/common.odin:94`). NOTE: `src/ai/common.odin:75`
defines its **own** `enemy_at` body — check whether it is identical and whether
it should also use the occupancy grid (it is on the hottest path).

**Dijkstra BFS** (`src/ai/enemy_pathfinding.odin:6-42`) — seeds at the player,
floods walkable cells via a ring-buffer queue. Recomputed unconditionally:
`src/ai/enemy_turns.odin:8-12`:

```odin
process_enemy_turns :: proc(messages: ^Message_Manager, game: ^Game) {
 ...
 compute_dijkstra_map(game)
```

**Call sites that drive enemy rounds** — `trigger_enemy_rounds`
(`src/gameplay/...`, re-exported at `src/input/common.odin:138`) is called from
`src/input/state_updates.odin:41,44,46` and `src/input/playing_state.odin:18,43,80`.
A single player input can trigger multiple enemy rounds (slow player), each
currently recomputing the BFS.

**Unchecked distance-map accessors already exist** but are file-private
(`src/engine/distance_map.odin:49-63`):

```odin
@(private = "file")
_distance_map_get_unchecked :: proc(dmap: ^Engine_Distance_Map, x, y: int) -> int { ... }
@(private = "file")
_distance_map_set_unchecked :: proc(dmap: ^Engine_Distance_Map, x, y, distance: int) { ... }
```

**`Game` struct** (`src/core/types.odin:261-`): has
`dijkstra_map: [MAP_WIDTH*MAP_HEIGHT]int` (line 263),
`enemies: [dynamic]Enemy` (line 269), `world: eng.World_Manager` (264). There is
**no** `dijkstra_dirty` and **no** `enemy_occupancy` field yet (`grep` confirms).

**`perf` channel** (`src/io/perf_timer.odin`): `perf_begin(label) -> Perf_Timer`
- `defer perf_end(t)`; zero-cost when the `perf` log channel is off. Already used
at `src/io/save_write.odin:26-27`. Enable the channel via the logger config
(`.env` / `ITD_*` log settings — see `game_diagnostics_init` in
`src/game_app_config.odin:44-47` and `logger_init_from_config`).

**Conventions:** engine layer (`src/engine/`) stays raylib-free and is the place
for the unchecked accessors. The occupancy grid lives on `Game` (game state),
not the engine. Match the existing `[MAP_WIDTH*MAP_HEIGHT]` flat-index grid
pattern (`dijkstra_map`, `tiles`, `ore_veins`). Index helper: grids use
`engine_grid_2d_index` / a `y*width+x` flat index — match `compute_dijkstra_map`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Type-check | `just check` | exit 0 |
| Full gate | `just verify` | `✓ tests + flag matrix + check + build passed` |
| AI tests | `python3 scripts/run_odin_tests.py -define:CHEATS=true` (read `ai` pkg) | pass |
| One test | `python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=main.dijkstra_map_is_only_recomputed_when_marked_dirty` | pass |
| Profile build | `just profile` then run with the `perf` channel on | per-system ms in the log |
| Format | `just fmt` | exit 0 |

## Scope

**In scope:**

- `src/engine/distance_map.odin` — make the two `_unchecked` accessors public
  (rename without the leading `_` / drop `@(private="file")`), documented as
  "caller must validate once".
- `src/core/types.odin` — add `dijkstra_dirty: bool` and
  `enemy_occupancy: [MAP_WIDTH*MAP_HEIGHT]i32` (store enemy index+1, 0 = empty)
  to `Game`.
- `src/core/game_utils.odin` — add `rebuild_enemy_occupancy(game)` and rewrite
  `enemy_at` to read the occupancy grid with a fallback; mark dijkstra dirty on
  enemy add/remove if there is a central place (otherwise rebuild occupancy at
  round start).
- `src/ai/enemy_pathfinding.odin` — validate the distance map once at the top of
  `compute_dijkstra_map`, switch the inner BFS to the unchecked accessors, clear
  `dijkstra_dirty` at the end.
- `src/ai/enemy_turns.odin` — recompute the BFS only when `dijkstra_dirty`.
- `src/ai/common.odin` — reconcile its local `enemy_at` (alias to `gcore` or
  keep but route through occupancy).
- The `trigger_enemy_rounds` definition (find it: `grep -rn "trigger_enemy_rounds ::" src/`)
  — mark `dijkstra_dirty = true` once per player input, and rebuild occupancy
  once per input.
- Tests under `test/` mirroring the changed packages.

**Out of scope (do NOT touch):**

- FOV/render per-cell validity hoist (audit P6 for those loops) — higher risk,
  marginal gain; separate plan.
- The save format — `dijkstra_dirty`/`enemy_occupancy` are transient; they must
  **not** be serialized. Confirm they are not added to any `Save_Data`/`Save_Floor`.
- `enemy_at` semantics: it must still return the **first alive** enemy at a cell
  and `nil` if none — do not change the contract.

## Git workflow

- Branch: `advisor/003-occupancy-flowfield`.
- Conventional Commits; suggested: `perf(ai): O(1) enemy occupancy + per-input dijkstra cache`.
- Commit P9 (occupancy) and P7 (cache) as two logical commits if convenient.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 0: Establish a baseline (gate)

Build `just profile`, enable the `perf` channel, play (or run a deterministic
seed: `FIXED_SEED=12345 just run-built` with the channel on) until several enemy
rounds occur. Record the per-round `enemy`/`save`/`fov` timings the channel logs
and the typical enemy count.

**Verify / gate**: if `compute_dijkstra_map` + enemy-turn time is negligible at
realistic counts (e.g. < ~0.5 ms/round at N≈30), **STOP and report** — the
optimization is not justified yet; note the baseline in `plans/README.md` and
mark this plan REJECTED-for-now with the numbers. Otherwise continue and keep the
baseline to compare against at the end.

### Step 1: Expose the unchecked distance-map accessors

In `src/engine/distance_map.odin`, make `_distance_map_get_unchecked` /
`_distance_map_set_unchecked` public (e.g. `engine_distance_map_get_unchecked` /
`_set_unchecked`), keep the doc comment that the caller must validate once and
bounds-check independently.

**Verify**: `just check` → exit 0; `grep -n "unchecked" src/engine/distance_map.odin`
shows them no longer `@(private="file")`.

### Step 2: Hoist validation + use unchecked accessors in the BFS

In `compute_dijkstra_map` (`src/ai/enemy_pathfinding.odin`), after building
`dmap`, validate once with `eng.engine_distance_map_is_valid(&dmap)` and early-
return if invalid. The BFS already bounds-checks neighbors
(`nx<0 || nx>=MAP_WIDTH ...`), so switch the per-cell `engine_distance_map_get/set`
to the unchecked variants. At the end, set `game.dijkstra_dirty = false`.

**Verify**: `just check` → exit 0. Existing AI/pathfinding tests still pass.

### Step 3: Add `dijkstra_dirty` + gate recompute

Add `dijkstra_dirty: bool` to `Game` (`src/core/types.odin`). In
`process_enemy_turns` (`src/ai/enemy_turns.odin`), call `compute_dijkstra_map`
only `if game.dijkstra_dirty`. In `trigger_enemy_rounds`, set
`game.dijkstra_dirty = true` once before the rounds loop.

**CRITICAL**: every test that calls `process_enemy_turns` directly (search:
`grep -rn "process_enemy_turns" test/`) now reads a stale/unreachable map unless
it sets `game.dijkstra_dirty = true` first. Update those tests to set the flag
(or call `compute_dijkstra_map` explicitly). Spot-check a movement test like
`visible_enemy_moves_downhill_toward_player`.

**Verify**: `just check` → exit 0; the AI test package passes after updating
direct callers.

### Step 4: Add the enemy occupancy grid (P9)

Add `enemy_occupancy: [MAP_WIDTH*MAP_HEIGHT]i32` to `Game`. Add
`rebuild_enemy_occupancy :: proc(game: ^Game)` in `src/core/game_utils.odin`:
zero the grid, then for each `enemy in game.enemies` that is `alive` and on-grid,
store `index+1` at `y*MAP_WIDTH + x` (skip if a cell is already occupied, to
preserve first-match). Rewrite `enemy_at` to read the grid:

```odin
enemy_at :: proc(game: ^Game, x, y: int) -> ^Enemy {
 if game == nil || x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT { return nil }
 slot := game.enemy_occupancy[y * MAP_WIDTH + x]
 if slot == 0 { return nil }
 e := &game.enemies[slot - 1]
 return e if e.alive else nil
}
```

Call `rebuild_enemy_occupancy(game)` once per input in `trigger_enemy_rounds`
(alongside marking dirty), and after any bulk enemy spawn/death pass. Reconcile
`src/ai/common.odin:75`'s local `enemy_at`.

**Verify**: `just check` → exit 0. Equivalence test (below) passes.

### Step 5: Format + full gate + compare to baseline

`just fmt`; `just verify`; re-run the Step 0 profile and confirm enemy-round time
dropped (record before/after in the PR description / `plans/README.md`).

**Verify**: `✓ tests + flag matrix + check + build passed`, and measured
improvement over the Step 0 baseline.

## Test plan

New tests (mirror `test/ai/` and `test/engine/` structure):

- `engine_distance_map_unchecked_accessors_read_and_write_without_validation` —
  set then get a cell via the public unchecked accessors.
- `dijkstra_map_is_only_recomputed_when_marked_dirty` — compute once, move the
  player without setting dirty, assert the map is unchanged; set dirty, assert it
  recomputes.
- `trigger_enemy_rounds_recomputes_flow_field_once_then_reuses_it_across_slow_player_rounds`
  — drive multiple enemy rounds from one input; assert the BFS ran once.
- `enemy_at_via_occupancy_grid_matches_linear_scan_for_every_cell` — build a game
  with several enemies, `rebuild_enemy_occupancy`, assert `enemy_at(x,y)` equals a
  reference linear scan for all cells.
- `enemy_at_returns_nil_for_dead_or_off_grid` — dead enemy's cell returns nil;
  off-grid coords return nil (no OOB under `-no-bounds-check`).
- `rebuild_enemy_occupancy_records_first_enemy_when_two_share_a_tile`.

Use `game_init_world(&g)` to get valid grids (zero-init `Game` has invalid grids
— see `CLAUDE.md` Testing patterns). Verification: `just verify` → all pass.

## Done criteria

ALL must hold:

- [ ] `just verify` → `✓ tests + flag matrix + check + build passed`
- [ ] `compute_dijkstra_map` runs once per player input, not once per enemy round
      (proven by the dirty-flag test)
- [ ] `enemy_at` reads `enemy_occupancy`; equivalence test vs linear scan passes
- [ ] `enemy_occupancy` / `dijkstra_dirty` are NOT in any `Save_Data`/`Save_Floor`
      (`grep -n "enemy_occupancy\|dijkstra_dirty" src/io/save_format.odin` → none)
- [ ] Step 5 profile shows enemy-round time below the Step 0 baseline
- [ ] `git status` shows only in-scope files
- [ ] `plans/README.md` status row updated with before/after numbers

## STOP conditions

Stop and report back if:

- The Step 0 baseline shows these paths are not hot (gate fails) — report numbers,
  do not optimize.
- Drift check shows the cited files changed and excerpts no longer match.
- Updating direct `process_enemy_turns` test callers breaks movement assertions
  in a way that suggests the cache is returning a stale/unreachable map — the
  dirty-flag wiring is wrong; fix before proceeding.
- Terrain mutates mid enemy-round (mining/abilities carving walls during a round)
  and the cached flow field would be stale — if such a path exists, report it;
  it must also mark `dijkstra_dirty`.
- You find an enemy add/remove path that does not rebuild occupancy, leaving
  `enemy_at` stale — list them rather than scattering rebuild calls blindly.

## Maintenance notes

- The flow-field cache assumes the player position and walkable terrain are the
  only BFS inputs. Any future feature that changes walkability mid-round (new
  destructible terrain, teleporting player) must set `dijkstra_dirty = true`.
- The occupancy grid assumes enemies do not move between a `rebuild` and the
  `enemy_at` reads within the same round-processing pass; if enemy movement
  starts interleaving with occupancy reads, rebuild after each move or update the
  grid incrementally on move.
- Deferred: FOV/render per-cell validity hoist (audit P6 for those loops) and AoS
  → occupancy-aware flow field for pack behavior (audit P9 long-term).
- `i32` occupancy (index+1) caps at enemy count; current `MAX_SAVE_ENEMIES`=64 is
  well within range. Fine.
