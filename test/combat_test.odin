package main

import "core:testing"

// ─── Helpers ──────────────────────────────────────────────────────────────────

make_combat_test_enemy :: proc(hp: int = 10, attack: int = 3, is_boss: bool = false) -> Enemy {
	e: Enemy
	e.hp = hp
	e.max_hp = hp
	e.attack = attack
	e.alive = true
	e.is_boss = is_boss
	e.name = "rat"
	return e
}


make_combat_test_game :: proc(hp: int = 10) -> Game {
	g: Game
	g.state = .Playing
	g.player.hp = hp
	g.player.max_hp = hp
	return g
}

make_combat_test_messages :: proc() -> Message_Manager {
	return message_manager_make()
}

// ─── effective_attack ─────────────────────────────────────────────────────────

@(test)
effective_attack_returns_base_attack_when_no_weapon_equipped :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 5

	testing.expect_value(t, effective_attack(&g), 5)
}

@(test)
effective_attack_adds_weapon_bonus_to_base_attack :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 4
	g.equipped_weapon = Equipment {
		occupied = true,
		item = Item{stat_bonus = 3},
	}

	testing.expect_value(t, effective_attack(&g), 7)
}

@(test)
effective_attack_ignores_unoccupied_weapon_slot :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 4
	g.equipped_weapon = Equipment {
		occupied = false,
		item = Item{stat_bonus = 99},
	}

	testing.expect_value(t, effective_attack(&g), 4)
}

// ─── effective_defense ───────────────────────────────────────────────────────

@(test)
effective_defense_returns_zero_when_no_armor_equipped :: proc(t: ^testing.T) {
	g := make_combat_test_game()

	testing.expect_value(t, effective_defense(&g), 0)
}

@(test)
effective_defense_returns_armor_stat_bonus_when_equipped :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.equipped_armor = Equipment {
		occupied = true,
		item = Item{stat_bonus = 2},
	}

	testing.expect_value(t, effective_defense(&g), 2)
}

// ─── resolve_attack_player_on_enemy ──────────────────────────────────────────

@(test)
player_attack_reduces_enemy_hp_by_effective_attack :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 4
	e := make_combat_test_enemy(hp = 10)
	msgs := make_combat_test_messages()

	resolve_attack_player_on_enemy(&msgs, &g, &e)

	// Damage is rolled with variance and may crit: bounds derive from effective_attack(4).
	lo, hi := damage_roll_bounds(4)
	dealt := 10 - e.hp
	testing.expect(t, dealt >= lo && dealt <= hi * CRIT_DAMAGE_MULT_PCT / 100)
}

@(test)
player_attack_with_weapon_bonus_applies_full_damage :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 2
	g.equipped_weapon = Equipment {
		occupied = true,
		item = Item{stat_bonus = 3},
	}
	e := make_combat_test_enemy(hp = 10)
	msgs := make_combat_test_messages()

	resolve_attack_player_on_enemy(&msgs, &g, &e)

	// effective_attack = 2+3 = 5; damage rolled with variance, may crit.
	lo, hi := damage_roll_bounds(5)
	dealt := 10 - e.hp
	testing.expect(t, dealt >= lo && dealt <= hi * CRIT_DAMAGE_MULT_PCT / 100)
}

@(test)
player_attack_reduces_kill_count_on_lethal_hit :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 100
	e := make_combat_test_enemy(hp = 5)
	msgs := make_combat_test_messages()

	testing.expect_value(t, g.kills, 0)
	resolve_attack_player_on_enemy(&msgs, &g, &e)
	testing.expect_value(t, g.kills, 1)
}

@(test)
player_attack_sets_enemy_alive_false_on_lethal_hit :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 100
	e := make_combat_test_enemy(hp = 5)
	msgs := make_combat_test_messages()

	resolve_attack_player_on_enemy(&msgs, &g, &e)

	testing.expect(t, !e.alive, "enemy must be marked dead after lethal hit")
	testing.expect_value(t, e.hp <= 0, true)
}

@(test)
player_attack_does_not_kill_enemy_when_damage_is_insufficient :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 2
	e := make_combat_test_enemy(hp = 10)
	msgs := make_combat_test_messages()

	resolve_attack_player_on_enemy(&msgs, &g, &e)

	testing.expect(t, e.alive, "enemy must remain alive when not killed")
	testing.expect_value(t, g.kills, 0)
}

@(test)
boss_killed_this_turn_is_set_when_boss_dies :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 100
	e := make_combat_test_enemy(hp = 5, is_boss = true)
	msgs := make_combat_test_messages()

	testing.expect(t, !g.boss_killed_this_turn, "flag must start false")
	resolve_attack_player_on_enemy(&msgs, &g, &e)
	testing.expect(t, g.boss_killed_this_turn, "boss_killed_this_turn must be set on boss kill")
}

@(test)
boss_killed_this_turn_is_not_set_when_non_boss_dies :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.player.attack = 100
	e := make_combat_test_enemy(hp = 5, is_boss = false)
	msgs := make_combat_test_messages()

	resolve_attack_player_on_enemy(&msgs, &g, &e)

	testing.expect(t, !g.boss_killed_this_turn, "boss flag must not be set for normal enemy kill")
}

// ─── resolve_attack_enemy_on_player ──────────────────────────────────────────

@(test)
enemy_attack_reduces_player_hp_by_attack_minus_defense :: proc(t: ^testing.T) {
	g := make_combat_test_game(hp = 20)
	g.equipped_armor = Equipment {
		occupied = true,
		item = Item{stat_bonus = 2},
	}
	e := make_combat_test_enemy(attack = 5)
	msgs := make_combat_test_messages()

	resolve_attack_enemy_on_player(&msgs, &g, &e)

	// Enemy attack(5) is rolled with variance, then reduced by defense(2), floored at 1.
	lo, hi := damage_roll_bounds(5)
	dealt := 20 - g.player.hp
	testing.expect(t, dealt >= max(lo - 2, 1) && dealt <= max(hi - 2, 1))
}

@(test)
enemy_attack_damage_is_floored_at_one :: proc(t: ^testing.T) {
	g := make_combat_test_game(hp = 10)
	g.equipped_armor = Equipment {
		occupied = true,
		item = Item{stat_bonus = 99},
	}
	e := make_combat_test_enemy(attack = 1)
	msgs := make_combat_test_messages()

	resolve_attack_enemy_on_player(&msgs, &g, &e)

	// defense (99) >> attack (1): damage must be at least 1
	testing.expect_value(t, g.player.hp, 9)
}

@(test)
enemy_attack_kills_player_when_damage_exceeds_hp :: proc(t: ^testing.T) {
	g := make_combat_test_game(hp = 1)
	e := make_combat_test_enemy(attack = 10)
	msgs := make_combat_test_messages()

	resolve_attack_enemy_on_player(&msgs, &g, &e)

	testing.expect_value(t, g.player.hp, 0)
	testing.expect_value(t, g.state, Game_State.Game_Over)
}

@(test)
enemy_attack_does_not_reduce_player_hp_below_zero :: proc(t: ^testing.T) {
	g := make_combat_test_game(hp = 3)
	e := make_combat_test_enemy(attack = 1000)
	msgs := make_combat_test_messages()

	resolve_attack_enemy_on_player(&msgs, &g, &e)

	testing.expect(t, g.player.hp >= 0, "player hp must not go below 0")
}
