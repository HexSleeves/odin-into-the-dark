# Into the Depths — UI/HUD Redesign

**Date:** 2026-06-06
**Direction:** A — Dense Tech Readout (Cogmind-style)
**Scope:** Full UI (gameplay HUD + message log + all overlays + tooltip + minimap) **plus** light-glow polish.
**Palette:** "Lamplit Mine"

---

## 1. Goal

Replace the current flat terminal HUD with a cohesive, modern roguelite "dense tech readout": bordered, header-labeled readout panels, segmented bars, a disciplined warm cave palette. Treasure-gold is reserved as a meaningful accent. The mine's light radius becomes an ambient fuel gauge (warm lamp → ember as oil drops). Engine layer (`src/engine/`) is untouched; all work is in `src/ui/` and `src/render/`.

## 2. Design tokens

### 2.1 Palette — rewrite `src/ui/ui_theme.odin` SB_* constants

Keep the existing constant **names** (so call sites don't churn) but retune RGB to the Lamplit Mine palette. Add a few new constants where the new layout needs them.

| Constant | New RGB | Hex | Role |
|---|---|---|---|
| `SB_BG` | 11,10,15 | `#0B0A0F` | screen void / sidebar base |
| `SB_PANEL` *(new)* | 21,19,28 | `#15131C` | panel background |
| `SB_DIVIDER` → reuse as border | 58,53,80 | `#3A3550` | panel border / divider |
| `SB_TITLE` | 245,182,56 | `#F5B638` | gold title/treasure accent |
| `SB_HEADER` | 138,130,112 | `#8A8270` | panel header labels |
| `SB_TEXT` | 232,223,200 | `#E8DFC8` | primary text |
| `SB_DIM` | 138,130,112 *(dimmer variant)* | `#5A5648` | passive/secondary |
| `SB_HP_FG` | 111,191,115 | `#6FBF73` | HP healthy |
| `SB_HP_LOW` | 216,69,62 | `#D8453E` | HP danger |
| `SB_HP_BG` | 30,20,20 | bar trough | HP empty cell |
| `SB_PICK_OK` | 232,163,61 | `#E8A33D` | pick healthy (amber, not green — distinct from HP) |
| `SB_PICK_WARN` | 245,182,56 | warn | |
| `SB_PICK_CRIT` | 216,69,62 | crit | |
| `SB_PICK_BG` | 36,31,16 | bar trough | |
| `SB_OIL` / lamp | 255,158,61 | `#FF9E3D` | light/oil/fuel |
| `SB_LAMP_LOW` *(new)* | 122,74,28 | `#7A4A1C` | ember (low fuel) |
| `SB_WPN` | 255,158,61 | warm | weapon |
| `SB_ARM` | 138,158,168 | cool steel | armor |
| `SB_HLM` | 200,180,120 | brass | helmet |
| `SB_POISON` | 115,200,40 | keep | poison |
| `SB_BOSS` | 216,69,62 | `#D8453E` | boss |
| `SB_KEY` | 138,130,112 | dim | control keys (de-emphasized) |

Rule: **gold (`SB_TITLE`) only for treasure/loot/title.** Quests use lamp/amber, not gold, to avoid diluting it.

### 2.2 Spacing/fonts — `src/render/clay_theme.odin`

Keep `CLAY_FONT_SMALL=12 / BODY=13 / TITLE=14` and `CLAY_SPACE_*`. Add panel-internal pad constant `CLAY_PANEL_PAD :: u16(6)`. Font unchanged; hierarchy via size+color+weight. Digits already monospace (tabular).

## 3. Panel system — new helper in `clay_theme.odin`

Cogmind readout panel = bordered box with a small inset uppercase header.

```
clay_panel :: proc(id: string, header: string, body: proc())  // or inline macro-style block
```

Implementation: a Clay element with `backgroundColor = SB_PANEL`, `border = {width = {all=1}, color = SB_DIVIDER}`, `cornerRadius` small (2), `padding = CLAY_PANEL_PAD`, `layoutDirection = .TopToBottom`, `childGap = CLAY_SPACE_XS`. Header rendered as first child: `clay_text(header, CLAY_FONT_SMALL, SB_HEADER)` with letter-spacing feel (uppercased text). Clay borders are already supported via `clay_render_border` (`clay_renderer.odin:108`).

Because Odin Clay uses the `if clay.UI(...)( decl ) { ... }` block idiom (not a callback), the practical form is an **open/begin** style: a `clay_panel_begin(id, header) -> bool` returning the `clay.UI` block condition, used as `if clay_panel_begin(...) { ...children... }`. Mirror the existing `clay.UI` block pattern rather than passing a `proc`.

## 4. Segmented bar — replace `clay_bar`

Add `clay_bar_segmented(id, ratio, segments, height, bg, fg)`: renders `segments` discrete cells (default 10) in a LeftToRight row with 1px gaps; fill `round(ratio*segments)` cells `fg`, rest `bg`. Keep old `clay_bar` for boss/continuous if needed. HP/PICK use segmented.

## 5. Gameplay sidebar HUD — rewrite `clay_render_hud` (`clay_hud.odin`)

Replace the flat divider-separated list with stacked panels (sidebar stays 256px, `SB_BG` base, panels are `SB_PANEL`):

1. Title `INTO THE DEPTHS` centered, `SB_TITLE`, gold. (no panel)
2. **VITALS** panel — HP row + segmented bar; PICK row + segmented bar (or `BROKEN`); ATK speed word (color by `effective_attack_cost`, thresholds unchanged).
3. **EXPEDITION** panel — DEPTH/`SURFACE` + TURN; POS; LIGHT (lamp color) + fuel/items; KILLS + NEAR; ORE/treasure count (gold) if tracked.
4. **QUEST** panel — objective text (lamp/amber `▸`), only if `game.quest != .Complete`.
5. **GEAR** panel — WPN/ARM/HLM rows, `---` dim when empty, colors `SB_WPN/ARM/HLM`.
6. **STATUS** panel — OIL/POISON/BURNING/FROZEN with turn counts, only when `has_status`.
7. **BOSS** panel — name + HP bar, only when a boss is alive.
8. spacer-grow, then **CONTROLS** panel at the bottom, dim keys.

Logic/conditionals preserved exactly from the current proc — only the visual wrapping and bar style change. Quest color moves from hardcoded `{255,215,0}` to a named lamp constant.

## 6. Message log — `clay_messages.odin`

Wrap the 7-line buffer in a **LOG** readout panel (border + `SB_PANEL` + header) spanning the bottom region (full width below map, height = `MSG_REGION_HEIGHT` 130px). Newest line `SB_TEXT`, older lines step toward `SB_DIM`. Keep buffer size and ordering.

## 7. Overlays — `clay_overlays.odin`, `clay_events.odin`, `clay_dialogue.odin`

Re-skin every overlay to the panel system + palette. `clay_overlay_decl` keeps the full-screen dim backdrop; centered content becomes a bordered `SB_PANEL` with gold header. Affected: title (embers recolored to lamp `SB_OIL`), inventory, crafting, help, scores, game-over, victory, cheats, shrine, merchant, dialogue. Text helpers `clay_overlay_text`/`clay_title_text` retargeted to palette. No layout/flow changes — visual skin only.

## 8. Tooltip + minimap

- `clay_tooltip.odin`: tooltip box gets `SB_PANEL` bg + `SB_DIVIDER` border; name `SB_TEXT`, HP colored by ratio. Mining/anvil/fountain hint banners use lamp/amber.
- `clay_minimap.odin`: recolor to palette — player gold (`SB_TITLE`), enemy/boss `SB_BOSS`, NPC green, treasure pip gold; explored dim toward `SB_DIM`, unseen `SB_BG`.

## 9. Map / light polish — `render_map.odin`

Single behavioral change: the light glow tint interpolates lamp→ember by remaining fuel. When `game.light_boost_turns > 0`, lerp glow toward `SB_OIL` (`#FF9E3D`); as fuel approaches 0 lerp toward `SB_LAMP_LOW` (`#7A4A1C`); with no boost, baseline current behavior. Tile base palette (`base_tile_color`) nudged warmer to sit in the Lamplit Mine field — small RGB tweaks only, no structural change. Sprites remain disabled (out of scope).

## 10. Component boundaries

- **Tokens** (`ui_theme.odin`, `clay_theme.odin`) — pure constants + 2 helpers (`clay_panel_begin`, `clay_bar_segmented`). Depend on nothing game-side.
- **HUD** (`clay_hud.odin`) — consumes tokens + panel/bar helpers + `Game` state. No new deps.
- **Overlays / messages / tooltip / minimap** — consume the same helpers.
- **Light** (`render_map.odin`) — consumes `SB_OIL`/`SB_LAMP_LOW` + `game.light_boost_turns`.

Each is independently viewable via `just run` and unchanged in interface to its callers (same proc signatures for the top-level `clay_render_*`).

## 11. Testing

- `just verify` (tests + flag matrix + check + build) is the gate.
- Existing `test/render/render_handlers_test.odin` must still pass.
- New helpers (`clay_bar_segmented` cell math) are pure → add a unit test for fill-count rounding (e.g. ratio 0.5 of 10 segments → 5 filled; 0 → 0; 1 → 10; clamp >1).
- Visual confirmation via `just run` against the start state in the reference screenshot.
- `just fmt` before commit.

## 12. Out of scope

- Sprite/tileset art (sprites stay disabled).
- New gameplay/stats, screen-resolution/grid changes, font replacement.
- Animation/juice beyond the light-glow lerp (chosen direction A is density-first, not juice-first; bar-drain tweening can be a later pass).

## 13. Risks

- Clay border rendering at 1px on every panel adds draw commands; arena is 8MB — fine, but watch command count.
- Segmented bars with many cells + per-panel borders could crowd the 256px sidebar; tune segment count (start 10) and pad.
- Quest color de-gold may need sign-off (kept amber per "gold = treasure only" rule).
