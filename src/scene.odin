package main

// ─── Game scene boundary ─────────────────────────────────────────────────────

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

scene_update :: proc(game: ^Game) -> bool {
	if game == nil {
		return true
	}

	im := &game.input
	switch scene_for_state(game.state) {
	case .Title:
		return update_title_screen(game, im)
	case .Gameplay:
		return update_playing(game, im)
	case .Game_Over:
		return update_game_over(game, im)
	case .Victory:
		return update_victory(game, im)
	case .Inventory:
		update_viewing_inventory(game, im)
	case .Crafting:
		update_viewing_crafting(game, im)
	case .Help:
		update_viewing_help(game, im)
	case .Scores:
		update_viewing_scores(game, im)
	}

	return false
}

