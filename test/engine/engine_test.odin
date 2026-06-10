#+build !js
package engine

import "base:runtime"
import "core:testing"

@(test)
engine_config_make_uses_requested_window_settings :: proc(t: ^testing.T) {
	config := engine_config_make(1280, 720, "Test Window", 144)

	testing.expect_value(t, config.window_width, 1280)
	testing.expect_value(t, config.window_height, 720)
	testing.expect(t, string(config.window_title) == "Test Window")
	testing.expect_value(t, config.target_fps, 144)
}

@(test)
game_app_callbacks_are_initialized :: proc(t: ^testing.T) {
	app := Game_App {
		name     = "Test App",
		init     = test_app_init,
		update   = test_app_update,
		render   = test_app_render,
		shutdown = test_app_shutdown,
		autosave = test_app_autosave,
	}

	testing.expect(t, app.init != nil)
	testing.expect(t, app.update != nil)
	testing.expect(t, app.render != nil)
	testing.expect(t, app.shutdown != nil)
	testing.expect(t, app.autosave != nil)
	testing.expect_value(t, app.name, "Test App")
}

@(test)
engine_exposes_owned_scene_manager :: proc(t: ^testing.T) {
	engine := Engine{}
	manager := engine_scene_manager(&engine)

	testing.expect(t, manager == &engine.scene_manager)
	testing.expect(t, !scene_manager_has_active(manager))
}

@(test)
engine_exposes_owned_generic_runtime_managers :: proc(t: ^testing.T) {
	engine := Engine{}

	testing.expect(t, engine_camera_manager(&engine) == &engine.camera_manager)
	testing.expect(t, engine_turn_manager(&engine) == &engine.turn_manager)
	testing.expect(t, engine_vfx_manager(&engine) == &engine.vfx_manager)
	testing.expect(t, engine_message_manager(&engine) == &engine.message_manager)
	testing.expect(t, engine_particle_manager(&engine) == &engine.particle_manager)
}

