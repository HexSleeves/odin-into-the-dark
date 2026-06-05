package main

import eng "./engine"

// ─── Input result ─────────────────────────────────────────────────────────────

Input_Result :: enum {
	None, // no action taken
	Moved, // player changed tiles — movement side effects apply
	Acted, // non-movement action consumed AP/turn
	Descended, // player descended to next floor
	Waited, // player skipped a turn (period key)
	Quit, // escape pressed — signal to close
}

read_cardinal_press :: proc(im: ^Input_Manager) -> (dx, dy: int) {
	if action_pressed(im, .Move_North) {dy = -1}
	if action_pressed(im, .Move_South) {dy = 1}
	if action_pressed(im, .Move_East) {dx = 1}
	if action_pressed(im, .Move_West) {dx = -1}
	return
}

// ─── Input handling ───────────────────────────────────────────────────────────

handle_input :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	im: ^Input_Manager,
	engine: ^eng.Engine = nil,
) -> Input_Result {
	if action_pressed(im, .Quit) {
		return .Quit
	}

	if action_pressed(im, .Wait) {
		// Deduct AP; trigger_enemy_rounds fires in handle_player_action
		game.player.energy -= BASE_ACTION_COST
		add_message(messages, game, "You wait...", eng.Engine_Color{180, 180, 180, 255})
		return .Waited
	}

	// Four independent repeat states — direction change fires immediately
	fired_n := check_repeat(im, .Move_North)
	fired_s := check_repeat(im, .Move_South)
	fired_e := check_repeat(im, .Move_East)
	fired_w := check_repeat(im, .Move_West)

	dx, dy: int
	if fired_n {dy = -1}
	if fired_s {dy = 1}
	if fired_e {dx = 1}
	if fired_w {dx = -1}

	if dx == 0 && dy == 0 {
		return .None
	}

	target_x := game.player.pos.x + dx
	target_y := game.player.pos.y + dy

	if !is_walkable(game, target_x, target_y) {
		// Check if bumping into a locked door with a key
		t := tile_at(game, target_x, target_y)
		if t != nil && t.type == .Locked_Door {
			if remove_item_from_inventory(game, ITEM_ID_VAULT_KEY) {
				t.type = .Floor
				add_message(
					messages,
					game,
					"You unlock the door with the Vault Key!",
					eng.Engine_Color{255, 215, 0, 255},
				)
				game.player.energy -= BASE_ACTION_COST
				return .Acted
			} else {
				add_message(
					messages,
					game,
					"The door is locked. You need a key.",
					eng.Engine_Color{180, 180, 180, 255},
				)
			}
		}
		return .None
	}

	target_enemy := enemy_at(game, target_x, target_y)
	if target_enemy != nil {
		resolve_attack_player_on_enemy(messages, game, target_enemy)
		// Deduct weapon-specific AP cost; trigger_enemy_rounds fires in handle_player_action
		game.player.energy -= effective_attack_cost(game)
		return .Acted
	}

	game.player.pos.x = target_x
	game.player.pos.y = target_y
	// Deduct move AP (player move_speed is 100 in Phase 1 → cost = BASE_MOVE_COST)
	move_cost := BASE_MOVE_COST
	if game.frozen_turns > 0 {move_cost *= 2}
	game.player.energy -= move_cost

	t := tile_at(game, target_x, target_y)
	if t != nil && t.type == .Descent {
		descend(content, camera, messages, game)
		return .Descended
	}

	return .Moved
}

