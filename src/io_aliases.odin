package main

// Re-export of the `io` package public API (logging + low-level asset/backend
// I/O) into `package main`, so existing call sites stay unqualified.
import gameio "./io"

// ─── Logger types ─────────────────────────────────────────────────────────────
Game_Logger :: gameio.Game_Logger
Game_Logger_Config :: gameio.Game_Logger_Config
Game_Log_Channel :: gameio.Game_Log_Channel
Game_Log_Channels :: gameio.Game_Log_Channels

// ─── Logger API ───────────────────────────────────────────────────────────────
logger_init_from_config :: gameio.logger_init_from_config
logger_init_from_env :: gameio.logger_init_from_env
logger_destroy :: gameio.logger_destroy
logger_logf :: gameio.logger_logf
logger_debugf :: gameio.logger_debugf
logger_infof :: gameio.logger_infof
logger_warnf :: gameio.logger_warnf
logger_errorf :: gameio.logger_errorf
logger_fatalf :: gameio.logger_fatalf
logger_should_log :: gameio.logger_should_log
logger_state :: gameio.logger_state
