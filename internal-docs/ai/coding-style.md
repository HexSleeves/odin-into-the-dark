# Coding Style

> Language, framework, and code conventions for Into the Depths.

## Language

- **Odin** (`2026-05` dev version)
- **No external dependencies** beyond Odin's `core:` and `vendor:raylib`
- **Package manager:** None — Odin handles imports natively

## Naming

| Kind | Convention | Example |
|---|---|---|
| Types / Enums | `PascalCase` | `Engine_File_System`, `Game_State` |
| Procedures | `snake_case` with `type_verb` prefix | `storage_manager_read`, `turn_manager_advance` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAP_WIDTH`, `SAVE_MAGIC` |
| Fields / locals | `snake_case` | `file_system`, `depth_min` |
| Constructor procs | `type_make` | `storage_manager_make()` |
| Destructor procs | `type_destroy` | `game_destroy()` |
| File-private helpers | `@(private = "file")` | Internal find_index procs |

## Error Handling

- Simple fallible ops return `bool` — no error union ceremony
- Early nil-guard: `if thing == nil { return }` or `if thing == nil { return false }`
- Fatal init failures: `logger_fatalf(.App, "..."); free(state); return false` — no panics
- No error handling for "impossible" internal cases (contract violations)

## Memory

- `Game` struct (~112 KB) is heap-allocated via `new(Game)` — too large for stack
- Dynamic collections: `[dynamic]T`, initialized in `game_init`, freed in `game_cleanup`
- Fixed-size arrays for tile data: `[MAP_WIDTH * MAP_HEIGHT]Tile`
- Save format: `Save_String` (`[MAX_NAME_LEN]u8` + `len`) to avoid heap pointers in serialized data
- Service storage: inline arena (`[ENGINE_SERVICE_STORAGE_WORDS]u64`) — no heap allocation
- Always pass `allocator` explicitly when reading files

## Backend Injection Pattern

```odin
fs := Engine_File_System{
    ctx               = &my_state,
    read_entire_file  = my_read_proc,
    write_entire_file = my_write_proc,
    exists            = my_exists_proc,
    remove            = my_remove_proc,
}
storage := storage_manager_make(fs)
```

All backends follow the same `{ctx: rawptr, fn_ptr, fn_ptr, ...}` shape.
Use `_or_default` procs when a zero-value backend should fall back to OS default.

## Data-Driven Design

- Game data lives in `data/*.json5` — no code change needed to add/modify content
- `data.odin` defines Odin structs mirroring json5 structure
- `Content_Manager` wraps `Data_Registry` with typed accessors
- Enemy/item types on runtime structs are string IDs matching json5 `id` fields

## Comments

Write comments only when the **why** is non-obvious — hidden constraints, subtle invariants, or workarounds.
No docstrings. No narrating what the code does.

## Imports

- Do not import `src/core` as `core` — conflicts with Odin's `core:` collection. Use `gcore`.
- Do not name the IO package `io` — conflicts with `core:io`. Use `gameio`.
- Engine layer must not import `vendor:raylib` or `clay`.
- Game layer can import both.

## Testing

- **Framework:** Odin's built-in `core:testing`
- **Test files:** `test/**/*_test.odin` (mirrors src structure)
- **Test names:** Full sentences describing behavior: `storage_manager_delegates_file_operations_to_configured_file_system`
- **Setup:** Call `game_init_world(&g)` before tile/web operations
- **Backend injection:** Construct fake `Engine_File_System` with test procs — no mocking framework
- **Engine tests:** Headless, no window required

## Formatting

- Use `odinfmt` (from OLS build) — `just fmt`
- Run before every commit
- `odin fmt` is NOT a valid subcommand

## Build Flags

| Define | Purpose |
|---|---|
| `CHEATS=true` | Enable cheat menu |
| `SPRITES=true` | Enable sprite rendering |
| `NO_AUDIO=true` | Disable audio |
| `NO_SPRITES=true` | Disable sprites |
| `SKIP_TITLE=true` | Skip title screen |
| `FIXED_SEED=N` | Fixed RNG seed |
| `PUBLIC_BUILD=true` | Release build flag |

## Forbidden Patterns

- Panics — use `logger_fatalf` + cleanup + return false
- Raylib imports in `src/engine/`
- Clay imports in `src/engine/`
- Editing `src/vendor/clay/` or `vendor/clay/`
- `odin fmt` (not a valid subcommand)
- Direct push to `main`

## File Organization

- One package per directory
- Root-level `src/*.odin` for app wiring in `package main`
- `src/core/` for pure data layer
- `src/gameplay/` for game mechanics
- `src/engine/` for reusable managers
- `test/` mirrors `src/` structure
