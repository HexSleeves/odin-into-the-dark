package main

import gameaudio "./audio"
import gcore "./core"
import eng "./engine"
import gameinput "./input"
import gameio "./io"
import gp "./gameplay"
import renderer "./render"
import gameui "./ui"

game_app_enforce_build_flags :: proc(engine: ^eng.Engine) {
	when NO_SPRITES {
		ui := gameui.ui_manager_state(game_engine_ui_manager(engine))
		if ui != nil {
			ui.use_sprites = false
		}
	}
}

game_app_make :: proc() -> eng.Game_App {
	return eng.Game_App {
		name = "Into the Depths",
		init = game_app_init,
		update = game_app_update,
		render = game_app_render,
		shutdown = game_app_shutdown,
		autosave = game_app_autosave,
	}
}

game_app_state :: proc(app: ^eng.Game_App) -> ^Into_The_Depths_App_State {
	if app == nil || app.state == nil {
		return nil
	}
	return cast(^Into_The_Depths_App_State)app.state
}

game_app_init :: proc(engine: ^eng.Engine, app: ^eng.Game_App) -> bool {
	state := new(Into_The_Depths_App_State)
	app.state = state

	when !NO_SPRITES {
		renderer.sprites_init(engine)
	}

	if !game_engine_register_app_services(engine) {
		gameio.logger_fatalf(.App, "Failed to register app services. Exiting.")
		when !NO_SPRITES {
			renderer.sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}

	content := game_engine_content_manager(engine)
	if content == nil || !content_manager_load_all(content) {
		gameio.logger_fatalf(.App, "Failed to load data files. Exiting.")
		when !NO_SPRITES {
			renderer.sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}

	eng.message_manager_bind_turns(
		game_engine_message_manager(engine),
		game_engine_turn_manager(engine),
	)

	state.game = gp.game_init(content)
	if !game_scene_manager_init(state.scene_descriptors[:], engine, state.game) {
		gameio.logger_fatalf(.App, "Failed to initialize scene manager. Exiting.")
		gp.game_destroy(state.game)
		when !NO_SPRITES {
			renderer.sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}

	game := state.game
	if game.state == .Playing {
		gameio.logger_debugf(.Init, "seed = %v", game.seed)
		gp.compute_fov(game)
		gcore.game_camera_update(game_engine_camera_manager(engine), game, true)
	}
	game_app_enforce_build_flags(engine)
	if !renderer.clay_ui_init(engine) {
		gameio.logger_fatalf(.App, "Failed to initialize Clay UI. Exiting.")
		gp.game_destroy(state.game)
		when !NO_SPRITES {
			renderer.sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}
	if game.state == .Playing {
		gameui.add_message(
			game_engine_message_manager(engine),
			game,
			"Welcome to the depths. Tread carefully...",
			eng.Engine_Color{200, 200, 100, 255},
		)
	}

	return true
}

game_app_update :: proc(engine: ^eng.Engine, app: ^eng.Game_App) -> bool {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return true
	}

	game := state.game
	when !NO_AUDIO {
		gameaudio.music_update(game)
	}
	game_app_enforce_build_flags(engine)
	gameinput.handle_global_input(engine, game, game_engine_input_manager(engine))
	return game_scene_manager_update(engine, game)
}

game_app_render :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}
	game_scene_manager_render(engine, state.game)
}

game_app_autosave :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}

	saves := game_engine_save_manager(engine)
	if state.game.state == .Playing && saves != nil {
		gameio.save_manager_save_game(saves, game_engine_turn_manager(engine), state.game)
	}
}

game_app_shutdown :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil {
		return
	}
	if state.game != nil {
		gp.game_destroy(state.game)
	}
	renderer.clay_ui_destroy()
	when !NO_SPRITES {
		renderer.sprites_cleanup(engine)
	}
	free(state)
	app.state = nil
}
