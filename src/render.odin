package main

import "core:fmt"
import rl "vendor:raylib"

// ─── Depth palette definitions ────────────────────────────────────────────────

PALETTE_MINE :: Floor_Palette{
	wall    = rl.Color{40, 40, 45, 255},
	floor   = rl.Color{139, 90, 43, 255},
	rubble  = rl.Color{180, 160, 100, 255},
	descent = rl.Color{0, 200, 200, 255},
}

PALETTE_STONE :: Floor_Palette{
	wall    = rl.Color{50, 50, 55, 255},
	floor   = rl.Color{100, 100, 110, 255},
	rubble  = rl.Color{130, 130, 120, 255},
	descent = rl.Color{0, 200, 200, 255},
}

PALETTE_CRYSTAL :: Floor_Palette{
	wall    = rl.Color{30, 45, 60, 255},
	floor   = rl.Color{50, 90, 100, 255},
	rubble  = rl.Color{80, 140, 130, 255},
	descent = rl.Color{0, 255, 200, 255},
}

PALETTE_DEEP :: Floor_Palette{
	wall    = rl.Color{35, 20, 45, 255},
	floor   = rl.Color{70, 40, 80, 255},
	rubble  = rl.Color{110, 60, 120, 255},
	descent = rl.Color{200, 100, 255, 255},
}

UNSEEN_COLOR :: rl.Color{0, 0, 0, 255}

// Dimming multiplier for explored-but-not-visible tiles (used in S03 FOV)
EXPLORED_DIM :: 0.4

// ─── Palette selection ────────────────────────────────────────────────────────

palette_for_depth :: proc(depth: int) -> Floor_Palette {
	if depth <= 2 { return PALETTE_MINE }
	if depth <= 4 { return PALETTE_STONE }
	if depth <= 7 { return PALETTE_CRYSTAL }
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
		return dim_color(base_tile_color(tile.type, palette), max(tile.light_level, 0.3))
	}
	if tile.explored {
		return dim_color(base_tile_color(tile.type, palette), EXPLORED_DIM)
	}
	return UNSEEN_COLOR
}

// ─── Map rendering (with camera offset) ───────────────────────────────────────

