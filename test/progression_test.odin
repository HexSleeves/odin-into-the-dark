package main

import "core:testing"

// ─── Kill-progression milestone tests ────────────────────────────────────────

@(test)
apply_kill_milestone_buff_returns_empty_string_before_threshold :: proc(t: ^testing.T) {
	g: Game
	g.player.hp = 10
	g.player.max_hp = 10
	g.player.attack = 3
	g.player.light_radius = 4
	g.kills = KILLS_PER_MILESTONE - 1
	g.kills_milestone = 0

	msg := apply_kill_milestone_buff(&g)

	testing.expect(t, msg == "", "expected no milestone message below threshold")
	testing.expect_value(t, g.kills_milestone, 0)
	testing.expect_value(t, g.player.max_hp, 10)
	testing.expect_value(t, g.player.attack, 3)
	testing.expect_value(t, g.player.light_radius, 4)
}

@(test)
apply_kill_milestone_buff_awards_max_hp_at_first_milestone :: proc(t: ^testing.T) {
	g: Game
	g.player.hp = 10
	g.player.max_hp = 10
	g.player.attack = 3
	g.player.light_radius = 4
	g.kills = KILLS_PER_MILESTONE // exactly at threshold
	g.kills_milestone = 0

	msg := apply_kill_milestone_buff(&g)

	testing.expect(t, msg != "", "expected a milestone message at threshold")
	testing.expect_value(t, g.kills_milestone, 1)
	testing.expect_value(t, g.player.max_hp, 10 + SHRINE_BUFF_MAX_HP)
	testing.expect_value(t, g.player.hp, 10 + SHRINE_BUFF_MAX_HP)
}

@(test)
apply_kill_milestone_buff_awards_attack_at_second_milestone :: proc(t: ^testing.T) {
	g: Game
	g.player.hp = 15
	g.player.max_hp = 15
	g.player.attack = 3
	g.player.light_radius = 4
	g.kills = KILLS_PER_MILESTONE * 2
	g.kills_milestone = 1 // first milestone already claimed

	msg := apply_kill_milestone_buff(&g)

	testing.expect(t, msg != "", "expected a milestone message at second threshold")
	testing.expect_value(t, g.kills_milestone, 2)
	testing.expect_value(t, g.player.attack, 3 + SHRINE_BUFF_ATTACK)
}

@(test)
apply_kill_milestone_buff_awards_light_at_third_milestone :: proc(t: ^testing.T) {
	g: Game
	g.player.hp = 15
	g.player.max_hp = 15
	g.player.attack = 5
	g.player.light_radius = 4
	g.kills = KILLS_PER_MILESTONE * 3
	g.kills_milestone = 2 // two milestones already claimed

	msg := apply_kill_milestone_buff(&g)

	testing.expect(t, msg != "", "expected a milestone message at third threshold")
	testing.expect_value(t, g.kills_milestone, 3)
	testing.expect_value(t, g.player.light_radius, 4 + SHRINE_BUFF_LIGHT)
}

@(test)
apply_kill_milestone_buff_cycles_back_to_max_hp_at_fourth_milestone :: proc(t: ^testing.T) {
	g: Game
	g.player.hp = 20
	g.player.max_hp = 20
	g.player.attack = 5
	g.player.light_radius = 6
	g.kills = KILLS_PER_MILESTONE * 4
	g.kills_milestone = 3 // three milestones already claimed

	msg := apply_kill_milestone_buff(&g)

	testing.expect(t, msg != "", "expected a milestone message at fourth threshold")
	testing.expect_value(t, g.kills_milestone, 4)
	// cycle wraps: index 3 % 3 == 0 → Max HP again
	testing.expect_value(t, g.player.max_hp, 20 + SHRINE_BUFF_MAX_HP)
}

@(test)
apply_kill_milestone_buff_does_not_double_award_on_same_kills_count :: proc(t: ^testing.T) {
	g: Game
	g.player.hp = 10
	g.player.max_hp = 10
	g.player.attack = 3
	g.kills = KILLS_PER_MILESTONE
	g.kills_milestone = 0

	// First call awards the milestone
	_ = apply_kill_milestone_buff(&g)
	hp_after_first := g.player.max_hp

	// Second call on same kills count must not award again
	msg2 := apply_kill_milestone_buff(&g)

	testing.expect(t, msg2 == "", "second call on same kills should return empty")
	testing.expect_value(t, g.player.max_hp, hp_after_first)
	testing.expect_value(t, g.kills_milestone, 1)
}
