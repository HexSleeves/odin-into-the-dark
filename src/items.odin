package main

import "core:fmt"
import "core:math/rand"

import rl "vendor:raylib"

// ─── Item factory (data-driven) ───────────────────────────────────────────────

item_make :: proc(id: string, pos: Vec2) -> Item {
	def := find_item_def(id)
	if def != nil {
		return item_make_from_def(def, pos)
	}
	// Fallback: unknown item
	fmt.eprintfln("[item] WARNING: unknown item id '%s'", id)
	return Item {
		pos = pos,
		item_type = id,
		name = id,
		glyph = '?',
		color = rl.WHITE,
		picked_up = false,
		quantity = 1,
	}
}

// ─── Stack limit lookup (data-driven) ─────────────────────────────────────────

item_stack_limit :: proc(id: string) -> int {
	def := find_item_def(id)
	if def != nil && def.stack_limit > 0 {
		return def.stack_limit
	}
	return 1
}

item_is_stackable :: proc(id: string) -> bool {
	return item_stack_limit(id) > 1
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
					fmt.tprintf(
						"Picked up %s (%d/%d).",
						item_display_name(it),
						slot.item.quantity,
						stack_limit,
					),
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
		fmt.tprintf("Picked up %s.", item_display_name(it)),
		rl.Color{100, 255, 100, 255},
	)
	return true
}

// ─── Use an item from inventory (data-driven) ────────────────────────────────

use_item :: proc(game: ^Game, slot_index: int) -> bool {
	if slot_index < 0 || slot_index >= MAX_INVENTORY {
		return false
	}
	if !game.inventory[slot_index].occupied {
		return false
	}

	itype := game.inventory[slot_index].item.item_type
	def := find_item_def(itype)
	if def != nil {
		// Equip-type items are not consumed on use; hint the player instead
		if def.effect.type == "equip" {
			add_message(
				game,
				fmt.tprintf("Press E in inventory to equip the %s.", def.name),
				rl.Color{180, 180, 180, 255},
			)
			return false
		}
		// Material items cannot be consumed directly
		if def.effect.type == "material" {
			add_message(
				game,
				"Raw materials cannot be used directly. Find an anvil to craft.",
				rl.Color{180, 180, 100, 255},
			)
			return false
		}
		apply_item_effect(game, def)
	} else {
		add_message(game, "Nothing happens.", rl.Color{180, 180, 180, 255})
	}

	// Decrement stack quantity; clear slot only when empty
	game.inventory[slot_index].item.quantity -= 1
	if game.inventory[slot_index].item.quantity <= 0 {
		game.inventory[slot_index] = {}
	}
	return true
}

// ─── Tick timed effects (call once per turn) ──────────────────────────────────

tick_timed_effects :: proc(game: ^Game) {
	if game.light_boost_turns > 0 {
		game.light_boost_turns -= 1
		if game.light_boost_turns <= 0 {
			game.light_boost_bonus = 0
			add_message(game, "The lantern oil burns out.", rl.Color{180, 130, 50, 255})
		}
	}
}

// ─── Drop an item from inventory onto the map ────────────────────────────────

