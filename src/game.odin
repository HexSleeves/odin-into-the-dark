package main

import "core:math/rand"
import "core:time"
import eng "./engine"

// ─── Game initialization ─────────────────────────────────────────────────────

game_init :: proc(content: ^Content_Manager) -> ^Game {
	// Derive seed from current time
	seed := u64(time.time_to_unix_nano(time.now()))

	logger_debugf(.Init, "seed = %v", seed)

	// Initialize RNG (used later by proc-gen in S02; seeded now for R014)
	rand.reset(seed)

	// Allocate on heap — Game struct is ~112KB with fixed-size arrays
	game := new(Game)

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.state = .Title_Screen

	// Player defaults from data (position set by generate_map)
	init_player_from_content(content, game)

	// Initialize dynamic collections before generate_map uses them
	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]Light_Source)

	// Procedurally generate the mine floor (sets player pos, descent, rooms)
	generate_map(content, game)

	// Give the player starting equipment
	give_starter_gear(content, game)

	return game
}

// ─── Reinitialize in place (for restart) ─────────────────────────────────────

game_reinit :: proc(content: ^Content_Manager, messages: ^Message_Manager, game: ^Game) {
	seed := u64(time.time_to_unix_nano(time.now()))
	logger_debugf(.Init, "seed = %v", seed)
	rand.reset(seed)

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.state = .Playing

	init_player_from_content(content, game)

	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]Light_Source)

	clear_messages(messages)

	generate_map(content, game)

	// Give the player starting equipment
	give_starter_gear(content, game)
}

// ─── Initialize player from data ─────────────────────────────────────────────

init_player_from_content :: proc(content: ^Content_Manager, game: ^Game) {
	p := content_manager_player_def(content)
	p_glyph: rune = '@'
	if len(p.glyph) > 0 {p_glyph = rune(p.glyph[0])}
	game.player = Player {
		pos          = Vec2{0, 0},
		hp           = p.hp,
		max_hp       = p.hp,
		attack       = p.attack,
		light_radius = p.light_radius,
		glyph        = p_glyph,
		color        = json5_color_to_rl(p.color),
	}
}

// ─── Camera ───────────────────────────────────────────────────────────────

game_camera_update :: proc(camera: ^eng.Camera_Manager, game: ^Game, snap: bool = false) {
	if camera == nil || game == nil {
		return
	}
	eng.camera_manager_update(
		camera,
		game.player.pos.x * TILE_SIZE + TILE_SIZE / 2,
		game.player.pos.y * TILE_SIZE + TILE_SIZE / 2,
		SCREEN_WIDTH,
		MAP_VIEW_HEIGHT,
		MAP_WIDTH * TILE_SIZE,
		MAP_HEIGHT * TILE_SIZE,
		snap,
	)
}

game_camera_x :: proc(camera: ^eng.Camera_Manager) -> int {
	if camera == nil {
		return 0
	}
	return camera.x
}

game_camera_y :: proc(camera: ^eng.Camera_Manager) -> int {
	if camera == nil {
		return 0
	}
	return camera.y
}

// ─── Cleanup ──────────────────────────────────────────────────────────────────

// Release dynamic allocations (rooms, enemies, light_sources)
game_cleanup :: proc(game: ^Game) {
	delete(game.rooms)
	delete(game.enemies)
	delete(game.items)
	delete(game.light_sources)
}

// Full destroy — cleanup + free heap allocation
game_destroy :: proc(game: ^Game) {
	game_cleanup(game)
	free(game)
}
