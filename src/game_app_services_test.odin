#+build !js
package main

import eng "./engine"
import "base:runtime"
import "core:testing"

@(test)
game_app_registers_current_engine_services :: proc(t: ^testing.T) {
	services := eng.engine_services_make(eng.engine_services_default_config())
	defer eng.engine_services_destroy(&services)
	input_backend_state := Test_Game_App_Input_Backend_State{}
	audio_backend_state := Test_Game_App_Audio_Backend_State{}
	file_system_state := Test_Game_App_File_System_State{}
	audio_backend := test_game_app_audio_backend(&audio_backend_state)
	file_system := eng.Engine_File_System {
		ctx               = &file_system_state,
		read_entire_file  = test_game_app_file_system_read_entire_file,
		write_entire_file = test_game_app_file_system_write_entire_file,
		exists            = test_game_app_file_system_exists,
		remove            = test_game_app_file_system_remove,
	}
	engine := eng.Engine {
		config = game_engine_config(),
		services = &services,
		file_system = file_system,
		storage_manager = eng.storage_manager_make(file_system),
		audio = audio_backend,
		audio_manager = eng.audio_manager_make(audio_backend),
		camera_manager = eng.camera_manager_make(),
		turn_manager = eng.turn_manager_make(),
		vfx_manager = eng.vfx_manager_make(),
		message_manager = eng.message_manager_make(),
		particle_manager = eng.particle_manager_make(),
		input = eng.Engine_Input_Backend {
			ctx = &input_backend_state,
			key_down = test_game_app_input_key_down,
			key_pressed = test_game_app_input_key_pressed,
			key_released = test_game_app_input_key_released,
			frame_time = test_game_app_input_frame_time,
		},
	}
	register_handler: proc(engine: ^eng.Engine) -> bool = game_engine_register_app_services

	testing.expect(t, register_handler != nil)
	testing.expect(t, game_engine_register_app_services(&engine))
	testing.expect(t, game_engine_content_manager(&engine) != nil)
	testing.expect(
		t,
		game_engine_content_manager(&engine).storage.file_system.ctx == rawptr(&file_system_state),
	)
	testing.expect(t, game_engine_save_manager(&engine) != nil)
	testing.expect(
		t,
		game_engine_save_manager(&engine).storage.file_system.ctx == rawptr(&file_system_state),
	)
	testing.expect(t, game_engine_audio_manager(&engine) != nil)
	testing.expect(t, game_engine_audio_manager(&engine) == &engine.audio_manager)
	testing.expect(
		t,
		game_engine_audio_manager(&engine).backend.ctx == rawptr(&audio_backend_state),
	)
	testing.expect(t, game_engine_sprite_manager(&engine) != nil)
	testing.expect(t, game_engine_particle_manager(&engine) != nil)
	testing.expect(t, game_engine_particle_manager(&engine) == &engine.particle_manager)
	testing.expect(t, game_engine_score_manager(&engine) != nil)
	testing.expect(t, game_engine_input_manager(&engine) != nil)
	testing.expect(
		t,
		game_engine_input_manager(&engine).backend.ctx == rawptr(&input_backend_state),
	)
	testing.expect(t, game_engine_message_manager(&engine) != nil)
	testing.expect(t, game_engine_message_manager(&engine) == &engine.message_manager)
	testing.expect(t, game_engine_camera_manager(&engine) != nil)
	testing.expect(t, game_engine_camera_manager(&engine) == &engine.camera_manager)
	testing.expect(t, game_engine_turn_manager(&engine) != nil)
	testing.expect(t, game_engine_turn_manager(&engine) == &engine.turn_manager)
	testing.expect(t, game_engine_vfx_manager(&engine) != nil)
	testing.expect(t, game_engine_vfx_manager(&engine) == &engine.vfx_manager)
	testing.expect(t, game_engine_ui_manager(&engine) != nil)
	testing.expect_value(t, services.service_count, 6)
	for i in 0 ..< services.service_count {
		testing.expect(t, services.services[i].owned)
	}
}

@(test)
game_engine_config_provides_game_audio_backend :: proc(t: ^testing.T) {
	config := game_engine_config()

	testing.expect(t, eng.engine_audio_backend_is_valid(config.audio))
	testing.expect(t, config.audio.ctx == rawptr(&g_raylib_audio))
}

Test_Game_App_Input_Backend_State :: struct {}

test_game_app_input_key_down :: proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
	return false
}

test_game_app_input_key_pressed :: proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
	return false
}

test_game_app_input_key_released :: proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
	return false
}

test_game_app_input_frame_time :: proc(ctx: rawptr) -> f32 {
	return 0
}

Test_Game_App_Audio_Backend_State :: struct {
	enabled: bool,
}

Test_Game_App_File_System_State :: struct {}

test_game_app_audio_backend :: proc(
	state: ^Test_Game_App_Audio_Backend_State,
) -> eng.Engine_Audio_Backend {
	return eng.Engine_Audio_Backend {
		ctx = state,
		play = test_game_app_audio_play,
		is_enabled = test_game_app_audio_is_enabled,
		set_enabled = test_game_app_audio_set_enabled,
		toggle = test_game_app_audio_toggle,
	}
}

test_game_app_audio_play :: proc(ctx: rawptr, sound_id: int) {}

test_game_app_audio_is_enabled :: proc(ctx: rawptr) -> bool {
	state := cast(^Test_Game_App_Audio_Backend_State)ctx
	return state.enabled
}

test_game_app_audio_set_enabled :: proc(ctx: rawptr, enabled: bool) -> bool {
	state := cast(^Test_Game_App_Audio_Backend_State)ctx
	state.enabled = enabled
	return state.enabled
}

test_game_app_audio_toggle :: proc(ctx: rawptr) -> bool {
	state := cast(^Test_Game_App_Audio_Backend_State)ctx
	state.enabled = !state.enabled
	return state.enabled
}

test_game_app_file_system_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	return {}, false
}

test_game_app_file_system_write_entire_file :: proc(
	ctx: rawptr,
	path: string,
	data: []u8,
) -> bool {
	return false
}

test_game_app_file_system_exists :: proc(ctx: rawptr, path: string) -> bool {
	return false
}

test_game_app_file_system_remove :: proc(ctx: rawptr, path: string) -> bool {
	return false
}