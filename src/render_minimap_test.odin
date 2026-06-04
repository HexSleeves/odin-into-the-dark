#+build !js
package main

import "core:testing"

@(test)
explore_cheat_reveals_enemy_dots_on_minimap_for_explored_tiles :: proc(t: ^testing.T) {
	game: Game
	game_init_world(&game)
	game.enemies = make([dynamic]Enemy)
	defer delete(game.enemies)
	append(&game.enemies, Enemy{pos = Vec2{4, 4}, alive = true})
	_ = tile_state_set(&game, 4, 4, false, true, 0)

	testing.expect(t, !minimap_should_draw_enemy_dot(&game, &game.enemies[0]))
	game.minimap_reveal_enemies = true
		testing.expect(t, minimap_should_draw_enemy_dot(&game, &game.enemies[0]))
}
