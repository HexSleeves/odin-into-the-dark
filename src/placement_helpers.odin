package main

can_place_enemy :: proc(game: ^Game, x, y: int) -> bool {
	if !is_walkable(game, x, y) {return false}
	if x == game.player.pos.x && y == game.player.pos.y {return false}
	if enemy_at(game, x, y) != nil {return false}
	if t := tile_at(game, x, y); t != nil && t.type == .Descent {return false}
	return true
}

can_place_item :: proc(game: ^Game, x, y: int) -> bool {
	if !can_place_enemy(game, x, y) {return false}
	if item_at(game, x, y) != nil {return false}
	return true
}
