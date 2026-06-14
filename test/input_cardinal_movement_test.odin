#+build !js
package main

import eng "./engine"
import "core:testing"

// Regression lock for R10: the roguelike grid only supports cardinal movement.
// read_cardinal_press must collapse a simultaneous diagonal key press to a single
// horizontal axis (drop the vertical component) so the player never moves
// diagonally, while leaving pure-cardinal and idle input untouched.

cardinal_input_make :: proc(state: ^Test_Input_Backend_State) -> Input_Manager {
	input := input_manager_make()
	input.backend = test_input_backend(state)
	return input
}

@(test)
read_cardinal_press_collapses_diagonal_to_horizontal_axis_only :: proc(t: ^testing.T) {
	// North + East held at once -> must resolve to East only (dx=1, dy=0).
	state := Test_Input_Backend_State{}
	state.pressed[eng.Engine_Key.W] = true // Move_North
	state.pressed[eng.Engine_Key.D] = true // Move_East
	input := cardinal_input_make(&state)

	dx, dy := read_cardinal_press(&input)
	testing.expect_value(t, dx, 1)
	testing.expect_value(t, dy, 0)

	// South + West held at once -> West only (dx=-1, dy=0).
	state2 := Test_Input_Backend_State{}
	state2.pressed[eng.Engine_Key.S] = true // Move_South
	state2.pressed[eng.Engine_Key.A] = true // Move_West
	input2 := cardinal_input_make(&state2)

	dx2, dy2 := read_cardinal_press(&input2)
	testing.expect_value(t, dx2, -1)
	testing.expect_value(t, dy2, 0)
}

@(test)
read_cardinal_press_preserves_pure_cardinal_and_idle_input :: proc(t: ^testing.T) {
	// Pure vertical press survives untouched.
	north := Test_Input_Backend_State{}
	north.pressed[eng.Engine_Key.W] = true
	in_north := cardinal_input_make(&north)
	ndx, ndy := read_cardinal_press(&in_north)
	testing.expect_value(t, ndx, 0)
	testing.expect_value(t, ndy, -1)

	// Pure horizontal press survives untouched.
	west := Test_Input_Backend_State{}
	west.pressed[eng.Engine_Key.A] = true
	in_west := cardinal_input_make(&west)
	wdx, wdy := read_cardinal_press(&in_west)
	testing.expect_value(t, wdx, -1)
	testing.expect_value(t, wdy, 0)

	// No keys pressed -> no movement.
	idle := Test_Input_Backend_State{}
	in_idle := cardinal_input_make(&idle)
	idx, idy := read_cardinal_press(&in_idle)
	testing.expect_value(t, idx, 0)
	testing.expect_value(t, idy, 0)
}
