package engine

import "base:runtime"
import "core:testing"

@(test)
config_manager_parses_env_text :: proc(t: ^testing.T) {
	config := config_manager_make()
	ok := config_manager_load_env_text(
		&config,
		"# ignored\nITD_LOG_LEVEL=debug\nITD_LOG_FILE=false\nexport ITD_LOG_FILE_PATH=logs/test.log\nQUOTED=\"hello world\"\n",
	)

	testing.expect(t, ok)
	level, level_ok := config_manager_get(&config, "ITD_LOG_LEVEL")
	file_enabled, file_ok := config_manager_get(&config, "ITD_LOG_FILE")
	file_path, path_ok := config_manager_get(&config, "ITD_LOG_FILE_PATH")
	quoted, quoted_ok := config_manager_get(&config, "QUOTED")

	testing.expect(t, level_ok)
	testing.expect(t, file_ok)
	testing.expect(t, path_ok)
	testing.expect(t, quoted_ok)
	testing.expect_value(t, level, "debug")
	testing.expect_value(t, file_enabled, "false")
	testing.expect_value(t, file_path, "logs/test.log")
	testing.expect_value(t, quoted, "hello world")
}

@(test)
config_manager_overrides_duplicate_keys :: proc(t: ^testing.T) {
	config := config_manager_make()
	config_manager_load_env_text(&config, "ITD_LOG_LEVEL=info\nITD_LOG_LEVEL=warn\n")

	value, ok := config_manager_get(&config, "ITD_LOG_LEVEL")

	testing.expect(t, ok)
	testing.expect_value(t, value, "warn")
	testing.expect_value(t, config.entry_count, 1)
}

@(test)
config_manager_loads_env_file_from_configured_file_system :: proc(t: ^testing.T) {
	config := config_manager_make()
	fs_state := Test_File_System_State {
		content = "ITD_LOG_LEVEL=trace\nCUSTOM_VALUE=engine-fs\n",
	}
	fs := Engine_File_System {
		ctx               = &fs_state,
		read_entire_file  = test_file_system_read_entire_file,
		write_entire_file = test_file_system_write_entire_file,
		exists            = test_file_system_exists,
		remove            = test_file_system_remove,
	}

	ok := config_manager_load_env_file_with_file_system(&config, "virtual.env", fs)

	testing.expect(t, ok)
	testing.expect_value(t, fs_state.read_count, 1)
	testing.expect_value(t, fs_state.last_path, "virtual.env")
	level, level_ok := config_manager_get(&config, "ITD_LOG_LEVEL")
	custom, custom_ok := config_manager_get(&config, "CUSTOM_VALUE")
	testing.expect(t, level_ok)
	testing.expect(t, custom_ok)
	testing.expect_value(t, level, "trace")
	testing.expect_value(t, custom, "engine-fs")
}

Test_File_System_State :: struct {
	content:    string,
	last_path:  string,
	read_count: int,
}

test_file_system_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	state := cast(^Test_File_System_State)ctx
	state.read_count += 1
	state.last_path = path
	buf := make([]u8, len(state.content), allocator)
	for i in 0 ..< len(state.content) {
		buf[i] = state.content[i]
	}
	return buf, true
}

test_file_system_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	return false
}

test_file_system_exists :: proc(ctx: rawptr, path: string) -> bool {
	return false
}

test_file_system_remove :: proc(ctx: rawptr, path: string) -> bool {
	return false
}
