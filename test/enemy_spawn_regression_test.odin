#+build !js
package main

import "core:testing"

@(test)
game_init_with_loaded_content_spawns_enemies :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	loaded := content_manager_load_all(&content)
	testing.expect(t, loaded)

	game := game_init(&content)
	defer game_destroy(game)

	// game_init now starts on the surface (depth 0). Simulate descending into
	// the mine: set a mine depth and generate.
	game.state = .Playing
	game.depth = 1
	generate_map(&content, game)

	testing.expect(t, len(game.enemies) > 0)
}
