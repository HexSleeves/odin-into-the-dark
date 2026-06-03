#+build !js
package engine

import rl "vendor:raylib"

// Raylib texture backend — desktop default. Excluded from the JS/WASM build,
// which cannot link libraylib.a; web uses the karl2d texture backend (loading
// from #load'd bytes, since there is no filesystem on WASM).

engine_texture_backend_raylib :: proc() -> Engine_Texture_Backend {
	return Engine_Texture_Backend{load = raylib_texture_load, unload = raylib_texture_unload}
}

@(private = "file")
raylib_texture_load :: proc(ctx: rawptr, path: string) -> Engine_Texture {
	path_buf: [1024]u8
	copy_len := min(len(path), len(path_buf) - 1)
	for i in 0 ..< copy_len {
		path_buf[i] = path[i]
	}
	path_buf[copy_len] = 0

	raw_texture := new(rl.Texture2D)
	raw_texture^ = rl.LoadTexture(cast(cstring)&path_buf[0])
	if raw_texture.id == 0 {
		free(raw_texture)
		return {}
	}

	return Engine_Texture {
		handle = rawptr(raw_texture),
		width = raw_texture.width,
		height = raw_texture.height,
	}
}

@(private = "file")
raylib_texture_unload :: proc(ctx: rawptr, texture: ^Engine_Texture) {
	if texture == nil || texture.handle == nil {
		return
	}

	raw_texture := cast(^rl.Texture2D)texture.handle
	if raw_texture.id != 0 {
		rl.UnloadTexture(raw_texture^)
	}
	free(raw_texture)
	texture^ = {}
}
