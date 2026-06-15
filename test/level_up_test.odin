#+build !js
package main

import "core:testing"

// ─── D3: milestone kill-driven level-ups ──────────────────────────────────────

@(test)
levelup_level_for_kills_advances_one_level_per_threshold :: proc(t: ^testing.T) {
	testing.expect_value(t, levelup_level_for_kills(0), 1)
	testing.expect_value(t, levelup_level_for_kills(KILLS_PER_LEVEL - 1), 1)
	testing.expect_value(t, levelup_level_for_kills(KILLS_PER_LEVEL), 2)
	testing.expect_value(t, levelup_level_for_kills(KILLS_PER_LEVEL * 3), 4)
}

@(test)
levelup_kills_for_level_is_inverse_of_level_for_kills :: proc(t: ^testing.T) {
	testing.expect_value(t, levelup_kills_for_level(1), 0)
	testing.expect_value(t, levelup_kills_for_level(2), KILLS_PER_LEVEL)
	testing.expect_value(t, levelup_kills_for_level(4), KILLS_PER_LEVEL * 3)
	// Round-trip: the kills at a level derive back to that level.
	for level in 1 ..= 5 {
		testing.expect_value(t, levelup_level_for_kills(levelup_kills_for_level(level)), level)
	}
}

@(test)
check_level_up_queues_a_menu_when_a_threshold_is_crossed :: proc(t: ^testing.T) {
	g: Game
	game_init_world(&g)
	g.state = .Playing
	g.player_level = 1
	g.kills = KILLS_PER_LEVEL // exactly one level reached

	check_level_up(nil, &g)

	testing.expect_value(t, g.player_level, 2)
	testing.expect_value(t, g.pending_level_ups, 1)
	testing.expect_value(t, g.state, Game_State.Viewing_Level_Up)
}

@(test)
check_level_up_does_nothing_below_threshold :: proc(t: ^testing.T) {
	g: Game
	game_init_world(&g)
	g.state = .Playing
	g.player_level = 1
	g.kills = KILLS_PER_LEVEL - 1

	check_level_up(nil, &g)

	testing.expect_value(t, g.player_level, 1)
	testing.expect_value(t, g.pending_level_ups, 0)
	testing.expect_value(t, g.state, Game_State.Playing)
}

@(test)
apply_levelup_buff_raises_max_hp_and_current_hp_without_cost :: proc(t: ^testing.T) {
	g: Game
	game_init_world(&g)
	g.state = .Viewing_Level_Up
	g.player.hp = 20
	g.player.max_hp = 25
	g.pending_level_ups = 1

	apply_levelup_buff(nil, &g, .Max_HP)

	// Max HP raised AND current HP raised (no shrine-style sacrifice).
	testing.expect_value(t, g.player.max_hp, 25 + LEVELUP_BUFF_MAX_HP)
	testing.expect_value(t, g.player.hp, 20 + LEVELUP_BUFF_MAX_HP)
	testing.expect_value(t, g.pending_level_ups, 0)
	testing.expect_value(t, g.state, Game_State.Playing)
}

@(test)
apply_levelup_buff_reopens_menu_while_more_are_pending :: proc(t: ^testing.T) {
	g: Game
	game_init_world(&g)
	g.state = .Viewing_Level_Up
	g.player.hp = 20
	g.player.max_hp = 25
	g.pending_level_ups = 2 // two queued

	apply_levelup_buff(nil, &g, .Attack)

	// One consumed, one still pending → menu stays open for the next choice.
	testing.expect_value(t, g.pending_level_ups, 1)
	testing.expect_value(t, g.state, Game_State.Viewing_Level_Up)
}
