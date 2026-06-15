package renderer

import gcore "../core"
import eng "../engine"
import ui_pkg "../ui"

// Engine/core-typed service accessors now live in package core
// (src/core/services.odin); re-aliased here so renderer's bare-name call sites
// keep resolving without churn.
game_engine_turn_manager :: gcore.game_engine_turn_manager
game_engine_message_manager :: gcore.game_engine_message_manager
game_engine_camera_manager :: gcore.game_engine_camera_manager
game_engine_vfx_manager :: gcore.game_engine_vfx_manager
game_engine_particle_manager :: gcore.game_engine_particle_manager
game_engine_frame_manager :: gcore.game_engine_frame_manager
game_engine_floating_text_manager :: gcore.game_engine_floating_text_manager
game_engine_save_manager :: gcore.game_engine_save_manager
game_engine_content_manager :: gcore.game_engine_content_manager
game_camera_x :: gcore.game_camera_x
game_camera_y :: gcore.game_camera_y

// Accessors returning renderer/ui-owned types stay here — moving them to core
// would create a core->render/ui import cycle.

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

game_engine_score_manager :: proc(engine: ^eng.Engine) -> ^Score_Manager {
	if engine == nil || engine.services == nil {return nil}
	return(
		cast(^Score_Manager)eng.engine_services_get(
			engine.services,
			gcore.GAME_ENGINE_SERVICE_SCORES,
		) \
	)
}
