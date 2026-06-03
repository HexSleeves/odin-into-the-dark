package engine

Turn_Manager :: struct {
	count: int,
}

turn_manager_make :: proc() -> Turn_Manager {
	return Turn_Manager{}
}

turn_manager_current :: proc(turns: ^Turn_Manager) -> int {
	if turns == nil {
		return 0
	}
	return turns.count
}

turn_manager_advance :: proc(turns: ^Turn_Manager) -> int {
	if turns == nil {
		return 0
	}
	turns.count += 1
	return turns.count
}

turn_manager_set :: proc(turns: ^Turn_Manager, count: int) {
	if turns == nil {
		return
	}
	turns.count = max(count, 0)
}

turn_manager_reset :: proc(turns: ^Turn_Manager) {
	turn_manager_set(turns, 0)
}

// ─── Energy Actor (Qud-style AP system) ───────────────────────────────────────────

// Energy_Actor holds the AP-system fields shared by Player and Enemy.
// quickness * 10 AP are granted each round (base QN=100 → 1000 AP/round).
// Action costs are deducted from energy; negative energy → AP debt carried over.
Energy_Actor :: struct {
	energy:     int, // current action points (may be negative = debt)
	quickness:  int, // AP generated per round = quickness * 10
	move_speed: int, // movement cost modifier (100 = normal, 50 = fast, 150 = slow)
}

// Grant one round's worth of AP to an actor.
energy_actor_grant :: proc(actor: ^Energy_Actor) {
	actor.energy += actor.quickness * 10
}

// Spend AP for an action. Energy may go negative (debt).
energy_actor_spend :: proc(actor: ^Energy_Actor, cost: int) {
	actor.energy -= cost
}

// Returns true when the actor has AP remaining to act.
energy_actor_can_act :: proc(actor: ^Energy_Actor) -> bool {
	return actor.energy > 0
}
