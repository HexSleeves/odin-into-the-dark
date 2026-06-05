package main

import eng "./engine"
import "core:strconv"


Game_Config :: struct {
	master_volume: f32,
	music_volume:  f32,
}

g_game_config: Game_Config
g_config: eng.Config_Manager

game_engine_config :: proc() -> eng.Engine_Config {
	config := eng.engine_config_make(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths", 60)
	when ODIN_OS == .JS {
		// Web: karl2d backends, nil audio (no music streaming on web yet)
		config.platform = karl2d_platform_backend()
		config.render = karl2d_render_backend()
		config.input = karl2d_input_backend()
		config.texture = karl2d_texture_backend()
	} else {
		// Desktop: Raylib defaults + optional game audio backend
		when !NO_AUDIO {
			config.audio = game_audio_backend(audio_state())
		}
	}
	return config
}

game_engine_services_config :: proc() -> eng.Engine_Services_Config {
	return eng.Engine_Services_Config {
		diagnostics_init = game_diagnostics_init,
		diagnostics_shutdown = game_diagnostics_shutdown,
		runtime_assets_init = game_runtime_assets_init,
		runtime_assets_shutdown = game_runtime_assets_shutdown,
	}
}

game_diagnostics_init :: proc() {
	g_config = eng.config_manager_make()
	eng.config_manager_load_env_file(&g_config, ".env")
	logger_init_from_config(logger_state(), &g_config)

	if v, ok := strconv.parse_f32(eng.config_manager_get_or(&g_config, "ITD_MASTER_VOLUME", ""));
	   ok && v > 0 {
		g_game_config.master_volume = v
	} else {
		g_game_config.master_volume = 0.7
	}
	if v, ok := strconv.parse_f32(eng.config_manager_get_or(&g_config, "ITD_MUSIC_VOLUME", ""));
	   ok && v > 0 {
		g_game_config.music_volume = v
	} else {
		g_game_config.music_volume = 0.3
	}
}

game_diagnostics_shutdown :: proc() {
	logger_destroy(logger_state())
}

game_runtime_assets_init :: proc() {
	when ODIN_OS != .JS {
		when !NO_AUDIO {
			backend := game_audio_backend(audio_state())
			audio_init(backend)
			music_init()
			audio_set_master_volume(g_game_config.master_volume)
			music_set_volume(g_game_config.music_volume)
		}
	}
}

game_runtime_assets_shutdown :: proc() {
	when ODIN_OS != .JS {
		when !NO_AUDIO {
			music_cleanup()
			audio_cleanup()
		}
	}
}
