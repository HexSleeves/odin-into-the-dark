#+build !js
package engine

import "core:testing"

@(test)
particle_manager_starts_empty_and_owns_fixed_pool :: proc(t: ^testing.T) {
	particles := particle_manager_make()

	testing.expect_value(t, particle_manager_active_count(&particles), 0)
	testing.expect_value(t, len(particles.pool), ENGINE_MAX_PARTICLES)
}

@(test)
particle_manager_spawns_particles_at_pixel_position :: proc(t: ^testing.T) {
	particles := particle_manager_make()

	particle_manager_spawn_pixels(&particles, 12, 24, engine_color_make(1, 2, 3, 4), 3, 2.0)

	testing.expect_value(t, particle_manager_active_count(&particles), 3)
	testing.expect_value(t, particles.pool[0].pos[0], f32(12))
	testing.expect_value(t, particles.pool[0].pos[1], f32(24))
	testing.expect_value(t, particles.pool[0].color.r, u8(1))
	testing.expect_value(t, particles.pool[0].color.a, u8(4))
}

@(test)
particle_manager_updates_motion_and_deactivates_expired_particles :: proc(t: ^testing.T) {
	particles := particle_manager_make()
	particles.pool[0] = Particle {
		pos    = {1, 2},
		vel    = {3, 4},
		color  = engine_color_make(255, 255, 255, 255),
		life   = 0.01,
		decay  = 0.02,
		size   = 2,
		active = true,
	}

	particle_manager_update(&particles)

	testing.expect_value(t, particles.pool[0].pos[0], f32(4))
	testing.expect_value(t, particles.pool[0].pos[1], f32(6))
	testing.expect(t, !particles.pool[0].active)
}

@(test)
particle_manager_render_submits_active_particles_to_engine_render_backend :: proc(t: ^testing.T) {
	render_state := Test_Particle_Render_State{}
	engine := Engine {
		render = Engine_Render_Backend {
			ctx = &render_state,
			begin_frame = test_particle_render_begin_frame,
			end_frame = test_particle_render_end_frame,
			clear = test_particle_render_clear,
			begin_scissor = test_particle_render_begin_scissor,
			end_scissor = test_particle_render_end_scissor,
			draw_rectangle = test_particle_render_draw_rectangle,
			draw_text = test_particle_render_draw_text,
			measure_text = test_particle_render_measure_text,
			draw_rectangle_lines = test_particle_render_draw_rectangle_lines,
			draw_texture_region = test_particle_render_draw_texture_region,
		},
	}
	particles := particle_manager_make()
	particles.pool[0] = Particle {
		pos    = {10, 20},
		vel    = {},
		color  = engine_color_make(100, 120, 140, 200),
		life   = 0.5,
		decay  = 0.01,
		size   = 4,
		active = true,
	}

	particle_manager_render(&engine, &particles)

	testing.expect_value(t, render_state.rectangle_count, 1)
	testing.expect_value(t, render_state.last_x, 10)
	testing.expect_value(t, render_state.last_y, 20)
	testing.expect_value(t, render_state.last_width, 2)
	testing.expect_value(t, render_state.last_color.a, u8(100))
}

Test_Particle_Render_State :: struct {
	rectangle_count: int,
	last_x:          i32,
	last_y:          i32,
	last_width:      i32,
	last_color:      Engine_Color,
}

test_particle_render_begin_frame :: proc(ctx: rawptr) {}
test_particle_render_end_frame :: proc(ctx: rawptr) {}
test_particle_render_clear :: proc(ctx: rawptr, color: Engine_Color) {}
test_particle_render_begin_scissor :: proc(ctx: rawptr, x, y, width, height: i32) {}
test_particle_render_end_scissor :: proc(ctx: rawptr) {}
test_particle_render_draw_text :: proc(
	ctx: rawptr,
	text: cstring,
	x, y, size: i32,
	color: Engine_Color,
) {}
test_particle_render_measure_text :: proc(ctx: rawptr, text: cstring, size: i32) -> i32 {return 0}
test_particle_render_draw_rectangle_lines :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: Engine_Color,
) {}
test_particle_render_draw_texture_region :: proc(
	ctx: rawptr,
	texture: Engine_Texture,
	source, dest: Engine_Rect,
	origin: Engine_Vec2,
	rotation: f32,
	tint: Engine_Color,
) {}

test_particle_render_draw_rectangle :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: Engine_Color,
) {
	state := cast(^Test_Particle_Render_State)ctx
	state.rectangle_count += 1
	state.last_x = x
	state.last_y = y
	state.last_width = width
	state.last_color = color
}