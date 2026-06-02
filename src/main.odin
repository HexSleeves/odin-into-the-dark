package main

import "core:fmt"

import rl "vendor:raylib"

// ─── Entry point ──────────────────────────────────────────────────────────────

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	audio_init()
	defer audio_cleanup()

	sprites_init()
	defer sprites_cleanup()

	// Load all external data files (enemies, items, player)
	if !data_load_all() {
		fmt.eprintln("[FATAL] Failed to load data files. Exiting.")
		return
	}

	game := game_init()
	defer game_destroy(game)

	if DEBUG_LOGS {
		fmt.printfln("Seed: %v", game.seed)
	}

	compute_fov(game)
	camera_update(game, snap = true)
	add_message(game, "Welcome to the depths. Tread carefully...", rl.Color{200, 200, 100, 255})

	// Disable default escape key to allow inventory to be closed with ESC
	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

	for !rl.WindowShouldClose() {
		handle_global_input(game, &game.input)

		// ── Update ──
		quit := false
		switch game.state {
		case .Title_Screen:
			quit = update_title_screen(game, &game.input)
		case .Playing:
			quit = update_playing(game, &game.input)
		case .Game_Over:
			quit = update_game_over(game, &game.input)
		case .Victory:
			quit = update_victory(game, &game.input)
		case .Viewing_Inventory:
			update_viewing_inventory(game, &game.input)
		case .Viewing_Crafting:
			update_viewing_crafting(game, &game.input)
		case .Viewing_Help:
			update_viewing_help(game, &game.input)
		case .Viewing_Scores:
			update_viewing_scores(game, &game.input)
		}
		if quit {
			break
		}

		// ── Draw ──
		render_game(game)
	}

	// ── Auto-save on quit if game is in progress ──
	if game.state == .Playing {
		save_game(game)
	}
}
