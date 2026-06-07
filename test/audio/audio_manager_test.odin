#+build !js
package audio

import eng "../engine"
import "core:mem"
import "core:sync"
import "core:testing"

@(private = "file")
audio_manager_test_g_audio_mutex: sync.Mutex

@(test)
audio_manager_make_wraps_current_audio_backend :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved := g_audio
	defer g_audio = saved

	test_state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	g_audio.enabled = true
	g_audio.backend = test_game_audio_backend_make(&test_state)
	audio := audio_manager_make()

	testing.expect(t, eng.audio_manager_is_enabled(&audio))
}

@(test)
audio_manager_reports_enabled_state_from_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = false,
	}
	audio := eng.audio_manager_make(test_game_audio_backend_make(&state))

	testing.expect(t, !audio_manager_is_enabled(&audio))

	state.enabled = true
	testing.expect(t, audio_manager_is_enabled(&audio))
}

@(test)
audio_manager_play_sfx_delegates_to_engine_audio_backend :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved := g_audio
	defer g_audio = saved

	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	backend := test_game_audio_backend_make(&state)
	g_audio.backend = backend
	g_audio.sounds[.Mine] = 42

	audio := eng.audio_manager_make(backend)
	audio_manager_play_sfx(&audio, .Mine)
	testing.expect_value(t, state.play_count, 1)
	testing.expect_value(t, state.last_sound_id, 42)
}

@(test)
audio_manager_stop_sfx_delegates_to_backend :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved := g_audio
	defer g_audio = saved

	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	backend := test_game_audio_backend_make(&state)
	g_audio.backend = backend
	g_audio.sounds[.Hit] = 7

	audio := eng.audio_manager_make(backend)
	audio_manager_stop_sfx(&audio, .Hit)
	testing.expect_value(t, state.stop_count, 1)
	testing.expect_value(t, state.last_stopped_id, 7)
}

@(test)
audio_manager_set_sfx_volume_delegates_to_backend :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved := g_audio
	defer g_audio = saved

	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	backend := test_game_audio_backend_make(&state)
	g_audio.backend = backend
	g_audio.sounds[.Death] = 13

	audio := eng.audio_manager_make(backend)
	audio_manager_set_sfx_volume(&audio, .Death, 0.75)
	testing.expect_value(t, state.last_volume_id, 13)
	testing.expect_value(t, state.last_volume, f32(0.75))
}

@(test)
audio_manager_set_master_volume_delegates_to_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend_make(&state))

	audio_manager_set_master_volume(&audio, 0.5)
	testing.expect_value(t, state.master_volume, f32(0.5))
}

@(test)
audio_manager_play_sfx_looped_delegates_to_backend :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved := g_audio
	defer g_audio = saved

	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	backend := test_game_audio_backend_make(&state)
	g_audio.backend = backend
	g_audio.sounds[.Water] = 99

	audio := eng.audio_manager_make(backend)
	audio_manager_play_sfx_looped(&audio, .Water)
	testing.expect_value(t, state.play_looped_count, 1)
	testing.expect_value(t, state.last_looped_id, 99)
}

@(test)
audio_manager_update_delegates_to_backend :: proc(t: ^testing.T) {
	state := Test_Game_Audio_Backend_State {
		enabled = true,
	}
	audio := eng.audio_manager_make(test_game_audio_backend_make(&state))

	eng.audio_manager_update(&audio)
	testing.expect_value(t, state.update_count, 1)
}

@(test)
audio_manager_stop_when_disabled_still_delegates :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved := g_audio
	defer g_audio = saved

	state := Test_Game_Audio_Backend_State {
		enabled = false,
	}
	backend := test_game_audio_backend_make(&state)
	g_audio.backend = backend
	g_audio.sounds[.Footstep] = 3

	audio := eng.audio_manager_make(backend)
	audio_manager_stop_sfx(&audio, .Footstep)
	testing.expect_value(t, state.stop_count, 1)
}

