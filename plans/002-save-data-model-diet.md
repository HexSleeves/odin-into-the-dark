# Plan 002: Shrink the save/data model — drop dead `Tile` fields, carry tile-state directly

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat bf2a4bd..HEAD -- src/core/types.odin src/io/save_format.odin src/io/save_migrations.odin src/io/save_convert.odin src/io/save_restore.odin src/io/save_write.odin src/core/game_utils.odin`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.
>
> **DECISION REQUIRED before Step 1** — see "Decision gate" below. Do not start
> until the operator has chosen the legacy-save policy.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/001-finish-save-recovery-batch.md (must be committed first)
- **Category**: tech-debt / migration
- **Planned at**: commit `bf2a4bd`, 2026-06-13

## Why this matters

The `Game` struct is ~253 KB (measured, not the docs' old "112 KB" claim) and a
large fraction is duplicated tile state. `Tile` carries `visible`, `explored`,
and `light_level` (`src/core/types.odin:44-49`), but those are *also* owned by
the engine's `Tile_State_Manager` — `Tile`'s copies exist only as a save
serialization carrier. Every `Game` and every `Saved_Floor` (one per visited
depth, up to `MAX_DEPTH+1`) pays for this twice. Dropping the three dead `Tile`
fields and serializing the engine tile-state layer directly shrinks `Tile` from
~16 to ~8 bytes and `Game` by ~32 KB, and removes a whole class of
"two sources of truth for tile visibility" bugs. This is the cheapest structural
win in the audit's medium-term tier — but it is a **save-format change on a
permadeath save**, so it is HIGH risk and must land behind the round-trip tests
that already exist (`test/io/save_roundtrip_test.odin`) plus the new ones here.

## Decision gate (operator must choose before Step 1)

This bumps the on-disk save version from v10 to **v11**. Two policies:

- **A — Drop legacy read support (RECOMMENDED).** Per the project rule
  "delete old paths by default unless there is an explicit compat contract"
  (`AGENTS.md`), and because the game has no released version with a save-compat
  contract ("shipped" = a release Git tag), drop the v2–v10 read/migration code.
  v11 becomes the only readable format. This collapses the effort from L→M and
  deletes the `Save_Data_V2..V8` freezes and their migration branches. **Old
  local saves become unreadable** (acceptable for a permadeath dev build; a stale
  save is consumed-on-load anyway).
- **B — Keep v10 readable.** Add a frozen `Save_Data_V10` + `Tile_V10` snapshot
  and a v10→v11 migration that lifts inline `Tile.visible/explored/light_level`
  into the new tile-state array. Keeps the L effort and the full migration chain.

This plan is written for **Policy A** as the default path, with the Policy-B
additions called out inline as "(Policy B only)". **If the operator chose B, do
the marked extra steps; if A, skip them and delete the legacy freezes.** If no
decision was provided, STOP and ask.

## Current state

**Dead fields on `Tile`** — `src/core/types.odin:44-49`:

```odin
Tile :: struct {
	type:        Tile_Type,
	visible:     bool,
	explored:    bool,
	light_level: f32,
}
```

The live source of visibility/light is the engine `Tile_State_Manager`
(`src/engine/tile_state_manager.odin`), held on `Game` at
`src/core/types.odin:287` (`tile_states: eng.Tile_State_Manager`) and rebuilt by
`game_init_world` (`src/core/game_utils.odin:161-168`). `Tile`'s three fields are
written/read only by the save bridge.

**Save carriers that embed `Tile`** (`src/io/save_format.odin`):

- `Save_Floor.tiles: [MAP_WIDTH*MAP_HEIGHT]Tile` (line 86)
- `Save_Data.tiles: [MAP_WIDTH*MAP_HEIGHT]Tile` (line 126)
- and the frozen legacy structs `Save_Data_V8/V7/V6/V4/V3/V2` (lines 178-371),
  each with their own `tiles: [...]Tile`.
- `Saved_Floor.tiles: [MAP_WIDTH*MAP_HEIGHT]Tile` (`src/core/types.odin:231`).

**Current save version constants** (`src/io/save_format.odin:9-17`):

```odin
SAVE_VERSION :: u32(10)
SAVE_VERSION_V9 :: u32(9)
... (down to V2)
SAVE_MAGIC :: u32(0x44455054) // "DEPT"
```

**Header** (`src/io/save_format.odin:107-118`): `Save_Header_Legacy` is 8 bytes
(magic+version, v2–v9), `Save_Header` is 12 bytes (adds `crc32`, v10+). Do not
change the header layout in this plan — v11 keeps the 12-byte `Save_Header`.

**Migration entry** (`src/io/save_migrations.odin`): `clamp_save_counts` (clamps
file-controlled counts to capacities — keep, it is the C2 fix) and
`migrate_legacy_status_fields`. `load_save_data` (in `save_migrations.odin`,
called from `read_and_decode_save` in `save_restore.odin`) selects the migration
branch by `header.version`.

**The engine tile-state layer to serialize.** `Tile_State_Manager` exposes
per-cell accessors (see `src/engine/tile_state_manager.odin` —
`tile_state_at`, `tile_state_visible/explored/light_level`, and the matching
setters). You will add export/import procs that copy between a flat
`[N]eng.Tile_State` array and the manager.

**Repo conventions:**

- `core` is imported as `gcore`; engine as `eng`. `package gameio` re-aliases
  what it needs in `src/io/common.odin` (check it before referencing a bare
  name). `package gameplay` aliases in `src/gameplay/common.odin`.
- Save-safe types must contain **no heap pointers/strings** — that is why
  `Save_String` (fixed buffer) exists. `eng.Tile_State` is a value type (verify
  with `grep -n "Tile_State ::" src/engine/tile_state_manager.odin`); a flat
  array of it is save-safe.
- Migration tests model: `test/io/save_roundtrip_test.odin` (existing). Match its
  structure (build a struct literal, serialize with the legacy/current writer,
  call `load_save_data`, assert fields).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Type-check | `just check` | exit 0 |
| Full gate | `just verify` | `✓ tests + flag matrix + check + build passed` |
| Save tests only | `python3 scripts/run_odin_tests.py -define:CHEATS=true` then read the `io` package result | save tests pass |
| One test | `python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=main.v11_save_data_round_trips_through_load_save_data` | pass |
| Format | `just fmt` | exit 0 |
| Confirm fields gone | `grep -n "visible\|explored\|light_level" src/core/types.odin` | no matches inside `Tile ::` |
| Struct size probe | add a `size_of(Tile)` / `size_of(Game)` assertion in a test (see Test plan) | asserts hold |

## Suggested executor toolkit

- Run `graphify query "how is Tile_State_Manager serialized into the save"` and
  `graphify explain "save data migration"` before starting — cheaper than
  grepping the whole `io` package.

## Scope

**In scope:**

- `src/core/types.odin` — shrink `Tile` (drop 3 fields); add a tile-state array
  field to `Saved_Floor`.
- `src/io/save_format.odin` — add `SAVE_VERSION :: u32(11)`; add a flat
  `tile_states` array field to `Save_Data` and `Save_Floor`; (Policy B) add
  frozen `Save_Data_V10`/`Tile_V10`; (Policy A) delete `Save_Data_V2..V8`.
- `src/core/game_utils.odin` — add `tile_state_manager` export/import helpers (or
  put them next to the manager if the executor prefers; keep them in `gcore`).
- `src/io/save_write.odin` — populate the new `tile_states` array on write.
- `src/io/save_restore.odin` — restore from the new `tile_states` array on read.
- `src/io/save_convert.odin` — floor snapshot ↔ `Save_Floor` copies for the new
  field.
- `src/io/save_migrations.odin` — set v11 as current; (Policy B) add v10→v11 lift;
  (Policy A) delete dead legacy branches.
- `src/gameplay/generation.odin` — if it reads/writes `Tile.visible/explored/
  light_level` on snapshot save/restore, route through the new export/import.
- `src/gameplay/common.odin`, `src/io/common.odin` — alias updates only if a new
  `gcore` symbol needs re-exporting.
- `test/io/save_roundtrip_test.odin` (and/or a new `test/io/save_tilestate_test.odin`).

**Out of scope (do NOT touch):**

- The `Save_Header` / `Save_Header_Legacy` layout and the CRC32 logic — v11
  reuses the 12-byte header unchanged.
- `clamp_save_counts` — it is the C2 OOB fix; keep it and extend it for any new
  counts only if you add a count (you do not).
- `Ore_Vein.ore_type: string → enum` — the audit groups this with the diet, but
  it is a **separate, independent change** with its own risk; do NOT bundle it
  here. Leave `ore_type: string` (`src/core/types.odin:179`) alone. (Tracked as a
  follow-up in `plans/README.md`.)
- Present-floors-only save (length-prefixed `visited_floors`) — separate
  follow-up; keep the fixed `[MAX_DEPTH+1]` array.
- The atomic-write / `.bak` recovery code (Plan 001).

## Git workflow

- Branch: `advisor/002-save-data-model-diet` (save-format changes deserve
  isolation from `main`).
- Conventional Commits; suggested final message:
  `refactor(io): serialize engine tile-state directly; drop dead Tile fields (save v11)`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

> Order matters: add the new carrier path first, make write+read use it, verify
> a v11 round-trip, *then* delete the dead `Tile` fields. Never leave the tree
> in a state where save and load disagree on layout.

### Step 1: Add the tile-state export/import helpers in `gcore`

In `src/core/game_utils.odin`, add two procs (names match the engine accessor
style):

- `tile_state_manager_export :: proc(tsm: ^eng.Tile_State_Manager, out: []eng.Tile_State)`
  — copy every cell's `Tile_State` into `out` (length `MAP_WIDTH*MAP_HEIGHT`);
  nil/short-slice guard.
- `tile_state_manager_import :: proc(tsm: ^eng.Tile_State_Manager, src: []eng.Tile_State)`
  — copy `src` back into the manager; nil/short-slice guard.

Use the existing per-cell accessors; do not reach into manager internals if a
public accessor exists. If the manager already exposes a bulk
`tile_state_manager_cells`/slice accessor, prefer it.

**Verify**: `just check` → exit 0.

### Step 2: Add the `tile_states` array to the save carriers

In `src/io/save_format.odin`, add as the **last** field of both `Save_Data` and
`Save_Floor`:

```odin
tile_states: [MAP_WIDTH * MAP_HEIGHT]eng.Tile_State,
```

In `src/core/types.odin`, add the same field as the last field of `Saved_Floor`.
Bump `SAVE_VERSION :: u32(11)` in `save_format.odin:9`. Do not delete the `tiles`
arrays yet.

**Verify**: `just check` → exit 0.

### Step 3: Populate `tile_states` on write; restore from it on read

- `src/io/save_write.odin` — where it fills `Save_Data.tiles` from the live game,
  also call `tile_state_manager_export(&game.tile_states, data.tile_states[:])`.
  For each visited floor written into `Save_Floor`, export that floor's snapshot
  tile-state (see `save_convert.odin` for the snapshot→`Save_Floor` copy).
- `src/io/save_restore.odin` — after restoring fixed fields, call
  `tile_state_manager_import(&game.tile_states, data.tile_states[:])` instead of
  copying `Tile.visible/explored/light_level` into the manager.
- `src/io/save_convert.odin` — copy the new `tile_states` field in both
  `Saved_Floor`↔`Save_Floor` directions.

At this point both old (`Tile` fields) and new (`tile_states`) paths are written;
that is fine and intentional for the next verify.

**Verify**: `just check` → exit 0. Then write the v11 round-trip test (Step 5)
and run it before deleting anything.

### Step 4: Set the migration policy

- **Policy A**: In `save_migrations.odin`, make `load_save_data` accept only
  `header.version == SAVE_VERSION` (11). Delete the v2–v10 branches and the
  frozen `Save_Data_V2..V8` structs in `save_format.odin`. Delete the now-unused
  `SAVE_VERSION_V2..V9` constants. Keep `clamp_save_counts` and
  `migrate_legacy_status_fields` only if still referenced; delete if not.
- **Policy B only**: Add `Save_Data_V10` (current `Save_Data` *without*
  `tile_states`, *with* the old per-`Tile` fields) and `Tile_V10` (the old
  4-field `Tile`). Add a v10→v11 branch that `mem.copy`s the common prefix, then
  lifts each `Tile_V10.visible/explored/light_level` into the new
  `tile_states` array. Keep the v9-and-below chain only if the operator wants it
  (default under B: keep v10 only, drop ≤v9).

**Verify**: `just check` → exit 0; `grep -n "Save_Data_V" src/io/save_format.odin`
shows only what the chosen policy keeps.

### Step 5: Drop the dead `Tile` fields

Now that read/write use `tile_states`, remove `visible`, `explored`,
`light_level` from `Tile` in `src/core/types.odin:44-49`, leaving:

```odin
Tile :: struct {
	type: Tile_Type,
}
```

Fix every resulting compile error by routing through the `Tile_State_Manager`
(the live source) — `grep -rn "\.visible\|\.explored\|\.light_level" src/` and
replace each `tile.visible`-style access with the manager accessor. Most should
already use the manager; the remaining ones are the bridge code you just
rewrote.

**Verify**: `grep -n "visible\|explored\|light_level" src/core/types.odin` shows
none inside `Tile ::`. `just check` → exit 0.

### Step 6: Format and full gate

`just fmt` then `just verify`.

**Verify**: `✓ tests + flag matrix + check + build passed`.

## Test plan

Add to `test/io/save_roundtrip_test.odin` (or a new
`test/io/save_tilestate_test.odin`, `package gameio`, `#+build !js`):

