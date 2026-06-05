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

// ─── Save / load API ──────────────────────────────────────────────────────────
Save_Manager :: gameio.Save_Manager
save_manager_make :: gameio.save_manager_make
save_manager_save_exists :: gameio.save_manager_save_exists
save_manager_save_game :: gameio.save_manager_save_game
save_manager_load_game :: gameio.save_manager_load_game
save_exists :: gameio.save_exists
save_exists_at :: gameio.save_exists_at
save_exists_in_storage :: gameio.save_exists_in_storage
save_game :: gameio.save_game
save_game_to_path :: gameio.save_game_to_path
save_game_to_storage :: gameio.save_game_to_storage
load_game :: gameio.load_game
load_game_from_path :: gameio.load_game_from_path
load_game_from_storage :: gameio.load_game_from_storage
SAVE_FILE :: gameio.SAVE_FILE
Save_Header :: gameio.Save_Header
load_save_data :: gameio.load_save_data
