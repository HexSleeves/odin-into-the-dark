#+build js
package engine

// WASM has no filesystem. The game layer must inject an FS backend
// (e.g. using #load for embedded data or an IndexedDB adapter).
engine_file_system_default :: proc() -> Engine_File_System {
	return Engine_File_System{}
}
