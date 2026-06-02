package main

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

KEY_REPEAT_DELAY :: f32(0.20) // seconds before repeat starts
KEY_REPEAT_RATE :: f32(0.08) // seconds between repeats

@(private = "file")
move_hold_time: f32 = 0 // how long a movement key has been held
@(private = "file")
move_repeat_timer: f32 = 0 // time until next repeat fires
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
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {cur_dy = -1}
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {cur_dy = 1}
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {cur_dx = -1}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {cur_dx = 1}

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
		return cur_dx, cur_dy, true // fire immediately on direction change
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


read_cardinal_press :: proc() -> (dx, dy: int) {
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {dy = -1}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {dy = 1}
	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {dx = -1}
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {dx = 1}
	return
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

handle_forced_turn :: proc(game: ^Game) -> bool {
	// Web: skip player's turn if stuck
	if game.skip_next_turn {
		game.skip_next_turn = false
		game.turn_count += 1
		hp_before := game.player.hp
		advance_turn(game, hp_before)
		add_message(game, "You break free from the web.", rl.Color{200, 200, 100, 255})
		return true
	}

	// Water: costs an extra turn
	if game.water_slow_active {
		game.water_slow_active = false
		game.turn_count += 1
		hp_before := game.player.hp
		advance_turn(game, hp_before)
		add_message(game, "You push through the water.", rl.Color{40, 80, 180, 255})
		return true
	}

	return false
}

handle_mining_input :: proc(game: ^Game) -> bool {
	if !game.ui.mining_mode {return false}

	if rl.IsKeyPressed(.ESCAPE) {
		game.ui.mining_mode = false
		add_message(game, "Mining cancelled.", rl.Color{180, 180, 180, 255})
		return true
	}

	mdx, mdy := read_cardinal_press()
	if mdx != 0 || mdy != 0 {
		game.ui.mining_mode = false
		if mine_wall(game, mdx, mdy) {
			play_sfx(.Mine)
			spawn_mine_particles(
				game.player.pos.x + mdx,
				game.player.pos.y + mdy,
				game.camera_x,
				game.camera_y,
			)
			hp_before := game.player.hp
			advance_turn(game, hp_before)
		}
	}

	return true
}

handle_playing_hotkeys :: proc(game: ^Game) -> bool {
	// C key: open crafting if on anvil
	if rl.IsKeyPressed(.C) {
		cur := tile_at(game, game.player.pos.x, game.player.pos.y)
		if cur != nil && cur.type == .Anvil {
			game.state = .Viewing_Crafting
			return true
		}
		add_message(game, "You need to stand on an anvil to craft.", rl.Color{180, 180, 180, 255})
	}

	// X key: enter mining mode
	if rl.IsKeyPressed(.X) {
		start_mining_mode(game)
		return true
	}

	// M key: toggle minimap
	if rl.IsKeyPressed(.M) {
		game.ui.show_minimap = !game.ui.show_minimap
	}

	// F1 key: toggle audio
	if rl.IsKeyPressed(.F1) {
		audio_toggle()
		if g_audio.enabled {
			add_message(game, "Sound: ON", rl.Color{180, 180, 180, 255})
		} else {
			add_message(game, "Sound: OFF", rl.Color{180, 180, 180, 255})
		}
	}

	// F2 key: toggle ASCII / Sprite mode
	if rl.IsKeyPressed(.F2) {
		game.ui.use_sprites = !game.ui.use_sprites
		if game.ui.use_sprites {
			add_message(game, "Render: SPRITES", rl.Color{180, 180, 180, 255})
		} else {
			add_message(game, "Render: ASCII", rl.Color{180, 180, 180, 255})
		}
	}

	// F5 key: save game
	if rl.IsKeyPressed(.F5) {
		if save_game(game) {
			add_message(game, "Game saved.", rl.Color{100, 255, 100, 255})
		} else {
			add_message(game, "Save failed!", rl.Color{255, 100, 100, 255})
		}
	}

	// G key: pick up item (instant, no turn cost)
	if rl.IsKeyPressed(.G) {
		if pickup_item(game) {
			play_sfx(.Pickup)
			spawn_pickup_particles(
				game.player.pos.x,
				game.player.pos.y,
				game.camera_x,
				game.camera_y,
			)
		}
	}

	// I key: open inventory screen
	if rl.IsKeyPressed(.I) {
		game.state = .Viewing_Inventory
		game.ui.inspect_slot = 0
		return true
	}

	// ? key: open help screen
	if (rl.IsKeyPressed(.SLASH) && rl.IsKeyDown(.LEFT_SHIFT)) ||
	   (rl.IsKeyPressed(.SLASH) && rl.IsKeyDown(.RIGHT_SHIFT)) {
		game.ui.return_to_title = false
		game.state = .Viewing_Help
		return true
	}

	return false
}
