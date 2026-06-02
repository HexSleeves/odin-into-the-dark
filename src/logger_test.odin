package main

import "core:log"
import "core:testing"
import eng "./engine"

@(test)
logger_parse_bool_accepts_common_env_values :: proc(t: ^testing.T) {
	testing.expect(t, logger_parse_bool("1", false))
	testing.expect(t, logger_parse_bool("true", false))
	testing.expect(t, logger_parse_bool("YES", false))
	testing.expect(t, logger_parse_bool("on", false))

	testing.expect(t, !logger_parse_bool("0", true))
	testing.expect(t, !logger_parse_bool("false", true))
	testing.expect(t, !logger_parse_bool("NO", true))
	testing.expect(t, !logger_parse_bool("off", true))

	testing.expect(t, logger_parse_bool("", true))
	testing.expect(t, !logger_parse_bool("unknown", false))
}

@(test)
logger_parse_level_supports_aliases_and_off :: proc(t: ^testing.T) {
	level, enabled := logger_parse_level("debug", log.Level.Info)
	testing.expect(t, enabled)
	testing.expect_value(t, level, log.Level.Debug)

	level, enabled = logger_parse_level("warning", log.Level.Info)
	testing.expect(t, enabled)
	testing.expect_value(t, level, log.Level.Warning)

	level, enabled = logger_parse_level("warn", log.Level.Info)
	testing.expect(t, enabled)
	testing.expect_value(t, level, log.Level.Warning)

	level, enabled = logger_parse_level("off", log.Level.Info)
	testing.expect(t, !enabled)
	testing.expect_value(t, level, log.Level.Info)

	level, enabled = logger_parse_level("invalid", log.Level.Error)
	testing.expect(t, enabled)
	testing.expect_value(t, level, log.Level.Error)
}

@(test)
logger_channel_labels_and_filters_are_stable :: proc(t: ^testing.T) {
	testing.expect_value(t, logger_channel_label(.Data), "data")
	testing.expect_value(t, logger_channel_label(.Gen), "gen")
	testing.expect_value(t, logger_channel_label(.Save), "save")

	channels := logger_parse_channels("data, gen,enemy")
	testing.expect(t, .Data in channels)
	testing.expect(t, .Gen in channels)
	testing.expect(t, .Enemy in channels)
	testing.expect(t, !(.Fov in channels))

	all_channels := logger_parse_channels("all")
	testing.expect(t, .App in all_channels)
	testing.expect(t, .Save in all_channels)
}

@(test)
logger_config_reads_engine_config_manager_values :: proc(t: ^testing.T) {
	config := eng.config_manager_make()
	eng.config_manager_load_env_text(
		&config,
		"ITD_LOG_LEVEL=debug\nITD_LOG_CONSOLE=false\nITD_LOG_FILE=true\nITD_LOG_FILE_PATH=logs/config-manager.log\nITD_LOG_CHANNELS=data,save\n",
	)

	logger_config := logger_config_from_config(&config)

	testing.expect_value(t, logger_config.console_level, log.Level.Debug)
	testing.expect_value(t, logger_config.file_level, log.Level.Debug)
	testing.expect(t, !logger_config.console_enabled)
	testing.expect(t, logger_config.file_enabled)
	testing.expect_value(t, logger_config.file_path, "logs/config-manager.log")
	testing.expect(t, .Data in logger_config.channels)
	testing.expect(t, .Save in logger_config.channels)
	testing.expect(t, !(.Audio in logger_config.channels))
}
