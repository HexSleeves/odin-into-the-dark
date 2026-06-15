#+build !js
package main

import "core:testing"

// ─── P9: O(1) enemy_at via enemy_occupancy grid ──────────────────────────────
//
// These tests pin the occupancy grid to the semantics of the original linear
// scan (first alive enemy on a tile, dead/off-grid ignored) and verify the grid
// is kept correct across the spawn/move/death/cleanup maintenance points.

// Reference implementation: the pre-P9 linear scan. enemy_at must agree with
// this for every cell, at all times.
enemy_at_linear_ref :: proc(game: ^Game, x, y: int) -> ^Enemy {
	for &enemy in game.enemies {
		if enemy.alive && enemy.pos.x == x && enemy.pos.y == y {
			return &enemy
		}
	}
	return nil
}

// Assert enemy_at == linear scan for every cell on the map.
expect_occupancy_matches_scan :: proc(t: ^testing.T, game: ^Game) {
	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			testing.expect(t, enemy_at(game, x, y) == enemy_at_linear_ref(game, x, y))
		}
	}
}

enemy_occupancy_test_setup :: proc(game: ^Game) {
	game_init_world(game)
	for &tile in game.tiles {
		tile.type = .Floor
	}
	game.player.pos = Vec2{0, 0}
	game.enemies = make([dynamic]Enemy)
}

@(test)
enemy_at_grid_lookup_equals_linear_scan_for_every_cell :: proc(t: ^testing.T) {
	game: Game
	enemy_occupancy_test_setup(&game)
	defer delete(game.enemies)

	append(&game.enemies, Enemy{pos = Vec2{3, 4}, alive = true})
	append(&game.enemies, Enemy{pos = Vec2{10, 2}, alive = true})
	append(&game.enemies, Enemy{pos = Vec2{7, 7}, alive = false}) // dead: never matches
	enemy_occupancy_mark_dirty(&game)

	expect_occupancy_matches_scan(t, &game)

	// Exact hits return the live enemy.
	testing.expect(t, enemy_at(&game, 3, 4) != nil)
	testing.expect(t, enemy_at(&game, 10, 2) != nil)
	// Dead enemy's tile reads empty.
	testing.expect(t, enemy_at(&game, 7, 7) == nil)
}

@(test)
enemy_at_returns_nil_for_off_grid_queries :: proc(t: ^testing.T) {
	game: Game
	enemy_occupancy_test_setup(&game)
	defer delete(game.enemies)

	append(&game.enemies, Enemy{pos = Vec2{1, 1}, alive = true})
	enemy_occupancy_mark_dirty(&game)

	testing.expect(t, enemy_at(&game, -1, 0) == nil)
	testing.expect(t, enemy_at(&game, 0, -1) == nil)
	testing.expect(t, enemy_at(&game, MAP_WIDTH, 0) == nil)
	testing.expect(t, enemy_at(&game, 0, MAP_HEIGHT) == nil)
}

@(test)
enemy_at_returns_lowest_slot_on_overlapping_tile :: proc(t: ^testing.T) {
	// Two alive enemies share a tile (can happen transiently). The grid must
	// return the lowest-slot enemy, matching the linear scan's first match.
	game: Game
	enemy_occupancy_test_setup(&game)
	defer delete(game.enemies)

	append(&game.enemies, Enemy{pos = Vec2{5, 5}, alive = true, hp = 11})
	append(&game.enemies, Enemy{pos = Vec2{5, 5}, alive = true, hp = 22})
	enemy_occupancy_mark_dirty(&game)

	got := enemy_at(&game, 5, 5)
	testing.expect(t, got != nil)
	testing.expect_value(t, got.hp, 11) // slot 0 wins
	testing.expect(t, got == enemy_at_linear_ref(&game, 5, 5))
}

@(test)
enemy_occupancy_tracks_spawn_append :: proc(t: ^testing.T) {
	game: Game
	enemy_occupancy_test_setup(&game)
	defer delete(game.enemies)

	testing.expect(t, enemy_at(&game, 4, 4) == nil)

	append(&game.enemies, Enemy{pos = Vec2{4, 4}, alive = true})
	enemy_occupancy_mark_dirty(&game)

	testing.expect(t, enemy_at(&game, 4, 4) != nil)
	expect_occupancy_matches_scan(t, &game)
}

@(test)
enemy_occupancy_tracks_move :: proc(t: ^testing.T) {
	game: Game
	enemy_occupancy_test_setup(&game)
	defer delete(game.enemies)

	append(&game.enemies, Enemy{pos = Vec2{2, 2}, alive = true})
	enemy_occupancy_mark_dirty(&game)
	testing.expect(t, enemy_at(&game, 2, 2) != nil)

	// Move the enemy and mark dirty (as the AP move/teleport paths do).
	game.enemies[0].pos = Vec2{8, 9}
	enemy_occupancy_mark_dirty(&game)

	testing.expect(t, enemy_at(&game, 2, 2) == nil) // old tile freed
	testing.expect(t, enemy_at(&game, 8, 9) != nil) // new tile occupied
	expect_occupancy_matches_scan(t, &game)
}

@(test)
enemy_occupancy_tracks_death :: proc(t: ^testing.T) {
	game: Game
	enemy_occupancy_test_setup(&game)
	defer delete(game.enemies)

	append(&game.enemies, Enemy{pos = Vec2{6, 1}, alive = true})
	enemy_occupancy_mark_dirty(&game)
	testing.expect(t, enemy_at(&game, 6, 1) != nil)

	// Death (as combat / status-effect paths do): alive=false + mark dirty.
	game.enemies[0].alive = false
	enemy_occupancy_mark_dirty(&game)

	testing.expect(t, enemy_at(&game, 6, 1) == nil)
	expect_occupancy_matches_scan(t, &game)
}

@(test)
enemy_occupancy_tracks_cleanup_unordered_remove :: proc(t: ^testing.T) {
	// remove_dead_enemies uses unordered_remove, which shuffles slot indices.
	// The grid must be rebuilt against the new slots, not the old ones.
	game: Game
	enemy_occupancy_test_setup(&game)
	defer delete(game.enemies)

	append(&game.enemies, Enemy{pos = Vec2{1, 1}, alive = false}) // will be removed
	append(&game.enemies, Enemy{pos = Vec2{2, 2}, alive = true})
	append(&game.enemies, Enemy{pos = Vec2{3, 3}, alive = true})
	enemy_occupancy_mark_dirty(&game)

	particles := particle_manager_make()
	messages := message_manager_make()
	remove_dead_enemies(&messages, &game, &particles, 0, 0)

	// Slot 0 (dead) gone; unordered_remove moved slot 2 -> slot 0.
	testing.expect_value(t, len(game.enemies), 2)
	testing.expect(t, enemy_at(&game, 1, 1) == nil) // removed
	testing.expect(t, enemy_at(&game, 2, 2) != nil)
	testing.expect(t, enemy_at(&game, 3, 3) != nil)
	expect_occupancy_matches_scan(t, &game)
}
