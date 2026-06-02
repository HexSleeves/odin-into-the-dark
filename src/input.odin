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

// ─── Per-state update handlers ────────────────────────────────────────────────

@(private = "file")
death_sound_played: bool

TITLE_OPTION_COUNT :: 5
TITLE_NEW_GAME :: 0
TITLE_CONTINUE :: 1
TITLE_HIGH_SCORES :: 2
TITLE_HELP :: 3
TITLE_QUIT :: 4

update_title_screen :: proc(game: ^Game) -> (quit: bool) {
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		game.ui.title_choice = (game.ui.title_choice + TITLE_OPTION_COUNT - 1) % TITLE_OPTION_COUNT
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		game.ui.title_choice = (game.ui.title_choice + 1) % TITLE_OPTION_COUNT
	}

	if rl.IsKeyPressed(.N) {
		game.ui.title_choice = TITLE_NEW_GAME
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.C) {
		game.ui.title_choice = TITLE_CONTINUE
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.H) {
		game.ui.title_choice = TITLE_HIGH_SCORES
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.SLASH) && (rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)) {
		game.ui.title_choice = TITLE_HELP
		return activate_title_choice(game)
	}
	if rl.IsKeyPressed(.Q) || rl.IsKeyPressed(.ESCAPE) {
		return true
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		return activate_title_choice(game)
	}

	return false
}

activate_title_choice :: proc(game: ^Game) -> (quit: bool) {
	switch game.ui.title_choice {
	case TITLE_NEW_GAME:
		death_sound_played = false
		restart_game(game)
	case TITLE_CONTINUE:
		if save_exists() {
			if load_game(game) {
				death_sound_played = false
			} else {
				add_message(game, "Save file could not be loaded.", rl.Color{255, 180, 50, 255})
			}
		}
	case TITLE_HIGH_SCORES:
		game.state = .Viewing_Scores
	case TITLE_HELP:
		game.ui.return_to_title = true
		game.state = .Viewing_Help
	case TITLE_QUIT:
		return true
	}
	return false
}

handle_global_input :: proc(game: ^Game) {
	if rl.IsKeyPressed(.F9) {
		if load_game(game) {
			death_sound_played = false
		} else {
			add_message(game, "No save file found.", rl.Color{255, 180, 50, 255})
		}
	}
}

update_playing :: proc(game: ^Game) -> (quit: bool) {
	if handle_forced_turn(game) {return}
	if handle_mining_input(game) {return}
	if handle_playing_hotkeys(game) {return}
	return handle_player_action(game)
}

update_game_over :: proc(game: ^Game) -> (quit: bool) {
	if !death_sound_played {
		play_sfx(.Death)
		spawn_death_particles(game.player.pos.x, game.player.pos.y, game.camera_x, game.camera_y)
		death_sound_played = true
	}
	if !game.score_saved {
		save_run_score(game)
	}
	if rl.IsKeyPressed(.R) {
		death_sound_played = false
		restart_game(game)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		return true
	}
	return
}

update_victory :: proc(game: ^Game) -> (quit: bool) {
	if !game.score_saved {
		game.death_cause = "Victory!"
		save_run_score(game)
	}
	if rl.IsKeyPressed(.R) {
		restart_game(game)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		return true
	}
	return
}

update_viewing_inventory :: proc(game: ^Game) {
	// I or Escape closes inventory (reset drop/equip mode)
	if rl.IsKeyPressed(.I) || rl.IsKeyPressed(.ESCAPE) {
		game.state = .Playing
		game.ui.dropping = false
		game.ui.equipping = false
		game.ui.inspect_slot = -1
	}
	// Up/Down arrows to move inspect cursor (0-8 = inventory, 9/10/11 = weapon/armor/helmet)
	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		game.ui.inspect_slot = max(game.ui.inspect_slot - 1, 0)
	}
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		game.ui.inspect_slot = min(game.ui.inspect_slot + 1, MAX_INVENTORY + 2)
	}
	// D key toggles drop mode
	if rl.IsKeyPressed(.D) {
		game.ui.dropping = !game.ui.dropping
		game.ui.equipping = false
	}
	// E key toggles equip mode
	if rl.IsKeyPressed(.E) {
		game.ui.equipping = !game.ui.equipping
		game.ui.dropping = false
	}
	// Number keys 1-9 to use, drop, or equip items
	keys := [9]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE}
	for key, idx in keys {
		if rl.IsKeyPressed(key) {
			if game.ui.dropping {
				drop_item(game, idx)
				game.ui.dropping = false
			} else if game.ui.equipping {
				equip_item(game, idx)
				game.ui.equipping = false
			} else {
				use_item(game, idx)
			}
		}
	}
}

update_viewing_crafting :: proc(game: ^Game) {
	// ESC or C closes crafting
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.C) {
		game.state = .Playing
	}
	// Number keys 1-4 to craft
	if rl.IsKeyPressed(.ONE) {try_craft(game, 0)}
	if rl.IsKeyPressed(.TWO) {try_craft(game, 1)}
	if rl.IsKeyPressed(.THREE) {try_craft(game, 2)}
	if rl.IsKeyPressed(.FOUR) {try_craft(game, 3)}
}

update_viewing_help :: proc(game: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.SLASH) {
		if game.ui.return_to_title {
			game.ui.return_to_title = false
			game.state = .Title_Screen
		} else {
			game.state = .Playing
		}
	}
}

update_viewing_scores :: proc(game: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.H) {
		game.state = .Title_Screen
	}
}
