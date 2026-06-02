package engine

import "core:os"

CONFIG_MANAGER_MAX_ENTRIES :: 64
CONFIG_MANAGER_MAX_KEY_LEN :: 64
CONFIG_MANAGER_MAX_VALUE_LEN :: 256

Config_Entry :: struct {
	key:       [CONFIG_MANAGER_MAX_KEY_LEN]u8,
	key_len:   int,
	value:     [CONFIG_MANAGER_MAX_VALUE_LEN]u8,
	value_len: int,
}

Config_Manager :: struct {
	entry_count: int,
	entries:     [CONFIG_MANAGER_MAX_ENTRIES]Config_Entry,
}

config_manager_make :: proc() -> Config_Manager {
	return Config_Manager{}
}

config_manager_load_env_file :: proc(config: ^Config_Manager, path: string) -> bool {
	if config == nil {
		return false
	}
	buf, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		return false
	}
	defer delete(buf, context.allocator)
	return config_manager_load_env_text(config, string(buf))
}

config_manager_load_env_text :: proc(config: ^Config_Manager, text: string) -> bool {
	if config == nil {
		return false
	}

	start := 0
	for start <= len(text) {
		end := start
		for end < len(text) && text[end] != '\n' && text[end] != '\r' {
			end += 1
		}
		config_manager_parse_env_line(config, text[start:end])

		start = end + 1
		for start < len(text) && (text[start] == '\n' || text[start] == '\r') {
			start += 1
		}
		if end >= len(text) {
			break
		}
	}
	return true
}

config_manager_get :: proc(config: ^Config_Manager, key: string) -> (value: string, ok: bool) {
	if config == nil {
		return "", false
	}
	for i in 0 ..< config.entry_count {
		entry := &config.entries[i]
		if config_manager_entry_key(entry) == key {
			return config_manager_entry_value(entry), true
		}
	}
	return "", false
}

config_manager_get_or :: proc(config: ^Config_Manager, key: string, fallback: string) -> string {
	if value, ok := config_manager_get(config, key); ok {
		return value
	}
	return fallback
}

@(private = "file")
config_manager_parse_env_line :: proc(config: ^Config_Manager, line: string) {
	trimmed := config_manager_trim_ascii(line)
	if trimmed == "" || trimmed[0] == '#' {
		return
	}
	if len(trimmed) > 7 && trimmed[0:7] == "export " {
		trimmed = config_manager_trim_ascii(trimmed[7:])
	}

	eq := -1
	for i in 0 ..< len(trimmed) {
		if trimmed[i] == '=' {
			eq = i
			break
		}
	}
	if eq <= 0 {
		return
	}

	key := config_manager_trim_ascii(trimmed[:eq])
	value := config_manager_unquote(config_manager_trim_ascii(trimmed[eq + 1:]))
	if key == "" {
		return
	}
	config_manager_set(config, key, value)
}

@(private = "file")
config_manager_set :: proc(config: ^Config_Manager, key, value: string) -> bool {
	index := -1
	for i in 0 ..< config.entry_count {
		if config_manager_entry_key(&config.entries[i]) == key {
			index = i
			break
		}
	}
	if index < 0 {
		if config.entry_count >= CONFIG_MANAGER_MAX_ENTRIES {
			return false
		}
		index = config.entry_count
		config.entry_count += 1
	}

	entry := &config.entries[index]
	entry.key_len = min(len(key), CONFIG_MANAGER_MAX_KEY_LEN)
	entry.value_len = min(len(value), CONFIG_MANAGER_MAX_VALUE_LEN)
	for i in 0 ..< entry.key_len {
		entry.key[i] = key[i]
	}
	for i in 0 ..< entry.value_len {
		entry.value[i] = value[i]
	}
	return true
}

@(private = "file")
config_manager_entry_key :: proc(entry: ^Config_Entry) -> string {
	return string(entry.key[:entry.key_len])
}

@(private = "file")
config_manager_entry_value :: proc(entry: ^Config_Entry) -> string {
	return string(entry.value[:entry.value_len])
}

@(private = "file")
config_manager_unquote :: proc(value: string) -> string {
	if len(value) >= 2 {
		if (value[0] == '"' && value[len(value) - 1] == '"') ||
		   (value[0] == '\'' && value[len(value) - 1] == '\'') {
			return value[1:len(value) - 1]
		}
	}
	return value
}

@(private = "file")
config_manager_trim_ascii :: proc(value: string) -> string {
	start := 0
	end := len(value)
	for start < end && config_manager_is_ascii_space(value[start]) {
		start += 1
	}
	for end > start && config_manager_is_ascii_space(value[end - 1]) {
		end -= 1
	}
	return value[start:end]
}

@(private = "file")
config_manager_is_ascii_space :: proc(ch: u8) -> bool {
	return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}
