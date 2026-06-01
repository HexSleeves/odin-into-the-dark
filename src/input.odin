package main

import "core:fmt"

import rl "vendor:raylib"

// ─── Input result ─────────────────────────────────────────────────────────────

Input_Result :: enum {
	None, // no action taken
	Moved, // player moved — turn consumed
	Descended, // player descended to next floor
	Waited, // player skipped a turn (period key)
	Quit, // escape pressed — signal to close
}

// ─── Key repeat for held movement keys ────────────────────────────────────────
// Initial delay before repeat starts, then faster repeat rate.

KEY_REPEAT_DELAY :: f32(0.20)  // seconds before repeat starts
KEY_REPEAT_RATE  :: f32(0.08)  // seconds between repeats

@(private = "file")
move_hold_time: f32 = 0       // how long a movement key has been held
@(private = "file")
move_repeat_timer: f32 = 0    // time until next repeat fires
@(private = "file")
last_move_dx: int = 0
@(private = "file")
last_move_dy: int = 0

// Check if a movement direction should fire this frame (initial press OR held repeat)
@(private = "file")
check_move_direction :: proc() -> (dx, dy: int, fired: bool) {
	dt := rl.GetFrameTime()

	// Read current direction from held keys
	cur_dx, cur_dy: int
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)    { cur_dy = -1 }
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)   { cur_dy = 1 }
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)   { cur_dx = -1 }
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT)  { cur_dx = 1 }

	// Nothing held — reset state
	if cur_dx == 0 && cur_dy == 0 {
		move_hold_time = 0
		move_repeat_timer = 0
		last_move_dx = 0
		last_move_dy = 0
		return 0, 0, false
	}

	// Direction changed — treat as fresh press
	if cur_dx != last_move_dx || cur_dy != last_move_dy {
		last_move_dx = cur_dx
		last_move_dy = cur_dy
		move_hold_time = 0
		move_repeat_timer = 0
		return cur_dx, cur_dy, true  // fire immediately on direction change
	}

	// Same direction held — accumulate time
	move_hold_time += dt

	// First press already fired (hold_time was 0 last frame) — wait for delay
	if move_hold_time < KEY_REPEAT_DELAY {
		return 0, 0, false
	}

	// Past delay — check repeat timer
	move_repeat_timer += dt
	if move_repeat_timer >= KEY_REPEAT_RATE {
		move_repeat_timer -= KEY_REPEAT_RATE
		return cur_dx, cur_dy, true
	}

	return 0, 0, false
}

// ─── Input handling ───────────────────────────────────────────────────────────

handle_input :: proc(game: ^Game) -> Input_Result {
	// Escape to quit
	if rl.IsKeyPressed(.ESCAPE) {
		return .Quit
	}

	// Period key: wait / skip turn (no repeat)
	if rl.IsKeyPressed(.PERIOD) {
		game.turn_count += 1
		add_message(game, "You wait...", rl.Color{180, 180, 180, 255})
		return .Waited
	}

	// Direction with key repeat support
	dx, dy, has_input := check_move_direction()

	// No movement input this frame
	if !has_input {
		return .None
	}

	// Compute target position
	target_x := game.player.pos.x + dx
	target_y := game.player.pos.y + dy

	// Wall collision check
	if !is_walkable(game, target_x, target_y) {
		return .None
	}

	// Check for enemy at target — bump to attack
	target_enemy := enemy_at(game, target_x, target_y)
	if target_enemy != nil {
		resolve_attack_player_on_enemy(game, target_enemy)
		game.turn_count += 1
		return .Moved // attack consumes a turn
	}

	// Move player and consume a turn
	game.player.pos.x = target_x
	game.player.pos.y = target_y
	game.turn_count += 1

	// Check if player stepped on Descent tile
	t := tile_at(game, target_x, target_y)
	if t != nil && t.type == .Descent {
		descend(game)
		return .Descended
	}

	return .Moved
}

// ─── Descent to next floor ───────────────────────────────────────────────────

descend :: proc(game: ^Game) {
	// Victory condition: escaping from depth 12
	if game.depth >= 12 {
		game.state = .Victory
		return
	}

	game.depth += 1

	// Reduce light radius with depth (min 2 at depth 8+, min 3 otherwise)
	min_light := 3
	if game.depth >= 8 {min_light = 2}
	game.player.light_radius = max(g_data.player.light_radius - game.depth + 1, min_light)

	// Regenerate the map (clears tiles, web_tiles, rooms, spawns enemies)
	generate_map(game)

	// Recompute FOV and camera for new floor
	compute_fov(game)
	camera_update(game)

	add_message(
		game,
		fmt.tprintf("You descend to depth %d...", game.depth),
		rl.Color{0, 200, 200, 255},
	)
}
