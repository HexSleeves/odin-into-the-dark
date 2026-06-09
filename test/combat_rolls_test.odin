package main

import "core:math/rand"
import "core:testing"

// ─── damage_roll ──────────────────────────────────────────────────────────────

@(test)
damage_roll_returns_zero_for_non_positive_base :: proc(t: ^testing.T) {
	testing.expect_value(t, damage_roll(0), 0)
	testing.expect_value(t, damage_roll(-5), 0)
}

@(test)
damage_roll_stays_within_variance_bounds :: proc(t: ^testing.T) {
	rand.reset(0xDEADBEEF)
	base := 10
	lo, hi := damage_roll_bounds(base)
	testing.expect_value(t, lo, base * DAMAGE_VARIANCE_MIN_PCT / 100)
	testing.expect_value(t, hi, base * DAMAGE_VARIANCE_MAX_PCT / 100)
	for _ in 0 ..< 1000 {
		d := damage_roll(base)
		testing.expect(t, d >= lo && d <= hi)
	}
}

@(test)
damage_roll_never_returns_less_than_one_for_positive_base :: proc(t: ^testing.T) {
	rand.reset(0xDEADBEEF)
	for _ in 0 ..< 1000 {
		testing.expect(t, damage_roll(1) >= 1)
	}
}

@(test)
damage_roll_is_deterministic_for_same_seed :: proc(t: ^testing.T) {
	rand.reset(42)
	first: [16]int
	for i in 0 ..< len(first) {
		first[i] = damage_roll(20)
	}
	rand.reset(42)
	for i in 0 ..< len(first) {
		testing.expect_value(t, damage_roll(20), first[i])
	}
}

// ─── crit_roll ────────────────────────────────────────────────────────────────

@(test)
crit_roll_never_fires_at_zero_chance :: proc(t: ^testing.T) {
	rand.reset(0xDEADBEEF)
	for _ in 0 ..< 1000 {
		testing.expect(t, !crit_roll(0))
	}
}

@(test)
crit_roll_always_fires_at_full_chance :: proc(t: ^testing.T) {
	rand.reset(0xDEADBEEF)
	for _ in 0 ..< 1000 {
		testing.expect(t, crit_roll(100))
	}
}

// ─── effective_crit_chance ────────────────────────────────────────────────────

@(test)
effective_crit_chance_is_base_when_unarmed :: proc(t: ^testing.T) {
	g := make_combat_test_game()

	testing.expect_value(t, effective_crit_chance(&g), BASE_CRIT_CHANCE_PCT)
}

@(test)
effective_crit_chance_adds_equipped_weapon_bonus :: proc(t: ^testing.T) {
	g := make_combat_test_game()
	g.equipped_weapon.occupied = true
	g.equipped_weapon.item.crit_chance = 15

	testing.expect_value(t, effective_crit_chance(&g), BASE_CRIT_CHANCE_PCT + 15)
}

@(test)
item_defs_carry_crit_chance_into_made_items :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	def := content_manager_item_def(&content, "mine_dagger")
	testing.expect(t, def != nil)
	testing.expect(t, def.crit_chance > 0)

	it := item_make_from_def(def, Vec2{0, 0})
	testing.expect_value(t, it.crit_chance, def.crit_chance)
}
