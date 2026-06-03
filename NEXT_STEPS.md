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

### Game
| Feature | Details |
|---|---|
| 3-tier ambient BGM | Shallow/Mid/Deep drones; crossfades on descent |
| Volume settings | `[` / `]` live adjustment; `.env` config |
| Death/hit particles | Enemy death burst at enemy tile; player damage hit particles |
| Heal particles | Green burst on potion/oil use |
| Screen shake on damage | Player taking damage triggers shake + flash |
| hp_before fix | Gas_Vent damage now correctly triggers shake/particles |
| **Poison status** | Gas_Vent inflicts 5 turns of poison (1 HP/turn); HUD indicator; Antidote cures it |
| **Antidote item** | `data/items.json5`; cure_poison effect; spawns in world |
| **Fountain tiles** | Appears in rooms at depth 2+; restores up to 5 HP on step |
| **items_found counter** | Tracked per run; saved in v4 format; shown in score table |
| **Score v4** | Includes items_found; save migrates cleanly from v3/v2 |
| **Combat flash** | Yellow flash on every player attack; big flash+shake on boss kill |
| **Boss_Kill sound** | Triumphant 440Hz tone on boss death; special kill message |
| **boss_killed_this_turn** | Flag set by combat.odin and enemy.odin for future use |
| **HUD: poison + kills** | Poison turns displayed; kills shown in stats line |
| **Score display** | Items column added to score table rows |

---

## Remaining work (prioritized)

### Priority 1 — Still missing

**1.1 Status effects depth**
- Burning/Frozen status not yet added
- Enemies could inflict status effects (deep_watcher could freeze, etc.)
- Show status icons (small colored glyphs) rather than text in HUD

**1.2 Enemy AI depth**
- Ranged attacker AI (enemy throws projectile, doesn't need to be adjacent)
- Berserker AI (charges in straight line toward player)
- Lurker AI (stays still until adjacent, then attacks)
- Currently all enemies chase or wander — more behavioral variety needed

**1.3 More special rooms**
- Monster den (extra enemies + better loot)
- Treasure vault (locked room with guaranteed good item)
- Currently only Fountain and Anvil as special rooms

### Priority 2 — Game feel

**2.1 Render texture map layer (performance)**
- Camera scroll still redraws ~3200 tiles per frame
- Approach: `rl.RenderTexture2D` for the map; redraw only when dirty; blit at camera offset
- Saves 99% of tile draw calls during scrolling

**2.2 Better footstep sounds**
- Different sfx on Water, Stone, Rubble tile types
- Currently all tiles use the same Footstep sound

**2.3 Depth-appropriate camera zoom**
- Zoom in slightly on boss encounters
- Currently camera stays at fixed zoom

### Priority 3 — Progression

**3.1 Loot scaling by depth**
- Better items should appear more frequently at deeper depths
- Currently all items have equal spawn probability regardless of depth
- `content_manager_pick_item_def` could filter by depth

**3.2 Hunger / resource drain**
- Light radius decreases slowly without torches
- Adds urgency and resource management

**3.3 Victory condition improvements**
- Currently victory = reach depth 10 and kill abyssal lord
- Add a proper ending sequence / victory screen with full score breakdown

### Priority 4 — Engine maturity

**4.1 Frame allocator adoption**
- `engine_frame_allocator` exists but no game code uses it yet
- `fmt.ctprintf` + `fmt.tprintf` calls allocate temp memory via `context.temp_allocator`
- These are fine as-is (Raylib's temp allocator), but explicit frame arena would be cleaner

**4.2 Render texture map (see 2.1)**

**4.3 `#load` for embedded assets**
- Assets currently loaded from disk at runtime
- `#load("data/enemies.json5")` at compile time → single-executable shipping
- `load_json5_from_bytes` already exists for this path

### Priority 5 — Shipping

**5.1 Title screen polish**
- Currently static text + menu
- Add: subtle particle ambient effect, animated title glow
- Show last 3 scores directly on title (without going to High Scores screen)

**5.2 macOS bundle**
- Bundle into `.app` with Info.plist for Gatekeeper compliance

**5.3 WASM / web target**
- Odin WASM target requires replacing `core:os` file I/O
- `Engine_File_System` abstraction is already in place for this path

---

## Immediate actionable items

1. `just run` and play-test all new features (poison, fountain, boss kill, combat flash)
2. Render texture map layer — biggest remaining performance win
3. Loot scaling by depth (data-only change, no new procs needed)
4. Ranged attacker AI (new behavior in `enemy.odin`)
5. Title screen: show 3 recent scores inline
