package main

import "core:testing"

// ─── Helpers ──────────────────────────────────────────────────────────────────

make_status_test_game :: proc(hp: int = 10) -> Game {
	g: Game
	g.state = .Playing
	g.player.hp = hp
	g.player.max_hp = hp
	return g
}

make_test_messages :: proc() -> Message_Manager {
	return message_manager_make()
}

make_status_test_enemy :: proc(hp: int = 5) -> Enemy {
	return Enemy {
		hp = hp,
		max_hp = hp,
		alive = true,
		name = "rat",
		enemy_type = "rat",
		quickness = 100,
		move_speed = 100,
	}
}

// ─── Poison ───────────────────────────────────────────────────────────────────

@(test)
poison_tick_reduces_hp_by_one_each_turn :: proc(t: ^testing.T) {
	g := make_status_test_game(5)
	g.player_status[.Poison] = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 4)
	testing.expect_value(t, g.player_status[.Poison], 2)
}

@(test)
poison_expires_after_correct_number_of_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.player_status[.Poison] = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g) // turns=1, hp=9
	tick_timed_effects(&msgs, &g) // turns=0, hp=8

	testing.expect_value(t, g.player_status[.Poison], 0)
	testing.expect_value(t, g.player.hp, 8)

	// Third tick: poison turns already 0, no more damage
	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.player.hp, 8)
}

@(test)
poison_kills_player_when_hp_reaches_zero :: proc(t: ^testing.T) {
	g := make_status_test_game(1)
	g.player_status[.Poison] = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 0)
	testing.expect_value(t, g.state, Game_State.Game_Over)
}

@(test)
poison_does_not_reduce_hp_below_zero :: proc(t: ^testing.T) {
	g := make_status_test_game(1)
	g.player_status[.Poison] = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect(t, g.player.hp >= 0, "hp must not go below 0")
}

// ─── Burn ─────────────────────────────────────────────────────────────────────

@(test)
burn_tick_reduces_hp_by_one_each_turn :: proc(t: ^testing.T) {
	g := make_status_test_game(5)
	g.player_status[.Burning] = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 4)
	testing.expect_value(t, g.player_status[.Burning], 2)
}

@(test)
burn_expires_after_correct_number_of_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.player_status[.Burning] = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player_status[.Burning], 0)
	testing.expect_value(t, g.player.hp, 8)

	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.player.hp, 8)
}

@(test)
burn_kills_player_when_hp_reaches_zero :: proc(t: ^testing.T) {
	g := make_status_test_game(1)
	g.player_status[.Burning] = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 0)
	testing.expect_value(t, g.state, Game_State.Game_Over)
}

// ─── Frozen ───────────────────────────────────────────────────────────────────

@(test)
frozen_decrements_each_turn :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.player_status[.Frozen] = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player_status[.Frozen], 2)
}

@(test)
frozen_expires_after_correct_number_of_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.player_status[.Frozen] = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player_status[.Frozen], 0)
}

@(test)
frozen_does_not_damage_player :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.player_status[.Frozen] = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 10)
}

@(test)
frozen_cleared_after_expiry_leaves_no_residual_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.player_status[.Frozen] = 1
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player_status[.Frozen], 0)

	// Additional ticks must not underflow
	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.player_status[.Frozen], 0)
}

// ─── No-op when game is over ──────────────────────────────────────────────────

@(test)
timed_effects_are_skipped_when_game_is_over :: proc(t: ^testing.T) {
	g := make_status_test_game(3)
	g.state = .Game_Over
	g.player_status[.Poison] = 5
	g.player_status[.Burning] = 5
	g.player_status[.Frozen] = 5
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 3)
	testing.expect_value(t, g.player_status[.Poison], 5)
	testing.expect_value(t, g.player_status[.Burning], 5)
	testing.expect_value(t, g.player_status[.Frozen], 5)
}

// ─── Interaction: simultaneous poison + burn ──────────────────────────────────

@(test)
simultaneous_poison_and_burn_each_deal_one_damage :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.player_status[.Poison] = 2
	g.player_status[.Burning] = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 8)
}

@(test)
simultaneous_poison_and_burn_can_kill_player :: proc(t: ^testing.T) {
	g := make_status_test_game(2)
	g.player_status[.Poison] = 3
	g.player_status[.Burning] = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.state, Game_State.Game_Over)
}

// ─── status_apply helper ──────────────────────────────────────────────────────

@(test)
status_apply_keeps_longer_existing_duration :: proc(t: ^testing.T) {
	s: Status_Turns
	status_apply(&s, .Poison, 5)
	status_apply(&s, .Poison, 2)
	testing.expect_value(t, s[.Poison], 5)

	status_apply(&s, .Poison, 8)
	testing.expect_value(t, s[.Poison], 8)
}

// ─── Enemy status effects ─────────────────────────────────────────────────────

@(test)
enemy_poison_ticks_damage_and_expires :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.enemies = make([dynamic]Enemy)
	defer delete(g.enemies)
	e := make_status_test_enemy(3)
	e.status[.Poison] = 2
	append(&g.enemies, e)
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.enemies[0].hp, 2)
	testing.expect_value(t, g.enemies[0].status[.Poison], 1)

	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.enemies[0].hp, 1)
	testing.expect_value(t, g.enemies[0].status[.Poison], 0)

	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.enemies[0].hp, 1)
}

@(test)
enemy_burning_kill_increments_kill_counter :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.enemies = make([dynamic]Enemy)
	defer delete(g.enemies)
	e := make_status_test_enemy(1)
	e.status[.Burning] = 3
	append(&g.enemies, e)
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.enemies[0].alive, false)
	testing.expect_value(t, g.kills, 1)
}

@(test)
dead_enemies_do_not_tick_statuses :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.enemies = make([dynamic]Enemy)
	defer delete(g.enemies)
	e := make_status_test_enemy(5)
	e.alive = false
	e.status[.Poison] = 3
	append(&g.enemies, e)
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.enemies[0].hp, 5)
	testing.expect_value(t, g.enemies[0].status[.Poison], 3)
	testing.expect_value(t, g.kills, 0)
}

@(test)
enemy_frozen_and_webbed_count_down_without_damage :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.enemies = make([dynamic]Enemy)
	defer delete(g.enemies)
	e := make_status_test_enemy(5)
	e.status[.Frozen] = 2
	e.status[.Webbed] = 1
	append(&g.enemies, e)
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.enemies[0].hp, 5)
	testing.expect_value(t, g.enemies[0].status[.Frozen], 1)
	testing.expect_value(t, g.enemies[0].status[.Webbed], 0)
}
