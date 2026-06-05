# Clay Full UI Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every screen-space UI surface with Clay while keeping world rendering on the existing engine renderer.

**Architecture:** Keep the existing world pass in `render_game`, then run one Clay UI pass that dispatches by `game.state` and composes persistent gameplay UI plus modal overlays. Delete each legacy screen-space renderer as soon as its Clay replacement is complete so there is only one UI implementation per surface.

**Tech Stack:** Odin 2026-05, vendored Clay Odin bindings, existing `Engine_Render_Backend`, existing input/UI/content/message/score managers, `core:testing`, `just`.

---

## File Structure

### New files
- `src/clay_theme.odin` — shared Clay colors, spacing, font sizes, borders, section helpers
- `src/clay_screen_ui.odin` — top-level Clay screen dispatcher and gameplay/modal composition
- `src/clay_messages.odin` — Clay message panel
- `src/clay_minimap.odin` — Clay minimap panel and minimap cell rendering helpers
- `src/clay_tooltip.odin` — Clay tooltip panel
- `src/clay_title.odin` — Clay title screen
- `src/clay_help.odin` — Clay help screen
- `src/clay_scores.odin` — Clay high scores screen
- `src/clay_game_over.odin` — Clay game-over overlay
- `src/clay_victory.odin` — Clay victory overlay
- `src/clay_inventory.odin` — Clay inventory overlay
- `src/clay_crafting.odin` — Clay crafting overlay
- `src/clay_cheats.odin` — Clay cheats overlay

### Existing files to modify
- `src/render.odin` — replace per-screen UI calls with one Clay dispatcher call
- `src/clay_hud.odin` — route through shared theme helpers and remove temporary legacy coexistence assumptions
- `src/clay_ui_test.odin` — extend Clay command tests
- `src/render_map.odin` — remove legacy tooltip rendering after Clay tooltip lands
- `src/render_hud.odin` — remove legacy contextual hint rendering once Clay gameplay overlays absorb it
- `src/messages.odin` — remove render path after Clay message panel lands; keep storage helpers only if still useful
- `src/render_minimap.odin` — delete after Clay minimap lands
- `src/render_ui.odin` — remove title/help/scores/inventory/crafting/game over/victory renderers as replacements land
- `src/cheat_menu.odin` — remove legacy cheat render procedure once Clay cheats overlay lands; keep input/state logic
- `src/render_handlers_test.odin` — update function-existence assertions to the new dispatcher/surface entrypoints
- `justfile` — keep Clay verification commands aligned with migrated surfaces if new focused test recipes help
- `AGENTS.md` — final cleanup note if file ownership changes materially

### Existing files intentionally kept unchanged in behavior
- `src/input.odin` — action semantics remain authoritative
- `src/game_app.odin` — Clay lifecycle already initialized; only revisit if dispatcher requirements change
- `src/messages.odin` add/clear logic — render-layer migration only
- `src/types.odin`, `src/data.odin`, `src/saveload.odin` — no data model or persistence change

---

### Task 1: Establish the unified Clay screen dispatcher and theme layer

**Files:**
- Create: `src/clay_theme.odin`
- Create: `src/clay_screen_ui.odin`
- Modify: `src/render.odin`
- Modify: `src/clay_hud.odin`
- Test: `src/clay_ui_test.odin`

- [ ] **Step 1: Write the failing dispatcher test**

```odin
@(test)
clay_screen_ui_renders_hud_for_playing_state :: proc(t: ^testing.T) {
	state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input = eng.engine_input_backend_nil(),
		render = clay_test_render_backend(&state),
	}
	game := game_init(content_manager_make())
	defer game_destroy(game)
	game.state = .Playing

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()

	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, commands.length > 0)
	testing.expect(t, state.text_count > 0)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: FAIL because `clay_render_screen_ui` and/or the shared theme helpers do not exist yet.

- [ ] **Step 3: Add the shared theme file**

```odin
package main

import eng "./engine"
import clay "./vendor/clay"

