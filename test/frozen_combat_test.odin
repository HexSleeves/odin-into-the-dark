package main

import "core:math/rand"
import "core:testing"

// ─── Frozen affects combat (Audit #23) ───────────────────────────────────────
//
// Frozen no longer only doubles movement cost: a frozen attacker has a chance to
// skip its swing entirely, and any landed hit deals reduced damage. These tests
// pin both behaviors with bounded + aggregate assertions over a seeded RNG.

// frozen_combat_test_enemy builds a high-attack enemy so the damage signal is
// large relative to the floor-at-1 clamp.
@(private = "file")
frozen_combat_test_enemy :: proc(frozen: bool) -> Enemy {
	e: Enemy
	e.hp = 10
	e.max_hp = 10
	e.attack = 40
	e.crit_chance = 0
	e.alive = true
	e.name = "ice wraith"
	if frozen {e.status[.Frozen] = 5}
	return e
}

@(private = "file")
frozen_combat_test_game :: proc() -> Game {
	g: Game
	g.state = .Playing
	g.player.hp = 1_000_000
	g.player.max_hp = 1_000_000
	return g
}

@(test)
frozen_enemy_landed_hit_is_capped_at_the_reduced_damage_band :: proc(t: ^testing.T) {
	// Every landed frozen hit must be <= the reduced-damage upper bound. No
	// defense is equipped, so the only reduction is the frozen damage scale.
	rand.reset(0xF0F0F0)
	_, hi := damage_roll_bounds(40)
	frozen_hit_cap := max(hi * CRIT_DAMAGE_MULT_PCT / 100 * FROZEN_DAMAGE_PCT / 100, 1)

	msgs := make_combat_test_messages()
	for _ in 0 ..< 200 {
		g := frozen_combat_test_game()
		e := frozen_combat_test_enemy(frozen = true)
		before := g.player.hp
		resolve_attack_enemy_on_player(&msgs, &g, &e)
		dealt := before - g.player.hp
		testing.expect(t, dealt >= 0, "frozen hit cannot heal the player")
		testing.expect(
			t,
			dealt <= frozen_hit_cap,
			"frozen landed hit must not exceed the reduced-damage cap",
		)
	}
}

@(test)
frozen_enemy_sometimes_skips_its_swing :: proc(t: ^testing.T) {
	// Over many swings a frozen enemy must skip at least once (deal 0 damage),
	// which an unfrozen enemy with the same attack can never do (floored at 1).
	rand.reset(0xBEEF11)
	msgs := make_combat_test_messages()

	skipped := 0
	for _ in 0 ..< 300 {
		g := frozen_combat_test_game()
		e := frozen_combat_test_enemy(frozen = true)
		before := g.player.hp
		resolve_attack_enemy_on_player(&msgs, &g, &e)
		if before - g.player.hp == 0 {skipped += 1}
	}
	testing.expect(t, skipped > 0, "a frozen enemy must occasionally skip its swing")
}

@(test)
frozen_enemy_deals_less_total_damage_than_an_unfrozen_one :: proc(t: ^testing.T) {
	// Aggregate damage over many identical swings: the frozen path (skip chance +
	// halved hits) must deal strictly less total than the unfrozen path.
	TRIALS :: 400

	rand.reset(0x5151)
	msgs := make_combat_test_messages()
	frozen_total := 0
	for _ in 0 ..< TRIALS {
		g := frozen_combat_test_game()
		e := frozen_combat_test_enemy(frozen = true)
		before := g.player.hp
		resolve_attack_enemy_on_player(&msgs, &g, &e)
		frozen_total += before - g.player.hp
	}

	rand.reset(0x5151)
	unfrozen_total := 0
	for _ in 0 ..< TRIALS {
		g := frozen_combat_test_game()
		e := frozen_combat_test_enemy(frozen = false)
		before := g.player.hp
		resolve_attack_enemy_on_player(&msgs, &g, &e)
		unfrozen_total += before - g.player.hp
	}

	testing.expect(
		t,
		frozen_total < unfrozen_total,
		"frozen enemies must deal less total combat damage than unfrozen ones",
	)
}
