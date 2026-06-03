package main

import eng "./engine"

// ─── Save manager facade ─────────────────────────────────────────────────────

Save_Manager :: struct {
	file_path: string,
	storage:   eng.Storage_Manager,
}

save_manager_make :: proc() -> Save_Manager {
	return Save_Manager{file_path = SAVE_FILE, storage = eng.storage_manager_make()}
}

save_manager_save_exists :: proc(saves: ^Save_Manager) -> bool {
	if saves == nil {
		return save_exists()
	}
	return save_exists_in_storage(&saves.storage, saves.file_path)
}

save_manager_save_game :: proc(
	saves: ^Save_Manager,
	turns: ^eng.Turn_Manager,
	game: ^Game,
) -> bool {
	if saves == nil {
		return save_game(turns, game)
	}
	return save_game_to_storage(turns, game, &saves.storage, saves.file_path)
}

save_manager_load_game :: proc(
	saves: ^Save_Manager,
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	ui: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
) -> bool {
	if saves == nil {
		return load_game(content, turns, camera, vfx, ui, messages, game)
	}
	return load_game_from_storage(
		content,
		turns,
		camera,
		vfx,
		ui,
		messages,
		game,
		&saves.storage,
		saves.file_path,
	)
}
