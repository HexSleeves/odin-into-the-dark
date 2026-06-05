package main

import "core:fmt"

import eng "./engine"

// ─── Item factory (data-driven) ───────────────────────────────────────────────

item_make :: proc(content: ^Content_Manager, id: string, pos: Vec2) -> Item {
	def := content_manager_item_def(content, id)
	if def != nil {
		return item_make_from_def(def, pos)
	}
	// Fallback: unknown item
	logger_warnf(.Items, "unknown item id '%s'", id)
	return Item {
		pos       = pos,
		item_type = id,
		name      = id,
		glyph     = '?',
		color     = eng.Engine_Color{255, 255, 255, 255},
		picked_up = false,
		quantity  = 1,
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

	itype := it.item_type
	stack_limit := item_stack_limit(content, itype)
	if item_is_stackable(content, itype) {
		for i in 0 ..< MAX_INVENTORY {
			slot := &game.inventory[i]
			if slot.occupied && slot.item.item_type == itype && slot.item.quantity < stack_limit {
				slot.item.quantity += 1
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