- `v11_save_data_round_trips_through_load_save_data` — build a `Game` with
  distinct visibility/light per a few cells, save, load, assert the
  `Tile_State_Manager` visibility/light is restored exactly.
- `save_load_preserves_engine_tile_state_layer` — full save→load asserting
  visible/explored/light for a handful of cells survive a round trip.
- `tile_struct_shrank_after_dropping_visibility_fields` — `#assert` /
  `testing.expect_value(t, size_of(Tile), size_of(Tile_Type))` (or compute the
  expected size with `size_of`; do **not** hardcode a byte count).
- (Policy B only)
  `v10_save_migrates_tile_visibility_into_dedicated_tile_state_array` — craft a
  v10 buffer (old 4-field `Tile` + 12-byte header) and assert the migration
  lifts visibility into the v11 tile-state array.
- A negative: `load_save_data_rejects_unsupported_old_version` (Policy A) — a
  v9/v10 buffer is rejected (returns `false`/nil), not crashed.

Verification: `just verify` → all pass, including the new tile-state tests.

## Done criteria

ALL must hold:

- [ ] `grep -n "visible\|explored\|light_level" src/core/types.odin` → none in `Tile`
- [ ] `SAVE_VERSION` is `u32(11)` in `src/io/save_format.odin`
- [ ] `Save_Data`, `Save_Floor`, `Saved_Floor` each have a `tile_states` array field
- [ ] A v11 save→load round-trip test exists and passes; tile visibility/light survive
- [ ] A `size_of(Tile)` assertion proves the shrink
- [ ] Policy A: `grep -n "Save_Data_V[2-9]" src/io/save_format.odin` → none;
      Policy B: only `Save_Data_V10` remains and its v10→v11 migration test passes
