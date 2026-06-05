package renderer

import ui_pkg "../ui"

import gcore "../core"

import eng "../engine"
import "core:math"

UNSEEN_COLOR :: eng.Engine_Color{0, 0, 0, 255}
EXPLORED_DIM :: 0.55


// ─── gcore.Tile color helpers ───────────────────────────────────────────────────────

dim_color :: proc(c: eng.Engine_Color, factor: f32) -> eng.Engine_Color {
	return eng.Engine_Color {
		u8(f32(c.r) * factor),
		u8(f32(c.g) * factor),
		u8(f32(c.b) * factor),
		c.a,
	}
}

base_tile_color :: proc(type: gcore.Tile_Type, palette: gcore.Floor_Palette) -> eng.Engine_Color {
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
		return eng.Engine_Color{40, 80, 180, 255}
	case .Fountain:
		return eng.Engine_Color{40, 120, 220, 255}
	case .Gas_Vent:
		return eng.Engine_Color{160, 180, 40, 255}
	case .Unstable:
		return eng.Engine_Color{180, 120, 60, 255}
	case .Chasm:
		return eng.Engine_Color{10, 10, 15, 255}
	case .Anvil:
		return eng.Engine_Color{160, 160, 170, 255}
	case .Fire_Vent:
		return eng.Engine_Color{200, 80, 20, 255}
	case .Locked_Door:
		return eng.Engine_Color{180, 140, 50, 255}
	}
	return UNSEEN_COLOR
}

get_tile_color :: proc(
	tile: gcore.Tile,
	state: eng.Tile_State,
	palette: gcore.Floor_Palette,
) -> eng.Engine_Color {
	if state.visible {
		return dim_color(base_tile_color(tile.type, palette), max(state.light_level, 0.5))
	}
	if state.explored {
		return dim_color(base_tile_color(tile.type, palette), EXPLORED_DIM)
	}
	return UNSEEN_COLOR
}

camera_zoom :: proc(camera: ^eng.Camera_Manager) -> f32 {
	return eng.camera_manager_zoom(camera)
}

camera_tile_size :: proc(camera: ^eng.Camera_Manager) -> i32 {
	return max(i32(f32(gcore.TILE_SIZE) * camera_zoom(camera)), 1)
}

camera_world_x_to_screen :: proc(camera: ^eng.Camera_Manager, world_x: int) -> i32 {
	return i32(f32(world_x - game_camera_x(camera)) * camera_zoom(camera))
}

camera_world_y_to_screen :: proc(camera: ^eng.Camera_Manager, world_y: int) -> i32 {
	return i32(f32(world_y - game_camera_y(camera)) * camera_zoom(camera))
}

screen_shake_offset :: proc(vfx: ^eng.Vfx_Manager) -> (x, y: i32) {
	shake := eng.vfx_manager_shake_offset(vfx)
	x = i32(shake[0])
	y = i32(shake[1])
	return
}

camera_world_x_to_screen_shaken :: proc(
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	world_x: int,
) -> i32 {
	shake_x, _ := screen_shake_offset(vfx)
	return camera_world_x_to_screen(camera, world_x) - shake_x
}

camera_world_y_to_screen_shaken :: proc(
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	world_y: int,
) -> i32 {
	_, shake_y := screen_shake_offset(vfx)
	return camera_world_y_to_screen(camera, world_y) - shake_y
}

visible_tile_bounds :: proc(camera: ^eng.Camera_Manager) -> (x0, y0, x1, y1: int) {
	camera_x := game_camera_x(camera)
	camera_y := game_camera_y(camera)
	zoom := camera_zoom(camera)
	view_w := int(f32(gcore.MAP_VIEW_WIDTH) / zoom)
	view_h := int(f32(gcore.MAP_VIEW_HEIGHT) / zoom)
	x0 = max(0, camera_x / gcore.TILE_SIZE)
	y0 = max(0, camera_y / gcore.TILE_SIZE)
	x1 = min(gcore.MAP_WIDTH - 1, (camera_x + view_w) / gcore.TILE_SIZE + 1)
	y1 = min(gcore.MAP_HEIGHT - 1, (camera_y + view_h) / gcore.TILE_SIZE + 1)
	return
}

// ─── Map rendering (with camera offset) ───────────────────────────────────────

