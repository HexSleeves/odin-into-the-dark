#+build !js
package main

import eng "./engine"
import "core:testing"

path_test_fill_tiles :: proc(game: ^Game, tile_type: Tile_Type = .Floor) {
	game_init_world(game)
	for &tile in game.tiles {
		tile.type = tile_type
	}
}

@(test)
dijkstra_map_treats_locked_doors_as_unreachable_barriers :: proc(t: ^testing.T) {
	game: Game
	path_test_fill_tiles(&game, .Wall)
	game.tiles[pos_to_idx(1, 1)].type = .Floor
	game.tiles[pos_to_idx(2, 1)].type = .Locked_Door
	game.tiles[pos_to_idx(3, 1)].type = .Floor
	game.player.pos = Vec2{1, 1}

	compute_dijkstra_map(&game)
	dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(&game), DMAP_UNREACHABLE)

	testing.expect_value(t, eng.engine_distance_map_get(&dmap, 1, 1), 0)
	testing.expect_value(t, eng.engine_distance_map_get(&dmap, 2, 1), DMAP_UNREACHABLE)
	testing.expect_value(t, eng.engine_distance_map_get(&dmap, 3, 1), DMAP_UNREACHABLE)
}

@(test)
visible_enemy_moves_downhill_toward_player :: proc(t: ^testing.T) {
	game: Game
	path_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{4, 1},
			hp = 5,
			max_hp = 5,
			alive = true,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 4, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, Vec2{3, 1})
}

@(test)
visible_enemy_does_not_enter_occupied_tile_while_chasing :: proc(t: ^testing.T) {
	game: Game
	path_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{4, 1},
			hp = 5,
			max_hp = 5,
			alive = true,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{3, 1},
			hp = 5,
			max_hp = 5,
			alive = true,
			energy = 0,
			quickness = 0,
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 4, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, Vec2{4, 1})
	testing.expect_value(t, game.enemies[1].pos, Vec2{3, 1})
}

@(test)
adjacent_visible_enemy_attacks_instead_of_moving :: proc(t: ^testing.T) {
	game: Game
	path_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{2, 1},
			hp = 5,
			max_hp = 5,
			attack = 3,
			alive = true,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 2, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, Vec2{2, 1})
	// Enemy attack(3) is rolled with variance (no defense equipped), floored at 1.
	lo, hi := damage_roll_bounds(3)
	dealt := 20 - game.player.hp
	testing.expect(t, dealt >= max(lo, 1) && dealt <= max(hi, 1))
}

@(test)
enemy_turns_stop_after_player_death_and_preserve_first_death_cause :: proc(t: ^testing.T) {
	game: Game
	path_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 1
	game.player.max_hp = 1
	game.state = .Playing
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{2, 1},
			name = "Cave Crawler",
			hp = 5,
			max_hp = 5,
			attack = 1,
			alive = true,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{1, 2},
			name = "Rat",
			hp = 5,
			max_hp = 5,
			attack = 1,
			alive = true,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 2, 1, true, true, 1)
	_ = tile_state_set(&game, 1, 2, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.state, Game_State.Game_Over)
	testing.expect_value(t, game.player.hp, 0)
	testing.expect(t, game.death_cause == "Killed by a Cave Crawler")
	testing.expect_value(t, game.enemies[1].energy, 0)
}

@(test)
visible_unreachable_enemy_stops_instead_of_random_wandering :: proc(t: ^testing.T) {
	game: Game
	path_test_fill_tiles(&game, .Wall)
	game.tiles[pos_to_idx(1, 1)].type = .Floor
	game.tiles[pos_to_idx(5, 5)].type = .Floor
	game.tiles[pos_to_idx(6, 5)].type = .Floor
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{5, 5},
			hp = 5,
			max_hp = 5,
			alive = true,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 5, 5, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, Vec2{5, 5})
	testing.expect_value(t, game.enemies[0].energy, 0)
}
