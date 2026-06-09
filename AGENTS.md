# Repository Guidelines

Turn-based 2D roguelike written in [Odin](https://odin-lang.org/) + Raylib.
**Repo:** `HexSleeves/odin-into-the-dark`

---

## Project Overview

_Into the Depths_ is a procedurally generated mine-descending roguelike. The player descends floors, fights data-driven enemies, collects/equips items, and is scored on depth, kills, and turns survived. The game is implemented in two Odin packages: a reusable `engine` layer and the game-specific `main` layer.

---

## Architecture & Data Flow

```
main()  →  engine_run(config, services, &app)
             │
             ├─ Backend init (platform/audio/input/render/texture)
             ├─ Manager init (texture, audio, storage, camera, turn, vfx, message, particle)
             ├─ app.init  → register services → load content (json5) → game_init → scene_init
             │
             └─ Loop: app.update → handle_global_input → scene_manager_update → scene callbacks
                      app.render → scene_manager_render → active scene render callback
                      [on exit] app.autosave
```

**Two-package split:**

| Package  | Path          | Role                                                    |
| -------- | ------------- | ------------------------------------------------------- |
| `engine` | `src/engine/` | Backend-agnostic, window-free managers and abstractions |
| `main`   | `src/`        | Game-specific logic, scenes, rendering, data            |

**`Game_App` is a vtable struct** — `init`, `update`, `render`, `shutdown`, `autosave` are function pointers with a `rawptr state` field. The game layer fills this struct; the engine calls it.

**Services registry** — game-layer managers (Content, Save, Sprite, Score, Input, UI) are registered by `Engine_Service_Id` (typed `int`) at init time and retrieved via `cast(^Type)eng.engine_services_get(engine.services, ID)`. Max 16 services; storage is a fixed inline arena.

**Scene system** — `Game_State` enum maps 1:1 to `Game_Scene` enum. Each scene has `enter/update/render/exit` callbacks. `scene.odin` owns the mapping; `engine.Scene_Manager` owns the lifecycle.

**Backend abstraction** — every I/O boundary is a struct of `ctx: rawptr` + function pointers:

- `Engine_File_System` — read/write/exists/remove
- `Engine_Input_Backend`, `Engine_Audio_Backend`, `Engine_Render_Backend`, `Engine_Texture_Backend`

Defaults use OS/Raylib implementations. Tests inject fake backends by constructing the struct directly — no mocking framework.

**Clay UI path** — Clay is the default immediate-mode UI layout path. Clay is vendored at `src/vendor/clay/`; `src/render/clay_ui.odin` owns context/input/text measurement, `src/render/clay_renderer.odin` translates Clay commands to `Engine_Render_Backend`, and `src/render/clay_hud.odin`/`src/render/clay_overlays.odin` declare game UI. Engine code never imports Clay.

---

## Key Directories

| Path                                 | Purpose                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------- |
| `src/`                               | Game package (`package main`) — app lifecycle, scene routing, and alias shims               |
| `src/core/`                          | Pure data layer — game types, constants, content/save managers, inventory/equipment helpers |
| `src/gameplay/`                      | Gameplay orchestration — actions, items, mining, FOV, generation, status effects            |
| `src/input/`                         | Input package (`package gameinput`) — input manager, key bindings, all input state handlers |
| `src/render/`                        | Rendering package — Clay UI, world rendering, sprites, particles                            |
| `src/audio/` / `src/io/` / `src/ui/` | Audio, logging/platform I/O, and UI manager packages                                        |
| `src/ai/` / `src/gen/`               | AI (enemy turns, combat, abilities) and map generation packages                             |
| `src/engine/`                        | Engine package (`package engine`) — reusable, backend-agnostic managers                     |
| `data/`                              | json5 data files — enemies, items, player, sprites                                          |
| `assets/`                            | PNG spritesheets (tiles, characters, items, GUI)                                            |
| `scripts/`                           | Python runtime evidence/verification scripts                                                |

---

## Development Commands

```bash
just verify          # full CI: odin test src/ && odin test src/engine/ && odin check src/ && odin build src/
just test            # odin test src/ && odin test src/engine/
just check           # odin check src/   (type-check only, no binary)
just build           # odin build src/ -out:into_the_depths
just run             # odin run src/
just fmt             # /Users/lecoqjacob/Developer/games/ols/odinfmt src/ -w
just release         # odin build src/ -out:into_the_depths -o:speed -disable-assert -no-bounds-check
just stats           # wc -l on all .odin and .json5 files
```

`just verify` is the required pre-completion gate. Always run it before finishing any task.

**Tooling:**

- Odin: `2026-05` (Homebrew, `/opt/homebrew/Cellar/odin/2026-05/`)
- OLS language server: `ols.json` — `-vet -strict-style` checker args, inlay hints enabled
- `odinfmt` binary: `/Users/lecoqjacob/Developer/games/ols/odinfmt`
- No external package manager — uses Odin's built-in `vendor:raylib` and `core:` collections

---

## Code Conventions & Common Patterns

### Naming

| Kind                 | Convention                           | Example                                         |
| -------------------- | ------------------------------------ | ----------------------------------------------- |
| Types / Enums        | `PascalCase`                         | `Engine_File_System`, `Game_State`              |
| Procedures           | `snake_case` with `type_verb` prefix | `storage_manager_read`, `turn_manager_advance`  |
| Constants            | `SCREAMING_SNAKE_CASE`               | `MAP_WIDTH`, `SAVE_MAGIC`                       |
| Fields / locals      | `snake_case`                         | `file_system`, `depth_min`                      |
| Constructor procs    | `type_make`                          | `storage_manager_make()`, `turn_manager_make()` |
| Destructor procs     | `type_destroy`                       | `game_destroy()`, `score_table_destroy()`       |
| File-private helpers | `@(private = "file")` attribute      | internal find_index procs                       |

### Error Handling

- Simple fallible operations return `bool` — no error union ceremony for internal ops.
- Early nil-guard pattern: `if thing == nil { return }` or `if thing == nil { return false }`.
- Fatal init failures: `logger_fatalf(.App, "..."); free(state); return false` — no panics.
- No error handling for "impossible" internal cases (contract violations).

### Memory

- `Game` struct (~112 KB) is heap-allocated via `new(Game)` — too large for stack.
- Dynamic collections (`rooms`, `enemies`, `items`, `light_sources`) are `[dynamic]T`, initialized in `game_init`, freed in `game_cleanup`.
- Fixed-size arrays used for tile data: `[MAP_WIDTH * MAP_HEIGHT]Tile`.
- Save format uses `Save_String` (`[MAX_NAME_LEN]u8` + `len`) to avoid heap pointers in serialized data.
- Service storage uses an inline arena (`[ENGINE_SERVICE_STORAGE_WORDS]u64`) — no heap allocation for service registration.
- Always pass `allocator` explicitly when reading files: `storage_manager_read(&s, path, context.allocator)`.

### Backend Injection Pattern

```odin
// Engine_File_System is a procedure table
fs := Engine_File_System{
    ctx               = &my_state,
    read_entire_file  = my_read_proc,
    write_entire_file = my_write_proc,
    exists            = my_exists_proc,
    remove            = my_remove_proc,
}
storage := storage_manager_make(fs)
```

All backends follow the same `{ctx: rawptr, fn_ptr, fn_ptr, ...}` shape. Use `_or_default` procs when a zero-value backend should fall back to OS default.

### Data-Driven Design

- Game data (enemies, items, player stats) lives in `data/*.json5` — **no code change needed** to add/modify content.
- `data.odin` defines Odin structs mirroring json5 structure and loads them via `core:encoding/json`.
- `Content_Manager` wraps `Data_Registry` and exposes typed accessors (`content_manager_enemy_def`, `content_manager_item_def`, etc.).
- Enemy/item types on runtime structs are string IDs (`enemy_type: string`, `item_type: string`) matching json5 `id` fields.

### Comments

Write comments only when the **why** is non-obvious — hidden constraints, subtle invariants, or workarounds. No docstrings, no narrating what the code does.

---

## Important Files

| File                                                                                                                                             | Purpose                                                                              |
| ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| `src/main.odin`                                                                                                                                  | Entry point — 12 lines, calls `engine_run`                                           |
| `src/game_app_lifecycle.odin` / `src/game_app_config.odin` / `src/game_services.odin`                                                            | App lifecycle, build/runtime config, and game service registration/accessors         |
| `src/core/types.odin`                                                                                                                            | Core game types: `Game`, `Player`, `Enemy`, `Item`, `Tile`, `Game_State`             |
| `src/core/screen_layout.odin` / `src/core/gameplay_tuning.odin` / `src/core/build_config.odin`                                                   | Screen geometry, gameplay tuning constants, build flags                              |
| `src/game.odin`                                                                                                                                  | `game_init`, `game_destroy`, `game_camera_update`                                    |
| `src/scene.odin`                                                                                                                                 | `Game_Scene` enum, `scene_for_state`, scene update/render callbacks                  |
| `src/gameplay/generation.odin`                                                                                                                   | Map generation dispatch and item spawning                                            |
| `src/gameplay/actions.odin`                                                                                                                      | Turn/combat orchestration: descend, advance_turn, trigger_enemy_rounds, tile effects |
| `src/gameplay/items.odin`                                                                                                                        | Item factory, pickup, use, drop, equip, apply_item_effect                            |
| `src/gameplay/mining.odin`                                                                                                                       | Mining and crafting orchestration                                                    |
| `src/gameplay/fov.odin`                                                                                                                          | Field-of-view computation                                                            |
| `src/gameplay/status_effects.odin`                                                                                                               | Timed effect ticking (poison, fire, light drain)                                     |
| `src/gameplay/restart.odin`                                                                                                                      | Score saving                                                                         |
| `src/gen/*.odin`                                                                                                                                 | Procedural room/cave/mixed map generation                                            |
| `src/data.odin` / `src/core/data_defs.odin` / `src/core/content_manager.odin`                                                                    | json5 parsing, data schemas, content registry/accessors                              |
| `src/io/save_*.odin`                                                                                                                             | Binary save format and persistence flow                                              |
| `src/actions.odin`                                                                                                                               | Root bridge: handle_player_action, restart_game                                      |
| `src/ai/combat.odin`                                                                                                                             | Combat resolution                                                                    |
| `src/input/manager.odin`                                                                                                                         | Input manager, key bindings, Game_Action enum                                        |
| `src/input/playing_action.odin`                                                                                                                  | Movement/combat input dispatch (handle_input)                                        |
| `src/input/playing_state.odin`                                                                                                                   | Playing state hotkeys, mining input, forced turns                                    |
| `src/input/state_updates.odin`                                                                                                                   | Per-state update handlers (inventory, crafting, help, scores, game over, victory)    |
| `src/input/cheats.odin`                                                                                                                          | Cheat menu input handling                                                            |
| `src/render/render.odin`                                                                                                                         | Top-level render dispatch                                                            |
| `src/render/render_map.odin` / `src/render/render_items.odin` / `src/render/render_world.odin` / `src/render/render_title_fx.odin`               | World/map/item rendering and title fire backdrop effects                             |
| `src/render/clay_ui.odin` / `src/render/clay_renderer.odin` / `src/render/clay_hud.odin` / `src/render/clay_overlays.odin` / `src/render/clay_*` | Clay immediate-mode UI path                                                          |
| `src/vendor/clay/`                                                                                                                               | Vendored Clay Odin binding and prebuilt platform libraries                           |
| `src/engine/engine.odin`                                                                                                                         | `Engine` struct, `engine_run` loop, all manager accessors                            |
| `src/engine/engine_services.odin`                                                                                                                | Service registry (up to 16 services, inline arena)                                   |
| `src/engine/file_system.odin`                                                                                                                    | `Engine_File_System` abstraction + OS default                                        |
| `src/engine/storage_manager.odin`                                                                                                                | Generic byte-level persistence via injected FS                                       |
| `src/engine/scene_manager.odin`                                                                                                                  | Scene lifecycle (enter/update/render/exit)                                           |
| `src/engine/turn_manager.odin`                                                                                                                   | Turn counter                                                                         |
| `data/enemies.json5`                                                                                                                             | Enemy stats, abilities, depth-weighted spawn tables                                  |
| `data/items.json5`                                                                                                                               | Item stats, effects, stack limits, equipment slots                                   |
| `data/player.json5`                                                                                                                              | Player starting stats                                                                |
| `data/sprites.json5`                                                                                                                             | Sprite sheet mapping                                                                 |

---

## Runtime/Tooling Preferences

- **Language:** Odin (`2026-05`)
- **Renderer:** World rendering uses game-layer `render_draw_*` helpers over `Engine_Render_Backend`; UI rendering uses Clay translated through the same backend
- **Build tool:** `just` (justfile), not make/cmake
- **Formatter:** `odinfmt` — run via `just fmt`; must be installed at the path in justfile
- **LSP:** OLS with `-vet -strict-style`; inlay hints on
- **No external dependencies** beyond Odin's standard library and vendor:raylib
- **Engine layer must stay backend-agnostic** — no Raylib imports in `src/engine/`
- **Clay UI:** default UI path; keep Clay in the game layer and translate through `Engine_Render_Backend`

---

## Testing & QA

### Framework

Odin's built-in `core:testing` package. No external test framework.

```odin
@(test)
my_test_procedure_name_is_a_full_sentence :: proc(t: ^testing.T) {
    testing.expect(t, condition)
    testing.expect_value(t, actual, expected)
}
```

### Running Tests

```bash
just test               # both packages
odin test src/          # main package only
odin test src/engine/   # engine package only
```

### Test Patterns

- **Test procedure names are full sentences** describing the behavior under test: `storage_manager_delegates_file_operations_to_configured_file_system`.
- **Inject fake backends** by constructing `Engine_File_System` / other backends with test functions — no mocking framework needed.
- **State structs** track call counts and last arguments to verify delegation: `read_count int`, `last_path string`, etc.
- Engine tests live in `package engine` (same package as source). Game tests live in `package main`.
- Test files named `*_test.odin`.
- Tests must be **window-free** — engine layer has no Raylib dependency, so engine tests run headlessly.

### Coverage Expectations

- Every new manager or public proc with non-trivial logic needs a test.
- Backend injection paths must be tested with a fake FS/backend.
- Save/load round-trips should be tested with in-memory fake storage.

---

## GitHub Project Board

**Board:** <https://github.com/users/HexSleeves/projects/4>

### Project IDs (for GraphQL mutations)

```
PROJECT_ID:         PVT_kwHOAI2S3s4BZire
STATUS_FIELD_ID:    PVTSSF_lAHOAI2S3s4BZirezhUgnCQ
STATUS_TODO:        f75ad846
STATUS_IN_PROGRESS: 47fc9ee4
STATUS_DONE:        98236657
```

### Required Board Actions

| Situation                        | Action                                          |
| -------------------------------- | ----------------------------------------------- |
| Starting work on a tracked issue | Set issue to **In Progress** on board           |
| Completing tracked work          | Close issue + set to **Done** on board          |
| Discovering untracked work       | Create issue, add to board, set **In Progress** |
| Opening a PR for a feature       | Add `Closes #N` to PR body                      |

### Move Issue to In Progress

```bash
ITEM_ID=$(gh api graphql -f query='{
  repository(owner: "HexSleeves", name: "odin-into-the-dark") {
    issue(number: ISSUE_NUM) { projectItems(first:1) { nodes { id } } }
  }
}' --jq '.data.repository.issue.projectItems.nodes[0].id')

gh api graphql -f query='mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwHOAI2S3s4BZire"
    itemId: "'$ITEM_ID'"
    fieldId: "PVTSSF_lAHOAI2S3s4BZirezhUgnCQ"
    value: { singleSelectOptionId: "47fc9ee4" }
  }) { projectV2Item { id } }
}'
```

### Close Issue + Move to Done

```bash
gh issue close ISSUE_NUM --repo HexSleeves/odin-into-the-dark \
  --comment "Completed: <one-line summary>"

# Then update board status to Done (98236657) using ITEM_ID pattern above
```

### Create Issue + Add to Board

```bash
URL=$(gh issue create --repo HexSleeves/odin-into-the-dark \
  --title "title" --body "body" \
  --label "roadmap,LABEL" --milestone MILESTONE_NUM)

NUM=$(echo $URL | grep -o '[0-9]*$')
NODE=$(gh api repos/HexSleeves/odin-into-the-dark/issues/$NUM --jq '.node_id')

gh api graphql -f query='mutation {
  addProjectV2ItemById(input: {
    projectId: "PVT_kwHOAI2S3s4BZire"
    contentId: "'$NODE'"
  }) { item { id } }
}'
```

### Milestones

| Number | Name                       |
| ------ | -------------------------- |
| 1      | v0.2 — Content & Polish    |
| 2      | v0.3 — Depth & Progression |
| 3      | v0.4 — Game Modes & Polish |
| 4      | v0.5 — Engine Maturity     |

### Labels

`content` · `engine` · `gameplay` · `ui/ux` · `performance` · `good first issue` · `roadmap` · `backlog`

## Rules

- Always run `just verify` before claiming a task is done.
- Always run `just fmt` before committing code.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:

- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
