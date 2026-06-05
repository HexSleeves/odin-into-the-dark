#+build !js
package engine

import "core:testing"

@(test)
nil_input_backend_is_valid_and_returns_empty_state :: proc(t: ^testing.T) {
	input := engine_input_backend_nil()

	testing.expect(t, engine_input_backend_is_valid(input))
	testing.expect(t, !engine_input_key_down(input, .W))
	testing.expect(t, !engine_input_key_pressed(input, .W))
	testing.expect(t, !engine_input_key_released(input, .W))
	testing.expect_value(t, engine_input_frame_time(input), f32(0))
	testing.expect_value(t, engine_input_mouse_position(input).x, f32(0))
	testing.expect_value(t, engine_input_mouse_position(input).y, f32(0))
	testing.expect(t, !engine_input_mouse_button_down(input, .Left))
	testing.expect(t, !engine_input_mouse_button_released(input, .Left))
	testing.expect_value(t, engine_input_scroll_delta(input), f32(0))
}

@(test)
nil_render_backend_is_valid_and_safe_to_call :: proc(t: ^testing.T) {
	engine := Engine {
		render = engine_render_backend_nil(),
	}

	testing.expect(t, engine_render_backend_is_valid(engine.render))
	engine_render_begin_frame(&engine)
	engine_render_clear(&engine, engine_color_make(1, 2, 3, 4))
	engine_render_begin_scissor(&engine, 1, 2, 3, 4)
	engine_render_draw_rectangle(&engine, 1, 2, 3, 4, engine_color_make(5, 6, 7, 8))
	engine_render_draw_rectangle_lines(&engine, 1, 2, 3, 4, engine_color_make(9, 10, 11, 12))
	engine_render_draw_text(&engine, "hello", 1, 2, 12, engine_color_make(13, 14, 15, 16))
	testing.expect_value(t, engine_render_measure_text(&engine, "hello", 12), i32(0))
	engine_render_draw_texture_region(
		&engine,
		Engine_Texture{},
		engine_rect_make(0, 0, 1, 1),
		engine_rect_make(0, 0, 1, 1),
		engine_vec2_make(0, 0),
		0,
		engine_color_make(255, 255, 255, 255),
	)
	engine_render_end_scissor(&engine)
	engine_render_end_frame(&engine)
}

@(test)
nil_texture_backend_is_valid_and_returns_empty_textures :: proc(t: ^testing.T) {
	engine := Engine {
		texture = engine_texture_backend_nil(),
	}
	texture := engine_texture_load(&engine, "assets/missing.png")

	testing.expect(t, engine_texture_backend_is_valid(engine.texture))
	testing.expect(t, !engine_texture_is_valid(texture))
	engine_texture_unload(&engine, &texture)
	testing.expect(t, !engine_texture_is_valid(texture))
}

@(test)
nil_platform_backend_is_valid_and_headless :: proc(t: ^testing.T) {
	platform := engine_platform_backend_nil()

	testing.expect(t, engine_platform_backend_is_valid(platform))
	testing.expect(t, platform.init(platform.ctx, engine_config_make(1, 1, "nil", 0)))
	platform.set_target_fps(platform.ctx, 60)
	platform.disable_exit_key(platform.ctx)
	testing.expect(t, platform.window_should_close(platform.ctx))
	platform.shutdown(platform.ctx)
}
