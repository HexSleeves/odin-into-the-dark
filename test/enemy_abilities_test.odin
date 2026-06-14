package main

import eng "./engine"
import "core:testing"

// ─── Helpers ──────────────────────────────────────────────────────────────────

// make_enemy returns a minimal live enemy at pos with the given ability.
make_ability_test_enemy :: proc(
	x, y: int,
	ability: string,
	max_cd: int = 3,
	range: int = 5,
	attack: int = 3,
) -> Enemy {
	e: Enemy
	e.pos = Vec2{x, y}
	e.hp = 10
	e.max_hp = 10
	e.attack = attack
	e.alive = true
	e.ability_type = ability
	e.ability_cooldown = 0
	e.ability_max_cd = max_cd
	e.ability_range = range
	e.name = "test enemy"
	return e
}

// make_floor sets a tile to Floor so is_walkable returns true.
make_floor :: proc(g: ^Game, x, y: int) {
	g.tiles[y * MAP_WIDTH + x].type = .Floor
}


make_ability_test_game :: proc(hp: int = 10) -> Game {
	g: Game
	g.state = .Playing
	g.player.hp = hp
	g.player.max_hp = hp
	game_init_world(&g)
	return g
}

make_ability_test_messages :: proc() -> Message_Manager {
	return message_manager_make()
}

// ─── Cooldown behaviour ───────────────────────────────────────────────────────

@(test)
ability_on_cooldown_does_not_fire :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// Place player right next to enemy so the ability *would* fire if off cooldown.
	g.player.pos = Vec2{5, 5}
	make_floor(&g, 5, 5)

	enemy := make_ability_test_enemy(5, 6, ENEMY_ABILITY_RANGED_SHOOT, 3, 8)
	enemy.ability_cooldown = 2 // still on cooldown
	// Mark the enemy tile visible so ranged shot could proceed.
	_ = tile_state_set(&g, 5, 6, true, true, 1.0)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	hp_before := g.player.hp
	process_enemy_abilities(&msgs, &g)

	// Cooldown decremented but ability did not fire.
	testing.expect_value(t, g.enemies[0].ability_cooldown, 1)
	testing.expect_value(t, g.player.hp, hp_before)
}

@(test)
ability_cooldown_decrements_each_call :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	g.player.pos = Vec2{5, 5}

	enemy := make_ability_test_enemy(5, 10, ENEMY_ABILITY_RANGED_SHOOT, 5, 3)
	enemy.ability_cooldown = 5
	append(&g.enemies, enemy)
	defer delete(g.enemies)

	process_enemy_abilities(&msgs, &g)
	testing.expect_value(t, g.enemies[0].ability_cooldown, 4)

	process_enemy_abilities(&msgs, &g)
	testing.expect_value(t, g.enemies[0].ability_cooldown, 3)
}

// ─── Range guard ──────────────────────────────────────────────────────────────

@(test)
out_of_range_ranged_ability_does_not_trigger :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// Player far away — Manhattan distance 15, ability_range 5.
	g.player.pos = Vec2{1, 1}
	enemy := make_ability_test_enemy(10, 7, ENEMY_ABILITY_RANGED_SHOOT, 3, 5, 4)
	_ = tile_state_set(&g, 10, 7, true, true, 1.0)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	hp_before := g.player.hp
	process_enemy_abilities(&msgs, &g)

	testing.expect_value(t, g.player.hp, hp_before)
	// Cooldown must NOT have been reset (ability never fired).
	testing.expect_value(t, g.enemies[0].ability_cooldown, 0)
}

// ─── Web ability ──────────────────────────────────────────────────────────────

@(test)
web_ability_sets_web_on_adjacent_floor_tile :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// Player within web range (dist <= 3).
	g.player.pos = Vec2{5, 5}
	make_floor(&g, 5, 5)

	enemy := make_ability_test_enemy(5, 7, ENEMY_ABILITY_WEB, 4, 5)
	// Place a walkable floor tile adjacent to the enemy (above it = y-1).
	make_floor(&g, 5, 8)
	make_floor(&g, 4, 7)
	make_floor(&g, 6, 7)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	process_enemy_abilities(&msgs, &g)

	// At least one adjacent tile should now have a web.
	web_placed :=
		web_tile_at(&g, 5, 6) ||
		web_tile_at(&g, 5, 8) ||
		web_tile_at(&g, 4, 7) ||
		web_tile_at(&g, 6, 7)
	testing.expect(t, web_placed, "expected a web tile to be placed adjacent to the enemy")
	// Cooldown must have been reset.
	testing.expect(
		t,
		g.enemies[0].ability_cooldown == g.enemies[0].ability_max_cd,
		"expected ability_cooldown to be reset to ability_max_cd after firing",
	)
}

