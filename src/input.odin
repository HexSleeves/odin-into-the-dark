package main

import rl "vendor:raylib"

// ─── Input result ─────────────────────────────────────────────────────────────

Input_Result :: enum {
	None,        // no action taken
	Moved,       // player moved — turn consumed
	Quit,        // escape pressed — signal to close
}

// ─── Input handling ───────────────────────────────────────────────────────────

handle_input :: proc(game: ^Game) -> Input_Result {
	// Escape to quit
	if rl.IsKeyPressed(.ESCAPE) {
		return .Quit
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

	// Move player and consume a turn
	game.player.pos.x = target_x
	game.player.pos.y = target_y
	game.turn_count += 1

	return .Moved
}