when USE_CLAY {
	CLAY_SPACE_1 :: f32(4)
	CLAY_SPACE_2 :: f32(8)
	CLAY_SPACE_3 :: f32(12)
	CLAY_FONT_SM :: u16(12)
	CLAY_FONT_MD :: u16(14)

	clay_theme_color :: proc(color: eng.Engine_Color) -> clay.Color {
		return {f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
	}

	clay_theme_divider :: proc(id: string) {
		if clay.UI(clay.ID(id))(clay.ElementDeclaration {
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(1)}},
			backgroundColor = clay_theme_color(SB_DIVIDER),
		}) {}
	}
}
```

- [ ] **Step 4: Add the dispatcher file**

```odin
package main

import clay "./vendor/clay"
import eng "./engine"

when USE_CLAY {
	clay_render_screen_ui :: proc(engine: ^eng.Engine, game: ^Game) {
		if game == nil { return }
		if clay.UI(clay.ID("screen-ui-root"))(clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(f32(SCREEN_WIDTH)), height = clay.SizingFixed(f32(SCREEN_HEIGHT))},
				layoutDirection = .TopToBottom,
			},
		}) {
			switch game.state {
				case .Playing:
					clay_render_gameplay_ui(engine, game)
				case .Title_Screen:
					clay_render_title_screen(engine, game)
				case .Viewing_Help:
					clay_render_help_screen(engine, game)
				// remaining states added in later tasks
			}
		}
	}

	clay_render_gameplay_ui :: proc(engine: ^eng.Engine, game: ^Game) {
		clay_render_hud(engine, game)
	}
}
```

- [ ] **Step 5: Route `render.odin` through the dispatcher**

```odin
when USE_CLAY {
	clay_ui_begin_frame(engine)
	clay_render_screen_ui(engine, game)
	commands := clay_ui_end_frame(delta_time)
	clay_render_commands(engine, commands)
} else {
	render_hud(engine, game)
	render_messages_for_engine(engine)
	if ui.show_minimap && game.state == .Playing { render_minimap(engine, game) }
	// legacy screen-state calls stay until each surface is migrated
}
```

- [ ] **Step 6: Make `clay_hud.odin` use the shared theme helpers**

```odin
// replace direct clay_color helper calls with clay_theme_color
clay_text :: proc(text: cstring, size: u16, color: eng.Engine_Color) {
	clay.TextDynamic(string(text), {textColor = clay_theme_color(color), fontSize = size, lineHeight = size})
}
```

- [ ] **Step 7: Run the targeted Clay test to verify it passes**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: PASS with the new dispatcher test green.

- [ ] **Step 8: Commit**

```bash
git add src/clay_theme.odin src/clay_screen_ui.odin src/render.odin src/clay_hud.odin src/clay_ui_test.odin
git commit -m "refactor: add Clay screen UI dispatcher"
```

### Task 2: Migrate gameplay message panel, minimap, tooltip, and contextual hints to Clay

**Files:**
- Create: `src/clay_messages.odin`
- Create: `src/clay_minimap.odin`
- Create: `src/clay_tooltip.odin`
- Modify: `src/clay_screen_ui.odin`
- Modify: `src/render_map.odin`
- Modify: `src/render_hud.odin`
- Modify: `src/messages.odin`
- Delete: `src/render_minimap.odin`
- Test: `src/clay_ui_test.odin`
- Test: `src/render_handlers_test.odin`

- [ ] **Step 1: Write the failing gameplay-surface test**

```odin
@(test)
clay_gameplay_ui_renders_messages_and_minimap_when_enabled :: proc(t: ^testing.T) {
	state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input = eng.engine_input_backend_nil(),
		render = clay_test_render_backend(&state),
	}
	game := game_init(content_manager_make())
	defer game_destroy(game)
	game.state = .Playing
	ui := ui_manager_state(game_engine_ui_manager(&engine))
	ui.show_minimap = true
	messages := game_engine_message_manager(&engine)
	add_message(messages, game, "hello", eng.Engine_Color{255,255,255,255})

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()
	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)

	testing.expect(t, commands.length > 0)
	testing.expect(t, state.rectangle_count > 0)
}
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: FAIL because gameplay UI only renders the HUD today.