@(test)
engine_run_uses_configured_platform_backend :: proc(t: ^testing.T) {
	platform_state := Test_Platform_State{}
	file_system_state := Test_Run_File_System_State{}
	render_state := Test_Render_Backend_State{}
	input_state := Test_Run_Input_Backend_State {
		frame_time = 0.125,
	}
	texture_state := Test_Texture_Backend_State{}
	app_state := Test_Run_App_State{}
	config := engine_config_make(640, 360, "Backend Test", 144)
	config.platform = Engine_Platform_Backend {
		ctx                 = &platform_state,
		init                = test_platform_init,
		shutdown            = test_platform_shutdown,
		set_target_fps      = test_platform_set_target_fps,
		disable_exit_key    = test_platform_disable_exit_key,
		window_should_close = test_platform_window_should_close,
	}
	config.file_system = Engine_File_System {
		ctx               = &file_system_state,
		read_entire_file  = test_run_file_system_read_entire_file,
		write_entire_file = test_run_file_system_write_entire_file,
		exists            = test_run_file_system_exists,
		remove            = test_run_file_system_remove,
	}
	config.input = Engine_Input_Backend {
		ctx                   = &input_state,
		key_down              = test_run_input_key_down,
		key_pressed           = test_run_input_key_pressed,
		key_released          = test_run_input_key_released,
		frame_time            = test_run_input_frame_time,
		mouse_position        = test_run_input_mouse_position,
		mouse_button_down     = test_run_input_mouse_button_down,
		mouse_button_released = test_run_input_mouse_button_released,
		scroll_delta          = test_run_input_scroll_delta,
	}
	config.render = Engine_Render_Backend {
		ctx                  = &render_state,
		begin_frame          = test_render_begin_frame,
		end_frame            = test_render_end_frame,
		clear                = test_render_clear,
		begin_scissor        = test_render_begin_scissor,
		end_scissor          = test_render_end_scissor,
		draw_rectangle       = test_render_draw_rectangle,
		draw_text            = test_render_draw_text,
		measure_text         = test_render_measure_text,
		draw_rectangle_lines = test_render_draw_rectangle_lines,
		draw_texture_region  = test_render_draw_texture_region,
	}
	config.texture = Engine_Texture_Backend {
		ctx    = &texture_state,
		load   = test_texture_load,
		unload = test_texture_unload,
	}
	app := Game_App {
		name     = "Backend Test App",
		state    = &app_state,
		init     = test_run_app_init,
		update   = test_run_app_update,
		render   = test_run_app_render,
		shutdown = test_run_app_shutdown,
		autosave = test_run_app_autosave,
	}

	engine_run(config, engine_services_default_config(), &app)

	testing.expect_value(t, platform_state.init_count, 1)
	testing.expect_value(t, platform_state.shutdown_count, 1)
	testing.expect_value(t, platform_state.target_fps, 144)
	testing.expect_value(t, platform_state.disable_exit_key_count, 1)
	testing.expect_value(t, platform_state.should_close_calls, 2)
	testing.expect_value(t, app_state.init_count, 1)
	testing.expect_value(t, app_state.update_count, 1)
	testing.expect_value(t, app_state.frame_index, 1)
	testing.expect_value(t, app_state.delta_time, f32(0.125))
	testing.expect_value(t, app_state.elapsed_time, f32(0.125))
	testing.expect_value(t, app_state.event_count_in_update, 0)
	testing.expect_value(t, app_state.event_count_in_render, 1)
	testing.expect_value(t, app_state.render_count, 1)
	testing.expect_value(t, app_state.shutdown_count, 1)
	testing.expect_value(t, app_state.autosave_count, 1)
	testing.expect(t, app_state.file_system_ctx == rawptr(&file_system_state))
	testing.expect(t, app_state.input_ctx == rawptr(&input_state))
	testing.expect_value(t, texture_state.load_count, 1)
	testing.expect_value(t, texture_state.unload_count, 1)
	testing.expect(t, texture_state.last_loaded_path == "assets/test.png")
	testing.expect(t, texture_state.last_unloaded_handle == app_state.texture_handle)
	testing.expect_value(t, render_state.begin_frame_count, 1)
	testing.expect_value(t, render_state.clear_count, 1)
	testing.expect_value(t, render_state.begin_scissor_count, 1)
	testing.expect_value(t, render_state.rectangle_count, 1)
	testing.expect_value(t, render_state.text_count, 1)
	testing.expect_value(t, render_state.measure_count, 1)
	testing.expect_value(t, render_state.rectangle_lines_count, 1)
	testing.expect_value(t, render_state.texture_region_count, 1)
	testing.expect_value(t, app_state.measured_width, 42)
	testing.expect_value(t, render_state.end_scissor_count, 1)
	testing.expect_value(t, render_state.end_frame_count, 1)
	testing.expect_value(t, render_state.last_color.r, u8(1))
	testing.expect_value(t, render_state.last_color.g, u8(2))
	testing.expect_value(t, render_state.last_color.b, u8(3))
	testing.expect_value(t, render_state.last_color.a, u8(4))
}

@(test)
engine_shutdown_allows_app_without_shutdown_callback :: proc(t: ^testing.T) {
	platform_state := Test_Platform_State{}
	texture_state := Test_Texture_Backend_State{}
	app_state := Test_Run_App_State{}
	config := engine_config_make(640, 360, "Nil Shutdown Test", 60)
	config.platform = Engine_Platform_Backend {
		ctx                 = &platform_state,
		init                = test_platform_init,
		shutdown            = test_platform_shutdown,
		set_target_fps      = test_platform_set_target_fps,
		disable_exit_key    = test_platform_disable_exit_key,
		window_should_close = test_platform_window_should_close,
	}
	config.texture = Engine_Texture_Backend {
		ctx    = &texture_state,
		load   = test_texture_load,
		unload = test_texture_unload,
	}
	app := Game_App {
		name     = "Nil Shutdown App",
		state    = &app_state,
		init     = test_run_app_init,
		update   = test_run_app_update,
		render   = nil,
		shutdown = nil,
		autosave = test_run_app_autosave,
	}

	engine_run(config, engine_services_default_config(), &app)

	testing.expect_value(t, app_state.init_count, 1)
	testing.expect_value(t, app_state.autosave_count, 1)
	testing.expect_value(t, platform_state.shutdown_count, 1)
}

