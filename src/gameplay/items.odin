package gameplay

import gcore "../core"
import eng "../engine"
import "core:fmt"

// item_make creates an Item from a content ID, with fallback for unknown IDs.
item_make :: proc(content: ^Content_Manager, id: string, pos: Vec2) -> Item {
	def := content_manager_item_def(content, id)
	if def != nil {
		return item_make_from_def(def, pos)
	}
	logger_warnf(.Items, "unknown item id '%s'", id)
	return Item {
		pos = pos,
		item_type = id,
		name = id,
		glyph = '?',
		color = eng.Engine_Color{255, 255, 255, 255},
		picked_up = false,
		quantity = 1,
	}
}

// ─── Pick up item at player position ──────────────────────────────────────────

pickup_item :: proc(content: ^Content_Manager, messages: ^Message_Manager, game: ^Game) -> bool {
	it := item_at(game, game.player.pos.x, game.player.pos.y)
	if it == nil {
		add_message(
			messages,
			game,
			"Nothing to pick up here.",
			eng.Engine_Color{180, 180, 180, 255},
		)
		return false
	}

	// The Ancient Treasure completes the quest goal on pickup.
	if it.item_type == ITEM_ID_ANCIENT_TREASURE {
		it.picked_up = true
		game.items_found += 1
		game.quest = .Treasure_Found
		add_message(
			messages,
			game,
			"You claim the Ancient Treasure! Return to the surface for your reward.",
			eng.Engine_Color{255, 215, 0, 255},
		)
		return true
	}

	itype := it.item_type
	stack_limit := item_stack_limit(content, itype)
	if item_is_stackable(content, itype) {
		for i in 0 ..< MAX_INVENTORY {
			slot := &game.inventory[i]
			if slot.occupied && slot.item.item_type == itype && slot.item.quantity < stack_limit {
				// Transfer as much of the ground item's quantity as fits.
				// Remainder (if any) falls through to the next stack/empty slot.
				room := stack_limit - slot.item.quantity
				moved := min(room, it.quantity)
				slot.item.quantity += moved
				it.quantity -= moved
				if it.quantity <= 0 {
					it.picked_up = true
					game.items_found += 1
					add_message(
						messages,
						game,
						fmt.tprintf(
							"Picked up %s (%d/%d).",
							item_display_name(it),
							slot.item.quantity,
							stack_limit,
						),
						eng.Engine_Color{100, 255, 100, 255},
					)
					return true
				}
			}
		}
	}

	slot_idx := inventory_first_empty_slot(game)
	if slot_idx < 0 {
		add_message(messages, game, "Inventory is full!", eng.Engine_Color{255, 100, 100, 255})
		return false
	}

	inventory_put_slot(game, slot_idx, it^)
	it.picked_up = true
	game.items_found += 1
	add_message(
		messages,
		game,
		fmt.tprintf("Picked up %s.", item_display_name(it)),
		eng.Engine_Color{100, 255, 100, 255},
	)
	return true
}

// ─── Use an item from inventory (data-driven) ────────────────────────────────

use_item :: proc(
	content: ^Content_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	slot_index: int,
	engine: ^eng.Engine = nil,
) -> bool {
	if !inventory_slot_in_bounds(slot_index) {return false}
	if !game.inventory[slot_index].occupied {return false}

	itype := game.inventory[slot_index].item.item_type
	def := content_manager_item_def(content, itype)
	if def == nil {
		add_message(messages, game, "Nothing happens.", eng.Engine_Color{180, 180, 180, 255})
		return false
	}
	if def.effect.type == ITEM_EFFECT_EQUIP {
		add_message(
			messages,
			game,
			fmt.tprintf("Press E in inventory to equip the %s.", def.name),
			eng.Engine_Color{180, 180, 180, 255},
		)
		return false
	}
	if def.effect.type == ITEM_EFFECT_MATERIAL {
		add_message(
			messages,
			game,
			"Raw materials cannot be used directly. Find an anvil to craft.",
			eng.Engine_Color{180, 180, 100, 255},
		)
		return false
	}

	apply_item_effect(messages, game, def)
	if engine != nil {
		cam := game_engine_camera_manager(engine)
		particles := game_engine_particle_manager(engine)
		if def.effect.type == ITEM_EFFECT_HEAL ||
		   def.effect.type == ITEM_EFFECT_TIMED_LIGHT_BOOST {
			spawn_pickup_particles(
				particles,
				game.player.pos.x,
				game.player.pos.y,
				game_camera_x(cam),
				game_camera_y(cam),
			)
		}
	}
	inventory_decrement_slot(game, slot_index)
	return true
}

// ─── Drop an item from inventory ──────────────────────────────────────────────

