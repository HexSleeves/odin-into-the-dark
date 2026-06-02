package main

UI_Manager :: struct {
	state: UI_State,
}

ui_manager_make :: proc(use_sprites: bool) -> UI_Manager {
	return UI_Manager {
		state = UI_State {
			use_sprites = use_sprites,
			inspect_slot = -1,
		},
	}
}

ui_manager_state :: proc(ui: ^UI_Manager) -> ^UI_State {
	if ui == nil {
		return nil
	}
	return &ui.state
}

ui_manager_reset_for_new_game :: proc(ui: ^UI_Manager, use_sprites: bool) {
	if ui == nil {
		return
	}
	ui.state = UI_State {
		use_sprites = use_sprites,
		inspect_slot = -1,
	}
}

ui_manager_reset_transient :: proc(ui: ^UI_Manager) {
	if ui == nil {
		return
	}
	use_sprites := ui.state.use_sprites
	ui.state.mining_mode = false
	ui.state.dropping = false
	ui.state.equipping = false
	ui.state.show_minimap = false
	ui.state.inspect_slot = -1
	ui.state.use_sprites = use_sprites
}

ui_manager_use_sprites :: proc(ui: ^UI_Manager) -> bool {
	if ui == nil {
		return false
	}
	return ui.state.use_sprites
}
