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

// ─── Equipment: equip / unequip ───────────────────────────────────────────────

equip_item :: proc(messages: ^Message_Manager, game: ^Game, slot_index: int) -> bool {
	if !inventory_slot_in_bounds(slot_index) {return false}
	if !game.inventory[slot_index].occupied {return false}

	item := &game.inventory[slot_index].item
	if item.equipment_slot == "" {
		add_message(
			messages,
			game,
			"That item cannot be equipped.",
			eng.Engine_Color{180, 180, 180, 255},
		)
		return false
	}

	equip_slot := game_equipment_slot(game, item.equipment_slot)
	if equip_slot == nil {
		add_message(
			messages,
			game,
			"Unknown equipment slot.",
			eng.Engine_Color{180, 180, 180, 255},
		)
		return false
	}

	if equip_slot.occupied {
		empty := inventory_first_empty_slot(game)
		if empty < 0 {
			add_message(
				messages,
				game,
				"No inventory space to swap equipment!",
				eng.Engine_Color{255, 100, 100, 255},
			)
			return false
		}
		inventory_put_slot(game, empty, equip_slot.item, 1)
		add_message(
			messages,
			game,
			fmt.tprintf("You unequip the %s.", item_display_name(&equip_slot.item)),
			eng.Engine_Color{180, 180, 100, 255},
		)
	}

	equip_slot.occupied = true
	equip_slot.item = item^
	add_message(
		messages,
		game,
		fmt.tprintf("You equip the %s.", item_display_name(item)),
		eng.Engine_Color{100, 200, 255, 255},
	)
	game.inventory[slot_index] = {}
	return true
}

unequip_slot :: proc(messages: ^Message_Manager, game: ^Game, slot_name: string) -> bool {
	equip_slot := game_equipment_slot(game, slot_name)
	if equip_slot == nil {return false}
	if !equip_slot.occupied {return false}

	empty := inventory_first_empty_slot(game)
	if empty < 0 {
		add_message(
			messages,
			game,
			"Inventory full! Cannot unequip.",
			eng.Engine_Color{255, 100, 100, 255},
		)
		return false
	}

	inventory_put_slot(game, empty, equip_slot.item, 1)
	add_message(
		messages,
		game,
		fmt.tprintf("You unequip the %s.", item_display_name(&equip_slot.item)),
		eng.Engine_Color{180, 180, 100, 255},
	)
	equip_slot^ = {}
	return true
}
