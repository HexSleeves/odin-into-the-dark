package main

import "core:fmt"
import "core:log"
import "core:os"

// ─── Game diagnostics logger ─────────────────────────────────────────────────

Game_Log_Channel :: enum {
	App,
	Init,
	Data,
	Sprites,
	Gen,
	Fov,
	Enemy,
	Items,
	Scores,
	Audio,
	Input,
	Save,
}

Game_Log_Channels :: bit_set[Game_Log_Channel]

Game_Logger_Config :: struct {
	enabled:         bool,
	console_enabled: bool,
	file_enabled:    bool,
	console_level:   log.Level,
	file_level:      log.Level,
	file_path:       string,
	channels:        Game_Log_Channels,
	include_source:  bool,
	flush_file:      bool,
}

Game_Logger :: struct {
	config:        Game_Logger_Config,
	console:       log.Logger,
	file:          log.Logger,
	file_handle:   ^os.File,
	console_ready: bool,
	file_ready:    bool,
}

g_logger: Game_Logger

LOGGER_DEFAULT_FILE_PATH :: "into_the_depths.log"

// ─── Lifecycle ────────────────────────────────────────────────────────────────

logger_init_from_env :: proc(logger: ^Game_Logger) {
	logger^ = {}
	logger.config = logger_config_from_env()

	if !logger.config.enabled {
		return
	}

	options: log.Options
	if logger.config.include_source {
		options = log.Options{.Level, .Short_File_Path, .Line, .Procedure, .Terminal_Color} | log.Full_Timestamp_Opts
	} else {
		options = log.Options{.Level, .Terminal_Color} | log.Full_Timestamp_Opts
	}

	if logger.config.console_enabled {
		logger.console = log.create_console_logger(logger.config.console_level, options, "itd")
		logger.console_ready = true
	}

	if logger.config.file_enabled {
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
}

logger_destroy :: proc(logger: ^Game_Logger) {
	if logger.file_ready {
		if logger.config.flush_file && logger.file_handle != nil {
			os.flush(logger.file_handle)
		}
		log.destroy_file_logger(logger.file)
		logger.file_ready = false
		logger.file_handle = nil
	}
	if logger.console_ready {
		log.destroy_console_logger(logger.console)
		logger.console_ready = false
	}
}

// ─── Configuration ───────────────────────────────────────────────────────────

logger_config_from_env :: proc() -> Game_Logger_Config {
	base_level, enabled := logger_parse_level(os.get_env("ITD_LOG_LEVEL", context.temp_allocator), log.Level.Info)
	console_level, console_enabled_from_level := logger_parse_level(
		os.get_env("ITD_LOG_CONSOLE_LEVEL", context.temp_allocator),
		base_level,
	)
	file_level, file_enabled_from_level := logger_parse_level(
		os.get_env("ITD_LOG_FILE_LEVEL", context.temp_allocator),
		base_level,
	)

	file_path := os.get_env("ITD_LOG_FILE_PATH", context.allocator)
	if file_path == "" {
		file_path = LOGGER_DEFAULT_FILE_PATH
	}

	return Game_Logger_Config {
		enabled         = enabled,
		console_enabled = enabled &&
		                  console_enabled_from_level &&
		                  logger_parse_bool(os.get_env("ITD_LOG_CONSOLE", context.temp_allocator), true),
		file_enabled    = enabled &&
		                  file_enabled_from_level &&
		                  logger_parse_bool(os.get_env("ITD_LOG_FILE", context.temp_allocator), true),
		console_level   = console_level,
		file_level      = file_level,
		file_path       = file_path,
		channels        = logger_parse_channels(os.get_env("ITD_LOG_CHANNELS", context.temp_allocator)),
		include_source  = logger_parse_bool(os.get_env("ITD_LOG_SOURCE", context.temp_allocator), true),
		flush_file      = logger_parse_bool(os.get_env("ITD_LOG_FLUSH", context.temp_allocator), true),
	}
}

logger_parse_bool :: proc(value: string, fallback: bool) -> bool {
	trimmed := logger_trim_ascii(value)
	if trimmed == "" {return fallback}

	if logger_ascii_equal_fold(trimmed, "1") ||
	   logger_ascii_equal_fold(trimmed, "true") ||
	   logger_ascii_equal_fold(trimmed, "yes") ||
	   logger_ascii_equal_fold(trimmed, "on") {
		return true
	}

	if logger_ascii_equal_fold(trimmed, "0") ||
	   logger_ascii_equal_fold(trimmed, "false") ||
	   logger_ascii_equal_fold(trimmed, "no") ||
	   logger_ascii_equal_fold(trimmed, "off") {
		return false
	}

	return fallback
}

logger_parse_level :: proc(value: string, fallback: log.Level) -> (level: log.Level, enabled: bool) {
	trimmed := logger_trim_ascii(value)
	if trimmed == "" {return fallback, true}

	if logger_ascii_equal_fold(trimmed, "debug") {return log.Level.Debug, true}
	if logger_ascii_equal_fold(trimmed, "info") {return log.Level.Info, true}
	if logger_ascii_equal_fold(trimmed, "warn") || logger_ascii_equal_fold(trimmed, "warning") {
		return log.Level.Warning, true
	}
	if logger_ascii_equal_fold(trimmed, "error") {return log.Level.Error, true}
	if logger_ascii_equal_fold(trimmed, "fatal") {return log.Level.Fatal, true}
	if logger_ascii_equal_fold(trimmed, "off") {return fallback, false}

	return fallback, true
}

logger_parse_channels :: proc(value: string) -> Game_Log_Channels {
	trimmed := logger_trim_ascii(value)
	if trimmed == "" || logger_ascii_equal_fold(trimmed, "all") {
		return Game_Log_Channels{
			.App,
			.Init,
			.Data,
			.Sprites,
			.Gen,
			.Fov,
			.Enemy,
			.Items,
			.Scores,
			.Audio,
			.Input,
			.Save,
		}
	}

	channels: Game_Log_Channels
	start := 0
	for i in 0 ..= len(trimmed) {
		if i == len(trimmed) || trimmed[i] == ',' {
			part := logger_trim_ascii(trimmed[start:i])
			if channel, ok := logger_channel_from_string(part); ok {
				channels += Game_Log_Channels{channel}
			}
			start = i + 1
		}
	}
	return channels
}

logger_channel_from_string :: proc(value: string) -> (channel: Game_Log_Channel, ok: bool) {
	trimmed := logger_trim_ascii(value)
	if logger_ascii_equal_fold(trimmed, "app") {return .App, true}
	if logger_ascii_equal_fold(trimmed, "init") {return .Init, true}
	if logger_ascii_equal_fold(trimmed, "data") {return .Data, true}
	if logger_ascii_equal_fold(trimmed, "sprites") || logger_ascii_equal_fold(trimmed, "sprite") {
		return .Sprites, true
	}
	if logger_ascii_equal_fold(trimmed, "gen") || logger_ascii_equal_fold(trimmed, "generation") {
		return .Gen, true
	}
	if logger_ascii_equal_fold(trimmed, "fov") {return .Fov, true}
	if logger_ascii_equal_fold(trimmed, "enemy") || logger_ascii_equal_fold(trimmed, "enemies") {
		return .Enemy, true
	}
	if logger_ascii_equal_fold(trimmed, "item") || logger_ascii_equal_fold(trimmed, "items") {
		return .Items, true
	}
	if logger_ascii_equal_fold(trimmed, "score") || logger_ascii_equal_fold(trimmed, "scores") {
		return .Scores, true
	}
	if logger_ascii_equal_fold(trimmed, "audio") {return .Audio, true}
	if logger_ascii_equal_fold(trimmed, "input") {return .Input, true}
	if logger_ascii_equal_fold(trimmed, "save") || logger_ascii_equal_fold(trimmed, "saveload") {
		return .Save, true
	}
	return .App, false
}

logger_channel_label :: proc(channel: Game_Log_Channel) -> string {
	switch channel {
	case .App:
		return "app"
	case .Init:
		return "init"
	case .Data:
		return "data"
	case .Sprites:
		return "sprites"
	case .Gen:
		return "gen"
	case .Fov:
		return "fov"
	case .Enemy:
		return "enemy"
	case .Items:
		return "items"
	case .Scores:
		return "scores"
	case .Audio:
		return "audio"
	case .Input:
		return "input"
	case .Save:
		return "save"
	}
	return "app"
}

// ─── Logging API ─────────────────────────────────────────────────────────────

logger_debugf :: proc(channel: Game_Log_Channel, fmt_str: string, args: ..any, location := #caller_location) {
	logger_logf(&g_logger, log.Level.Debug, channel, fmt_str, ..args, location=location)
}

logger_infof :: proc(channel: Game_Log_Channel, fmt_str: string, args: ..any, location := #caller_location) {
	logger_logf(&g_logger, log.Level.Info, channel, fmt_str, ..args, location=location)
}

logger_warnf :: proc(channel: Game_Log_Channel, fmt_str: string, args: ..any, location := #caller_location) {
	logger_logf(&g_logger, log.Level.Warning, channel, fmt_str, ..args, location=location)
}

logger_errorf :: proc(channel: Game_Log_Channel, fmt_str: string, args: ..any, location := #caller_location) {
	logger_logf(&g_logger, log.Level.Error, channel, fmt_str, ..args, location=location)
}

logger_fatalf :: proc(channel: Game_Log_Channel, fmt_str: string, args: ..any, location := #caller_location) {
	logger_logf(&g_logger, log.Level.Fatal, channel, fmt_str, ..args, location=location)
}

logger_logf :: proc(
	logger: ^Game_Logger,
	level: log.Level,
	channel: Game_Log_Channel,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	if !logger_should_log(logger, level, channel) {
		return
	}

	message := fmt.tprintf("[%s] ", logger_channel_label(channel))
	message = fmt.tprintf("%s%s", message, fmt.tprintf(fmt_str, ..args))

	if logger.console_ready && level >= logger.config.console_level {
		logger.console.procedure(logger.console.data, level, message, logger.console.options, location)
	}

	if logger.file_ready && level >= logger.config.file_level {
		logger.file.procedure(logger.file.data, level, message, logger.file.options, location)
		if logger.config.flush_file && logger.file_handle != nil {
			os.flush(logger.file_handle)
		}
	}
}

logger_should_log :: proc(logger: ^Game_Logger, level: log.Level, channel: Game_Log_Channel) -> bool {
	if logger == nil || !logger.config.enabled || !(channel in logger.config.channels) {
		return false
	}

	console_will_log := logger.console_ready && level >= logger.config.console_level
	file_will_log := logger.file_ready && level >= logger.config.file_level
	return console_will_log || file_will_log
}

// ─── String helpers ──────────────────────────────────────────────────────────

logger_trim_ascii :: proc(value: string) -> string {
	start := 0
	end := len(value)

	for start < end && logger_is_ascii_space(value[start]) {
		start += 1
	}
	for end > start && logger_is_ascii_space(value[end - 1]) {
		end -= 1
	}

	return value[start:end]
}

logger_ascii_equal_fold :: proc(a, b: string) -> bool {
	if len(a) != len(b) {return false}
	for i in 0 ..< len(a) {
		if logger_ascii_lower(a[i]) != logger_ascii_lower(b[i]) {
			return false
		}
	}
	return true
}

logger_ascii_lower :: proc(ch: u8) -> u8 {
	if ch >= 'A' && ch <= 'Z' {
		return ch + ('a' - 'A')
	}
	return ch
}

logger_is_ascii_space :: proc(ch: u8) -> bool {
	return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}
