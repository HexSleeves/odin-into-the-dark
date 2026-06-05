package gameinput

import eng "../engine"
import "core:fmt"

Game_Config :: struct {
	master_volume: f32,
	music_volume:  f32,
}

handle_forced_turn :: proc(engine: ^eng.Engine, game: ^Game) -> bool {
	messages := game_engine_message_manager(engine)

	if game.skip_next_turn {
		game.skip_next_turn = false
		game.player.energy -= game.player.quickness * 10
		trigger_enemy_rounds(engine, game)
		add_message(messages, game, "You break free from the web.", eng.Engine_Color{200, 200, 100, 255})
		return true
	}

	if game.water_slow_active {
		game.water_slow_active = false
		game.player.energy -= game.player.quickness * 10
		trigger_enemy_rounds(engine, game)
		add_message(messages, game, "You push through the water.", eng.Engine_Color{40, 80, 180, 255})
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

handle_playing_hotkeys :: proc(
	engine: ^eng.Engine,
	game: ^Game,
	im: ^Input_Manager,
	config: ^Game_Config,
) -> bool {
	messages := game_engine_message_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	if action_pressed(im, .Crafting) {
		cur := tile_at(game, game.player.pos.x, game.player.pos.y)
		if cur != nil && cur.type == .Anvil {
			game.state = .Viewing_Crafting
			return true
		}
		add_message(messages, game, "You need to stand on an anvil to craft.", eng.Engine_Color{180, 180, 180, 255})
	}

	if action_pressed(im, .Mine) {
		start_mining_mode(game_engine_ui_manager(engine), messages, game)
		return true
	}

	if action_pressed(im, .Toggle_Map) {
		ui.show_minimap = !ui.show_minimap
	}

	when !NO_AUDIO {
		if action_pressed(im, .Toggle_Audio) {
			audio := game_engine_audio_manager(engine)
			enabled := audio_manager_toggle(audio)
			if enabled {
				add_message(messages, game, "Sound: ON", eng.Engine_Color{180, 180, 180, 255})
			} else {
				add_message(messages, game, "Sound: OFF", eng.Engine_Color{180, 180, 180, 255})
			}
		}
	}

	when !NO_SPRITES {
		if action_pressed(im, .Toggle_Sprites) {
			ui.use_sprites = !ui.use_sprites
			if ui.use_sprites {
				add_message(messages, game, "Render: SPRITES", eng.Engine_Color{180, 180, 180, 255})
			} else {
				add_message(messages, game, "Render: ASCII", eng.Engine_Color{180, 180, 180, 255})
			}
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

	if config != nil {
		if eng.engine_input_key_pressed(eng.engine_input_backend(engine), .Left_Bracket) {
			config.master_volume = max(0, config.master_volume - 0.1)
			audio_set_master_volume(config.master_volume)
			add_message(
				messages,
				game,
				fmt.tprintf("Volume: %d%%", int(config.master_volume * 100 + 0.5)),
				eng.Engine_Color{180, 180, 180, 255},
			)
		}
		if eng.engine_input_key_pressed(eng.engine_input_backend(engine), .Right_Bracket) {
			config.master_volume = min(1, config.master_volume + 0.1)
			audio_set_master_volume(config.master_volume)
			add_message(
				messages,
				game,
				fmt.tprintf("Volume: %d%%", int(config.master_volume * 100 + 0.5)),
				eng.Engine_Color{180, 180, 180, 255},
			)
		}
	}

	return false
}
