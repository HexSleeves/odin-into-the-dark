package main

import "core:fmt"
import rl "vendor:raylib"

// ─── Tile color constants ─────────────────────────────────────────────────────

WALL_COLOR :: rl.Color{40, 40, 45, 255}
FLOOR_COLOR :: rl.Color{139, 90, 43, 255}
RUBBLE_COLOR :: rl.Color{180, 160, 100, 255}
DESCENT_COLOR :: rl.Color{0, 200, 200, 255}
UNSEEN_COLOR :: rl.Color{0, 0, 0, 255}

// Dimming multiplier for explored-but-not-visible tiles (used in S03 FOV)
EXPLORED_DIM :: 0.4

// ─── Tile color helpers ───────────────────────────────────────────────────────

dim_color :: proc(c: rl.Color, factor: f32) -> rl.Color {
	return rl.Color{u8(f32(c.r) * factor), u8(f32(c.g) * factor), u8(f32(c.b) * factor), c.a}
}

base_tile_color :: proc(type: Tile_Type) -> rl.Color {
	#partial switch type {
	case .Wall:
		return WALL_COLOR
	case .Floor:
		return FLOOR_COLOR
	case .Rubble:
		return RUBBLE_COLOR
	case .Descent:
		return DESCENT_COLOR
	}
	return UNSEEN_COLOR
}

get_tile_color :: proc(tile: Tile) -> rl.Color {
	if tile.visible {
		return dim_color(base_tile_color(tile.type), max(tile.light_level, 0.3))
	}
	if tile.explored {
		return dim_color(base_tile_color(tile.type), EXPLORED_DIM)
	}
	return UNSEEN_COLOR
}

// ─── Map rendering (with camera offset) ───────────────────────────────────────

render_map :: proc(game: ^Game) {
	ox := i32(game.camera_x)
	oy := i32(game.camera_y)

	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			sx := i32(x * TILE_SIZE) - ox
			sy := i32(y * TILE_SIZE) - oy

			// Cull tiles entirely outside the map viewport
			if sx + i32(TILE_SIZE) < 0 || sx >= i32(SCREEN_WIDTH) { continue }
			if sy + i32(TILE_SIZE) < 0 || sy >= i32(MAP_VIEW_HEIGHT) { continue }

			tile := game.tiles[pos_to_idx(x, y)]
			color := get_tile_color(tile)
			rl.DrawRectangle(sx, sy, i32(TILE_SIZE), i32(TILE_SIZE), color)
		}
	}
}

// ─── Player rendering ─────────────────────────────────────────────────────────

render_player :: proc(game: ^Game) {
	px := i32(game.player.pos.x * TILE_SIZE) - i32(game.camera_x)
	py := i32(game.player.pos.y * TILE_SIZE) - i32(game.camera_y)

	font_size :: i32(TILE_SIZE)
	glyph_buf: [2]u8
	glyph_buf[0] = u8(game.player.glyph)
	glyph_buf[1] = 0
	glyph_cstr := cast(cstring)&glyph_buf[0]
	rl.DrawText(glyph_cstr, px, py, font_size, game.player.color)
}

// ─── Enemy rendering ──────────────────────────────────────────────────────────

render_enemies :: proc(game: ^Game) {
	ox := i32(game.camera_x)
	oy := i32(game.camera_y)

	for &enemy in game.enemies {
		if !enemy.alive { continue }

		tile := tile_at(game, enemy.pos.x, enemy.pos.y)
		if tile == nil || !tile.visible { continue }

		ex := i32(enemy.pos.x * TILE_SIZE) - ox
		ey := i32(enemy.pos.y * TILE_SIZE) - oy

		font_size :: i32(TILE_SIZE)
		glyph_buf: [2]u8
		glyph_buf[0] = u8(enemy.glyph)
		glyph_buf[1] = 0
		glyph_cstr := cast(cstring)&glyph_buf[0]
		rl.DrawText(glyph_cstr, ex, ey, font_size, enemy.color)
	}
}

// ─── HUD rendering (fixed region below map viewport) ──────────────────────────

render_hud :: proc(game: ^Game) {
	hud_y := i32(MAP_VIEW_HEIGHT)

	// Background bar
	rl.DrawRectangle(0, hud_y, i32(SCREEN_WIDTH), i32(HUD_REGION_HEIGHT), rl.Color{20, 20, 25, 255})

	// HP bar
	hp_ratio := f32(max(game.player.hp, 0)) / f32(game.player.max_hp)
	hp_bar_w :: i32(200)
	hp_bar_h :: i32(16)
	hp_x :: i32(8)
	hp_y := hud_y + 4

	// Background (red)
	rl.DrawRectangle(hp_x, hp_y, hp_bar_w, hp_bar_h, rl.Color{80, 20, 20, 255})
	// Foreground (green)
	rl.DrawRectangle(hp_x, hp_y, i32(f32(hp_bar_w) * hp_ratio), hp_bar_h, rl.Color{40, 180, 40, 255})

	// HP text
	rl.DrawText(
		rl.TextFormat("HP: %d/%d", i32(game.player.hp), i32(game.player.max_hp)),
		hp_x + 4, hp_y + 1, 14, rl.WHITE,
	)

	// Stats line
	stats_y := hp_y + hp_bar_h + 4

	alive_count: i32 = 0
	for &e in game.enemies {
		if e.alive { alive_count += 1 }
	}

	rl.DrawText(
		rl.TextFormat(
			"Depth: %d  |  Light: %d  |  Enemies: %d  |  Turn: %d  |  G=Grab  I=Inv  .=Wait",
			i32(game.depth), i32(game.player.light_radius), alive_count, i32(game.turn_count),
		),
		hp_x, stats_y, 14, rl.Color{180, 180, 180, 255},
	)
}

