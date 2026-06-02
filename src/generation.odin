package main

import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

// ─── Generation constants ─────────────────────────────────────────────────────

MIN_ROOM_W :: 4
MAX_ROOM_W :: 10
MIN_ROOM_H :: 3
MAX_ROOM_H :: 8
MAX_ROOMS :: 12
ROOM_PADDING :: 1

// ─── Room helpers ─────────────────────────────────────────────────────────────

room_center :: proc(r: Room) -> Vec2 {
	return Vec2{(r.x1 + r.x2) / 2, (r.y1 + r.y2) / 2}
}

rooms_overlap :: proc(a, b: Room, padding: int) -> bool {
	if a.x1 - padding >= b.x2 + padding {return false}
	if b.x1 - padding >= a.x2 + padding {return false}
	if a.y1 - padding >= b.y2 + padding {return false}
	if b.y1 - padding >= a.y2 + padding {return false}
	return true
}

// ─── Carving helpers ──────────────────────────────────────────────────────────

carve_rect :: proc(game: ^Game, x1, y1, x2, y2: int) {
	for y in y1 ..< y2 {
		for x in x1 ..< x2 {
			if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
				game.tiles[pos_to_idx(x, y)].type = .Floor
			}
		}
	}
}

carve_h_tunnel :: proc(game: ^Game, x1, x2, y: int) {
	lo := min(x1, x2)
	hi := max(x1, x2)
	for x in lo ..= hi {
		if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
			game.tiles[pos_to_idx(x, y)].type = .Floor
		}
	}
}

carve_v_tunnel :: proc(game: ^Game, y1, y2, x: int) {
	lo := min(y1, y2)
	hi := max(y1, y2)
	for y in lo ..= hi {
		if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
			game.tiles[pos_to_idx(x, y)].type = .Floor
		}
	}
}

// ─── Map generator (depth dispatch) ───────────────────────────────────────────

generate_map :: proc(content: ^Content_Manager, game: ^Game) {
	// Clear tiles
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i] = Tile{}
		game.web_tiles[i] = false
	}

	// Clear rooms and state
	clear(&game.rooms)
	game.skip_next_turn = false

	// Dispatch by depth
	if game.depth <= 2 {
		generate_rooms(game)
	} else if game.depth <= 4 {
		generate_mixed(game)
	} else {
		generate_cave(game)
	}

	// Spawn enemies and items (works for all gen types)
	spawn_enemies(content, game)
	spawn_items(content, game)
	spawn_hazards(game)
	spawn_ore_veins(game)

	// Spawn 1 anvil per floor
	spawn_anvil(game)

	// Spawn boss on milestone depths
	spawn_boss(content, game)

	// Clear hazard state
	game.water_slow_active = false

	// Set depth-based floor palette
	game.palette = palette_for_depth(game.depth)
}

// ─── Room-and-corridor generator ──────────────────────────────────────────────

