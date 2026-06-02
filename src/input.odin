package main

import rl "vendor:raylib"

// ─── Input result ─────────────────────────────────────────────────────────────

Input_Result :: enum {
	None,       // no action taken
	Moved,      // player moved — turn consumed
	Descended,  // player descended to next floor
	Waited,     // player skipped a turn (period key)
	Quit,       // escape pressed — signal to close
}

read_cardinal_press :: proc(im: ^Input_Manager) -> (dx, dy: int) {
	if action_pressed(im, .Move_North) {dy = -1}
	if action_pressed(im, .Move_South) {dy = 1}
	if action_pressed(im, .Move_East)  {dx = 1}
	if action_pressed(im, .Move_West)  {dx = -1}
	return
}

// ─── Input handling ───────────────────────────────────────────────────────────

handle_input :: proc(game: ^Game, im: ^Input_Manager) -> Input_Result {
	if action_pressed(im, .Quit) {
		return .Quit
	}

	if action_pressed(im, .Wait) {
		game.turn_count += 1
		add_message(game, "You wait...", rl.Color{180, 180, 180, 255})
		return .Waited
	}

	// Four independent repeat states — direction change fires immediately
	fired_n := check_repeat(im, .Move_North)
	fired_s := check_repeat(im, .Move_South)
	fired_e := check_repeat(im, .Move_East)
	fired_w := check_repeat(im, .Move_West)

	dx, dy: int
	if fired_n {dy = -1}
	if fired_s {dy = 1}
	if fired_e {dx = 1}
	if fired_w {dx = -1}

	if dx == 0 && dy == 0 {
		return .None
	}

	target_x := game.player.pos.x + dx
	target_y := game.player.pos.y + dy

	if !is_walkable(game, target_x, target_y) {
		return .None
	}

	target_enemy := enemy_at(game, target_x, target_y)
	if target_enemy != nil {
		resolve_attack_player_on_enemy(game, target_enemy)
		game.turn_count += 1
		return .Moved
	}

	game.player.pos.x = target_x
	game.player.pos.y = target_y
	game.turn_count += 1

	t := tile_at(game, target_x, target_y)
	if t != nil && t.type == .Descent {
		descend(game)
		return .Descended
	}

	return .Moved
}

