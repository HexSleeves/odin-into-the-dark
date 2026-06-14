#+build !js
package main

import eng "./engine"
import "core:testing"

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Builds a minimal engine wired with the UI, message, and input services that the
// pause/playing update procs read. Caller owns teardown via the returned services
// pointer (deferred destroy in the test).
@(private = "file")
pause_test_engine :: proc(
	t: ^testing.T,
	services: ^eng.Engine_Services,
	engine: ^eng.Engine,
	ui: ^UI_Manager,
	input: ^Input_Manager,
) {
	services^ = engine_services_make(engine_services_default_config())
	engine.services = services
	engine.message_manager = message_manager_make()
	testing.expect(
		t,
		engine_services_register(services, GAME_ENGINE_SERVICE_MESSAGES, &engine.message_manager),
	)
	testing.expect(t, engine_services_register(services, GAME_ENGINE_SERVICE_UI, ui))
	testing.expect(t, engine_services_register(services, GAME_ENGINE_SERVICE_INPUT, input))
}

@(private = "file")
pause_test_input :: proc(state: ^Test_Input_Backend_State) -> Input_Manager {
	input := input_manager_make()
	input.backend = test_input_backend(state)
	return input
}

// ─── Tests ────────────────────────────────────────────────────────────────────

@(test)
escape_during_play_opens_the_pause_menu_instead_of_quitting :: proc(t: ^testing.T) {
	game: Game
	game.state = .Playing
	ui := ui_manager_make(false)

	state := Test_Input_Backend_State{}
	state.pressed[eng.Engine_Key.Escape] = true
	input := pause_test_input(&state)

	services: eng.Engine_Services
	engine: eng.Engine
	pause_test_engine(t, &services, &engine, &ui, &input)
	defer engine_services_destroy(&services)

	quit := update_playing(&engine, &game, &input, nil)

	testing.expect(t, !quit, "Escape must not quit the process")
	testing.expect_value(t, game.state, Game_State.Pause)
	testing.expect_value(t, ui.state.pause_choice, PAUSE_RESUME)
}

@(test)
pause_menu_resume_returns_to_playing :: proc(t: ^testing.T) {
	game: Game
	game.state = .Pause
	ui := ui_manager_make(false)
	ui.state.pause_choice = PAUSE_RESUME

	state := Test_Input_Backend_State{}
	state.pressed[eng.Engine_Key.Enter] = true
	input := pause_test_input(&state)

	services: eng.Engine_Services
	engine: eng.Engine
	pause_test_engine(t, &services, &engine, &ui, &input)
	defer engine_services_destroy(&services)

	quit := update_pause(&engine, &game, &input)

	testing.expect(t, !quit)
	testing.expect_value(t, game.state, Game_State.Playing)
}

@(test)
pause_menu_quit_to_title_returns_to_title_without_exiting_process :: proc(t: ^testing.T) {
	game: Game
	game.state = .Pause
	ui := ui_manager_make(false)
	ui.state.pause_choice = PAUSE_QUIT_TO_TITLE

	state := Test_Input_Backend_State{}
	state.pressed[eng.Engine_Key.Enter] = true
	input := pause_test_input(&state)

	services: eng.Engine_Services
	engine: eng.Engine
	pause_test_engine(t, &services, &engine, &ui, &input)
	defer engine_services_destroy(&services)

	quit := update_pause(&engine, &game, &input)

	// Quit-to-Title must return to the title screen, never signal a process exit.
	testing.expect(t, !quit, "Quit to Title must keep the process alive")
	testing.expect_value(t, game.state, Game_State.Title_Screen)
}

@(test)
pause_menu_escape_resumes_play :: proc(t: ^testing.T) {
	game: Game
	game.state = .Pause
	ui := ui_manager_make(false)
	ui.state.pause_choice = PAUSE_QUIT_TO_TITLE

	state := Test_Input_Backend_State{}
	state.pressed[eng.Engine_Key.Escape] = true
	input := pause_test_input(&state)

	services: eng.Engine_Services
	engine: eng.Engine
	pause_test_engine(t, &services, &engine, &ui, &input)
	defer engine_services_destroy(&services)

	quit := update_pause(&engine, &game, &input)

	// Escape resumes regardless of the highlighted row (never quits to title).
	testing.expect(t, !quit)
	testing.expect_value(t, game.state, Game_State.Playing)
}

@(test)
pause_menu_down_then_up_cycles_selection :: proc(t: ^testing.T) {
	game: Game
	game.state = .Pause
	ui := ui_manager_make(false)
	ui.state.pause_choice = PAUSE_RESUME

	services: eng.Engine_Services
	engine: eng.Engine

	down_state := Test_Input_Backend_State{}
	down_state.pressed[eng.Engine_Key.S] = true
	down_input := pause_test_input(&down_state)
	pause_test_engine(t, &services, &engine, &ui, &down_input)
	defer engine_services_destroy(&services)

	update_pause(&engine, &game, &down_input)
	testing.expect_value(t, ui.state.pause_choice, PAUSE_QUIT_TO_TITLE)

	up_state := Test_Input_Backend_State{}
	up_state.pressed[eng.Engine_Key.W] = true
	up_input := pause_test_input(&up_state)
	testing.expect(t, engine_services_register(&services, GAME_ENGINE_SERVICE_INPUT, &up_input))

	update_pause(&engine, &game, &up_input)
	testing.expect_value(t, ui.state.pause_choice, PAUSE_RESUME)
}
