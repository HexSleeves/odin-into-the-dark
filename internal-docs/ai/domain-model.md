# Domain Model

> Product concepts and user-facing language for Into the Depths.

## Product Identity

- **Name:** Into the Depths
- **Tagline:** "You are not conquering the mine. You are trying to survive it long enough to reach the depths below."
- **Genre:** Turn-based 2D roguelike
- **Primary platform:** Desktop (macOS, Linux, Windows)
- **Secondary platform:** Web (WASM/WebGL)

## Core Loop

1. Player descends procedurally generated mine floors
2. Each floor is darker and more dangerous
3. Mine walls for ores, craft equipment at anvils
4. Fight enemies with bump-to-attack combat
5. Reach the next floor to descend deeper
6. Die and score based on depth, kills, turns survived

## Key Concepts

| Concept | User-Facing Name | Description |
|---|---|---|
| Floor / Depth | "Floor N" | A single level of the mine. Deeper = harder. |
| Tile | "Tile" | Discrete square on the map. Can be floor, wall, water, etc. |
| FOV | "Field of view" | What the player can see. Limited by light radius. |
| Light | "Light" | Central survival mechanic. Radius shrinks with depth. |
| Mining | "Mining" | Breaking walls to collect ores. |
| Crafting | "Crafting" | Using ores at anvils to make equipment. |
| Equipment | "Equipment" | Weapons, armor, pickaxes. Two tiers. |
| Items | "Items" | Consumables, materials, equipment. 17 types. |
| Enemies | "Enemies" / "Monsters" | Data-driven foes with abilities. |
| Status Effects | "Effects" | Poison, fire, light drain, slowed, blinded. |
| Hazards | "Hazards" | Water, gas vents, unstable ground, chasms. |
| Score | "Score" | Based on depth, kills, turns survived. |
| Save | "Save" | Persistent save with full world state. |

## User-Facing Language

- **Do use:** "Into the Depths", "Floor", "Depth", "Mine", "Descend", "Light", "Equipment", "Craft", "Ore"
- **Do not use:** "Dungeon", "Level" (use "Floor"), "HP" (use "Health" or context-appropriate), "XP" (no experience system)

## Tone

- Dark, atmospheric, survival-focused
- Not humorous or lighthearted
- Descriptive rather than mechanical
- Example: "The shadows grow deeper..." not "Light radius reduced by 50%"

## Depth Tiers

| Depth Range | Palette | Theme |
|---|---|---|
| 1-3 | Brown | Entry mine |
| 4-6 | Gray | Stone depths |
| 7-9 | Blue | Crystal caverns |
| 10+ | Purple | The deep |

## Controls (User-Facing)

| Key | Action |
|---|---|
| WASD / Arrow Keys | Move |
| . (period) | Wait |
| G | Pick up |
| I | Inventory |
| 1-9 | Use item |
| D + 1-9 | Drop item |
| E + 1-9 | Equip item |
| X + direction | Mine |
| C (on anvil) | Craft |
| M | Minimap |
| ? | Help |
| R (game over) | Restart |
| ESC | Close / Quit |

## Data-Driven Content

All content lives in `data/*.json5`:

- `enemies.json5` — Enemy stats, abilities, spawn tables
- `items.json5` — Item stats, effects, stack limits, equipment slots
- `player.json5` — Starting stats
- `sprites.json5` — Sprite sheet mapping

Adding content requires only data changes — no code.

## Sensitive Information

- Do not expose internal engine structure in user-facing text
- Do not mention "Raylib", "Odin", "Clay", "karl2d" in user-facing copy
- Do not expose save file format details
- Do not mention "string IDs" or "json5" in user-facing docs
