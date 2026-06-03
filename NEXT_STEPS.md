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
| Energy_Actor struct | `turn_manager.odin` — reusable `{energy, quickness, move_speed}` for future actors |
| Camera lerp fix | Minimum step ±1px guarantees convergence; int truncation was stalling the lerp |

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
| Burning status | Fire_Vent (depth 4+) inflicts 4 turns burning (-1 HP/turn); orange HUD indicator |
| Antidote item | `data/items.json5`; cure_poison effect; spawns in world |
| Fountain tiles | Appears in rooms at depth 2+; restores up to 5 HP on step |
| items_found counter | Tracked per run; saved in v4 format; shown in score table |
| Score v4 | Includes items_found; save migrates cleanly from v3/v2 |
| Combat flash | Yellow flash on every player attack; big flash+shake on boss kill |
| Boss_Kill sound | Triumphant 440Hz tone on boss death; special kill message |
| boss_killed_this_turn | Flag set by combat.odin and enemy.odin for future use |
| HUD: poison + kills | Poison turns displayed; kills shown in stats line |
| Score display | Items column added to score table rows |
| 3 new enemy types | cave_bat (fast QN=150), stone_thrower (ranged), mine_lurker (lurker) |
| Ranged enemy AI | `ranged_shoot` ability: fires at player in LOS within range |
| Lurker AI | Stays still until adjacent, then attacks; low QN means fewer actions |
| Depth-based loot | `item_spawn_tables` in items.json5; better gear at depth 6+ |
| Energy turn system | Qud-style AP scheduling: `quickness*10` AP/round, carry-over debt, action costs |
| Weapon speed HUD | "ATK: Normal/Fast/Slow/Very Slow" color-coded indicator |
| Mine Dagger | Fast weapon (action_cost 700, +1 ATK) — spawns depth 3+ |
| Greatsword | Heavy weapon (action_cost 2100, +7 ATK) — spawns depth 6+ |
| Monster den room | 25% chance at depth 3+; 3-5 extra enemies + guaranteed item |
| Passive light drain | Every 30 rounds (depth 3+) without light source, radius -1 (min 2) |
| Fire_Vent tile | New hazard tile spawns depth 4+; -2 HP + burning on step |

---

## Remaining work (prioritized)

### Priority 1 — Content

**1.1 Frozen status effect**
- Deep_watcher could inflict frozen (slows player move_speed or skips a turn)
- Complement to poison (DoT) and burning (DoT + light) with a control effect
- HUD indicator in cyan/blue

**1.2 Treasure vault room**
- Locked door tile blocks entry; key item spawns elsewhere on the floor
- Guaranteed rare item inside
- Currently only Fountain, Anvil, and Monster Den as special rooms

### Priority 2 — Game feel

**2.1 Better footstep sounds**
- Different sfx for Water, Stone, Rubble tile types
- Currently all tiles use the same Footstep sound

**2.2 Depth-appropriate camera zoom**
- Zoom in slightly on boss encounters
- Currently camera stays at fixed zoom

### Priority 3 — Progression

**3.1 Victory condition improvements**
- Currently victory = reach depth 12
- Add a proper ending sequence / score breakdown screen with full stats

### Priority 4 — Engine maturity

**4.1 Frame allocator adoption**
- `engine_frame_allocator` exists but no game code uses it yet

**4.2 `#load` for embedded assets**
- Assets currently loaded from disk at runtime
- `#load("data/enemies.json5")` at compile time → single-executable shipping
- `load_json5_from_bytes` already exists for this path

**4.3 Render texture map (deferred)**
- Attempted and reverted — camera lerp and render texture caching are incompatible
- Revisit only after switching to snap camera or world-space render texture

### Priority 5 — Shipping

**5.1 Title screen polish**
- Subtle particle ambient effect, animated title glow
- Show last 3 scores directly on title

**5.2 macOS bundle**
- Bundle into `.app` with Info.plist for Gatekeeper compliance

**5.3 WASM / web target**
- Odin WASM target requires replacing `core:os` file I/O
- `Engine_File_System` abstraction is already in place

---

## Immediate actionable items

1. **Frozen status effect** — deep_watcher freeze, completes status triangle
2. **Treasure vault room** — locked door + key, guaranteed rare item
3. **Tile-type footstep sounds** — Water splash, Rubble crunch, Stone step
4. **Victory screen score breakdown** — proper ending with full stats
