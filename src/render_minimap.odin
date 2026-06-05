package main

import eng "./engine"


// ─── Minimap overlay ──────────────────────────────────────────────────────────

MINIMAP_TILE_SIZE :: i32(2) // each map tile = 2x2 pixels on minimap
minimap_should_draw_enemy_dot :: proc(game: ^Game, enemy: ^Enemy) -> bool {
	if game == nil || enemy == nil || !enemy.alive {
		return false
	}
	if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
		return true
	}
	return game.minimap_reveal_enemies && tile_explored_at(game, enemy.pos.x, enemy.pos.y)
}

MINIMAP_MARGIN :: i32(8)

render_minimap :: proc(engine: ^eng.Engine, game: ^Game) {
	_ = engine
	clay_render_minimap(game)
}
