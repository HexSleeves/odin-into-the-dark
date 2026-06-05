package main

import eng "./engine"
import "core:fmt"

// ─── Starter gear ─────────────────────────────────────────────────────────────

give_starter_gear :: proc(content: ^Content_Manager, game: ^Game) {
	// Equip a Rusty Pickaxe directly into the weapon slot
	pick_def := content_manager_item_def(content, ITEM_ID_RUSTY_PICKAXE)
	if pick_def != nil {
		pick := item_make_from_def(pick_def, Vec2{0, 0})
		pick.picked_up = true
		game.equipped_weapon = Equipment {
			occupied = true,
			item     = pick,
		}
	}

	// Put a Torch in inventory slot 0
	torch_def := content_manager_item_def(content, ITEM_ID_TORCH)
	if torch_def != nil {
		torch := item_make_from_def(torch_def, Vec2{0, 0})
		torch.picked_up = true
		inventory_put_slot(game, 0, torch, 1)
	}

	// Put 2 Bandages in inventory slot 1
	band_def := content_manager_item_def(content, ITEM_ID_BANDAGE)
	if band_def != nil {
		band := item_make_from_def(band_def, Vec2{0, 0})
		band.picked_up = true
		inventory_put_slot(game, 1, band, 2)
	}
}

// ─── Equipment: equip / unequip / stat queries ────────────────────────────────

game_equipment_slot :: proc(game: ^Game, slot_name: string) -> ^Equipment {
	if game == nil {return nil}
	if slot_name == EQUIPMENT_SLOT_WEAPON {return &game.equipped_weapon}
	if slot_name == EQUIPMENT_SLOT_ARMOR {return &game.equipped_armor}
	if slot_name == EQUIPMENT_SLOT_HELMET {return &game.equipped_helmet}
	return nil
}

equip_item :: proc(messages: ^Message_Manager, game: ^Game, slot_index: int) -> bool {
	if !inventory_slot_in_bounds(slot_index) {return false}
	if !game.inventory[slot_index].occupied {return false}

	item := &game.inventory[slot_index].item
	if item.equipment_slot == "" {
		add_message(messages, game, "That item cannot be equipped.", eng.Engine_Color{180, 180, 180, 255})
		return false
	}

	equip_slot := game_equipment_slot(game, item.equipment_slot)
	if equip_slot == nil {
		add_message(messages, game, "Unknown equipment slot.", eng.Engine_Color{180, 180, 180, 255})
		return false
	}

	if equip_slot.occupied {
		empty := inventory_first_empty_slot(game)
		if empty < 0 {
			add_message(messages, game, "No inventory space to swap equipment!", eng.Engine_Color{255, 100, 100, 255})
			return false
		}
		inventory_put_slot(game, empty, equip_slot.item, 1)
		add_message(messages, game, fmt.tprintf("You unequip the %s.", item_display_name(&equip_slot.item)), eng.Engine_Color{180, 180, 100, 255})
	}

	equip_slot.occupied = true
	equip_slot.item = item^
	add_message(messages, game, fmt.tprintf("You equip the %s.", item_display_name(item)), eng.Engine_Color{100, 200, 255, 255})
	game.inventory[slot_index] = {}
	return true
}

unequip_slot :: proc(messages: ^Message_Manager, game: ^Game, slot_name: string) -> bool {
	equip_slot := game_equipment_slot(game, slot_name)
	if equip_slot == nil {return false}
	if !equip_slot.occupied {return false}

	empty := inventory_first_empty_slot(game)
	if empty < 0 {
		add_message(messages, game, "Inventory full! Cannot unequip.", eng.Engine_Color{255, 100, 100, 255})
		return false
	}

	inventory_put_slot(game, empty, equip_slot.item, 1)
	add_message(messages, game, fmt.tprintf("You unequip the %s.", item_display_name(&equip_slot.item)), eng.Engine_Color{180, 180, 100, 255})
	equip_slot^ = {}
	return true
}

// ─── Effective stat queries (used by combat + fov) ────────────────────────────

effective_attack :: proc(game: ^Game) -> int {
	bonus := 0
	if game.equipped_weapon.occupied {bonus = game.equipped_weapon.item.stat_bonus}
	return game.player.attack + bonus
}

effective_defense :: proc(game: ^Game) -> int {
	if game.equipped_armor.occupied {return game.equipped_armor.item.stat_bonus}
	return 0
}

effective_light_bonus :: proc(game: ^Game) -> int {
	if game.equipped_helmet.occupied {return game.equipped_helmet.item.stat_bonus}
	return 0
}

// Returns the AP cost to attack with the currently equipped weapon.
// Weapons with action_cost > 0 in data use that value; otherwise BASE_ACTION_COST.
effective_attack_cost :: proc(game: ^Game) -> int {
	if game.equipped_weapon.occupied && game.equipped_weapon.item.action_cost > 0 {
		return game.equipped_weapon.item.action_cost
	}
	return BASE_ACTION_COST
}
