package engine

import "base:runtime"

// ─── Engine runtime boundary ─────────────────────────────────────────────────

Engine_Config :: struct {
	window_width:  i32,
	window_height: i32,
	window_title:  cstring,
	target_fps:    i32,
	platform:      Engine_Platform_Backend,
	file_system:   Engine_File_System,
	audio:         Engine_Audio_Backend,
	input:         Engine_Input_Backend,
	render:        Engine_Render_Backend,
	texture:       Engine_Texture_Backend,
}

Engine :: struct {
	config:           Engine_Config,
	services:         ^Engine_Services,
	scene_manager:    Scene_Manager,
	frame_manager:    Frame_Manager,
	event_manager:    Event_Manager,
	texture_manager:  Texture_Manager,
	audio_manager:    Audio_Manager,
	storage_manager:  Storage_Manager,
	camera_manager:   Camera_Manager,
	turn_manager:     Turn_Manager,
	vfx_manager:      Vfx_Manager,
	message_manager:  Message_Manager,
	particle_manager: Particle_Manager,
	file_system:      Engine_File_System,
	audio:            Engine_Audio_Backend,
	input:            Engine_Input_Backend,
	render:           Engine_Render_Backend,
	texture:          Engine_Texture_Backend,
}

Game_App :: struct {
	name:     string,
	state:    rawptr,
	init:     proc(engine: ^Engine, app: ^Game_App) -> bool,
	update:   proc(engine: ^Engine, app: ^Game_App) -> bool,
	render:   proc(engine: ^Engine, app: ^Game_App),
	shutdown: proc(engine: ^Engine, app: ^Game_App),
	autosave: proc(engine: ^Engine, app: ^Game_App),
}

engine_config_make :: proc(
	window_width: i32,
	window_height: i32,
	window_title: cstring,
	target_fps: i32,
) -> Engine_Config {
	return Engine_Config {
		window_width = window_width,
		window_height = window_height,
		window_title = window_title,
		target_fps = target_fps,
	}
}

engine_scene_manager :: proc(engine: ^Engine) -> ^Scene_Manager {
	if engine == nil {
		return nil
	}
	return &engine.scene_manager
}

engine_frame_manager :: proc(engine: ^Engine) -> ^Frame_Manager {
	if engine == nil {
		return nil
	}
	return &engine.frame_manager
}

engine_event_manager :: proc(engine: ^Engine) -> ^Event_Manager {
	if engine == nil {
		return nil
	}
	return &engine.event_manager
}

engine_texture_manager :: proc(engine: ^Engine) -> ^Texture_Manager {
	if engine == nil {
		return nil
	}
	return &engine.texture_manager
}

engine_audio_manager :: proc(engine: ^Engine) -> ^Audio_Manager {
	if engine == nil {
		return nil
	}
	return &engine.audio_manager
}

engine_storage_manager :: proc(engine: ^Engine) -> ^Storage_Manager {
	if engine == nil {
		return nil
	}
	return &engine.storage_manager
}

engine_camera_manager :: proc(engine: ^Engine) -> ^Camera_Manager {
	if engine == nil {
		return nil
	}
	return &engine.camera_manager
}

engine_turn_manager :: proc(engine: ^Engine) -> ^Turn_Manager {
	if engine == nil {
		return nil
	}
	return &engine.turn_manager
}

engine_vfx_manager :: proc(engine: ^Engine) -> ^Vfx_Manager {
	if engine == nil {
		return nil
	}
	return &engine.vfx_manager
}

engine_message_manager :: proc(engine: ^Engine) -> ^Message_Manager {
	if engine == nil {
		return nil
	}
	return &engine.message_manager
}

engine_particle_manager :: proc(engine: ^Engine) -> ^Particle_Manager {
	if engine == nil {
		return nil
	}
	return &engine.particle_manager
}

engine_file_system :: proc(engine: ^Engine) -> Engine_File_System {
	if engine == nil {
		return engine_file_system_default()
	}
	return engine_file_system_or_default(engine.file_system)
}

engine_input_backend :: proc(engine: ^Engine) -> Engine_Input_Backend {
	if engine == nil {
		return engine_input_backend_default()
	}
	return engine_input_backend_or_default(engine.input)
}

engine_audio_backend :: proc(engine: ^Engine) -> Engine_Audio_Backend {
	if engine == nil {
		return engine_audio_backend_nil()
	}
	return engine_audio_backend_or_default(engine.audio)
}

engine_render_backend :: proc(engine: ^Engine) -> Engine_Render_Backend {
	if engine == nil {
		return engine_render_backend_default()
	}
	return engine_render_backend_or_default(engine.render)
}

