# Into the Depths

> _You are not conquering the mine. You are trying to survive it long enough to reach the depths below._

A turn-based 2D roguelike written in [Odin](https://odin-lang.org/) with [Raylib](https://www.raylib.com/). You descend through procedurally generated mine floors where **light is the central survival mechanic** — each floor darker, each enemy more dangerous.

![Odin](https://img.shields.io/badge/Odin-dev--2026--05%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)

---

## Features

| Category                  | Details                                                                        |
| ------------------------- | ------------------------------------------------------------------------------ |
| **Procedural generation** | 3 map styles (rooms, mixed, caves) that shift with depth                       |
| **FOV & lighting**        | Recursive shadowcasting with depth-scaled light radius                         |
| **Mining & crafting**     | Mine walls for ores, craft equipment at anvils                                 |
| **Combat**                | Bump-to-attack with A\* enemy pathfinding and monster abilities                |
| **Items & equipment**     | 17 item types across consumables, materials, and 2 tiers of equipment          |
| **Environmental hazards** | Water, gas vents, unstable ground, and chasms                                  |
| **Depth palettes**        | Brown mine → gray stone → blue crystal → purple deep                           |
| **Full UI**               | Inventory with inspect panel, crafting menu, minimap, help screen, message log |
| **Save & load**           | Persistent save with full world state                                          |
| **Score tracking**        | Local high score persistence                                                   |
| **Particle system**       | Visual feedback for combat, mining, hazards                                    |
| **Audio**                 | Spatial sound effects and ambient audio                                        |

---

## Screenshots

_Coming soon_

---

## Getting Started

### Prerequisites

- [Odin](https://odin-lang.org/docs/install/) (dev-2026-05 or later)
- [just](https://just.systems/) (task runner)
- Odin vendor Raylib bindings (included with Odin)

### Build & Run

```bash
# Clone
git clone https://github.com/HexSleeves/odin-into-the-dark
cd odin-into-the-dark

# Build and run (debug)
just run

# Or manually
odin run src/

# Release build (optimized, no bounds checks)
just release

# Run tests
just test

# Format source files (requires odinfmt from OLS)
just fmt
```

---

## Controls

| Key                   | Action                  |
| --------------------- | ----------------------- |
| `WASD` / `Arrow Keys` | Move                    |
| `.` (period)          | Wait a turn             |
| Walk into enemy       | Attack                  |
| `G`                   | Pick up item            |
| `I`                   | Open inventory          |
| `1`–`9`               | Use item (in inventory) |
| `D` + `1`–`9`         | Drop item               |
| `E` + `1`–`9`         | Equip item              |
| `Up` / `Down`         | Inspect item details    |
| `X` + direction       | Mine adjacent wall      |
| `C` (on anvil)        | Open crafting           |
| `M`                   | Toggle minimap          |
| `?`                   | Help screen             |
| `R` (game over)       | Restart                 |
| `ESC`                 | Close menu / Quit       |

---

## Project Structure

```
src/
├── main.odin               # Entry point and game loop
├── constants.odin          # All game constants and layout values
├── types.odin              # Struct and enum definitions
├── map_utils.odin          # Tile access helpers
├── game.odin               # Game init/reinit, camera, cleanup
├── game_app.odin           # Application shell and engine integration
├── input.odin              # Player input and descent logic
├── logger.odin             # Runtime diagnostics logger
├── combat.odin             # Attack resolution
├── enemy.odin              # Enemy AI (A*, Dijkstra, chase, wander, abilities)
├── fov.odin                # Field of view (recursive shadowcasting)
├── items.odin              # Item factory, pickup, drop, use, spawn
├── equipment.odin          # Equip/unequip, effective stats, starter gear
├── mining.odin             # Wall mining, crafting recipes, material management
├── generation.odin         # Map generation dispatch, rooms, hazards, ore veins
├── mapgen_cave.odin        # Cellular automata cave/mixed generators
├── data.odin               # JSON5 data loading, enemy/item factories
├── messages.odin           # Message log ring buffer
├── particles.odin          # Particle effect system
├── render.odin             # Top-level render orchestrator
├── render_map.odin         # Map tiles, entities, palettes, tooltip
├── render_hud.odin         # HUD bar (HP, stats, pickaxe, equipment)
├── render_ui.odin          # Overlay screens (inventory, crafting, help, game over)
├── render_minimap.odin     # Minimap overlay
├── saveload.odin           # Save/load serialization
└── scores.odin             # High score tracking
engine/
├── engine.odin             # Engine bootstrap and service registry
├── engine_services.odin    # Pluggable backend interface definitions
├── game_app.odin           # Application lifecycle management
├── input_manager.odin      # Unified input with action mapping
├── audio_manager.odin      # Audio playback management
├── sprite_manager.odin     # Sprite atlas and frame management
├── scene_manager.odin      # Scene push/pop stack
├── content_manager.odin    # Asset content loading
├── message_manager.odin    # Typed in-engine event messages
├── particle_manager.odin   # Particle pool and update
├── camera_manager.odin     # Camera transform management
├── config_manager.odin     # Runtime config and env vars
└── ...                     # Additional managers and backends
data/
├── enemies.json5           # Enemy definitions and spawn tables
├── items.json5             # Item definitions and spawn weights
└── player.json5            # Player starting stats
```

### Architecture

The engine layer (`src/engine/`) provides pluggable backends for rendering, audio, input, and platform abstractions. Game logic sits above the engine and communicates through typed messages and manager interfaces. This keeps game code backend-agnostic and fully testable without a window.

---

## Data-Driven Design

Enemy types, item definitions, spawn weights, and player stats live in JSON5 files under `data/`. Adding a new enemy or item requires only a data change — no code modifications.

---

## Diagnostics Logging

The game writes diagnostics through a logger with console and file sinks, separate from the in-game message panel.

When launched through `just`, variables can live in `.env` (via `set dotenv-load`). Running `./into_the_depths` directly requires variables to be exported in the shell.

| Variable                | Default               | Description                                                                                                               |
| ----------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `ITD_LOG_LEVEL`         | `info`                | Base level: `debug`, `info`, `warn`, `error`, `fatal`, `off`                                                              |
| `ITD_LOG_CONSOLE`       | `1`                   | Enable console logging                                                                                                    |
| `ITD_LOG_FILE`          | `1`                   | Enable file logging                                                                                                       |
| `ITD_LOG_FILE_PATH`     | `into_the_depths.log` | Log file path (append mode)                                                                                               |
| `ITD_LOG_CONSOLE_LEVEL` | `ITD_LOG_LEVEL`       | Console-specific minimum level                                                                                            |
| `ITD_LOG_FILE_LEVEL`    | `ITD_LOG_LEVEL`       | File-specific minimum level                                                                                               |
| `ITD_LOG_CHANNELS`      | `all`                 | Comma-separated channel filter: `app`, `init`, `data`, `gen`, `fov`, `enemy`, `items`, `input`, `save`, `audio`, or `all` |
| `ITD_LOG_SOURCE`        | `1`                   | Include source file and line in output                                                                                    |
| `ITD_LOG_FLUSH`         | `1`                   | Flush file logs after each write                                                                                          |

```bash
# Examples
ITD_LOG_LEVEL=debug just run
ITD_LOG_LEVEL=debug ITD_LOG_CHANNELS=data,gen just run
ITD_LOG_CONSOLE=0 ITD_LOG_FILE=1 just run
```

---

## Roadmap

### v0.2 — Content & Polish

- [ ] Additional enemy types with unique abilities per depth tier
- [ ] Expanded crafting recipes and material tiers
- [ ] Status effects (burning, slowed, poisoned, blinded)
- [ ] More environmental hazards (flooding, cave-ins)
- [ ] Sound effect pass with spatial audio
- [ ] Animated sprites for player and enemies

### v0.3 — Depth & Progression

- [ ] Boss encounters at depth milestones
- [ ] Unique floor events (merchant, shrine, trapped chest)
- [ ] Permanent upgrades between runs (meta-progression)
- [ ] Deeper depth tiers (floors 11–20) with new palettes
- [ ] Cursed and enchanted item variants

### v0.4 — Game Modes & Polish

- [ ] Daily challenge seed (shared globally)
- [ ] Seeded custom runs
- [ ] Online leaderboard
- [ ] Controller / gamepad support
- [ ] Accessibility options (colorblind modes, larger text)
- [ ] Settings menu (volume, keybindings, display)

### v0.5 — Engine Maturity

- [ ] Hot-reload data files without restart
- [ ] Replay system (record and replay full runs)
- [ ] Mod support via external data packs
- [ ] Performance profiling pass
- [ ] CI/CD pipeline with automated test runs

### Backlog / Under Consideration

ta packs

- [ ] Performance profiling pass
- [ ] CI/CD pipeline with automated test runs

### Backlog / Under Consideration

- Multiplayer co-op (shared mine, split resources)
- Steam release with Steamworks integration
- Mobile port (touch controls)
- Map editor / level seeds export

---

## Development

```bash
just          # List all commands
just build    # Debug build
just run      # Build and run
just test     # Run all tests
just check    # Type-check only
just fmt      # Format all source files
just release  # Optimized release build
just verify   # Full CI: test + check + build
just stats    # Line count by file
just clean    # Remove build artifacts
```

---

## Contributing

Issues and PRs welcome. Check open issues for `good first issue` tags before starting large features.

1. Fork and clone
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Test: `just verify`
4. Open a PR against `main`

---

## License

[MIT](LICENSE) © Jacob LeCoq
