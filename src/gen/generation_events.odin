package gen

import gcore "../core"
import "core:math/rand"

// spawn_floor_event places at most one event tile (Shrine, Chest, or Merchant)
// on a random walkable floor tile, gated by depth and chance.
spawn_floor_event :: proc(game: ^gcore.Game) {
	if game.depth < gcore.EVENT_MIN_DEPTH {return}
	if rand.int_max(100) >= gcore.EVENT_SPAWN_CHANCE {return}

	event_type := pick_event_type()

	// Try to place on a walkable floor tile away from player and descent
	for _ in 0 ..< 200 {
		x := rand.int_max(gcore.MAP_WIDTH - 2) + 1
		y := rand.int_max(gcore.MAP_HEIGHT - 2) + 1
		if !can_place_event(game, x, y) {continue}

		idx := gcore.pos_to_idx(x, y)
		game.tiles[idx].type = event_type
		return
	}
}

@(private = "file")
pick_event_type :: proc() -> gcore.Tile_Type {
	roll := rand.int_max(3)
	switch roll {
	case 0:
		return .Shrine
	case 1:
		return .Chest
	case 2:
		return .Merchant
	}
	return .Shrine
}

@(private = "file")
can_place_event :: proc(game: ^gcore.Game, x, y: int) -> bool {
	if x <= 0 || x >= gcore.MAP_WIDTH - 1 || y <= 0 || y >= gcore.MAP_HEIGHT - 1 {
		return false
	}
	idx := gcore.pos_to_idx(x, y)
	if game.tiles[idx].type != .Floor {return false}
	// Not on player start
	if x == game.player.pos.x && y == game.player.pos.y {return false}
	// Not adjacent to descent
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			nx := x + dx
			ny := y + dy
			if nx >= 0 && nx < gcore.MAP_WIDTH && ny >= 0 && ny < gcore.MAP_HEIGHT {
				if game.tiles[gcore.pos_to_idx(nx, ny)].type == .Descent {return false}
			}
		}
	}
	// Not on an enemy or item
	if gcore.enemy_at(game, x, y) != nil {return false}
	if gcore.item_at(game, x, y) != nil {return false}
	return true
}
