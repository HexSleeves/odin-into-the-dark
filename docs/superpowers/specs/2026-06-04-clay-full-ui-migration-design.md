# Clay Full UI Migration Design

Date: 2026-06-04
Repo: `HexSleeves/odin-into-the-dark`
Status: Approved for planning

## Goal

Replace all **screen-space UI** with Clay while keeping **world rendering** on the current renderer.

In scope:
- sidebar HUD
- message log
- minimap
- tooltip
- title screen
- inventory
- crafting
- help
- high scores
- game over
- victory
- cheat menu
- screen-space hints and overlays tied to those surfaces

Out of scope:
- map tile rendering
- item/enemy/player rendering
- particle rendering
- camera math
- world-space effects and animations unless they are purely screen-space UI decorations

## Decisions

1. Clay replaces **all screen-space UI only**.
2. World rendering stays on the existing `Engine_Render_Backend` path.
3. Legacy non-Clay screen-space renderers are **deleted as each screen lands**. No long-lived dual UI trees.
4. `USE_CLAY` remains the migration gate while the conversion is in progress.
5. Engine stays Clay-free. Clay remains game-layer only.
6. No Raylib imports are allowed in Clay game-layer files.

## Current UI Surface Map

Current screen-space UI is spread across:
- `src/render_hud.odin`
- `src/messages.odin`
- `src/render_minimap.odin`
- `src/render_ui.odin`
- `src/cheat_menu.odin`
- `src/render_map.odin` tooltip logic
- `src/render.odin` orchestration

This migration consolidates those surfaces into a single Clay-driven UI pass.

## Target Architecture

### Frame structure

`render_game` becomes:

1. begin render frame
2. clear background
3. render world pass
   - map
   - webs
   - items
   - enemies
   - player
   - particles
4. begin Clay UI frame
5. build the active screen-space UI tree
6. end Clay layout and submit render commands
7. render final non-UI overlays that intentionally stay outside Clay, if any remain
8. render flash / full-screen VFX overlay last
9. end render frame

### Single UI dispatcher

Add a single game-layer UI dispatcher, for example:
- `clay_render_screen_ui(engine, game)`

Responsibilities:
- always render persistent UI surfaces while in gameplay state
- render state-specific overlays based on `game.state`
- own z-ordering of screen-space UI
- centralize future focus, hover, and scroll policy

This dispatcher replaces the current pattern where `render_game` manually calls many independent screen-space renderers.

## File Layout

### Keep
- `src/clay_ui.odin` — Clay lifecycle, per-frame setup, pointer + scroll bridge, text measurement
- `src/clay_renderer.odin` — Clay command translation into engine render primitives

### Add
- `src/clay_theme.odin`
  - colors
  - spacing constants
  - font sizes
  - reusable panel styles
  - shared helper builders for borders, section headers, status rows, etc.

- `src/clay_screen_ui.odin`
  - top-level UI dispatcher
  - state switch for active screens
  - ordering of persistent HUD/messages/minimap/tooltip versus modal overlays

### Split by screen / concern
- `src/clay_hud.odin`
- `src/clay_messages.odin`
- `src/clay_minimap.odin`
- `src/clay_tooltip.odin`
- `src/clay_title.odin`
- `src/clay_inventory.odin`
- `src/clay_crafting.odin`
- `src/clay_help.odin`
- `src/clay_scores.odin`
- `src/clay_game_over.odin`
- `src/clay_victory.odin`
- `src/clay_cheats.odin`

A file may absorb multiple tiny surfaces if they share one lifecycle, but the default is one file per major screen so the code stays bounded.

### Delete progressively
As each Clay screen lands, delete the old renderer immediately:
- `render_hud.odin` sections
- `messages.odin` rendering section
- `render_minimap.odin`
- corresponding sections in `render_ui.odin`
- corresponding sections in `cheat_menu.odin`
- screen-space tooltip rendering in `render_map.odin`

The replacement must be complete before deletion. No stubs.

## UI Composition Model

### Gameplay state

When `game.state == .Playing`, the Clay tree should include:
- HUD sidebar
- message panel
- minimap when enabled
- tooltip when relevant
- contextual gameplay hints that are truly screen-space UI
- cheat overlay only when the state changes to cheats view

### Modal states

When in modal or full-screen UI states, the Clay tree should render the relevant screen overlay:
- title
- inventory
- crafting
- help
- high scores
- game over
- victory
- cheats

The dispatcher decides whether persistent gameplay surfaces remain visible underneath a modal surface. Default rule:
- full-screen menus own the screen and do not preserve gameplay HUD/messages unless the current UX already depends on it
- gameplay-adjacent overlays like tooltip/minimap remain tied to `.Playing`

## Input Model

### Pointer

Use the existing Clay pointer bridge in `src/clay_ui.odin`:
- mouse position from `engine_input_mouse_position`
- primary button state from `engine_input_mouse_button_down(.Left)`
- released state available for click behaviors where needed

### Scroll

Use `engine_input_scroll_delta` to drive:
- scrollable inventory lists
- help text pages if converted to scroll containers
- score lists if needed

### Keyboard

Clay does not replace the game’s action input model. Keyboard navigation remains driven by the existing input managers and action handlers unless a screen explicitly benefits from pointer-first interaction.

Rule:
- keep existing gameplay and menu hotkeys authoritative
- use Clay for layout and hover/click affordances, not as a new input abstraction layer

## Styling Rules

