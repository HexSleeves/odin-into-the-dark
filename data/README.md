# Data Directory — Into the Depths

Game content and balance data, loaded at startup from JSON5 files.

See `src/data.odin` for the loader.

## Files

| File            | Purpose                                                                         |
| --------------- | ------------------------------------------------------------------------------- |
| `enemies.json5` | Enemy definitions (stats, glyph, color) + depth-based spawn tables              |
| `items.json5`   | Item definitions (stats, glyph, color, stack limit, use-effect) + spawn weights |
| `player.json5`  | Player starting stats (HP, attack, light radius, glyph, color)                  |

## Editing

1. Edit any `.json5` file while the game is not running.
2. Restart — changes take effect immediately, no recompile needed.

## Conventions

- IDs: lowercase `snake_case` strings.
- Colors: `[r, g, b, a]` (0–255).
- Glyphs: single-character strings (e.g. `"r"`, `"!"`).
- Spawn weights are relative (don't need to sum to 100).
- JSON5 supports comments (`//`), trailing commas, and unquoted keys.

## Adding Content

- **New enemy**: add entry to `enemies` array + add to relevant `spawn_tables` entries.
- **New item**: add entry to `items` array + add to `spawn_weights`. New effect types need a handler in `apply_item_effect` in `src/data.odin`.
