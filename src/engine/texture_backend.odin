package engine

import rl "vendor:raylib"

Engine_Texture :: struct {
	handle: rawptr,
	width:  i32,
	height: i32,
}

Engine_Texture_Backend :: struct {
	ctx:    rawptr,
	load:   proc(ctx: rawptr, path: string) -> Engine_Texture,
	unload: proc(ctx: rawptr, texture: ^Engine_Texture),
}

engine_texture_is_valid :: proc(texture: Engine_Texture) -> bool {
	return texture.handle != nil
}

engine_texture_backend_is_valid :: proc(texture: Engine_Texture_Backend) -> bool {
	return texture.load != nil && texture.unload != nil
}

engine_texture_backend_or_default :: proc(
	texture: Engine_Texture_Backend,
) -> Engine_Texture_Backend {
	if engine_texture_backend_is_valid(texture) {
		return texture
	}
	return engine_texture_backend_default()
}

engine_texture_backend_default :: proc() -> Engine_Texture_Backend {
	return Engine_Texture_Backend{load = raylib_texture_load, unload = raylib_texture_unload}
}

engine_texture_backend_nil :: proc() -> Engine_Texture_Backend {
	return Engine_Texture_Backend{load = nil_texture_load, unload = nil_texture_unload}
}

engine_texture_load :: proc(engine: ^Engine, path: string) -> Engine_Texture {
	texture := engine_texture_backend(engine)
	return texture.load(texture.ctx, path)
}

engine_texture_unload :: proc(engine: ^Engine, texture: ^Engine_Texture) {
	if texture == nil || texture.handle == nil {
		return
	}
	backend := engine_texture_backend(engine)
	backend.unload(backend.ctx, texture)
	texture^ = {}
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

@(private = "file")
nil_texture_load :: proc(ctx: rawptr, path: string) -> Engine_Texture {
	return Engine_Texture{}
}

@(private = "file")
nil_texture_unload :: proc(ctx: rawptr, texture: ^Engine_Texture) {
	if texture != nil {
		texture^ = {}
	}
}