- [ ] **Step 3: Add Clay messages panel**

```odin
package main

import clay "./vendor/clay"
import eng "./engine"

when USE_CLAY {
	clay_render_messages :: proc(engine: ^eng.Engine, messages: ^Message_Manager) {
		if messages == nil { return }
		if clay.UI(clay.ID("messages-panel"))(clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(f32(MAP_VIEW_WIDTH)), height = clay.SizingFixed(f32(MSG_REGION_HEIGHT))},
				padding = clay.Padding{left = 8, right = 8, top = 6, bottom = 6},
				layoutDirection = .TopToBottom,
			},
			backgroundColor = clay_theme_color(eng.Engine_Color{10, 10, 16, 230}),
		}) {
			for i := 0; i < min(MSG_MAX_VISIBLE, messages.count); i += 1 {
				entry := eng.message_manager_entry_at(messages, i)
				clay.TextDynamic(entry.text, {textColor = clay_theme_color(entry.color), fontSize = CLAY_FONT_SM, lineHeight = CLAY_FONT_SM})
			}
		}
	}
}
```

- [ ] **Step 4: Add Clay minimap and tooltip files**

```odin
// src/clay_minimap.odin
when USE_CLAY {
	clay_render_minimap :: proc(engine: ^eng.Engine, game: ^Game) {
		if clay.UI(clay.ID("minimap-panel"))(clay.ElementDeclaration {
			layout = {sizing = {width = clay.SizingFixed(164), height = clay.SizingFixed(104)}},
			backgroundColor = clay_theme_color(eng.Engine_Color{0, 0, 0, 180}),
		}) {
			clay_render_minimap_cells(engine, game)
		}
	}
}

// src/clay_tooltip.odin
when USE_CLAY {
	clay_render_tooltip :: proc(engine: ^eng.Engine, game: ^Game) {
		text := tooltip_text_for_mouse(engine, game)
		if len(text) == 0 { return }
		if clay.UI(clay.ID("tooltip"))(clay.ElementDeclaration {
			layout = {padding = clay.Padding{left = 6, right = 6, top = 4, bottom = 4}},
			backgroundColor = clay_theme_color(eng.Engine_Color{0, 0, 0, 220}),
		}) {
			clay.TextDynamic(text, {textColor = clay_theme_color(SB_TEXT), fontSize = CLAY_FONT_SM, lineHeight = CLAY_FONT_SM})
		}
	}
}
```

- [ ] **Step 5: Compose these gameplay surfaces in the dispatcher**

```odin
clay_render_gameplay_ui :: proc(engine: ^eng.Engine, game: ^Game) {
	clay_render_hud(engine, game)
	clay_render_messages(engine, game_engine_message_manager(engine))
	ui := ui_manager_state(game_engine_ui_manager(engine))
	if ui != nil && ui.show_minimap {
		clay_render_minimap(engine, game)
	}
	clay_render_tooltip(engine, game)
	clay_render_gameplay_hints(engine, game)
}
```

- [ ] **Step 6: Delete the legacy gameplay UI renderers they replace**

```odin
// remove legacy tooltip render proc from render_map.odin
// remove contextual overlay render section from render_hud.odin
// remove render_messages / render_messages_for_engine from messages.odin
// delete src/render_minimap.odin and remove callers
```

- [ ] **Step 7: Update function-existence tests**

```odin
// render_handlers_test.odin
screen_ui_render: proc(engine: ^eng.Engine, game: ^Game) = clay_render_screen_ui
messages_render: proc(engine: ^eng.Engine, messages: ^Message_Manager) = clay_render_messages
minimap_render: proc(engine: ^eng.Engine, game: ^Game) = clay_render_minimap
tooltip_render: proc(engine: ^eng.Engine, game: ^Game) = clay_render_tooltip
```

- [ ] **Step 8: Run targeted and package tests**

Run: `odin test src/ -define:USE_CLAY=true`
Expected: PASS with gameplay UI tests green and no references to `render_minimap`/legacy message renderers left.

