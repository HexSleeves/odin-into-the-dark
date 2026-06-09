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

@(private = "file")
TITLE_HOTKEYS := [gcore.TITLE_OPTION_COUNT]string{"N", "C", "H", "?", "Q"}

clay_render_title_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	choice := 0
	if ui != nil {choice = ui.title_choice}
	saves := game_engine_save_manager(engine)
	has_save := gcore.save_manager_save_exists(saves)
	options := ui_pkg.UI_TITLE_OPTIONS

	if clay.UI(clay.ID("title-backdrop"))(clay_menu_backdrop_decl()) {
		clay_render_title_embers(engine)
		if clay.UI(clay.ID("title-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_APP_TITLE)
			clay_menu_subtitle(ui_pkg.UI_TITLE_SUBTITLE)
			clay_menu_subtitle(ui_pkg.UI_TITLE_TAGLINE, ui_pkg.SB_DIM, 14)
			clay_menu_accent_rule("title-rule")
			for label, idx in options {
				disabled := idx == gcore.TITLE_CONTINUE && !has_save
				selected := idx == choice
				clay_menu_item(
					fmt.tprintf("title-item-%d", idx),
					label,
					TITLE_HOTKEYS[idx],
					selected,
					disabled,
				)
			}
			if !has_save {
				clay_menu_kv(
					"title-continue-note",
					"",
					ui_pkg.UI_TITLE_CONTINUE_DISABLED,
					13,
					ui_pkg.SB_DIM,
					ui_pkg.SB_DIM,
				)
			}
			clay_menu_footer("title-footer", ui_pkg.UI_TITLE_FOOTER)
			clay_text_centered(ui_pkg.UI_APP_VERSION, 12, ui_pkg.SB_DIM)
		}
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
	if clay.UI(clay.ID("inventory-backdrop"))(clay_menu_backdrop_decl(floating = true)) {
		if clay.UI(clay.ID("inventory-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_INVENTORY_TITLE)
			clay_menu_subtitle(ui_pkg.UI_INVENTORY_HELP)
			clay_menu_accent_rule("inventory-rule")
			if ui != nil &&
			   ui.dropping {clay_text_centered(ui_pkg.UI_INVENTORY_DROP_MODE, 16, ui_pkg.SB_TITLE)}
			if ui != nil &&
			   ui.equipping {clay_text_centered(ui_pkg.UI_INVENTORY_EQUIP_MODE, 16, ui_pkg.SB_ARM)}
			for idx in 0 ..< gcore.MAX_INVENTORY {
				slot := game.inventory[idx]
				selected := ui != nil && ui.inspect_slot == idx
				if slot.occupied {
					qty :=
						fmt.tprintf(" x%d", slot.item.quantity) if slot.item.quantity > 1 else ""
					clay_menu_item(
						fmt.tprintf("inventory-item-%d", idx),
						fmt.tprintf("%s%s", gcore.item_display_name(&slot.item), qty),
						fmt.tprintf("%d", idx + 1),
						selected,
					)
					if selected && len(slot.item.description) > 0 {
						clay_menu_kv(
							fmt.tprintf("inventory-desc-%d", idx),
							"",
							slot.item.description,
							13,
							ui_pkg.SB_DIM,
							ui_pkg.SB_DIM,
						)
					}
				} else {
					clay_menu_item(
						fmt.tprintf("inventory-item-%d", idx),
						"[empty]",
						fmt.tprintf("%d", idx + 1),
						selected,
						true,
					)
				}
			}
			eq_slot := ui != nil ? ui.inspect_slot : -1
			clay_menu_section("inventory-equipment", "EQUIPMENT")
			clay_equipment_line("WPN", &game.equipped_weapon, eq_slot == gcore.MAX_INVENTORY)
			clay_equipment_line("ARM", &game.equipped_armor, eq_slot == gcore.MAX_INVENTORY + 1)
			clay_equipment_line("HLM", &game.equipped_helmet, eq_slot == gcore.MAX_INVENTORY + 2)
		}
	}
}

clay_render_crafting_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	content := game_engine_content_manager(engine)
	if clay.UI(clay.ID("crafting-backdrop"))(clay_menu_backdrop_decl(floating = true)) {
		if clay.UI(clay.ID("crafting-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_CRAFTING_TITLE)
			clay_menu_subtitle(ui_pkg.UI_CRAFTING_HELP)
			clay_menu_accent_rule("crafting-rule")
			recipes := gcore.RECIPES
			for idx in 0 ..< len(recipes) {
				recipe := recipes[idx]
				have := gcore.count_material(game, recipe.material_id)
				can_craft := have >= recipe.material_qty
				color := ui_pkg.SB_HP_FG if can_craft else ui_pkg.SB_HP_LOW
				mat_name := recipe.material_id
				if mat_def := gcore.content_manager_item_def(content, recipe.material_id);
				   mat_def != nil {mat_name = mat_def.name}
				clay_menu_kv(
					fmt.tprintf("crafting-recipe-%d", idx),
					fmt.tprintf("%d. %s", idx + 1, recipe.name),
					fmt.tprintf("[%d/%d %s]", have, recipe.material_qty, mat_name),
					16,
					ui_pkg.SB_TEXT,
					color,
				)
			}
		}
	}
}

clay_render_help_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	_ = engine
	_ = game
	sections := ui_pkg.ui_help_sections()
	if clay.UI(clay.ID("help-backdrop"))(clay_menu_backdrop_decl()) {
		if clay.UI(clay.ID("help-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_HELP_TITLE)
			clay_menu_accent_rule("help-rule")
			for section, sidx in sections {
				clay_menu_section(fmt.tprintf("help-section-%d", sidx), section.title)
				for row, ridx in section.rows {
					clay_menu_kv(fmt.tprintf("help-row-%d-%d", sidx, ridx), row.key, row.action)
				}
			}
			clay_menu_footer("help-footer", ui_pkg.UI_HELP_FOOTER)
		}
	}
}

clay_render_scores_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	_ = game
	table := score_manager_load(game_engine_score_manager(engine))
	defer score_table_destroy(&table)
	if clay.UI(clay.ID("scores-backdrop"))(clay_menu_backdrop_decl()) {
		if clay.UI(clay.ID("scores-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_SCORES_TITLE)
			clay_menu_accent_rule("scores-rule")
			if table.count == 0 {
				clay_text_centered(ui_pkg.UI_SCORES_EMPTY, 18, ui_pkg.SB_DIM)
			} else {
				clay_menu_kv(
					"scores-header",
					"Rank",
					"Depth / Kills / Items / Turns",
					14,
					ui_pkg.SB_HEADER,
					ui_pkg.SB_HEADER,
				)
				for i in 0 ..< min(table.count, MAX_SCORES) {
					s := table.scores[i]
					clay_menu_kv(
						fmt.tprintf("scores-row-%d", i),
						fmt.tprintf("#%d", i + 1),
						fmt.tprintf("%d / %d / %d / %d", s.depth, s.kills, s.items_found, s.turns),
					)
				}
			}
			clay_menu_footer("scores-footer", ui_pkg.UI_SCORES_FOOTER)
		}
	}
}

clay_render_game_over_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	turns := game_engine_turn_manager(engine)
	if clay.UI(clay.ID("game-over-backdrop"))(clay_menu_backdrop_decl()) {
		if clay.UI(clay.ID("game-over-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_GAME_OVER_TITLE, ui_pkg.SB_HP_LOW)
			clay_menu_accent_rule("game-over-rule")
			cause := game.death_cause if len(game.death_cause) > 0 else "Unknown cause of death"
			clay_text_centered(cause, 18, ui_pkg.SB_TEXT)
			clay_menu_kv("game-over-depth", "Depth", fmt.tprintf("%d", game.depth))
			clay_menu_kv("game-over-kills", "Kills", fmt.tprintf("%d", game.kills))
			clay_menu_kv(
				"game-over-turns",
				"Turns",
				fmt.tprintf("%d", eng.turn_manager_current(turns)),
			)
			clay_menu_footer("game-over-footer", ui_pkg.UI_GAME_OVER_FOOTER)
		}
	}
}

clay_render_victory_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	turns := game_engine_turn_manager(engine)
	if clay.UI(clay.ID("victory-backdrop"))(clay_menu_backdrop_decl()) {
		if clay.UI(clay.ID("victory-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_VICTORY_TITLE)
			clay_menu_subtitle(ui_pkg.UI_VICTORY_SUBTITLE)
			clay_menu_accent_rule("victory-rule")
			clay_menu_kv("victory-depth", "Depth Reached", fmt.tprintf("%d", game.depth))
			clay_menu_kv("victory-kills", "Enemies Slain", fmt.tprintf("%d", game.kills))
			clay_menu_kv("victory-items", "Items Found", fmt.tprintf("%d", game.items_found))
			clay_menu_kv(
				"victory-turns",
				"Turns Survived",
				fmt.tprintf("%d", eng.turn_manager_current(turns)),
			)
			clay_menu_footer("victory-footer", ui_pkg.UI_VICTORY_FOOTER)
		}
	}
}

clay_render_cheats_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	choice := 0
	if ui != nil {choice = ui.cheat_choice}
	if clay.UI(clay.ID("cheats-backdrop"))(clay_menu_backdrop_decl(floating = true)) {
		if clay.UI(clay.ID("cheats-card"))(clay_menu_card_decl()) {
			clay_menu_title(ui_pkg.UI_CHEATS_TITLE)
			clay_menu_subtitle(ui_pkg.UI_CHEATS_HELP)
			clay_menu_accent_rule("cheats-rule")
			when CHEATS_ENABLED {
				for i in 0 ..< gcore.CHEAT_COMMAND_COUNT {
					command := gcore.cheat_command_for_index(i)
					clay_menu_item(
						fmt.tprintf("cheats-item-%d", i),
						string(gcore.cheat_command_label(command)),
						fmt.tprintf("%d", i + 1),
						i == choice,
					)
				}
			}
		}
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

clay_equipment_line :: proc(label: string, equipment: ^gcore.Equipment, selected := false) {
	occupied := equipment != nil && equipment.occupied
	text: string
	if occupied {
		text = fmt.tprintf(
			"%s %s (+%d)",
			label,
			gcore.item_display_name(&equipment.item),
			equipment.item.stat_bonus,
		)
	} else {
		text = fmt.tprintf("%s ---", label)
	}
	clay_menu_item(fmt.tprintf("equipment-%s", label), text, "", selected, !occupied)
}
