package main

import "core:fmt"

import rl "vendor:raylib"

// ─── Entry point ──────────────────────────────────────────────────────────────

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Load all external data files (enemies, items, player)
	if !data_load_all() {
		fmt.eprintln("[FATAL] Failed to load data files. Exiting.")
		return
	}

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
			// Web: skip player's turn if stuck
			if game.skip_next_turn {
				game.skip_next_turn = false
				game.turn_count += 1
				process_enemy_turns(game)
				process_enemy_abilities(game)
				remove_dead_enemies(game)
				tick_timed_effects(game)
				compute_fov(game)
				camera_update(game)
				add_message(game, "You break free from the web.", rl.Color{200, 200, 100, 255})
			} else if game.water_slow_active {
				// Water: costs an extra turn
				game.water_slow_active = false
				game.turn_count += 1
				process_enemy_turns(game)
				process_enemy_abilities(game)
				remove_dead_enemies(game)
				tick_timed_effects(game)
				compute_fov(game)
				camera_update(game)
				add_message(game, "You push through the water.", rl.Color{40, 80, 180, 255})
			} else {
			// M key: toggle minimap
			if rl.IsKeyPressed(.M) {
				game.show_minimap = !game.show_minimap
			}

			// G key: pick up item (instant, no turn cost)
			if rl.IsKeyPressed(.G) {
				pickup_item(game)
			}

			// I key: open inventory screen
			if rl.IsKeyPressed(.I) {
				game.state = .Viewing_Inventory
			}

			game.prev_player_pos = game.player.pos
			result := handle_input(game)
			if result == .Quit {
				break
			}
			if result == .Moved {
				// Check if player stepped on web
				pidx := pos_to_idx(game.player.pos.x, game.player.pos.y)
				if game.web_tiles[pidx] {
					game.web_tiles[pidx] = false // consume the web
					game.skip_next_turn = true
					add_message(game, "You are stuck in a web!", rl.Color{180, 180, 180, 255})
				}

				// Hazard tile effects
				cur_tile := tile_at(game, game.player.pos.x, game.player.pos.y)
				if cur_tile != nil {
					if cur_tile.type == .Water {
						game.water_slow_active = true
						add_message(game, "You wade through water...", rl.Color{40, 80, 180, 255})
					}
					if cur_tile.type == .Gas_Vent {
						game.player.hp -= 2
						add_message(game, "Toxic gas burns you! (-2 HP)", rl.Color{160, 180, 40, 255})
						if game.player.hp <= 0 {
							game.state = .Game_Over
							add_message(game, "You have been slain...", rl.Color{255, 0, 0, 255})
						}
					}
				}

				// Unstable collapse: previous tile collapses into chasm
				if game.prev_player_pos.x != game.player.pos.x || game.prev_player_pos.y != game.player.pos.y {
					prev_tile := tile_at(game, game.prev_player_pos.x, game.prev_player_pos.y)
					if prev_tile != nil && prev_tile.type == .Unstable {
						prev_tile.type = .Chasm
						add_message(game, "The ground collapses behind you!", rl.Color{180, 120, 60, 255})
					}
				}

				process_enemy_turns(game)
				process_enemy_abilities(game)
				remove_dead_enemies(game)
				tick_timed_effects(game)
				compute_fov(game)
				camera_update(game)

				// Announce item on player's tile
				it := item_at(game, game.player.pos.x, game.player.pos.y)
				if it != nil {
					add_message(
						game,
						fmt.tprintf("You see a %s here.", item_display_name(it)),
						rl.Color{255, 255, 100, 255},
					)
				}
			}
			if result == .Waited {
				process_enemy_turns(game)
				process_enemy_abilities(game)
				remove_dead_enemies(game)
				tick_timed_effects(game)
				compute_fov(game)
				camera_update(game)
			}
			} // end else (not skip_next_turn)
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
			// I or Escape closes inventory (reset drop/equip mode)
			if rl.IsKeyPressed(.I) || rl.IsKeyPressed(.ESCAPE) {
				game.state = .Playing
				game.dropping = false
				game.equipping = false
			}
			// D key toggles drop mode
			if rl.IsKeyPressed(.D) {
				game.dropping = !game.dropping
				game.equipping = false
			}
			// E key toggles equip mode
			if rl.IsKeyPressed(.E) {
				game.equipping = !game.equipping
				game.dropping = false
			}
			// Number keys 1-9 to use, drop, or equip items
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
					if game.dropping {
						drop_item(game, idx)
						game.dropping = false
					} else if game.equipping {
						equip_item(game, idx)
						game.equipping = false
					} else {
						use_item(game, idx)
					}
				}
			}
		}

		// ── Draw ──
		render_game(game)
	}
}
