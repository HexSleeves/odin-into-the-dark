package core

// item_make stays at root (needs logger from io — would create cycle).
// These are pure helpers that only need Content_Manager.

item_stack_limit :: proc(content: ^Content_Manager, id: string) -> int {
	def := content_manager_item_def(content, id)
	if def != nil && def.stack_limit > 0 {
		return def.stack_limit
	}
	return 1
}

item_is_stackable :: proc(content: ^Content_Manager, id: string) -> bool {
	return item_stack_limit(content, id) > 1
}
