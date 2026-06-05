package main

import eng "./engine"

// ─── Game scene boundary ─────────────────────────────────────────────────────

GAME_SCENE_COUNT :: 9

Game_Scene :: enum {
	Title,
	Gameplay,
	Game_Over,
	Victory,
	Inventory,
	Crafting,
	Help,
	Scores,
	Cheats,
}

scene_for_state :: proc(state: Game_State) -> Game_Scene {
	switch state {
	case .Title_Screen:
		return .Title
	case .Playing:
		return .Gameplay
	case .Game_Over:
		return .Game_Over
	case .Victory:
		return .Victory
	case .Viewing_Inventory:
		return .Inventory
	case .Viewing_Crafting:
		return .Crafting
	case .Viewing_Help:
		return .Help
	case .Viewing_Scores:
		return .Scores
	case .Viewing_Cheats:
		return .Cheats
	}

	return .Gameplay
}

game_scene_id :: proc(scene: Game_Scene) -> eng.Engine_Scene_Id {
	return cast(eng.Engine_Scene_Id)scene
}

game_scene_manager_init :: proc(
	scenes: []eng.Engine_Scene,
	engine: ^eng.Engine,
	game: ^Game,
) -> bool {
	manager := eng.engine_scene_manager(engine)
	if manager == nil || game == nil || len(scenes) < GAME_SCENE_COUNT {
		return false
	}

	scenes[0] = eng.Engine_Scene {
		id     = game_scene_id(.Title),
		ctx    = rawptr(game),
		update = game_scene_title_update,
		render = game_scene_render,
	}
	scenes[1] = eng.Engine_Scene {
		id     = game_scene_id(.Gameplay),
		ctx    = rawptr(game),
		update = game_scene_gameplay_update,
		render = game_scene_render,
	}
	scenes[2] = eng.Engine_Scene {
		id     = game_scene_id(.Game_Over),
		ctx    = rawptr(game),
		update = game_scene_game_over_update,
		render = game_scene_render,
	}
	scenes[3] = eng.Engine_Scene {
		id     = game_scene_id(.Victory),
		ctx    = rawptr(game),
		update = game_scene_victory_update,
		render = game_scene_render,
	}
	scenes[4] = eng.Engine_Scene {
		id     = game_scene_id(.Inventory),
		ctx    = rawptr(game),
		update = game_scene_inventory_update,
		render = game_scene_render,
	}
	scenes[5] = eng.Engine_Scene {
		id     = game_scene_id(.Crafting),
		ctx    = rawptr(game),
		update = game_scene_crafting_update,
		render = game_scene_render,
	}
	scenes[6] = eng.Engine_Scene {
		id     = game_scene_id(.Help),
		ctx    = rawptr(game),
		update = game_scene_help_update,
		render = game_scene_render,
	}
	scenes[7] = eng.Engine_Scene {
		id     = game_scene_id(.Scores),
		ctx    = rawptr(game),
		update = game_scene_scores_update,
		render = game_scene_render,
	}
	scenes[8] = eng.Engine_Scene {
		id     = game_scene_id(.Cheats),
		ctx    = rawptr(game),
		update = game_scene_cheats_update,
		render = game_scene_render,
	}


	manager^ = eng.scene_manager_make(scenes[:GAME_SCENE_COUNT])
	return game_scene_manager_sync(engine, game)
}

game_scene_manager_sync :: proc(engine: ^eng.Engine, game: ^Game) -> bool {
	manager := eng.engine_scene_manager(engine)
	if engine == nil || game == nil {
		return false
	}
	return eng.scene_manager_set_active(
		manager,
		engine,
		game_scene_id(scene_for_state(game.state)),
	)
}

game_scene_manager_update :: proc(engine: ^eng.Engine, game: ^Game) -> bool {
	if !game_scene_manager_sync(engine, game) {
		return true
	}
	manager := eng.engine_scene_manager(engine)
	return eng.scene_manager_update(manager, engine)
}

game_scene_manager_render :: proc(engine: ^eng.Engine, game: ^Game) {
	if !game_scene_manager_sync(engine, game) {
		return
	}
	manager := eng.engine_scene_manager(engine)
	eng.scene_manager_render(manager, engine)
}

scene_update :: proc(game: ^Game) -> bool {
	if game == nil {
		return true
	}

	scenes: [GAME_SCENE_COUNT]eng.Engine_Scene
	services := eng.engine_services_make(eng.engine_services_default_config())
	engine := eng.Engine {
		services = &services,
	}
	game_engine_register_app_services(&engine)
	if !game_scene_manager_init(scenes[:], &engine, game) {
		return true
	}
	return game_scene_manager_update(&engine, game)
}

game_scene_title_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_title_screen(engine, game, game_engine_input_manager(engine))
}

game_scene_gameplay_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_playing(engine, game, game_engine_input_manager(engine), &g_game_config)
}

game_scene_game_over_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_game_over(engine, game, game_engine_input_manager(engine))
}

game_scene_victory_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_victory(engine, game, game_engine_input_manager(engine))
}

game_scene_inventory_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_inventory(
		game_engine_content_manager(engine),
		game_engine_ui_manager(engine),
		game_engine_message_manager(engine),
		game,
		game_engine_input_manager(engine),
		engine,
	)
	return false
}

game_scene_crafting_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_crafting(
		game_engine_content_manager(engine),
		game_engine_message_manager(engine),
		game,
		game_engine_input_manager(engine),
	)
	return false
}

game_scene_help_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_help(game_engine_ui_manager(engine), game, game_engine_input_manager(engine))
	return false
}

game_scene_scores_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_scores(game, game_engine_input_manager(engine))
	return false
}

game_scene_cheats_update :: proc(engine: ^eng.Engine, ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_cheats(
		game_engine_content_manager(engine),
		game_engine_turn_manager(engine),
		game_engine_camera_manager(engine),
		game_engine_message_manager(engine),
		game_engine_ui_manager(engine),
		game,
		game_engine_input_manager(engine),
	)
	return false
}

game_scene_render :: proc(engine: ^eng.Engine, ctx: rawptr) {
	game := cast(^Game)ctx
	render_game(engine, game)
}
