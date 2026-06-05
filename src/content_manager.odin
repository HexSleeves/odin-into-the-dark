package main

import gcore "./core"

// content_manager types and accessors live in gcore/content_manager.odin.
// This file provides the load_all wrapper that needs package-main data loading.

Content_Manager :: gcore.Content_Manager
content_manager_make :: gcore.content_manager_make
content_manager_is_loaded :: gcore.content_manager_is_loaded
content_manager_enemy_def :: gcore.content_manager_enemy_def
content_manager_item_def :: gcore.content_manager_item_def
content_manager_player_def :: gcore.content_manager_player_def
content_manager_enemy_def_for_depth :: gcore.content_manager_enemy_def_for_depth
content_manager_pick_item_def :: gcore.content_manager_pick_item_def
content_manager_pick_item_def_for_depth :: gcore.content_manager_pick_item_def_for_depth
content_manager_room_item_chance :: gcore.content_manager_room_item_chance
content_manager_destroy :: gcore.content_manager_destroy

content_manager_load_all :: proc(content: ^gcore.Content_Manager) -> bool {
	if content == nil {
		return data_load_all()
	}
	ok := data_load_all_into(&content.registry)
	content.loaded = ok && content.registry.loaded
	return ok
}
