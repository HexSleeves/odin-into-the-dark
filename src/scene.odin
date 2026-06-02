package main

import eng "./engine"

// ─── Game scene boundary ─────────────────────────────────────────────────────

GAME_SCENE_COUNT :: 8

Game_Scene :: enum {
	Title,
	Gameplay,
	Game_Over,
	Victory,
	Inventory,
	Crafting,
	Help,
	Scores,
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
	}

	return .Gameplay
}

game_scene_id :: proc(scene: Game_Scene) -> eng.Engine_Scene_Id {
	return cast(eng.Engine_Scene_Id)scene
}

game_scene_manager_init :: proc(
	manager: ^eng.Scene_Manager,
	scenes: []eng.Engine_Scene,
	game: ^Game,
) -> bool {
	if manager == nil || game == nil || len(scenes) < GAME_SCENE_COUNT {
		return false
	}

	scenes[0] = eng.Engine_Scene {
		id      = game_scene_id(.Title),
		ctx     = rawptr(game),
		update  = game_scene_title_update,
		render  = game_scene_render,
	}
	scenes[1] = eng.Engine_Scene {
		id      = game_scene_id(.Gameplay),
		ctx     = rawptr(game),
		update  = game_scene_gameplay_update,
		render  = game_scene_render,
	}
	scenes[2] = eng.Engine_Scene {
		id      = game_scene_id(.Game_Over),
		ctx     = rawptr(game),
		update  = game_scene_game_over_update,
		render  = game_scene_render,
	}
	scenes[3] = eng.Engine_Scene {
		id      = game_scene_id(.Victory),
		ctx     = rawptr(game),
		update  = game_scene_victory_update,
		render  = game_scene_render,
	}
	scenes[4] = eng.Engine_Scene {
		id      = game_scene_id(.Inventory),
		ctx     = rawptr(game),
		update  = game_scene_inventory_update,
		render  = game_scene_render,
	}
	scenes[5] = eng.Engine_Scene {
		id      = game_scene_id(.Crafting),
		ctx     = rawptr(game),
		update  = game_scene_crafting_update,
		render  = game_scene_render,
	}
	scenes[6] = eng.Engine_Scene {
		id      = game_scene_id(.Help),
		ctx     = rawptr(game),
		update  = game_scene_help_update,
		render  = game_scene_render,
	}
	scenes[7] = eng.Engine_Scene {
		id      = game_scene_id(.Scores),
		ctx     = rawptr(game),
		update  = game_scene_scores_update,
		render  = game_scene_render,
	}

	manager^ = eng.scene_manager_make(scenes[:GAME_SCENE_COUNT])
	return game_scene_manager_sync(manager, game)
}

game_scene_manager_sync :: proc(manager: ^eng.Scene_Manager, game: ^Game) -> bool {
	if game == nil {
		return false
	}
	return eng.scene_manager_set_active(manager, game_scene_id(scene_for_state(game.state)))
}

game_scene_manager_update :: proc(manager: ^eng.Scene_Manager, game: ^Game) -> bool {
	if !game_scene_manager_sync(manager, game) {
		return true
	}
	return eng.scene_manager_update(manager)
}

game_scene_manager_render :: proc(manager: ^eng.Scene_Manager, game: ^Game) {
	if !game_scene_manager_sync(manager, game) {
		return
	}
	eng.scene_manager_render(manager)
}

scene_update :: proc(game: ^Game) -> bool {
	if game == nil {
		return true
	}

	scenes: [GAME_SCENE_COUNT]eng.Engine_Scene
	manager: eng.Scene_Manager
	if !game_scene_manager_init(&manager, scenes[:], game) {
		return true
	}
	return game_scene_manager_update(&manager, game)
}

game_scene_title_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_title_screen(game, &game.input)
}

game_scene_gameplay_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_playing(game, &game.input)
}

game_scene_game_over_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_game_over(game, &game.input)
}

game_scene_victory_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	return update_victory(game, &game.input)
}

game_scene_inventory_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_inventory(game, &game.input)
	return false
}

game_scene_crafting_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_crafting(game, &game.input)
	return false
}

game_scene_help_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_help(game, &game.input)
	return false
}

game_scene_scores_update :: proc(ctx: rawptr) -> bool {
	game := cast(^Game)ctx
	update_viewing_scores(game, &game.input)
	return false
}

game_scene_render :: proc(ctx: rawptr) {
	game := cast(^Game)ctx
	render_game(game)
}
