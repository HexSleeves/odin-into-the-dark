#+build !js
package engine

import "base:runtime"
import "core:testing"

@(test)
storage_manager_delegates_file_operations_to_configured_file_system :: proc(t: ^testing.T) {
	state := Storage_Test_File_System_State {
		read_content  = "from storage",
		exists_result = true,
		remove_result = true,
	}
	fs := Engine_File_System {
		ctx               = &state,
		read_entire_file  = storage_test_read_entire_file,
		write_entire_file = storage_test_write_entire_file,
		exists            = storage_test_exists,
		remove            = storage_test_remove,
	}
	storage := storage_manager_make(fs)
	payload := [?]u8{'s', 'a', 'v', 'e'}

	testing.expect(t, storage_manager_exists(&storage, "save.dat"))
	testing.expect(t, storage_manager_write(&storage, "save.dat", payload[:]))
	buf, read_ok := storage_manager_read(&storage, "save.dat", context.allocator)
	defer delete(buf, context.allocator)
	testing.expect(t, read_ok)
	testing.expect(t, storage_manager_remove(&storage, "save.dat"))

	testing.expect_value(t, state.exists_count, 1)
	testing.expect_value(t, state.write_count, 1)
	testing.expect_value(t, state.read_count, 1)
	testing.expect_value(t, state.remove_count, 1)
	testing.expect_value(t, state.last_path, "save.dat")
	testing.expect_value(t, state.last_write_len, len(payload))
	testing.expect_value(t, len(buf), len(state.read_content))
	testing.expect(t, buf[0] == 'f')
}

@(test)
engine_exposes_owned_storage_manager :: proc(t: ^testing.T) {
	engine := Engine{}
	manager := engine_storage_manager(&engine)

	testing.expect(t, manager == &engine.storage_manager)
}

Storage_Test_File_System_State :: struct {
	read_content:   string,
	last_path:      string,
	last_write_len: int,
	read_count:     int,
	write_count:    int,
	exists_count:   int,
	remove_count:   int,
	exists_result:  bool,
	remove_result:  bool,
}

storage_test_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	state := cast(^Storage_Test_File_System_State)ctx
	state.read_count += 1
	state.last_path = path
	buf := make([]u8, len(state.read_content), allocator)
	for i in 0 ..< len(state.read_content) {
		buf[i] = state.read_content[i]
	}
	return buf, true
}

storage_test_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	state := cast(^Storage_Test_File_System_State)ctx
	state.write_count += 1
	state.last_path = path
	state.last_write_len = len(data)
	return true
}

storage_test_exists :: proc(ctx: rawptr, path: string) -> bool {
	state := cast(^Storage_Test_File_System_State)ctx
	state.exists_count += 1
	state.last_path = path
	return state.exists_result
}

storage_test_remove :: proc(ctx: rawptr, path: string) -> bool {
	state := cast(^Storage_Test_File_System_State)ctx
	state.remove_count += 1
	state.last_path = path
	return state.remove_result
}
