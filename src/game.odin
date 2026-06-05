package main

import eng "./engine"
import "core:math/rand"
import "core:time"

// ─── Game initialization ─────────────────────────────────────────────────────

game_next_seed :: proc() -> u64 {
	if FIXED_SEED > 0 {
		return u64(FIXED_SEED)
	}
	return u64(time.time_to_unix_nano(time.now()))
}

game_initial_state :: proc() -> Game_State {
	when SKIP_TITLE {
		return .Playing
	} else {
		return .Title_Screen
	}
}

game_init :: proc(content: ^Content_Manager) -> ^Game {
	seed := game_next_seed()

	logger_debugf(.Init, "seed = %v", seed)

	// Initialize RNG (used later by proc-gen in S02; seeded now for R014)
	rand.reset(seed)

	// Allocate on heap — Game struct is ~112KB with fixed-size arrays
	game := new(Game)

	game.seed = seed
	game_init_world(game)
	game.depth = 1
	game.state = game_initial_state()

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
	seed := game_next_seed()
	logger_debugf(.Init, "seed = %v", seed)
	rand.reset(seed)

	game.seed = seed
	game_init_world(game)
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

game_init_world :: proc(game: ^Game) {
	if game == nil {
		return
	}
	game.world = eng.world_manager_make(MAP_WIDTH, MAP_HEIGHT, TILE_SIZE)
	game.web_tiles = eng.bool_grid_manager_make(eng.world_manager_grid(game.world))
	game.tile_states = eng.tile_state_manager_make(eng.world_manager_grid(game.world))
	game.map_width = eng.world_manager_width(game.world)
	game.map_height = eng.world_manager_height(game.world)
}

// ─── Initialize player from data ─────────────────────────────────────────────

init_player_from_content :: proc(content: ^Content_Manager, game: ^Game) {
	p := content_manager_player_def(content)
	p_glyph: rune = '@'
	if len(p.glyph) > 0 {p_glyph = rune(p.glyph[0])}
	qn := 100 if p.quickness == 0 else p.quickness
	ms := 100 if p.move_speed == 0 else p.move_speed
	game.player = Player {
		pos          = Vec2{0, 0},
		hp           = p.hp,
		max_hp       = p.hp,
		attack       = p.attack,
		light_radius = p.light_radius,
		glyph        = p_glyph,
		color        = json5_color_to_engine(p.color),
		quickness    = qn,
		move_speed   = ms,
		energy       = qn * 10, // start ready to act (one full round of AP)
	}
}

// ─── Camera ───────────────────────────────────────────────────────────────
game_has_live_boss :: proc(game: ^Game) -> bool {
	if game == nil {
		return false
	}
	for &enemy in game.enemies {
		if enemy.alive && enemy.is_boss {
			return true
		}
	}
	return false
}


game_camera_update :: proc(camera: ^eng.Camera_Manager, game: ^Game, snap: bool = false) {
	if camera == nil || game == nil {
		return
	}
	zoom := f32(1.12) if game_has_live_boss(game) else f32(1)
	eng.camera_manager_set_zoom(camera, zoom)
	eng.camera_manager_update(
		camera,
		game.player.pos.x * TILE_SIZE + TILE_SIZE / 2,
		game.player.pos.y * TILE_SIZE + TILE_SIZE / 2,
		MAP_VIEW_WIDTH,
		MAP_VIEW_HEIGHT,
		eng.world_manager_pixel_width(game.world),
		eng.world_manager_pixel_height(game.world),
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
