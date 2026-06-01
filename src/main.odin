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
			// Mining mode takes priority over all other input
			if game.mining_mode {
				if rl.IsKeyPressed(.ESCAPE) {
					game.mining_mode = false
					add_message(game, "Mining cancelled.", rl.Color{180, 180, 180, 255})
				} else {
					mdx, mdy: int
					if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP)    { mdy = -1 }
					if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN)  { mdy = 1 }
					if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT)  { mdx = -1 }
					if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) { mdx = 1 }

					if mdx != 0 || mdy != 0 {
						game.mining_mode = false
						if mine_wall(game, mdx, mdy) {
							process_enemy_turns(game)
							process_enemy_abilities(game)
							remove_dead_enemies(game)
							tick_timed_effects(game)
							compute_fov(game)
							camera_update(game)
						}
					}
				}
			} else {
			// C key: open crafting if on anvil
			if rl.IsKeyPressed(.C) {
				cur := tile_at(game, game.player.pos.x, game.player.pos.y)
				if cur != nil && cur.type == .Anvil {
					game.state = .Viewing_Crafting
				} else {
					add_message(game, "You need to stand on an anvil to craft.", rl.Color{180, 180, 180, 255})
				}
			}

			// X key: enter mining mode
			if rl.IsKeyPressed(.X) {
				can_mine := false
				if !game.equipped_weapon.occupied {
					add_message(game, "You need a pickaxe to mine!", rl.Color{255, 100, 100, 255})
				} else if game.equipped_weapon.item.max_durability > 0 && game.equipped_weapon.item.durability <= 0 {
					add_message(game, fmt.tprintf("Your %s is broken!", game.equipped_weapon.item.name), rl.Color{255, 100, 100, 255})
				} else {
					can_mine = true
				}
				if can_mine {
					game.mining_mode = true
					add_message(game, "Mine which direction? (WASD/arrows, ESC cancel)", rl.Color{200, 200, 100, 255})
				}
			}

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
				game.inspect_slot = 0
			}

			// ? key: open help screen
			if rl.IsKeyPressed(.SLASH) && rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyPressed(.SLASH) && rl.IsKeyDown(.RIGHT_SHIFT) {
				game.state = .Viewing_Help
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
						game.player.hp -= 3
						add_message(game, "Toxic gas burns you! (-3 HP)", rl.Color{160, 180, 40, 255})
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
			} // end else (not mining_mode)
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
				game.inspect_slot = -1
			}
			// Up/Down arrows to move inspect cursor (0-8 = inventory, 9/10/11 = weapon/armor/helmet)
			if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
				game.inspect_slot = max(game.inspect_slot - 1, 0)
			}
			if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
				game.inspect_slot = min(game.inspect_slot + 1, MAX_INVENTORY + 2) // 9=weapon, 10=armor, 11=helmet
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
		} else if game.state == .Viewing_Crafting {
			// ESC or C closes crafting
			if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.C) {
				game.state = .Playing
			}

			// Number keys 1-4 to craft
			if rl.IsKeyPressed(.ONE)   { try_craft(game, 0) }
			if rl.IsKeyPressed(.TWO)   { try_craft(game, 1) }
			if rl.IsKeyPressed(.THREE) { try_craft(game, 2) }
			if rl.IsKeyPressed(.FOUR)  { try_craft(game, 3) }
		} else if game.state == .Viewing_Help {
			if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.SLASH) {
				game.state = .Playing
			}
		}

		// ── Draw ──
		render_game(game)
	}
}
