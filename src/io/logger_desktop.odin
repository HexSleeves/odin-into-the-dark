#+build !js
package gameio

import eng "../engine"
import "core:fmt"
import "core:log"
import "core:os"

logger_init_file :: proc(logger: ^Game_Logger, options: log.Options) {
	if !logger.config.file_enabled {
		return
	}
	file_options := options - log.Options{.Terminal_Color}
	file, open_err := os.open(
		logger.config.file_path,
		os.File_Flags{.Write, .Create, .Append},
		os.Permissions_Default_File,
	)
	if open_err != nil {
		fmt.eprintfln(
			"[logger] ERROR: could not open log file '%s': %v",
			logger.config.file_path,
			open_err,
		)
	} else {
		logger.file_handle = file
		logger.file = log.create_file_logger(file, logger.config.file_level, file_options, "itd")
		logger.file_ready = true
	}
}

logger_destroy_file :: proc(logger: ^Game_Logger) {
	if !logger.file_ready {
		return
	}
	fh := cast(^os.File)logger.file_handle
	if logger.config.flush_file && fh != nil {
		os.flush(fh)
	}
	log.destroy_file_logger(logger.file)
	logger.file_ready = false
	logger.file_handle = nil
}

logger_flush_file :: proc(logger: ^Game_Logger) {
	if logger.config.flush_file && logger.file_handle != nil {
		os.flush(cast(^os.File)logger.file_handle)
	}
}

logger_config_value :: proc(config: ^eng.Config_Manager, key: string) -> string {
	if value, ok := eng.config_manager_get(config, key); ok {
		return value
	}
	return os.get_env(key, context.temp_allocator)
}

logger_config_file_path :: proc(config: ^eng.Config_Manager) -> string {
	file_path, file_path_ok := eng.config_manager_get(config, "ITD_LOG_FILE_PATH")
	if !file_path_ok {
		file_path = os.get_env("ITD_LOG_FILE_PATH", context.allocator)
	}
	return file_path
}
