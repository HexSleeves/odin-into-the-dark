package main

import eng "./engine"
import "core:testing"

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
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_play_sfx(&audio, .Mine)
	testing.expect_value(t, state.play_count, 1)
	testing.expect_value(t, state.last_sound_id, int(Sound_Type.Mine))
}

@(test)
audio_manager_stop_sfx_delegates_to_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_stop_sfx(&audio, .Hit)
	testing.expect_value(t, state.stop_count, 1)
	testing.expect_value(t, state.last_stopped_id, int(Sound_Type.Hit))
}

@(test)
audio_manager_set_sfx_volume_delegates_to_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_set_sfx_volume(&audio, .Death, 0.75)
	testing.expect_value(t, state.last_volume_id, int(Sound_Type.Death))
	testing.expect_value(t, state.last_volume, f32(0.75))
}

@(test)
audio_manager_set_master_volume_delegates_to_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_set_master_volume(&audio, 0.5)
	testing.expect_value(t, state.master_volume, f32(0.5))
}

@(test)
audio_manager_play_sfx_looped_delegates_to_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_play_sfx_looped(&audio, .Water)
	testing.expect_value(t, state.play_looped_count, 1)
	testing.expect_value(t, state.last_looped_id, int(Sound_Type.Water))
}

@(test)
audio_manager_update_delegates_to_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	eng.audio_manager_update(&audio)
	testing.expect_value(t, state.update_count, 1)
}

@(test)
audio_manager_stop_when_disabled_still_delegates :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = false,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_stop_sfx(&audio, .Footstep)
	testing.expect_value(t, state.stop_count, 1)
}

@(test)
audio_manager_play_looped_skipped_when_disabled :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = false,
	}
	audio := eng.audio_manager_make(test_game_audio_backend(&state))

	audio_manager_play_sfx_looped(&audio, .Water)
	testing.expect_value(t, state.play_looped_count, 0)
}

Test_Game_Audio_Backend_State :: struct {
	enabled:           bool,
	play_count:        int,
	last_sound_id:     int,
	stop_count:        int,
	last_stopped_id:   int,
	last_volume_id:    int,
	last_volume:       f32,
	master_volume:     f32,
	play_looped_count: int,
	last_looped_id:    int,
	update_count:      int,
}

test_game_audio_backend :: proc(
	state: ^Test_Game_Audio_Backend_State,
) -> eng.Engine_Audio_Backend {
	return eng.Engine_Audio_Backend {
		ctx = state,
		play = test_game_audio_play,
		is_enabled = test_game_audio_is_enabled,
		set_enabled = test_game_audio_set_enabled,
		toggle = test_game_audio_toggle,
		stop = test_game_audio_stop,
		set_volume = test_game_audio_set_volume,
		set_master_volume = test_game_audio_set_master_volume,
		play_looped = test_game_audio_play_looped,
		update = test_game_audio_update,
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

test_game_audio_stop :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.stop_count += 1
	state.last_stopped_id = sound_id
}

test_game_audio_set_volume :: proc(ctx: rawptr, sound_id: int, volume: f32) {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.last_volume_id = sound_id
	state.last_volume = volume
}

test_game_audio_set_master_volume :: proc(ctx: rawptr, volume: f32) {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.master_volume = volume
}

test_game_audio_play_looped :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.play_looped_count += 1
	state.last_looped_id = sound_id
}

test_game_audio_update :: proc(ctx: rawptr) {
	state := cast(^Test_Game_Audio_Backend_State)ctx
	state.update_count += 1
}