@(test)
web_ability_does_not_fire_when_player_out_of_range :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// dist > 3.
	g.player.pos = Vec2{1, 1}
	enemy := make_ability_test_enemy(10, 10, ENEMY_ABILITY_WEB, 4, 5)
	make_floor(&g, 10, 9)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	process_enemy_abilities(&msgs, &g)

	web_placed :=
		web_tile_at(&g, 10, 9) ||
		web_tile_at(&g, 10, 11) ||
		web_tile_at(&g, 9, 10) ||
		web_tile_at(&g, 11, 10)
	testing.expect(t, !web_placed, "expected no web when player is out of range")
}

// ─── Ranged attack ────────────────────────────────────────────────────────────

@(test)
ranged_shoot_deals_damage_when_in_range_and_visible :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// dist = 3, within range 5, clear line of sight (carve the column to floor).
	g.player.pos = Vec2{5, 5}
	enemy := make_ability_test_enemy(5, 8, ENEMY_ABILITY_RANGED_SHOOT, 3, 5, 4)
	make_floor(&g, 5, 5)
	make_floor(&g, 5, 6)
	make_floor(&g, 5, 7)
	make_floor(&g, 5, 8)
	_ = tile_state_set(&g, 5, 8, true, true, 1.0)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	process_enemy_abilities(&msgs, &g)

	lo, hi := damage_roll_bounds(enemy.attack)
	testing.expect(
		t,
		g.player.hp >= 20 - hi && g.player.hp <= 20 - lo,
		"expected player hp reduced by damage_roll(attack) with no armor",
	)
	testing.expect(
		t,
		g.enemies[0].ability_cooldown == g.enemies[0].ability_max_cd,
		"expected cooldown reset after ranged attack",
	)
}

@(test)
ranged_shoot_does_not_fire_when_line_of_sight_is_blocked :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// In range, but a wall at (5,7) blocks line of sight to the player.
	g.player.pos = Vec2{5, 5}
	enemy := make_ability_test_enemy(5, 8, ENEMY_ABILITY_RANGED_SHOOT, 3, 5, 4)
	make_floor(&g, 5, 5)
	make_floor(&g, 5, 6)
	make_floor(&g, 5, 8)
	// (5,7) is left as the default wall, blocking LOS.
	_ = tile_state_set(&g, 5, 8, true, true, 1.0)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	hp_before := g.player.hp
	process_enemy_abilities(&msgs, &g)

	testing.expect_value(t, g.player.hp, hp_before)
}

// ─── Poison cloud (D8) ──────────────────────────────────────────────────────

@(test)
poison_cloud_ability_stamps_a_gas_vent_tile_adjacent_to_the_enemy_when_player_is_in_range :: proc(
	t: ^testing.T,
) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// Player within range (Manhattan 2 <= range 4).
	g.player.pos = Vec2{5, 7}
	enemy := make_ability_test_enemy(5, 5, ENEMY_ABILITY_POISON_CLOUD, 4, 4)
	// Provide an adjacent Floor tile for the gas to vent onto.
	make_floor(&g, 5, 6)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	process_enemy_abilities(&msgs, &g)

	// The adjacent floor tile became a Gas_Vent and the ability went on cooldown.
	venting := tile_at(&g, 5, 6)
	testing.expect(t, venting != nil)
	testing.expect_value(t, venting.type, Tile_Type.Gas_Vent)
	testing.expect_value(t, g.enemies[0].ability_cooldown, 4)
}

@(test)
poison_cloud_ability_does_nothing_when_player_is_out_of_range :: proc(t: ^testing.T) {
	g := make_ability_test_game(20)
	msgs := make_ability_test_messages()

	// Player far away (Manhattan > range 4).
	g.player.pos = Vec2{20, 20}
	enemy := make_ability_test_enemy(5, 5, ENEMY_ABILITY_POISON_CLOUD, 4, 4)
	make_floor(&g, 5, 6)

	append(&g.enemies, enemy)
	defer delete(g.enemies)

	process_enemy_abilities(&msgs, &g)

	// No gas vented; cooldown untouched (decrement-only path also leaves it at 0).
	venting := tile_at(&g, 5, 6)
	testing.expect(t, venting != nil)
	testing.expect_value(t, venting.type, Tile_Type.Floor)
	testing.expect_value(t, g.enemies[0].ability_cooldown, 0)
}
