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

// ─── Input handling ───────────────────────────────────────────────────────────

handle_input :: proc(game: ^Game) -> Input_Result {
	// Escape to quit
	if rl.IsKeyPressed(.ESCAPE) {
		return .Quit
	}

	// Period key: wait / skip turn
	if rl.IsKeyPressed(.PERIOD) {
		game.turn_count += 1
		add_message(game, "You wait...", rl.Color{180, 180, 180, 255})
		return .Waited
	}

	// Direction delta from WASD + arrow keys
	dx, dy: int

	// Up
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		dy = -1
	}
	// Down
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		dy = 1
	}
	// Left
	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
		dx = -1
	}
	// Right
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
		dx = 1
	}

	// No movement key pressed
	if dx == 0 && dy == 0 {
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
	game.depth += 1

	// Reduce light radius with depth (min 3)
	game.player.light_radius = max(8 - game.depth + 1, 3)

	// Regenerate the map (clears tiles, places rooms, spawns enemies)
	generate_map(game)

	// Recompute FOV for new floor
	compute_fov(game)

	add_message(
		game,
		fmt.tprintf("You descend to depth %d...", game.depth),
		rl.Color{0, 200, 200, 255},
	)
}
