package core

import "core:math/rand"

Content_Manager :: struct {
	loaded:   bool,
	registry: Data_Registry,
}

content_manager_make :: proc() -> Content_Manager {
	return Content_Manager{}
}

content_manager_is_loaded :: proc(content: ^Content_Manager) -> bool {
	if content == nil {return false}
	return content.loaded && content.registry.loaded
}

content_manager_enemy_def :: proc(content: ^Content_Manager, id: string) -> ^Enemy_Def {
	if content == nil {return nil}
	for &def in content.registry.enemies.enemies {
		if def.id == id {return &def}
	}
	return nil
}

content_manager_item_def :: proc(content: ^Content_Manager, id: string) -> ^Item_Def {
	if content == nil {return nil}
	for &def in content.registry.items.items {
		if def.id == id {return &def}
	}
	return nil
}

content_manager_player_def :: proc(content: ^Content_Manager) -> ^Player_Def {
	if content == nil {return nil}
	return &content.registry.player
}

content_manager_enemy_def_for_depth :: proc(content: ^Content_Manager, depth: int) -> ^Enemy_Def {
	if content == nil {return nil}
	for &table in content.registry.enemies.spawn_tables {
		if depth >= table.depth_min && depth <= table.depth_max {
			total_weight := 0
			for &w in table.weights {total_weight += w.weight}
			if total_weight <= 0 {break}
			roll := rand.int_max(total_weight)
			acc := 0
			for &w in table.weights {
				acc += w.weight
				if roll < acc {
					def := content_manager_enemy_def(content, w.id)
					if def != nil {return def}
					break
				}
			}
			break
		}
	}
	if len(content.registry.enemies.enemies) > 0 {
		return &content.registry.enemies.enemies[0]
	}
	return nil
}

content_manager_pick_item_def :: proc(content: ^Content_Manager) -> ^Item_Def {
	if content == nil {return nil}
	total_weight := 0
	for &w in content.registry.items.spawn_weights {total_weight += w.weight}
	if total_weight <= 0 {
		if len(content.registry.items.items) > 0 {return &content.registry.items.items[0]}
		return nil
	}
	roll := rand.int_max(total_weight)
	acc := 0
	for &w in content.registry.items.spawn_weights {
		acc += w.weight
		if roll < acc {
			def := content_manager_item_def(content, w.id)
			if def != nil {return def}
			break
		}
	}
	if len(content.registry.items.items) > 0 {return &content.registry.items.items[0]}
	return nil
}

content_manager_pick_item_def_for_depth :: proc(
	content: ^Content_Manager,
	depth: int,
) -> ^Item_Def {
	if content == nil {return nil}
	for &table in content.registry.items.item_spawn_tables {
		if depth >= table.depth_min && depth <= table.depth_max {
			total_weight := 0
			for &w in table.weights {total_weight += w.weight}
			if total_weight <= 0 {break}
			roll := rand.int_max(total_weight)
			acc := 0
			for &w in table.weights {
				acc += w.weight
				if roll < acc {
					def := content_manager_item_def(content, w.id)
					if def != nil {return def}
					break
				}
			}
			break
		}
	}
	return content_manager_pick_item_def(content)
}

content_manager_room_item_chance :: proc(content: ^Content_Manager) -> int {
	if content == nil {return 0}
	return content.registry.items.room_item_chance
}

content_manager_destroy :: proc(content: ^Content_Manager) {
	if content == nil {return}
	data_registry_destroy(&content.registry)
	content^ = {}
}
