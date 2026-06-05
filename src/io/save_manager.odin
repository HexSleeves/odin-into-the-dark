package gameio

import gcore "../core"
import eng "../engine"

// ─── Save manager facade ─────────────────────────────────────────────────────

Save_Manager :: gcore.Save_Manager
save_manager_make :: gcore.save_manager_make
save_manager_save_exists :: gcore.save_manager_save_exists

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
