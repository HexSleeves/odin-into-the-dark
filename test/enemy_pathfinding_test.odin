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
dijkstra_map_is_only_recomputed_when_marked_dirty :: proc(t: ^testing.T) {
	game: Game
	path_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)

	dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(&game), DMAP_UNREACHABLE)

	// Poison the flow field with a sentinel the BFS would never produce at (1,1).
	SENTINEL :: 7777
	_ = eng.engine_distance_map_set(&dmap, 1, 1, SENTINEL)

	// dirty == false → process_enemy_turns must NOT recompute; sentinel survives.
	game.dijkstra_dirty = false
	messages := message_manager_make()
	process_enemy_turns(&messages, &game)
	testing.expect_value(t, eng.engine_distance_map_get(&dmap, 1, 1), SENTINEL)

	// dirty == true → recompute; player tile resets to 0 and the flag clears.
	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)
	testing.expect_value(t, eng.engine_distance_map_get(&dmap, 1, 1), 0)
	testing.expect_value(t, game.dijkstra_dirty, false)
}

@(test)
trigger_enemy_rounds_recomputes_flow_field_once_then_reuses_it_across_slow_player_rounds :: proc(
	t: ^testing.T,
) {
	// compute_dijkstra_map clears dijkstra_dirty. So after one recompute within a
	// burst of enemy rounds, the flag stays false and later rounds reuse the field.
	game: Game
	path_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)

	// First recompute (simulating the first enemy round of a player input).
	game.dijkstra_dirty = true
	compute_dijkstra_map(&game)
	testing.expect_value(t, game.dijkstra_dirty, false)

	// Poison the field; if a later round reused it (dirty still false) the sentinel
	// survives, proving no redundant recompute happened.
	dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(&game), DMAP_UNREACHABLE)
	SENTINEL :: 5555
	_ = eng.engine_distance_map_set(&dmap, 1, 1, SENTINEL)

	messages := message_manager_make()
	process_enemy_turns(&messages, &game) // dirty == false → no recompute
	testing.expect_value(t, eng.engine_distance_map_get(&dmap, 1, 1), SENTINEL)
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

	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, Vec2{3, 1})
}

@(test)
visible_enemy_does_not_enter_occupied_tile_while_chasing :: proc(t: ^testing.T) {
	// A chaser must never step ONTO a tile held by another enemy. With an open
	// floor around it, the occupancy-aware chase routes the chaser into a free
	// lane instead — but it can never land on the blocker's tile.
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

	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)

	// The blocker (no AP) never moves; the chaser never lands on its tile.
	testing.expect_value(t, game.enemies[1].pos, Vec2{3, 1})
	testing.expect(
		t,
		game.enemies[0].pos != game.enemies[1].pos,
		"chaser must not occupy the blocker's tile",
	)
}

@(test)
chaser_routes_around_an_occupied_downhill_tile_instead_of_funneling :: proc(t: ^testing.T) {
	// Single-file corridor mouth: the blocker sits on the chaser's only strictly-
	// downhill tile. The occupancy-aware chase sidesteps into an adjacent open
	// lane (a tile at most one step farther) so the pack fans out instead of
	// stalling in a column behind the blocker.
	game: Game
	path_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)
	// Chaser with one round of AP.
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
	// Stationary blocker parked on the chaser's only downhill tile (3,1).
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

	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)

	// Blocker stays put; chaser must have MOVED (no longer stalled at (4,1)) and
	// must have stepped to an adjacent lane, not onto the occupied tile.
	testing.expect_value(t, game.enemies[1].pos, Vec2{3, 1})
	moved := game.enemies[0].pos != Vec2{4, 1}
	testing.expect(t, moved, "chaser must route around the blocker instead of stalling")
	testing.expect(
		t,
		game.enemies[0].pos == Vec2{4, 0} || game.enemies[0].pos == Vec2{4, 2},
		"chaser should sidestep into an adjacent open lane",
	)
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

	game.dijkstra_dirty = true
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

	game.dijkstra_dirty = true
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

	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, Vec2{5, 5})
	testing.expect_value(t, game.enemies[0].energy, 0)
}
