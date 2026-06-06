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

	// game_init defers map gen when state is Title_Screen.
	// Simulate "New Game": force Playing and generate the map.
	game.state = .Playing
	generate_map(&content, game)

	testing.expect(t, len(game.enemies) > 0)
}
