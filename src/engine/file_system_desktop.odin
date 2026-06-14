#+build !js
package engine

import "base:runtime"
import "core:os"

engine_file_system_default :: proc() -> Engine_File_System {
	return Engine_File_System {
		read_entire_file = os_read_entire_file,
		write_entire_file = os_write_entire_file,
		exists = os_exists,
		remove = os_remove,
		rename = os_rename,
	}
}

@(private = "file")
os_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	buf, err := os.read_entire_file(path, allocator)
	if err != nil {
		return {}, false
	}
	return buf, true
}

@(private = "file")
os_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	err := os.write_entire_file(path, data)
	return err == nil
}

@(private = "file")
os_exists :: proc(ctx: rawptr, path: string) -> bool {
	return os.exists(path)
}

@(private = "file")
os_remove :: proc(ctx: rawptr, path: string) -> bool {
	err := os.remove(path)
	return err == nil
}

@(private = "file")
os_rename :: proc(ctx: rawptr, old_path, new_path: string) -> bool {
	err := os.rename(old_path, new_path)
	return err == nil
}
