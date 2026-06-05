package main

import "core:encoding/json"

import gcore "./core"

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