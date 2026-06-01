package main

import "core:fmt"

import rl "vendor:raylib"

@(private = "file")
death_sound_played: bool

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
		// ── F9: Load game (works from any state) ──
		if rl.IsKeyPressed(.F9) {
			if load_game(game) {
				death_sound_played = false
			} else {
				add_message(game, "No save file found.", rl.Color{255, 180, 50, 255})
			}
		}

		// ── Update ──
		quit := false
		switch game.state {
		case .Playing:
			quit = update_playing(game)
		case .Game_Over:
			quit = update_game_over(game)
		case .Victory:
			quit = update_victory(game)
		case .Viewing_Inventory:
			update_viewing_inventory(game)
		case .Viewing_Crafting:
			update_viewing_crafting(game)
		case .Viewing_Help:
			update_viewing_help(game)
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

// ─── Turn helpers ─────────────────────────────────────────────────────────────

advance_turn :: proc(game: ^Game, hp_before: int) {
	process_enemy_turns(game)
	process_enemy_abilities(game)
	remove_dead_enemies(game)
	tick_timed_effects(game)
	compute_fov(game)
	camera_update(game)
	if game.player.hp < hp_before {
		game.vfx.flash_color = rl.Color{255, 0, 0, 255}
		game.vfx.flash_alpha = 0.3
	}
}

save_run_score :: proc(game: ^Game) {
	game.score_saved = true
	table := load_scores()
	entry := Score_Entry {
		depth = game.depth,
		kills = game.kills,
		turns = game.turn_count,
		cause = game.death_cause,
	}
	game.last_score_rank = insert_score(&table, entry)
	save_scores(&table)
}

restart_game :: proc(game: ^Game) {
	game_cleanup(game)
	game^ = {}
	game_reinit(game)
	compute_fov(game)
	camera_update(game, snap = true)
	game.score_saved = false
	game.death_cause = ""
	game.last_score_rank = -1
	add_message(game, "A new journey begins...", rl.Color{200, 200, 100, 255})
}

// ─── Per-state update handlers ────────────────────────────────────────────────

update_playing :: proc(game: ^Game) -> (quit: bool) {
	if handle_forced_turn(game) {return}
	if handle_mining_input(game) {return}
	if handle_playing_hotkeys(game) {return}
	return handle_player_action(game)
}

handle_forced_turn :: proc(game: ^Game) -> bool {
	// Web: skip player's turn if stuck
	if game.skip_next_turn {
		game.skip_next_turn = false
		game.turn_count += 1
		hp_before := game.player.hp
		advance_turn(game, hp_before)
		add_message(game, "You break free from the web.", rl.Color{200, 200, 100, 255})
		return true
	}

	// Water: costs an extra turn
	if game.water_slow_active {
		game.water_slow_active = false
		game.turn_count += 1
		hp_before := game.player.hp
		advance_turn(game, hp_before)
		add_message(game, "You push through the water.", rl.Color{40, 80, 180, 255})
		return true
	}

	return false
}

handle_mining_input :: proc(game: ^Game) -> bool {
	if !game.ui.mining_mode {return false}

	if rl.IsKeyPressed(.ESCAPE) {
		game.ui.mining_mode = false
		add_message(game, "Mining cancelled.", rl.Color{180, 180, 180, 255})
		return true
	}

	mdx, mdy := read_cardinal_press()
	if mdx != 0 || mdy != 0 {
		game.ui.mining_mode = false
		if mine_wall(game, mdx, mdy) {
			play_sfx(.Mine)
			spawn_mine_particles(
				game.player.pos.x + mdx,
				game.player.pos.y + mdy,
				game.camera_x,
				game.camera_y,
			)
			hp_before := game.player.hp
			advance_turn(game, hp_before)
		}
	}

	return true
}

read_cardinal_press :: proc() -> (dx, dy: int) {
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {dy = -1}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {dy = 1}
	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {dx = -1}
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {dx = 1}
	return
}

handle_playing_hotkeys :: proc(game: ^Game) -> bool {
	// C key: open crafting if on anvil
	if rl.IsKeyPressed(.C) {
		cur := tile_at(game, game.player.pos.x, game.player.pos.y)
		if cur != nil && cur.type == .Anvil {
			game.state = .Viewing_Crafting
			return true
		}
		add_message(
			game,
			"You need to stand on an anvil to craft.",
			rl.Color{180, 180, 180, 255},
		)
	}

	// X key: enter mining mode
	if rl.IsKeyPressed(.X) {
		start_mining_mode(game)
		return true
	}

	// M key: toggle minimap
	if rl.IsKeyPressed(.M) {
		game.ui.show_minimap = !game.ui.show_minimap
	}

	// F1 key: toggle audio
	if rl.IsKeyPressed(.F1) {
		audio_toggle()
		if g_audio.enabled {
			add_message(game, "Sound: ON", rl.Color{180, 180, 180, 255})
		} else {
			add_message(game, "Sound: OFF", rl.Color{180, 180, 180, 255})
		}
	}

	// F2 key: toggle ASCII / Sprite mode
	if rl.IsKeyPressed(.F2) {
		game.ui.use_sprites = !game.ui.use_sprites
		if game.ui.use_sprites {
			add_message(game, "Render: SPRITES", rl.Color{180, 180, 180, 255})
		} else {
			add_message(game, "Render: ASCII", rl.Color{180, 180, 180, 255})
		}
	}

	// F5 key: save game
	if rl.IsKeyPressed(.F5) {
		if save_game(game) {
			add_message(game, "Game saved.", rl.Color{100, 255, 100, 255})
		} else {
			add_message(game, "Save failed!", rl.Color{255, 100, 100, 255})
		}
	}

	// G key: pick up item (instant, no turn cost)
	if rl.IsKeyPressed(.G) {
		if pickup_item(game) {
			play_sfx(.Pickup)
			spawn_pickup_particles(
				game.player.pos.x,
				game.player.pos.y,
				game.camera_x,
				game.camera_y,
			)
		}
	}

	// I key: open inventory screen
	if rl.IsKeyPressed(.I) {
		game.state = .Viewing_Inventory
		game.ui.inspect_slot = 0
		return true
	}

	// ? key: open help screen
	if (rl.IsKeyPressed(.SLASH) && rl.IsKeyDown(.LEFT_SHIFT)) ||
	   (rl.IsKeyPressed(.SLASH) && rl.IsKeyDown(.RIGHT_SHIFT)) {
		game.state = .Viewing_Help
		return true
	}

	return false
}

start_mining_mode :: proc(game: ^Game) {
	can_mine := false
	if !game.equipped_weapon.occupied {
		add_message(game, "You need a pickaxe to mine!", rl.Color{255, 100, 100, 255})
	} else if game.equipped_weapon.item.max_durability > 0 &&
	   game.equipped_weapon.item.durability <= 0 {
		add_message(
			game,
			fmt.tprintf("Your %s is broken!", game.equipped_weapon.item.name),
			rl.Color{255, 100, 100, 255},
		)
	} else {
		can_mine = true
	}

	if can_mine {
		game.ui.mining_mode = true
		add_message(
			game,
			"Mine which direction? (WASD/arrows, ESC cancel)",
			rl.Color{200, 200, 100, 255},
		)
	}
}

handle_player_action :: proc(game: ^Game) -> (quit: bool) {
	game.prev_player_pos = game.player.pos
	kills_before := game.kills
	result := handle_input(game)

	switch result {
	case .Quit:
		return true
	case .Moved:
		handle_player_moved(game, kills_before)
	case .Waited:
		hp_before := game.player.hp
		advance_turn(game, hp_before)
	case .Descended:
		handle_player_descended(game)
	case .None:
	}

	return false
}

handle_player_moved :: proc(game: ^Game, kills_before: int) {
	// Combat hit particles when a kill happened this turn
	if game.kills > kills_before {
		spawn_hit_particles(
			game.prev_player_pos.x,
			game.prev_player_pos.y,
			game.camera_x,
			game.camera_y,
		)
	}
	play_sfx(.Footstep)

	consume_web_if_present(game)
	apply_current_tile_effects(game)
	collapse_unstable_previous_tile(game)

	hp_before := game.player.hp
	advance_turn(game, hp_before)
	announce_item_under_player(game)
}

consume_web_if_present :: proc(game: ^Game) {
	pidx := pos_to_idx(game.player.pos.x, game.player.pos.y)
	if game.web_tiles[pidx] {
		game.web_tiles[pidx] = false
		game.skip_next_turn = true
		add_message(game, "You are stuck in a web!", rl.Color{180, 180, 180, 255})
	}
}

apply_current_tile_effects :: proc(game: ^Game) {
	cur_tile := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur_tile == nil {return}

	if cur_tile.type == .Water {
		game.water_slow_active = true
		play_sfx(.Water)
		add_message(game, "You wade through water...", rl.Color{40, 80, 180, 255})
	}

	if cur_tile.type == .Gas_Vent {
		game.player.hp -= 3
		game.vfx.flash_color = rl.Color{160, 180, 40, 255}
		game.vfx.flash_alpha = 0.4
		add_message(game, "Toxic gas burns you! (-3 HP)", rl.Color{160, 180, 40, 255})
		if game.player.hp <= 0 {
			game.death_cause = "Suffocated by toxic gas"
			game.state = .Game_Over
			add_message(game, "You have been slain...", rl.Color{255, 0, 0, 255})
		}
	}
}

collapse_unstable_previous_tile :: proc(game: ^Game) {
	if game.prev_player_pos.x == game.player.pos.x &&
	   game.prev_player_pos.y == game.player.pos.y {
		return
	}

	prev_tile := tile_at(game, game.prev_player_pos.x, game.prev_player_pos.y)
	if prev_tile != nil && prev_tile.type == .Unstable {
		prev_tile.type = .Chasm
		add_message(game, "The ground collapses behind you!", rl.Color{180, 120, 60, 255})
	}
}

announce_item_under_player :: proc(game: ^Game) {
	it := item_at(game, game.player.pos.x, game.player.pos.y)
	if it == nil {return}
	add_message(
		game,
		fmt.tprintf("You see a %s here.", item_display_name(it)),
		rl.Color{255, 255, 100, 255},
	)
}

handle_player_descended :: proc(game: ^Game) {
	play_sfx(.Descent)
	game.vfx.flash_color = rl.Color{255, 255, 255, 255}
	game.vfx.flash_alpha = 0.5
	hp_before := game.player.hp
	advance_turn(game, hp_before)
}

update_game_over :: proc(game: ^Game) -> (quit: bool) {
	if !death_sound_played {
		play_sfx(.Death)
		spawn_death_particles(
			game.player.pos.x,
			game.player.pos.y,
			game.camera_x,
			game.camera_y,
		)
		death_sound_played = true
	}
	if !game.score_saved {
		save_run_score(game)
	}
	if rl.IsKeyPressed(.R) {
		death_sound_played = false
		restart_game(game)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		return true
	}
	return
}

update_victory :: proc(game: ^Game) -> (quit: bool) {
	if !game.score_saved {
		game.death_cause = "Victory!"
		save_run_score(game)
	}
	if rl.IsKeyPressed(.R) {
		restart_game(game)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		return true
	}
	return
}

update_viewing_inventory :: proc(game: ^Game) {
	// I or Escape closes inventory (reset drop/equip mode)
	if rl.IsKeyPressed(.I) || rl.IsKeyPressed(.ESCAPE) {
		game.state = .Playing
		game.ui.dropping = false
		game.ui.equipping = false
		game.ui.inspect_slot = -1
	}
	// Up/Down arrows to move inspect cursor (0-8 = inventory, 9/10/11 = weapon/armor/helmet)
	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		game.ui.inspect_slot = max(game.ui.inspect_slot - 1, 0)
	}
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		game.ui.inspect_slot = min(game.ui.inspect_slot + 1, MAX_INVENTORY + 2)
	}
	// D key toggles drop mode
	if rl.IsKeyPressed(.D) {
		game.ui.dropping = !game.ui.dropping
		game.ui.equipping = false
	}
	// E key toggles equip mode
	if rl.IsKeyPressed(.E) {
		game.ui.equipping = !game.ui.equipping
		game.ui.dropping = false
	}
	// Number keys 1-9 to use, drop, or equip items
	keys := [9]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE}
	for key, idx in keys {
		if rl.IsKeyPressed(key) {
			if game.ui.dropping {
				drop_item(game, idx)
				game.ui.dropping = false
			} else if game.ui.equipping {
				equip_item(game, idx)
				game.ui.equipping = false
			} else {
				use_item(game, idx)
			}
		}
	}
}

update_viewing_crafting :: proc(game: ^Game) {
	// ESC or C closes crafting
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.C) {
		game.state = .Playing
	}
	// Number keys 1-4 to craft
	if rl.IsKeyPressed(.ONE) {try_craft(game, 0)}
	if rl.IsKeyPressed(.TWO) {try_craft(game, 1)}
	if rl.IsKeyPressed(.THREE) {try_craft(game, 2)}
	if rl.IsKeyPressed(.FOUR) {try_craft(game, 3)}
}

update_viewing_help :: proc(game: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.SLASH) {
		game.state = .Playing
	}
}
