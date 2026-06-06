package gen

import gcore "../core"

// generate_town builds the surface hub (depth 0): a daylit town with NPCs,
// building structures, and a mine entrance (Descent tile). No combat, no hazards.
generate_town :: proc(game: ^Game) {
	// Walls everywhere, then carve the town plaza.
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i].type = .Wall
	}

	// Town plaza: a large open rectangle centered on the map.
	px1 := 8
	py1 := 6
	px2 := MAP_WIDTH - 8
	py2 := MAP_HEIGHT - 6
	carve_rect(game, px1, py1, px2, py2)

	// A few building outlines inside the plaza (walls forming structures).
	carve_building(game, 12, 10, 22, 17) // shop (left)
	carve_building(game, MAP_WIDTH - 24, 10, MAP_WIDTH - 14, 17) // hall (right)
	carve_building(game, MAP_WIDTH / 2 - 5, py2 - 9, MAP_WIDTH / 2 + 5, py2 - 3) // guard post

	// Player starts at the town center.
	game.player.pos = gcore.Vec2{MAP_WIDTH / 2, MAP_HEIGHT / 2}

	// Mine entrance (Descent) near the top-center of the plaza.
	mine_x := MAP_WIDTH / 2
	mine_y := py1 + 2
	game.tiles[gcore.pos_to_idx(mine_x, mine_y)].type = .Descent

	gcore.place_town_npcs(game)

	game.palette = gcore.palette_for_depth(0)
	game.player.light_radius = gcore.SURFACE_LIGHT_RADIUS
	game.active_npc = -1
}

// carve_building draws a wall outline (a simple structure) with a doorway.
@(private = "file")
carve_building :: proc(game: ^Game, x1, y1, x2, y2: int) {
	for x in x1 ..= x2 {
		set_wall(game, x, y1)
		set_wall(game, x, y2)
	}
	for y in y1 ..= y2 {
		set_wall(game, x1, y)
		set_wall(game, x2, y)
	}
	// Doorway in the bottom wall, centered.
	door_x := (x1 + x2) / 2
	if door_x > 0 && door_x < MAP_WIDTH {
		game.tiles[gcore.pos_to_idx(door_x, y2)].type = .Floor
	}
}

@(private = "file")
set_wall :: proc(game: ^Game, x, y: int) {
	if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
		game.tiles[gcore.pos_to_idx(x, y)].type = .Wall
	}
}

// (NPC placement lives in core/dialogue.odin so io can repopulate on load.)
