#+build !js
package main
import eng "./engine"

import "core:math/rand"
import "core:testing"

@(test)
generate_map_spawns_at_least_one_enemy_across_depths_and_sample_seeds :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	seeds := [6]u64{1, 2, 3, 7, 42, 12345}
	for depth in 1 ..= MAX_DEPTH {
		for seed in seeds {
			rand.reset(seed)
			game := new(Game)
			game_init_world(game)
			game.depth = depth
			init_player_from_content(&content, game)
			game.rooms = make([dynamic]Room)
			game.enemies = make([dynamic]Enemy)
			game.items = make([dynamic]Item)
			game.light_sources = make([dynamic]Light_Source)
			generate_map(&content, game)
			testing.expectf(t, len(game.enemies) > 0, "depth=%d seed=%d had zero enemies", depth, seed)
			compute_dijkstra_map(game)
			dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(game), DMAP_UNREACHABLE)
			reachable_enemies := 0
			for enemy in game.enemies {
				if !enemy.alive {continue}
				if eng.engine_distance_map_get(&dmap, enemy.pos.x, enemy.pos.y) < DMAP_UNREACHABLE {
					reachable_enemies += 1
				}
			}
			testing.expectf(t, reachable_enemies > 0, "depth=%d seed=%d had no reachable enemies out of %d", depth, seed, len(game.enemies))
			game_destroy(game)
		}
	}
}
