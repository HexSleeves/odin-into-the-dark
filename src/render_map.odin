package main

import eng "./engine"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// ─── Depth palette definitions ────────────────────────────────────────────────

PALETTE_MINE :: Floor_Palette {
	wall    = rl.Color{40, 40, 45, 255},
	floor   = rl.Color{139, 90, 43, 255},
	rubble  = rl.Color{180, 160, 100, 255},
	descent = rl.Color{0, 200, 200, 255},
}

PALETTE_STONE :: Floor_Palette {
	wall    = rl.Color{50, 50, 55, 255},
	floor   = rl.Color{100, 100, 110, 255},
	rubble  = rl.Color{130, 130, 120, 255},
	descent = rl.Color{0, 200, 200, 255},
}

PALETTE_CRYSTAL :: Floor_Palette {
	wall    = rl.Color{30, 45, 60, 255},
	floor   = rl.Color{50, 90, 100, 255},
	rubble  = rl.Color{80, 140, 130, 255},
	descent = rl.Color{0, 255, 200, 255},
}

PALETTE_FLOODED :: Floor_Palette {
	wall    = rl.Color{25, 40, 55, 255},
	floor   = rl.Color{35, 65, 80, 255},
	rubble  = rl.Color{50, 90, 85, 255},
	descent = rl.Color{0, 200, 255, 255},
}

PALETTE_DEEP :: Floor_Palette {
	wall    = rl.Color{35, 20, 45, 255},
	floor   = rl.Color{70, 40, 80, 255},
	rubble  = rl.Color{110, 60, 120, 255},
	descent = rl.Color{200, 100, 255, 255},
}

UNSEEN_COLOR :: rl.Color{0, 0, 0, 255}

// Dimming multiplier for explored-but-not-visible tiles (used in S03 FOV)
EXPLORED_DIM :: 0.55

// ─── Palette selection ────────────────────────────────────────────────────────

palette_for_depth :: proc(depth: int) -> Floor_Palette {
	if depth <= 2 {return PALETTE_MINE}
	if depth <= 4 {return PALETTE_STONE}
	if depth == 5 {return PALETTE_CRYSTAL}
	if depth <= 7 {return PALETTE_FLOODED}
	return PALETTE_DEEP
}

// ─── Tile color helpers ───────────────────────────────────────────────────────

dim_color :: proc(c: rl.Color, factor: f32) -> rl.Color {
	return rl.Color{u8(f32(c.r) * factor), u8(f32(c.g) * factor), u8(f32(c.b) * factor), c.a}
}

base_tile_color :: proc(type: Tile_Type, palette: Floor_Palette) -> rl.Color {
	#partial switch type {
	case .Wall:
		return palette.wall
	case .Floor:
		return palette.floor
	case .Rubble:
		return palette.rubble
	case .Descent:
		return palette.descent
	case .Water:
		return rl.Color{40, 80, 180, 255}
	case .Fountain:
		return rl.Color{40, 120, 220, 255}
	case .Gas_Vent:
		return rl.Color{160, 180, 40, 255}
	case .Unstable:
		return rl.Color{180, 120, 60, 255}
	case .Chasm:
		return rl.Color{10, 10, 15, 255}
	case .Anvil:
		return rl.Color{160, 160, 170, 255}
	case .Fire_Vent:
		return rl.Color{200, 80, 20, 255}
	}
	return UNSEEN_COLOR
}

get_tile_color :: proc(tile: Tile, state: eng.Tile_State, palette: Floor_Palette) -> rl.Color {
	if state.visible {
		return dim_color(base_tile_color(tile.type, palette), max(state.light_level, 0.5))
	}
	if state.explored {
		return dim_color(base_tile_color(tile.type, palette), EXPLORED_DIM)
	}
	return UNSEEN_COLOR
}

visible_tile_bounds :: proc(camera: ^eng.Camera_Manager) -> (x0, y0, x1, y1: int) {
	camera_x := game_camera_x(camera)
	camera_y := game_camera_y(camera)
	x0 = max(0, camera_x / TILE_SIZE)
	y0 = max(0, camera_y / TILE_SIZE)
	x1 = min(MAP_WIDTH - 1, (camera_x + MAP_VIEW_WIDTH) / TILE_SIZE)
	y1 = min(MAP_HEIGHT - 1, (camera_y + MAP_VIEW_HEIGHT) / TILE_SIZE)
	return
}

// ─── Map rendering (with camera offset) ───────────────────────────────────────

