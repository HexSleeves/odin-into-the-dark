package renderer

import ui_pkg "../ui"

import gcore "../core"

import eng "../engine"
import "core:fmt"
import clay "libs:clay"

@(private = "file")
clay_overlays_import_anchor :: proc() {
	_ = eng.Engine{}
	_ = clay.ElementDeclaration{}
	_ = fmt.tprintf
}

clay_render_title_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	choice := 0
	if ui != nil {choice = ui.title_choice}
	saves := game_engine_save_manager(engine)
	has_save := gcore.save_manager_save_exists(saves)
	options := ui_pkg.UI_TITLE_OPTIONS

	if clay.UI(clay.ID("title-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 230})) {
		clay_render_title_embers(engine)
		clay_title_text(ui_pkg.UI_APP_TITLE, 48, ui_pkg.SB_TITLE)
		clay_spacer_fixed("title-art-gap", 1, 32)
		clay_overlay_text(ui_pkg.UI_TITLE_SUBTITLE, 18, ui_pkg.SB_HEADER)
		clay_spacer_fixed("title-gap", 1, 12)
		for label, idx in options {
			disabled := idx == gcore.TITLE_CONTINUE && !has_save
			selected := idx == choice
			color := ui_pkg.SB_TEXT
			if disabled {color = ui_pkg.SB_DIM}
			if selected && !disabled {color = ui_pkg.SB_TITLE}
			prefix := ">" if selected else " "
			clay_overlay_text(fmt.tprintf("%s %s", prefix, label), 24, color)
		}
		if !has_save {
			clay_overlay_text(ui_pkg.UI_TITLE_CONTINUE_DISABLED, 14, ui_pkg.SB_DIM)
		}
		clay_spacer_grow("title-footer-gap")
		clay_overlay_text(ui_pkg.UI_TITLE_FOOTER, 14, ui_pkg.SB_DIM)
		clay_overlay_text(ui_pkg.UI_APP_VERSION, 12, ui_pkg.SB_DIM)
	}
}

clay_render_title_embers :: proc(engine: ^eng.Engine) {
	frame := 0
	frames := game_engine_frame_manager(engine)
	if frames != nil {
		frame = eng.frame_manager_index(frames^)
	}

	for i in 0 ..< 18 {
		phase := (frame + i * 37) % 180
		x := i32(120 + (i * 71) % (gcore.SCREEN_WIDTH - 240))
		y := i32(90 + phase * 2)
		if y > 500 {y -= 360}
		alpha := u8(max(25, 140 - phase / 2))
		size := i32(2 + (i % 3))

		if clay.UI(clay.ID("title-ember", u32(i)))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingFixed(f32(size)),
					height = clay.SizingFixed(f32(size)),
				},
			},
			backgroundColor = clay_color(
				eng.Engine_Color{ui_pkg.SB_OIL.r, ui_pkg.SB_OIL.g, ui_pkg.SB_OIL.b, alpha},
			),
			floating = {
				offset = {f32(x), f32(y)},
				attachTo = .Parent,
				attachment = {element = .LeftTop, parent = .LeftTop},
				pointerCaptureMode = .Passthrough,
			},
		},
		) {}
	}
}

clay_render_inventory_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	if clay.UI(clay.ID("inventory-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 200})) {
		clay_title_text(ui_pkg.UI_INVENTORY_TITLE, 30, ui_pkg.SB_TITLE)
		clay_overlay_text(ui_pkg.UI_INVENTORY_HELP, 14, ui_pkg.SB_DIM)
		if ui != nil &&
		   ui.dropping {clay_overlay_text(ui_pkg.UI_INVENTORY_DROP_MODE, 16, ui_pkg.SB_TITLE)}
		if ui != nil &&
		   ui.equipping {clay_overlay_text(ui_pkg.UI_INVENTORY_EQUIP_MODE, 16, ui_pkg.SB_ARM)}
		clay_spacer_fixed("inventory-gap", 1, 18)
		for idx in 0 ..< gcore.MAX_INVENTORY {
			slot := game.inventory[idx]
			selected := ui != nil && ui.inspect_slot == idx
			color := ui_pkg.SB_TITLE if selected else ui_pkg.SB_TEXT
			if slot.occupied {
				qty := fmt.tprintf(" x%d", slot.item.quantity) if slot.item.quantity > 1 else ""
				clay_overlay_text(
					fmt.tprintf("%d. %s%s", idx + 1, gcore.item_display_name(&slot.item), qty),
					16,
					color,
				)
			} else {
				clay_overlay_text(fmt.tprintf("%d. [empty]", idx + 1), 16, ui_pkg.SB_DIM)
			}
		}
		clay_spacer_fixed("equipment-gap", 1, 12)
		clay_overlay_text("EQUIPMENT", 18, ui_pkg.SB_HEADER)
		clay_equipment_line("WPN", &game.equipped_weapon)
		clay_equipment_line("ARM", &game.equipped_armor)
		clay_equipment_line("HLM", &game.equipped_helmet)
	}
}

