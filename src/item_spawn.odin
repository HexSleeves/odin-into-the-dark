package main

import "core:math/rand"


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
			pos := Vec2{x, y}
			if !can_place_item(game, x, y) {continue}

			def := content_manager_pick_item_def_for_depth(content, game.depth)
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

			if !can_place_item(game, ix, iy) {continue}

			def := content_manager_pick_item_def_for_depth(content, game.depth)
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
// ─── Remove item from inventory by type ──────────────────────────────────────
