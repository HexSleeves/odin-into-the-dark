# Into the Depths — Next Steps

## What shipped across all sessions

### Engine

| Feature | Details |
|---|---|
| `Tile_State #packed` | 8→6 bytes/cell, eliminates implicit padding |
| Cell limits 4096→8192 | Tile state + bool grid; supports ~90×90 maps |
| Frame arena allocator | `engine_frame_allocator(engine)` resets each frame |
| Audio backend expansion | `stop`, `set_volume`, `set_master_volume`, `play_looped`, `update` vtable procs |
| Screen shake | `vfx_manager_shake(vfx, amount)`, decays per tick, applied to render origin |
| Fix: music `encode_wav` | `for i, s in []i16` infers `i` as `i16` → overflow. Fixed with `mem.copy`. |
| Fix: render flicker | Dirty-tile early-return wrong for immediate-mode Raylib. Removed. |
| **Energy_Actor struct** | `turn_manager.odin` — reusable `{energy, quickness, move_speed}` for future actors |

### Game

| Feature | Details |
|---|---|
| 3-tier ambient BGM | Shallow/Mid/Deep drones; crossfades on descent |
| Volume settings | `[` / `]` live adjustment; `.env` config |
| Death/hit particles | Enemy death burst at enemy tile; player damage hit particles |
| Heal particles | Green burst on potion/oil use |
| Screen shake on damage | Player taking damage triggers shake + flash |
| hp_before fix | Gas_Vent damage now correctly triggers shake/particles |
| Poison status | Gas_Vent inflicts 5 turns of poison (1 HP/turn); HUD indicator; Antidote cures it |
| Antidote item | `data/items.json5`; cure_poison effect; spawns in world |
| Fountain tiles | Appears in rooms at depth 2+; restores up to 5 HP on step |
| items_found counter | Tracked per run; saved in v4 format; shown in score table |
| Score v4 | Includes items_found; save migrates cleanly from v3/v2 |
| Combat flash | Yellow flash on every player attack; big flash+shake on boss kill |
| Boss_Kill sound | Triumphant 440Hz tone on boss death; special kill message |
| boss_killed_this_turn | Flag set by combat.odin and enemy.odin for future use |
| HUD: poison + kills | Poison turns displayed; kills shown in stats line |
| Score display | Items column added to score table rows |
| **3 new enemy types** | cave_bat (fast/berserker via QN=150), stone_thrower (ranged), mine_lurker (lurker) |
| **Ranged enemy AI** | `ranged_shoot` ability: fires at player in LOS within range, deducts cooldown |
| **Lurker AI** | Stays still until adjacent, then attacks; low QN (80) means it acts less often |
| **Depth-based loot** | `item_spawn_tables` in items.json5; better gear at depth 6+ |
| **Energy turn system** | Qud-style AP scheduling: `quickness*10` AP/round, carry-over debt, action costs |
| **Weapon speed HUD** | "ATK: Normal/Fast/Slow/Very Slow" replaces raw AP number |
| **action_cost on items** | Weapons carry AP cost; pickaxes slow (1100-1200), daggers fast (≤700) |
| **Enemy speed variety** | Per-enemy quickness + move_speed in data; shadow_stalker QN=130, deep_watcher QN=80 |

---

## Remaining work (prioritized)

### Priority 1 — Content (high impact, playable difference)

**1.1 Status effects depth**
- Burning (from torch trap / fire enemy) and Frozen (from deep_watcher?) not yet added
- Enemies could inflict status: deep_watcher freezes, toxic_spore poisons (already done)
- Show status as small colored glyphs in HUD rather than text

**1.2 More special rooms**
- Monster den: cluster of enemies + better loot, flag spawned room as "cleared"
- Treasure vault: locked door tile, key item somewhere on floor, guaranteed rare item inside
- Currently only Fountain and Anvil as special rooms

**1.3 More weapons**
- Dagger (action_cost: 700, low damage) would make the speed system immediately tangible
- Greatsword (action_cost: 2100, high damage) as a late-game weapon
- Currently only pickaxes exist as weapons — the ATK speed display has nothing to compare against

### Priority 2 — Game feel

**2.1 Render texture map layer (performance)**
- Camera scroll still redraws ~3200 tiles per frame
- Approach: `rl.RenderTexture2D` for the map; redraw only when dirty; blit at camera offset
- Saves 99% of tile draw calls during scrolling

**2.2 Better footstep sounds**
- Different sfx for Water, Stone, Rubble tile types
- Currently all tiles use the same Footstep sound

**2.3 Depth-appropriate camera zoom**
- Zoom in slightly on boss encounters (screen shake already wired)
- Currently camera stays at fixed zoom

### Priority 3 — Progression

**3.1 Hunger / resource drain**
- Light radius decreases slowly without torches/lanterns
- Adds urgency and makes the lantern_oil items feel meaningful
- Simple: decrement `light_boost_turns` passively each round if no active light item equipped

**3.2 Victory condition improvements**
- Currently victory = reach depth 10 and kill abyssal lord
- Add a proper ending sequence / score breakdown screen

**3.3 Dagger / weapon variety**
- See 1.3 — mentioned here because it unlocks the full AP speed system feel

### Priority 4 — Engine maturity

**4.1 Frame allocator adoption**
- `engine_frame_allocator` exists but no game code uses it yet
- `fmt.ctprintf` / `fmt.tprintf` calls use `context.temp_allocator` which is fine but not explicit

**4.2 `#load` for embedded assets**
- Assets currently loaded from disk at runtime
- `#load("data/enemies.json5")` at compile time → single-executable shipping
- `load_json5_from_bytes` already exists for this path

### Priority 5 — Shipping

**5.1 Title screen polish**
- Add subtle particle ambient effect, animated title glow
- Show last 3 scores directly on title (without navigating to High Scores screen)

**5.2 macOS bundle**
- Bundle into `.app` with Info.plist for Gatekeeper compliance

**5.3 WASM / web target**
- Odin WASM target requires replacing `core:os` file I/O
- `Engine_File_System` abstraction is already in place for this path

---

## Immediate actionable items (ordered by impact)

1. **Add dagger + greatsword to items.json5** — makes the ATK speed system immediately tangible; pure data change
2. **Monster den special room** — high gameplay impact, generation code already has the hook
3. **Render texture map** — biggest performance win; fixes frame-rate during scroll
4. **Burning status effect** — completes the status triangle (poison ✓, freeze pending, burn pending)
5. **Passive light drain** — makes torch/lantern management meaningful without major code changes
