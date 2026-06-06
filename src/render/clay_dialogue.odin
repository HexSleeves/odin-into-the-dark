package renderer

import gcore "../core"
import eng "../engine"
import ui_pkg "../ui"
import clay "libs:clay"

clay_render_dialogue_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	name, line, ok := gcore.dialogue_current_line(game)
	if !ok {return}

	if clay.UI(clay.ID("dialogue-overlay"))(clay_dialogue_decl()) {
		clay_text(name, CLAY_FONT_TITLE, eng.Engine_Color{230, 200, 120, 255})
		clay_text(line, CLAY_HUD_ROW_FONT, eng.Engine_Color{230, 230, 230, 255})
		clay_text("[SPACE] continue   [ESC] end", CLAY_HUD_ROW_FONT, ui_pkg.SB_DIM)
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
			offset = {40, f32(gcore.MAP_VIEW_HEIGHT) - 160},
			attachment = {element = .LeftTop, parent = .LeftTop},
		},
		backgroundColor = clay_color(eng.Engine_Color{20, 18, 12, 240}),
		cornerRadius = clay.CornerRadiusAll(6),
	}
}
