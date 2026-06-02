package main

import "core:testing"

@(test)
content_manager_make_starts_unloaded :: proc(t: ^testing.T) {
	content := content_manager_make()

	testing.expect(t, !content.loaded)
}

@(test)
content_manager_is_loaded_reads_manager_state :: proc(t: ^testing.T) {
	content := content_manager_make()
	testing.expect(t, !content_manager_is_loaded(&content))

	content.loaded = true
	testing.expect(t, content_manager_is_loaded(&content))
}
