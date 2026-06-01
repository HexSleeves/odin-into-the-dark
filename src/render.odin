package main

import rl "vendor:raylib"

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(game: ^Game) {
	update_particles()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// Clip the map rendering to the viewport region so it doesn't bleed into HUD/messages
	rl.BeginScissorMode(0, 0, i32(SCREEN_WIDTH), i32(MAP_VIEW_HEIGHT))
	render_map(game)
	render_webs(game)
	render_items(game)
	render_enemies(game)
	render_player(game)
	render_particles()
	rl.EndScissorMode()

	render_hud(game)
	render_messages(game)

	if game.show_minimap && game.state == .Playing {
		render_minimap(game)
	}

	if game.state == .Playing {
		render_tooltip(game)
	}
	if game.state == .Game_Over {
		render_game_over(game)
	}
	if game.state == .Viewing_Inventory {
		render_inventory(game)
	}
	if game.state == .Viewing_Crafting {
		render_crafting(game)
	}
	if game.state == .Viewing_Help {
		render_help(game)
	}

	// Screen flash overlay (S02)
	if game.flash_alpha > 0.01 {
		alpha := u8(game.flash_alpha * 255.0)
		rl.DrawRectangle(
			0,
			0,
			i32(SCREEN_WIDTH),
			i32(SCREEN_HEIGHT),
			rl.Color{game.flash_color.r, game.flash_color.g, game.flash_color.b, alpha},
		)
		game.flash_alpha *= 0.85
		if game.flash_alpha < 0.01 {game.flash_alpha = 0}
	}

	rl.EndDrawing()
}
