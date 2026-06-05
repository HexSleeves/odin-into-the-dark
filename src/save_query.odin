package main

import eng "./engine"


save_exists :: proc() -> bool {
	return save_exists_at(SAVE_FILE)
}

save_exists_at :: proc(path: string) -> bool {
	storage := eng.storage_manager_make()
	return save_exists_in_storage(&storage, path)
}

save_exists_in_storage :: proc(storage: ^eng.Storage_Manager, path: string) -> bool {
	return eng.storage_manager_exists(storage, path)
}