@(test)
engine_shutdown_unloads_textures_before_platform_shutdown :: proc(t: ^testing.T) {
	order := 0
	platform_state := Test_Platform_State {
		order = &order,
	}
	texture_state := Test_Texture_Backend_State {
		order = &order,
	}

	state: Engine_State
	state.platform_started = true
	state.platform = Engine_Platform_Backend {
		ctx                 = &platform_state,
		init                = test_platform_init,
		shutdown            = test_platform_shutdown,
		set_target_fps      = test_platform_set_target_fps,
		disable_exit_key    = test_platform_disable_exit_key,
		window_should_close = test_platform_window_should_close,
	}
	state.engine.texture_manager = texture_manager_make(
		Engine_Texture_Backend {
			ctx = &texture_state,
			load = test_texture_load,
			unload = test_texture_unload,
		},
	)
	state.engine.texture_manager.loaded[0] = true
	state.engine.texture_manager.textures[0] = Engine_Texture {
		handle = rawptr(uintptr(123)),
		width  = 16,
		height = 16,
	}

	engine_shutdown(&state)

	testing.expect_value(t, texture_state.unload_count, 1)
	testing.expect_value(t, platform_state.shutdown_count, 1)
	testing.expect(t, texture_state.unload_order < platform_state.shutdown_order)
}

test_app_init :: proc(engine: ^Engine, app: ^Game_App) -> bool {return true}
test_app_update :: proc(engine: ^Engine, app: ^Game_App) -> bool {return false}
test_app_render :: proc(engine: ^Engine, app: ^Game_App) {}
test_app_shutdown :: proc(engine: ^Engine, app: ^Game_App) {}
test_app_autosave :: proc(engine: ^Engine, app: ^Game_App) {}

Test_Platform_State :: struct {
	init_count:             int,
	shutdown_count:         int,
	target_fps:             i32,
	disable_exit_key_count: int,
	should_close_calls:     int,
	order:                  ^int,
	shutdown_order:         int,
}

test_platform_init :: proc(ctx: rawptr, config: Engine_Config) -> bool {
	state := cast(^Test_Platform_State)ctx
	state.init_count += 1
	return true
}

test_platform_shutdown :: proc(ctx: rawptr) {
	state := cast(^Test_Platform_State)ctx
	state.shutdown_count += 1
	if state.order != nil {
		state.shutdown_order = state.order^
		state.order^ += 1
	}
}

test_platform_set_target_fps :: proc(ctx: rawptr, target_fps: i32) {
	state := cast(^Test_Platform_State)ctx
	state.target_fps = target_fps
}

test_run_app_init_with_manager_texture :: proc(engine: ^Engine, app: ^Game_App) -> bool {
	state := cast(^Test_Run_App_State)app.state
	state.init_count += 1
	_ = engine_texture_manager_load(engine, "assets/test.png")
	return true
}

test_platform_disable_exit_key :: proc(ctx: rawptr) {
	state := cast(^Test_Platform_State)ctx
	state.disable_exit_key_count += 1
}

test_platform_window_should_close :: proc(ctx: rawptr) -> bool {
	state := cast(^Test_Platform_State)ctx
	state.should_close_calls += 1
	return state.should_close_calls > 1
}

