package main

import eng "./engine"
import "core:fmt"

// ─── Mining ───────────────────────────────────────────────────────────────────

mineable_tile_type :: proc(tile_type: Tile_Type) -> bool {
	#partial switch tile_type {
	case .Wall, .Gas_Vent, .Fire_Vent, .Unstable:
		return true
	}
	return false
}

mine_wall :: proc(
	content: ^Content_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	dx, dy: int,
) -> bool {
	tx := game.player.pos.x + dx
	ty := game.player.pos.y + dy

	// Check bounds
	if tx < 0 || tx >= MAP_WIDTH || ty < 0 || ty >= MAP_HEIGHT {return false}

	t := tile_at(game, tx, ty)
	if t == nil || !mineable_tile_type(t.type) {
		add_message(messages, game, "Nothing to mine there.", eng.Engine_Color{180, 180, 180, 255})
		return false
	}

	// Check pickaxe — need an equipped weapon with durability
	if !game.equipped_weapon.occupied {
		add_message(
			messages,
			game,
			"You need a pickaxe to mine!",
			eng.Engine_Color{255, 100, 100, 255},
		)
		return false
	}
	wpn := &game.equipped_weapon.item
	if wpn.max_durability > 0 && wpn.durability <= 0 {
		add_message(
			messages,
			game,
			fmt.tprintf("Your %s is broken!", wpn.name),
			eng.Engine_Color{255, 100, 100, 255},
		)
		return false
	}

	// Mine the wall
	idx := pos_to_idx(tx, ty)
	mined_tile_type := t.type
	vein := game.ore_veins[idx]

	// Convert wall to rubble
	t.type = .Rubble

	// If ore vein, spawn material item
	if vein.ore_type != "" {
		def := content_manager_item_def(content, vein.ore_type)
		if def != nil {
			ore_item := item_make_from_def(def, Vec2{tx, ty})
			append(&game.items, ore_item)
			add_message(messages, game, fmt.tprintf("You found %s!", def.name), vein.color)
		} else {
			add_message(
				messages,
				game,
				"You mine through a vein, but nothing useful falls out.",
				eng.Engine_Color{180, 160, 100, 255},
			)
		}
		game.ore_veins[idx] = {} // clear the vein
	} else {
		msg := "You mine through the wall."
		#partial switch mined_tile_type {
		case .Gas_Vent:
			msg = "You collapse the gas vent."
		case .Fire_Vent:
			msg = "You collapse the fire vent."
		case .Unstable:
			msg = "You break the unstable ground into rubble."
		}
		add_message(messages, game, msg, eng.Engine_Color{180, 160, 100, 255})
	}

	// Decrease equipped weapon durability
	if wpn.max_durability > 0 {
		wpn.durability -= 1
		if wpn.durability <= 0 {
			add_message(
				messages,
				game,
				fmt.tprintf("Your %s breaks!", wpn.name),
				eng.Engine_Color{255, 80, 80, 255},
			)
		} else if wpn.durability <= 5 {
			add_message(
				messages,
				game,
				fmt.tprintf(
					"%s wearing down... (%d/%d)",
					wpn.name,
					wpn.durability,
					wpn.max_durability,
				),
				eng.Engine_Color{255, 180, 50, 255},
			)
		}
	}

	return true
}

// ─── Crafting recipes ─────────────────────────────────────────────────────────

Recipe :: struct {
	name:         string,
	material_id:  string,
	material_qty: int,
	result_id:    string, // "" means special (like pickaxe repair)
	is_repair:    bool,
}

RECIPES :: [4]Recipe {
	{
		name = "Repair Pickaxe",
		material_id = "iron_ore",
		material_qty = 3,
		result_id = "",
		is_repair = true,
	},
	{
		name = "Copper Shield",
		material_id = "copper_ore",
		material_qty = 2,
		result_id = "copper_shield",
		is_repair = false,
	},
	{
		name = "Crystal Torch",
		material_id = "crystal_shard",
		material_qty = 2,
		result_id = "crystal_torch",
		is_repair = false,
	},
	{
		name = "Golden Amulet",
		material_id = "gold_nugget",
		material_qty = 1,
		result_id = "golden_amulet",
		is_repair = false,
	},
}

// Count how many of a material the player has in inventory
count_material :: proc(game: ^Game, material_id: string) -> int {
	total := 0
	for i in 0 ..< MAX_INVENTORY {
		if game.inventory[i].occupied && game.inventory[i].item.item_type == material_id {
			total += game.inventory[i].item.quantity
		}
	}
	return total
}

// Consume N of a material from inventory
consume_material :: proc(game: ^Game, material_id: string, amount: int) {
	remaining := amount
	for i in 0 ..< MAX_INVENTORY {
		if remaining <= 0 {break}
		if !game.inventory[i].occupied {continue}
		if game.inventory[i].item.item_type != material_id {continue}

		take := min(game.inventory[i].item.quantity, remaining)
		game.inventory[i].item.quantity -= take
		remaining -= take
		if game.inventory[i].item.quantity <= 0 {
			game.inventory[i] = {}
		}
	}
}

try_craft :: proc(
	content: ^Content_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	recipe_index: int,
) {
	if recipe_index < 0 || recipe_index >= len(RECIPES) {return}

	recipes := RECIPES
	recipe := recipes[recipe_index]
	have := count_material(game, recipe.material_id)

	if have < recipe.material_qty {
		add_message(
			messages,
			game,
			fmt.tprintf("Need %d %s (have %d).", recipe.material_qty, recipe.material_id, have),
			eng.Engine_Color{255, 100, 100, 255},
		)
		return
	}

	if recipe.is_repair {
		// Repair equipped weapon durability
		if !game.equipped_weapon.occupied || game.equipped_weapon.item.max_durability <= 0 {
			add_message(
				messages,
				game,
				"No weapon to repair.",
				eng.Engine_Color{255, 100, 100, 255},
			)
			return
		}
		game.equipped_weapon.item.durability = game.equipped_weapon.item.max_durability
		consume_material(game, recipe.material_id, recipe.material_qty)
		add_message(
			messages,
			game,
			fmt.tprintf("%s repaired!", game.equipped_weapon.item.name),
			eng.Engine_Color{100, 255, 100, 255},
		)
		return
	}

	// Find empty inventory slot for crafted item
	slot_idx := -1
	for i in 0 ..< MAX_INVENTORY {
		if !game.inventory[i].occupied {
			slot_idx = i
			break
		}
	}
	if slot_idx < 0 {
		add_message(
			messages,
			game,
			"Inventory full! Cannot craft.",
			eng.Engine_Color{255, 100, 100, 255},
		)
		return
	}

	def := content_manager_item_def(content, recipe.result_id)
	if def == nil {
		add_message(messages, game, "Recipe error.", eng.Engine_Color{255, 100, 100, 255})
		return
	}

	consume_material(game, recipe.material_id, recipe.material_qty)
	crafted := item_make_from_def(def, Vec2{0, 0})
	crafted.picked_up = true
	game.inventory[slot_idx].occupied = true
	game.inventory[slot_idx].item = crafted
	game.inventory[slot_idx].item.quantity = 1

	add_message(
		messages,
		game,
		fmt.tprintf("Crafted %s!", def.name),
		eng.Engine_Color{100, 255, 100, 255},
	)
}
