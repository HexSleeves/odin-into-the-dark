package renderer

import gcore "../core"

import eng "../engine"

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	particles := game_engine_particle_manager(engine)
	update_particles(particles)

	eng.engine_render_begin_frame(engine)
	eng.engine_render_clear(engine, eng.engine_color_make(0, 0, 0, 255))

	// Clip the map rendering to the viewport region so it doesn't bleed into HUD/messages
	eng.engine_render_begin_scissor(
		engine,
		0,
		0,
		i32(gcore.MAP_VIEW_WIDTH),
		i32(gcore.MAP_VIEW_HEIGHT),
	)
	render_map(engine, game)
	render_webs(engine, game)
	render_items(engine, game)
	render_enemies(engine, game)
	render_npcs(engine, game)
	render_player(engine, game)
	render_particles(engine, particles)
	eng.engine_render_end_scissor(engine)

	clay_ui_begin_frame(engine)
	clay_render_screen_ui(engine, game)
	delta_time := f32(0)
	frames := eng.engine_frame_manager(engine)
	if frames != nil {
		delta_time = eng.frame_manager_delta_time(frames^)
	}
	commands := clay_ui_end_frame(delta_time)
	clay_render_commands(engine, commands)

	// Screen flash overlay (S02)
	vfx := game_engine_vfx_manager(engine)
	if vfx != nil && vfx.flash_alpha > 0.01 {
		alpha := u8(vfx.flash_alpha * 255.0)
		eng.engine_render_draw_rectangle(
			engine,
			0,
			0,
			i32(gcore.SCREEN_WIDTH),
			i32(gcore.SCREEN_HEIGHT),
			eng.engine_color_make(vfx.flash_color.r, vfx.flash_color.g, vfx.flash_color.b, alpha),
		)
		eng.vfx_manager_fade_flash(vfx, 0.85)
	}

	eng.engine_render_end_frame(engine)
}
