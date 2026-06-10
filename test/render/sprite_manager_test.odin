#+build !js
package renderer

import gcore "../core"

import eng "../engine"
import "core:mem"
import "core:sync"
import "core:testing"

@(private = "file")
sprite_manager_test_g_sprites_mutex: sync.Mutex

@(test)
sprite_manager_make_wraps_current_sprite_atlas :: proc(t: ^testing.T) {
	sprites := sprite_manager_make()

	testing.expect(t, sprites.backend == &g_sprites)
}

@(test)
sprite_manager_reports_loaded_state_from_backend :: proc(t: ^testing.T) {
	sync.mutex_lock(&sprite_manager_test_g_sprites_mutex)
	defer sync.mutex_unlock(&sprite_manager_test_g_sprites_mutex)

	sprites := sprite_manager_make()
	was_loaded := g_sprites.loaded
	defer g_sprites.loaded = was_loaded

	g_sprites.loaded = false
	testing.expect(t, !sprite_manager_is_loaded(&sprites))

	g_sprites.loaded = true
	testing.expect(t, sprite_manager_is_loaded(&sprites))
}

@(test)
sprites_use_embedded_tileset_bytes_for_texture_lifetime :: proc(t: ^testing.T) {
	sync.mutex_lock(&sprite_manager_test_g_sprites_mutex)
	defer sync.mutex_unlock(&sprite_manager_test_g_sprites_mutex)

	state := Test_Sprite_Texture_Backend_State{}
	texture_backend := test_sprite_texture_backend(&state)
	engine := eng.Engine {
		texture         = texture_backend,
		texture_manager = eng.texture_manager_make(texture_backend),
	}
	defer sprites_cleanup(&engine)

	sprites_init(&engine)

	testing.expect(t, g_sprites.loaded)
	testing.expect_value(t, eng.texture_manager_loaded_count(engine.texture_manager), 1)
	testing.expect_value(t, state.load_count, 0)
	testing.expect_value(t, state.load_bytes_count, 1)
	testing.expect(t, state.last_name == "assets/kenney_1bit.png")
	testing.expect(t, state.last_bytes_len > 0)
	sprites_cleanup(&engine)
	testing.expect_value(t, eng.texture_manager_loaded_count(engine.texture_manager), 0)
	testing.expect_value(t, state.unload_count, 1)
}

@(test)
sprite_manager_draw_uses_default_tile_size_when_no_size_is_supplied :: proc(t: ^testing.T) {
	state := Test_Sprite_Render_Backend_State{}
	engine := eng.Engine {
		render = test_sprite_render_backend(&state),
	}
	atlas := Sprite_Atlas {
		loaded = true,
		texture = eng.Engine_Texture{handle = rawptr(uintptr(1)), width = 64, height = 64},
	}
	sprites := Sprite_Manager {
		backend = &atlas,
	}

	sprite_manager_draw(&engine, &sprites, sprite_at(0, 0, 16), 4, 5)

	testing.expect_value(t, state.texture_draw_count, 1)
	testing.expect_value(t, state.last_dest.width, f32(gcore.TILE_SIZE))
	testing.expect_value(t, state.last_dest.height, f32(gcore.TILE_SIZE))
}

@(test)
sprite_manager_draw_uses_requested_destination_size :: proc(t: ^testing.T) {
	state := Test_Sprite_Render_Backend_State{}
	engine := eng.Engine {
		render = test_sprite_render_backend(&state),
	}
	atlas := Sprite_Atlas {
		loaded = true,
		texture = eng.Engine_Texture{handle = rawptr(uintptr(1)), width = 64, height = 64},
	}
	sprites := Sprite_Manager {
		backend = &atlas,
	}

	sprite_manager_draw(
		&engine,
		&sprites,
		sprite_at(0, 0, 16),
		4,
		5,
		eng.Engine_Color{255, 255, 255, 255},
		35,
	)

	testing.expect_value(t, state.texture_draw_count, 1)
	testing.expect_value(t, state.last_dest.width, f32(35))
	testing.expect_value(t, state.last_dest.height, f32(35))
}

