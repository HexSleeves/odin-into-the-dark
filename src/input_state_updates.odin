package main

import eng "./engine"

update_playing :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> (quit: bool) {
	if cheat_open_if_requested(game_engine_ui_manager(engine), game, im) {return false}
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