// ─── Inventory overlay screen ─────────────────────────────────────────────────

render_inventory :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), rl.Color{0, 0, 0, 200})

	title := cstring("INVENTORY")
	title_size :: i32(30)
	title_w := rl.MeasureText(title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	rl.DrawText(title, title_x, 100, title_size, rl.WHITE)

	subtitle := cstring("Press 1-9 to use | I or ESC to close")
	subtitle_size :: i32(14)
	sub_w := rl.MeasureText(subtitle, subtitle_size)
	sub_x := (i32(SCREEN_WIDTH) - sub_w) / 2
	rl.DrawText(subtitle, sub_x, 140, subtitle_size, rl.Color{150, 150, 150, 255})

	slot_size :: i32(16)
	slot_x :: i32(440)
	empty_color :: rl.Color{80, 80, 80, 255}

	for idx in 0 ..< MAX_INVENTORY {
		y_pos := i32(180) + i32(idx) * 28
		if game.inventory[idx].occupied {
			it := game.inventory[idx].item
			name := item_display_name(&it)
			if it.quantity > 1 {
				rl.DrawText(
					fmt.ctprintf("%d. %s x%d", idx + 1, name, it.quantity),
					slot_x, y_pos, slot_size, it.color,
				)
			} else {
				rl.DrawText(
					fmt.ctprintf("%d. %s", idx + 1, name),
					slot_x, y_pos, slot_size, it.color,
				)
			}
		} else {
			rl.DrawText(
				fmt.ctprintf("%d. [empty]", idx + 1),
				slot_x, y_pos, slot_size, empty_color,
			)
		}
	}
}

// ─── Game Over screen ─────────────────────────────────────────────────────────

render_game_over :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), rl.Color{0, 0, 0, 180})

	center_y := i32(MAP_VIEW_HEIGHT) / 2 - 60

	title_size :: i32(40)
	title := cstring("GAME OVER")
	title_w := rl.MeasureText(title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	rl.DrawText(title, title_x, center_y, title_size, rl.RED)

	depth_size :: i32(20)
	depth_text := rl.TextFormat("Reached depth %d", i32(game.depth))
	depth_w := rl.MeasureText(depth_text, depth_size)
	depth_x := (i32(SCREEN_WIDTH) - depth_w) / 2
	rl.DrawText(depth_text, depth_x, center_y + 50, depth_size, rl.Color{200, 200, 200, 255})

	stats_size :: i32(18)
	stats_text := rl.TextFormat(
		"Enemies slain: %d  |  Turns: %d",
		i32(game.kills), i32(game.turn_count),
	)
	stats_w := rl.MeasureText(stats_text, stats_size)
	stats_x := (i32(SCREEN_WIDTH) - stats_w) / 2
	rl.DrawText(stats_text, stats_x, center_y + 80, stats_size, rl.Color{180, 180, 180, 255})

	restart := cstring("Press R to restart  |  ESC to quit")
	restart_size :: i32(16)
	restart_w := rl.MeasureText(restart, restart_size)
	restart_x := (i32(SCREEN_WIDTH) - restart_w) / 2
	rl.DrawText(restart, restart_x, center_y + 110, restart_size, rl.Color{150, 150, 150, 255})
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
	if int(mouse.y) >= MAP_VIEW_HEIGHT { return }

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

	if box_x + box_w > i32(SCREEN_WIDTH) { box_x = i32(SCREEN_WIDTH) - box_w }
	if box_x < 0 { box_x = 0 }
	if box_y < 0 { box_y = 0 }
	if box_y + box_h > i32(SCREEN_HEIGHT) { box_y = i32(SCREEN_HEIGHT) - box_h }

	rl.DrawRectangle(box_x, box_y, box_w, box_h, TOOLTIP_BG_COLOR)
	rl.DrawText(tooltip_text, box_x + TOOLTIP_PAD_X, box_y + TOOLTIP_PAD_Y, TOOLTIP_FONT_SIZE, TOOLTIP_TEXT_COLOR)
}

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(game: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// Clip the map rendering to the viewport region so it doesn't bleed into HUD/messages
	rl.BeginScissorMode(0, 0, i32(SCREEN_WIDTH), i32(MAP_VIEW_HEIGHT))
	render_map(game)
	render_items(game)
	render_enemies(game)
	render_player(game)
	rl.EndScissorMode()

	render_hud(game)
	render_messages(game)

	if game.state == .Playing {
		render_tooltip(game)
	}
	if game.state == .Game_Over {
		render_game_over(game)
	}
	if game.state == .Viewing_Inventory {
		render_inventory(game)
	}

	rl.EndDrawing()
}