- [ ] `Ore_Vein.ore_type` is still `string` (untouched)
- [ ] `just verify` → `✓ tests + flag matrix + check + build passed`
- [ ] `git status` shows only in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows any save file changed since `bf2a4bd` and the excerpts no
  longer match — especially if Plan 001 has **not** been committed (this plan
  depends on it).
- No legacy-save policy (A or B) was provided — do not guess; ask.
- `eng.Tile_State` turns out to contain a pointer/string (not save-safe) — STOP;
  the direct-serialize approach is invalid and needs rethinking.
- Removing the `Tile` fields produces compile errors in files outside the scope
  list (e.g. render or AI reading `tile.visible` directly) — report the list;
  do not silently expand scope without confirming the manager accessor is the
  right replacement at each site.
- A save round-trip test fails on tile visibility after Step 3 — the export/import
  is wrong; fix before deleting any fields (Step 5).

## Maintenance notes

- This is the foundation for two deferred follow-ups, both of which also bump the
  save version and so must sequence *after* this: (1) `Ore_Vein.ore_type` →
  `Ore_Kind` enum, and (2) present-floors-only (length-prefixed `visited_floors`)
  to cut the 3.9 MB save. Do them in separate plans, each behind these
  round-trip tests.
- A reviewer should scrutinize: the export/import cell ordering (must match grid
  indexing), that no code still reads `tile.visible`-style fields, and that the
  chosen legacy policy is intentional (old saves unreadable under Policy A).
- The save format changed twice already this session (v10 CRC + a V2–V4
  migration fix). This is the third structural change; the round-trip tests are
  the safety net — do not skip them.
