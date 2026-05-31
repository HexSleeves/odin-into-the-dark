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

// ─── Game initialization ─────────────────────────────────────────────────────

game_init :: proc() -> ^Game {
	// Derive seed from current time
	seed := u64(time.time_to_unix_nano(time.now()))

	fmt.printfln("[init] seed = %v", seed)

	// Initialize RNG (used later by proc-gen in S02; seeded now for R014)
	rand.reset(seed)

	// Allocate on heap — Game struct is ~112KB with fixed-size arrays
	game := new(Game)

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.turn_count = 0
	game.state = .Playing

	// Player defaults (position set by generate_map)
	game.player = Player {
		pos          = Vec2{0, 0},
		hp           = 20,
		max_hp       = 20,
		attack       = 5,
		light_radius = 8,
		glyph        = '@',
		color        = rl.YELLOW,
	}

	// Initialize dynamic collections before generate_map uses them
	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.light_sources = make([dynamic]Light_Source)

	// Procedurally generate the mine floor (sets player pos, descent, rooms)
	generate_map(game)

	return game
}

// ─── Reinitialize in place (for restart) ─────────────────────────────────────

game_reinit :: proc(game: ^Game) {
	seed := u64(time.time_to_unix_nano(time.now()))
	fmt.printfln("[init] seed = %v", seed)
	rand.reset(seed)

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.turn_count = 0
	game.state = .Playing

	game.player = Player {
		pos          = Vec2{0, 0},
		hp           = 20,
		max_hp       = 20,
		attack       = 5,
		light_radius = 8,
		glyph        = '@',
		color        = rl.YELLOW,
	}

	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.light_sources = make([dynamic]Light_Source)

	clear_messages(game)

	generate_map(game)
}

// ─── Cleanup ──────────────────────────────────────────────────────────────────

// Release dynamic allocations (rooms, enemies, light_sources)
game_cleanup :: proc(game: ^Game) {
	delete(game.rooms)
	delete(game.enemies)
	delete(game.light_sources)
}

// Full destroy — cleanup + free heap allocation
game_destroy :: proc(game: ^Game) {
	game_cleanup(game)
	free(game)
}
