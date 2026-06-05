# New Item — Add a Data-Driven Item

Add a new item to the game by editing `data/items.json5`. No recompile needed — unless the effect type is new.

$ARGUMENTS

## Workflow

### 1. Design the Item

Decide on:

- **ID** — `snake_case` string, unique in the file (e.g. `"smoke_bomb"`)
- **Name** — display name
- **Glyph** — single ASCII character
- **Color** — `[r, g, b, 255]` RGBA (0–255)
- **Stack limit** — how many can be carried (1 = no stacking, 5 = generous)
- **Effect type** — see existing types below; new types need code changes
- **Spawn weight** — relative spawn probability (higher = more common)
- **Depth range** (optional) — depth-gated spawn weights

### 2. Add to `data/items.json5`

Open `data/items.json5` and add a new entry to the `items` array:

```json5
{
  id: "smoke_bomb",
  name: "Smoke Bomb",
  glyph: "*",
  color: [80, 80, 80, 255],
  stack_limit: 2,
  effect: {
    type: "teleport",    // must match a handler in src/data.odin
    value: 0,
  },
},
```

### 3. Add to Spawn Weights

Find the `spawn_weights` array and add your item:

```json5
{ id: "smoke_bomb", weight: 10 },
```

Or add depth-gated entries if the item should only appear at certain depths.

### 4. Verify (data-only change)

```bash
just check
```

Test in-game:

```bash
CHEATS=true SKIP_TITLE=true just run-built
```

### 5. If Adding a New Effect Type

New effect types require an Odin code change in `src/data.odin` inside `apply_item_effect`:

```odin
case "teleport":
    // implement teleport logic here
    game_teleport_player(game)
```

After adding the handler:

1. Add a regression test in `src/item_use_regression_test.odin`
2. Run `just verify`

## Existing Effect Types

| Type | `value` meaning | Notes |
|------|----------------|-------|
| `heal` | HP restored | Capped at max HP |
| `cure_poison` | — (value unused) | Clears poison status |
| `light_boost` | Radius added | Permanent until next use |
| `timed_light_boost` | Radius added | Lasts `duration` turns |
| `strength_boost` | Attack added | Temporary |
| `armor_boost` | Defense added | Check `src/data.odin` for duration |

## Glyph Conventions

| Glyph | Meaning |
|-------|---------|
| `!` | Potions / consumables |
| `+` | Medical / bandages |
| `t` | Tools / torches |
| `o` | Oils / liquids |
| `[` `]` | Armor |
| `)` | Weapons |
| `$` | Gold / valuables |
| `?` | Scrolls / unknown |
