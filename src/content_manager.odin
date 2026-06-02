package main

// ─── Content manager facade ──────────────────────────────────────────────────

Content_Manager :: struct {
	loaded: bool,
}

content_manager_make :: proc() -> Content_Manager {
	return Content_Manager{}
}

content_manager_load_all :: proc(content: ^Content_Manager) -> bool {
	ok := data_load_all()
	if content != nil {
		content.loaded = ok
	}
	return ok
}

content_manager_is_loaded :: proc(content: ^Content_Manager) -> bool {
	if content == nil {
		return g_data.loaded
	}
	return content.loaded
}

content_manager_enemy_def :: proc(content: ^Content_Manager, id: string) -> ^Enemy_Def {
	return find_enemy_def(id)
}

content_manager_item_def :: proc(content: ^Content_Manager, id: string) -> ^Item_Def {
	return find_item_def(id)
}
