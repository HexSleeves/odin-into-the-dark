package main

import "core:encoding/json"
import "core:fmt"

import gcore "./core"
import eng "./engine"

// ─── Type aliases (types now live in gcore/data_defs.odin) ───────────────────

Color_Array :: gcore.Color_Array
Ability_Def :: gcore.Ability_Def
Enemy_Def :: gcore.Enemy_Def
Spawn_Weight :: gcore.Spawn_Weight
Spawn_Table :: gcore.Spawn_Table
Enemy_Data :: gcore.Enemy_Data
Item_Effect :: gcore.Item_Effect
Item_Spawn_Table :: gcore.Item_Spawn_Table
Item_Def :: gcore.Item_Def
Item_Spawn_Weight :: gcore.Item_Spawn_Weight
Item_Data :: gcore.Item_Data
Player_Def :: gcore.Player_Def
Data_Registry :: gcore.Data_Registry

json5_color_to_engine :: gcore.json5_color_to_engine
data_registry_destroy :: gcore.data_registry_destroy

// ─── Global data registry ─────────────────────────────────────────────────────

g_data: gcore.Data_Registry

// ─── Loader ───────────────────────────────────────────────────────────────────

@(private = "file")
EMBEDDED_ENEMIES :: #load("../data/enemies.json5")
@(private = "file")
EMBEDDED_ITEMS :: #load("../data/items.json5")
@(private = "file")
EMBEDDED_PLAYER :: #load("../data/player.json5")

data_load_all :: proc() -> bool {
	return data_load_all_into(&g_data)
}

data_load_all_into :: proc(registry: ^gcore.Data_Registry) -> bool {
	if registry == nil {
		return false
	}
	next: gcore.Data_Registry
	next.owned = true

	enemies, enemies_ok := load_json5_from_bytes(gcore.Enemy_Data, EMBEDDED_ENEMIES)
	if !enemies_ok {return false}
	next.enemies = enemies

	items, items_ok := load_json5_from_bytes(gcore.Item_Data, EMBEDDED_ITEMS)
	if !items_ok {
		gcore.data_registry_destroy(&next)
		return false
	}
	next.items = items

	player, player_ok := load_json5_from_bytes(gcore.Player_Def, EMBEDDED_PLAYER)
	if !player_ok {
		gcore.data_registry_destroy(&next)
		return false
	}
	next.player = player
	next.loaded = true

	gcore.data_registry_destroy(registry)
	registry^ = next

	logger_debugf(
		.Data,
		"loaded %v enemies, %v spawn tables, %v items",
		len(registry.enemies.enemies),
		len(registry.enemies.spawn_tables),
		len(registry.items.items),
	)

	return true
}

load_json5_from_bytes :: proc($T: typeid, data: []u8) -> (result: T, ok: bool) {
	parse_err := json.unmarshal(data, &result, spec = .JSON5)
	if parse_err != nil {
		logger_errorf(.Data, "parse failed: %v", parse_err)
		return {}, false
	}
	return result, true
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
		if game.poison_turns > 0 {
			game.poison_turns = 0
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
