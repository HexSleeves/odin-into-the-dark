package engine

import "base:runtime"

// Engine file system boundary.
//
// Default implementations use core:os on desktop (file_system_desktop.odin).
// WASM builds get a nil default; game layer must inject an FS backend.
Engine_File_System :: struct {
	ctx:               rawptr,
	read_entire_file:  proc(
		ctx: rawptr,
		path: string,
		allocator: runtime.Allocator,
	) -> (
		[]u8,
		bool,
	),
	write_entire_file: proc(ctx: rawptr, path: string, data: []u8) -> bool,
	exists:            proc(ctx: rawptr, path: string) -> bool,
	remove:            proc(ctx: rawptr, path: string) -> bool,
}

engine_file_system_is_valid :: proc(fs: Engine_File_System) -> bool {
	return(
		fs.read_entire_file != nil &&
		fs.write_entire_file != nil &&
		fs.exists != nil &&
		fs.remove != nil \
	)
}

engine_file_system_or_default :: proc(fs: Engine_File_System) -> Engine_File_System {
	if engine_file_system_is_valid(fs) {
		return fs
	}
	return engine_file_system_default()
}
