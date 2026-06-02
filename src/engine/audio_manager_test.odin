package engine

import "core:testing"

@(test)
audio_backend_nil_is_valid_and_disabled :: proc(t: ^testing.T) {
	backend := engine_audio_backend_nil()

	testing.expect(t, engine_audio_backend_is_valid(backend))
	testing.expect(t, !engine_audio_backend_is_enabled(backend))
	testing.expect(t, !engine_audio_backend_set_enabled(backend, true))
	testing.expect(t, !engine_audio_backend_toggle(backend))
	engine_audio_backend_play(backend, 1)
}

@(test)
audio_manager_delegates_play_toggle_and_enabled_state :: proc(t: ^testing.T) {
	state := Test_Audio_Backend_State{enabled = true}
	audio := audio_manager_make(test_audio_backend(&state))

	testing.expect(t, audio_manager_is_enabled(&audio))
	audio_manager_play(&audio, 3)
	testing.expect_value(t, state.play_count, 1)
	testing.expect_value(t, state.last_sound_id, 3)

	testing.expect(t, !audio_manager_toggle(&audio))
	testing.expect(t, !audio_manager_is_enabled(&audio))
	audio_manager_play(&audio, 4)
	testing.expect_value(t, state.play_count, 1)

	testing.expect(t, audio_manager_set_enabled(&audio, true))
	audio_manager_play(&audio, 5)
	testing.expect_value(t, state.play_count, 2)
	testing.expect_value(t, state.last_sound_id, 5)
}

@(test)
engine_exposes_owned_audio_manager :: proc(t: ^testing.T) {
	engine := Engine{}
	manager := engine_audio_manager(&engine)

	testing.expect(t, manager == &engine.audio_manager)
}

Test_Audio_Backend_State :: struct {
	enabled: bool,
	play_count: int,
	last_sound_id: int,
}

test_audio_backend :: proc(state: ^Test_Audio_Backend_State) -> Engine_Audio_Backend {
	return Engine_Audio_Backend {
		ctx = state,
		play = test_audio_play,
		is_enabled = test_audio_is_enabled,
		set_enabled = test_audio_set_enabled,
		toggle = test_audio_toggle,
	}
}

test_audio_play :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Test_Audio_Backend_State)ctx
	state.play_count += 1
	state.last_sound_id = sound_id
}

test_audio_is_enabled :: proc(ctx: rawptr) -> bool {
	state := cast(^Test_Audio_Backend_State)ctx
	return state.enabled
}

test_audio_set_enabled :: proc(ctx: rawptr, enabled: bool) -> bool {
	state := cast(^Test_Audio_Backend_State)ctx
	state.enabled = enabled
	return state.enabled
}

test_audio_toggle :: proc(ctx: rawptr) -> bool {
	state := cast(^Test_Audio_Backend_State)ctx
	state.enabled = !state.enabled
	return state.enabled
}
