package main

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
	case .Gas_Vent:
		return rl.Color{160, 180, 40, 255}
	case .Unstable:
		return rl.Color{180, 120, 60, 255}
	case .Chasm:
		return rl.Color{10, 10, 15, 255}
	case .Anvil:
		return rl.Color{160, 160, 170, 255}
	}
	return UNSEEN_COLOR
}

get_tile_color :: proc(tile: Tile, palette: Floor_Palette) -> rl.Color {
	if tile.visible {
		return dim_color(base_tile_color(tile.type, palette), max(tile.light_level, 0.5))
	}
	if tile.explored {
		return dim_color(base_tile_color(tile.type, palette), EXPLORED_DIM)
	}
	return UNSEEN_COLOR
}

// ─── Map rendering (with camera offset) ───────────────────────────────────────

render_map :: proc(game: ^Game) {
	game.anim_frame += 1

	ox := i32(game.camera_x)
	oy := i32(game.camera_y)
	palette := palette_for_depth(game.depth)

	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			sx := i32(x * TILE_SIZE) - ox
			sy := i32(y * TILE_SIZE) - oy

			// Cull tiles entirely outside the map viewport
			if sx + i32(TILE_SIZE) < 0 || sx >= i32(SCREEN_WIDTH) {continue}
			if sy + i32(TILE_SIZE) < 0 || sy >= i32(MAP_VIEW_HEIGHT) {continue}

			tile := game.tiles[pos_to_idx(x, y)]

			if !tile.visible && !tile.explored {
				rl.DrawRectangle(sx, sy, i32(TILE_SIZE), i32(TILE_SIZE), UNSEEN_COLOR)
			} else {
				spr := get_tile_sprite(tile.type)
				base := base_tile_color(tile.type, palette)
				tint: rl.Color
				if tile.visible {
					brightness := max(tile.light_level, 0.5)
					tint = rl.Color{u8(f32(base.r) * brightness), u8(f32(base.g) * brightness), u8(f32(base.b) * brightness), 255}
				} else {
					dim := f32(EXPLORED_DIM)
					tint = rl.Color{u8(f32(base.r) * dim), u8(f32(base.g) * dim), u8(f32(base.b) * dim), 255}
				}
				draw_sprite(spr, sx, sy, tint)

				// Ore vein overlay on walls
				if tile.type == .Wall {
					vein := game.ore_veins[pos_to_idx(x, y)]
					if vein.ore_type != "" {
						ore_tint := vein.color
						if !tile.visible {
							ore_tint = dim_color(vein.color, EXPLORED_DIM)
						}
						draw_sprite(g_sprites.spr_ore_vein, sx, sy, ore_tint)
					}
				}
			}
		}
	}
}

// ─── Web tile rendering ───────────────────────────────────────────────────────

render_webs :: proc(game: ^Game) {
	ox := i32(game.camera_x)
	oy := i32(game.camera_y)

	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			idx := pos_to_idx(x, y)
			if !game.web_tiles[idx] {continue}

			tile := &game.tiles[idx]
			if !tile.visible {continue}

			sx := i32(x * TILE_SIZE) - ox
			sy := i32(y * TILE_SIZE) - oy

			// Cull off-screen
			if sx + i32(TILE_SIZE) < 0 || sx >= i32(SCREEN_WIDTH) {continue}
			if sy + i32(TILE_SIZE) < 0 || sy >= i32(MAP_VIEW_HEIGHT) {continue}

			draw_sprite(g_sprites.spr_web, sx, sy, rl.Color{180, 180, 180, 150})
		}
	}
}

// ─── Player rendering ─────────────────────────────────────────────────────────

render_player :: proc(game: ^Game) {
	px := i32(game.player.pos.x * TILE_SIZE) - i32(game.camera_x)
	py := i32(game.player.pos.y * TILE_SIZE) - i32(game.camera_y)

	bob_phase := f32(game.anim_frame) * 0.06
	bob_offset := i32(math.sin(f64(bob_phase)) * 0.8)
	py += bob_offset

	if g_sprites.loaded {
		draw_sprite(g_sprites.spr_player, px, py)
	} else {
		glyph_buf: [2]u8
		glyph_buf[0] = u8(game.player.glyph)
		glyph_buf[1] = 0
		rl.DrawText(cast(cstring)&glyph_buf[0], px, py, i32(TILE_SIZE), game.player.color)
	}
}

// ─── Enemy rendering ──────────────────────────────────────────────────────────

render_enemies :: proc(game: ^Game) {
	ox := i32(game.camera_x)
	oy := i32(game.camera_y)

	for &enemy in game.enemies {
		if !enemy.alive {continue}

		tile := tile_at(game, enemy.pos.x, enemy.pos.y)
		if tile == nil || !tile.visible {continue}

		ex := i32(enemy.pos.x * TILE_SIZE) - ox
		ey := i32(enemy.pos.y * TILE_SIZE) - oy

		bob_phase := f32(game.anim_frame + enemy.pos.x * 17 + enemy.pos.y * 31) * 0.05
		bob_offset := i32(math.sin(f64(bob_phase)) * 1.5)
		ey += bob_offset

		if g_sprites.loaded {
			spr := get_enemy_sprite(enemy.enemy_type)
			draw_sprite(spr, ex, ey, enemy.color)
		} else {
			glyph_buf: [2]u8
			glyph_buf[0] = u8(enemy.glyph)
			glyph_buf[1] = 0
			rl.DrawText(cast(cstring)&glyph_buf[0], ex, ey, i32(TILE_SIZE), enemy.color)
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

render_tooltip :: proc(game: ^Game) {
	mouse := rl.GetMousePosition()

	// Only show tooltips when mouse is in the map viewport region
	if int(mouse.y) >= MAP_VIEW_HEIGHT {return}

	// Convert screen coordinates to tile coordinates using camera offset
	tile_x := (int(mouse.x) + game.camera_x) / TILE_SIZE
	tile_y := (int(mouse.y) + game.camera_y) / TILE_SIZE

	if tile_x < 0 || tile_x >= MAP_WIDTH || tile_y < 0 || tile_y >= MAP_HEIGHT {
		return
	}

	tile := tile_at(game, tile_x, tile_y)
	if tile == nil || !tile.visible {
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

	text_w := rl.MeasureText(tooltip_text, TOOLTIP_FONT_SIZE)
	box_w := text_w + TOOLTIP_PAD_X * 2
	box_h := TOOLTIP_FONT_SIZE + TOOLTIP_PAD_Y * 2

	box_x := i32(mouse.x) + TOOLTIP_OFFSET_X
	box_y := i32(mouse.y) + TOOLTIP_OFFSET_Y

	if box_x + box_w > i32(SCREEN_WIDTH) {box_x = i32(SCREEN_WIDTH) - box_w}
	if box_x < 0 {box_x = 0}
	if box_y < 0 {box_y = 0}
	if box_y + box_h > i32(SCREEN_HEIGHT) {box_y = i32(SCREEN_HEIGHT) - box_h}

	rl.DrawRectangle(box_x, box_y, box_w, box_h, TOOLTIP_BG_COLOR)
	rl.DrawText(
		tooltip_text,
		box_x + TOOLTIP_PAD_X,
		box_y + TOOLTIP_PAD_Y,
		TOOLTIP_FONT_SIZE,
		TOOLTIP_TEXT_COLOR,
	)
}
