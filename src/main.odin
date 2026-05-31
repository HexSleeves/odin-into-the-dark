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
	camera_update(game)
	add_message(game, "Welcome to the depths. Tread carefully...", rl.Color{200, 200, 100, 255})

	// Disable default escape key to allow inventory to be closed with ESC
	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

	for !rl.WindowShouldClose() {
		// ── Update ──
		if game.state == .Playing {
			// G key: pick up item (instant, no turn cost)
			if rl.IsKeyPressed(.G) {
				pickup_item(game)
			}

			// I key: open inventory screen
			if rl.IsKeyPressed(.I) {
				game.state = .Viewing_Inventory
			}

			result := handle_input(game)
			if result == .Quit {
				break
			}
			if result == .Moved {
				process_enemy_turns(game)
				remove_dead_enemies(game)
				compute_fov(game)
				camera_update(game)

				// Announce item on player's tile
				it := item_at(game, game.player.pos.x, game.player.pos.y)
				if it != nil {
					add_message(
						game,
						fmt.tprintf("You see a %s here.", item_type_name(it.item_type)),
						rl.Color{255, 255, 100, 255},
					)
				}
			}
			if result == .Waited {
				process_enemy_turns(game)
				remove_dead_enemies(game)
				compute_fov(game)
				camera_update(game)
			}
		} else if game.state == .Game_Over {
			if rl.IsKeyPressed(.R) {
				game_cleanup(game)
				game^ = {}
				game_reinit(game)
				compute_fov(game)
				camera_update(game)
				add_message(game, "A new journey begins...", rl.Color{200, 200, 100, 255})
			}
			if rl.IsKeyPressed(.ESCAPE) {
				break
			}
		} else if game.state == .Viewing_Inventory {
			// I or Escape closes inventory
			if rl.IsKeyPressed(.I) || rl.IsKeyPressed(.ESCAPE) {
				game.state = .Playing
			}
			// Number keys 1-9 to use items
			keys := [9]rl.KeyboardKey {
				.ONE,
				.TWO,
				.THREE,
				.FOUR,
				.FIVE,
				.SIX,
				.SEVEN,
				.EIGHT,
				.NINE,
			}
			for key, idx in keys {
				if rl.IsKeyPressed(key) {
					use_item(game, idx)
				}
			}
		}

		// ── Draw ──
		render_game(game)
	}
}