drop_item :: proc(game: ^Game, slot_index: int) -> bool {
	if slot_index < 0 || slot_index >= MAX_INVENTORY {return false}
	if !game.inventory[slot_index].occupied {return false}

	slot := &game.inventory[slot_index]

	// Create item on map at player position
	dropped := Item {
		pos       = game.player.pos,
		item_type = slot.item.item_type,
		name      = slot.item.name,
		glyph     = slot.item.glyph,
		color     = slot.item.color,
		picked_up = false,
		quantity  = 1,
	}
	append(&game.items, dropped)

	add_message(
		game,
		fmt.tprintf("You drop a %s.", item_display_name(&slot.item)),
		rl.Color{180, 180, 100, 255},
	)

	// Decrement stack or clear slot
	slot.item.quantity -= 1
	if slot.item.quantity <= 0 {
		slot^ = {}
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

// ─── Spawn items into rooms (data-driven) ─────────────────────────────────────

spawn_items :: proc(game: ^Game) {
	clear(&game.items)

	if len(game.rooms) < 2 {
		// Cave layout: scatter items on random floor tiles
		target := 3 + game.depth
		if target > 10 {target = 10}

		spawned := 0
		for _ in 0 ..< target * 10 {
			if spawned >= target {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			if !is_walkable(game, x, y) {continue}
			pos := Vec2{x, y}
			if pos == game.player.pos {continue}
			t := tile_at(game, x, y)
			if t != nil && t.type == .Descent {continue}
			if enemy_at(game, x, y) != nil {continue}
			if item_at(game, x, y) != nil {continue}

			def := pick_item_def()
			if def != nil {
				append(&game.items, item_make_from_def(def, pos))
				spawned += 1
			}
		}
		fmt.printfln("[items] spawned %v items (cave, depth=%v)", spawned, game.depth)
		return
	}

	room_chance := g_data.items.room_item_chance
	if room_chance <= 0 {room_chance = 50}

	total := 0

	// Skip room 0 (player spawn), iterate remaining rooms
	for i in 1 ..< len(game.rooms) {
		// Percentage chance to place an item in this room
		if rand.int_max(100) >= room_chance {
			continue
		}

		room := game.rooms[i]

		// Pick random floor position inside room
		placed := false
		for _ in 0 ..< 20 {
			ix := rand.int_max(room.x2 - room.x1 - 2) + room.x1 + 1
			iy := rand.int_max(room.y2 - room.y1 - 2) + room.y1 + 1
			pos := Vec2{ix, iy}

			if !is_walkable(game, ix, iy) {continue}
			if pos == game.player.pos {continue}

			t := tile_at(game, ix, iy)
			if t != nil && t.type == .Descent {continue}

			if enemy_at(game, ix, iy) != nil {continue}
			if item_at(game, ix, iy) != nil {continue}

			def := pick_item_def()
			if def != nil {
				append(&game.items, item_make_from_def(def, pos))
				total += 1
			}
			placed = true
			break
		}

		_ = placed
	}

	fmt.printfln(
		"[items] spawned %v items across %v rooms (depth=%v)",
		total,
		len(game.rooms) - 1,
		game.depth,
	)
}

// ─── Equipment: equip / unequip / stat queries ────────────────────────────────

equip_item :: proc(game: ^Game, slot_index: int) -> bool {
	if slot_index < 0 || slot_index >= MAX_INVENTORY {return false}
	if !game.inventory[slot_index].occupied {return false}

	item := &game.inventory[slot_index].item
	if item.equipment_slot == "" {
		add_message(game, "That item cannot be equipped.", rl.Color{180, 180, 180, 255})
		return false
	}

	// Determine which equipment slot
	equip_slot: ^Equipment
	if item.equipment_slot == "weapon" {equip_slot = &game.equipped_weapon} else if item.equipment_slot == "armor" {equip_slot = &game.equipped_armor} else if item.equipment_slot == "helmet" {equip_slot = &game.equipped_helmet} else {
		add_message(game, "Unknown equipment slot.", rl.Color{180, 180, 180, 255})
		return false
	}

	// If slot already occupied, swap: put equipped item back in inventory
	if equip_slot.occupied {
		empty := -1
		for i in 0 ..< MAX_INVENTORY {
			if !game.inventory[i].occupied {empty = i; break}
		}
		if empty < 0 {
			add_message(game, "No inventory space to swap equipment!", rl.Color{255, 100, 100, 255})
			return false
		}
		// Put old equipment back
		game.inventory[empty].occupied = true
		game.inventory[empty].item = equip_slot.item
		game.inventory[empty].item.quantity = 1
		add_message(
			game,
			fmt.tprintf("You unequip the %s.", item_display_name(&equip_slot.item)),
			rl.Color{180, 180, 100, 255},
		)
	}

	// Equip the new item
	equip_slot.occupied = true
	equip_slot.item = item^
	add_message(
		game,
		fmt.tprintf("You equip the %s.", item_display_name(item)),
		rl.Color{100, 200, 255, 255},
	)

	// Remove from inventory
	game.inventory[slot_index] = {}

	return true
}

unequip_slot :: proc(game: ^Game, slot_name: string) -> bool {
	equip_slot: ^Equipment
	if slot_name == "weapon" {equip_slot = &game.equipped_weapon} else if slot_name == "armor" {equip_slot = &game.equipped_armor} else if slot_name == "helmet" {equip_slot = &game.equipped_helmet} else {return false}

	if !equip_slot.occupied {return false}

	// Find empty inventory slot
	empty := -1
	for i in 0 ..< MAX_INVENTORY {
		if !game.inventory[i].occupied {empty = i; break}
	}
	if empty < 0 {
		add_message(game, "Inventory full! Cannot unequip.", rl.Color{255, 100, 100, 255})
		return false
	}

	game.inventory[empty].occupied = true
	game.inventory[empty].item = equip_slot.item
	game.inventory[empty].item.quantity = 1
	add_message(
		game,
		fmt.tprintf("You unequip the %s.", item_display_name(&equip_slot.item)),
		rl.Color{180, 180, 100, 255},
	)
	equip_slot^ = {}
	return true
}

// ─── Effective stat queries (used by combat + fov) ────────────────────────────

effective_attack :: proc(game: ^Game) -> int {
	bonus := 0
	if game.equipped_weapon.occupied {bonus = game.equipped_weapon.item.stat_bonus}
	return game.player.attack + bonus
}

effective_defense :: proc(game: ^Game) -> int {
	if game.equipped_armor.occupied {return game.equipped_armor.item.stat_bonus}
	return 0
}

effective_light_bonus :: proc(game: ^Game) -> int {
	if game.equipped_helmet.occupied {return game.equipped_helmet.item.stat_bonus}
	return 0
}

// ─── Crafting recipes ─────────────────────────────────────────────────────────

Recipe :: struct {
	name:         string,
	material_id:  string,
	material_qty: int,
	result_id:    string, // "" means special (like pickaxe repair)
	is_repair:    bool,
}

RECIPES :: [4]Recipe{
	{ name = "Repair Pickaxe",  material_id = "iron_ore",      material_qty = 3, result_id = "",              is_repair = true },
	{ name = "Copper Shield",   material_id = "copper_ore",    material_qty = 2, result_id = "copper_shield", is_repair = false },
	{ name = "Crystal Torch",   material_id = "crystal_shard", material_qty = 2, result_id = "crystal_torch", is_repair = false },
	{ name = "Golden Amulet",   material_id = "gold_nugget",   material_qty = 1, result_id = "golden_amulet", is_repair = false },
}

// Count how many of a material the player has in inventory
count_material :: proc(game: ^Game, material_id: string) -> int {
	total := 0
	for i in 0 ..< MAX_INVENTORY {
		if game.inventory[i].occupied && game.inventory[i].item.item_type == material_id {
			total += game.inventory[i].item.quantity
		}
	}
	return total
}

// Consume N of a material from inventory
consume_material :: proc(game: ^Game, material_id: string, amount: int) {
	remaining := amount
	for i in 0 ..< MAX_INVENTORY {
		if remaining <= 0 { break }
		if !game.inventory[i].occupied { continue }
		if game.inventory[i].item.item_type != material_id { continue }

		take := min(game.inventory[i].item.quantity, remaining)
		game.inventory[i].item.quantity -= take
		remaining -= take
		if game.inventory[i].item.quantity <= 0 {
			game.inventory[i] = {}
		}
	}
}

try_craft :: proc(game: ^Game, recipe_index: int) {
	if recipe_index < 0 || recipe_index >= len(RECIPES) { return }

	recipes := RECIPES
	recipe := recipes[recipe_index]
	have := count_material(game, recipe.material_id)

	if have < recipe.material_qty {
		add_message(game, fmt.tprintf("Need %d %s (have %d).", recipe.material_qty, recipe.material_id, have), rl.Color{255, 100, 100, 255})
		return
	}

	if recipe.is_repair {
		// Repair pickaxe
		game.pickaxe_durability = game.pickaxe_max_dur
		consume_material(game, recipe.material_id, recipe.material_qty)
		add_message(game, "Pickaxe repaired!", rl.Color{100, 255, 100, 255})
		return
	}

	// Find empty inventory slot for crafted item
	slot_idx := -1
	for i in 0 ..< MAX_INVENTORY {
		if !game.inventory[i].occupied {
			slot_idx = i
			break
		}
	}
	if slot_idx < 0 {
		add_message(game, "Inventory full! Cannot craft.", rl.Color{255, 100, 100, 255})
		return
	}

	def := find_item_def(recipe.result_id)
	if def == nil {
		add_message(game, "Recipe error.", rl.Color{255, 100, 100, 255})
		return
	}

	consume_material(game, recipe.material_id, recipe.material_qty)
	crafted := item_make_from_def(def, Vec2{0, 0})
	crafted.picked_up = true
	game.inventory[slot_idx].occupied = true
	game.inventory[slot_idx].item = crafted
	game.inventory[slot_idx].item.quantity = 1

	add_message(game, fmt.tprintf("Crafted %s!", def.name), rl.Color{100, 255, 100, 255})
}