clay_render_crafting_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	content := game_engine_content_manager(engine)
	if clay.UI(clay.ID("crafting-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 200})) {
		clay_title_text(ui_pkg.UI_CRAFTING_TITLE, 30, ui_pkg.SB_TITLE)
		clay_overlay_text(ui_pkg.UI_CRAFTING_HELP, 14, ui_pkg.SB_DIM)
		clay_spacer_fixed("craft-gap", 1, 28)
		recipes := gcore.RECIPES
		for idx in 0 ..< len(recipes) {
			recipe := recipes[idx]
			have := gcore.count_material(game, recipe.material_id)
			can_craft := have >= recipe.material_qty
			color := ui_pkg.SB_HP_FG if can_craft else ui_pkg.SB_HP_LOW
			mat_name := recipe.material_id
			if mat_def := gcore.content_manager_item_def(content, recipe.material_id);
			   mat_def != nil {mat_name = mat_def.name}
			clay_overlay_text(
				fmt.tprintf(
					"%d. %s  [%d/%d %s]",
					idx + 1,
					recipe.name,
					have,
					recipe.material_qty,
					mat_name,
				),
				16,
				color,
			)
		}
	}
}

clay_render_help_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	_ = engine
	_ = game
	lines := ui_pkg.UI_HELP_LINES
	if clay.UI(clay.ID("help-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
		clay_title_text(ui_pkg.UI_HELP_TITLE, 28, ui_pkg.SB_TITLE)
		clay_spacer_fixed("help-gap", 1, 20)
		for line, idx in lines {
			if len(line) == 0 {
				clay_spacer_fixed(fmt.tprintf("help-spacer-%d", idx), 1, 10)
			} else {
				color :=
					ui_pkg.SB_TITLE if line == "MOVEMENT" || line == "ITEMS" || line == "TOOLS" else ui_pkg.SB_TEXT
				clay_overlay_text(line, 15, color)
			}
		}
		clay_spacer_grow("help-footer-gap")
		clay_overlay_text(ui_pkg.UI_HELP_FOOTER, 16, ui_pkg.SB_DIM)
	}
}

clay_render_scores_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	_ = game
	table := score_manager_load(game_engine_score_manager(engine))
	defer score_table_destroy(&table)
	if clay.UI(clay.ID("scores-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 230})) {
		clay_title_text(ui_pkg.UI_SCORES_TITLE, 34, ui_pkg.SB_TITLE)
		clay_spacer_fixed("scores-gap", 1, 26)
		if table.count == 0 {
			clay_overlay_text(ui_pkg.UI_SCORES_EMPTY, 18, ui_pkg.SB_DIM)
		} else {
			for i in 0 ..< min(table.count, MAX_SCORES) {
				s := table.scores[i]
				clay_overlay_text(
					fmt.tprintf(
						"#%d  Depth %d  Kills %d  Items %d  Turns %d",
						i + 1,
						s.depth,
						s.kills,
						s.items_found,
						s.turns,
					),
					16,
					ui_pkg.SB_TEXT,
				)
			}
		}
		clay_spacer_grow("scores-footer-gap")
		clay_overlay_text(ui_pkg.UI_SCORES_FOOTER, 16, ui_pkg.SB_DIM)
	}
}

