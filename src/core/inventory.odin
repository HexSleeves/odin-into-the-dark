package core

// Pure inventory helpers — no messages, no engine dependency.

inventory_slot_in_bounds :: proc(slot_index: int) -> bool {
	return slot_index >= 0 && slot_index < MAX_INVENTORY
}

inventory_first_empty_slot :: proc(game: ^Game) -> int {
	if game == nil {return -1}
	for i in 0 ..< MAX_INVENTORY {
		if !game.inventory[i].occupied {return i}
	}
	return -1
}

inventory_put_slot :: proc(game: ^Game, slot_index: int, item: Item, quantity: int = 1) -> bool {
	if game == nil || !inventory_slot_in_bounds(slot_index) {return false}
	game.inventory[slot_index].occupied = true
	game.inventory[slot_index].item = item
	game.inventory[slot_index].item.quantity = quantity
	return true
}

inventory_decrement_slot :: proc(game: ^Game, slot_index: int, amount: int = 1) -> bool {
	if game == nil || !inventory_slot_in_bounds(slot_index) {return false}
	if !game.inventory[slot_index].occupied {return false}
	game.inventory[slot_index].item.quantity -= amount
	if game.inventory[slot_index].item.quantity <= 0 {
		game.inventory[slot_index] = {}
	}
	return true
}

inventory_count_item_type :: proc(game: ^Game, item_type: string) -> int {
	if game == nil {return 0}
	total := 0
	for i in 0 ..< MAX_INVENTORY {
		if game.inventory[i].occupied && game.inventory[i].item.item_type == item_type {
			total += game.inventory[i].item.quantity
		}
	}
	return total
}

inventory_consume_item_type :: proc(game: ^Game, item_type: string, amount: int) -> bool {
	if game == nil || amount <= 0 {return false}
	if inventory_count_item_type(game, item_type) < amount {return false}
	remaining := amount
	for i in 0 ..< MAX_INVENTORY {
		if remaining <= 0 {break}
		if !game.inventory[i].occupied {continue}
		if game.inventory[i].item.item_type != item_type {continue}
		take := min(game.inventory[i].item.quantity, remaining)
		remaining -= take
		inventory_decrement_slot(game, i, take)
	}
	return true
}

remove_item_from_inventory :: proc(game: ^Game, item_type: string) -> bool {
	return inventory_consume_item_type(game, item_type, 1)
}
