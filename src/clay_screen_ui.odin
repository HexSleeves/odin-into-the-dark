package main

import eng "./engine"
import clay "./vendor/clay"

@(private = "file")
clay_screen_ui_import_anchor :: proc() {
	_ = eng.Engine{}
	_ = clay.ElementDeclaration{}
}

when USE_CLAY {
	clay_render_screen_ui :: proc(engine: ^eng.Engine, game: ^Game) {
		if game == nil {
			return
		}

		if clay.UI(clay.ID("screen-ui-root"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingFixed(f32(SCREEN_WIDTH)),
					height = clay.SizingFixed(f32(SCREEN_HEIGHT)),
				},
				layoutDirection = .TopToBottom,
			},
		},
		) {
			#partial switch game.state {
			case .Playing:
				clay_render_gameplay_ui(engine, game)
			case .Title_Screen, .Viewing_Help, .Viewing_Scores:
				// Future Clay screens intentionally route through the dispatcher but remain
				// legacy-rendered until their migration tasks are implemented.
			}
		}
	}

	@(private = "file")
	clay_render_gameplay_ui :: proc(engine: ^eng.Engine, game: ^Game) {
		clay_render_hud(engine, game)
	}
}
