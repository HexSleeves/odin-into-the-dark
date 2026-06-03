package main

import eng "./engine"
import "core:fmt"

// ─── Input result ─────────────────────────────────────────────────────────────

Input_Result :: enum {
	None, // no action taken
	Moved, // player moved — turn consumed
	Descended, // player descended to next floor
	Waited, // player skipped a turn (period key)
	Quit, // escape pressed — signal to close
}

read_cardinal_press :: proc(im: ^Input_Manager) -> (dx, dy: int) {
	if action_pressed(im, .Move_North) {dy = -1}
	if action_pressed(im, .Move_South) {dy = 1}
	if action_pressed(im, .Move_East) {dx = 1}
	if action_pressed(im, .Move_West) {dx = -1}
	return
}

// ─── Input handling ───────────────────────────────────────────────────────────

handle_input :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	im: ^Input_Manager,
	engine: ^eng.Engine = nil,
) -> Input_Result {
	if action_pressed(im, .Quit) {
		return .Quit
	}

	if action_pressed(im, .Wait) {
		// Deduct AP; trigger_enemy_rounds fires in handle_player_action
		game.player.energy -= BASE_ACTION_COST
		add_message(messages, game, "You wait...", eng.Engine_Color{180, 180, 180, 255})
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
		// Check if bumping into a locked door with a key
		t := tile_at(game, target_x, target_y)
		if t != nil && t.type == .Locked_Door {
			if remove_item_from_inventory(game, "vault_key") {
				t.type = .Floor
				add_message(
					messages,
					game,
					"You unlock the door with the Vault Key!",
					eng.Engine_Color{255, 215, 0, 255},
				)
				game.player.energy -= BASE_ACTION_COST
				return .Moved
			} else {
				add_message(
					messages,
					game,
					"The door is locked. You need a key.",
					eng.Engine_Color{180, 180, 180, 255},
				)
			}
		}
		return .None
	}

	target_enemy := enemy_at(game, target_x, target_y)
	if target_enemy != nil {
		resolve_attack_player_on_enemy(messages, game, target_enemy)
		// Deduct weapon-specific AP cost; trigger_enemy_rounds fires in handle_player_action
		game.player.energy -= effective_attack_cost(game)
		return .Moved
	}

	game.player.pos.x = target_x
	game.player.pos.y = target_y
	// Deduct move AP (player move_speed is 100 in Phase 1 → cost = BASE_MOVE_COST)
	move_cost := BASE_MOVE_COST
	if game.frozen_turns > 0 {move_cost *= 2}
	game.player.energy -= move_cost

	t := tile_at(game, target_x, target_y)
	if t != nil && t.type == .Descent {
		descend(content, camera, messages, game)
		return .Descended
	}

	return .Moved
}

handle_forced_turn :: proc(engine: ^eng.Engine, game: ^Game) -> bool {
	messages := game_engine_message_manager(engine)

	if game.skip_next_turn {
		game.skip_next_turn = false
		// Drain a full round of AP — player loses their turn in the web
		game.player.energy -= game.player.quickness * 10
		trigger_enemy_rounds(engine, game)
		add_message(
			messages,
			game,
			"You break free from the web.",
			eng.Engine_Color{200, 200, 100, 255},
		)
		return true
	}

	if game.water_slow_active {
		game.water_slow_active = false
		// Drain a full round of AP — moving through water costs an extra beat
		game.player.energy -= game.player.quickness * 10
		trigger_enemy_rounds(engine, game)
		add_message(
			messages,
			game,
			"You push through the water.",
			eng.Engine_Color{40, 80, 180, 255},
		)
		return true
	}

	return false
}

