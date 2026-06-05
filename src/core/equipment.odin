package core

// Pure equipment stat queries — no messages, no engine.

game_equipment_slot :: proc(game: ^Game, slot_name: string) -> ^Equipment {
	if game == nil {return nil}
	if slot_name == EQUIPMENT_SLOT_WEAPON {return &game.equipped_weapon}
	if slot_name == EQUIPMENT_SLOT_ARMOR {return &game.equipped_armor}
	if slot_name == EQUIPMENT_SLOT_HELMET {return &game.equipped_helmet}
	return nil
}

effective_attack :: proc(game: ^Game) -> int {
	bonus := 0
	if game.equipped_weapon.occupied {bonus = game.equipped_weapon.item.stat_bonus}
	return game.player.attack + bonus
}

effective_defense :: proc(game: ^Game) -> int {
	if game.equipped_armor.occupied {return game.equipped_armor.item.stat_bonus}
	return 0
}
