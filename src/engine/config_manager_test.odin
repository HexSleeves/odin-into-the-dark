package engine

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
