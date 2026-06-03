#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
content_handlers_accept_content_manager_context :: proc(t: ^testing.T) {
	game_init_handler: proc(content: ^Content_Manager) -> ^Game = game_init
	game_reinit_handler: proc(content: ^Content_Manager, messages: ^Message_Manager, game: ^Game) =
		game_reinit
	player_init_handler: proc(content: ^Content_Manager, game: ^Game) = init_player_from_content
	starter_gear_handler: proc(content: ^Content_Manager, game: ^Game) = give_starter_gear
	restart_handler: proc(
			content: ^Content_Manager,
			turns: ^eng.Turn_Manager,
			camera: ^eng.Camera_Manager,
			vfx: ^eng.Vfx_Manager,
			ui: ^UI_Manager,
			messages: ^Message_Manager,
			game: ^Game,
		) =
		restart_game
	descend_handler: proc(
			content: ^Content_Manager,
			camera: ^eng.Camera_Manager,
			messages: ^Message_Manager,
			game: ^Game,
		) =
		descend
	advance_handler: proc(
			turns: ^eng.Turn_Manager,
			camera: ^eng.Camera_Manager,
			vfx: ^eng.Vfx_Manager,
			messages: ^Message_Manager,
			game: ^Game,
			hp_before: int,
			particles: ^eng.Particle_Manager,
		) =
		advance_turn
	map_handler: proc(content: ^Content_Manager, game: ^Game) = generate_map
	enemy_spawn_handler: proc(content: ^Content_Manager, game: ^Game) = spawn_enemies
	item_spawn_handler: proc(content: ^Content_Manager, game: ^Game) = spawn_items
	enemy_make_handler: proc(content: ^Content_Manager, id: string, pos: Vec2) -> Enemy =
		enemy_make
	item_make_handler: proc(content: ^Content_Manager, id: string, pos: Vec2) -> Item = item_make
	item_stack_handler: proc(content: ^Content_Manager, id: string) -> int = item_stack_limit
	use_item_handler: proc(
			content: ^Content_Manager,
			messages: ^Message_Manager,
			game: ^Game,
			slot_index: int,
			engine: ^eng.Engine,
		) -> bool =
		use_item
	mine_handler: proc(
			content: ^Content_Manager,
			messages: ^Message_Manager,
			game: ^Game,
			dx, dy: int,
		) -> bool =
		mine_wall
	craft_handler: proc(
			content: ^Content_Manager,
			messages: ^Message_Manager,
			game: ^Game,
			recipe_index: int,
		) =
		try_craft

	testing.expect(t, game_init_handler != nil)
	testing.expect(t, game_reinit_handler != nil)
	testing.expect(t, player_init_handler != nil)
	testing.expect(t, starter_gear_handler != nil)
	testing.expect(t, restart_handler != nil)
	testing.expect(t, descend_handler != nil)
	testing.expect(t, advance_handler != nil)
	testing.expect(t, map_handler != nil)
	testing.expect(t, enemy_spawn_handler != nil)
	testing.expect(t, item_spawn_handler != nil)
	testing.expect(t, enemy_make_handler != nil)
	testing.expect(t, item_make_handler != nil)
	testing.expect(t, item_stack_handler != nil)
	testing.expect(t, use_item_handler != nil)
	testing.expect(t, mine_handler != nil)
	testing.expect(t, craft_handler != nil)
}