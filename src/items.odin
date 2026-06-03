package main

import "core:fmt"
import "core:math/rand"

import eng "./engine"
import rl "vendor:raylib"

// ─── Item factory (data-driven) ───────────────────────────────────────────────

item_make :: proc(content: ^Content_Manager, id: string, pos: Vec2) -> Item {
	def := content_manager_item_def(content, id)
	if def != nil {
		return item_make_from_def(def, pos)
	}
	// Fallback: unknown item
	logger_warnf(.Items, "unknown item id '%s'", id)
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

item_stack_limit :: proc(content: ^Content_Manager, id: string) -> int {
	def := content_manager_item_def(content, id)
	if def != nil && def.stack_limit > 0 {
		return def.stack_limit
	}
	return 1
}

item_is_stackable :: proc(content: ^Content_Manager, id: string) -> bool {
	return item_stack_limit(content, id) > 1
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

pickup_item :: proc(content: ^Content_Manager, messages: ^Message_Manager, game: ^Game) -> bool {
	it := item_at(game, game.player.pos.x, game.player.pos.y)
	if it == nil {
		add_message(messages, game, "Nothing to pick up here.", rl.Color{180, 180, 180, 255})
		return false
	}

	itype := it.item_type
	stack_limit := item_stack_limit(content, itype)

	// Only stackable items can merge into existing stacks
	if item_is_stackable(content, itype) {
		for i in 0 ..< MAX_INVENTORY {
			slot := &game.inventory[i]
			if slot.occupied && slot.item.item_type == itype && slot.item.quantity < stack_limit {
				slot.item.quantity += 1
				it.picked_up = true
				game.items_found += 1
				add_message(
					messages,
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
		add_message(messages, game, "Inventory is full!", rl.Color{255, 100, 100, 255})
		return false
	}

	// Copy item into slot as a new stack of 1 and mark map item as picked up
	game.inventory[slot_idx].occupied = true
	game.inventory[slot_idx].item = it^
	game.inventory[slot_idx].item.quantity = 1
	it.picked_up = true
	game.items_found += 1

	add_message(
		messages,
		game,
		fmt.tprintf("Picked up %s.", item_display_name(it)),
		rl.Color{100, 255, 100, 255},
	)
	return true
}

// ─── Use an item from inventory (data-driven) ────────────────────────────────

use_item :: proc(
	content: ^Content_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	slot_index: int,
	engine: ^eng.Engine = nil,
) -> bool {
	if slot_index < 0 || slot_index >= MAX_INVENTORY {
		return false
	}
	if !game.inventory[slot_index].occupied {
		return false
	}

	itype := game.inventory[slot_index].item.item_type
	def := content_manager_item_def(content, itype)
	if def != nil {
		// Equip-type items are not consumed on use; hint the player instead
		if def.effect.type == "equip" {
			add_message(
				messages,
				game,
				fmt.tprintf("Press E in inventory to equip the %s.", def.name),
				rl.Color{180, 180, 180, 255},
			)
			return false
		}
		// Material items cannot be consumed directly
		if def.effect.type == "material" {
			add_message(
				messages,
				game,
				"Raw materials cannot be used directly. Find an anvil to craft.",
				rl.Color{180, 180, 100, 255},
			)
			return false
		}
		apply_item_effect(messages, game, def)
		if engine != nil {
			cam := game_engine_camera_manager(engine)
			particles := game_engine_particle_manager(engine)
			if def.effect.type == "heal" || def.effect.type == "timed_light_boost" {
				spawn_pickup_particles(
					particles,
					game.player.pos.x, game.player.pos.y,
					game_camera_x(cam), game_camera_y(cam),
				)
			}
		}
	} else {
		add_message(messages, game, "Nothing happens.", rl.Color{180, 180, 180, 255})
	}

	// Decrement stack quantity; clear slot only when empty
	game.inventory[slot_index].item.quantity -= 1
	if game.inventory[slot_index].item.quantity <= 0 {
		game.inventory[slot_index] = {}
	}
	return true
}

// ─── Tick timed effects (call once per turn) ──────────────────────────────────

tick_timed_effects :: proc(messages: ^Message_Manager, game: ^Game) {
	if game.light_boost_turns > 0 {
		game.light_boost_turns -= 1
		if game.light_boost_turns <= 0 {
			game.light_boost_bonus = 0
			add_message(messages, game, "The lantern oil burns out.", rl.Color{180, 130, 50, 255})
		}
	}

	if game.poison_turns > 0 {
		game.poison_turns -= 1
		game.player.hp -= 1
		add_message(messages, game, "Poison damages you! (-1 HP)", rl.Color{120, 200, 40, 255})
		if game.player.hp <= 0 {
			game.death_cause = "Died from poison"
			game.state = .Game_Over
			add_message(messages, game, "You have been slain...", rl.Color{255, 0, 0, 255})
		}
	}
}

// ─── Drop an item from inventory onto the map ────────────────────────────────

drop_item :: proc(messages: ^Message_Manager, game: ^Game, slot_index: int) -> bool {
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
		messages,
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

render_items :: proc(engine: ^eng.Engine, game: ^Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	ox := i32(game_camera_x(camera))
	oy := i32(game_camera_y(camera))

	for &item in game.items {
		if item.picked_up {continue}

		// Only render items on visible tiles
		if !tile_visible_at(game, item.pos.x, item.pos.y) {continue}

		ix := i32(item.pos.x * TILE_SIZE) - ox
		iy := i32(item.pos.y * TILE_SIZE) - oy

		if ui.use_sprites {
			spr := sprite_manager_item(sprites, item.item_type)
			sprite_manager_draw(engine, sprites, spr, ix, iy, item.color)
		} else {
			font_size :: i32(TILE_SIZE)
			glyph_buf: [2]u8
			glyph_buf[0] = u8(item.glyph)
			glyph_buf[1] = 0
			glyph_cstr := cast(cstring)&glyph_buf[0]
			render_draw_text(engine, glyph_cstr, ix, iy, font_size, item.color)
		}
	}
}

// ─── Spawn items into rooms (data-driven) ─────────────────────────────────────

spawn_items :: proc(content: ^Content_Manager, game: ^Game) {
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

			def := content_manager_pick_item_def(content)
			if def != nil {
				append(&game.items, item_make_from_def(def, pos))
				spawned += 1
			}
		}
		logger_debugf(.Items, "spawned %v items (cave, depth=%v)", spawned, game.depth)
		return
	}

	room_chance := content_manager_room_item_chance(content)
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

			def := content_manager_pick_item_def(content)
			if def != nil {
				append(&game.items, item_make_from_def(def, pos))
				total += 1
			}
			placed = true
			break
		}

		_ = placed
	}

	logger_debugf(
		.Items,
		"spawned %v items across %v rooms (depth=%v)",
		total,
		len(game.rooms) - 1,
		game.depth,
	)
}
