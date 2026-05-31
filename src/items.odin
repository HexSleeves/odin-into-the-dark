package main

import "core:fmt"
import "core:math/rand"

import rl "vendor:raylib"

// ─── Item factory ─────────────────────────────────────────────────────────────

item_make :: proc(itype: Item_Type, pos: Vec2) -> Item {
	switch itype {
	case .Health_Potion:
		return Item{
			pos       = pos,
			item_type = .Health_Potion,
			glyph     = '!',
			color     = rl.Color{255, 80, 80, 255},
			picked_up = false,
		}
	case .Torch:
		return Item{
			pos       = pos,
			item_type = .Torch,
			glyph     = 't',
			color     = rl.Color{255, 180, 50, 255},
			picked_up = false,
		}
	}
	// Unreachable but satisfies compiler
	return Item{}
}

// ─── Human-readable item name ─────────────────────────────────────────────────

item_type_name :: proc(itype: Item_Type) -> string {
	switch itype {
	case .Health_Potion:
		return "Health Potion"
	case .Torch:
		return "Torch"
	}
	return "Unknown"
}

// ─── Find item at position ────────────────────────────────────────────────────

item_at :: proc(game: ^Game, x, y: int) -> ^Item {
	for &it in game.items {
		if !it.picked_up && it.pos.x == x && it.pos.y == y {
			return &it
		}
	}
	return nil
}

// ─── Render items on visible tiles ────────────────────────────────────────────

render_items :: proc(game: ^Game) {
	for &item in game.items {
		if item.picked_up { continue }

		// Only render items on visible tiles
		tile := tile_at(game, item.pos.x, item.pos.y)
		if tile == nil || !tile.visible { continue }

		ix := i32(item.pos.x * TILE_SIZE)
		iy := i32(item.pos.y * TILE_SIZE)
		font_size :: i32(TILE_SIZE)
		glyph_buf: [2]u8
		glyph_buf[0] = u8(item.glyph)
		glyph_buf[1] = 0
		glyph_cstr := cast(cstring)&glyph_buf[0]
		rl.DrawText(glyph_cstr, ix, iy, font_size, item.color)
	}
}

// ─── Spawn items into rooms ───────────────────────────────────────────────────

spawn_items :: proc(game: ^Game) {
	clear(&game.items)

	if len(game.rooms) < 2 {
		return
	}

	total := 0

	// Skip room 0 (player spawn), iterate remaining rooms
	for i in 1 ..< len(game.rooms) {
		// 50% chance to place an item in this room
		if rand.int_max(2) == 0 {
			continue
		}

		room := game.rooms[i]

		// Pick random floor position inside room (with margin)
		placed := false
		for _ in 0 ..< 20 {
			ix := rand.int_max(room.x2 - room.x1 - 2) + room.x1 + 1
			iy := rand.int_max(room.y2 - room.y1 - 2) + room.y1 + 1
			pos := Vec2{ix, iy}

			// Reject invalid positions
			if !is_walkable(game, ix, iy) { continue }
			if pos == game.player.pos { continue }

			// Don't place on descent tile
			t := tile_at(game, ix, iy)
			if t != nil && t.type == .Descent { continue }

			// Don't stack on enemies or other items
			if enemy_at(game, ix, iy) != nil { continue }
			if item_at(game, ix, iy) != nil { continue }

			// 50/50 choice between Health_Potion and Torch
			itype: Item_Type = .Health_Potion if rand.int_max(2) == 0 else .Torch
			append(&game.items, item_make(itype, pos))
			total += 1
			placed = true
			break
		}

		_ = placed // suppress unused warning
	}

	fmt.printfln("[items] spawned %v items across %v rooms (depth=%v)", total, len(game.rooms) - 1, game.depth)
}