handle_mining_input :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> bool {
	messages := game_engine_message_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	if !ui.mining_mode {return false}

	if action_pressed(im, .Quit) {
		ui.mining_mode = false
		add_message(messages, game, "Mining cancelled.", eng.Engine_Color{180, 180, 180, 255})
		return true
	}

	mdx, mdy := read_cardinal_press(im)
	if mdx != 0 || mdy != 0 {
		ui.mining_mode = false
		if mine_wall(game_engine_content_manager(engine), messages, game, mdx, mdy) {
			// Mining costs one action's worth of AP
			game.player.energy -= BASE_ACTION_COST
			audio_manager_play_sfx(game_engine_audio_manager(engine), .Mine)
			spawn_mine_particles(
				game_engine_particle_manager(engine),
				game.player.pos.x + mdx,
				game.player.pos.y + mdy,
				game_camera_x(game_engine_camera_manager(engine)),
				game_camera_y(game_engine_camera_manager(engine)),
			)
			trigger_enemy_rounds(engine, game)
		}
	}

	return true
}

handle_playing_hotkeys :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> bool {
	messages := game_engine_message_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	if action_pressed(im, .Crafting) {
		cur := tile_at(game, game.player.pos.x, game.player.pos.y)
		if cur != nil && cur.type == .Anvil {
			game.state = .Viewing_Crafting
			return true
		}
		add_message(
			messages,
			game,
			"You need to stand on an anvil to craft.",
			eng.Engine_Color{180, 180, 180, 255},
		)
	}

	if action_pressed(im, .Mine) {
		start_mining_mode(game_engine_ui_manager(engine), messages, game)
		return true
	}

	if action_pressed(im, .Toggle_Map) {
		ui.show_minimap = !ui.show_minimap
	}

	if action_pressed(im, .Toggle_Audio) {
		audio := game_engine_audio_manager(engine)
		enabled := audio_manager_toggle(audio)
		if enabled {
			add_message(messages, game, "Sound: ON", eng.Engine_Color{180, 180, 180, 255})
		} else {
			add_message(messages, game, "Sound: OFF", eng.Engine_Color{180, 180, 180, 255})
		}
	}

	if action_pressed(im, .Toggle_Sprites) {
		ui.use_sprites = !ui.use_sprites
		if ui.use_sprites {
			add_message(messages, game, "Render: SPRITES", eng.Engine_Color{180, 180, 180, 255})
		} else {
			add_message(messages, game, "Render: ASCII", eng.Engine_Color{180, 180, 180, 255})
		}
	}

	if action_pressed(im, .Save) {
		saves := game_engine_save_manager(engine)
		if save_manager_save_game(saves, game_engine_turn_manager(engine), game) {
			add_message(messages, game, "Game saved.", eng.Engine_Color{100, 255, 100, 255})
		} else {
			add_message(messages, game, "Save failed!", eng.Engine_Color{255, 100, 100, 255})
		}
	}

	if action_pressed(im, .Pickup) {
		if pickup_item(game_engine_content_manager(engine), messages, game) {
			camera := game_engine_camera_manager(engine)
			audio_manager_play_sfx(game_engine_audio_manager(engine), .Pickup)
			spawn_pickup_particles(
				game_engine_particle_manager(engine),
				game.player.pos.x,
				game.player.pos.y,
				game_camera_x(camera),
				game_camera_y(camera),
			)
		}
	}

	if action_pressed(im, .Inventory) {
		game.state = .Viewing_Inventory
		ui.inspect_slot = 0
		return true
	}

	if action_pressed(im, .Help) {
		ui.return_to_title = false
		game.state = .Viewing_Help
		return true
	}
	if eng.engine_input_key_pressed(eng.engine_input_backend(engine), .Left_Bracket) {
		g_game_config.master_volume = max(0, g_game_config.master_volume - 0.1)
		audio_set_master_volume(g_game_config.master_volume)
		add_message(
			messages,
			game,
			fmt.tprintf("Volume: %d%%", int(g_game_config.master_volume * 100 + 0.5)),
			eng.Engine_Color{180, 180, 180, 255},
		)
	}
	if eng.engine_input_key_pressed(eng.engine_input_backend(engine), .Right_Bracket) {
		g_game_config.master_volume = min(1, g_game_config.master_volume + 0.1)
		audio_set_master_volume(g_game_config.master_volume)
		add_message(
			messages,
			game,
			fmt.tprintf("Volume: %d%%", int(g_game_config.master_volume * 100 + 0.5)),
			eng.Engine_Color{180, 180, 180, 255},
		)
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

update_title_screen :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	ui := ui_manager_state(game_engine_ui_manager(engine))
	if action_pressed(im, .Menu_Up) {
		ui.title_choice = (ui.title_choice + TITLE_OPTION_COUNT - 1) % TITLE_OPTION_COUNT
	}
	if action_pressed(im, .Menu_Down) {
		ui.title_choice = (ui.title_choice + 1) % TITLE_OPTION_COUNT
	}

	if action_pressed(im, .Menu_New_Game) {
		ui.title_choice = TITLE_NEW_GAME
		return activate_title_choice(engine, game)
	}
	if action_pressed(im, .Menu_Continue) {
		ui.title_choice = TITLE_CONTINUE
		return activate_title_choice(engine, game)
	}
	if action_pressed(im, .Menu_High_Scores) {
		ui.title_choice = TITLE_HIGH_SCORES
		return activate_title_choice(engine, game)
	}
	if action_pressed(im, .Help) {
		ui.title_choice = TITLE_HELP
		return activate_title_choice(engine, game)
	}
	if action_pressed(im, .Menu_Quit) || action_pressed(im, .Menu_Back) {
		return true
	}
	if action_pressed(im, .Menu_Confirm) {
		return activate_title_choice(engine, game)
	}

	return false
}

activate_title_choice :: proc(engine: ^eng.Engine, game: ^Game) -> (quit: bool) {
	ui := ui_manager_state(game_engine_ui_manager(engine))
	switch ui.title_choice {
	case TITLE_NEW_GAME:
		death_sound_played = false
		restart_game(
			game_engine_content_manager(engine),
			game_engine_turn_manager(engine),
			game_engine_camera_manager(engine),
			game_engine_vfx_manager(engine),
			game_engine_ui_manager(engine),
			game_engine_message_manager(engine),
			game,
		)
	case TITLE_CONTINUE:
		saves := game_engine_save_manager(engine)
		if save_manager_save_exists(saves) {
			if save_manager_load_game(
				saves,
				game_engine_content_manager(engine),
				game_engine_turn_manager(engine),
				game_engine_camera_manager(engine),
				game_engine_vfx_manager(engine),
				game_engine_ui_manager(engine),
				game_engine_message_manager(engine),
				game,
			) {
				death_sound_played = false
			} else {
				add_message(
					game_engine_message_manager(engine),
					game,
					"Save file could not be loaded.",
					eng.Engine_Color{255, 180, 50, 255},
				)
			}
		}
	case TITLE_HIGH_SCORES:
		game.state = .Viewing_Scores
	case TITLE_HELP:
		ui.return_to_title = true
		game.state = .Viewing_Help
	case TITLE_QUIT:
		return true
	}
	return false
}

handle_global_input :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Load) {
		saves := game_engine_save_manager(engine)
		if save_manager_load_game(
			saves,
			game_engine_content_manager(engine),
			game_engine_turn_manager(engine),
			game_engine_camera_manager(engine),
			game_engine_vfx_manager(engine),
			game_engine_ui_manager(engine),
			game_engine_message_manager(engine),
			game,
		) {
			death_sound_played = false
		} else {
			add_message(
				game_engine_message_manager(engine),
				game,
				"No save file found.",
				eng.Engine_Color{255, 180, 50, 255},
			)
		}
	}
}