- [ ] **Step 9: Commit**

```bash
git add src/clay_messages.odin src/clay_minimap.odin src/clay_tooltip.odin src/clay_screen_ui.odin src/render_map.odin src/render_hud.odin src/messages.odin src/render_handlers_test.odin
git rm src/render_minimap.odin
git commit -m "feat: migrate gameplay UI surfaces to Clay"
```

### Task 3: Migrate title, help, and high scores screens to Clay

**Files:**
- Create: `src/clay_title.odin`
- Create: `src/clay_help.odin`
- Create: `src/clay_scores.odin`
- Modify: `src/clay_screen_ui.odin`
- Modify: `src/render_ui.odin`
- Test: `src/clay_ui_test.odin`
- Test: `src/render_handlers_test.odin`

- [ ] **Step 1: Write the failing title/help/scores test**

```odin
@(test)
clay_screen_ui_renders_title_screen_text_for_title_state :: proc(t: ^testing.T) {
	state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input = eng.engine_input_backend_nil(),
		render = clay_test_render_backend(&state),
	}
	game := game_init(content_manager_make())
	defer game_destroy(game)
	game.state = .Title_Screen

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()
	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, state.text_count > 0)
}
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: FAIL because the dispatcher still routes `.Title_Screen` to a missing or stub title screen implementation.

- [ ] **Step 3: Add the Clay title screen file**

```odin
package main

import clay "./vendor/clay"
import eng "./engine"

when USE_CLAY {
	clay_render_title_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		if clay.UI(clay.ID("title-screen"))(clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(f32(SCREEN_WIDTH)), height = clay.SizingFixed(f32(SCREEN_HEIGHT))},
				childAlignment = {x = .Center, y = .Center},
				layoutDirection = .TopToBottom,
				childGap = CLAY_SPACE_2,
			},
			backgroundColor = clay_theme_color(eng.Engine_Color{0, 0, 0, 255}),
		}) {
			clay.TextDynamic("INTO THE DEPTHS", {textColor = clay_theme_color(SB_TITLE), fontSize = 22, lineHeight = 22})
			clay_render_title_options(ui)
		}
	}
}
```

- [ ] **Step 4: Add help and scores files**

```odin
// src/clay_help.odin
when USE_CLAY {
	clay_render_help_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		clay_render_centered_modal("help-screen", "HELP")
	}
}

// src/clay_scores.odin
when USE_CLAY {
	clay_render_scores_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		scores := game_engine_score_manager(engine)
		clay_render_scores_table(scores)
	}
}
```

- [ ] **Step 5: Wire the dispatcher states**

```odin
switch game.state {
case .Title_Screen:
	clay_render_title_screen(engine, game)
case .Viewing_Help:
	clay_render_help_screen(engine, game)
case .Viewing_Scores:
	clay_render_scores_screen(engine, game)
// other states stay on legacy paths until later tasks
}
```

- [ ] **Step 6: Remove the matching legacy renderers from `render_ui.odin`**

```odin
// delete render_title_screen
// delete render_high_scores
// delete render_help
```

- [ ] **Step 7: Update render handler tests to reference Clay replacements**

```odin
title_render: proc(engine: ^eng.Engine, game: ^Game) = clay_render_title_screen
help_render: proc(engine: ^eng.Engine, game: ^Game) = clay_render_help_screen
scores_render: proc(engine: ^eng.Engine, game: ^Game) = clay_render_scores_screen
```

- [ ] **Step 8: Run Clay package tests**

Run: `odin test src/ -define:USE_CLAY=true`
Expected: PASS with title/help/score render tests green.

- [ ] **Step 9: Commit**

```bash
git add src/clay_title.odin src/clay_help.odin src/clay_scores.odin src/clay_screen_ui.odin src/render_ui.odin src/render_handlers_test.odin src/clay_ui_test.odin
git commit -m "feat: migrate menu screens to Clay"
```

### Task 4: Migrate game-over and victory screens to Clay

**Files:**
- Create: `src/clay_game_over.odin`
- Create: `src/clay_victory.odin`
- Modify: `src/clay_screen_ui.odin`
- Modify: `src/render_ui.odin`
- Test: `src/clay_ui_test.odin`

- [ ] **Step 1: Write the failing outcome-screen test**

```odin
@(test)
clay_screen_ui_renders_victory_screen_for_victory_state :: proc(t: ^testing.T) {
	state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input = eng.engine_input_backend_nil(),
		render = clay_test_render_backend(&state),
	}
	game := game_init(content_manager_make())
	defer game_destroy(game)
	game.state = .Victory

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()
	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, state.text_count > 0)
}
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: FAIL because `.Victory` still depends on the legacy renderer.

