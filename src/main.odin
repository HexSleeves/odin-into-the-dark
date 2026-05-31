package main

import "core:fmt"

import rl "vendor:raylib"

// ─── Entry point ──────────────────────────────────────────────────────────────

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	game := game_init()
	defer game_destroy(&game)

	// Seed is already printed by game_init; echo in main for visibility.
	fmt.printfln("Seed: %v", game.seed)

	for !rl.WindowShouldClose() {
		// ── Update ──
		if game.state == .Playing {
			result := handle_input(&game)
			if result == .Quit {
				break
			}
		}

		// ── Draw ──
		render_game(&game)
	}
}
