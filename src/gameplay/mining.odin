package gameplay

import gcore "../core"
import eng "../engine"
import "core:fmt"

Recipe :: gcore.Recipe
RECIPES :: gcore.RECIPES

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

	if tx < 0 || tx >= MAP_WIDTH || ty < 0 || ty >= MAP_HEIGHT {return false}

	t := tile_at(game, tx, ty)
	if t == nil || !mineable_tile_type(t.type) {
		add_message(messages, game, "Nothing to mine there.", eng.Engine_Color{180, 180, 180, 255})
		return false
	}

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

	idx := pos_to_idx(tx, ty)
	mined_tile_type := t.type
	vein := game.ore_veins[idx]
	t.type = .Rubble

	if vein.ore_type != "" {
		def := content_manager_item_def(content, vein.ore_type)
		if def != nil {
			ore_item := item_make_from_def(def, Vec2{tx, ty})
			append(&game.items, ore_item)
			add_message(messages, game, fmt.tprintf("You found %s!", def.name), vein.color)
			tutorial_hint_once(
				messages,
				game,
				.First_Ore,
				"Ore drops to the ground where you mined. Step onto it and press G to pick it up.",
				eng.Engine_Color{255, 220, 130, 255},
			)
		} else {
			add_message(
				messages,
				game,
				"You mine through a vein, but nothing useful falls out.",
				eng.Engine_Color{180, 160, 100, 255},
			)
		}
		game.ore_veins[idx] = {}
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

	if wpn.max_durability > 0 {
		wpn.durability -= 1
		if wpn.durability <= 0 {
			add_message(
				messages,
				game,
				fmt.tprintf("Your %s breaks!", wpn.name),
				eng.Engine_Color{255, 80, 80, 255},
			)
		} else if wpn.durability <= DURABILITY_WARN_THRESHOLD {
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

	// Recompute FOV so newly-opened space is immediately visible.
	compute_fov(game)

	return true
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
		inventory_consume_item_type(game, recipe.material_id, recipe.material_qty)
		add_message(
			messages,
			game,
			fmt.tprintf("%s repaired!", game.equipped_weapon.item.name),
			eng.Engine_Color{100, 255, 100, 255},
		)
		return
	}

	slot_idx := inventory_first_empty_slot(game)
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

	inventory_consume_item_type(game, recipe.material_id, recipe.material_qty)
	crafted := item_make_from_def(def, Vec2{0, 0})
	crafted.picked_up = true
	inventory_put_slot(game, slot_idx, crafted, 1)

	add_message(
		messages,
		game,
		fmt.tprintf("Crafted %s!", def.name),
		eng.Engine_Color{100, 255, 100, 255},
	)
}
