package gameplay

import gcore "../core"
import eng "../engine"
import "base:runtime"
import "core:math/rand"
import "core:time"

// ─── Build flags ──────────────────────────────────────────────────────────────
FIXED_SEED :: #config(FIXED_SEED, 0)
SKIP_TITLE :: #config(SKIP_TITLE, false)
// Sprites disabled until sprite mapping is redone.
DEFAULT_USE_SPRITES :: false
NO_SPRITES :: #config(NO_SPRITES, false)

// ─── Seed ─────────────────────────────────────────────────────────────────────

game_next_seed :: proc() -> u64 {
	if FIXED_SEED > 0 {
		return u64(FIXED_SEED)
	}
	return u64(time.time_to_unix_nano(time.now()))
}

game_initial_state :: proc() -> gcore.Game_State {
	when SKIP_TITLE {
		return .Playing
	} else {
		return .Title_Screen
	}
}

// ─── Init ─────────────────────────────────────────────────────────────────────

game_init :: proc(content: ^Content_Manager) -> ^Game {
	seed := game_next_seed()
	logger_debugf(.Init, "seed = %v", seed)
	rand.reset(seed)

	game := new(Game)
	game.seed = seed
	gcore.game_init_world(game)
	game.depth = SURFACE_DEPTH
	game.state = game_initial_state()

	init_player_from_content(content, game)

	game.rooms = make([dynamic]gcore.Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]gcore.Light_Source)

	// Only generate the world when skipping the title screen.
	// Otherwise New Game / Continue triggers restart_game or save_manager_load_game.
	if game.state == .Playing {
		generate_map(content, game)
		give_starter_gear(content, game)
	}

	return game
}

// ─── Reinitialize in place (for restart) ─────────────────────────────────────

game_reinit :: proc(content: ^Content_Manager, messages: ^Message_Manager, game: ^Game) {
	// This proc runs inside the engine update callback, which sets
	// context.allocator to a per-frame arena. Dynamic arrays allocated
	// from the frame arena would be freed next frame. Force the heap
	// allocator for all persistent allocations.
	old_context := context
	defer {
		context = old_context
	}
	context.allocator = runtime.default_allocator()

	seed := game_next_seed()
	logger_debugf(.Init, "seed = %v", seed)
	rand.reset(seed)

	game.seed = seed
	gcore.game_init_world(game)
	game.depth = SURFACE_DEPTH
	game.state = .Playing

	init_player_from_content(content, game)

	game.rooms = make([dynamic]gcore.Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]gcore.Light_Source)

	clear_messages(messages)
	generate_map(content, game)
	give_starter_gear(content, game)
}

// ─── Player from data ─────────────────────────────────────────────────────────

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
		color        = gcore.json5_color_to_engine(p.color),
		quickness    = qn,
		move_speed   = ms,
		energy       = qn * 10,
	}
}

// ─── Camera helper ────────────────────────────────────────────────────────────

game_has_live_boss :: proc(game: ^Game) -> bool {
	if game == nil {return false}
	for &enemy in game.enemies {
		if enemy.alive && enemy.is_boss {return true}
	}
	return false
}

// ─── Cleanup ──────────────────────────────────────────────────────────────────

game_cleanup :: proc(game: ^Game) {
	clear_visited_floors(game)
	delete(game.rooms)
	delete(game.enemies)
	delete(game.items)
	delete(game.light_sources)
}

game_destroy :: proc(game: ^Game) {
	game_cleanup(game)
	free(game)
}

// ─── Restart ──────────────────────────────────────────────────────────────────

restart_game :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	ui: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
) {
	game_cleanup(game)
	game^ = {}
	eng.turn_manager_reset(turns)
	eng.vfx_manager_reset(vfx)
	ui_manager_reset_for_new_game(ui, DEFAULT_USE_SPRITES)
	game_reinit(content, messages, game)
	compute_fov(game)
	game_camera_update(camera, game, true)
	game.score_saved = false
	game.death_cause = ""
	game.last_score_rank = -1
	add_message(messages, game, "A new journey begins...", eng.Engine_Color{200, 200, 100, 255})
}