@(test)
audio_manager_play_looped_skipped_when_disabled :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved := g_audio
	defer g_audio = saved

	state := Test_Game_Audio_Backend_State {
		enabled = false,
	}
	backend := test_game_audio_backend_make(&state)
	g_audio.backend = backend
	g_audio.sounds[.Footstep] = 3

	audio := eng.audio_manager_make(backend)
	audio_manager_play_sfx_looped(&audio, .Footstep)
	testing.expect_value(t, state.play_looped_count, 0)
}

@(test)
music_init_unloads_previously_loaded_tracks_when_a_later_tier_fails :: proc(t: ^testing.T) {
	sync.mutex_lock(&audio_manager_test_g_audio_mutex)
	defer sync.mutex_unlock(&audio_manager_test_g_audio_mutex)

	saved_audio := g_audio
	saved_music := g_music
	defer {
		g_audio = saved_audio
		g_music = saved_music
	}

	state := Test_Music_Backend_State {
		fail_load_number = 2,
	}
	g_audio.enabled = true
	g_audio.backend = test_music_backend_make(&state)
	g_music = {}

	track: mem.Tracking_Allocator
	previous_allocator := context.allocator
	mem.tracking_allocator_init(&track, previous_allocator)
	defer mem.tracking_allocator_destroy(&track)

	context.allocator = mem.tracking_allocator(&track)
	music_init()
	context.allocator = previous_allocator

	testing.expect(t, !g_music.initialized)
	testing.expect(t, !g_music.enabled)
	testing.expect_value(t, state.load_music_count, 2)
	testing.expect_value(t, state.unload_music_count, 1)
	testing.expect_value(t, len(g_music.wav_data[.Shallow]), 0)
	testing.expect_value(t, len(g_music.wav_data[.Mid]), 0)
	testing.expect_value(t, len(g_music.wav_data[.Deep]), 0)
	testing.expect_value(t, len(track.allocation_map), 0)
}

Test_Music_Backend_State :: struct {
	load_music_count:   int,
	unload_music_count: int,
	fail_load_number:   int,
}

test_music_backend_make :: proc(state: ^Test_Music_Backend_State) -> eng.Engine_Audio_Backend {
	backend := eng.engine_audio_backend_nil()
	backend.ctx = state
	backend.load_music = test_music_load
	backend.unload_music = test_music_unload
	backend.is_music_valid = test_music_is_valid
	backend.set_music_looping = test_music_set_looping
	backend.set_music_volume = test_music_set_volume
	backend.play_music = test_music_play
	backend.stop_music = test_music_stop
	backend.pause_music = test_music_pause
	backend.resume_music = test_music_resume
	backend.update_music = test_music_update
	backend.get_frame_time = test_music_frame_time
	return backend
}

test_music_load :: proc(
	ctx: rawptr,
	format: string,
	data: rawptr,
	data_len: i32,
) -> eng.Engine_Music_Handle {
	state := cast(^Test_Music_Backend_State)ctx
	state.load_music_count += 1
	if state.load_music_count == state.fail_load_number {
		return nil
	}
	return rawptr(uintptr(state.load_music_count))
}

test_music_unload :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	state := cast(^Test_Music_Backend_State)ctx
	if handle != nil {
		state.unload_music_count += 1
	}
}

test_music_is_valid :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) -> bool {return(
		handle !=
		nil \
	)}
test_music_set_looping :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle, looping: bool) {}
test_music_set_volume :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle, volume: f32) {}
test_music_play :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {}
test_music_stop :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {}
test_music_pause :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {}
test_music_resume :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {}
test_music_update :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {}
test_music_frame_time :: proc(ctx: rawptr) -> f32 {return 1.0 / 60.0}

// ─── Test backend ────────────────────────────────────────────────────────────

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

test_game_audio_backend_make :: proc(
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