@(test)
sprites_cleanup_releases_json_owned_sprite_metadata_allocations :: proc(t: ^testing.T) {
	sync.mutex_lock(&sprite_manager_test_g_sprites_mutex)
	defer sync.mutex_unlock(&sprite_manager_test_g_sprites_mutex)

	track: mem.Tracking_Allocator
	previous_allocator := context.allocator
	mem.tracking_allocator_init(&track, previous_allocator)
	defer mem.tracking_allocator_destroy(&track)

	state := Test_Sprite_Texture_Backend_State{}
	texture_backend := test_sprite_texture_backend(&state)
	engine := eng.Engine {
		texture         = texture_backend,
		texture_manager = eng.texture_manager_make(texture_backend),
	}

	context.allocator = mem.tracking_allocator(&track)
	sprites_init(&engine)
	loaded := g_sprites.loaded
	sprites_cleanup(&engine)
	context.allocator = previous_allocator

	testing.expect(t, loaded)
	testing.expect_value(t, len(track.allocation_map), 0)
}

@(test)
sprites_init_replaces_existing_atlas_without_leaking_previous_metadata :: proc(t: ^testing.T) {
	sync.mutex_lock(&sprite_manager_test_g_sprites_mutex)
	defer sync.mutex_unlock(&sprite_manager_test_g_sprites_mutex)

	track: mem.Tracking_Allocator
	previous_allocator := context.allocator
	mem.tracking_allocator_init(&track, previous_allocator)
	defer mem.tracking_allocator_destroy(&track)

	state := Test_Sprite_Texture_Backend_State{}
	texture_backend := test_sprite_texture_backend(&state)
	engine := eng.Engine {
		texture         = texture_backend,
		texture_manager = eng.texture_manager_make(texture_backend),
	}

	context.allocator = mem.tracking_allocator(&track)
	sprites_init(&engine)
	first_loaded := g_sprites.loaded
	sprites_init(&engine)
	second_loaded := g_sprites.loaded
	sprites_cleanup(&engine)
	context.allocator = previous_allocator

	testing.expect(t, first_loaded)
	testing.expect(t, second_loaded)
	testing.expect_value(t, state.load_bytes_count, 2)
	testing.expect_value(t, state.unload_count, 2)
	testing.expect_value(t, len(track.allocation_map), 0)
}

@(test)
sprite_lookup_covers_special_tiles_and_town_npcs :: proc(t: ^testing.T) {
	testing.expect_value(t, tile_type_to_sprite_key(.Shrine), "shrine")
	testing.expect_value(t, tile_type_to_sprite_key(.Chest), "chest")
	testing.expect_value(t, tile_type_to_sprite_key(.Merchant), "merchant")
	testing.expect_value(t, tile_type_to_sprite_key(.Ascent), "ascent")
	testing.expect_value(t, tile_type_to_sprite_key(.Locked_Door), "locked_door")

	testing.expect_value(t, npc_role_to_sprite_key(.Shopkeeper), "shopkeeper")
	testing.expect_value(t, npc_role_to_sprite_key(.Guard), "guard")
	testing.expect_value(t, npc_role_to_sprite_key(.Elder), "elder")
	testing.expect_value(t, npc_role_to_sprite_key(.Old_Miner), "old_miner")
}

@(test)
sprite_manager_named_returns_npc_category_sprites :: proc(t: ^testing.T) {
	atlas := Sprite_Atlas {
		loaded    = true,
		tile_size = 16,
		npc_map   = make(map[string]Sprite),
	}
	defer delete(atlas.npc_map)
	(&atlas.npc_map)["shopkeeper"] = sprite_at(3, 4, 16)
	sprites := Sprite_Manager {
		backend = &atlas,
	}

	spr := sprite_manager_named(&sprites, "npc", "shopkeeper")

	testing.expect_value(t, spr.src.x, f32(48))
	testing.expect_value(t, spr.src.y, f32(64))
}

