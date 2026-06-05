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

// ─── Poison ───────────────────────────────────────────────────────────────────

@(test)
poison_tick_reduces_hp_by_one_each_turn :: proc(t: ^testing.T) {
	g := make_status_test_game(5)
	g.poison_turns = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 4)
	testing.expect_value(t, g.poison_turns, 2)
}

@(test)
poison_expires_after_correct_number_of_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.poison_turns = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g) // turns=1, hp=9
	tick_timed_effects(&msgs, &g) // turns=0, hp=8

	testing.expect_value(t, g.poison_turns, 0)
	testing.expect_value(t, g.player.hp, 8)

	// Third tick: poison_turns already 0, no more damage
	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.player.hp, 8)
}

@(test)
poison_kills_player_when_hp_reaches_zero :: proc(t: ^testing.T) {
	g := make_status_test_game(1)
	g.poison_turns = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 0)
	testing.expect_value(t, g.state, Game_State.Game_Over)
}

@(test)
poison_does_not_reduce_hp_below_zero :: proc(t: ^testing.T) {
	g := make_status_test_game(1)
	g.poison_turns = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect(t, g.player.hp >= 0, "hp must not go below 0")
}

// ─── Burn ─────────────────────────────────────────────────────────────────────

@(test)
burn_tick_reduces_hp_by_one_each_turn :: proc(t: ^testing.T) {
	g := make_status_test_game(5)
	g.burning_turns = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 4)
	testing.expect_value(t, g.burning_turns, 2)
}

@(test)
burn_expires_after_correct_number_of_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.burning_turns = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.burning_turns, 0)
	testing.expect_value(t, g.player.hp, 8)

	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.player.hp, 8)
}

@(test)
burn_kills_player_when_hp_reaches_zero :: proc(t: ^testing.T) {
	g := make_status_test_game(1)
	g.burning_turns = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 0)
	testing.expect_value(t, g.state, Game_State.Game_Over)
}

// ─── Frozen ───────────────────────────────────────────────────────────────────

@(test)
frozen_decrements_each_turn :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.frozen_turns = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.frozen_turns, 2)
}

@(test)
frozen_expires_after_correct_number_of_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.frozen_turns = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.frozen_turns, 0)
}

@(test)
frozen_does_not_damage_player :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.frozen_turns = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)
	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 10)
}

@(test)
frozen_cleared_after_expiry_leaves_no_residual_turns :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.frozen_turns = 1
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.frozen_turns, 0)

	// Additional ticks must not underflow
	tick_timed_effects(&msgs, &g)
	testing.expect_value(t, g.frozen_turns, 0)
}

// ─── No-op when game is over ──────────────────────────────────────────────────

@(test)
timed_effects_are_skipped_when_game_is_over :: proc(t: ^testing.T) {
	g := make_status_test_game(3)
	g.state = .Game_Over
	g.poison_turns = 5
	g.burning_turns = 5
	g.frozen_turns = 5
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 3)
	testing.expect_value(t, g.poison_turns, 5)
	testing.expect_value(t, g.burning_turns, 5)
	testing.expect_value(t, g.frozen_turns, 5)
}

// ─── Interaction: simultaneous poison + burn ──────────────────────────────────

@(test)
simultaneous_poison_and_burn_each_deal_one_damage :: proc(t: ^testing.T) {
	g := make_status_test_game(10)
	g.poison_turns = 2
	g.burning_turns = 2
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.player.hp, 8)
}

@(test)
simultaneous_poison_and_burn_can_kill_player :: proc(t: ^testing.T) {
	g := make_status_test_game(2)
	g.poison_turns = 3
	g.burning_turns = 3
	msgs := make_test_messages()

	tick_timed_effects(&msgs, &g)

	testing.expect_value(t, g.state, Game_State.Game_Over)
}
