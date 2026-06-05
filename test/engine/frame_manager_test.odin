#+build !js
package engine

import "core:testing"

@(test)
frame_manager_starts_empty_and_advances_time :: proc(t: ^testing.T) {
	frames := frame_manager_make()

	testing.expect_value(t, frame_manager_index(frames), 0)
	testing.expect_value(t, frame_manager_delta_time(frames), f32(0))
	testing.expect_value(t, frame_manager_elapsed_time(frames), f32(0))
	testing.expect(t, !frame_manager_quit_requested(frames))

	frame_manager_begin(&frames, 0.125)

	testing.expect_value(t, frame_manager_index(frames), 1)
	testing.expect_value(t, frame_manager_delta_time(frames), f32(0.125))
	testing.expect_value(t, frame_manager_elapsed_time(frames), f32(0.125))
}

@(test)
frame_manager_tracks_quit_requests :: proc(t: ^testing.T) {
	frames := frame_manager_make()

	frame_manager_request_quit(&frames)
	testing.expect(t, frame_manager_quit_requested(frames))

	frame_manager_clear_quit(&frames)
	testing.expect(t, !frame_manager_quit_requested(frames))
}
