package engine

import "core:testing"

@(test)
texture_manager_loads_gets_and_unloads_by_handle :: proc(t: ^testing.T) {
	state := Test_Texture_Manager_Backend_State{}
	manager := texture_manager_make(test_texture_manager_backend(&state))

	handle := texture_manager_load(&manager, "assets/a.png")
	texture := texture_manager_get(manager, handle)

	testing.expect(t, texture_handle_is_valid(handle))
	testing.expect(t, engine_texture_is_valid(texture))
	testing.expect_value(t, texture.width, i32(16))
	testing.expect_value(t, texture.height, i32(24))
	testing.expect_value(t, texture_manager_loaded_count(manager), 1)
	testing.expect_value(t, state.load_count, 1)
	testing.expect(t, state.last_path == "assets/a.png")

	testing.expect(t, texture_manager_unload(&manager, handle))
	testing.expect_value(t, state.unload_count, 1)
	testing.expect_value(t, texture_manager_loaded_count(manager), 0)
	testing.expect(t, !engine_texture_is_valid(texture_manager_get(manager, handle)))
}

@(test)
texture_manager_unload_all_releases_loaded_textures :: proc(t: ^testing.T) {
	state := Test_Texture_Manager_Backend_State{}
	manager := texture_manager_make(test_texture_manager_backend(&state))

	_ = texture_manager_load(&manager, "assets/a.png")
	_ = texture_manager_load(&manager, "assets/b.png")

	testing.expect_value(t, texture_manager_loaded_count(manager), 2)
	texture_manager_unload_all(&manager)
	testing.expect_value(t, state.unload_count, 2)
	testing.expect_value(t, texture_manager_loaded_count(manager), 0)
}

@(test)
engine_exposes_owned_texture_manager :: proc(t: ^testing.T) {
	engine := Engine{}
	manager := engine_texture_manager(&engine)

	testing.expect(t, manager == &engine.texture_manager)
}

Test_Texture_Manager_Backend_State :: struct {
	load_count:   int,
	unload_count: int,
	last_path:    string,
}

test_texture_manager_backend :: proc(
	state: ^Test_Texture_Manager_Backend_State,
) -> Engine_Texture_Backend {
	return Engine_Texture_Backend {
		ctx = state,
		load = test_texture_manager_backend_load,
		unload = test_texture_manager_backend_unload,
	}
}

test_texture_manager_backend_load :: proc(ctx: rawptr, path: string) -> Engine_Texture {
	state := cast(^Test_Texture_Manager_Backend_State)ctx
	state.load_count += 1
	state.last_path = path
	return Engine_Texture{handle = ctx, width = 16, height = 24}
}

test_texture_manager_backend_unload :: proc(ctx: rawptr, texture: ^Engine_Texture) {
	state := cast(^Test_Texture_Manager_Backend_State)ctx
	state.unload_count += 1
	texture^ = {}
}
