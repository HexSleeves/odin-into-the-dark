package main

import "core:testing"
import eng "./engine"

@(test)
audio_manager_make_wraps_current_audio_backend :: proc(t: ^testing.T) {
	audio := audio_manager_make()

	testing.expect(t, eng.audio_manager_is_enabled(&audio) == g_audio.enabled)
}

@(test)
audio_manager_reports_enabled_state_from_backend :: proc(t: ^testing.T) {
	audio := audio_manager_make()
	was_enabled := g_audio.enabled
	defer g_audio.enabled = was_enabled

	g_audio.enabled = false
	testing.expect(t, !audio_manager_is_enabled(&audio))

	g_audio.enabled = true
	testing.expect(t, audio_manager_is_enabled(&audio))
}

@(test)
audio_manager_play_sfx_delegates_to_engine_audio_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State{enabled = true}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_play_sfx(&audio, .Mine)
	testing.expect_value(t, state.play_count, 1)
	testing.expect_value(t, state.last_sound_id, int(Sound_Type.Mine))
}

Test_Game_Audio_Backend_State :: struct {
	enabled: bool,
	play_count: int,
	last_sound_id: int,
}

test_game_audio_backend :: proc(state: ^Test_Game_Audio_Backend_State) -> eng.Engine_Audio_Backend {
	return eng.Engine_Audio_Backend {
		ctx = state,
		play = test_game_audio_play,
		is_enabled = test_game_audio_is_enabled,
		set_enabled = test_game_audio_set_enabled,
		toggle = test_game_audio_toggle,
	}
}

test_game_audio_play :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.play_count += 1
	state.last_sound_id = sound_id
}

test_game_audio_is_enabled :: proc(ctx: rawptr) -> bool {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	return state.enabled
}

test_game_audio_set_enabled :: proc(ctx: rawptr, enabled: bool) -> bool {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.enabled = enabled
	return state.enabled
}

test_game_audio_toggle :: proc(ctx: rawptr) -> bool {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.enabled = !state.enabled
	return state.enabled
}
