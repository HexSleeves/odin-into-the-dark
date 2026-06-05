package main

import eng "./engine"

// handle_player_action stays at root — it calls handle_input (root/input layer)
// and dispatches to gameplay procs. It bridges input and gameplay.

handle_player_action :: proc(engine: ^eng.Engine, game: ^Game) -> (quit: bool) {
	messages := game_engine_message_manager(engine)
	game.prev_player_pos = game.player.pos
	kills_before := game.kills
	result := handle_input(
		game_engine_content_manager(engine),
		game_engine_turn_manager(engine),
		game_engine_camera_manager(engine),
		messages,
		game,
		game_engine_input_manager(engine),
		engine,
	)

	switch result {
	case .Quit:
		return true
	case .Moved:
		handle_player_moved(engine, game, kills_before)
		trigger_enemy_rounds(engine, game)
		announce_item_under_player(messages, game)
	case .Acted:
		trigger_enemy_rounds(engine, game)
	case .Waited:
		trigger_enemy_rounds(engine, game)
	case .Descended:
		handle_player_descended(engine, game)
	case .None:
	}

	return false
}

// restart_game stays at root — it calls game_cleanup/game_reinit which are
// root-only (depend on data loading, seed generation, dynamic alloc).

restart_game :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	ui: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
) {
	game_cleanup(game)
	game^ = {}
	eng.turn_manager_reset(turns)
	eng.vfx_manager_reset(vfx)
	ui_manager_reset_for_new_game(ui, DEFAULT_USE_SPRITES)
	game_reinit(content, messages, game)
	compute_fov(game)
	game_camera_update(camera, game, true)
	game.score_saved = false
	game.death_cause = ""
	game.last_score_rank = -1
	add_message(messages, game, "A new journey begins...", eng.Engine_Color{200, 200, 100, 255})
}
