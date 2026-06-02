package main

import "core:testing"

@(test)
content_manager_make_starts_unloaded :: proc(t: ^testing.T) {
	content := content_manager_make()

	testing.expect(t, !content.loaded)
	testing.expect(t, !content.registry.loaded)
}

@(test)
content_manager_is_loaded_reads_manager_state :: proc(t: ^testing.T) {
	content := content_manager_make()
	testing.expect(t, !content_manager_is_loaded(&content))

	content.loaded = true
	content.registry.loaded = true
	testing.expect(t, content_manager_is_loaded(&content))
}

@(test)
content_manager_accessors_read_owned_registry :: proc(t: ^testing.T) {
	content := content_manager_make()
	content.registry.loaded = true
	content.registry.player.hp = 12
	content.registry.items.items = []Item_Def{Item_Def{id = "test_item", name = "Test Item"}}
	content.registry.enemies.enemies = []Enemy_Def{Enemy_Def{id = "test_enemy", name = "Test Enemy"}}

	testing.expect_value(t, content_manager_player_def(&content).hp, 12)
	testing.expect_value(t, content_manager_item_def(&content, "test_item").name, "Test Item")
	testing.expect_value(t, content_manager_enemy_def(&content, "test_enemy").name, "Test Enemy")
}

@(test)
content_manager_spawn_helpers_read_owned_registry :: proc(t: ^testing.T) {
	content := content_manager_make()
	content.registry.loaded = true
	content.registry.items.room_item_chance = 33
	content.registry.items.items = []Item_Def{Item_Def{id = "fallback_item", name = "Fallback Item"}}
	content.registry.items.spawn_weights = []Item_Spawn_Weight{Item_Spawn_Weight{id = "fallback_item", weight = 1}}
	content.registry.enemies.enemies = []Enemy_Def{Enemy_Def{id = "fallback_enemy", name = "Fallback Enemy"}}
	content.registry.enemies.spawn_tables = []Spawn_Table{Spawn_Table{depth_min = 1, depth_max = 9, weights = []Spawn_Weight{Spawn_Weight{id = "fallback_enemy", weight = 1}}}}

	testing.expect_value(t, content_manager_room_item_chance(&content), 33)
	testing.expect_value(t, content_manager_pick_item_def(&content).id, "fallback_item")
	testing.expect_value(t, content_manager_enemy_def_for_depth(&content, 1).id, "fallback_enemy")
}
