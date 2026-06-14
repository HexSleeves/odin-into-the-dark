package renderer

import gcore "../core"
import "core:testing"

// Replicates the per-cell linear-scan logic the minimap used before the scratch
// buffer existed, so the equivalence test has a reference oracle.
@(private = "file")
linear_scan_kind :: proc(game: ^gcore.Game, x, y: int) -> Minimap_Entity_Kind {
	e := gcore.enemy_at(game, x, y)
	if e != nil && e.alive && minimap_should_draw_enemy_dot(game, e) {
		return .Enemy
	}
	if gcore.npc_at(game, x, y) >= 0 && gcore.tile_explored_at(game, x, y) {
		return .NPC
	}
	return .None
}

@(test)
minimap_entity_scratch_matches_linear_scans_for_every_cell :: proc(t: ^testing.T) {
	game: gcore.Game
	gcore.game_init_world(&game)
	game.enemies = make([dynamic]gcore.Enemy)
	defer delete(game.enemies)

	// A visible enemy, an explored-but-not-visible enemy (hidden without reveal),
	// and an NPC on an explored tile.
	append(&game.enemies, gcore.Enemy{pos = gcore.Vec2{5, 5}, alive = true})
	append(&game.enemies, gcore.Enemy{pos = gcore.Vec2{9, 3}, alive = true})
	_ = gcore.tile_state_set(&game, 5, 5, true, true, 1)
	_ = gcore.tile_state_set(&game, 9, 3, false, true, 0)

	game.npcs[0] = gcore.NPC {
		pos = gcore.Vec2{2, 7},
	}
	game.npc_count = 1
	_ = gcore.tile_state_set(&game, 2, 7, false, true, 0)

	scratch: Minimap_Entity_Scratch
	minimap_build_entity_scratch(&game, &scratch)

	for y in 0 ..< gcore.MAP_HEIGHT {
		for x in 0 ..< gcore.MAP_WIDTH {
			got := minimap_scratch_kind_at(&scratch, x, y)
			want := linear_scan_kind(&game, x, y)
			testing.expectf(t, got == want, "cell (%d,%d): got %v want %v", x, y, got, want)
		}
	}
}

@(test)
minimap_entity_scratch_skips_dead_and_off_grid_entities :: proc(t: ^testing.T) {
	game: gcore.Game
	gcore.game_init_world(&game)
	game.enemies = make([dynamic]gcore.Enemy)
	defer delete(game.enemies)

	// Dead enemy on a visible tile must NOT stamp.
	append(&game.enemies, gcore.Enemy{pos = gcore.Vec2{4, 4}, alive = false})
	_ = gcore.tile_state_set(&game, 4, 4, true, true, 1)
	// Off-grid enemy must not OOB-write or stamp.
	append(&game.enemies, gcore.Enemy{pos = gcore.Vec2{-1, 5}, alive = true})

	scratch: Minimap_Entity_Scratch
	minimap_build_entity_scratch(&game, &scratch)

	testing.expect_value(t, minimap_scratch_kind_at(&scratch, 4, 4), Minimap_Entity_Kind.None)
}

@(test)
minimap_entity_scratch_records_first_enemy_when_two_share_a_tile :: proc(t: ^testing.T) {
	game: gcore.Game
	gcore.game_init_world(&game)
	game.enemies = make([dynamic]gcore.Enemy)
	defer delete(game.enemies)

	// Two enemies on the same visible tile: first-match wins (it's an Enemy stamp
	// either way, but an NPC on that tile must not override the enemy stamp).
	append(&game.enemies, gcore.Enemy{pos = gcore.Vec2{6, 6}, alive = true})
	append(&game.enemies, gcore.Enemy{pos = gcore.Vec2{6, 6}, alive = true})
	_ = gcore.tile_state_set(&game, 6, 6, true, true, 1)

	game.npcs[0] = gcore.NPC {
		pos = gcore.Vec2{6, 6},
	}
	game.npc_count = 1

	scratch: Minimap_Entity_Scratch
	minimap_build_entity_scratch(&game, &scratch)

	testing.expect_value(t, minimap_scratch_kind_at(&scratch, 6, 6), Minimap_Entity_Kind.Enemy)
}
