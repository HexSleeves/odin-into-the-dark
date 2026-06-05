package main

import eng "./engine"

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(engine: ^eng.Engine, game: ^Game) {
	particles := game_engine_particle_manager(engine)
	update_particles(particles)

	eng.engine_render_begin_frame(engine)
	eng.engine_render_clear(engine, eng.engine_color_make(0, 0, 0, 255))

	// Clip the map rendering to the viewport region so it doesn't bleed into HUD/messages
	eng.engine_render_begin_scissor(engine, 0, 0, i32(MAP_VIEW_WIDTH), i32(MAP_VIEW_HEIGHT))
	render_map(engine, game)
	render_webs(engine, game)
	render_items(engine, game)
	render_enemies(engine, game)
	render_player(engine, game)
	render_particles(engine, particles)
	eng.engine_render_end_scissor(engine)
	if game.state == .Title_Screen {
		frame := 0
		frames := game_engine_frame_manager(engine)
		if frames != nil {
			frame = eng.frame_manager_index(frames^)
		}
		glow := u8(170 + (frame % 60) * 85 / 59)
		draw_centered_text(engine, "INTO THE DEPTHS", 108, 52, eng.Engine_Color{90, 55, 20, glow})
		draw_centered_text(engine, "INTO THE DEPTHS", 110, 48, eng.Engine_Color{255, 230, 120, 255})
		draw_title_embers(engine, frame)
	}

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
			i32(SCREEN_WIDTH),
			i32(SCREEN_HEIGHT),
			eng.engine_color_make(vfx.flash_color.r, vfx.flash_color.g, vfx.flash_color.b, alpha),
		)
		eng.vfx_manager_fade_flash(vfx, 0.85)
	}

	eng.engine_render_end_frame(engine)
}
