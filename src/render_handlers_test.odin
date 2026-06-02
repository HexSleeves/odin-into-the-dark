package main

import "core:testing"
import eng "./engine"

@(test)
render_handlers_accept_engine_context_for_services :: proc(t: ^testing.T) {
	top_level_render: proc(engine: ^eng.Engine, game: ^Game) = render_game
	title_render: proc(engine: ^eng.Engine, game: ^Game) = render_title_screen
	map_render: proc(engine: ^eng.Engine, game: ^Game) = render_map
	webs_render: proc(engine: ^eng.Engine, game: ^Game) = render_webs
	player_render: proc(engine: ^eng.Engine, game: ^Game) = render_player
	enemies_render: proc(engine: ^eng.Engine, game: ^Game) = render_enemies
	items_render: proc(engine: ^eng.Engine, game: ^Game) = render_items
	inventory_render: proc(engine: ^eng.Engine, game: ^Game) = render_inventory

	testing.expect(t, top_level_render != nil)
	testing.expect(t, title_render != nil)
	testing.expect(t, map_render != nil)
	testing.expect(t, webs_render != nil)
	testing.expect(t, player_render != nil)
	testing.expect(t, enemies_render != nil)
	testing.expect(t, items_render != nil)
	testing.expect(t, inventory_render != nil)
}