drop_item :: proc(messages: ^Message_Manager, game: ^Game, slot_index: int) -> bool {
	if !inventory_slot_in_bounds(slot_index) {return false}
	if !game.inventory[slot_index].occupied {return false}

	slot := &game.inventory[slot_index]
	dropped := Item {
		pos       = game.player.pos,
		item_type = slot.item.item_type,
		name      = slot.item.name,
		glyph     = slot.item.glyph,
		color     = slot.item.color,
		picked_up = false,
		quantity  = 1,
	}
	append(&game.items, dropped)
	add_message(
		messages,
		game,
		fmt.tprintf("You drop a %s.", item_display_name(&slot.item)),
		eng.Engine_Color{180, 180, 100, 255},
	)
	inventory_decrement_slot(game, slot_index)
	return true
}

// ─── Data-driven item use ─────────────────────────────────────────────────────

apply_item_effect :: proc(messages: ^Message_Manager, game: ^Game, def: ^gcore.Item_Def) {
	eff := &def.effect

	if eff.type == ITEM_EFFECT_HEAL {
		actual_heal := min(eff.value, game.player.max_hp - game.player.hp)
		game.player.hp = min(game.player.hp + eff.value, game.player.max_hp)
		add_message(
			messages,
			game,
			fmt.tprintf("You use a %s. Restored %d HP.", def.name, actual_heal),
			eng.Engine_Color{100, 255, 100, 255},
		)
	} else if eff.type == ITEM_EFFECT_LIGHT_BOOST {
		max_r := eff.max_radius
		if max_r <= 0 {max_r = 10}
		game.player.light_radius = min(game.player.light_radius + eff.value, max_r)
		add_message(
			messages,
			game,
			fmt.tprintf("You use a %s. Light radius increased.", def.name),
			eng.Engine_Color{255, 180, 50, 255},
		)
	} else if eff.type == ITEM_EFFECT_TIMED_LIGHT_BOOST {
		game.light_boost_bonus = eff.value
		game.light_boost_turns = eff.duration
		// Reset the drain timer so the boost starts from a clean interval —
		// prevents light from draining the same turn the oil wears off.
		game.light_drain_timer = 0
		add_message(
			messages,
			game,
			"You apply lantern oil. Light burns brighter!",
			eng.Engine_Color{255, 200, 80, 255},
		)
	} else if eff.type == ITEM_EFFECT_EQUIP {
		add_message(
			messages,
			game,
			fmt.tprintf("Press E in inventory to equip the %s.", def.name),
			eng.Engine_Color{180, 180, 180, 255},
		)
	} else if eff.type == ITEM_EFFECT_MATERIAL {
		add_message(
			messages,
			game,
			"Raw materials cannot be used directly. Find an anvil to craft.",
			eng.Engine_Color{180, 180, 100, 255},
		)
	} else if eff.type == ITEM_EFFECT_CURE_POISON {
		if status_active(&game.player_status, .Poison) {
			game.player_status[.Poison] = 0
			add_message(
				messages,
				game,
				"You drink the antidote. Poison cured!",
				eng.Engine_Color{120, 220, 80, 255},
			)
		} else {
			add_message(
				messages,
				game,
				"You drink the antidote. (You weren't poisoned)",
				eng.Engine_Color{120, 220, 80, 255},
			)
		}
	} else {
		add_message(
			messages,
			game,
			fmt.tprintf("You use a %s. Nothing happens.", def.name),
			eng.Engine_Color{180, 180, 180, 255},
		)
	}
}

// ─── Equipment ────────────────────────────────────────────────────────────────

give_starter_gear :: proc(content: ^Content_Manager, game: ^Game) {
	pick_def := content_manager_item_def(content, ITEM_ID_RUSTY_PICKAXE)
	if pick_def != nil {
		pick := item_make_from_def(pick_def, Vec2{0, 0})
		pick.picked_up = true
		game.equipped_weapon = Equipment {
			occupied = true,
			item     = pick,
		}
	}

	torch_def := content_manager_item_def(content, ITEM_ID_TORCH)
	if torch_def != nil {
		torch := item_make_from_def(torch_def, Vec2{0, 0})
		torch.picked_up = true
		inventory_put_slot(game, 0, torch, 1)
	}

	band_def := content_manager_item_def(content, ITEM_ID_BANDAGE)
	if band_def != nil {
		band := item_make_from_def(band_def, Vec2{0, 0})
		band.picked_up = true
		inventory_put_slot(game, 1, band, 2)
	}

	// Starter armor: gives effective_defense 1 from turn one so the early floors
	// are not a flat damage race against spike abilities.
	vest_def := content_manager_item_def(content, ITEM_ID_LEATHER_VEST)
	if vest_def != nil {
		vest := item_make_from_def(vest_def, Vec2{0, 0})
		vest.picked_up = true
		game.equipped_armor = Equipment {
			occupied = true,
			item     = vest,
		}
	}
}

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