render_map :: proc(game: ^Game) {
	ox := i32(game.camera_x)
	oy := i32(game.camera_y)
	palette := game.palette

	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			sx := i32(x * TILE_SIZE) - ox
			sy := i32(y * TILE_SIZE) - oy

			// Cull tiles entirely outside the map viewport
			if sx + i32(TILE_SIZE) < 0 || sx >= i32(SCREEN_WIDTH) {continue}
			if sy + i32(TILE_SIZE) < 0 || sy >= i32(MAP_VIEW_HEIGHT) {continue}

			tile := game.tiles[pos_to_idx(x, y)]
			color := get_tile_color(tile, palette)
			rl.DrawRectangle(sx, sy, i32(TILE_SIZE), i32(TILE_SIZE), color)

			// Ore vein indicator on walls
			if tile.type == .Wall && (tile.visible || tile.explored) {
				vein := game.ore_veins[pos_to_idx(x, y)]
				if vein.ore_type != "" {
					dot_x := sx + i32(TILE_SIZE) / 2 - 2
					dot_y := sy + i32(TILE_SIZE) / 2 - 2
					vein_color := vein.color
					if !tile.visible {
						vein_color = dim_color(vein.color, EXPLORED_DIM)
					}
					rl.DrawRectangle(dot_x, dot_y, 4, 4, vein_color)
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

			rl.DrawText("w", sx, sy, i32(TILE_SIZE), rl.Color{180, 180, 180, 150})
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
		if !enemy.alive {continue}

		tile := tile_at(game, enemy.pos.x, enemy.pos.y)
		if tile == nil || !tile.visible {continue}

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
	rl.DrawRectangle(
		0,
		hud_y,
		i32(SCREEN_WIDTH),
		i32(HUD_REGION_HEIGHT),
		rl.Color{20, 20, 25, 255},
	)

	// HP bar
	hp_ratio := f32(max(game.player.hp, 0)) / f32(game.player.max_hp)
	hp_bar_w :: i32(200)
	hp_bar_h :: i32(16)
	hp_x :: i32(8)
	hp_y := hud_y + 4

	// Background (red)
	rl.DrawRectangle(hp_x, hp_y, hp_bar_w, hp_bar_h, rl.Color{80, 20, 20, 255})
	// Foreground (green)
	rl.DrawRectangle(
		hp_x,
		hp_y,
		i32(f32(hp_bar_w) * hp_ratio),
		hp_bar_h,
		rl.Color{40, 180, 40, 255},
	)

	// HP text
	rl.DrawText(
		rl.TextFormat("HP: %d/%d", i32(game.player.hp), i32(game.player.max_hp)),
		hp_x + 4,
		hp_y + 1,
		14,
		rl.WHITE,
	)

	// Stats line
	stats_y := hp_y + hp_bar_h + 4

	alive_count: i32 = 0
	for &e in game.enemies {
		if e.alive {alive_count += 1}
	}

	rl.DrawText(
		rl.TextFormat(
			"Depth: %d  |  Light: %d  |  Enemies: %d  |  Turn: %d  |  G=Grab  I=Inv  X=Mine  M=Map  ?=Help",
			i32(game.depth),
			i32(game.player.light_radius),
			alive_count,
			i32(game.turn_count),
		),
		hp_x,
		stats_y,
		14,
		rl.Color{180, 180, 180, 255},
	)

	// Oil buff indicator
	if game.light_boost_turns > 0 {
		oil_text := rl.TextFormat("Oil: %dt", i32(game.light_boost_turns))
		oil_x := hp_x + hp_bar_w + 16
		rl.DrawText(oil_text, oil_x, hp_y + 1, 14, rl.Color{255, 200, 80, 255})
	}

	// Pickaxe durability bar
	pick_x := hp_x + hp_bar_w + 120
	pick_bar_w :: i32(80)
	pick_bar_h :: i32(12)
	pick_y := hp_y + 2

	// Background
	rl.DrawRectangle(pick_x, pick_y, pick_bar_w, pick_bar_h, rl.Color{40, 30, 20, 255})

	if game.pickaxe_durability > 0 {
		pick_ratio := f32(game.pickaxe_durability) / f32(max(game.pickaxe_max_dur, 1))
		// Color gradient: green -> yellow -> red
		pick_color: rl.Color
		if pick_ratio > 0.5 {
			pick_color = rl.Color{80, 180, 80, 255} // green
		} else if pick_ratio > 0.25 {
			pick_color = rl.Color{200, 180, 50, 255} // yellow
		} else {
			pick_color = rl.Color{200, 60, 60, 255} // red
		}
		rl.DrawRectangle(pick_x, pick_y, i32(f32(pick_bar_w) * pick_ratio), pick_bar_h, pick_color)
		rl.DrawText(
			rl.TextFormat("Pick: %d/%d", i32(game.pickaxe_durability), i32(game.pickaxe_max_dur)),
			pick_x + 2, pick_y, 12, rl.WHITE,
		)
	} else {
		rl.DrawText("Pick: BROKEN", pick_x + 2, pick_y, 12, rl.Color{255, 80, 80, 255})
	}

	// Mining mode indicator (centered at top of screen)
	if game.mining_mode {
		mine_text := cstring("[MINING] Choose direction (WASD/arrows) | ESC cancel")
		mine_w := rl.MeasureText(mine_text, 14)
		rl.DrawText(mine_text, (i32(SCREEN_WIDTH) - mine_w) / 2, 2, 14, rl.Color{255, 200, 80, 255})
	}

	// Contextual hint: C=Craft when standing on anvil
	cur := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur != nil && cur.type == .Anvil {
		anvil_text := cstring("[C=Craft]")
		anvil_w := rl.MeasureText(anvil_text, 14)
		rl.DrawText(anvil_text, (i32(SCREEN_WIDTH) - anvil_w) / 2, hud_y - 18, 14, rl.Color{160, 160, 170, 255})
	}

	// Equipment indicators (right side of HUD)
	eq_x := i32(hp_x) + 600
	if game.equipped_weapon.occupied {
		rl.DrawText(
			fmt.ctprintf("Wpn: %s (+%d)", game.equipped_weapon.item.name, game.equipped_weapon.item.stat_bonus),
			eq_x, hp_y + 1, 14, rl.Color{200, 150, 80, 255},
		)
	} else {
		rl.DrawText("Wpn: ---", eq_x, hp_y + 1, 14, rl.Color{80, 80, 80, 255})
	}
	if game.equipped_armor.occupied {
		rl.DrawText(
			fmt.ctprintf("Arm: %s (+%d)", game.equipped_armor.item.name, game.equipped_armor.item.stat_bonus),
			eq_x, hp_y + 18, 14, rl.Color{100, 160, 200, 255},
		)
	} else {
		rl.DrawText("Arm: ---", eq_x, hp_y + 18, 14, rl.Color{80, 80, 80, 255})
	}
	if game.equipped_helmet.occupied {
		rl.DrawText(
			fmt.ctprintf("Hlm: %s (+%d)", game.equipped_helmet.item.name, game.equipped_helmet.item.stat_bonus),
			eq_x + 200, hp_y + 1, 14, rl.Color{200, 200, 50, 255},
		)
	} else {
		rl.DrawText("Hlm: ---", eq_x + 200, hp_y + 1, 14, rl.Color{80, 80, 80, 255})
	}
}

// ─── Inventory overlay screen ─────────────────────────────────────────────────

render_inventory :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), rl.Color{0, 0, 0, 200})

	title := cstring("INVENTORY")
	title_size :: i32(30)
	title_w := rl.MeasureText(title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	rl.DrawText(title, title_x, 100, title_size, rl.WHITE)

	subtitle := cstring("Press 1-9 to use | D=Drop | E=Equip | I or ESC to close")
	subtitle_size :: i32(14)
	sub_w := rl.MeasureText(subtitle, subtitle_size)
	sub_x := (i32(SCREEN_WIDTH) - sub_w) / 2
	rl.DrawText(subtitle, sub_x, 140, subtitle_size, rl.Color{150, 150, 150, 255})

	// Drop mode indicator
	if game.dropping {
		drop_text := cstring("[DROP MODE] Press 1-9 to drop")
		drop_size :: i32(16)
		drop_w := rl.MeasureText(drop_text, drop_size)
		drop_x := (i32(SCREEN_WIDTH) - drop_w) / 2
		rl.DrawText(drop_text, drop_x, 160, drop_size, rl.Color{255, 200, 80, 255})
	}

	// Equip mode indicator
	if game.equipping {
		equip_text := cstring("[EQUIP MODE] Press 1-9 to equip")
		equip_size :: i32(16)
		equip_w := rl.MeasureText(equip_text, equip_size)
		equip_x := (i32(SCREEN_WIDTH) - equip_w) / 2
		rl.DrawText(equip_text, equip_x, 160, equip_size, rl.Color{100, 200, 255, 255})
	}

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
					slot_x,
					y_pos,
					slot_size,
					it.color,
				)
			} else {
				rl.DrawText(
					fmt.ctprintf("%d. %s", idx + 1, name),
					slot_x,
					y_pos,
					slot_size,
					it.color,
				)
			}
		} else {
			rl.DrawText(
				fmt.ctprintf("%d. [empty]", idx + 1),
				slot_x,
				y_pos,
				slot_size,
				empty_color,
			)
		}
	}

	// Equipment section
	eq_y := i32(180) + i32(MAX_INVENTORY) * 28 + 20
	rl.DrawText("EQUIPMENT", slot_x, eq_y, 18, rl.Color{200, 200, 100, 255})
	eq_y += 24

	// Weapon
	if game.equipped_weapon.occupied {
		rl.DrawText(
			fmt.ctprintf("Weapon: %s (+%d atk)", game.equipped_weapon.item.name, game.equipped_weapon.item.stat_bonus),
			slot_x, eq_y, slot_size, rl.Color{200, 150, 80, 255},
		)
	} else {
		rl.DrawText("Weapon: [empty]", slot_x, eq_y, slot_size, empty_color)
	}
	eq_y += 22

	// Armor
	if game.equipped_armor.occupied {
		rl.DrawText(
			fmt.ctprintf("Armor:  %s (+%d def)", game.equipped_armor.item.name, game.equipped_armor.item.stat_bonus),
			slot_x, eq_y, slot_size, rl.Color{100, 160, 200, 255},
		)
	} else {
		rl.DrawText("Armor:  [empty]", slot_x, eq_y, slot_size, empty_color)
	}
	eq_y += 22

	// Helmet
	if game.equipped_helmet.occupied {
		rl.DrawText(
			fmt.ctprintf("Helmet: %s (+%d light)", game.equipped_helmet.item.name, game.equipped_helmet.item.stat_bonus),
			slot_x, eq_y, slot_size, rl.Color{200, 200, 50, 255},
		)
	} else {
		rl.DrawText("Helmet: [empty]", slot_x, eq_y, slot_size, empty_color)
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
		i32(game.kills),
		i32(game.turn_count),
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

// ─── Minimap overlay ──────────────────────────────────────────────────────────

MINIMAP_TILE_SIZE :: i32(2) // each map tile = 2x2 pixels on minimap
MINIMAP_MARGIN :: i32(8)

render_minimap :: proc(game: ^Game) {
	// Position: top-right corner
	mm_w := i32(MAP_WIDTH) * MINIMAP_TILE_SIZE
	mm_h := i32(MAP_HEIGHT) * MINIMAP_TILE_SIZE
	mm_x := i32(SCREEN_WIDTH) - mm_w - MINIMAP_MARGIN
	mm_y := MINIMAP_MARGIN

	// Semi-transparent background
	rl.DrawRectangle(mm_x - 2, mm_y - 2, mm_w + 4, mm_h + 4, rl.Color{0, 0, 0, 180})

	// Draw tiles
	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			tile := game.tiles[pos_to_idx(x, y)]

			px := mm_x + i32(x) * MINIMAP_TILE_SIZE
			py := mm_y + i32(y) * MINIMAP_TILE_SIZE

			if tile.visible {
				c: rl.Color
				#partial switch tile.type {
				case .Wall:    c = rl.Color{80, 80, 90, 255}
				case .Floor:   c = rl.Color{160, 120, 60, 255}
				case .Rubble:  c = rl.Color{140, 130, 90, 255}
				case .Descent: c = rl.Color{0, 255, 255, 255}
				case:          c = rl.Color{120, 100, 80, 255}
				}
				rl.DrawRectangle(px, py, MINIMAP_TILE_SIZE, MINIMAP_TILE_SIZE, c)
			} else if tile.explored {
				c: rl.Color
				#partial switch tile.type {
				case .Wall:    c = rl.Color{30, 30, 35, 255}
				case .Floor:   c = rl.Color{60, 45, 25, 255}
				case .Rubble:  c = rl.Color{55, 50, 35, 255}
				case .Descent: c = rl.Color{0, 80, 80, 255}
				case:          c = rl.Color{50, 40, 30, 255}
				}
				rl.DrawRectangle(px, py, MINIMAP_TILE_SIZE, MINIMAP_TILE_SIZE, c)
			}
			// Unseen tiles: don't draw (background shows through)
		}
	}

	// Draw enemies on visible tiles as red dots
	for &enemy in game.enemies {
		if !enemy.alive {continue}
		tile := tile_at(game, enemy.pos.x, enemy.pos.y)
		if tile == nil || !tile.visible {continue}
		ex := mm_x + i32(enemy.pos.x) * MINIMAP_TILE_SIZE
		ey := mm_y + i32(enemy.pos.y) * MINIMAP_TILE_SIZE
		rl.DrawRectangle(ex, ey, MINIMAP_TILE_SIZE, MINIMAP_TILE_SIZE, rl.Color{255, 60, 60, 255})
	}

	// Draw player as bright yellow dot
	player_px := mm_x + i32(game.player.pos.x) * MINIMAP_TILE_SIZE
	player_py := mm_y + i32(game.player.pos.y) * MINIMAP_TILE_SIZE
	rl.DrawRectangle(player_px, player_py, MINIMAP_TILE_SIZE, MINIMAP_TILE_SIZE, rl.Color{255, 255, 0, 255})
}

