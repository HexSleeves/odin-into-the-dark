package engine

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

engine_run :: proc(
	config: Engine_Config,
	services_config: Engine_Services_Config,
	app: ^Game_App,
) {
	services := engine_services_make(services_config)
	defer engine_services_destroy(&services)
	engine := Engine {
		config      = config,
		services    = &services,
		file_system = engine_file_system_or_default(config.file_system),
		audio       = engine_audio_backend_or_default(config.audio),
		input       = engine_input_backend_or_default(config.input),
		render      = engine_render_backend_or_default(config.render),
		texture     = engine_texture_backend_or_default(config.texture),
	}
	engine.texture_manager = texture_manager_make(engine.texture)
	engine.audio_manager = audio_manager_make(engine.audio)
	engine.camera_manager = camera_manager_make()
	engine.turn_manager = turn_manager_make()
	engine.vfx_manager = vfx_manager_make()
	engine.message_manager = message_manager_make()
	message_manager_bind_turns(&engine.message_manager, &engine.turn_manager)
	engine.particle_manager = particle_manager_make()
	defer texture_manager_unload_all(&engine.texture_manager)
	platform := engine_platform_backend_or_default(config.platform)

	engine_services_init_diagnostics(&services)
	defer engine_services_shutdown_diagnostics(&services)

	if !platform.init(platform.ctx, config) {
		return
	}
	defer platform.shutdown(platform.ctx)
	platform.set_target_fps(platform.ctx, config.target_fps)

	engine_services_init_runtime_assets(&services)
	defer engine_services_shutdown_runtime_assets(&services)

	if app == nil || app.init == nil || !app.init(&engine, app) {
		return
	}
	defer app.shutdown(&engine, app)

	// Disable default escape key to allow inventory to be closed with ESC.
	platform.disable_exit_key(platform.ctx)

	for !platform.window_should_close(platform.ctx) {
		frame_manager_begin(&engine.frame_manager, engine_input_frame_time(engine.input))
		frame_manager_clear_quit(&engine.frame_manager)
		event_manager_clear(&engine.event_manager)

		quit := false
		if app.update != nil {
			quit = app.update(&engine, app)
		}
		if quit || frame_manager_quit_requested(engine.frame_manager) {
			break
		}

		if app.render != nil {
			app.render(&engine, app)
		}
	}

	if app.autosave != nil {
		app.autosave(&engine, app)
	}
}
