package main

import gcore "./core"

// content_manager_load_all loads all embedded data into the given content manager.
content_manager_load_all :: proc(content: ^gcore.Content_Manager) -> bool {
	if content == nil {return false}
	ok := data_load_all_into(&content.registry)
	content.loaded = ok && content.registry.loaded
	return ok
}