Test_Sprite_Render_Backend_State :: struct {
	texture_draw_count: int,
	last_dest:          eng.Engine_Rect,
}

test_sprite_render_backend :: proc(
	state: ^Test_Sprite_Render_Backend_State,
) -> eng.Engine_Render_Backend {
	return eng.Engine_Render_Backend {
		ctx = state,
		begin_frame = test_sprite_render_begin_frame,
		end_frame = test_sprite_render_end_frame,
		clear = test_sprite_render_clear,
		begin_scissor = test_sprite_render_begin_scissor,
		end_scissor = test_sprite_render_end_scissor,
		draw_rectangle = test_sprite_render_draw_rectangle,
		draw_text = test_sprite_render_draw_text,
		measure_text = test_sprite_render_measure_text,
		draw_rectangle_lines = test_sprite_render_draw_rectangle_lines,
		draw_texture_region = test_sprite_render_draw_texture_region,
	}
}

test_sprite_render_begin_frame :: proc(ctx: rawptr) {}
test_sprite_render_end_frame :: proc(ctx: rawptr) {}
test_sprite_render_clear :: proc(ctx: rawptr, color: eng.Engine_Color) {}
test_sprite_render_begin_scissor :: proc(ctx: rawptr, x, y, width, height: i32) {}
test_sprite_render_end_scissor :: proc(ctx: rawptr) {}
test_sprite_render_draw_rectangle :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: eng.Engine_Color,
) {}
test_sprite_render_draw_text :: proc(
	ctx: rawptr,
	text: cstring,
	x, y, size: i32,
	color: eng.Engine_Color,
	font: eng.Engine_Font,
) {}
test_sprite_render_measure_text :: proc(
	ctx: rawptr,
	text: cstring,
	size: i32,
	font: eng.Engine_Font,
) -> i32 {return 0}
test_sprite_render_draw_rectangle_lines :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: eng.Engine_Color,
) {}
test_sprite_render_draw_texture_region :: proc(
	ctx: rawptr,
	texture: eng.Engine_Texture,
	source, dest: eng.Engine_Rect,
	origin: eng.Engine_Vec2,
	rotation: f32,
	tint: eng.Engine_Color,
) {
	state := cast(^Test_Sprite_Render_Backend_State)ctx
	state.texture_draw_count += 1
	state.last_dest = dest
}

Test_Sprite_Texture_Backend_State :: struct {
	load_count:       int,
	load_bytes_count: int,
	unload_count:     int,
	last_path:        string,
	last_name:        string,
	last_bytes_len:   int,
}

test_sprite_texture_backend :: proc(
	state: ^Test_Sprite_Texture_Backend_State,
) -> eng.Engine_Texture_Backend {
	return eng.Engine_Texture_Backend {
		ctx = state,
		load = test_sprite_texture_load,
		load_bytes = test_sprite_texture_load_bytes,
		unload = test_sprite_texture_unload,
	}
}

test_sprite_texture_load :: proc(ctx: rawptr, path: string) -> eng.Engine_Texture {
	state := cast(^Test_Sprite_Texture_Backend_State)ctx
	state.load_count += 1
	state.last_path = path
	return eng.Engine_Texture{handle = ctx, width = 16, height = 16}
}

test_sprite_texture_load_bytes :: proc(
	ctx: rawptr,
	name: string,
	data: []u8,
) -> eng.Engine_Texture {
	state := cast(^Test_Sprite_Texture_Backend_State)ctx
	state.load_bytes_count += 1
	state.last_name = name
	state.last_bytes_len = len(data)
	return eng.Engine_Texture{handle = ctx, width = 16, height = 16}
}

test_sprite_texture_unload :: proc(ctx: rawptr, texture: ^eng.Engine_Texture) {
	state := cast(^Test_Sprite_Texture_Backend_State)ctx
	state.unload_count += 1
	texture^ = {}
}
