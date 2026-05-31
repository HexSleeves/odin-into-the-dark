package main

import "core:fmt"
import "core:math/rand"
import "core:time"

import rl "vendor:raylib"

// ─── Map helpers ──────────────────────────────────────────────────────────────

pos_to_idx :: proc(x, y: int) -> int {
	return y * MAP_WIDTH + x
}

idx_to_pos :: proc(idx: int) -> Vec2 {
	return Vec2{idx % MAP_WIDTH, idx / MAP_WIDTH}
}

tile_at :: proc(game: ^Game, x, y: int) -> ^Tile {
	if x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT {
		return nil
	}
	return &game.tiles[pos_to_idx(x, y)]
}

is_walkable :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {
		return false
	}
	#partial switch t.type {
	case .Floor, .Rubble, .Descent:
		return true
	}
	return false
}

// ─── Hardcoded test map ───────────────────────────────────────────────────────

// carve_rect sets all tiles in the rectangle [x1,x2) x [y1,y2) to Floor.
@(private = "file")
carve_rect :: proc(game: ^Game, x1, y1, x2, y2: int) {
	for y in y1 ..< y2 {
		for x in x1 ..< x2 {
			if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
				game.tiles[pos_to_idx(x, y)].type = .Floor
			}
		}
	}
}

// carve_h_corridor sets a 1-tile-high horizontal corridor to Floor.
@(private = "file")
carve_h_corridor :: proc(game: ^Game, x1, x2, y: int) {
	lo := min(x1, x2)
	hi := max(x1, x2)
	for x in lo ..= hi {
		if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
			game.tiles[pos_to_idx(x, y)].type = .Floor
		}
	}
}

@(private = "file")
generate_test_map :: proc(game: ^Game) {
	// All tiles default to Wall (zero-value of Tile_Type).

	// Room 1: 10x8 near center — top-left at (30, 20)
	room1_x1 :: 30
	room1_y1 :: 20
	room1_x2 :: 40 // 30 + 10
	room1_y2 :: 28 // 20 + 8
	carve_rect(game, room1_x1, room1_y1, room1_x2, room1_y2)

	// Room 2: 6x5 offset to the right — top-left at (50, 21)
	room2_x1 :: 50
	room2_y1 :: 21
	room2_x2 :: 56 // 50 + 6
	room2_y2 :: 26 // 21 + 5
	carve_rect(game, room2_x1, room2_y1, room2_x2, room2_y2)

	// Horizontal corridor connecting rooms at y=23
	corridor_y :: 23
	carve_h_corridor(game, room1_x2 - 1, room2_x1, corridor_y)

	// Place a Rubble tile in each room
	game.tiles[pos_to_idx(34, 24)].type = .Rubble // center-ish of room 1
	game.tiles[pos_to_idx(53, 23)].type = .Rubble // center-ish of room 2

	// Place the Descent tile in the second room
	game.tiles[pos_to_idx(52, 24)].type = .Descent
}

// ─── Game initialization ─────────────────────────────────────────────────────

game_init :: proc() -> Game {
	// Derive seed from current time
	seed := u64(time.time_to_unix_nano(time.now()))

	fmt.printfln("[init] seed = %v", seed)

	// Initialize RNG (used later by proc-gen in S02; seeded now for R014)
	rand.reset(seed)

	game: Game

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.turn_count = 0
	game.state = .Playing

	// Build the hardcoded test map (all tiles start as Wall via zero-init)
	generate_test_map(&game)

	// Place player on a floor tile in room 1
	game.player = Player {
		pos          = Vec2{32, 23},
		hp           = 20,
		max_hp       = 20,
		attack       = 5,
		light_radius = 8,
		glyph        = '@',
		color        = rl.YELLOW,
	}

	// Empty dynamic collections (zero-init is fine, but be explicit)
	game.enemies = make([dynamic]Enemy)
	game.light_sources = make([dynamic]Light_Source)

	return game
}

// ─── Cleanup ──────────────────────────────────────────────────────────────────

game_destroy :: proc(game: ^Game) {
	delete(game.enemies)
	delete(game.light_sources)
}
