package renderer

import gcore "../core"
import eng "../engine"
import ui_pkg "../ui"
import "core:fmt"
import clay "libs:clay"

clay_render_dialogue_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	content := game_engine_content_manager(engine)
	speaker, text, choices, ok := gcore.dialogue_current_line(content, game)
	if !ok {return}

	if clay.UI(clay.ID("dialogue-overlay"))(clay_dialogue_decl()) {
		clay_menu_title(speaker, ui_pkg.SB_TITLE, CLAY_FONT_TITLE)
		clay_menu_accent_rule("dialogue-rule")
		clay_text(text, CLAY_HUD_ROW_FONT, ui_pkg.SB_TEXT)

		if len(choices) > 0 {
			// Render numbered choice list
			for choice, i in choices {
				marker := "  "
				if i == game.dialogue_choice {marker = "> "}
				label := fmt.tprintf("%s%d. %s", marker, i + 1, choice.text)
				color := ui_pkg.SB_DIM if i != game.dialogue_choice else ui_pkg.SB_TEXT
				clay_text(label, CLAY_HUD_ROW_FONT, color)
			}
			clay_menu_footer("dialogue-footer", "[W/S] select   [SPACE] confirm   [ESC] end")
		} else {
			clay_menu_footer("dialogue-footer", "[SPACE] continue   [ESC] end")
		}
	}
}

// Dialogue box anchored to the bottom-center of the screen (above the message log).
@(private = "file")
clay_dialogue_decl :: proc() -> clay.ElementDeclaration {
	return clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingFixed(f32(gcore.MAP_VIEW_WIDTH) - 80),
				height = clay.SizingFit({}),
			},
			padding = clay.Padding{left = 20, right = 20, top = 16, bottom = 16},
			childGap = 8,
			layoutDirection = .TopToBottom,
		},
		floating = {
			attachTo = .Root,
			offset = {40, f32(gcore.MAP_VIEW_HEIGHT) - 200},
			attachment = {element = .LeftTop, parent = .LeftTop},
		},
		backgroundColor = clay_color(ui_pkg.SB_PANEL),
		border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {1, 1, 1, 1, 0}},
		cornerRadius = {3, 3, 3, 3},
	}
}
