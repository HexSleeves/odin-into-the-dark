#+build !js
package engine

import "core:testing"

@(test)
event_manager_starts_empty_and_preserves_event_order :: proc(t: ^testing.T) {
	events := event_manager_make()

	testing.expect_value(t, event_manager_count(events), 0)
	testing.expect(t, event_manager_push(&events, engine_event_key_down(.W)))
	testing.expect(t, event_manager_push(&events, engine_event_mouse_move(10, 20)))
	testing.expect(t, event_manager_push(&events, engine_event_window_resized(800, 600)))

	testing.expect_value(t, event_manager_count(events), 3)
	testing.expect_value(t, event_manager_at(events, 0).type, Engine_Event_Type.Key_Down)
	testing.expect_value(t, event_manager_at(events, 0).key, Engine_Key.W)
	testing.expect_value(t, event_manager_at(events, 1).type, Engine_Event_Type.Mouse_Move)
	testing.expect_value(t, event_manager_at(events, 1).mouse_x, f32(10))
	testing.expect_value(t, event_manager_at(events, 1).mouse_y, f32(20))
	testing.expect_value(t, event_manager_at(events, 2).type, Engine_Event_Type.Window_Resized)
	testing.expect_value(t, event_manager_at(events, 2).width, i32(800))
	testing.expect_value(t, event_manager_at(events, 2).height, i32(600))
}

@(test)
event_manager_clears_frame_events_and_rejects_overflow :: proc(t: ^testing.T) {
	events := event_manager_make()

	for _ in 0 ..< ENGINE_EVENT_MAX {
		testing.expect(t, event_manager_push(&events, engine_event_key_up(.A)))
	}
	testing.expect_value(t, event_manager_count(events), ENGINE_EVENT_MAX)
	testing.expect(t, !event_manager_push(&events, engine_event_key_up(.D)))

	event_manager_clear(&events)
	testing.expect_value(t, event_manager_count(events), 0)
	testing.expect_value(t, event_manager_at(events, 0).type, Engine_Event_Type.None)
}