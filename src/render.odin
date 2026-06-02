package main

import rl "vendor:raylib"
import eng "./engine"

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(engine: ^eng.Engine, game: ^Game) {
	update_particles()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// Clip the map rendering to the viewport region so it doesn't bleed into HUD/messages
	rl.BeginScissorMode(0, 0, i32(SCREEN_WIDTH), i32(MAP_VIEW_HEIGHT))
	render_map(engine, game)
	render_webs(engine, game)
	render_items(engine, game)
	render_enemies(engine, game)
	render_player(engine, game)
	render_particles()
	rl.EndScissorMode()

	render_hud(game)
	render_messages(game)

	if game.ui.show_minimap && game.state == .Playing {
		render_minimap(game)
	}

	if game.state == .Title_Screen {
		render_title_screen(engine, game)
	}
	if game.state == .Playing {
		render_tooltip(game)
	}
	if game.state == .Game_Over {
		render_game_over(game)
	}
	if game.state == .Viewing_Inventory {
		render_inventory(engine, game)
	}
	if game.state == .Viewing_Crafting {
		render_crafting(game)
	}
	if game.state == .Viewing_Help {
		render_help(game)
	}
	if game.state == .Viewing_Scores {
		render_high_scores(game)
	}
	if game.state == .Victory {
		render_victory(game)
	}

	// Screen flash overlay (S02)
	if game.vfx.flash_alpha > 0.01 {
		alpha := u8(game.vfx.flash_alpha * 255.0)
		rl.DrawRectangle(
			0,
			0,
			i32(SCREEN_WIDTH),
			i32(SCREEN_HEIGHT),
			rl.Color{game.vfx.flash_color.r, game.vfx.flash_color.g, game.vfx.flash_color.b, alpha},
		)
		game.vfx.flash_alpha *= 0.85
		if game.vfx.flash_alpha < 0.01 {game.vfx.flash_alpha = 0}
	}

	rl.EndDrawing()
}