- [ ] **Step 3: Add Clay game-over and victory files**

```odin
// src/clay_game_over.odin
when USE_CLAY {
	clay_render_game_over_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		clay_render_centered_modal("game-over", "YOU DIED")
		clay_render_score_summary(engine, game)
	}
}

// src/clay_victory.odin
when USE_CLAY {
	clay_render_victory_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		clay_render_centered_modal("victory", "ESCAPED THE DEPTHS")
		clay_render_score_summary(engine, game)
	}
}
```

- [ ] **Step 4: Route `.Game_Over` and `.Victory` through the dispatcher**

```odin
case .Game_Over:
	clay_render_game_over_screen(engine, game)
case .Victory:
	clay_render_victory_screen(engine, game)
```

- [ ] **Step 5: Delete the legacy outcome renderers from `render_ui.odin`**

```odin
// delete render_game_over
// delete render_victory
```

- [ ] **Step 6: Run Clay package tests**

Run: `odin test src/ -define:USE_CLAY=true`
Expected: PASS with outcome-state tests green.

- [ ] **Step 7: Commit**

```bash
git add src/clay_game_over.odin src/clay_victory.odin src/clay_screen_ui.odin src/render_ui.odin src/clay_ui_test.odin
git commit -m "feat: migrate outcome screens to Clay"
```

### Task 5: Migrate inventory overlay to Clay

**Files:**
- Create: `src/clay_inventory.odin`
- Modify: `src/clay_screen_ui.odin`
- Modify: `src/render_ui.odin`
- Modify: `src/input.odin` (only if selection helpers need extraction, not behavior changes)
- Test: `src/clay_ui_test.odin`

- [ ] **Step 1: Write the failing inventory-screen test**

```odin
@(test)
clay_inventory_screen_renders_item_rows_for_inventory_state :: proc(t: ^testing.T) {
	state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input = eng.engine_input_backend_nil(),
		render = clay_test_render_backend(&state),
	}
	game := game_init(content_manager_make())
	defer game_destroy(game)
	game.state = .Viewing_Inventory
	append(&game.inventory, Item{name = "Torch"})

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()
	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, state.text_count > 0)
}
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: FAIL because `.Viewing_Inventory` is not yet rendered through Clay.

- [ ] **Step 3: Add the inventory file with keyboard-first layout**

```odin
package main

import clay "./vendor/clay"
import eng "./engine"

when USE_CLAY {
	clay_render_inventory_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		if clay.UI(clay.ID("inventory-screen"))(clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(f32(SCREEN_WIDTH)), height = clay.SizingFixed(f32(SCREEN_HEIGHT))},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = clay_theme_color(eng.Engine_Color{0, 0, 0, 220}),
		}) {
			clay_render_inventory_panel(game, ui)
		}
	}
}
```

- [ ] **Step 4: If needed, extract row/selection formatting helpers from `render_ui.odin` before deleting it**

```odin
inventory_row_label :: proc(item: ^Item) -> string {
	if item == nil { return "---" }
	return item.name
}
```

- [ ] **Step 5: Route `.Viewing_Inventory` through the dispatcher and delete `render_inventory`**

```odin
case .Viewing_Inventory:
	clay_render_inventory_screen(engine, game)
