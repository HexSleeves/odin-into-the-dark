#+build !js
package main

import "base:runtime"
import "core:mem"
import "core:testing"

@(test)
content_manager_make_starts_unloaded :: proc(t: ^testing.T) {
	content := content_manager_make()

	testing.expect(t, !content.loaded)
	testing.expect(t, !content.registry.loaded)
}

@(test)
content_manager_load_all_uses_embedded_data :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)

	testing.expect(t, content_manager_load_all(&content))
	testing.expect(t, content.loaded)
	testing.expect(t, content.registry.loaded)
	testing.expect(t, len(content.registry.enemies.enemies) > 0)
	testing.expect(t, len(content.registry.items.items) > 0)
	testing.expect(t, content.registry.player.hp > 0)
}

@(test)
content_manager_destroy_releases_json_owned_registry_allocations :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	previous_allocator := context.allocator
	mem.tracking_allocator_init(&track, previous_allocator)
	defer mem.tracking_allocator_destroy(&track)

	context.allocator = mem.tracking_allocator(&track)
	content := content_manager_make()
	loaded := content_manager_load_all(&content)
	content_manager_destroy(&content)
	context.allocator = previous_allocator

	testing.expect(t, loaded)
	testing.expect_value(t, len(track.allocation_map), 0)
}

@(test)
content_manager_reload_releases_previous_registry_allocations :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	previous_allocator := context.allocator
	mem.tracking_allocator_init(&track, previous_allocator)
	defer mem.tracking_allocator_destroy(&track)

	context.allocator = mem.tracking_allocator(&track)
	content := content_manager_make()
	first_loaded := content_manager_load_all(&content)
	second_loaded := content_manager_load_all(&content)
	content_manager_destroy(&content)
	context.allocator = previous_allocator

	testing.expect(t, first_loaded)
	testing.expect(t, second_loaded)
	testing.expect_value(t, len(track.allocation_map), 0)
}

@(test)
content_manager_load_all_with_instance_does_not_alias_global_registry :: proc(t: ^testing.T) {
	data_registry_destroy(&g_data)
	defer data_registry_destroy(&g_data)
	content := content_manager_make()
	defer content_manager_destroy(&content)

	loaded := content_manager_load_all(&content)

	testing.expect(t, loaded)
	testing.expect(t, content.loaded)
	testing.expect(t, content.registry.loaded)
	testing.expect(t, !g_data.loaded)
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
	content.registry.enemies.enemies = []Enemy_Def {
		Enemy_Def{id = "test_enemy", name = "Test Enemy"},
	}

	testing.expect_value(t, content_manager_player_def(&content).hp, 12)
	testing.expect_value(t, content_manager_item_def(&content, "test_item").name, "Test Item")
	testing.expect_value(t, content_manager_enemy_def(&content, "test_enemy").name, "Test Enemy")
}

@(test)
content_manager_spawn_helpers_read_owned_registry :: proc(t: ^testing.T) {
	content := content_manager_make()
	content.registry.loaded = true
	content.registry.items.room_item_chance = 33
	content.registry.items.items = []Item_Def {
		Item_Def{id = "fallback_item", name = "Fallback Item"},
	}
	content.registry.items.spawn_weights = []Item_Spawn_Weight {
		Item_Spawn_Weight{id = "fallback_item", weight = 1},
	}
	content.registry.enemies.enemies = []Enemy_Def {
		Enemy_Def{id = "fallback_enemy", name = "Fallback Enemy"},
	}
	content.registry.enemies.spawn_tables = []Spawn_Table {
		Spawn_Table {
			depth_min = 1,
			depth_max = 9,
			weights = []Spawn_Weight{Spawn_Weight{id = "fallback_enemy", weight = 1}},
		},
	}

	testing.expect_value(t, content_manager_room_item_chance(&content), 33)
	testing.expect_value(t, content_manager_pick_item_def(&content).id, "fallback_item")
	testing.expect_value(t, content_manager_enemy_def_for_depth(&content, 1).id, "fallback_enemy")
}

Content_Test_File_System_State :: struct {
	read_count: int,
}

content_test_file_system_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	state := cast(^Content_Test_File_System_State)ctx
	state.read_count += 1
	content := ""
	if path == "data/enemies.json5" {
		content = "{enemies:[{id:\"rat\",name:\"Rat\",glyph:\"r\",color:[1,2,3,255],hp:1,attack:1,ability:{type:\"\",cooldown:0,range:0}}],spawn_tables:[{depth_min:1,depth_max:1,weights:[{id:\"rat\",weight:1}]}]}"
	} else if path == "data/items.json5" {
		content = "{items:[{id:\"torch\",name:\"Torch\",glyph:\"!\",color:[4,5,6,255],stack_limit:1,effect:{type:\"light\",value:1,max_radius:2,duration:3},equipment_slot:\"\",durability:0}],spawn_weights:[{id:\"torch\",weight:1}],room_item_chance:5}"
	} else if path == "data/player.json5" {
		content = "{hp:10,attack:2,light_radius:6,glyph:\"@\",color:[255,255,255,255]}"
	} else {
		return {}, false
	}
	buf := make([]u8, len(content), allocator)
	for i in 0 ..< len(content) {
		buf[i] = content[i]
	}
	return buf, true
}

content_test_file_system_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	return false
}

content_test_file_system_exists :: proc(ctx: rawptr, path: string) -> bool {
	return false
}

content_test_file_system_remove :: proc(ctx: rawptr, path: string) -> bool {
	return false
}