clay_render_game_over_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	turns := game_engine_turn_manager(engine)
	if clay.UI(clay.ID("game-over-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
		clay_title_text(ui_pkg.UI_GAME_OVER_TITLE, 36, ui_pkg.SB_HP_LOW)
		cause := game.death_cause if len(game.death_cause) > 0 else "Unknown cause of death"
		clay_overlay_text(cause, 18, ui_pkg.SB_TEXT)
		clay_overlay_text(
			fmt.tprintf(
				"Depth: %d  |  Kills: %d  |  Turns: %d",
				game.depth,
				game.kills,
				eng.turn_manager_current(turns),
			),
			16,
			ui_pkg.SB_DIM,
		)
		clay_spacer_fixed("game-over-gap", 1, 28)
		clay_overlay_text(ui_pkg.UI_GAME_OVER_FOOTER, 16, ui_pkg.SB_DIM)
	}
}

clay_render_victory_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	turns := game_engine_turn_manager(engine)
	if clay.UI(clay.ID("victory-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
		clay_title_text(ui_pkg.UI_VICTORY_TITLE, 48, ui_pkg.SB_TITLE)
		clay_overlay_text(ui_pkg.UI_VICTORY_SUBTITLE, 20, ui_pkg.SB_HEADER)
		clay_spacer_fixed("victory-gap", 1, 24)
		clay_overlay_text(fmt.tprintf("Depth Reached  %d", game.depth), 18, ui_pkg.SB_TEXT)
		clay_overlay_text(fmt.tprintf("Enemies Slain  %d", game.kills), 18, ui_pkg.SB_TEXT)
		clay_overlay_text(fmt.tprintf("Items Found    %d", game.items_found), 18, ui_pkg.SB_TEXT)
		clay_overlay_text(
			fmt.tprintf("Turns Survived %d", eng.turn_manager_current(turns)),
			18,
			ui_pkg.SB_TEXT,
		)
		clay_spacer_grow("victory-footer-gap")
		clay_overlay_text(ui_pkg.UI_VICTORY_FOOTER, 16, ui_pkg.SB_DIM)
	}
}

clay_render_cheats_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	choice := 0
	if ui != nil {choice = ui.cheat_choice}
	if clay.UI(clay.ID("cheats-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
		clay_title_text(ui_pkg.UI_CHEATS_TITLE, 32, ui_pkg.SB_TITLE)
		clay_overlay_text(ui_pkg.UI_CHEATS_HELP, 14, ui_pkg.SB_DIM)
		clay_spacer_fixed("cheats-gap", 1, 26)
		when CHEATS_ENABLED {
			for i in 0 ..< gcore.CHEAT_COMMAND_COUNT {
				command := gcore.cheat_command_for_index(i)
				prefix := ">" if i == choice else " "
				color := ui_pkg.SB_TITLE if i == choice else ui_pkg.SB_TEXT
				clay_overlay_text(
					fmt.tprintf("%s %d. %s", prefix, i + 1, gcore.cheat_command_label(command)),
					18,
					color,
				)
			}
		}
	}
}

clay_overlay_decl :: proc(color: eng.Engine_Color) -> clay.ElementDeclaration {
	return clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingFixed(f32(gcore.SCREEN_WIDTH)),
				height = clay.SizingFixed(f32(gcore.SCREEN_HEIGHT)),
			},
			padding = clay.Padding{left = 32, right = 32, top = 48, bottom = 32},
			childGap = 10,
			childAlignment = {x = .Center, y = .Top},
			layoutDirection = .TopToBottom,
		},
		floating = {attachTo = .Parent, attachment = {element = .LeftTop, parent = .LeftTop}},
		backgroundColor = clay_color(color),
		border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {1, 1, 1, 1, 0}},
		cornerRadius = {3, 3, 3, 3},
	}
}

clay_title_text :: proc(text: string, size: u16, color: eng.Engine_Color) {
	clay_overlay_text(text, size, color)
}

clay_overlay_text :: proc(text: string, size: u16, color: eng.Engine_Color) {
	if clay.UI(clay.ID_LOCAL("overlay-text"))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}},
	},
	) {
		clay.TextDynamic(text, {textColor = clay_color(color), fontSize = size, lineHeight = size})
	}
}

clay_equipment_line :: proc(label: string, equipment: ^gcore.Equipment) {
	if equipment != nil && equipment.occupied {
		clay_overlay_text(
			fmt.tprintf(
				"%s %s (+%d)",
				label,
				gcore.item_display_name(&equipment.item),
				equipment.item.stat_bonus,
			),
			15,
			ui_pkg.SB_TEXT,
		)
	} else {
		clay_overlay_text(fmt.tprintf("%s ---", label), 15, ui_pkg.SB_DIM)
	}
}
