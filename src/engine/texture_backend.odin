package engine

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

// Raylib on desktop (texture_backend_raylib.odin); nil on JS, where Raylib
// cannot link and the game injects the karl2d texture backend.
engine_texture_backend_default :: proc() -> Engine_Texture_Backend {
	when ODIN_OS == .JS {
		return engine_texture_backend_nil()
	} else {
		return engine_texture_backend_raylib()
	}
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
nil_texture_load :: proc(ctx: rawptr, path: string) -> Engine_Texture {
	return Engine_Texture{}
}

@(private = "file")
nil_texture_unload :: proc(ctx: rawptr, texture: ^Engine_Texture) {
	if texture != nil {
		texture^ = {}
	}
}