update_playing :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if handle_forced_turn(engine, game) {return}
	if handle_mining_input(engine, game, im) {return}
	if handle_playing_hotkeys(engine, game, im) {return}
	return handle_player_action(engine, game)
}

update_game_over :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if !death_sound_played {
		audio_manager_play_sfx(game_engine_audio_manager(engine), .Death)
		spawn_death_particles(
			game_engine_particle_manager(engine),
			game.player.pos.x,
			game.player.pos.y,
			game_camera_x(game_engine_camera_manager(engine)),
			game_camera_y(game_engine_camera_manager(engine)),
		)
		death_sound_played = true
	}
	if !game.score_saved {
		save_run_score(game_engine_score_manager(engine), game_engine_turn_manager(engine), game)
	}
	if action_pressed(im, .Restart) {
		death_sound_played = false
		restart_game(
			game_engine_content_manager(engine),
			game_engine_turn_manager(engine),
			game_engine_camera_manager(engine),
			game_engine_vfx_manager(engine),
			game_engine_ui_manager(engine),
			game_engine_message_manager(engine),
			game,
		)
	}
	if action_pressed(im, .Quit) {
		return true
	}
	return
}

update_victory :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if !game.score_saved {
		game.death_cause = "Victory!"
		save_run_score(game_engine_score_manager(engine), game_engine_turn_manager(engine), game)
	}
	if action_pressed(im, .Restart) {
		restart_game(
			game_engine_content_manager(engine),
			game_engine_turn_manager(engine),
			game_engine_camera_manager(engine),
			game_engine_vfx_manager(engine),
			game_engine_ui_manager(engine),
			game_engine_message_manager(engine),
			game,
		)
	}
	if action_pressed(im, .Quit) {
		return true
	}
	return
}

