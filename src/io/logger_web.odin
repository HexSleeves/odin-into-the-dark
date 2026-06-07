#+build js
package gameio

import eng "../engine"
import "core:log"

// WASM: no filesystem, no env vars — file logging is disabled.

logger_init_file :: proc(logger: ^Game_Logger, options: log.Options) {}

logger_destroy_file :: proc(logger: ^Game_Logger) {}

logger_flush_file :: proc(logger: ^Game_Logger) {}

logger_config_value :: proc(config: ^eng.Config_Manager, key: string) -> string {
	if value, ok := eng.config_manager_get(config, key); ok {
		return value
	}
	return ""
}

logger_config_file_path :: proc(config: ^eng.Config_Manager) -> (string, bool) {
	return "", false
}
