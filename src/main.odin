package main

import "core:fmt"

import rl "vendor:raylib"

// ─── Entry point ──────────────────────────────────────────────────────────────

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	game := game_init()
	defer game_destroy(game)

	fmt.printfln("Seed: %v", game.seed)

	compute_fov(game)
	add_message(game, "Welcome to the depths. Tread carefully...", rl.Color{200, 200, 100, 255})

	for !rl.WindowShouldClose() {
		// ── Update ──
		if game.state == .Playing {
			result := handle_input(game)
			if result == .Quit {
				break
			}
			if result == .Moved {
				process_enemy_turns(game)
				remove_dead_enemies(game)
				compute_fov(game)
			}
		} else if game.state == .Game_Over {
			if rl.IsKeyPressed(.R) {
				game_cleanup(game)
				game^ = {}
				game_reinit(game)
				compute_fov(game)
				add_message(game, "A new journey begins...", rl.Color{200, 200, 100, 255})
			}
			if rl.IsKeyPressed(.ESCAPE) {
				break
			}
		}

		// ── Draw ──
		render_game(game)
	}
}
