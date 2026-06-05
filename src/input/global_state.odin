package gameinput

import eng "../engine"

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
