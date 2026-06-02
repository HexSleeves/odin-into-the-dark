package engine

// ─── Scene manager ───────────────────────────────────────────────────────────

Engine_Scene_Id :: int

Engine_Scene_Callback :: proc(engine: ^Engine, ctx: rawptr)
Engine_Scene_Update_Callback :: proc(engine: ^Engine, ctx: rawptr) -> bool

Engine_Scene :: struct {
	id:     Engine_Scene_Id,
	ctx:    rawptr,
	enter:  Engine_Scene_Callback,
	update: Engine_Scene_Update_Callback,
	render: Engine_Scene_Callback,
	exit:   Engine_Scene_Callback,
}

Scene_Manager :: struct {
	scenes:       []Engine_Scene,
	active_index: int,
	has_active:   bool,
}

scene_manager_make :: proc(scenes: []Engine_Scene) -> Scene_Manager {
	return Scene_Manager {
		scenes = scenes,
	}
}

scene_manager_has_active :: proc(manager: ^Scene_Manager) -> bool {
	return manager != nil && manager.has_active
}

scene_manager_active_id :: proc(manager: ^Scene_Manager) -> Engine_Scene_Id {
	if manager == nil || !manager.has_active {
		return -1
	}
	return manager.scenes[manager.active_index].id
}

scene_manager_set_active :: proc(manager: ^Scene_Manager, engine: ^Engine, id: Engine_Scene_Id) -> bool {
	if manager == nil || engine == nil {
		return false
	}

	next_index, found := scene_manager_find_index(manager, id)
	if !found {
		return false
	}

	if manager.has_active && manager.active_index == next_index {
		return true
	}

	if manager.has_active {
		current := &manager.scenes[manager.active_index]
		if current.exit != nil {
			current.exit(engine, current.ctx)
		}
	}

	manager.active_index = next_index
	manager.has_active = true

	next := &manager.scenes[manager.active_index]
	if next.enter != nil {
		next.enter(engine, next.ctx)
	}

	return true
}

scene_manager_update :: proc(manager: ^Scene_Manager, engine: ^Engine) -> bool {
	if manager == nil || engine == nil || !manager.has_active {
		return false
	}

	scene := &manager.scenes[manager.active_index]
	if scene.update == nil {
		return false
	}
	return scene.update(engine, scene.ctx)
}

scene_manager_render :: proc(manager: ^Scene_Manager, engine: ^Engine) {
	if manager == nil || engine == nil || !manager.has_active {
		return
	}

	scene := &manager.scenes[manager.active_index]
	if scene.render != nil {
		scene.render(engine, scene.ctx)
	}
}

@(private = "file")
scene_manager_find_index :: proc(manager: ^Scene_Manager, id: Engine_Scene_Id) -> (index: int, found: bool) {
	for i in 0 ..< len(manager.scenes) {
		if manager.scenes[i].id == id {
			return i, true
		}
	}
	return -1, false
}
