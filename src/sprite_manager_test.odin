#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
sprite_manager_make_wraps_current_sprite_atlas :: proc(t: ^testing.T) {
	sprites := sprite_manager_make()

	testing.expect(t, sprites.backend == &g_sprites)
}

@(test)
sprite_manager_reports_loaded_state_from_backend :: proc(t: ^testing.T) {
	sprites := sprite_manager_make()
	was_loaded := g_sprites.loaded
	defer g_sprites.loaded = was_loaded

	g_sprites.loaded = false
	testing.expect(t, !sprite_manager_is_loaded(&sprites))

	g_sprites.loaded = true
	testing.expect(t, sprite_manager_is_loaded(&sprites))
}

@(test)
sprites_use_engine_texture_manager_for_tileset_lifetime :: proc(t: ^testing.T) {
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
	testing.expect(t, state.last_path == "assets/kenney_1bit.png")

	sprites_cleanup(&engine)
	testing.expect_value(t, eng.texture_manager_loaded_count(engine.texture_manager), 0)
	testing.expect_value(t, state.unload_count, 1)
}

Test_Sprite_Texture_Backend_State :: struct {
	load_count:   int,
	unload_count: int,
	last_path:    string,
}

test_sprite_texture_backend :: proc(
	state: ^Test_Sprite_Texture_Backend_State,
) -> eng.Engine_Texture_Backend {
	return eng.Engine_Texture_Backend {
		ctx = state,
		load = test_sprite_texture_load,
		unload = test_sprite_texture_unload,
	}
}

test_sprite_texture_load :: proc(ctx: rawptr, path: string) -> eng.Engine_Texture {
	state := cast(^Test_Sprite_Texture_Backend_State)ctx
	state.load_count += 1
	state.last_path = path
	return eng.Engine_Texture{handle = ctx, width = 16, height = 16}
}

test_sprite_texture_unload :: proc(ctx: rawptr, texture: ^eng.Engine_Texture) {
	state := cast(^Test_Sprite_Texture_Backend_State)ctx
	state.unload_count += 1
	texture^ = {}
}
