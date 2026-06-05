package main

import "core:math/rand"


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
