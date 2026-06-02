package main

import "core:math/rand"
import "core:time"

// ─── Game initialization ─────────────────────────────────────────────────────

game_init :: proc() -> ^Game {
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
	game.turn_count = 0
	game.state = .Title_Screen
	game.ui.use_sprites = g_sprites.loaded
	game.ui.inspect_slot = -1
	game.ui.title_choice = 0

	// Player defaults from data (position set by generate_map)
	init_player_from_data(game)

	// Initialize dynamic collections before generate_map uses them
	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]Light_Source)

	input_manager_init(&game.input)

	// Procedurally generate the mine floor (sets player pos, descent, rooms)
	generate_map(game)

	// Give the player starting equipment
	give_starter_gear(game)

	return game
}

// ─── Reinitialize in place (for restart) ─────────────────────────────────────

game_reinit :: proc(game: ^Game) {
	seed := u64(time.time_to_unix_nano(time.now()))
	logger_debugf(.Init, "seed = %v", seed)
	rand.reset(seed)

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.turn_count = 0
	game.state = .Playing
	game.ui.use_sprites = g_sprites.loaded
	game.ui.inspect_slot = -1

	init_player_from_data(game)

	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]Light_Source)

	clear_messages(game)

	input_manager_init(&game.input)

	generate_map(game)

	// Give the player starting equipment
	give_starter_gear(game)
}

// ─── Initialize player from data ─────────────────────────────────────────────

init_player_from_data :: proc(game: ^Game) {
	p := &g_data.player
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

// Centers the viewport on the player, clamped to map edges.
// snap=true jumps instantly (use on init/restart); snap=false lerps smoothly.
camera_update :: proc(game: ^Game, snap: bool = false) {
	// Player pixel center
	px := game.player.pos.x * TILE_SIZE + TILE_SIZE / 2
	py := game.player.pos.y * TILE_SIZE + TILE_SIZE / 2

	// Viewport pixel size (map region only, not HUD/messages)
	vw := SCREEN_WIDTH
	vh := MAP_VIEW_HEIGHT

	// Center on player
	cam_x := px - vw / 2
	cam_y := py - vh / 2

	// Clamp so we never show past map edges
	map_pixel_w := MAP_WIDTH * TILE_SIZE
	map_pixel_h := MAP_HEIGHT * TILE_SIZE

	if cam_x < 0 {cam_x = 0}
	if cam_y < 0 {cam_y = 0}
	if cam_x + vw > map_pixel_w {cam_x = map_pixel_w - vw}
	if cam_y + vh > map_pixel_h {cam_y = map_pixel_h - vh}

	// If map is smaller than viewport, center it
	if map_pixel_w < vw {cam_x = -(vw - map_pixel_w) / 2}
	if map_pixel_h < vh {cam_y = -(vh - map_pixel_h) / 2}

	game.camera_target_x = cam_x
	game.camera_target_y = cam_y

	if snap {
		game.camera_x = cam_x
		game.camera_y = cam_y
	} else {
		// Smooth lerp toward target
		LERP_SPEED :: 0.2
		diff_x := cam_x - game.camera_x
		diff_y := cam_y - game.camera_y
		game.camera_x += int(f32(diff_x) * LERP_SPEED)
		game.camera_y += int(f32(diff_y) * LERP_SPEED)
		// Snap if very close to prevent jitter
		if abs(diff_x) <= 1 {game.camera_x = cam_x}
		if abs(diff_y) <= 1 {game.camera_y = cam_y}
	}
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
