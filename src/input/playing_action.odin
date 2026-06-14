package gameinput

import aipkg "../ai"
import eng "../engine"

Input_Result :: enum {
	None,
	Moved,
	Acted,
	Descended,
	Ascended,
	Waited,
}

read_cardinal_press :: proc(im: ^Input_Manager) -> (dx, dy: int) {
	if action_pressed(im, .Move_North) {dy = -1}
	if action_pressed(im, .Move_South) {dy = 1}
	if action_pressed(im, .Move_East) {dx = 1}
	if action_pressed(im, .Move_West) {dx = -1}
	// Force cardinal: prefer horizontal when both axes are set.
	if dx != 0 && dy != 0 {dy = 0}
	return
}

resolve_attack_player_on_enemy :: aipkg.resolve_attack_player_on_enemy
handle_input :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	im: ^Input_Manager,
	engine: ^eng.Engine = nil,
) -> Input_Result {
	if action_pressed(im, .Wait) {
		game.player.energy -= BASE_ACTION_COST
		add_message(messages, game, "You wait...", eng.Engine_Color{180, 180, 180, 255})
		return .Waited
	}

	fired_n := check_repeat(im, .Move_North)
	fired_s := check_repeat(im, .Move_South)
	fired_e := check_repeat(im, .Move_East)
	fired_w := check_repeat(im, .Move_West)

	dx, dy: int
	if fired_n {dy = -1}
	if fired_s {dy = 1}
	if fired_e {dx = 1}
	if fired_w {dx = -1}
	// Force cardinal: prefer horizontal when both axes are held simultaneously.
	if dx != 0 && dy != 0 {dy = 0}

	if dx == 0 && dy == 0 {
		return .None
	}

	target_x := game.player.pos.x + dx
	target_y := game.player.pos.y + dy

	if !is_walkable(game, target_x, target_y) {
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

	// Walking into an NPC starts dialogue (surface town).
	if npc_idx := npc_at(game, target_x, target_y); npc_idx >= 0 {
		if engine != nil {
			npc_content := game_engine_content_manager(engine)
			npc_msgs := game_engine_message_manager(engine)
			if npc_content != nil && npc_msgs != nil {
				start_conversation(npc_msgs, npc_content, game, npc_idx)
			}
		}
		return .None
	}

	target_enemy := enemy_at(game, target_x, target_y)
	if target_enemy != nil {
		resolve_attack_player_on_enemy(messages, game, target_enemy)
		game.player.energy -= effective_attack_cost(game)
		return .Acted
	}

	t := tile_at(game, target_x, target_y)
	if t != nil && t.type == .Descent && !descend_allowed(game) {
		add_descent_locked_message(messages, game)
		return .None
	}

	game.player.pos.x = target_x
	game.player.pos.y = target_y
	move_cost := BASE_MOVE_COST
	if status_active(&game.player_status, .Frozen) {move_cost *= 2}
	game.player.energy -= move_cost

	if t != nil {
		if t.type == .Descent {
			if descend(content, camera, messages, game) {
				return .Descended
			}
			return .None
		}
		if t.type == .Ascent {
			if ascend(content, camera, messages, game) {
				return .Ascended
			}
		}
	}

	return .Moved
}
