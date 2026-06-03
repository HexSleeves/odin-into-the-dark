package engine

import "base:runtime"

Frame_Manager :: struct {
	frame_index:    int,
	delta_time:     f32,
	elapsed_time:   f32,
	quit_requested: bool,
	arena:          runtime.Arena,
}

frame_manager_make :: proc() -> Frame_Manager {
	return Frame_Manager{}
}

frame_manager_begin :: proc(frames: ^Frame_Manager, delta_time: f32) {
	if frames == nil {
		return
	}
	frames.frame_index += 1
	frames.delta_time = max(delta_time, 0)
	frames.elapsed_time += frames.delta_time
	runtime.arena_free_all(&frames.arena)
}

frame_manager_index :: proc(frames: Frame_Manager) -> int {
	return frames.frame_index
}

frame_manager_delta_time :: proc(frames: Frame_Manager) -> f32 {
	return frames.delta_time
}

frame_manager_elapsed_time :: proc(frames: Frame_Manager) -> f32 {
	return frames.elapsed_time
}

frame_manager_request_quit :: proc(frames: ^Frame_Manager) {
	if frames == nil {
		return
	}
	frames.quit_requested = true
}

frame_manager_clear_quit :: proc(frames: ^Frame_Manager) {
	if frames == nil {
		return
	}
	frames.quit_requested = false
}

frame_manager_quit_requested :: proc(frames: Frame_Manager) -> bool {
	return frames.quit_requested
}

frame_manager_allocator :: proc(frames: ^Frame_Manager) -> runtime.Allocator {
	if frames == nil {
		return context.allocator
	}
	return runtime.arena_allocator(&frames.arena)
}

frame_manager_destroy :: proc(frames: ^Frame_Manager) {
	if frames == nil {
		return
	}
	runtime.arena_destroy(&frames.arena)
}