- Reuse the current visual palette where practical so the migration preserves the game’s existing look.
- Shared colors and spacing move into `clay_theme.odin`.
- Use Clay containers for section layout, padding, dividers, and alignment.
- Keep typography sizes aligned with existing UI unless a specific screen needs a deliberate redesign.
- Avoid style drift between screens by routing all common styles through a small helper layer instead of hand-writing constants in each file.

## Per-Screen Expectations

### HUD
- already partially migrated
- becomes the reference style for Clay sections, rows, bars, and bottom-pinned controls

### Messages
- convert log panel into a Clay container pinned to the message region
- preserve current line count and turn-aware message ordering
- no message storage changes; render-only migration

### Minimap
- keep existing minimap tile data and visibility rules
- move screen placement, frame, and panel composition into Clay
- actual minimap cell drawing may still use low-level rectangles emitted through the Clay render path or a dedicated custom child if needed

### Tooltip
- move tooltip panel placement and text wrapping into Clay
- keep current hover detection logic sourced from map/camera state unless that logic is also worth extracting

### Title / Help / Scores / Game Over / Victory
- these are full-screen or centered overlays and should migrate cleanly to Clay panel composition
- preserve existing menu selection semantics and keyboard behavior

### Inventory / Crafting / Cheats
- highest interaction complexity
- preserve selection, highlighted rows, and action prompts
- if pointer support improves UX, it must not break keyboard-first behavior

## Data Flow

The migration is render-layer only.

No changes to:
- save format
- game state ownership
- content manager contracts
- action handlers
- turn sequencing

Clay screen functions read from existing sources:
- `game`
- UI manager state
- message manager state
- score manager state
- content manager when item metadata is needed

Render functions must stay pure with respect to game progression. They may compute display-only derived values but must not mutate gameplay state.

## Error Handling

- Clay init failure remains fatal during app init.
- Screen builders should nil-guard their dependencies and render nothing rather than crashing if a manager is absent.
- No hidden fallbacks to legacy renderers once a screen is migrated.
- Unsupported Clay render command types should remain explicit and visible in code. If a screen depends on a command type, add real support instead of silently hoping it works.

## Performance and Memory Constraints

- No heap churn in the Clay render loop beyond existing frame/temp allocator usage.
- Reuse frame allocator for temporary text conversion.
- Avoid duplicate string formatting when the same text is used multiple times in a frame.
- Prefer small helper builders over large intermediate structures.
- Do not introduce engine-layer dependencies on Clay.

## Deletion Strategy

For each migrated screen:
1. add Clay replacement
2. wire screen through the unified Clay dispatcher
3. verify behavior with `USE_CLAY=true`
4. remove the corresponding legacy screen-space renderer immediately
5. keep non-Clay builds compiling by ensuring `USE_CLAY=false` still has a coherent fallback only for screens not yet migrated

This means the migration should proceed in slices that remain end-to-end complete.

## Recommended Migration Order

1. finish gameplay surfaces first
   - messages
   - minimap
   - tooltip
   - contextual screen-space hints
2. migrate simplest full-screen screens
   - high scores
   - help
   - title
3. migrate outcome screens
   - game over
   - victory
4. migrate complex interactive overlays
   - inventory
   - crafting
   - cheats
5. collapse orchestration and delete final legacy screen-space paths

Rationale:
- gameplay surfaces validate the persistent Clay frame model
- simple centered overlays validate common modal panel helpers
- inventory/crafting/cheats are last because they carry the most interaction detail

## Testing Strategy

### Build coverage
Must remain green for:
- `odin check src/ -define:USE_CLAY=true`
- `odin check src/ -define:USE_CLAY=false`
- `odin test src/ -define:USE_CLAY=true`
- `odin test src/ -define:USE_CLAY=false`
- `just verify`

### Unit coverage
Add or extend tests for:
- Clay screen builders where command counts or specific command shapes can be asserted
- dispatcher behavior by game state
- render command generation for shared helpers where practical
- minimap/message/tooltip data-to-command transformations

### Behavioral checks
For each migrated screen:
- keyboard navigation unchanged
- pointer interaction works if added
- scroll works where added
- non-Clay path still compiles for not-yet-migrated screens
- no legacy renderer for that screen remains after cutover

### Visual QA
Manual checks should confirm:
- alignment and sizing parity or intended improvement
- no overlap with world viewport or message region
- tooltip and minimap layering are correct
- modal overlays fully cover or intentionally preserve underlying UI

## Risks

### 1. Mixed migration state becomes messy
Mitigation:
- one dispatcher
- delete each old screen as soon as its replacement is complete
- do not keep two layout systems for the same surface

### 2. Inventory/crafting interaction regressions
Mitigation:
- migrate these last
- preserve existing action semantics first, pointer enhancements second

### 3. Minimap and tooltip do not fit a pure layout model cleanly
Mitigation:
- let Clay own container placement and clipping
- keep low-level draw logic focused inside the Clay-driven surface file if needed

### 4. UI styling drifts across files
Mitigation:
- central `clay_theme.odin`
- shared helpers for common panels, rows, headers, dividers, bars

## Success Criteria

The migration is complete when:
- every screen-space UI surface is rendered through Clay
- world rendering remains on the current renderer
- no legacy screen-space renderer remains for migrated surfaces
- `USE_CLAY=true` and `USE_CLAY=false` both compile during the migration window
- all tests and verification commands pass
- player-visible behavior is preserved unless an intentional UI improvement is specified

## Non-Goals

- rewriting gameplay logic
- redesigning the game’s visual identity from scratch
- moving engine abstractions into Clay
- replacing world rendering with Clay
- introducing a second input architecture