handle_forced_turn :: proc(game: ^Game) -> bool {
	if game.skip_next_turn {
		game.skip_next_turn = false
		game.turn_count += 1
		hp_before := game.player.hp
		advance_turn(game, hp_before)
		add_message(game, "You break free from the web.", rl.Color{200, 200, 100, 255})
		return true
	}

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

handle_mining_input :: proc(game: ^Game, im: ^Input_Manager) -> bool {
	if !game.ui.mining_mode {return false}

	if action_pressed(im, .Quit) {
		game.ui.mining_mode = false
		add_message(game, "Mining cancelled.", rl.Color{180, 180, 180, 255})
		return true
	}

	mdx, mdy := read_cardinal_press(im)
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

handle_playing_hotkeys :: proc(game: ^Game, im: ^Input_Manager) -> bool {
	if action_pressed(im, .Crafting) {
		cur := tile_at(game, game.player.pos.x, game.player.pos.y)
		if cur != nil && cur.type == .Anvil {
			game.state = .Viewing_Crafting
			return true
		}
		add_message(game, "You need to stand on an anvil to craft.", rl.Color{180, 180, 180, 255})
	}

	if action_pressed(im, .Mine) {
		start_mining_mode(game)
		return true
	}

	if action_pressed(im, .Toggle_Map) {
		game.ui.show_minimap = !game.ui.show_minimap
	}

	if action_pressed(im, .Toggle_Audio) {
		audio_toggle()
		if g_audio.enabled {
			add_message(game, "Sound: ON", rl.Color{180, 180, 180, 255})
		} else {
			add_message(game, "Sound: OFF", rl.Color{180, 180, 180, 255})
		}
	}

	if action_pressed(im, .Toggle_Sprites) {
		game.ui.use_sprites = !game.ui.use_sprites
		if game.ui.use_sprites {
			add_message(game, "Render: SPRITES", rl.Color{180, 180, 180, 255})
		} else {
			add_message(game, "Render: ASCII", rl.Color{180, 180, 180, 255})
		}
	}

	if action_pressed(im, .Save) {
		if save_game(game) {
			add_message(game, "Game saved.", rl.Color{100, 255, 100, 255})
		} else {
			add_message(game, "Save failed!", rl.Color{255, 100, 100, 255})
		}
	}

	if action_pressed(im, .Pickup) {
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

	if action_pressed(im, .Inventory) {
		game.state = .Viewing_Inventory
		game.ui.inspect_slot = 0
		return true
	}

	if action_pressed(im, .Help) {
		game.ui.return_to_title = false
		game.state = .Viewing_Help
		return true
	}

	return false
}

// ─── Per-state update handlers ────────────────────────────────────────────────

@(private = "file")
death_sound_played: bool

TITLE_OPTION_COUNT :: 5
TITLE_NEW_GAME :: 0
TITLE_CONTINUE :: 1
TITLE_HIGH_SCORES :: 2
TITLE_HELP :: 3
TITLE_QUIT :: 4

update_title_screen :: proc(game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if action_pressed(im, .Menu_Up) {
		game.ui.title_choice = (game.ui.title_choice + TITLE_OPTION_COUNT - 1) % TITLE_OPTION_COUNT
	}
	if action_pressed(im, .Menu_Down) {
		game.ui.title_choice = (game.ui.title_choice + 1) % TITLE_OPTION_COUNT
	}

	if action_pressed(im, .Menu_New_Game) {
		game.ui.title_choice = TITLE_NEW_GAME
		return activate_title_choice(game)
	}
	if action_pressed(im, .Menu_Continue) {
		game.ui.title_choice = TITLE_CONTINUE
		return activate_title_choice(game)
	}
	if action_pressed(im, .Menu_High_Scores) {
		game.ui.title_choice = TITLE_HIGH_SCORES
		return activate_title_choice(game)
	}
	if action_pressed(im, .Help) {
		game.ui.title_choice = TITLE_HELP
		return activate_title_choice(game)
	}
	if action_pressed(im, .Menu_Quit) || action_pressed(im, .Menu_Back) {
		return true
	}
	if action_pressed(im, .Menu_Confirm) {
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

handle_global_input :: proc(game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Load) {
		if load_game(game) {
			death_sound_played = false
		} else {
			add_message(game, "No save file found.", rl.Color{255, 180, 50, 255})
		}
	}
}

update_playing :: proc(game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if handle_forced_turn(game) {return}
	if handle_mining_input(game, im) {return}
	if handle_playing_hotkeys(game, im) {return}
	return handle_player_action(game)
}

update_game_over :: proc(game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if !death_sound_played {
		play_sfx(.Death)
		spawn_death_particles(game.player.pos.x, game.player.pos.y, game.camera_x, game.camera_y)
		death_sound_played = true
	}
	if !game.score_saved {
		save_run_score(game)
	}
	if action_pressed(im, .Restart) {
		death_sound_played = false
		restart_game(game)
	}
	if action_pressed(im, .Quit) {
		return true
	}
	return
}

update_victory :: proc(game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if !game.score_saved {
		game.death_cause = "Victory!"
		save_run_score(game)
	}
	if action_pressed(im, .Restart) {
		restart_game(game)
	}
	if action_pressed(im, .Quit) {
		return true
	}
	return
}

update_viewing_inventory :: proc(game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Inventory) || action_pressed(im, .Menu_Back) {
		game.state = .Playing
		game.ui.dropping = false
		game.ui.equipping = false
		game.ui.inspect_slot = -1
	}
	if action_pressed(im, .Menu_Up) {
		game.ui.inspect_slot = max(game.ui.inspect_slot - 1, 0)
	}
	if action_pressed(im, .Menu_Down) {
		game.ui.inspect_slot = min(game.ui.inspect_slot + 1, MAX_INVENTORY + 2)
	}
	if action_pressed(im, .Inv_Drop_Mode) {
		game.ui.dropping = !game.ui.dropping
		game.ui.equipping = false
	}
	if action_pressed(im, .Inv_Equip_Mode) {
		game.ui.equipping = !game.ui.equipping
		game.ui.dropping = false
	}
	inv_actions := [9]Game_Action{
		.Inv_Slot_1, .Inv_Slot_2, .Inv_Slot_3,
		.Inv_Slot_4, .Inv_Slot_5, .Inv_Slot_6,
		.Inv_Slot_7, .Inv_Slot_8, .Inv_Slot_9,
	}
	for act, idx in inv_actions {
		if action_pressed(im, act) {
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

update_viewing_crafting :: proc(game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Menu_Back) || action_pressed(im, .Crafting) {
		game.state = .Playing
	}
	if action_pressed(im, .Craft_1) {try_craft(game, 0)}
	if action_pressed(im, .Craft_2) {try_craft(game, 1)}
	if action_pressed(im, .Craft_3) {try_craft(game, 2)}
	if action_pressed(im, .Craft_4) {try_craft(game, 3)}
}

update_viewing_help :: proc(game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Menu_Back) || action_pressed(im, .Help) {
		if game.ui.return_to_title {
			game.ui.return_to_title = false
			game.state = .Title_Screen
		} else {
			game.state = .Playing
		}
	}
}

update_viewing_scores :: proc(game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Menu_Back) || action_pressed(im, .Menu_High_Scores) {
		game.state = .Title_Screen
	}
}
