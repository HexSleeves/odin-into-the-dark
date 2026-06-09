package engine

ENGINE_TEXTURE_MAX :: 128

Engine_Texture_Handle :: distinct int
ENGINE_TEXTURE_HANDLE_NONE :: Engine_Texture_Handle(0)

Texture_Manager :: struct {
	backend:  Engine_Texture_Backend,
	loaded:   [ENGINE_TEXTURE_MAX]bool,
	textures: [ENGINE_TEXTURE_MAX]Engine_Texture,
}

texture_manager_make :: proc(backend: Engine_Texture_Backend) -> Texture_Manager {
	return Texture_Manager{backend = engine_texture_backend_or_default(backend)}
}

texture_handle_is_valid :: proc(handle: Engine_Texture_Handle) -> bool {
	return int(handle) > 0 && int(handle) <= ENGINE_TEXTURE_MAX
}

texture_manager_load :: proc(manager: ^Texture_Manager, path: string) -> Engine_Texture_Handle {
	if manager == nil {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	slot := texture_manager_first_free_slot(manager^)
	if slot < 0 {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	backend := engine_texture_backend_or_default(manager.backend)
	texture := backend.load(backend.ctx, path)
	if !engine_texture_is_valid(texture) {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	manager.loaded[slot] = true
	manager.textures[slot] = texture
	return Engine_Texture_Handle(slot + 1)
}

texture_manager_load_bytes :: proc(
	manager: ^Texture_Manager,
	name: string,
	data: []u8,
) -> Engine_Texture_Handle {
	if manager == nil {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	slot := texture_manager_first_free_slot(manager^)
	if slot < 0 {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	backend := engine_texture_backend_or_default(manager.backend)
	if backend.load_bytes == nil {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	texture := backend.load_bytes(backend.ctx, name, data)
	if !engine_texture_is_valid(texture) {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	manager.loaded[slot] = true
	manager.textures[slot] = texture
	return Engine_Texture_Handle(slot + 1)
}


texture_manager_get :: proc(
	manager: Texture_Manager,
	handle: Engine_Texture_Handle,
) -> Engine_Texture {
	if !texture_handle_is_valid(handle) {
		return Engine_Texture{}
	}
	slot := int(handle) - 1
	if !manager.loaded[slot] {
		return Engine_Texture{}
	}
	return manager.textures[slot]
}

texture_manager_unload :: proc(manager: ^Texture_Manager, handle: Engine_Texture_Handle) -> bool {
	if manager == nil || !texture_handle_is_valid(handle) {
		return false
	}
	slot := int(handle) - 1
	if !manager.loaded[slot] {
		return false
	}
	backend := engine_texture_backend_or_default(manager.backend)
	backend.unload(backend.ctx, &manager.textures[slot])
	manager.loaded[slot] = false
	manager.textures[slot] = Engine_Texture{}
	return true
}

texture_manager_unload_all :: proc(manager: ^Texture_Manager) {
	if manager == nil {
		return
	}
	for i in 0 ..< ENGINE_TEXTURE_MAX {
		if manager.loaded[i] {
			_ = texture_manager_unload(manager, Engine_Texture_Handle(i + 1))
		}
	}
}

texture_manager_loaded_count :: proc(manager: Texture_Manager) -> int {
	count := 0
	for i in 0 ..< ENGINE_TEXTURE_MAX {
		if manager.loaded[i] {
			count += 1
		}
	}
	return count
}

engine_texture_manager_load :: proc(engine: ^Engine, path: string) -> Engine_Texture_Handle {
	manager := engine_texture_manager(engine)
	if manager == nil {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	return texture_manager_load(manager, path)
}

engine_texture_manager_load_bytes :: proc(
	engine: ^Engine,
	name: string,
	data: []u8,
) -> Engine_Texture_Handle {
	manager := engine_texture_manager(engine)
	if manager == nil {
		return ENGINE_TEXTURE_HANDLE_NONE
	}
	return texture_manager_load_bytes(manager, name, data)
}

engine_texture_manager_get :: proc(
	engine: ^Engine,
	handle: Engine_Texture_Handle,
) -> Engine_Texture {
	manager := engine_texture_manager(engine)
	if manager == nil {
		return Engine_Texture{}
	}
	return texture_manager_get(manager^, handle)
}

engine_texture_manager_unload :: proc(engine: ^Engine, handle: Engine_Texture_Handle) -> bool {
	manager := engine_texture_manager(engine)
	if manager == nil {
		return false
	}
	return texture_manager_unload(manager, handle)
}

@(private = "file")
texture_manager_first_free_slot :: proc(manager: Texture_Manager) -> int {
	for i in 0 ..< ENGINE_TEXTURE_MAX {
		if !manager.loaded[i] {
			return i
		}
	}
	return -1
}