// ─── Crafting overlay screen ──────────────────────────────────────────────────

render_crafting :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), rl.Color{0, 0, 0, 200})

	title := cstring("CRAFTING")
	title_size :: i32(30)
	title_w := rl.MeasureText(title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	rl.DrawText(title, title_x, 100, title_size, rl.WHITE)

	subtitle := cstring("Press 1-4 to craft | C or ESC to close")
	subtitle_size :: i32(14)
	sub_w := rl.MeasureText(subtitle, subtitle_size)
	sub_x := (i32(SCREEN_WIDTH) - sub_w) / 2
	rl.DrawText(subtitle, sub_x, 140, subtitle_size, rl.Color{150, 150, 150, 255})

	recipes := RECIPES
	slot_x :: i32(340)

	for idx in 0 ..< len(recipes) {
		recipe := recipes[idx]
		y_pos := i32(180) + i32(idx) * 40

		have := count_material(game, recipe.material_id)
		can_craft := have >= recipe.material_qty

		color := rl.Color{100, 255, 100, 255} if can_craft else rl.Color{150, 80, 80, 255}

		// Get material display name
		mat_def := find_item_def(recipe.material_id)
		mat_name := recipe.material_id
		if mat_def != nil { mat_name = mat_def.name }

		rl.DrawText(
			fmt.ctprintf("%d. %s  [%d/%d %s]", idx + 1, recipe.name, have, recipe.material_qty, mat_name),
			slot_x, y_pos, 16, color,
		)
	}
}

