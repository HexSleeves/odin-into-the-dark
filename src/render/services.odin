package renderer

import gcore "../core"
import eng "../engine"
import ui_pkg "../ui"

game_engine_turn_manager :: proc(engine: ^eng.Engine) -> ^eng.Turn_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Turn_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_TURNS,
		) \
	)
}

game_engine_message_manager :: proc(engine: ^eng.Engine) -> ^eng.Message_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Message_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_MESSAGES,
		) \
	)
}

game_engine_camera_manager :: proc(engine: ^eng.Engine) -> ^eng.Camera_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Camera_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_CAMERA,
		) \
	)
}

game_engine_vfx_manager :: proc(engine: ^eng.Engine) -> ^eng.Vfx_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Vfx_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_VFX,
		) \
	)
}

game_engine_particle_manager :: proc(engine: ^eng.Engine) -> ^eng.Particle_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^eng.Particle_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_PARTICLES,
		) \
	)
}

game_engine_frame_manager :: proc(engine: ^eng.Engine) -> ^eng.Frame_Manager {
	return eng.engine_frame_manager(engine)
}

game_engine_floating_text_manager :: proc(engine: ^eng.Engine) -> ^eng.Floating_Text_Manager {
	return eng.engine_floating_text_manager(engine)
}

game_engine_sprite_manager :: proc(engine: ^eng.Engine) -> ^Sprite_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^Sprite_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SPRITES,
		) \
	)
}

game_engine_ui_manager :: proc(engine: ^eng.Engine) -> ^ui_pkg.UI_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^ui_pkg.UI_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_UI,
		) \
	)
}

game_engine_save_manager :: proc(engine: ^eng.Engine) -> ^gcore.Save_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^gcore.Save_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SAVES,
		) \
	)
}

game_engine_score_manager :: proc(engine: ^eng.Engine) -> ^Score_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^Score_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SCORES,
		) \
	)
}

game_engine_content_manager :: proc(engine: ^eng.Engine) -> ^gcore.Content_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^gcore.Content_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_CONTENT,
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
