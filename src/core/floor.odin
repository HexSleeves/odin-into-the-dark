package core

import "base:runtime"

saved_floor_destroy :: proc(floor: ^Saved_Floor) {
	if floor == nil {return}
	if floor.rooms != nil {delete(floor.rooms)}
	if floor.enemies != nil {delete(floor.enemies)}
	if floor.items != nil {delete(floor.items)}
	if floor.light_sources != nil {delete(floor.light_sources)}
	floor^ = {}
}

clear_visited_floors :: proc(game: ^Game) {
	if game == nil {return}
	for i in 0 ..< len(game.visited_floors) {
		if game.visited_floors[i] == nil {continue}
		saved_floor_destroy(game.visited_floors[i])
		free(game.visited_floors[i], runtime.default_allocator())
		game.visited_floors[i] = nil
	}
}
