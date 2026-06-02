package main

import "core:testing"
import eng "./engine"

@(test)
game_app_registers_current_engine_services :: proc(t: ^testing.T) {
	services := eng.engine_services_make(eng.engine_services_default_config())
	defer eng.engine_services_destroy(&services)
	engine := eng.Engine {
		config = game_engine_config(),
		services = &services,
	}
	register_handler: proc(engine: ^eng.Engine) -> bool = game_engine_register_app_services

	testing.expect(t, register_handler != nil)
	testing.expect(t, game_engine_register_app_services(&engine))
	testing.expect(t, game_engine_content_manager(&engine) != nil)
	testing.expect(t, game_engine_save_manager(&engine) != nil)
	testing.expect(t, game_engine_audio_manager(&engine) != nil)
	testing.expect(t, game_engine_sprite_manager(&engine) != nil)
	testing.expect(t, game_engine_particle_manager(&engine) != nil)
	testing.expect(t, game_engine_score_manager(&engine) != nil)
	testing.expect(t, game_engine_input_manager(&engine) != nil)
	testing.expect(t, game_engine_message_manager(&engine) != nil)
	testing.expect(t, game_engine_camera_manager(&engine) != nil)
	testing.expect(t, game_engine_turn_manager(&engine) != nil)
	testing.expect(t, game_engine_vfx_manager(&engine) != nil)
	testing.expect_value(t, services.service_count, 11)
	for i in 0 ..< services.service_count {
		testing.expect(t, services.services[i].owned)
	}
}
