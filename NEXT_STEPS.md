# Into the Depths — Next Steps

## Recently shipped

| Area        | Feature                                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------------------ |
| Shipping    | Build-flag matrix, macOS bundle, and WASM/web smoke validation completed                                     |
| Engine      | Texture manager and desktop/web backends can load textures from embedded bytes                               |
| Engine      | Sprite atlas now loads from compile-time PNG bytes instead of runtime filesystem paths                       |
| Engine      | Persistent game reinitialization restores caller allocator context after heap-scoped allocations             |
| Polish      | Boss camera focus tuned to a named `BOSS_CAMERA_ZOOM` level                                                  |
| Polish      | Title screen adds a stronger atmospheric tagline                                                             |
| Content     | Old Miner intro is correctly marked as one-shot dialogue content                                             |
| Content     | Frozen status effect: deep_watcher freeze, doubled movement cost, timed thaw message, HUD indicator          |
| Content     | Treasure vault room: sealed perimeter, locked door, key elsewhere, guaranteed rare loot                      |
| Game feel   | Tile-specific footsteps for water, rubble, and stone/descent/anvil                                           |

## Build flag reference

```bash
CHEATS=true just run-built              # Shift+C cheat menu
SPRITES=true just run-built             # start in sprite mode
NO_AUDIO=true just run-built            # nil audio backend
NO_SPRITES=true just run-built          # skip sprite atlas runtime load/copy
SKIP_TITLE=true just run-built          # start directly in gameplay
FIXED_SEED=12345 just run-built         # deterministic map seed
```

Flags compose, for example:

```bash
CHEATS=true SKIP_TITLE=true FIXED_SEED=42 just run-built
NO_AUDIO=true NO_SPRITES=true just release-macos
```

## Remaining work

### Roadmap candidates

1. **CI/CD: automated test and build pipeline**
   - Capture the now-verified `just verify`, macOS release, and web release gates in CI.

2. **Settings menu: volume, keybindings, display**
   - Build on the existing title/help/menu structure and input action binding table.

3. **Accessibility: colorblind modes, larger text**
   - Extend the UI theme constants and render text sizing paths.

4. **Deeper content and progression**
   - Deeper depth tiers, additional floor events, cursed/enchanted items, crafting tiers, and hazards are still tracked as roadmap issues.

5. **Engine maturity follow-ups**
   - Performance profiling, replay support, hot-reload, and map editor/seed export remain larger roadmap items.