Test_Run_App_State :: struct {
	init_count:            int,
	update_count:          int,
	render_count:          int,
	shutdown_count:        int,
	autosave_count:        int,
	measured_width:        i32,
	file_system_ctx:       rawptr,
	input_ctx:             rawptr,
	texture:               Engine_Texture,
	texture_handle:        rawptr,
	frame_index:           int,
	delta_time:            f32,
	elapsed_time:          f32,
	event_count_in_update: int,
	event_count_in_render: int,
}

test_run_app_init :: proc(engine: ^Engine, app: ^Game_App) -> bool {
	state := cast(^Test_Run_App_State)app.state
	state.init_count += 1
	fs := engine_file_system(engine)
	state.file_system_ctx = fs.ctx
	input := engine_input_backend(engine)
	state.input_ctx = input.ctx
	_ = event_manager_push(engine_event_manager(engine), engine_event_window_close_requested())
	state.texture = engine_texture_load(engine, "assets/test.png")
	state.texture_handle = state.texture.handle
	return true
}

test_run_app_update :: proc(engine: ^Engine, app: ^Game_App) -> bool {
	state := cast(^Test_Run_App_State)app.state
	state.update_count += 1
	frames := engine_frame_manager(engine)
	state.frame_index = frame_manager_index(frames^)
	state.delta_time = frame_manager_delta_time(frames^)
	state.elapsed_time = frame_manager_elapsed_time(frames^)
	events := engine_event_manager(engine)
	state.event_count_in_update = event_manager_count(events^)
	_ = event_manager_push(events, engine_event_key_down(.W))
	return false
}

test_run_app_render :: proc(engine: ^Engine, app: ^Game_App) {
	state := cast(^Test_Run_App_State)app.state
	state.render_count += 1
	state.event_count_in_render = event_manager_count(engine_event_manager(engine)^)
	engine_render_begin_frame(engine)
	engine_render_clear(engine, engine_color_make(1, 2, 3, 4))
	engine_render_begin_scissor(engine, 5, 6, 7, 8)
	engine_render_draw_rectangle(engine, 9, 10, 11, 12, engine_color_make(13, 14, 15, 16))
	engine_render_draw_rectangle_lines(engine, 9, 10, 11, 12, engine_color_make(21, 22, 23, 24))
	engine_render_draw_text(engine, "hello", 13, 14, 15, engine_color_make(17, 18, 19, 20))
	state.measured_width = engine_render_measure_text(engine, "hello", 15)
	engine_render_draw_texture_region(
		engine,
		state.texture,
		engine_rect_make(1, 2, 3, 4),
		engine_rect_make(5, 6, 7, 8),
		engine_vec2_make(0, 0),
		0,
		engine_color_make(25, 26, 27, 28),
	)
	engine_render_end_scissor(engine)
	engine_render_end_frame(engine)
}

test_run_app_shutdown :: proc(engine: ^Engine, app: ^Game_App) {
	state := cast(^Test_Run_App_State)app.state
	state.shutdown_count += 1
	engine_texture_unload(engine, &state.texture)
}

test_run_app_autosave :: proc(engine: ^Engine, app: ^Game_App) {
	state := cast(^Test_Run_App_State)app.state
	state.autosave_count += 1
}

Test_Run_File_System_State :: struct {}

test_run_file_system_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	return {}, false
}

test_run_file_system_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	return false
}

test_run_file_system_exists :: proc(ctx: rawptr, path: string) -> bool {
	return false
}

test_run_file_system_remove :: proc(ctx: rawptr, path: string) -> bool {
	return false
}

Test_Run_Input_Backend_State :: struct {
	frame_time: f32,
}

test_run_input_key_down :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return false
}

test_run_input_key_pressed :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return false
}

test_run_input_key_released :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return false
}

test_run_input_frame_time :: proc(ctx: rawptr) -> f32 {
	state := cast(^Test_Run_Input_Backend_State)ctx
	return state.frame_time
}

