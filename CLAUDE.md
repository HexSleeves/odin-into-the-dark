# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
just verify          # required pre-completion gate: tests + flag matrix + check + build
just test            # run all tests via Python runner
just check           # type-check only (fast, no binary)
just build           # debug binary
just run             # build and run
just fmt             # format with odinfmt
just release         # optimized build (-o:speed, -disable-assert, -no-bounds-check)
```

**Run a single test:**

```bash
python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=main.test_proc_name_here
```

**Test runner detail:** `just test` calls `python3 scripts/run_odin_tests.py`. The script copies `src/` to `build/test-packages/src/` (excluding `*_test.odin`), overlays `test/**/*_test.odin` into matching dirs, then runs `odin test` per package. Test files live in `test/`, not `src/`.

## Architecture

**Two-layer split:**

- `src/engine/` (`package engine`) — backend-agnostic managers: scenes, turns, storage, grid, tile-state, audio/render/input backends as vtable structs
- `src/` (`package main`) — game logic, plus sub-packages imported and re-exported via aliases

**Sub-packages under `src/`** (each a separate Odin package):

| Path | Package | Re-exported via |
|---|---|---|
| `src/core/` | `package gcore` | `src/core_aliases.odin` |
| `src/render/` | `package renderer` | `src/render_aliases.odin` |
| `src/audio/`, `src/io/`, `src/ui/` | dedicated packages | direct import |

`core_aliases.odin` and `render_aliases.odin` re-export types and procs from their sub-packages into `package main` as bare names (`Game`, `Enemy`, `render_game`, etc.), so the rest of `src/` can use them unqualified.

**Game loop entry:** `main()` → `engine_run(config, services, &app)` where `app` is a `Game_App` vtable (`init/update/render/shutdown/autosave` function pointers + `rawptr state`).

**Services:** game-layer singletons (Content, Save, Sprite, Score, Input, UI) registered at init and retrieved via `cast(^Type)eng.engine_services_get(engine.services, ID)`. Max 16, stored in an inline arena — no heap allocation.

**Scene system:** `Game_State` enum → `Game_Scene` enum, 1:1. `scene.odin` owns the mapping. `engine.Scene_Manager` owns lifecycle (enter/update/render/exit callbacks).

**Data-driven content:** enemies, items, player stats in `data/*.json5`. `g_data` in `src/data.odin` is the global `Data_Registry`; `content_manager_load_all(&c)` loads into a local registry without touching `g_data`.

**Clay UI:** vendored at `src/vendor/clay/`. `src/render/clay_renderer.odin` translates Clay commands to `Engine_Render_Backend`. Engine code never imports Clay.

## Testing patterns

Test files are in `test/` using `package main`. The Python runner merges them into the src tree before compiling, so they access all package-main symbols directly.

**Test setup for game state:** call `game_init_world(&g)` to initialize `g.world`, `g.tile_states`, and `g.web_tiles` (zero-init `Game` structs have invalid grids; tile/web operations silently no-op on invalid grids).

**Fake backends:** construct `Engine_File_System` / other backend structs directly with test function pointers — no mocking framework.

**Naming:** test proc names are full sentences: `storage_manager_delegates_file_operations_to_configured_file_system`.

## Key invariants

- Engine layer (`src/engine/`) has zero Raylib imports — engine tests run headlessly.
- `Game` struct (~112 KB) must be heap-allocated via `new(Game)` in production; stack allocation is fine in tests for short-lived game state.
- `just verify` must pass before any task is considered complete.

## Rules

- Always run `just verify` before claiming a task is done.
- Always run `just fmt` before committing code.
