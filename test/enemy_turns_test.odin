#+build !js
package main

import "core:testing"

// Shared helper: fill all tiles with Floor and init the world manager.
enemy_turns_test_setup :: proc(game: ^Game) {
	game_init_world(game)
	for &tile in game.tiles {
		tile.type = .Floor
	}
	game.player.hp = 20
	game.player.max_hp = 20
	game.player.pos = Vec2{1, 1}
	game.enemies = make([dynamic]Enemy)
}

// ─── energy / can_act ─────────────────────────────────────────────────────────

@(test)
enemy_with_positive_energy_acts_when_visible :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	// Place enemy two steps away — it should move one step toward player.
	append(
		&game.enemies,
		Enemy {
			pos        = Vec2{3, 1},
			hp         = 5,
			max_hp     = 5,
			alive      = true,
			energy     = BASE_MOVE_COST, // already has enough AP — must act
			quickness  = 0, // no new AP granted this round
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 3, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	// Energy was positive, so the enemy must have moved closer.
	testing.expect_value(t, game.enemies[0].pos, Vec2{2, 1})
}

@(test)
enemy_energy_is_deducted_after_moving :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	// Give enemy exactly one move's worth of AP.
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{5, 1},
			hp = 5,
			max_hp = 5,
			alive = true,
			energy = BASE_MOVE_COST,
			quickness = 0,
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 5, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	// After one move the AP must be <= 0 (exactly 0 when move_speed == 100).
	testing.expect(
		t,
		game.enemies[0].energy <= 0,
		"energy should be zero or negative after one move",
	)
}

@(test)
enemy_with_no_energy_does_not_move :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	start_pos := Vec2{4, 1}
	append(
		&game.enemies,
		Enemy {
			pos        = start_pos,
			hp         = 5,
			max_hp     = 5,
			alive      = true,
			energy     = 0,
			quickness  = 0, // no AP granted this round either
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 4, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, start_pos)
}

// ─── quickness / AP grant ─────────────────────────────────────────────────────

@(test)
energy_granted_equals_quickness_times_ten :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	// Put the enemy far away so it never reaches the player in one burst and
	// we can observe the AP grant in isolation (quickness 0 → no move).
	// Use quickness = 0 so the enemy gets no AP and stays put; verify energy
	// stays at exactly what process_enemy_turns would have added.
	//
	// Simpler approach: put enemy on a wall-surrounded island so it cannot
	// move, and measure the energy delta directly.
	//
	// Grant 50 quickness → +500 AP each round.
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{10, 10},
			hp = 5,
			max_hp = 5,
			alive = true,
			energy = 0,
			quickness = 50,
			move_speed = 100,
		},
	)
	// Mark tile as visible so the chase path runs, but surround with walls so
	// movement fails and energy drains to 0 after all movement attempts.
	// We test the grant by pre-setting energy to a negative value ("debt") and
	// confirming the post-turn energy equals: initial + quickness*10 - costs.
	//
	// Easier: use quickness = 0 baseline and quickness = 50 comparison.
	// For a deterministic test: place enemy adjacent to player (attack uses
	// BASE_ACTION_COST = 1000) and give exactly 0 starting energy.
	// After the turn: energy = 0 + quickness*10 - BASE_ACTION_COST.
	game.enemies[0].pos = Vec2{2, 1}
	_ = tile_state_set(&game, 2, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	// AP granted = 50 * 10 = 500. Attack cost = BASE_ACTION_COST = 1000.
	// Remaining energy = 500 - 1000 = -500.
	expected := 50 * 10 - BASE_ACTION_COST
	testing.expect_value(t, game.enemies[0].energy, expected)
}

@(test)
quickness_100_grants_one_thousand_ap_per_round :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	// Adjacent enemy, quickness 100, 0 starting energy.
	// AP grant = 100 * 10 = 1000. Attack costs BASE_ACTION_COST = 1000.
	// After one attack: energy = 1000 - 1000 = 0.
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{2, 1},
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
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].energy, 0)
}

// ─── Lurker behavior ─────────────────────────────────────────────────────────

@(test)
lurker_not_visible_to_player_drains_energy_to_zero :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	start_pos := Vec2{5, 5}
	append(
		&game.enemies,
		Enemy {
			pos = start_pos,
			hp = 5,
			max_hp = 5,
			alive = true,
			behavior = ENEMY_BEHAVIOR_LURKER,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	// Do NOT set tile visible — lurker should stay completely still.
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, start_pos)
	testing.expect_value(t, game.enemies[0].energy, 0)
}

@(test)
lurker_visible_but_not_adjacent_stays_still :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	start_pos := Vec2{5, 1}
	append(
		&game.enemies,
		Enemy {
			pos = start_pos,
			hp = 5,
			max_hp = 5,
			alive = true,
			behavior = ENEMY_BEHAVIOR_LURKER,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	// Tile is visible — lurker_act_once runs, but enemy is not adjacent,
	// so it drains energy to 0 and returns false without moving.
	_ = tile_state_set(&game, 5, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	testing.expect_value(t, game.enemies[0].pos, start_pos)
	testing.expect_value(t, game.enemies[0].energy, 0)
}

@(test)
lurker_visible_and_adjacent_attacks_player :: proc(t: ^testing.T) {
	game: Game
	enemy_turns_test_setup(&game)
	defer delete(game.enemies)

	// player at (1,1), lurker at (2,1) — one step east = adjacent
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{2, 1},
			hp = 5,
			max_hp = 5,
			attack = 3,
			alive = true,
			behavior = ENEMY_BEHAVIOR_LURKER,
			energy = 0,
			quickness = 100,
			move_speed = 100,
		},
	)
	_ = tile_state_set(&game, 2, 1, true, true, 1)
	messages := message_manager_make()

	process_enemy_turns(&messages, &game)

	// Lurker attacked — player HP reduced, lurker did not move.
	testing.expect(
		t,
		game.player.hp < game.player.max_hp,
		"lurker should have attacked the player",
	)
	testing.expect_value(t, game.enemies[0].pos, Vec2{2, 1})
}
