#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
scene_for_state_maps_all_game_states :: proc(t: ^testing.T) {
	testing.expect_value(t, scene_for_state(.Title_Screen), Game_Scene.Title)
	testing.expect_value(t, scene_for_state(.Playing), Game_Scene.Gameplay)
	testing.expect_value(t, scene_for_state(.Game_Over), Game_Scene.Game_Over)
	testing.expect_value(t, scene_for_state(.Victory), Game_Scene.Victory)
	testing.expect_value(t, scene_for_state(.Viewing_Inventory), Game_Scene.Inventory)
	testing.expect_value(t, scene_for_state(.Viewing_Crafting), Game_Scene.Crafting)
	testing.expect_value(t, scene_for_state(.Viewing_Help), Game_Scene.Help)
	testing.expect_value(t, scene_for_state(.Viewing_Scores), Game_Scene.Scores)
}

@(test)
game_scene_manager_handlers_use_engine_owned_manager :: proc(t: ^testing.T) {
	init_handler: proc(scenes: []eng.Engine_Scene, engine: ^eng.Engine, game: ^Game) -> bool =
		game_scene_manager_init
	update_handler: proc(engine: ^eng.Engine, game: ^Game) -> bool = game_scene_manager_update
	render_handler: proc(engine: ^eng.Engine, game: ^Game) = game_scene_manager_render

	testing.expect(t, init_handler != nil)
	testing.expect(t, update_handler != nil)
	testing.expect(t, render_handler != nil)
}