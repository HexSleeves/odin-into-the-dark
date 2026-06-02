package engine

ENGINE_EVENT_MAX :: 256

Engine_Event_Type :: enum {
	None,
	Key_Down,
	Key_Up,
	Mouse_Move,
	Mouse_Button_Down,
	Mouse_Button_Up,
	Mouse_Wheel,
	Window_Close_Requested,
	Window_Focused,
	Window_Unfocused,
	Window_Resized,
}

Engine_Event :: struct {
	type:        Engine_Event_Type,
	key:         Engine_Key,
	mouse_x:     f32,
	mouse_y:     f32,
	mouse_button: int,
	wheel_delta: f32,
	width:       i32,
	height:      i32,
}

Event_Manager :: struct {
	count:  int,
	events: [ENGINE_EVENT_MAX]Engine_Event,
}

event_manager_make :: proc() -> Event_Manager {
	return Event_Manager{}
}

event_manager_count :: proc(manager: Event_Manager) -> int {
	return manager.count
}

event_manager_push :: proc(manager: ^Event_Manager, event: Engine_Event) -> bool {
	if manager == nil || manager.count >= ENGINE_EVENT_MAX {
		return false
	}
	manager.events[manager.count] = event
	manager.count += 1
	return true
}

event_manager_at :: proc(manager: Event_Manager, index: int) -> Engine_Event {
	if index < 0 || index >= manager.count {
		return Engine_Event{}
	}
	return manager.events[index]
}

event_manager_clear :: proc(manager: ^Event_Manager) {
	if manager == nil {
		return
	}
	for i in 0 ..< manager.count {
		manager.events[i] = Engine_Event{}
	}
	manager.count = 0
}

engine_event_key_down :: proc(key: Engine_Key) -> Engine_Event {
	return Engine_Event{type = .Key_Down, key = key}
}

engine_event_key_up :: proc(key: Engine_Key) -> Engine_Event {
	return Engine_Event{type = .Key_Up, key = key}
}

engine_event_mouse_move :: proc(x, y: f32) -> Engine_Event {
	return Engine_Event{type = .Mouse_Move, mouse_x = x, mouse_y = y}
}

engine_event_mouse_button_down :: proc(button: int, x, y: f32) -> Engine_Event {
	return Engine_Event{type = .Mouse_Button_Down, mouse_button = button, mouse_x = x, mouse_y = y}
}

engine_event_mouse_button_up :: proc(button: int, x, y: f32) -> Engine_Event {
	return Engine_Event{type = .Mouse_Button_Up, mouse_button = button, mouse_x = x, mouse_y = y}
}

engine_event_mouse_wheel :: proc(delta: f32) -> Engine_Event {
	return Engine_Event{type = .Mouse_Wheel, wheel_delta = delta}
}

engine_event_window_close_requested :: proc() -> Engine_Event {
	return Engine_Event{type = .Window_Close_Requested}
}

engine_event_window_focused :: proc() -> Engine_Event {
	return Engine_Event{type = .Window_Focused}
}

engine_event_window_unfocused :: proc() -> Engine_Event {
	return Engine_Event{type = .Window_Unfocused}
}

engine_event_window_resized :: proc(width, height: i32) -> Engine_Event {
	return Engine_Event{type = .Window_Resized, width = width, height = height}
}