engine_texture_backend :: proc(engine: ^Engine) -> Engine_Texture_Backend {
	if engine == nil {
		return engine_texture_backend_default()
	}
	return engine_texture_backend_or_default(engine.texture)
}

engine_frame_allocator :: proc(engine: ^Engine) -> runtime.Allocator {
	if engine == nil {
		return context.allocator
	}
	return frame_manager_allocator(&engine.frame_manager)
}

// ─── Split lifecycle for web (init/step/shutdown) ─────────────────────────────

Engine_State :: struct {
	engine:              Engine,
	services:            Engine_Services,
	platform:            Engine_Platform_Backend,
	app:                 ^Game_App,
	diagnostics_started: bool,
	runtime_started:     bool,
	platform_started:    bool,
	app_started:         bool,
}

engine_init :: proc(
	state: ^Engine_State,
	config: Engine_Config,
	services_config: Engine_Services_Config,
	app: ^Game_App,
) -> bool {
	state.services = engine_services_make(services_config)
	state.app = app

	state.engine = Engine {
		config      = config,
		services    = &state.services,
		file_system = engine_file_system_or_default(config.file_system),
		audio       = engine_audio_backend_or_default(config.audio),
		input       = engine_input_backend_or_default(config.input),
		render      = engine_render_backend_or_default(config.render),
		texture     = engine_texture_backend_or_default(config.texture),
	}

	state.engine.texture_manager = texture_manager_make(state.engine.texture)
	state.engine.audio_manager = audio_manager_make(state.engine.audio)
	state.engine.storage_manager = storage_manager_make(state.engine.file_system)
	state.engine.camera_manager = camera_manager_make()
	state.engine.turn_manager = turn_manager_make()
	state.engine.vfx_manager = vfx_manager_make()
	state.engine.message_manager = message_manager_make()
	message_manager_bind_turns(&state.engine.message_manager, &state.engine.turn_manager)
	state.engine.particle_manager = particle_manager_make()

	state.platform = engine_platform_backend_or_default(config.platform)

	engine_services_init_diagnostics(&state.services)
	state.diagnostics_started = true

	if !state.platform.init(state.platform.ctx, config) {
		return false
	}
	state.platform_started = true
	state.platform.set_target_fps(state.platform.ctx, config.target_fps)

	engine_services_init_runtime_assets(&state.services)
	state.runtime_started = true

	if app == nil || app.init == nil || !app.init(&state.engine, app) {
		return false
	}
	state.app_started = true

	state.platform.disable_exit_key(state.platform.ctx)
	return true
}

// engine_step runs one frame. Returns false when the game should exit.
engine_step :: proc(state: ^Engine_State) -> bool {
	if state.platform.window_should_close(state.platform.ctx) {
		return false
	}

	frame_manager_begin(&state.engine.frame_manager, engine_input_frame_time(state.engine.input))
	frame_manager_clear_quit(&state.engine.frame_manager)
	event_manager_clear(&state.engine.event_manager)
	audio_manager_update(&state.engine.audio_manager)

	quit := false
	if state.app.update != nil {
		old_context := context
		context.allocator = engine_frame_allocator(&state.engine)
		quit = state.app.update(&state.engine, state.app)
		context = old_context
	}
	if quit || frame_manager_quit_requested(state.engine.frame_manager) {
		return false
	}

	if state.app.render != nil {
		old_context := context
		context.allocator = engine_frame_allocator(&state.engine)
		state.app.render(&state.engine, state.app)
		context = old_context
	}
	return true
}

engine_shutdown :: proc(state: ^Engine_State) {
	if state.app_started && state.app != nil {
		if state.app.autosave != nil {
			state.app.autosave(&state.engine, state.app)
		}
		state.app.shutdown(&state.engine, state.app)
	}
	if state.runtime_started {
		engine_services_shutdown_runtime_assets(&state.services)
	}
	if state.platform_started {
		state.platform.shutdown(state.platform.ctx)
	}
	if state.diagnostics_started {
		engine_services_shutdown_diagnostics(&state.services)
	}
	texture_manager_unload_all(&state.engine.texture_manager)
	frame_manager_destroy(&state.engine.frame_manager)
	engine_services_destroy(&state.services)
}

// ─── Desktop convenience wrapper ─────────────────────────────────────────────

engine_run :: proc(
	config: Engine_Config,
	services_config: Engine_Services_Config,
	app: ^Game_App,
) {
	state: Engine_State
	if !engine_init(&state, config, services_config, app) {
		engine_shutdown(&state)
		return
	}
	for engine_step(&state) {}
	engine_shutdown(&state)
}