update_viewing_inventory :: proc(
	content: ^Content_Manager,
	ui_manager: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	im: ^Input_Manager,
	engine: ^eng.Engine = nil,
) {
	ui := ui_manager_state(ui_manager)
	if action_pressed(im, .Inventory) || action_pressed(im, .Menu_Back) {
		game.state = .Playing
		ui.dropping = false
		ui.equipping = false
		ui.inspect_slot = -1
	}
	if action_pressed(im, .Menu_Up) {
		ui.inspect_slot = max(ui.inspect_slot - 1, 0)
	}
	if action_pressed(im, .Menu_Down) {
		ui.inspect_slot = min(ui.inspect_slot + 1, MAX_INVENTORY + 2)
	}
	if action_pressed(im, .Inv_Drop_Mode) {
		ui.dropping = !ui.dropping
		ui.equipping = false
	}
	if action_pressed(im, .Inv_Equip_Mode) {
		ui.equipping = !ui.equipping
		ui.dropping = false
	}
	inv_actions := [9]Game_Action {
		.Inv_Slot_1,
		.Inv_Slot_2,
		.Inv_Slot_3,
		.Inv_Slot_4,
		.Inv_Slot_5,
		.Inv_Slot_6,
		.Inv_Slot_7,
		.Inv_Slot_8,
		.Inv_Slot_9,
	}
	for act, idx in inv_actions {
		if action_pressed(im, act) {
			if ui.dropping {
				drop_item(messages, game, idx)
				ui.dropping = false
			} else if ui.equipping {
				equip_item(messages, game, idx)
				ui.equipping = false
			} else {
				use_item(content, messages, game, idx, engine)
			}
		}
	}
}

update_viewing_crafting :: proc(
	content: ^Content_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	im: ^Input_Manager,
) {
	if action_pressed(im, .Menu_Back) || action_pressed(im, .Crafting) {
		game.state = .Playing
	}
	if action_pressed(im, .Craft_1) {try_craft(content, messages, game, 0)}
	if action_pressed(im, .Craft_2) {try_craft(content, messages, game, 1)}
	if action_pressed(im, .Craft_3) {try_craft(content, messages, game, 2)}
	if action_pressed(im, .Craft_4) {try_craft(content, messages, game, 3)}
}

update_viewing_help :: proc(ui_manager: ^UI_Manager, game: ^Game, im: ^Input_Manager) {
	ui := ui_manager_state(ui_manager)
	if action_pressed(im, .Menu_Back) || action_pressed(im, .Help) {
		if ui.return_to_title {
			ui.return_to_title = false
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