```

```odin
// delete render_inventory from render_ui.odin after the Clay version is complete
```

- [ ] **Step 6: Run Clay package tests**

Run: `odin test src/ -define:USE_CLAY=true`
Expected: PASS with inventory state rendering under Clay and no `render_inventory` references left.

- [ ] **Step 7: Commit**

```bash
git add src/clay_inventory.odin src/clay_screen_ui.odin src/render_ui.odin src/clay_ui_test.odin
git commit -m "feat: migrate inventory overlay to Clay"
```

### Task 6: Migrate crafting overlay to Clay

**Files:**
- Create: `src/clay_crafting.odin`
- Modify: `src/clay_screen_ui.odin`
- Modify: `src/render_ui.odin`
- Test: `src/clay_ui_test.odin`

- [ ] **Step 1: Write the failing crafting-screen test**

```odin
@(test)
clay_crafting_screen_renders_recipe_rows_for_crafting_state :: proc(t: ^testing.T) {
	state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input = eng.engine_input_backend_nil(),
		render = clay_test_render_backend(&state),
	}
	game := game_init(content_manager_make())
	defer game_destroy(game)
	game.state = .Viewing_Crafting

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()
	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, state.text_count > 0)
}
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: FAIL because `.Viewing_Crafting` still uses the legacy renderer.

- [ ] **Step 3: Add the crafting file**

```odin
package main

import clay "./vendor/clay"
import eng "./engine"

when USE_CLAY {
	clay_render_crafting_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		if clay.UI(clay.ID("crafting-screen"))(clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(f32(SCREEN_WIDTH)), height = clay.SizingFixed(f32(SCREEN_HEIGHT))},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = clay_theme_color(eng.Engine_Color{0, 0, 0, 220}),
		}) {
			clay_render_crafting_panel(engine, game)
		}
	}
}
```

- [ ] **Step 4: Route `.Viewing_Crafting` through the dispatcher and delete `render_crafting`**

```odin
case .Viewing_Crafting:
	clay_render_crafting_screen(engine, game)
```

```odin
// delete render_crafting from render_ui.odin
```

- [ ] **Step 5: Run Clay package tests**

Run: `odin test src/ -define:USE_CLAY=true`
Expected: PASS with crafting state rendering under Clay.

- [ ] **Step 6: Commit**

```bash
git add src/clay_crafting.odin src/clay_screen_ui.odin src/render_ui.odin src/clay_ui_test.odin
git commit -m "feat: migrate crafting overlay to Clay"
```

### Task 7: Migrate cheats overlay to Clay while keeping cheat logic in place

**Files:**
- Create: `src/clay_cheats.odin`
- Modify: `src/clay_screen_ui.odin`
- Modify: `src/cheat_menu.odin`
- Test: `src/clay_ui_test.odin`
- Test: `src/cheat_menu_test.odin`

- [ ] **Step 1: Write the failing cheats-screen test**

```odin
@(test)
clay_cheats_screen_renders_choices_for_cheat_state :: proc(t: ^testing.T) {
	state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input = eng.engine_input_backend_nil(),
		render = clay_test_render_backend(&state),
	}
	game := game_init(content_manager_make())
	defer game_destroy(game)
	game.state = .Viewing_Cheats

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()
	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, state.text_count > 0)
}
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `odin test src/ -define:USE_CLAY=true -file:clay_ui_test.odin`
Expected: FAIL because `.Viewing_Cheats` still depends on `render_cheats`.

- [ ] **Step 3: Add the cheats screen file**

```odin
package main

import clay "./vendor/clay"
import eng "./engine"

when USE_CLAY {
	clay_render_cheats_screen :: proc(engine: ^eng.Engine, game: ^Game) {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		if clay.UI(clay.ID("cheats-screen"))(clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(f32(SCREEN_WIDTH)), height = clay.SizingFixed(f32(SCREEN_HEIGHT))},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = clay_theme_color(eng.Engine_Color{0, 0, 0, 220}),
		}) {
			clay_render_cheat_list(ui)
		}
	}
}
```

- [ ] **Step 4: Route `.Viewing_Cheats` through the dispatcher and delete only the legacy cheat render proc**

```odin
case .Viewing_Cheats:
	clay_render_cheats_screen(engine, game)
