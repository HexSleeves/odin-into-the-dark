package main

// ─── Save manager facade ─────────────────────────────────────────────────────

Save_Manager :: struct {
	file_path: string,
}

save_manager_make :: proc() -> Save_Manager {
	return Save_Manager {
		file_path = SAVE_FILE,
	}
}

save_manager_save_exists :: proc(saves: ^Save_Manager) -> bool {
	if saves == nil {
		return save_exists()
	}
	return save_exists_at(saves.file_path)
}

save_manager_save_game :: proc(saves: ^Save_Manager, game: ^Game) -> bool {
	if saves == nil {
		return save_game(game)
	}
	return save_game_to_path(game, saves.file_path)
}

save_manager_load_game :: proc(saves: ^Save_Manager, game: ^Game) -> bool {
	if saves == nil {
		return load_game(game)
	}
	return load_game_from_path(game, saves.file_path)
}
