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

