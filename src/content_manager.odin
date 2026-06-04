package main

import "core:math/rand"

// ─── Content manager facade ──────────────────────────────────────────────────

Content_Manager :: struct {
	loaded:   bool,
	registry: Data_Registry,
}

content_manager_make :: proc() -> Content_Manager {
	return Content_Manager{}
}

content_manager_load_all :: proc(content: ^Content_Manager) -> bool {
	if content == nil {
		return data_load_all()
	}
	ok := data_load_all_into(&content.registry)
	content.loaded = ok && content.registry.loaded
	return ok
}

content_manager_is_loaded :: proc(content: ^Content_Manager) -> bool {
	if content == nil {
		return g_data.loaded
	}
	return content.loaded && content.registry.loaded
}

content_manager_enemy_def :: proc(content: ^Content_Manager, id: string) -> ^Enemy_Def {
	if content == nil {
		return find_enemy_def(id)
	}
	for &def in content.registry.enemies.enemies {
		if def.id == id {return &def}
	}
	return nil
}

content_manager_item_def :: proc(content: ^Content_Manager, id: string) -> ^Item_Def {
	if content == nil {
		return find_item_def(id)
	}
	for &def in content.registry.items.items {
		if def.id == id {return &def}
	}
	return nil
}

content_manager_player_def :: proc(content: ^Content_Manager) -> ^Player_Def {
	if content != nil {
		return &content.registry.player
	}
	return &g_data.player
}

content_manager_enemy_def_for_depth :: proc(content: ^Content_Manager, depth: int) -> ^Enemy_Def {
	if content == nil {
		return pick_enemy_def_for_depth(depth)
	}
	for &table in content.registry.enemies.spawn_tables {
		if depth >= table.depth_min && depth <= table.depth_max {
			total_weight := 0
			for &w in table.weights {
				total_weight += w.weight
			}
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
	if content == nil {
		return pick_item_def()
	}
	total_weight := 0
	for &w in content.registry.items.spawn_weights {
		total_weight += w.weight
	}
	if total_weight <= 0 {
		if len(content.registry.items.items) > 0 {
			return &content.registry.items.items[0]
		}
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

	if len(content.registry.items.items) > 0 {
		return &content.registry.items.items[0]
	}
	return nil
}

content_manager_pick_item_def_for_depth :: proc(
	content: ^Content_Manager,
	depth: int,
) -> ^Item_Def {
	if content == nil {
		return pick_item_def_for_depth(depth)
	}
	for &table in content.registry.items.item_spawn_tables {
		if depth >= table.depth_min && depth <= table.depth_max {
			total_weight := 0
			for &w in table.weights {
				total_weight += w.weight
			}
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
	// Fallback to flat spawn_weights if no depth table matches
	return content_manager_pick_item_def(content)
}

content_manager_room_item_chance :: proc(content: ^Content_Manager) -> int {
	if content == nil {
		return g_data.items.room_item_chance
	}
	return content.registry.items.room_item_chance
}

content_manager_destroy :: proc(content: ^Content_Manager) {
	if content == nil {return}
	data_registry_destroy(&content.registry)
	content^ = {}
}
