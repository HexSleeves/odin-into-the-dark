package main

import eng "./engine"
import clay "./vendor/clay"
import "core:fmt"

@(private = "file")
clay_overlays_import_anchor :: proc() {
	_ = eng.Engine{}
	_ = clay.ElementDeclaration{}
	_ = fmt.tprintf
}

	clay_render_title_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		choice := 0
		if ui != nil {choice = ui.title_choice}
		saves := game_engine_save_manager(engine)
		has_save := save_manager_save_exists(saves)
		options := [TITLE_OPTION_COUNT]string{"New Game", "Continue", "High Scores", "Help", "Quit"}

		if clay.UI(clay.ID("title-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 230})) {
			clay_spacer_fixed("title-art-gap", 1, 150)
			clay_overlay_text("A turn-based mining roguelike", 18, eng.Engine_Color{180, 180, 180, 255})
			clay_spacer_fixed("title-gap", 1, 12)
			for label, idx in options {
				disabled := idx == TITLE_CONTINUE && !has_save
				selected := idx == choice
				color := eng.Engine_Color{220, 220, 220, 255}
				if disabled {color = eng.Engine_Color{90, 90, 90, 255}}
				if selected && !disabled {color = eng.Engine_Color{255, 220, 100, 255}}
				prefix := ">" if selected else " "
				clay_overlay_text(fmt.tprintf("%s %s", prefix, label), 24, color)
			}
			if !has_save {
				clay_overlay_text("No save file found — Continue is disabled", 14, eng.Engine_Color{120, 120, 120, 255})
			}
			clay_spacer_grow("title-footer-gap")
			clay_overlay_text("Up/Down: Select  |  Enter: Confirm  |  N/C/H/?: Shortcuts  |  Esc/Q: Quit", 14, eng.Engine_Color{150, 150, 150, 255})
			clay_overlay_text("v0.1.0", 12, eng.Engine_Color{80, 80, 80, 255})
		}
	}

	clay_render_inventory_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		if clay.UI(clay.ID("inventory-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 200})) {
			clay_title_text("INVENTORY", 30, eng.Engine_Color{255, 255, 255, 255})
			clay_overlay_text("1-9=Use | D=Drop | E=Equip | Up/Down=Inspect | I/ESC=Close", 14, eng.Engine_Color{150, 150, 150, 255})
			if ui != nil && ui.dropping {clay_overlay_text("[DROP MODE] Press 1-9 to drop", 16, eng.Engine_Color{255, 200, 80, 255})}
			if ui != nil && ui.equipping {clay_overlay_text("[EQUIP MODE] Press 1-9 to equip", 16, eng.Engine_Color{100, 200, 255, 255})}
			clay_spacer_fixed("inventory-gap", 1, 18)
			for idx in 0 ..< MAX_INVENTORY {
				slot := game.inventory[idx]
				selected := ui != nil && ui.inspect_slot == idx
				color := eng.Engine_Color{255, 220, 100, 255} if selected else eng.Engine_Color{220, 220, 220, 255}
				if slot.occupied {
					qty := fmt.tprintf(" x%d", slot.item.quantity) if slot.item.quantity > 1 else ""
					clay_overlay_text(fmt.tprintf("%d. %s%s", idx + 1, item_display_name(&slot.item), qty), 16, color)
				} else {
					clay_overlay_text(fmt.tprintf("%d. [empty]", idx + 1), 16, eng.Engine_Color{90, 90, 90, 255})
				}
			}
			clay_spacer_fixed("equipment-gap", 1, 12)
			clay_overlay_text("EQUIPMENT", 18, eng.Engine_Color{200, 200, 100, 255})
			clay_equipment_line("WPN", &game.equipped_weapon)
			clay_equipment_line("ARM", &game.equipped_armor)
			clay_equipment_line("HLM", &game.equipped_helmet)
		}
	}

	clay_render_crafting_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		content := game_engine_content_manager(engine)
		if clay.UI(clay.ID("crafting-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 200})) {
			clay_title_text("CRAFTING", 30, eng.Engine_Color{255, 255, 255, 255})
			clay_overlay_text("Press 1-4 to craft | C or ESC to close", 14, eng.Engine_Color{150, 150, 150, 255})
			clay_spacer_fixed("craft-gap", 1, 28)
			recipes := RECIPES
			for idx in 0 ..< len(recipes) {
				recipe := recipes[idx]
				have := count_material(game, recipe.material_id)
				can_craft := have >= recipe.material_qty
				color := eng.Engine_Color{100, 255, 100, 255} if can_craft else eng.Engine_Color{150, 80, 80, 255}
				mat_name := recipe.material_id
				if mat_def := content_manager_item_def(content, recipe.material_id); mat_def != nil {mat_name = mat_def.name}
				clay_overlay_text(fmt.tprintf("%d. %s  [%d/%d %s]", idx + 1, recipe.name, have, recipe.material_qty, mat_name), 16, color)
			}
		}
	}

	clay_render_help_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		_ = engine
		_ = game
		lines := [?]string{"MOVEMENT", "WASD / Arrows    Move", ".  (period)      Wait a turn", "Walk into enemy  Attack", "", "ITEMS", "G                Pick up item", "I                Open inventory", "1-9              Use item", "D / E            Drop or equip from inventory", "", "TOOLS", "X                Mine adjacent wall/hazard", "C                Craft at anvils", "M                Toggle minimap", "F1               Mute audio", "ESC/Q            Close menu / quit"}
		if clay.UI(clay.ID("help-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
			clay_title_text("CONTROLS & HELP", 28, eng.Engine_Color{255, 255, 255, 255})
			clay_spacer_fixed("help-gap", 1, 20)
			for line, idx in lines {
				if len(line) == 0 {
					clay_spacer_fixed(fmt.tprintf("help-spacer-%d", idx), 1, 10)
				} else {
					color := eng.Engine_Color{255, 220, 100, 255} if line == "MOVEMENT" || line == "ITEMS" || line == "TOOLS" else eng.Engine_Color{200, 200, 200, 255}
					clay_overlay_text(line, 15, color)
				}
			}
			clay_spacer_grow("help-footer-gap")
			clay_overlay_text("Press ESC or ? to return", 16, eng.Engine_Color{150, 150, 150, 255})
		}
	}

	clay_render_scores_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		_ = game
		table := score_manager_load(game_engine_score_manager(engine))
		defer score_table_destroy(&table)
		if clay.UI(clay.ID("scores-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 230})) {
			clay_title_text("HIGH SCORES", 34, eng.Engine_Color{255, 220, 50, 255})
			clay_spacer_fixed("scores-gap", 1, 26)
			if table.count == 0 {
				clay_overlay_text("No scores yet.", 18, eng.Engine_Color{150, 150, 150, 255})
			} else {
				for i in 0 ..< min(table.count, MAX_SCORES) {
					s := table.scores[i]
					clay_overlay_text(fmt.tprintf("#%d  Depth %d  Kills %d  Items %d  Turns %d", i + 1, s.depth, s.kills, s.items_found, s.turns), 16, eng.Engine_Color{210, 210, 210, 255})
				}
			}
			clay_spacer_grow("scores-footer-gap")
			clay_overlay_text("Press ESC or H to return", 16, eng.Engine_Color{150, 150, 150, 255})
		}
	}

	clay_render_game_over_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		turns := game_engine_turn_manager(engine)
		if clay.UI(clay.ID("game-over-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
			clay_title_text("GAME OVER", 36, eng.Engine_Color{230, 41, 55, 255})
			cause := game.death_cause if len(game.death_cause) > 0 else "Unknown cause of death"
			clay_overlay_text(cause, 18, eng.Engine_Color{255, 255, 255, 255})
			clay_overlay_text(fmt.tprintf("Depth: %d  |  Kills: %d  |  Turns: %d", game.depth, game.kills, eng.turn_manager_current(turns)), 16, eng.Engine_Color{180, 180, 180, 255})
			clay_spacer_fixed("game-over-gap", 1, 28)
			clay_overlay_text("Press R to restart or Q to quit", 16, eng.Engine_Color{150, 150, 150, 255})
		}
	}

	clay_render_victory_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		turns := game_engine_turn_manager(engine)
		if clay.UI(clay.ID("victory-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
			clay_title_text("VICTORY!", 48, eng.Engine_Color{255, 215, 0, 255})
			clay_overlay_text("You have conquered the depths!", 20, eng.Engine_Color{200, 200, 100, 255})
			clay_spacer_fixed("victory-gap", 1, 24)
			clay_overlay_text(fmt.tprintf("Depth Reached  %d", game.depth), 18, eng.Engine_Color{255, 255, 200, 255})
			clay_overlay_text(fmt.tprintf("Enemies Slain  %d", game.kills), 18, eng.Engine_Color{255, 255, 200, 255})
			clay_overlay_text(fmt.tprintf("Items Found    %d", game.items_found), 18, eng.Engine_Color{255, 255, 200, 255})
			clay_overlay_text(fmt.tprintf("Turns Survived %d", eng.turn_manager_current(turns)), 18, eng.Engine_Color{255, 255, 200, 255})
			clay_spacer_grow("victory-footer-gap")
			clay_overlay_text("Press R to play again or Q to quit", 16, eng.Engine_Color{150, 150, 150, 255})
		}
	}

	clay_render_cheats_overlay :: proc(engine: ^eng.Engine, game: ^Game) {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		choice := 0
		if ui != nil {choice = ui.cheat_choice}
		if clay.UI(clay.ID("cheats-overlay"))(clay_overlay_decl(eng.Engine_Color{0, 0, 0, 220})) {
			clay_title_text("CHEAT MENU", 32, eng.Engine_Color{255, 215, 0, 255})
			clay_overlay_text("Built with -define:CHEATS=true. Press 1-8 or Enter; Esc/Shift+C closes.", 14, eng.Engine_Color{180, 180, 180, 255})
			clay_spacer_fixed("cheats-gap", 1, 26)
			when CHEATS_ENABLED {
				for i in 0 ..< CHEAT_COMMAND_COUNT {
					command := cheat_command_for_index(i)
					prefix := ">" if i == choice else " "
					color := eng.Engine_Color{255, 220, 100, 255} if i == choice else eng.Engine_Color{220, 220, 220, 255}
					clay_overlay_text(fmt.tprintf("%s %d. %s", prefix, i + 1, cheat_command_label(command)), 18, color)
				}
			}
		}
	}

	clay_overlay_decl :: proc(color: eng.Engine_Color) -> clay.ElementDeclaration {
		return clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(f32(SCREEN_WIDTH)), height = clay.SizingFixed(f32(SCREEN_HEIGHT))},
				padding = clay.Padding{left = 32, right = 32, top = 48, bottom = 32},
				childGap = 10,
				childAlignment = {x = .Center, y = .Top},
				layoutDirection = .TopToBottom,
			},
			backgroundColor = clay_color(color),
		}
	}

	clay_title_text :: proc(text: string, size: u16, color: eng.Engine_Color) {
		clay_overlay_text(text, size, color)
	}

	clay_overlay_text :: proc(text: string, size: u16, color: eng.Engine_Color) {
		if clay.UI(clay.ID_LOCAL("overlay-text"))(
		clay.ElementDeclaration {layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}}},
		) {
			clay.TextDynamic(text, {textColor = clay_color(color), fontSize = size, lineHeight = size})
		}
	}

	clay_equipment_line :: proc(label: string, equipment: ^Equipment) {
		if equipment != nil && equipment.occupied {
			clay_overlay_text(fmt.tprintf("%s %s (+%d)", label, item_display_name(&equipment.item), equipment.item.stat_bonus), 15, eng.Engine_Color{200, 200, 200, 255})
		} else {
			clay_overlay_text(fmt.tprintf("%s ---", label), 15, eng.Engine_Color{100, 100, 100, 255})
		}
	}
