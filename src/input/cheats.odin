package gameinput

import gcore "../core"
import eng "../engine"
import "core:fmt"

@(private = "file")
cheat_import_anchor :: proc() {
	_ = fmt.tprintf
	_ = gcore.CHEATS_ENABLED
}

when CHEATS_ENABLED {
	cheat_open_if_requested :: proc(ui_mgr: ^UI_Manager, game: ^Game, im: ^Input_Manager) -> bool {
		if game == nil || im == nil || !action_pressed(im, .Cheat_Menu) {return false}
		ui := ui_manager_state(ui_mgr)
		if ui != nil {ui.cheat_choice = 0}
		game.state = .Viewing_Cheats
		return true
	}

	cheat_find_descent :: proc(game: ^Game) -> (pos: Vec2, ok: bool) {
		if game == nil {return {}, false}
		for y in 0 ..< MAP_HEIGHT {
			for x in 0 ..< MAP_WIDTH {
				if game.tiles[pos_to_idx(x, y)].type == .Descent {
					return Vec2{x, y}, true
				}
			}
		}
		return {}, false
	}

	cheat_add_item_to_inventory :: proc(
		content: ^Content_Manager,
		messages: ^Message_Manager,
		game: ^Game,
		item_type: string,
	) -> bool {
		if game == nil {return false}
		slot_idx := inventory_first_empty_slot(game)
		if slot_idx >= 0 {
			item := item_make(content, item_type, game.player.pos)
			item.picked_up = true
			inventory_put_slot(game, slot_idx, item, 1)
			add_message(
				messages,
				game,
				fmt.tprintf("Cheat: added %s.", item_type),
				eng.Engine_Color{255, 215, 0, 255},
			)
			return true
		}
		add_message(
			messages,
			game,
			"Cheat: inventory is full.",
			eng.Engine_Color{255, 100, 100, 255},
		)
		return false
	}

	cheat_set_depth :: proc(
		content: ^Content_Manager,
		turns: ^eng.Turn_Manager,
		camera: ^eng.Camera_Manager,
		messages: ^Message_Manager,
		game: ^Game,
		depth: int,
	) {
		_ = turns
		if game == nil {return}
		target := clamp(depth, 1, MAX_DEPTH)
		game.depth = target
		game.light_drain_timer = 0
		game.water_slow_active = false
		game.minimap_reveal_enemies = false
		game.player_status[.Webbed] = 0
		generate_map(content, game)
		compute_fov(game)
		game_camera_update(camera, game, true)
		add_message(
			messages,
			game,
			fmt.tprintf("Cheat: depth %d.", target),
			eng.Engine_Color{255, 215, 0, 255},
		)
	}

	cheat_explore_map :: proc(messages: ^Message_Manager, game: ^Game) {
		if game == nil {return}
		for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
			state := tile_state_at_idx(game, i)
			_ = tile_state_set_idx(game, i, state.visible, true, state.light_level)
		}
		game.minimap_reveal_enemies = true
		add_message(
			messages,
			game,
			"Cheat: map fully explored.",
			eng.Engine_Color{255, 215, 0, 255},
		)
	}

	cheat_apply :: proc(
		content: ^Content_Manager,
		turns: ^eng.Turn_Manager,
		camera: ^eng.Camera_Manager,
		messages: ^Message_Manager,
		game: ^Game,
		command: Cheat_Command,
	) {
		if game == nil {return}
		switch command {
		case .Heal_Full:
			game.player.hp = game.player.max_hp
			add_message(
				messages,
				game,
				"Cheat: healed to full.",
				eng.Engine_Color{100, 255, 100, 255},
			)
		case .Cure_Statuses:
			game.player_status = {}
			add_message(
				messages,
				game,
				"Cheat: statuses cleared.",
				eng.Engine_Color{100, 180, 255, 255},
			)
		case .Teleport_Descent:
			if pos, ok := cheat_find_descent(game); ok {
				game.player.pos = pos
				compute_fov(game)
				game_camera_update(camera, game, true)
				add_message(
					messages,
					game,
					"Cheat: teleported to descent.",
					eng.Engine_Color{255, 215, 0, 255},
				)
			} else {
				add_message(
					messages,
					game,
					"Cheat: no descent tile found.",
					eng.Engine_Color{255, 100, 100, 255},
				)
			}
		case .Depth_Down:
			cheat_set_depth(content, turns, camera, messages, game, game.depth - 1)
		case .Depth_Up:
			cheat_set_depth(content, turns, camera, messages, game, game.depth + 1)
		case .Depth_Max:
			cheat_set_depth(content, turns, camera, messages, game, MAX_DEPTH)
		case .Add_Vault_Key:
			cheat_add_item_to_inventory(content, messages, game, gcore.ITEM_ID_VAULT_KEY)
		case .Explore_Map:
			cheat_explore_map(messages, game)
		}
	}

	update_viewing_cheats :: proc(
		content: ^Content_Manager,
		turns: ^eng.Turn_Manager,
		camera: ^eng.Camera_Manager,
		messages: ^Message_Manager,
		ui_mgr: ^UI_Manager,
		game: ^Game,
		im: ^Input_Manager,
	) {
		ui := ui_manager_state(ui_mgr)
		if action_pressed(im, .Menu_Back) || action_pressed(im, .Cheat_Menu) {
			game.state = .Playing
			return
		}
		if ui == nil {return}
		if action_pressed(im, .Menu_Up) {
			ui.cheat_choice = (ui.cheat_choice + CHEAT_COMMAND_COUNT - 1) % CHEAT_COMMAND_COUNT
		}
		if action_pressed(im, .Menu_Down) {
			ui.cheat_choice = (ui.cheat_choice + 1) % CHEAT_COMMAND_COUNT
		}

		shortcut_actions := [8]Game_Action {
			.Inv_Slot_1,
			.Inv_Slot_2,
			.Inv_Slot_3,
			.Inv_Slot_4,
			.Inv_Slot_5,
			.Inv_Slot_6,
			.Inv_Slot_7,
			.Inv_Slot_8,
		}
		for action, idx in shortcut_actions {
			if action_pressed(im, action) {
				cheat_apply(content, turns, camera, messages, game, cheat_command_for_index(idx))
				game.state = .Playing
				return
			}
		}
		if action_pressed(im, .Menu_Confirm) {
			cheat_apply(
				content,
				turns,
				camera,
				messages,
				game,
				cheat_command_for_index(ui.cheat_choice),
			)
			game.state = .Playing
		}
	}

} else {
	cheat_open_if_requested :: proc(ui_mgr: ^UI_Manager, game: ^Game, im: ^Input_Manager) -> bool {
		_ = ui_mgr
		_ = game
		_ = im
		return false
	}

	update_viewing_cheats :: proc(
		content: ^Content_Manager,
		turns: ^eng.Turn_Manager,
		camera: ^eng.Camera_Manager,
		messages: ^Message_Manager,
		ui_mgr: ^UI_Manager,
		game: ^Game,
		im: ^Input_Manager,
	) {
		_ = content
		_ = turns
		_ = camera
		_ = messages
		_ = ui_mgr
		_ = im
		if game != nil {game.state = .Playing}
	}
}
