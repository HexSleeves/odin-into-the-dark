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
		case .Title_Screen:
			quit = update_title_screen(game)
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
		case .Viewing_Scores:
			update_viewing_scores(game)
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

TITLE_OPTION_COUNT :: 5
TITLE_NEW_GAME :: 0
TITLE_CONTINUE :: 1
TITLE_HIGH_SCORES :: 2
TITLE_HELP :: 3
TITLE_QUIT :: 4

update_title_screen :: proc(game: ^Game) -> (quit: bool) {
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		game.ui.title_choice = (game.ui.title_choice + TITLE_OPTION_COUNT - 1) % TITLE_OPTION_COUNT
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		game.ui.title_choice = (game.ui.title_choice + 1) % TITLE_OPTION_COUNT
	}

	if rl.IsKeyPressed(.N) {
		game.ui.title_choice = TITLE_NEW_GAME
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.C) {
		game.ui.title_choice = TITLE_CONTINUE
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.H) {
		game.ui.title_choice = TITLE_HIGH_SCORES
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.SLASH) && (rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)) {
		game.ui.title_choice = TITLE_HELP
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.Q) || rl.IsKeyPressed(.ESCAPE) {
		return true
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		return activate_title_choice(game)
	}

	return false
}

activate_title_choice :: proc(game: ^Game) -> (quit: bool) {
	switch game.ui.title_choice {
	case TITLE_NEW_GAME:
		death_sound_played = false
		restart_game(game)
	case TITLE_CONTINUE:
		if save_exists() {
			if load_game(game) {
				death_sound_played = false
			} else {
				add_message(game, "Save file could not be loaded.", rl.Color{255, 180, 50, 255})
			}
		}
	case TITLE_HIGH_SCORES:
		game.state = .Viewing_Scores
	case TITLE_HELP:
		game.ui.return_to_title = true
		game.state = .Viewing_Help
	case TITLE_QUIT:
		return true
	}
	return false
}

update_playing :: proc(game: ^Game) -> (quit: bool) {
	if handle_forced_turn(game) {return}
	if handle_mining_input(game) {return}
	if handle_playing_hotkeys(game) {return}
	return handle_player_action(game)
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
	if game.prev_player_pos.x == game.player.pos.x && game.prev_player_pos.y == game.player.pos.y {
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


update_game_over :: proc(game: ^Game) -> (quit: bool) {
	if !death_sound_played {
		play_sfx(.Death)
		spawn_death_particles(game.player.pos.x, game.player.pos.y, game.camera_x, game.camera_y)
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
		if game.ui.return_to_title {
			game.ui.return_to_title = false
			game.state = .Title_Screen
		} else {
			game.state = .Playing
		}
	}
}

update_viewing_scores :: proc(game: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.H) {
		game.state = .Title_Screen
	}
}
