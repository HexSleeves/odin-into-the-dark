package main

import eng "./engine"

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
