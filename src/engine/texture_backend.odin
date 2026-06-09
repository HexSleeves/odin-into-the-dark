package engine

Engine_Texture :: struct {
	handle: rawptr,
	width:  i32,
	height: i32,
}

Engine_Texture_Backend :: struct {
	ctx:        rawptr,
	load:       proc(ctx: rawptr, path: string) -> Engine_Texture,
	load_bytes: proc(ctx: rawptr, name: string, data: []u8) -> Engine_Texture,
	unload:     proc(ctx: rawptr, texture: ^Engine_Texture),
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

// Fallback backend for subsystems that do not inject a texture backend.
// The game injects karl2d in game_engine_config for desktop and web builds.
engine_texture_backend_default :: proc() -> Engine_Texture_Backend {
	when ODIN_OS == .JS {
		return engine_texture_backend_nil()
	} else {
		return engine_texture_backend_raylib()
	}
}

engine_texture_backend_nil :: proc() -> Engine_Texture_Backend {
	return Engine_Texture_Backend {
		load = nil_texture_load,
		load_bytes = nil_texture_load_bytes,
		unload = nil_texture_unload,
	}
}

engine_texture_load :: proc(engine: ^Engine, path: string) -> Engine_Texture {
	texture := engine_texture_backend(engine)
	return texture.load(texture.ctx, path)
}

engine_texture_load_bytes :: proc(engine: ^Engine, name: string, data: []u8) -> Engine_Texture {
	texture := engine_texture_backend(engine)
	if texture.load_bytes == nil {
		return {}
	}
	return texture.load_bytes(texture.ctx, name, data)
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
nil_texture_load :: proc(ctx: rawptr, path: string) -> Engine_Texture {
	return Engine_Texture{}
}

@(private = "file")
nil_texture_load_bytes :: proc(ctx: rawptr, name: string, data: []u8) -> Engine_Texture {
	return Engine_Texture{}
}

@(private = "file")
nil_texture_unload :: proc(ctx: rawptr, texture: ^Engine_Texture) {
	if texture != nil {
		texture^ = {}
	}
}