render_map :: proc(engine: ^eng.Engine, game: ^Game) {
	vfx := game_engine_vfx_manager(engine)
	eng.vfx_manager_tick_frame(vfx)

	camera := game_engine_camera_manager(engine)
	cam_x := game_camera_x(camera)
	cam_y := game_camera_y(camera)

	sprites := game_engine_sprite_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	shake := eng.vfx_manager_shake_offset(vfx)
	ox := i32(cam_x) + i32(shake[0])
	oy := i32(cam_y) + i32(shake[1])
	palette := palette_for_depth(game.depth)

	x0, y0, x1, y1 := visible_tile_bounds(camera)
	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			sx := i32(x * TILE_SIZE) - ox
			sy := i32(y * TILE_SIZE) - oy

			// Cull tiles entirely outside the map viewport
			if sx + i32(TILE_SIZE) < 0 || sx >= i32(MAP_VIEW_WIDTH) {continue}
			if sy + i32(TILE_SIZE) < 0 || sy >= i32(MAP_VIEW_HEIGHT) {continue}

			idx := pos_to_idx(x, y)
			tile := game.tiles[idx]
			state := tile_state_at_idx(game, idx)

			if !state.visible && !state.explored {
				render_draw_rectangle(engine, sx, sy, i32(TILE_SIZE), i32(TILE_SIZE), UNSEEN_COLOR)
			} else {
				base := base_tile_color(tile.type, palette)
				tint: rl.Color
				if state.visible {
					brightness := max(state.light_level, 0.5)
					tint = rl.Color {
						u8(f32(base.r) * brightness),
						u8(f32(base.g) * brightness),
						u8(f32(base.b) * brightness),
						255,
					}
				} else {
					dim := f32(EXPLORED_DIM)
					tint = rl.Color {
						u8(f32(base.r) * dim),
						u8(f32(base.g) * dim),
						u8(f32(base.b) * dim),
						255,
					}
				}

				if ui.use_sprites {
					spr := sprite_manager_tile(sprites, tile.type)
					sprite_manager_draw(engine, sprites, spr, sx, sy, tint)
				} else {
					// ASCII mode: colored rectangle
					render_draw_rectangle(engine, sx, sy, i32(TILE_SIZE), i32(TILE_SIZE), tint)
				}

				// Ore vein overlay on walls
				if tile.type == .Wall {
					vein := game.ore_veins[idx]
					if vein.ore_type != "" {
						ore_tint := vein.color
						if !state.visible {
							ore_tint = dim_color(vein.color, EXPLORED_DIM)
						}
						if ui.use_sprites {
							spr := sprite_manager_named(sprites, "tile", "ore_vein")
							sprite_manager_draw(engine, sprites, spr, sx, sy, ore_tint)
						} else {
							dot_x := sx + i32(TILE_SIZE) / 2 - 3
							dot_y := sy + i32(TILE_SIZE) / 2 - 3
							render_draw_rectangle(engine, dot_x, dot_y, 6, 6, ore_tint)
						}
					}
				}
			}
		}
	}
}

// ─── Web tile rendering ───────────────────────────────────────────────────────

render_webs :: proc(engine: ^eng.Engine, game: ^Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	ox := i32(game_camera_x(camera))
	oy := i32(game_camera_y(camera))

	x0, y0, x1, y1 := visible_tile_bounds(camera)
	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			idx := pos_to_idx(x, y)
			if !web_tile_at_idx(game, idx) {continue}

			if !tile_visible_idx(game, idx) {continue}

			sx := i32(x * TILE_SIZE) - ox
			sy := i32(y * TILE_SIZE) - oy

			// Cull off-screen
			if sx + i32(TILE_SIZE) < 0 || sx >= i32(MAP_VIEW_WIDTH) {continue}
			if sy + i32(TILE_SIZE) < 0 || sy >= i32(MAP_VIEW_HEIGHT) {continue}

			if ui.use_sprites {
				spr := sprite_manager_named(sprites, "tile", "web")
				sprite_manager_draw(engine, sprites, spr, sx, sy, rl.Color{180, 180, 180, 150})
			} else {
				render_draw_text(
					engine,
					"w",
					sx + 4,
					sy + 4,
					i32(TILE_SIZE) - 8,
					rl.Color{180, 180, 180, 150},
				)
			}
		}
	}
}

// ─── Player rendering ─────────────────────────────────────────────────────────

render_player :: proc(engine: ^eng.Engine, game: ^Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	vfx := game_engine_vfx_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	px := i32(game.player.pos.x * TILE_SIZE) - i32(game_camera_x(camera))
	py := i32(game.player.pos.y * TILE_SIZE) - i32(game_camera_y(camera))

	bob_phase := f32(eng.vfx_manager_frame(vfx)) * 0.06
	bob_offset := i32(math.sin(f64(bob_phase)) * 0.8)
	py += bob_offset

	if ui.use_sprites {
		spr := sprite_manager_named(sprites, "character", "player")
		sprite_manager_draw(engine, sprites, spr, px, py, game.player.color)
	} else {
		glyph_buf: [2]u8
		glyph_buf[0] = u8(game.player.glyph)
		glyph_buf[1] = 0
		render_draw_text(
			engine,
			cast(cstring)&glyph_buf[0],
			px,
			py,
			i32(TILE_SIZE),
			game.player.color,
		)
	}
}

