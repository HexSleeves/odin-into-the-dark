package engine

import "base:runtime"

// Storage manager owns generic byte-level persistence for the engine.
//
// Game code still decides what bytes mean; this manager only centralizes the
// filesystem boundary so tests and future platforms can replace OS files.
Storage_Manager :: struct {
	file_system: Engine_File_System,
}

storage_manager_make :: proc(file_system: Engine_File_System = {}) -> Storage_Manager {
	return Storage_Manager{file_system = engine_file_system_or_default(file_system)}
}

storage_manager_is_valid :: proc(storage: Storage_Manager) -> bool {
	return engine_file_system_is_valid(storage.file_system)
}

storage_manager_file_system :: proc(storage: ^Storage_Manager) -> Engine_File_System {
	if storage == nil {
		return engine_file_system_default()
	}
	return engine_file_system_or_default(storage.file_system)
}

// Persistence degrades gracefully when no filesystem is available (e.g. WASM,
// where the default FS is empty and no backend is injected): reads/exists report
// "not found" and writes/removes report failure, instead of trapping on a nil
// function pointer mid-frame.
storage_manager_read :: proc(
	storage: ^Storage_Manager,
	path: string,
	allocator: runtime.Allocator = context.allocator,
) -> (
	[]u8,
	bool,
) {
	file_system := storage_manager_file_system(storage)
	if file_system.read_entire_file == nil {
		return nil, false
	}
	return file_system.read_entire_file(file_system.ctx, path, allocator)
}

storage_manager_write :: proc(storage: ^Storage_Manager, path: string, data: []u8) -> bool {
	file_system := storage_manager_file_system(storage)
	if file_system.write_entire_file == nil {
		return false
	}
	return file_system.write_entire_file(file_system.ctx, path, data)
}

storage_manager_exists :: proc(storage: ^Storage_Manager, path: string) -> bool {
	file_system := storage_manager_file_system(storage)
	if file_system.exists == nil {
		return false
	}
	return file_system.exists(file_system.ctx, path)
}

storage_manager_remove :: proc(storage: ^Storage_Manager, path: string) -> bool {
	file_system := storage_manager_file_system(storage)
	if file_system.remove == nil {
		return false
	}
	return file_system.remove(file_system.ctx, path)
}

// storage_manager_rename atomically moves old_path to new_path.
// Returns false if the underlying filesystem does not support rename (e.g. WASM).
storage_manager_rename :: proc(storage: ^Storage_Manager, old_path, new_path: string) -> bool {
	file_system := storage_manager_file_system(storage)
	if file_system.rename == nil {
		return false
	}
	return file_system.rename(file_system.ctx, old_path, new_path)
}
