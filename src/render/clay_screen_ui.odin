package renderer

import ui_pkg "../ui"

import gcore "../core"

import eng "../engine"
import clay "libs:clay"

@(private = "file")
clay_screen_ui_import_anchor :: proc() {
	_ = eng.Engine{}
	_ = clay.ElementDeclaration{}
}

clay_render_screen_ui :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	if game == nil {
		return
	}

	if clay.UI(clay.ID("screen-ui-root"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingFixed(f32(gcore.SCREEN_WIDTH)),
				height = clay.SizingFixed(f32(gcore.SCREEN_HEIGHT)),
			},
			layoutDirection = .TopToBottom,
		},
	},
	) {
		#partial switch game.state {
		case .Title_Screen:
			clay_render_title_overlay(engine, game)
		case .Playing:
			clay_render_gameplay_ui(engine, game)
		case .Viewing_Inventory:
			clay_render_gameplay_ui(engine, game)
			clay_render_inventory_overlay(engine, game)
		case .Viewing_Crafting:
			clay_render_gameplay_ui(engine, game)
			clay_render_crafting_overlay(engine, game)
		case .Viewing_Cheats:
			clay_render_gameplay_ui(engine, game)
			clay_render_cheats_overlay(engine, game)
		case .Pause:
			clay_render_gameplay_ui(engine, game)
			clay_render_pause_overlay(engine, game)
		case .Viewing_Help:
			clay_render_help_overlay(engine, game)
		case .Viewing_Scores:
			clay_render_scores_overlay(engine, game)
		case .Game_Over:
			clay_render_game_over_overlay(engine, game)
		case .Victory:
			clay_render_victory_overlay(engine, game)
		case .Viewing_Shrine:
			clay_render_gameplay_ui(engine, game)
			clay_render_shrine_overlay(engine, game)
		case .Viewing_Chest:
			clay_render_gameplay_ui(engine, game)
		case .Viewing_Merchant:
			clay_render_gameplay_ui(engine, game)
			clay_render_merchant_overlay(engine, game)
		case .Viewing_Dialogue:
			clay_render_gameplay_ui(engine, game)
			clay_render_dialogue_overlay(engine, game)
		case .Viewing_Level_Up:
			clay_render_gameplay_ui(engine, game)
			clay_render_level_up_overlay(engine, game)
		}
	}
}

@(private = "file")
clay_render_gameplay_ui :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	clay_render_hud(engine, game)
	if engine == nil || engine.services == nil {
		return
	}
	clay_render_messages(game_engine_message_manager(engine))
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	if ui != nil && ui.show_minimap {
		clay_render_minimap(game)
	}
	clay_render_tooltip(engine, game)
	clay_render_gameplay_hints(engine, game)
}
