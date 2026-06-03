#+build !js
package engine

import "core:testing"

@(test)
turn_manager_advances_and_resets_count :: proc(t: ^testing.T) {
	turns := turn_manager_make()

	testing.expect_value(t, turn_manager_current(&turns), 0)
	turn_manager_advance(&turns)
	turn_manager_advance(&turns)
	testing.expect_value(t, turn_manager_current(&turns), 2)

	turn_manager_reset(&turns)
	testing.expect_value(t, turn_manager_current(&turns), 0)
}

@(test)
turn_manager_can_restore_saved_count :: proc(t: ^testing.T) {
	turns := turn_manager_make()

	turn_manager_set(&turns, 42)

	testing.expect_value(t, turn_manager_current(&turns), 42)
}