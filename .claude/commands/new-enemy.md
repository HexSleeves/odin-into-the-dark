# New Enemy — Add a Data-Driven Enemy

Add a new enemy to the game by editing `data/enemies.json5`. No recompile needed.

$ARGUMENTS

## Workflow

### 1. Design the Enemy

Decide on:

- **ID** — `snake_case` string, unique in the file (e.g. `"crystal_golem"`)
- **Name** — display name shown in messages
- **Glyph** — single ASCII character for ASCII render mode
- **Color** — `[r, g, b, 255]` RGBA (0–255)
- **Stats** — `hp`, `attack`, `quickness` (100 = normal), `move_speed` (100 = normal)
- **Ability** — optional; see existing types: `web`, `freeze`, `poison_cloud`
- **Depth range** — which floors should it appear on (see `spawn_tables` below)

### 2. Add to `data/enemies.json5`

Open `data/enemies.json5` and add a new entry to the `enemies` array:

```json5
{
  id: "crystal_golem",       // unique snake_case id
  name: "Crystal Golem",
  glyph: "G",
  color: [100, 180, 220, 255],
  hp: 20,
  attack: 7,
  quickness: 70,             // slower than normal (100)
  move_speed: 130,           // slower movement
  // optional ability:
  // ability: { type: "freeze", cooldown: 6, range: 2 },
},
```

### 3. Add to Spawn Tables

Find the `spawn_tables` array in `data/enemies.json5`. Add the enemy ID to the appropriate depth entries. Higher weight = spawns more often.

```json5
// Example: appears on depths 4–8 with moderate weight
{ depth_min: 4, depth_max: 8, entries: [
  // ... existing entries ...
  { id: "crystal_golem", weight: 15 },
]},
```

### 4. Verify (no recompile needed for data changes)

Run a quick type-check to make sure no Odin code was accidentally broken:

```bash
just check
```

Then run the game and descend to the target depth to verify the enemy spawns and behaves correctly:

```bash
CHEATS=true SKIP_TITLE=true FIXED_SEED=42 just run-built
```

Use the cheat menu (Shift+C) → depth jump to reach the target floor quickly.

### 5. If Adding a New Ability Type

If the enemy needs a new `ability.type` not already in the code:

1. Open `src/enemy.odin` and find the ability dispatch logic
2. Add a new case for your ability type
3. Implement the effect
4. Add a test in a `*_test.odin` file
5. Run `just verify`

## Stat Reference

| Stat | Normal | Weak | Strong |
|------|--------|------|--------|
| `quickness` | 100 | 70–80 | 110–130 |
| `move_speed` | 100 | 120–140 (slower) | 70–80 (faster) |
| `hp` | 8–12 | 3–6 | 15–25 |
| `attack` | 3–4 | 1–2 | 6–10 |

## Existing Ability Types

| Type | Effect |
|------|--------|
| `web` | Immobilizes player (range = melee) |
| `freeze` | Freezes player, doubled move cost |
| `poison_cloud` | Applies poison on melee contact |
