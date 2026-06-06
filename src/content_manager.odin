package main

import gcore "./core"

// content_manager_load_all wraps data_load_all (root-only json5 loading).
content_manager_load_all :: proc(content: ^gcore.Content_Manager) -> bool {
	if content == nil {
		return data_load_all()
	}
	ok := data_load_all_into(&content.registry)
	content.loaded = ok && content.registry.loaded
	return ok
}