render_map :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	vfx := game_engine_vfx_manager(engine)
	eng.vfx_manager_tick_frame(vfx)

	camera := game_engine_camera_manager(engine)
	tile_size := camera_tile_size(camera)

	sprites := game_engine_sprite_manager(engine)
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	palette := gcore.palette_for_depth(game.depth)

	x0, y0, x1, y1 := visible_tile_bounds(camera)
	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			sx := camera_world_x_to_screen_shaken(camera, vfx, x * gcore.TILE_SIZE)
			sy := camera_world_y_to_screen_shaken(camera, vfx, y * gcore.TILE_SIZE)

			// Cull tiles entirely outside the map viewport
			if sx + tile_size < 0 || sx >= i32(gcore.MAP_VIEW_WIDTH) {continue}
			if sy + tile_size < 0 || sy >= i32(gcore.MAP_VIEW_HEIGHT) {continue}

			idx := gcore.pos_to_idx(x, y)
			tile := game.tiles[idx]
			state := gcore.tile_state_at_idx(game, idx)

			if !state.visible && !state.explored {
				render_draw_rectangle(engine, sx, sy, tile_size, tile_size, UNSEEN_COLOR)
			} else {
				base := base_tile_color(tile.type, palette)
				tint: eng.Engine_Color
				if state.visible {
					brightness := max(state.light_level, 0.5)
					tint = eng.Engine_Color {
						u8(f32(base.r) * brightness),
						u8(f32(base.g) * brightness),
						u8(f32(base.b) * brightness),
						255,
					}
				} else {
					dim := f32(EXPLORED_DIM)
					tint = eng.Engine_Color {
						u8(f32(base.r) * dim),
						u8(f32(base.g) * dim),
						u8(f32(base.b) * dim),
						255,
					}
				}

				if ui.use_sprites {
					spr := sprite_manager_tile(sprites, tile.type)
					sprite_manager_draw(engine, sprites, spr, sx, sy, tint, tile_size)
				} else {
					// ASCII mode: colored rectangle
					render_draw_rectangle(engine, sx, sy, tile_size, tile_size, tint)
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
							sprite_manager_draw(engine, sprites, spr, sx, sy, ore_tint, tile_size)
						} else {
							dot_x := sx + tile_size / 2 - 3
							dot_y := sy + tile_size / 2 - 3
							render_draw_rectangle(engine, dot_x, dot_y, 6, 6, ore_tint)
						}
					}
				}
			}
		}
	}
}

// ─── Web tile rendering ───────────────────────────────────────────────────────

render_webs :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	vfx := game_engine_vfx_manager(engine)
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	tile_size := camera_tile_size(camera)
	x0, y0, x1, y1 := visible_tile_bounds(camera)
	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			idx := gcore.pos_to_idx(x, y)
			if !gcore.web_tile_at_idx(game, idx) {continue}

			if !gcore.tile_visible_idx(game, idx) {continue}

			sx := camera_world_x_to_screen_shaken(camera, vfx, x * gcore.TILE_SIZE)
			sy := camera_world_y_to_screen_shaken(camera, vfx, y * gcore.TILE_SIZE)

			// Cull off-screen
			if sx + tile_size < 0 || sx >= i32(gcore.MAP_VIEW_WIDTH) {continue}
			if sy + tile_size < 0 || sy >= i32(gcore.MAP_VIEW_HEIGHT) {continue}
			spr := sprite_manager_named(sprites, "tile", "web")
			render_world_sprite_or_glyph(
				engine,
				sprites,
				ui.use_sprites,
				spr,
				'w',
				"w",
				eng.Engine_Color{180, 180, 180, 150},
				sx + (0 if ui.use_sprites else 4),
				sy + (0 if ui.use_sprites else 4),
				tile_size if ui.use_sprites else tile_size - 8,
			)
		}
	}
}

// ─── gcore.Player rendering ─────────────────────────────────────────────────────────

render_player :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	vfx := game_engine_vfx_manager(engine)
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	tile_size := camera_tile_size(camera)
	px := camera_world_x_to_screen_shaken(camera, vfx, game.player.pos.x * gcore.TILE_SIZE)
	py := camera_world_y_to_screen_shaken(camera, vfx, game.player.pos.y * gcore.TILE_SIZE)

	bob_phase := f32(eng.vfx_manager_frame(vfx)) * 0.06
	bob_offset := i32(math.sin(f64(bob_phase)) * f64(camera_zoom(camera)))
	py += bob_offset
	spr := sprite_manager_named(sprites, "character", "player")
	render_world_sprite_or_glyph(
		engine,
		sprites,
		ui.use_sprites,
		spr,
		game.player.glyph,
		nil,
		game.player.color,
		px,
		py,
		tile_size,
	)
}

// ─── gcore.Enemy rendering ──────────────────────────────────────────────────────────

render_enemies :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	vfx := game_engine_vfx_manager(engine)
	ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
	tile_size := camera_tile_size(camera)

	for &enemy in game.enemies {
		if !enemy.alive {continue}

		if !gcore.tile_visible_at(game, enemy.pos.x, enemy.pos.y) {continue}

		ex := camera_world_x_to_screen_shaken(camera, vfx, enemy.pos.x * gcore.TILE_SIZE)
		ey := camera_world_y_to_screen_shaken(camera, vfx, enemy.pos.y * gcore.TILE_SIZE)
		bob_phase := f32(eng.vfx_manager_frame(vfx) + enemy.pos.x * 17 + enemy.pos.y * 31) * 0.05
		bob_offset := i32(math.sin(f64(bob_phase)) * 1.5)
		ey += bob_offset

		spr := sprite_manager_enemy(sprites, enemy.enemy_type)
		render_world_sprite_or_glyph(
			engine,
			sprites,
			ui.use_sprites,
			spr,
			enemy.glyph,
			nil,
			enemy.color,
			ex,
			ey,
			tile_size,
		)
	}
}