test_run_input_mouse_position :: proc(ctx: rawptr) -> Engine_Mouse_Position {
	return {}
}

test_run_input_mouse_button_down :: proc(ctx: rawptr, button: Engine_Mouse_Button) -> bool {
	return false
}

test_run_input_mouse_button_released :: proc(ctx: rawptr, button: Engine_Mouse_Button) -> bool {
	return false
}

test_run_input_scroll_delta :: proc(ctx: rawptr) -> f32 {
	return 0
}

Test_Render_Backend_State :: struct {
	begin_frame_count:     int,
	end_frame_count:       int,
	clear_count:           int,
	begin_scissor_count:   int,
	end_scissor_count:     int,
	rectangle_count:       int,
	text_count:            int,
	measure_count:         int,
	rectangle_lines_count: int,
	texture_region_count:  int,
	last_color:            Engine_Color,
	last_texture:          rawptr,
}

test_render_begin_frame :: proc(ctx: rawptr) {
	state := cast(^Test_Render_Backend_State)ctx
	state.begin_frame_count += 1
}

test_render_end_frame :: proc(ctx: rawptr) {
	state := cast(^Test_Render_Backend_State)ctx
	state.end_frame_count += 1
}

test_render_clear :: proc(ctx: rawptr, color: Engine_Color) {
	state := cast(^Test_Render_Backend_State)ctx
	state.clear_count += 1
	state.last_color = color
}

test_render_begin_scissor :: proc(ctx: rawptr, x, y, width, height: i32) {
	state := cast(^Test_Render_Backend_State)ctx
	state.begin_scissor_count += 1
}

test_render_end_scissor :: proc(ctx: rawptr) {
	state := cast(^Test_Render_Backend_State)ctx
	state.end_scissor_count += 1
}

test_render_draw_rectangle :: proc(ctx: rawptr, x, y, width, height: i32, color: Engine_Color) {
	state := cast(^Test_Render_Backend_State)ctx
	state.rectangle_count += 1
}

test_render_draw_text :: proc(
	ctx: rawptr,
	text: cstring,
	x, y, size: i32,
	color: Engine_Color,
	font: Engine_Font,
) {
	state := cast(^Test_Render_Backend_State)ctx
	state.text_count += 1
}

test_render_measure_text :: proc(ctx: rawptr, text: cstring, size: i32, font: Engine_Font) -> i32 {
	state := cast(^Test_Render_Backend_State)ctx
	state.measure_count += 1
	return 42
}

test_render_draw_rectangle_lines :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: Engine_Color,
) {
	state := cast(^Test_Render_Backend_State)ctx
	state.rectangle_lines_count += 1
}

test_render_draw_texture_region :: proc(
	ctx: rawptr,
	texture: Engine_Texture,
	source, dest: Engine_Rect,
	origin: Engine_Vec2,
	rotation: f32,
	tint: Engine_Color,
) {
	state := cast(^Test_Render_Backend_State)ctx
	state.texture_region_count += 1
	state.last_texture = texture.handle
}

Test_Texture_Backend_State :: struct {
	load_count:           int,
	unload_count:         int,
	last_loaded_path:     string,
	last_unloaded_handle: rawptr,
	order:                ^int,
	unload_order:         int,
}

test_texture_load :: proc(ctx: rawptr, path: string) -> Engine_Texture {
	state := cast(^Test_Texture_Backend_State)ctx
	state.load_count += 1
	state.last_loaded_path = path
	return Engine_Texture{handle = rawptr(uintptr(123)), width = 16, height = 16}
}

test_texture_unload :: proc(ctx: rawptr, texture: ^Engine_Texture) {
	state := cast(^Test_Texture_Backend_State)ctx
	state.unload_count += 1
	state.last_unloaded_handle = texture.handle
	if state.order != nil {
		state.unload_order = state.order^
		state.order^ += 1
	}
	texture^ = {}
}
