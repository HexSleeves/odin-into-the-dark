package core

import eng "../engine"

// Engine service-locator accessors that depend only on engine + core types.
// They live in core (which every sub-package imports) so leaf packages alias
// gcore.* directly instead of routing through the render layer. Accessors that
// return renderer/ui-owned types (sprite/ui/score managers) stay in
// src/render/services.odin to avoid a core->render import cycle.

game_engine_turn_manager :: proc(engine: ^eng.Engine) -> ^eng.Turn_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Turn_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_TURNS,
		) \
	)
}

game_engine_message_manager :: proc(engine: ^eng.Engine) -> ^eng.Message_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Message_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_MESSAGES,
		) \
	)
}

game_engine_camera_manager :: proc(engine: ^eng.Engine) -> ^eng.Camera_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Camera_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_CAMERA,
		) \
	)
}

game_engine_vfx_manager :: proc(engine: ^eng.Engine) -> ^eng.Vfx_Manager {
	if engine == nil || engine.services == nil {return nil}
	return cast(^eng.Vfx_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_VFX)
}

game_engine_particle_manager :: proc(engine: ^eng.Engine) -> ^eng.Particle_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Particle_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_PARTICLES,
		) \
	)
}

game_engine_frame_manager :: proc(engine: ^eng.Engine) -> ^eng.Frame_Manager {
	return eng.engine_frame_manager(engine)
}

game_engine_floating_text_manager :: proc(engine: ^eng.Engine) -> ^eng.Floating_Text_Manager {
	return eng.engine_floating_text_manager(engine)
}

game_engine_save_manager :: proc(engine: ^eng.Engine) -> ^Save_Manager {
	if engine == nil || engine.services == nil {return nil}
	return cast(^Save_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_SAVES)
}

game_engine_content_manager :: proc(engine: ^eng.Engine) -> ^Content_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^Content_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_CONTENT,
		) \
	)
}

game_camera_x :: proc(camera: ^eng.Camera_Manager) -> int {
	if camera == nil {return 0}
	return int(camera.x)
}

game_camera_y :: proc(camera: ^eng.Camera_Manager) -> int {
	if camera == nil {return 0}
	return int(camera.y)
}