// ─── Help screen overlay ──────────────────────────────────────────────────────

render_help :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), rl.Color{0, 0, 0, 220})

	title := cstring("CONTROLS & HELP")
	title_size :: i32(28)
	title_w := rl.MeasureText(title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	rl.DrawText(title, title_x, 60, title_size, rl.WHITE)

	col1_x :: i32(180)
	col2_x :: i32(580)
	start_y :: i32(110)
	line_h :: i32(22)
	head_color :: rl.Color{255, 220, 100, 255}
	key_color :: rl.Color{100, 200, 255, 255}
	desc_color :: rl.Color{200, 200, 200, 255}

	// ── Column 1: Movement & Actions ──
	rl.DrawText("MOVEMENT", col1_x, start_y, 16, head_color)
	rl.DrawText("WASD / Arrows    Move", col1_x, start_y + line_h * 1, 14, desc_color)
	rl.DrawText(".  (period)      Wait a turn", col1_x, start_y + line_h * 2, 14, desc_color)
	rl.DrawText("Walk into enemy  Attack", col1_x, start_y + line_h * 3, 14, desc_color)

	rl.DrawText("ITEMS", col1_x, start_y + line_h * 5, 16, head_color)
	rl.DrawText("G                Pick up item", col1_x, start_y + line_h * 6, 14, desc_color)
	rl.DrawText("I                Open inventory", col1_x, start_y + line_h * 7, 14, desc_color)
	rl.DrawText("  1-9            Use item", col1_x, start_y + line_h * 8, 14, desc_color)
	rl.DrawText("  D + 1-9        Drop item", col1_x, start_y + line_h * 9, 14, desc_color)
	rl.DrawText("  E + 1-9        Equip item", col1_x, start_y + line_h * 10, 14, desc_color)

	rl.DrawText("MINING", col1_x, start_y + line_h * 12, 16, head_color)
	rl.DrawText("X + direction    Mine adjacent wall", col1_x, start_y + line_h * 13, 14, desc_color)
	rl.DrawText("C  (on anvil)    Open crafting", col1_x, start_y + line_h * 14, 14, desc_color)

	// ── Column 2: UI & Info ──
	rl.DrawText("DISPLAY", col2_x, start_y, 16, head_color)
	rl.DrawText("M                Toggle minimap", col2_x, start_y + line_h * 1, 14, desc_color)
	rl.DrawText("?                This help screen", col2_x, start_y + line_h * 2, 14, desc_color)
	rl.DrawText("ESC              Close menu / Quit", col2_x, start_y + line_h * 3, 14, desc_color)
	rl.DrawText("R  (game over)   Restart", col2_x, start_y + line_h * 4, 14, desc_color)

	rl.DrawText("TILE LEGEND", col2_x, start_y + line_h * 6, 16, head_color)
	rl.DrawText("@  You", col2_x, start_y + line_h * 7, 14, rl.YELLOW)
	rl.DrawText(">  Descent to next depth", col2_x, start_y + line_h * 8, 14, rl.Color{0, 200, 200, 255})
	rl.DrawText("*  Ore vein (colored dot on wall)", col2_x, start_y + line_h * 9, 14, rl.Color{200, 120, 50, 255})
	rl.DrawText("~  Water (slows movement)", col2_x, start_y + line_h * 10, 14, rl.Color{40, 80, 180, 255})
	rl.DrawText("!  Gas vent (damages you)", col2_x, start_y + line_h * 11, 14, rl.Color{160, 180, 40, 255})
	rl.DrawText("^  Unstable ground (collapses)", col2_x, start_y + line_h * 12, 14, rl.Color{180, 120, 60, 255})
	rl.DrawText("#  Anvil (stand on it, press C)", col2_x, start_y + line_h * 13, 14, rl.Color{160, 160, 170, 255})

	rl.DrawText("TIPS", col2_x, start_y + line_h * 15, 16, head_color)
	rl.DrawText("Mine walls to find ores!", col2_x, start_y + line_h * 16, 14, desc_color)
	rl.DrawText("Craft at anvils with materials.", col2_x, start_y + line_h * 17, 14, desc_color)
	rl.DrawText("Light shrinks as you go deeper.", col2_x, start_y + line_h * 18, 14, desc_color)

	// Footer
	footer := cstring("Press ESC or ? to close")
	footer_w := rl.MeasureText(footer, 14)
	rl.DrawText(footer, (i32(SCREEN_WIDTH) - footer_w) / 2, i32(SCREEN_HEIGHT) - 40, 14, rl.Color{120, 120, 120, 255})
}

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(game: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// Clip the map rendering to the viewport region so it doesn't bleed into HUD/messages
	rl.BeginScissorMode(0, 0, i32(SCREEN_WIDTH), i32(MAP_VIEW_HEIGHT))
	render_map(game)
	render_webs(game)
	render_items(game)
	render_enemies(game)
	render_player(game)
	rl.EndScissorMode()

	render_hud(game)
	render_messages(game)

	if game.show_minimap && game.state == .Playing {
		render_minimap(game)
	}

	if game.state == .Playing {
		render_tooltip(game)
	}
	if game.state == .Game_Over {
		render_game_over(game)
	}
	if game.state == .Viewing_Inventory {
		render_inventory(game)
	}
	if game.state == .Viewing_Crafting {
		render_crafting(game)
	}
	if game.state == .Viewing_Help {
		render_help(game)
	}

	rl.EndDrawing()
}