generate_rooms :: proc(game: ^Game) {
	// (a) Fill all tiles to Wall (already done by generate_map, but ensure it)
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i] = Tile{}
	}

	// (b) Attempt to place rooms
	for _ in 0 ..< MAX_ROOMS {
		w := rand.int_max(MAX_ROOM_W - MIN_ROOM_W + 1) + MIN_ROOM_W
		h := rand.int_max(MAX_ROOM_H - MIN_ROOM_H + 1) + MIN_ROOM_H
		x := rand.int_max(MAP_WIDTH - w - 1) + 1
		y := rand.int_max(MAP_HEIGHT - h - 1) + 1

		new_room := Room{x, y, x + w, y + h}

		overlap := false
		for &existing in game.rooms {
			if rooms_overlap(new_room, existing, ROOM_PADDING) {
				overlap = true
				break
			}
		}

		if !overlap {
			carve_rect(game, new_room.x1, new_room.y1, new_room.x2, new_room.y2)
			append(&game.rooms, new_room)
		}
	}

	// (c) Sort rooms by x1 for left-to-right ordering
	slice.sort_by(game.rooms[:], proc(a, b: Room) -> bool {
		return a.x1 < b.x1
	})

	// (d) Connect consecutive rooms with L-shaped corridors
	for i in 1 ..< len(game.rooms) {
		prev_center := room_center(game.rooms[i - 1])
		curr_center := room_center(game.rooms[i])

		if rand.int_max(2) == 0 {
			carve_h_tunnel(game, prev_center.x, curr_center.x, prev_center.y)
			carve_v_tunnel(game, prev_center.y, curr_center.y, curr_center.x)
		} else {
			carve_v_tunnel(game, prev_center.y, curr_center.y, prev_center.x)
			carve_h_tunnel(game, prev_center.x, curr_center.x, curr_center.y)
		}
	}

	// (e) Place player at center of first room
	if len(game.rooms) > 0 {
		game.player.pos = room_center(game.rooms[0])
	}

	// (f) Place Descent tile at center of last room
	descent_pos := Vec2{0, 0}
	if len(game.rooms) > 0 {
		descent_pos = room_center(game.rooms[len(game.rooms) - 1])
		game.tiles[pos_to_idx(descent_pos.x, descent_pos.y)].type = .Descent
	}

	// (g) Scatter 1-2 Rubble tiles in each room
	for &room in game.rooms {
		rubble_count := rand.int_max(2) + 1
		for _ in 0 ..< rubble_count {
			for _ in 0 ..< 10 {
				rx := rand.int_max(room.x2 - room.x1) + room.x1
				ry := rand.int_max(room.y2 - room.y1) + room.y1
				idx := pos_to_idx(rx, ry)
				if game.tiles[idx].type == .Floor &&
				   !(rx == game.player.pos.x && ry == game.player.pos.y) &&
				   !(rx == descent_pos.x && ry == descent_pos.y) {
					game.tiles[idx].type = .Rubble
					break
				}
			}
		}
	}

	// (h) Diagnostics log
	logger_debugf(
		.Gen,
		"rooms: seed=%v rooms=%v player=(%v,%v) descent=(%v,%v)",
		game.seed,
		len(game.rooms),
		game.player.pos.x,
		game.player.pos.y,
		descent_pos.x,
		descent_pos.y,
	)
}

// ─── Hazard tile spawning (depth-gated) ───────────────────────────────────────

