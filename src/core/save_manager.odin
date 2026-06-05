package core

import eng "../engine"

SAVE_FILE :: "savegame.dat"

Save_Manager :: struct {
	file_path: string,
	storage:   eng.Storage_Manager,
}

save_manager_make :: proc() -> Save_Manager {
	return Save_Manager{file_path = SAVE_FILE, storage = eng.storage_manager_make()}
}

save_manager_save_exists :: proc(saves: ^Save_Manager) -> bool {
	if saves == nil {return false}
	return eng.storage_manager_exists(&saves.storage, saves.file_path)
}
