# Into the Depths — Next Steps

## What shipped this session

### Engine (parity with karl2d)

| Feature | Details |
|---|---|
| `Tile_State #packed` | 8→6 bytes/cell, eliminates implicit padding |
| Cell limits 4096→8192 | Tile state + bool grid; supports up to ~90×90 maps |
| Frame arena allocator | `engine_frame_allocator(engine)` resets each frame; zero-cost scratch allocation |
| Audio backend expansion | `stop`, `set_volume`, `set_master_volume`, `play_looped`, `update` vtable procs |
| Audio loop replay | `audio_manager_update` in game loop drives looping sounds without rl.Music overhead |

### Game improvements

| Feature | Details |
|---|---|
| 3-tier ambient BGM | `Music_Tier`: Shallow (depth 1–3), Mid (4–6), Deep (7+); procedural additive-sine drones |
| Depth-reactive music | `music_set_tier_by_depth` called on descent; crossfades between tiers |
| Master volume ramp | Volume increases 0.6→1.0 with depth (0.02/floor) |
| Volume settings | `[` / `]` keys adjust volume live; `ITD_MASTER_VOLUME` / `ITD_MUSIC_VOLUME` in `.env` |
| `Game_Config` struct | `master_volume`, `music_volume`; loaded from `.env`, applied at startup |
| Dirty tile rendering | `render_map` early-exits on idle frames (no FOV change + camera stable = 0 tile draws) |
| Audio controls | `audio_stop_sfx`, `audio_set_sfx_volume`, `audio_set_master_volume`, `audio_play_sfx_looped` |

---

## Next steps (prioritized)

### Priority 1 — Core gameplay depth

**1.1 Enemy variety and AI**
- Add 2–3 more enemy behaviors: ranged attacker (throws rocks), berserker (charges in straight line), lurker (waits until adjacent)
- Enemy abilities from `data/enemies.json5` `ability.type` are parsed but most do nothing — wire them
- Boss rooms at depths 5, 10, 15

**1.2 Items and equipment**
- Equipment slots (armor, weapon, amulet) are in the data but effects are minimal
- Add: weapon swing animation (VFX flash), armor damage reduction in combat formula
- Consumables: potions have effects defined in JSON but need wiring

**1.3 Status effects system**
- Poisoned, Burning, Frozen — store as bitset on Player/Enemy
- Applied by certain enemies/items; proc each turn in `advance_turn`
- Show status icons in HUD

### Priority 2 — Game feel

**2.1 Visual feedback**
- Screen shake on taking damage (VFX manager already has flash — add shake)
- Particle burst on enemy death (particle manager already exists)
- Death animation for enemies before removal

**2.2 Sound design**
- Add level-up / boss-kill sound effects to the generated audio palette
- Ambient sound per tile type (water tiles: play Water sfx with low frequency loop)
- Different footstep sounds on different floor types

**2.3 Camera polish**
- Smooth camera lerp is already in — tune `LERP_SPEED` constant
- Add subtle camera zoom-in on boss encounter

### Priority 3 — Progression and content

**3.1 Difficulty scaling**
- Enemy stats scale with depth (already partially done via spawn tables)
- Loot quality curve: better items spawn deeper
- Hunger/torch mechanic: light radius decreases over time without torches

**3.2 Map generation variety**
- Add a "cavern" generator variant (cellular automata) for mid-depths
- Special rooms: treasure vault, monster den, fountain (restore HP)
- Secret doors (hidden walls that can be found with search action)

**3.3 Score and achievements**
- Score system exists (`scores.odin`) but only tracks runs
- Add: kill count, items found, floors cleared to score breakdown
- High score display on title screen

### Priority 4 — Engine maturity

**4.1 Adopt frame allocator**
- Identify per-frame scratch allocations still using `context.allocator`
- Port UI text format strings to `engine_frame_allocator`
- Port FOV/pathfinding temporary buffers

**4.2 Render texture map layer**
- Current dirty-tile system skips draws on idle frames, but camera scroll still redraws
- For smoother scrolling: render the full map to an `rl.RenderTexture2D` once
- On player action: redraw dirty tiles into the texture; each frame: blit texture at camera offset
- Reduces per-scroll work from ~3200 draw calls to 1

**4.3 Audio streaming for music**
- Current BGM is synthesized sine waves (~344KB/track loaded at startup)
- For longer, richer music: embed actual OGG files with `#load` and stream via `rl.LoadMusicStreamFromMemory`
- `vendor:stb/vorbis` is available in Odin

**4.4 `#load` for embedded assets**
- Currently all assets are runtime file reads
- Embed with `#load` for single-executable shipping: sprites JSON, character PNGs
- Implement `data_load_all_embedded` path using `load_json5_from_bytes` (already exists)

### Priority 5 — Shipping

**5.1 Title screen polish**
- Add animated title (subtle particle drift or waving effect)
- Show high scores on title
- Key hints for new players

**5.2 Save system hardening**
- Current save uses JSON with versioning (V2/V3) — add migration for new fields
- Auto-save on each floor descent (already hooked)
- Save slot selection for multiple runs

**5.3 Platform**
- macOS: bundle into `.app` with proper Info.plist
- Web: Odin WASM target (requires replacing `core:os` I/O with WASM-safe storage)
- The storage abstraction (`Engine_File_System`) is already in place for this

---

## Immediate actionable items (next session)

1. `just run` and play-test the new audio/music changes
2. Wire enemy abilities from JSON (`ability.type` in `enemies.json5`)  
3. Add particle burst on enemy death (particle_manager already available)
4. Add screen shake to `vfx_manager` (extend current flash impl)
5. Port 2–3 remaining `context.allocator` scratch uses to `engine_frame_allocator`
