package main

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

