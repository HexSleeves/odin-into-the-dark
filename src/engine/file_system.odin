package engine

import "base:runtime"
import "core:os"

// Engine file system boundary.
//
// Default implementations use core:os. Tests, tools, and future web/embedded
// builds can inject another backend without changing content/config callers.
Engine_File_System :: struct {
	ctx: rawptr,
	read_entire_file: proc(ctx: rawptr, path: string, allocator: runtime.Allocator) -> ([]u8, bool),
	write_entire_file: proc(ctx: rawptr, path: string, data: []u8) -> bool,
	exists: proc(ctx: rawptr, path: string) -> bool,
	remove: proc(ctx: rawptr, path: string) -> bool,
}

engine_file_system_is_valid :: proc(fs: Engine_File_System) -> bool {
	return fs.read_entire_file != nil &&
	       fs.write_entire_file != nil &&
	       fs.exists != nil &&
	       fs.remove != nil
}

engine_file_system_or_default :: proc(fs: Engine_File_System) -> Engine_File_System {
	if engine_file_system_is_valid(fs) {
		return fs
	}
	return engine_file_system_default()
}

engine_file_system_default :: proc() -> Engine_File_System {
	return Engine_File_System {
		read_entire_file = os_file_system_read_entire_file,
		write_entire_file = os_file_system_write_entire_file,
		exists = os_file_system_exists,
		remove = os_file_system_remove,
	}
}

@(private = "file")
os_file_system_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> ([]u8, bool) {
	buf, err := os.read_entire_file(path, allocator)
	if err != nil {
		return {}, false
	}
	return buf, true
}

@(private = "file")
os_file_system_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	err := os.write_entire_file(path, data)
	return err == nil
}

@(private = "file")
os_file_system_exists :: proc(ctx: rawptr, path: string) -> bool {
	return os.exists(path)
}

@(private = "file")
os_file_system_remove :: proc(ctx: rawptr, path: string) -> bool {
	err := os.remove(path)
	return err == nil
}