spawn_hazards :: proc(game: ^Game) {
	depth := game.depth

	// Water: depths 1+, 3-6 tiles (15-25 in flooded cavern)
	if depth >= 1 {
		count: int
		if depth >= 6 && depth <= 7 {
			count = rand.int_max(11) + 15
		} else {
			count = rand.int_max(4) + 3
		}
		placed := 0
		for _ in 0 ..< count * 20 {
			if placed >= count {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Floor {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			game.tiles[idx].type = .Water
			placed += 1
		}
	}

	// Gas vents: depths 3+, 2-4 tiles
	if depth >= 3 {
		count := rand.int_max(3) + 2
		placed := 0
		for _ in 0 ..< count * 20 {
			if placed >= count {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Floor {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			game.tiles[idx].type = .Gas_Vent
			placed += 1
		}
	}

	// Unstable ground: depths 5+, 2-3 tiles
	if depth >= 5 {
		count := rand.int_max(2) + 2
		placed := 0
		for _ in 0 ..< count * 20 {
			if placed >= count {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Floor {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			game.tiles[idx].type = .Unstable
			placed += 1
		}
	}

	logger_debugf(.Gen, "hazards spawned (depth=%v)", depth)
}

// ─── Ore vein spawning (depth-gated) ──────────────────────────────────────────

spawn_ore_veins :: proc(game: ^Game) {
	// Clear ore veins
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.ore_veins[i] = {}
	}

	depth := game.depth

	// Define ore colors
	iron_color := rl.Color{200, 120, 50, 255}
	copper_color := rl.Color{80, 180, 80, 255}
	crystal_color := rl.Color{100, 150, 255, 255}
	gold_color := rl.Color{255, 215, 0, 255}

	// Scan all wall tiles, ~10% chance to become ore vein
	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Wall {continue}

			// ~10% chance for wall to be ore
			if rand.int_max(100) >= 10 {continue}

			// Check if wall is adjacent to at least one floor-like tile (accessible)
			has_floor := false
			ADJ_DX :: [4]int{0, 0, -1, 1}
			ADJ_DY :: [4]int{-1, 1, 0, 0}
			adj_dx := ADJ_DX
			adj_dy := ADJ_DY
			for dir in 0 ..< 4 {
				nx := x + adj_dx[dir]
				ny := y + adj_dy[dir]
				if nx >= 0 && nx < MAP_WIDTH && ny >= 0 && ny < MAP_HEIGHT {
					t := game.tiles[pos_to_idx(nx, ny)]
					if t.type == .Floor ||
					   t.type == .Rubble ||
					   t.type == .Descent ||
					   t.type == .Water ||
					   t.type == .Gas_Vent ||
					   t.type == .Unstable {
						has_floor = true
						break
					}
				}
			}
			if !has_floor {continue}

			// Weighted ore type selection by depth
			ore_type: string
			ore_color: rl.Color
			roll := rand.int_max(100)

			if depth >= 8 {
				// iron 10, copper 25, crystal 35, gold 30
				if roll <
				   10 {ore_type = "iron_ore"; ore_color = iron_color} else if roll < 35 {ore_type = "copper_ore"; ore_color = copper_color} else if roll < 70 {ore_type = "crystal_shard"; ore_color = crystal_color} else {ore_type = "gold_nugget"; ore_color = gold_color}
			} else if depth >= 5 {
				// iron 20, copper 40, crystal 40
				if roll <
				   20 {ore_type = "iron_ore"; ore_color = iron_color} else if roll < 60 {ore_type = "copper_ore"; ore_color = copper_color} else {ore_type = "crystal_shard"; ore_color = crystal_color}
			} else if depth >= 3 {
				// iron 40, copper 60
				if roll <
				   40 {ore_type = "iron_ore"; ore_color = iron_color} else {ore_type = "copper_ore"; ore_color = copper_color}
			} else {
				// depth 1-2: only iron
				ore_type = "iron_ore"
				ore_color = iron_color
			}

			game.ore_veins[idx] = Ore_Vein {
				ore_type = ore_type,
				color    = ore_color,
			}
		}
	}

	logger_debugf(.Gen, "ore veins spawned (depth=%v)", depth)
}

// ─── Anvil spawning (one per floor) ───────────────────────────────────────────

spawn_anvil :: proc(game: ^Game) {
	for _ in 0 ..< 200 {
		x := rand.int_max(MAP_WIDTH - 2) + 1
		y := rand.int_max(MAP_HEIGHT - 2) + 1
		idx := pos_to_idx(x, y)
		if game.tiles[idx].type != .Floor {continue}
		pos := Vec2{x, y}
		if pos == game.player.pos {continue}
		if enemy_at(game, x, y) != nil {continue}
		if item_at(game, x, y) != nil {continue}
		game.tiles[idx].type = .Anvil
		logger_debugf(.Gen, "anvil at (%v,%v)", x, y)
		return
	}
}

// ─── Boss spawning (depth-gated) ─────────────────────────────────────────────

spawn_boss :: proc(content: ^Content_Manager, game: ^Game) {
	boss_id: string
	if game.depth == 5 {
		boss_id = "mine_guardian"
	} else if game.depth == 10 {
		boss_id = "abyssal_lord"
	} else {
		return
	}

	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			if game.tiles[pos_to_idx(x, y)].type == .Descent {
				DX :: [4]int{0, 0, -1, 1}
				DY :: [4]int{-1, 1, 0, 0}
				dx := DX
				dy := DY
				for dir in 0 ..< 4 {
					bx := x + dx[dir]
					by := y + dy[dir]
					if is_walkable(game, bx, by) && enemy_at(game, bx, by) == nil {
						def := content_manager_enemy_def(content, boss_id)
						if def != nil {
							boss := enemy_make_from_def(def, Vec2{bx, by})
							boss.is_boss = true
							append(&game.enemies, boss)
							logger_debugf(.Gen, "boss '%s' spawned at (%v,%v)", boss_id, bx, by)
						}
						return
					}
				}
				return
			}
		}
	}
}
