package main

import "core:encoding/json"

import gcore "./core"
import gameio "./io"

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

	gameio.logger_debugf(
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
		gameio.logger_errorf(.Data, "parse failed: %v", parse_err)
		return {}, false
	}
	return result, true
}