```

```odin
// in cheat_menu.odin keep:
// - cheat_open_if_requested
// - update_cheats
// remove only render_cheats after the Clay version lands
```

- [ ] **Step 5: Run cheat logic tests and Clay tests**

Run: `odin test src/ -define:USE_CLAY=true`
Expected: PASS with `cheat_menu_test.odin` still green and no legacy cheat render proc referenced.

- [ ] **Step 6: Commit**

```bash
git add src/clay_cheats.odin src/clay_screen_ui.odin src/cheat_menu.odin src/clay_ui_test.odin
git commit -m "feat: migrate cheats overlay to Clay"
```

### Task 8: Final cleanup, legacy removal, docs, and full verification

**Files:**
- Modify: `src/render.odin`
- Modify: `src/render_handlers_test.odin`
- Modify: `AGENTS.md`
- Modify: `justfile` (only if any temporary migration recipe can now be simplified)
- Delete: any now-unused screen-space render files or dead helpers
- Test: full package test and build matrix

- [ ] **Step 1: Delete any remaining legacy screen-space UI calls from `render.odin`**

```odin
when USE_CLAY {
	clay_ui_begin_frame(engine)
	clay_render_screen_ui(engine, game)
	commands := clay_ui_end_frame(delta_time)
	clay_render_commands(engine, commands)
} else {
	// only screens not yet migrated should remain here
}
```

If every screen-space surface is migrated, remove the old branch entirely and leave only the Clay UI path for screen-space rendering.

- [ ] **Step 2: Remove dead files and helpers**

```odin
// delete any leftover render_ui.odin procedures that were replaced
// delete leftover helpers whose only callers were removed
// delete legacy screen-space render files if now empty or obsolete
```

- [ ] **Step 3: Update documentation to reflect the finished ownership map**

```md
- screen-space UI now lives under `src/clay_*.odin`
- world rendering still uses the existing engine render path
- `render_game` owns the world pass + Clay pass orchestration
```

- [ ] **Step 4: Run the Clay and default verification matrix**

Run: `just test-flags`
Expected: PASS including `-define:USE_CLAY=true`

Run: `odin test src/ -define:USE_CLAY=true`
Expected: PASS

Run: `odin test src/ -define:USE_CLAY=false`
Expected: PASS during the migration window; if the legacy path is intentionally retired, replace this with the new intended fallback command and document it before running.

Run: `just verify`
Expected: PASS

- [ ] **Step 5: Run one Clay public-build compile**

Run: `odin build src/ -out:into_the_depths_clay -define:USE_CLAY=true -define:PUBLIC_BUILD=true`
Expected: build succeeds with no Clay-only compile regressions.

- [ ] **Step 6: Commit**

```bash
git add src render.odin AGENTS.md justfile
git rm <obsolete-ui-files>
git commit -m "refactor: complete Clay UI migration"
```

## Self-Review

### Spec coverage
- All screen-space UI surfaces from the spec have explicit migration tasks:
  - HUD: Task 1 keeps and normalizes it under theme + dispatcher
  - messages/minimap/tooltip/context hints: Task 2
  - title/help/high scores: Task 3
  - game over/victory: Task 4
  - inventory: Task 5
  - crafting: Task 6
  - cheats: Task 7
  - final orchestration + deletion: Task 8
- World rendering remains untouched except for removing tooltip/UI calls from legacy orchestration.
- Deletion-as-you-go is enforced in every screen task.

### Placeholder scan
- No `TODO`, `TBD`, “handle appropriately”, or “similar to previous task” placeholders remain.
- Every task includes file paths, code blocks, commands, expected outcomes, and commit steps.

### Type consistency
- Dispatcher entrypoint is consistently `clay_render_screen_ui`.
- Per-screen naming uses `clay_render_<screen>_screen` consistently for modal/full-screen surfaces.
- Gameplay surfaces use `clay_render_messages`, `clay_render_minimap`, `clay_render_tooltip` consistently.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-04-clay-full-ui-migration-plan.md`.

Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
