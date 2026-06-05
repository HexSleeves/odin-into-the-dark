package main

import eng "./engine"

GAME_ENGINE_SERVICE_CONTENT :: eng.Engine_Service_Id(1)
GAME_ENGINE_SERVICE_SAVES :: eng.Engine_Service_Id(2)
GAME_ENGINE_SERVICE_AUDIO :: eng.Engine_Service_Id(3)
GAME_ENGINE_SERVICE_SPRITES :: eng.Engine_Service_Id(4)
GAME_ENGINE_SERVICE_PARTICLES :: eng.Engine_Service_Id(5)
GAME_ENGINE_SERVICE_SCORES :: eng.Engine_Service_Id(6)
GAME_ENGINE_SERVICE_INPUT :: eng.Engine_Service_Id(7)
GAME_ENGINE_SERVICE_MESSAGES :: eng.Engine_Service_Id(8)
GAME_ENGINE_SERVICE_CAMERA :: eng.Engine_Service_Id(9)
GAME_ENGINE_SERVICE_TURNS :: eng.Engine_Service_Id(10)
GAME_ENGINE_SERVICE_VFX :: eng.Engine_Service_Id(11)
GAME_ENGINE_SERVICE_UI :: eng.Engine_Service_Id(12)

Into_The_Depths_App_State :: struct {
	game:              ^Game,
	scene_descriptors: [GAME_SCENE_COUNT]eng.Engine_Scene,
}
game_engine_register_app_services :: proc(engine: ^eng.Engine) -> bool {
	if engine == nil || engine.services == nil {
		return false
	}
	content := content_manager_make()
	// Data is #load'd at compile time — no storage backend needed.
	saves := save_manager_make()
	saves.storage = eng.storage_manager_make(eng.engine_file_system(engine))
	sprites := sprite_manager_make()
	scores := score_manager_make()
	scores.storage = eng.storage_manager_make(eng.engine_file_system(engine))
	input := input_manager_make()
	input.backend = eng.engine_input_backend(engine)
	ui := ui_manager_make(DEFAULT_USE_SPRITES)
	return(
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_CONTENT,
			&content,
			size_of(Content_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_SAVES,
			&saves,
			size_of(Save_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_SPRITES,
			&sprites,
			size_of(Sprite_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_SCORES,
			&scores,
			size_of(Score_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_INPUT,
			&input,
			size_of(Input_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_UI,
			&ui,
			size_of(UI_Manager),
		) !=
			nil \
	)
}

game_engine_content_manager :: proc(engine: ^eng.Engine) -> ^Content_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return(
		cast(^Content_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_CONTENT,
		) \
	)
}

game_engine_save_manager :: proc(engine: ^eng.Engine) -> ^Save_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Save_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_SAVES)
}

game_engine_audio_manager :: proc(engine: ^eng.Engine) -> ^Audio_Manager {
	return eng.engine_audio_manager(engine)
}

game_engine_sprite_manager :: proc(engine: ^eng.Engine) -> ^Sprite_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return(
		cast(^Sprite_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_SPRITES,
		) \
	)
}

game_engine_particle_manager :: proc(engine: ^eng.Engine) -> ^Particle_Manager {
	return eng.engine_particle_manager(engine)
}

game_engine_score_manager :: proc(engine: ^eng.Engine) -> ^Score_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Score_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_SCORES)
}

game_engine_input_manager :: proc(engine: ^eng.Engine) -> ^Input_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Input_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_INPUT)
}

game_engine_message_manager :: proc(engine: ^eng.Engine) -> ^Message_Manager {
	return eng.engine_message_manager(engine)
}

game_engine_camera_manager :: proc(engine: ^eng.Engine) -> ^eng.Camera_Manager {
	return eng.engine_camera_manager(engine)
}

game_engine_turn_manager :: proc(engine: ^eng.Engine) -> ^eng.Turn_Manager {
	return eng.engine_turn_manager(engine)
}

game_engine_vfx_manager :: proc(engine: ^eng.Engine) -> ^eng.Vfx_Manager {
	return eng.engine_vfx_manager(engine)
}
game_engine_frame_manager :: proc(engine: ^eng.Engine) -> ^eng.Frame_Manager {
	return eng.engine_frame_manager(engine)
}


game_engine_ui_manager :: proc(engine: ^eng.Engine) -> ^UI_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^UI_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_UI)
}
