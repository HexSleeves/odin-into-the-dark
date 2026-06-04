package main

import eng "./engine"
import "core:fmt"

when CHEATS_ENABLED {
	Cheat_Command :: enum {
		Heal_Full,
		Cure_Statuses,
		Teleport_Descent,
		Depth_Down,
		Depth_Up,
		Depth_Max,
		Add_Vault_Key,
	}

	CHEAT_COMMAND_COUNT :: 7

	cheat_command_label :: proc(command: Cheat_Command) -> cstring {
		switch command {
		case .Heal_Full:
			return cstring("Heal to full")
		case .Cure_Statuses:
			return cstring("Clear poison/burning/frozen/web")
		case .Teleport_Descent:
			return cstring("Teleport to descent")
		case .Depth_Down:
			return cstring("Go up one depth")
		case .Depth_Up:
			return cstring("Go down one depth")
		case .Depth_Max:
			return cstring("Go to final depth")
		case .Add_Vault_Key:
			return cstring("Add vault key")
		}
		return cstring("")
	}

	cheat_open_if_requested :: proc(
		ui_manager: ^UI_Manager,
		game: ^Game,
		im: ^Input_Manager,
	) -> bool {
		if game == nil || im == nil || !action_pressed(im, .Cheat_Menu) {return false}
		ui := ui_manager_state(ui_manager)
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
		for i in 0 ..< MAX_INVENTORY {
			if game.inventory[i].occupied {continue}
			game.inventory[i].occupied = true
			game.inventory[i].item = item_make(content, item_type, game.player.pos)
			game.inventory[i].item.picked_up = true
			game.inventory[i].item.quantity = 1
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
		game.skip_next_turn = false
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
			game.poison_turns = 0
			game.burning_turns = 0
			game.frozen_turns = 0
			game.skip_next_turn = false
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
			cheat_add_item_to_inventory(content, messages, game, "vault_key")
		}
	}

	cheat_command_for_index :: proc(index: int) -> Cheat_Command {
		return cast(Cheat_Command)clamp(index, 0, CHEAT_COMMAND_COUNT - 1)
	}

	update_viewing_cheats :: proc(
		content: ^Content_Manager,
		turns: ^eng.Turn_Manager,
		camera: ^eng.Camera_Manager,
		messages: ^Message_Manager,
		ui_manager: ^UI_Manager,
		game: ^Game,
		im: ^Input_Manager,
	) {
		ui := ui_manager_state(ui_manager)
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

		shortcut_actions := [7]Game_Action {
			.Inv_Slot_1,
			.Inv_Slot_2,
			.Inv_Slot_3,
			.Inv_Slot_4,
			.Inv_Slot_5,
			.Inv_Slot_6,
			.Inv_Slot_7,
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

	render_cheats :: proc(engine: ^eng.Engine, game: ^Game) {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		choice := 0
		if ui != nil {choice = ui.cheat_choice}
		render_draw_rectangle(
			engine,
			0,
			0,
			i32(SCREEN_WIDTH),
			i32(SCREEN_HEIGHT),
			eng.Engine_Color{0, 0, 0, 220},
		)
		title := cstring("CHEAT MENU")
		title_size :: i32(32)
		title_w := render_measure_text(engine, title, title_size)
		render_draw_text(
			engine,
			title,
			(i32(SCREEN_WIDTH) - title_w) / 2,
			120,
			title_size,
			eng.Engine_Color{255, 215, 0, 255},
		)
		help := cstring("Built with -define:CHEATS=true. Press 1-7 or Enter; Esc/Shift+C closes.")
		help_w := render_measure_text(engine, help, 14)
		render_draw_text(
			engine,
			help,
			(i32(SCREEN_WIDTH) - help_w) / 2,
			165,
			14,
			eng.Engine_Color{180, 180, 180, 255},
		)

		start_y :: i32(220)
		line_h :: i32(28)
		for i in 0 ..< CHEAT_COMMAND_COUNT {
			command := cheat_command_for_index(i)
			prefix := ">" if i == choice else " "
			text := fmt.ctprintf("%s %d. %s", prefix, i + 1, cheat_command_label(command))
			color :=
				eng.Engine_Color{255, 220, 100, 255} if i == choice else eng.Engine_Color{220, 220, 220, 255}
			render_draw_text(engine, text, 440, start_y + i32(i) * line_h, 18, color)
		}
	}
} else {
	cheat_open_if_requested :: proc(
		ui_manager: ^UI_Manager,
		game: ^Game,
		im: ^Input_Manager,
	) -> bool {
		_ = ui_manager
		_ = game
		_ = im
		return false
	}

	update_viewing_cheats :: proc(
		content: ^Content_Manager,
		turns: ^eng.Turn_Manager,
		camera: ^eng.Camera_Manager,
		messages: ^Message_Manager,
		ui_manager: ^UI_Manager,
		game: ^Game,
		im: ^Input_Manager,
	) {
		_ = content
		_ = turns
		_ = camera
		_ = messages
		_ = ui_manager
		_ = im
		if game != nil {game.state = .Playing}
	}

	render_cheats :: proc(engine: ^eng.Engine, game: ^Game) {
		_ = engine
		_ = game
	}
}
