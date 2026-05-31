package main

import "core:fmt"
import "core:math/rand"

import rl "vendor:raylib"

// ─── Item factory ─────────────────────────────────────────────────────────────

item_make :: proc(itype: Item_Type, pos: Vec2) -> Item {
	switch itype {
	case .Health_Potion:
		return Item {
			pos = pos,
			item_type = .Health_Potion,
			glyph = '!',
			color = rl.Color{255, 80, 80, 255},
			picked_up = false,
			quantity = 1,
		}
	case .Torch:
		return Item {
			pos = pos,
			item_type = .Torch,
			glyph = 't',
			color = rl.Color{255, 180, 50, 255},
			picked_up = false,
			quantity = 1,
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

// ─── Stack limits per item type ───────────────────────────────────────────────
// Returns the maximum stack size. A value of 1 means the item does not stack.

item_stack_limit :: proc(itype: Item_Type) -> int {
	switch itype {
	case .Health_Potion: return 3
	case .Torch:         return 1
	}
	return 1
}

// Returns whether this item type is allowed to stack in inventory.
item_is_stackable :: proc(itype: Item_Type) -> bool {
	return item_stack_limit(itype) > 1
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

// ─── Pick up item at player position ──────────────────────────────────────────

pickup_item :: proc(game: ^Game) -> bool {
	it := item_at(game, game.player.pos.x, game.player.pos.y)
	if it == nil {
		add_message(game, "Nothing to pick up here.", rl.Color{180, 180, 180, 255})
		return false
	}

	itype := it.item_type
	stack_limit := item_stack_limit(itype)

	// Only stackable items can merge into existing stacks
	if item_is_stackable(itype) {
		for i in 0 ..< MAX_INVENTORY {
			slot := &game.inventory[i]
			if slot.occupied && slot.item.item_type == itype && slot.item.quantity < stack_limit {
				slot.item.quantity += 1
				it.picked_up = true
				add_message(
					game,
					fmt.tprintf("Picked up %s (%d/%d).", item_type_name(itype), slot.item.quantity, stack_limit),
					rl.Color{100, 255, 100, 255},
				)
				return true
			}
		}
	}

	// Find first empty inventory slot for a new stack
	slot_idx := -1
	for i in 0 ..< MAX_INVENTORY {
		if !game.inventory[i].occupied {
			slot_idx = i
			break
		}
	}

	if slot_idx < 0 {
		add_message(game, "Inventory is full!", rl.Color{255, 100, 100, 255})
		return false
	}

	// Copy item into slot as a new stack of 1 and mark map item as picked up
	game.inventory[slot_idx].occupied = true
	game.inventory[slot_idx].item = it^
	game.inventory[slot_idx].item.quantity = 1
	it.picked_up = true

	add_message(
		game,
		fmt.tprintf("Picked up %s.", item_type_name(itype)),
		rl.Color{100, 255, 100, 255},
	)
	return true
}

// ─── Use an item from inventory ───────────────────────────────────────────────

use_item :: proc(game: ^Game, slot_index: int) -> bool {
	if slot_index < 0 || slot_index >= MAX_INVENTORY {
		return false
	}
	if !game.inventory[slot_index].occupied {
		return false
	}

	itype := game.inventory[slot_index].item.item_type

	switch itype {
	case .Health_Potion:
		heal_amount :: 8
		actual_heal := min(heal_amount, game.player.max_hp - game.player.hp)
		game.player.hp = min(game.player.hp + heal_amount, game.player.max_hp)
		add_message(
			game,
			fmt.tprintf("You use a Health Potion. Restored %d HP.", actual_heal),
			rl.Color{100, 255, 100, 255},
		)
	case .Torch:
		radius_boost :: 3
		game.player.light_radius = min(game.player.light_radius + radius_boost, 10)
		add_message(
			game,
			"You use a Torch. Light radius increased.",
			rl.Color{255, 180, 50, 255},
		)
	}

	// Decrement stack quantity; clear slot only when empty
	game.inventory[slot_index].item.quantity -= 1
	if game.inventory[slot_index].item.quantity <= 0 {
		game.inventory[slot_index] = {}
	}
	return true
}

// ─── Render items on visible tiles ────────────────────────────────────────────

render_items :: proc(game: ^Game) {
	ox := i32(game.camera_x)
	oy := i32(game.camera_y)

	for &item in game.items {
		if item.picked_up {continue}

		// Only render items on visible tiles
		tile := tile_at(game, item.pos.x, item.pos.y)
		if tile == nil || !tile.visible {continue}

		ix := i32(item.pos.x * TILE_SIZE) - ox
		iy := i32(item.pos.y * TILE_SIZE) - oy
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
			if !is_walkable(game, ix, iy) {continue}
			if pos == game.player.pos {continue}

			// Don't place on descent tile
			t := tile_at(game, ix, iy)
			if t != nil && t.type == .Descent {continue}

			// Don't stack on enemies or other items
			if enemy_at(game, ix, iy) != nil {continue}
			if item_at(game, ix, iy) != nil {continue}

			// 50/50 choice between Health_Potion and Torch
			itype: Item_Type = .Health_Potion if rand.int_max(2) == 0 else .Torch
			append(&game.items, item_make(itype, pos))
			total += 1
			placed = true
			break
		}

		_ = placed // suppress unused warning
	}

	fmt.printfln(
		"[items] spawned %v items across %v rooms (depth=%v)",
		total,
		len(game.rooms) - 1,
		game.depth,
	)
}
