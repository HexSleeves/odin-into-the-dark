package gen

import "core:math/rand"


spawn_ore_veins :: proc(game: ^Game) {
	// Clear ore veins
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.ore_veins[i] = {}
	}

	depth := game.depth

	// Define ore colors
	iron_color := Engine_Color{200, 120, 50, 255}
	copper_color := Engine_Color{80, 180, 80, 255}
	crystal_color := Engine_Color{100, 150, 255, 255}
	gold_color := Engine_Color{255, 215, 0, 255}

	// Scan all wall tiles, ~10% chance to become ore vein
	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Wall {continue}

			// ~10% chance for wall to be ore
			if rand.int_max(100) >= 10 {continue}

			// Check if wall is adjacent to at least one floor-like tile (accessible)
			has_floor := false
			adj_dx := CARDINAL_DX
			adj_dy := CARDINAL_DY
			for dir in 0 ..< 4 {
				nx := x + adj_dx[dir]
				ny := y + adj_dy[dir]
				if nx >= 0 && nx < MAP_WIDTH && ny >= 0 && ny < MAP_HEIGHT {
					t := game.tiles[pos_to_idx(nx, ny)]
					if t.type == .Floor ||
					   t.type == .Rubble ||
					   t.type == .Descent ||
					   t.type == .Water ||
					   t.type == .Gas_Vent ||
					   t.type == .Unstable {
						has_floor = true
						break
					}
				}
			}
			if !has_floor {continue}

			// Weighted ore type selection by depth
			ore_type: string
			ore_color: Engine_Color
			roll := rand.int_max(100)

			if depth >= 8 {
				// iron 10, copper 25, crystal 35, gold 30
				if roll <
				   10 {ore_type = "iron_ore"; ore_color = iron_color} else if roll < 35 {ore_type = "copper_ore"; ore_color = copper_color} else if roll < 70 {ore_type = "crystal_shard"; ore_color = crystal_color} else {ore_type = "gold_nugget"; ore_color = gold_color}
			} else if depth >= 5 {
				// iron 20, copper 40, crystal 40
				if roll <
				   20 {ore_type = "iron_ore"; ore_color = iron_color} else if roll < 60 {ore_type = "copper_ore"; ore_color = copper_color} else {ore_type = "crystal_shard"; ore_color = crystal_color}
			} else if depth >= 3 {
				// iron 40, copper 60
				if roll <
				   40 {ore_type = "iron_ore"; ore_color = iron_color} else {ore_type = "copper_ore"; ore_color = copper_color}
			} else {
				// depth 1-2: only iron
				ore_type = "iron_ore"
				ore_color = iron_color
			}

			game.ore_veins[idx] = Ore_Vein {
				ore_type = ore_type,
				color    = ore_color,
			}
		}
	}

	logger_debugf(.Gen, "ore veins spawned (depth=%v)", depth)
}

// ─── Anvil spawning (one per floor) ───────────────────────────────────────────