// ─── Enemy rendering ──────────────────────────────────────────────────────────

render_enemies :: proc(engine: ^eng.Engine, game: ^Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	vfx := game_engine_vfx_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	ox := i32(game_camera_x(camera))
	oy := i32(game_camera_y(camera))

	for &enemy in game.enemies {
		if !enemy.alive {continue}

		if !tile_visible_at(game, enemy.pos.x, enemy.pos.y) {continue}

		ex := i32(enemy.pos.x * TILE_SIZE) - ox
		ey := i32(enemy.pos.y * TILE_SIZE) - oy

		bob_phase := f32(eng.vfx_manager_frame(vfx) + enemy.pos.x * 17 + enemy.pos.y * 31) * 0.05
		bob_offset := i32(math.sin(f64(bob_phase)) * 1.5)
		ey += bob_offset

		if ui.use_sprites {
			spr := sprite_manager_enemy(sprites, enemy.enemy_type)
			sprite_manager_draw(engine, sprites, spr, ex, ey, enemy.color)
		} else {
			glyph_buf: [2]u8
			glyph_buf[0] = u8(enemy.glyph)
			glyph_buf[1] = 0
			render_draw_text(
				engine,
				cast(cstring)&glyph_buf[0],
				ex,
				ey,
				i32(TILE_SIZE),
				enemy.color,
			)
		}
	}
}

// ─── Mouse hover tooltip (camera-aware) ───────────────────────────────────────

TOOLTIP_BG_COLOR :: rl.Color{20, 20, 25, 230}
TOOLTIP_TEXT_COLOR :: rl.WHITE
TOOLTIP_FONT_SIZE :: i32(14)
TOOLTIP_PAD_X :: i32(6)
TOOLTIP_PAD_Y :: i32(4)
TOOLTIP_OFFSET_X :: i32(12)
TOOLTIP_OFFSET_Y :: i32(-20)

render_tooltip :: proc(engine: ^eng.Engine, game: ^Game) {
	mouse := eng.engine_mouse_position(engine)
	camera := game_engine_camera_manager(engine)

	// Only show tooltips when mouse is in the map viewport region
	if int(mouse.x) >= MAP_VIEW_WIDTH || int(mouse.y) >= MAP_VIEW_HEIGHT {return}

	// Convert screen coordinates to tile coordinates using camera offset
	tile_x := (int(mouse.x) + game_camera_x(camera)) / TILE_SIZE
	tile_y := (int(mouse.y) + game_camera_y(camera)) / TILE_SIZE

	if tile_x < 0 || tile_x >= MAP_WIDTH || tile_y < 0 || tile_y >= MAP_HEIGHT {
		return
	}

	tile := tile_at(game, tile_x, tile_y)
	if tile == nil || !tile_visible_at(game, tile_x, tile_y) {
		return
	}

	tooltip_text: cstring

	if game.player.pos.x == tile_x && game.player.pos.y == tile_y {
		tooltip_text = fmt.ctprintf("You (%d/%d HP)", game.player.hp, game.player.max_hp)
	} else {
		enemy := enemy_at(game, tile_x, tile_y)
		if enemy == nil {
			return
		}
		name := enemy_display_name(enemy)
		tooltip_text = fmt.ctprintf("%s (%d/%d HP)", name, enemy.hp, enemy.max_hp)
	}

	text_w := render_measure_text(engine, tooltip_text, TOOLTIP_FONT_SIZE)
	box_w := text_w + TOOLTIP_PAD_X * 2
	box_h := TOOLTIP_FONT_SIZE + TOOLTIP_PAD_Y * 2

	box_x := i32(mouse.x) + TOOLTIP_OFFSET_X
	box_y := i32(mouse.y) + TOOLTIP_OFFSET_Y

	if box_x + box_w > i32(MAP_VIEW_WIDTH) {box_x = i32(MAP_VIEW_WIDTH) - box_w}
	if box_x < 0 {box_x = 0}
	if box_y < 0 {box_y = 0}
	if box_y + box_h > i32(SCREEN_HEIGHT) {box_y = i32(SCREEN_HEIGHT) - box_h}

	render_draw_rectangle(engine, box_x, box_y, box_w, box_h, TOOLTIP_BG_COLOR)
	render_draw_text(
		engine,
		tooltip_text,
		box_x + TOOLTIP_PAD_X,
		box_y + TOOLTIP_PAD_Y,
		TOOLTIP_FONT_SIZE,
		TOOLTIP_TEXT_COLOR,
	)
}

// ─── Render texture stubs (texture approach reverted; kept for game_cleanup call) ──

render_map_ensure_texture :: proc(game: ^Game) {}

render_map_free_texture :: proc(game: ^Game) {}
