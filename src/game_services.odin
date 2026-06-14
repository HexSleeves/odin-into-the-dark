package main

import gameaudio "./audio"
import gcore "./core"
import eng "./engine"
import gameinput "./input"
import gameio "./io"
import renderer "./render"
import gameui "./ui"

// Bare re-exports of the canonical service ids (single source: src/core/service_ids.odin).
// These are aliases, not redefinitions — the value lives only in gcore.
GAME_ENGINE_SERVICE_CONTENT :: gcore.GAME_ENGINE_SERVICE_CONTENT
GAME_ENGINE_SERVICE_SAVES :: gcore.GAME_ENGINE_SERVICE_SAVES
GAME_ENGINE_SERVICE_AUDIO :: gcore.GAME_ENGINE_SERVICE_AUDIO
GAME_ENGINE_SERVICE_SPRITES :: gcore.GAME_ENGINE_SERVICE_SPRITES
GAME_ENGINE_SERVICE_PARTICLES :: gcore.GAME_ENGINE_SERVICE_PARTICLES
GAME_ENGINE_SERVICE_SCORES :: gcore.GAME_ENGINE_SERVICE_SCORES
GAME_ENGINE_SERVICE_INPUT :: gcore.GAME_ENGINE_SERVICE_INPUT
GAME_ENGINE_SERVICE_MESSAGES :: gcore.GAME_ENGINE_SERVICE_MESSAGES
GAME_ENGINE_SERVICE_CAMERA :: gcore.GAME_ENGINE_SERVICE_CAMERA
GAME_ENGINE_SERVICE_TURNS :: gcore.GAME_ENGINE_SERVICE_TURNS
GAME_ENGINE_SERVICE_VFX :: gcore.GAME_ENGINE_SERVICE_VFX
GAME_ENGINE_SERVICE_UI :: gcore.GAME_ENGINE_SERVICE_UI

Into_The_Depths_App_State :: struct {
	game:              ^gcore.Game,
	scene_descriptors: [GAME_SCENE_COUNT]eng.Engine_Scene,
}

game_engine_register_app_services :: proc(engine: ^eng.Engine) -> bool {
	if engine == nil || engine.services == nil {
		return false
	}
	content := gcore.content_manager_make()
	saves := gameio.save_manager_make()
	saves.storage = eng.storage_manager_make(eng.engine_file_system(engine))
	sprites := renderer.sprite_manager_make()
	scores := renderer.score_manager_make()
	scores.storage = eng.storage_manager_make(eng.engine_file_system(engine))
	input := gameinput.input_manager_make()
	input.backend = eng.engine_input_backend(engine)
	ui := gameui.ui_manager_make(DEFAULT_USE_SPRITES)
	// content, saves, input use engine_service_register_typed to capture typeid for
	// safe retrieval via engine_service_get_typed.
	// TODO: route remaining register_value sites through engine_service_register_typed
	return(
		eng.engine_service_register_typed(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_CONTENT,
			&content,
		) !=
			nil &&
		eng.engine_service_register_typed(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SAVES,
			&saves,
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SPRITES,
			&sprites,
			size_of(renderer.Sprite_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SCORES,
			&scores,
			size_of(renderer.Score_Manager),
		) !=
			nil &&
		eng.engine_service_register_typed(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_INPUT,
			&input,
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_UI,
			&ui,
			size_of(gameui.UI_Manager),
		) !=
			nil &&
		eng.engine_services_register(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_TURNS,
			&engine.turn_manager,
		) &&
		eng.engine_services_register(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_CAMERA,
			&engine.camera_manager,
		) &&
		eng.engine_services_register(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_VFX,
			&engine.vfx_manager,
		) &&
		eng.engine_services_register(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_MESSAGES,
			&engine.message_manager,
		) &&
		eng.engine_services_register(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_PARTICLES,
			&engine.particle_manager,
		) \
	)
}

game_engine_content_manager :: proc(engine: ^eng.Engine) -> ^gcore.Content_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return eng.engine_service_get_typed(
		engine.services,
		gcore.GAME_ENGINE_SERVICE_CONTENT,
		gcore.Content_Manager,
	)
}

game_engine_save_manager :: proc(engine: ^eng.Engine) -> ^gcore.Save_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return eng.engine_service_get_typed(
		engine.services,
		gcore.GAME_ENGINE_SERVICE_SAVES,
		gcore.Save_Manager,
	)
}

game_engine_audio_manager :: proc(engine: ^eng.Engine) -> ^gameaudio.Audio_Manager {
	return eng.engine_audio_manager(engine)
}

game_engine_sprite_manager :: proc(engine: ^eng.Engine) -> ^renderer.Sprite_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return(
		cast(^renderer.Sprite_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SPRITES,
		) \
	)
}

game_engine_particle_manager :: proc(engine: ^eng.Engine) -> ^eng.Particle_Manager {
	return eng.engine_particle_manager(engine)
}

game_engine_score_manager :: proc(engine: ^eng.Engine) -> ^renderer.Score_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return(
		cast(^renderer.Score_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SCORES,
		) \
	)
}

game_engine_input_manager :: proc(engine: ^eng.Engine) -> ^gameinput.Input_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return eng.engine_service_get_typed(
		engine.services,
		gcore.GAME_ENGINE_SERVICE_INPUT,
		gameinput.Input_Manager,
	)
	// TODO: route remaining accessors through engine_service_get_typed
}

game_engine_message_manager :: proc(engine: ^eng.Engine) -> ^eng.Message_Manager {
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

game_engine_ui_manager :: proc(engine: ^eng.Engine) -> ^gameui.UI_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return(
		cast(^gameui.UI_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_UI,
		) \
	)
}
