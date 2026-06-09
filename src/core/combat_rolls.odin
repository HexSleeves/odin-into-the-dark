package core

import "core:math/rand"

// Combat roll helpers. All randomness flows through context.random_generator,
// which game_init seeds via rand.reset(seed) — seeded runs stay reproducible.

// damage_roll applies DAMAGE_VARIANCE_MIN/MAX_PCT variance to base damage.
// Always returns at least 1 for a positive base.
damage_roll :: proc(base: int) -> int {
	if base <= 0 {return 0}
	span := DAMAGE_VARIANCE_MAX_PCT - DAMAGE_VARIANCE_MIN_PCT
	pct := DAMAGE_VARIANCE_MIN_PCT + rand.int_max(span + 1)
	return max(base * pct / 100, 1)
}

// damage_roll_bounds returns the inclusive min/max damage_roll can produce
// for a base value — used by tests and UI previews.
damage_roll_bounds :: proc(base: int) -> (lo, hi: int) {
	if base <= 0 {return 0, 0}
	return max(base * DAMAGE_VARIANCE_MIN_PCT / 100, 1),
		max(base * DAMAGE_VARIANCE_MAX_PCT / 100, 1)
}

crit_roll :: proc(chance_pct: int) -> bool {
	if chance_pct <= 0 {return false}
	return rand.int_max(100) < chance_pct
}

// Player crit chance: unarmed base plus the equipped weapon's crit_chance.
effective_crit_chance :: proc(game: ^Game) -> int {
	bonus := 0
	if game.equipped_weapon.occupied {bonus = game.equipped_weapon.item.crit_chance}
	return BASE_CRIT_CHANCE_PCT + bonus
}
