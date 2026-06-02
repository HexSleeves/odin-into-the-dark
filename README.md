# Into the Depths

A turn-based 2D roguelike written in [Odin](https://odin-lang.org/) with [Raylib](https://www.raylib.com/), where the player descends through procedurally generated mine floors. **Light is the central survival mechanic** — each floor is darker than the last. Enemies scale in danger with depth. The core fantasy: _"You are not conquering the mine. You are trying to survive it long enough to reach the depths below."_

## Features

- **Procedural generation** — 3 map styles (rooms, mixed, caves) that shift with depth
- **FOV & lighting** — Recursive shadowcasting with depth-scaled light radius
- **Mining & crafting** — Mine walls for ores, craft equipment at anvils
- **Combat** — Bump-to-attack with A\* enemy pathfinding and monster abilities
- **Items & equipment** — 17 item types across consumables, materials, and 2 tiers of equipment
- **Environmental hazards** — Water, gas vents, unstable ground, and chasms
- **4 depth-themed palettes** — Brown mine → gray stone → blue crystal → purple deep
- **Full UI** — Inventory with inspect panel, crafting menu, minimap, help screen, message log

## Controls

| Key             | Action                  |
| --------------- | ----------------------- |
| WASD / Arrows   | Move                    |
| . (period)      | Wait a turn             |
| Walk into enemy | Attack                  |
| G               | Pick up item            |
| I               | Open inventory          |
| 1-9             | Use item (in inventory) |
| D + 1-9         | Drop item               |
| E + 1-9         | Equip item              |
| Up/Down         | Inspect item details    |
| X + direction   | Mine adjacent wall      |
| C (on anvil)    | Open crafting           |
| M               | Toggle minimap          |
| ?               | Help screen             |
| R (game over)   | Restart                 |
| ESC             | Close menu / Quit       |

## Building

Requires [Odin](https://odin-lang.org/docs/install/) (dev-2026-05 or later) with vendor Raylib bindings.

```bash
# Quick build and run
just run

# Or manually
odin run src/

# Release build (optimized)
just release
```

## Diagnostics Logging

The game writes diagnostics through a small logger wrapper with console and file sinks. The in-game message panel remains separate and only shows player-facing gameplay messages.

When launched through `just`, logger variables can live in `.env` because the `justfile` uses `set dotenv-load`. Running `./into_the_depths` directly only reads variables already exported in the shell environment.

| Variable                | Default               | Description                                                                                                                                     |
| ----------------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `ITD_LOG_LEVEL`         | `info`                | Base log level: `debug`, `info`, `warn`, `warning`, `error`, `fatal`, or `off`.                                                                 |
| `ITD_LOG_CONSOLE`       | `1`                   | Enable console logging with `1/0`, `true/false`, `yes/no`, or `on/off`.                                                                         |
| `ITD_LOG_FILE`          | `1`                   | Enable file logging.                                                                                                                            |
| `ITD_LOG_FILE_PATH`     | `into_the_depths.log` | Log file path, opened in append mode.                                                                                                           |
| `ITD_LOG_CONSOLE_LEVEL` | `ITD_LOG_LEVEL`       | Optional console-specific minimum level.                                                                                                        |
| `ITD_LOG_FILE_LEVEL`    | `ITD_LOG_LEVEL`       | Optional file-specific minimum level.                                                                                                           |
| `ITD_LOG_CHANNELS`      | `all`                 | Comma-separated channel filter: `app`, `init`, `data`, `sprites`, `gen`, `fov`, `enemy`, `items`, `scores`, `audio`, `input`, `save`, or `all`. |
| `ITD_LOG_SOURCE`        | `1`                   | Include source file, line, and procedure in log output.                                                                                         |
| `ITD_LOG_FLUSH`         | `1`                   | Flush file logs after each write.                                                                                                               |

Examples:

```bash
ITD_LOG_LEVEL=debug just run
ITD_LOG_LEVEL=debug ITD_LOG_CHANNELS=data,gen just run
ITD_LOG_CONSOLE=0 ITD_LOG_FILE=1 ITD_LOG_FILE_PATH=into_the_depths.log just run
```

## Project Structure

```
src/
├── main.odin           # Entry point and game loop
├── constants.odin      # All game constants and layout values
├── types.odin          # Struct and enum definitions
├── map_utils.odin      # Tile access helpers (pos_to_idx, tile_at, is_walkable)
├── game.odin           # Game init/reinit, camera, cleanup
├── input.odin          # Player input handling and descent
├── logger.odin         # Runtime diagnostics logger (console/file sinks)
├── combat.odin         # Attack resolution
├── enemy.odin          # Enemy AI (A*, Dijkstra, chase, wander, abilities)
├── fov.odin            # Field of view (recursive shadowcasting)
├── items.odin          # Item factory, pickup, drop, use, spawn
├── equipment.odin      # Equip/unequip, effective stats, starter gear
├── mining.odin         # Wall mining, crafting recipes, material management
├── generation.odin     # Map generation dispatch, rooms, hazards, ore veins
├── mapgen_cave.odin    # Cellular automata cave/mixed generators
├── data.odin           # JSON5 data loading, enemy/item factories
├── messages.odin       # Message log ring buffer, display name helpers
├── render.odin         # Top-level render orchestrator
├── render_map.odin     # Map tiles, entities, palettes, tooltip
├── render_hud.odin     # HUD bar (HP, stats, pickaxe, equipment)
├── render_ui.odin      # Overlay screens (inventory, crafting, help, game over)
└── render_minimap.odin # Minimap overlay
data/
├── enemies.json5       # Enemy definitions and spawn tables
├── items.json5         # Item definitions and spawn weights
└── player.json5        # Player starting stats
```

## Data-Driven Design

Enemy types, item definitions, spawn weights, and player stats are defined in JSON5 data files under `data/`. Adding a new enemy or item requires only a data file change — no code modifications needed.

## License

[MIT](LICENSE)
