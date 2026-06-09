package audio

import eng "../engine"
import k2 "../../../karl2d"

MAX_KARL2D_SOUNDS :: 64
MAX_KARL2D_MUSIC :: 8

Karl2D_Audio_State :: struct {
	sounds:        [MAX_KARL2D_SOUNDS]k2.Sound,
	sound_loaded:  [MAX_KARL2D_SOUNDS]bool,
	sound_volume:  [MAX_KARL2D_SOUNDS]f32,
	music:         [MAX_KARL2D_MUSIC]k2.Sound,
	music_loaded:  [MAX_KARL2D_MUSIC]bool,
	music_volume:  [MAX_KARL2D_MUSIC]f32,
	enabled:       bool,
	initialized:   bool,
	master_volume: f32,
}

g_karl2d_audio: Karl2D_Audio_State

game_audio_backend :: proc(audio: ^Game_Audio) -> eng.Engine_Audio_Backend {
	return eng.Engine_Audio_Backend {
		ctx = &g_karl2d_audio,
		init_audio = karl2d_audio_init,
		shutdown_audio = karl2d_audio_shutdown,
		is_audio_ready = karl2d_audio_is_ready,
		load_sound = karl2d_audio_load_sound,
		unload_sound = karl2d_audio_unload_sound,
		play = karl2d_audio_play,
		stop = karl2d_audio_stop,
		set_volume = karl2d_audio_set_volume,
		play_looped = karl2d_audio_play_looped,
		is_playing = karl2d_audio_is_playing,
		is_enabled = karl2d_audio_is_enabled,
		set_enabled = karl2d_audio_set_enabled,
		toggle = karl2d_audio_toggle,
		set_master_volume = karl2d_audio_set_master_volume,
		update = karl2d_audio_update,
		load_music = karl2d_audio_load_music,
		unload_music = karl2d_audio_unload_music,
		play_music = karl2d_audio_play_music,
		stop_music = karl2d_audio_stop_music,
		pause_music = karl2d_audio_pause_music,
		resume_music = karl2d_audio_resume_music,
		set_music_volume = karl2d_audio_set_music_volume,
		update_music = karl2d_audio_update_music,
		is_music_valid = karl2d_audio_is_music_valid,
		set_music_looping = karl2d_audio_set_music_looping,
		get_frame_time = karl2d_audio_get_frame_time,
	}
}

karl2d_audio_init :: proc(ctx: rawptr) -> bool {
	state := cast(^Karl2D_Audio_State)ctx
	if state == nil {return false}
	state.enabled = true
	state.initialized = true
	state.master_volume = 1
	return true
}

karl2d_audio_shutdown :: proc(ctx: rawptr) {
	state := cast(^Karl2D_Audio_State)ctx
	if state == nil {return}
	for i in 0 ..< MAX_KARL2D_SOUNDS {
		if state.sound_loaded[i] {
			k2.destroy_sound(state.sounds[i])
		}
	}
	for i in 0 ..< MAX_KARL2D_MUSIC {
		if state.music_loaded[i] {
			k2.destroy_sound(state.music[i])
		}
	}
	state^ = {}
}

karl2d_audio_is_ready :: proc(ctx: rawptr) -> bool {
	state := cast(^Karl2D_Audio_State)ctx
	return state != nil && state.initialized
}

karl2d_audio_load_sound :: proc(ctx: rawptr, desc: eng.Engine_Sound_Desc) -> int {
	state := cast(^Karl2D_Audio_State)ctx
	if state == nil || desc.samples == nil || desc.frame_count == 0 {return -1}
	slot := karl2d_audio_first_free_sound(state)
	if slot < 0 {return -1}
	format: k2.Raw_Sound_Format
	switch desc.sample_size {
	case 8:
		format = .Integer8
	case 16:
		format = .Integer16
	case 32:
		format = .Integer32
	case:
		return -1
	}
	channels, channels_ok := karl2d_audio_channels(desc.channels)
	if !channels_ok {return -1}
	bytes_per_sample := int(desc.sample_size / 8)
	byte_len := int(desc.frame_count * desc.channels) * bytes_per_sample
	data := ([^]u8)(desc.samples)[:byte_len]
	sound := k2.load_sound_from_bytes_raw(data, format, int(desc.sample_rate), channels)
	if sound == k2.SOUND_NONE {return -1}
	state.sounds[slot] = sound
	state.sound_loaded[slot] = true
	state.sound_volume[slot] = desc.volume
	k2.set_sound_volume(sound, desc.volume * state.master_volume)
	return slot
}

karl2d_audio_unload_sound :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Karl2D_Audio_State)ctx
	if !karl2d_audio_sound_valid(state, sound_id) {return}
	k2.destroy_sound(state.sounds[sound_id])
	state.sounds[sound_id] = {}
	state.sound_loaded[sound_id] = false
	state.sound_volume[sound_id] = 0
}

karl2d_audio_play :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Karl2D_Audio_State)ctx
	if !karl2d_audio_sound_valid(state, sound_id) || !state.enabled {return}
	k2.play_sound(state.sounds[sound_id])
}

karl2d_audio_stop :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Karl2D_Audio_State)ctx
	if !karl2d_audio_sound_valid(state, sound_id) {return}
	k2.stop_sound(state.sounds[sound_id])
}

karl2d_audio_set_volume :: proc(ctx: rawptr, sound_id: int, volume: f32) {
	state := cast(^Karl2D_Audio_State)ctx
	if !karl2d_audio_sound_valid(state, sound_id) {return}
	state.sound_volume[sound_id] = clamp(volume, 0, 1)
	k2.set_sound_volume(state.sounds[sound_id], state.sound_volume[sound_id] * state.master_volume)
}

karl2d_audio_play_looped :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Karl2D_Audio_State)ctx
	if !karl2d_audio_sound_valid(state, sound_id) || !state.enabled {return}
	k2.set_sound_loop(state.sounds[sound_id], true)
	k2.play_sound(state.sounds[sound_id])
}

karl2d_audio_is_playing :: proc(ctx: rawptr, sound_id: int) -> bool {
	state := cast(^Karl2D_Audio_State)ctx
	if !karl2d_audio_sound_valid(state, sound_id) {return false}
	return k2.sound_is_playing(state.sounds[sound_id])
}

karl2d_audio_is_enabled :: proc(ctx: rawptr) -> bool {
	state := cast(^Karl2D_Audio_State)ctx
	return state != nil && state.enabled
}

karl2d_audio_set_enabled :: proc(ctx: rawptr, enabled: bool) -> bool {
	state := cast(^Karl2D_Audio_State)ctx
	if state == nil {return false}
	state.enabled = enabled
	return state.enabled
}

karl2d_audio_toggle :: proc(ctx: rawptr) -> bool {
	state := cast(^Karl2D_Audio_State)ctx
	if state == nil {return false}
	state.enabled = !state.enabled
	return state.enabled
}

karl2d_audio_set_master_volume :: proc(ctx: rawptr, volume: f32) {
	state := cast(^Karl2D_Audio_State)ctx
	if state == nil {return}
	state.master_volume = clamp(volume, 0, 1)
	for i in 0 ..< MAX_KARL2D_SOUNDS {
		if state.sound_loaded[i] {
			k2.set_sound_volume(state.sounds[i], state.sound_volume[i] * state.master_volume)
		}
	}
	for i in 0 ..< MAX_KARL2D_MUSIC {
		if state.music_loaded[i] {
			k2.set_sound_volume(state.music[i], state.music_volume[i] * state.master_volume)
		}
	}
}

karl2d_audio_update :: proc(ctx: rawptr) {
	k2.update_audio_mixer()
}

karl2d_audio_load_music :: proc(
	ctx: rawptr,
	format: string,
	data: rawptr,
	data_len: i32,
) -> eng.Engine_Music_Handle {
	state := cast(^Karl2D_Audio_State)ctx
	if state == nil || data == nil || data_len <= 0 {return nil}
	slot := karl2d_audio_first_free_music(state)
	if slot < 0 {return nil}
	bytes := ([^]u8)(data)[:int(data_len)]
	sound := k2.load_sound_from_bytes(bytes)
	if sound == k2.SOUND_NONE {return nil}
	state.music[slot] = sound
	state.music_loaded[slot] = true
	state.music_volume[slot] = 1
	return rawptr(&state.music[slot])
}

karl2d_audio_unload_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	state := cast(^Karl2D_Audio_State)ctx
	idx := karl2d_audio_music_index(state, handle)
	if idx < 0 {return}
	k2.destroy_sound(state.music[idx])
	state.music[idx] = {}
	state.music_loaded[idx] = false
	state.music_volume[idx] = 0
}

karl2d_audio_play_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	state := cast(^Karl2D_Audio_State)ctx
	idx := karl2d_audio_music_index(state, handle)
	if idx < 0 || !state.enabled {return}
	k2.play_sound(state.music[idx])
}

karl2d_audio_stop_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	state := cast(^Karl2D_Audio_State)ctx
	idx := karl2d_audio_music_index(state, handle)
	if idx < 0 {return}
	k2.stop_sound(state.music[idx])
}

karl2d_audio_pause_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	karl2d_audio_stop_music(ctx, handle)
}

karl2d_audio_resume_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	karl2d_audio_play_music(ctx, handle)
}

karl2d_audio_set_music_volume :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle, volume: f32) {
	state := cast(^Karl2D_Audio_State)ctx
	idx := karl2d_audio_music_index(state, handle)
	if idx < 0 {return}
	state.music_volume[idx] = clamp(volume, 0, 1)
	k2.set_sound_volume(state.music[idx], state.music_volume[idx] * state.master_volume)
}

karl2d_audio_update_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	k2.update_audio_mixer()
}

karl2d_audio_is_music_valid :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) -> bool {
	state := cast(^Karl2D_Audio_State)ctx
	return karl2d_audio_music_index(state, handle) >= 0
}

karl2d_audio_set_music_looping :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle, looping: bool) {
	state := cast(^Karl2D_Audio_State)ctx
	idx := karl2d_audio_music_index(state, handle)
	if idx < 0 {return}
	k2.set_sound_loop(state.music[idx], looping)
}

karl2d_audio_get_frame_time :: proc(ctx: rawptr) -> f32 {
	return k2.get_frame_time()
}

@(private = "file")
karl2d_audio_first_free_sound :: proc(state: ^Karl2D_Audio_State) -> int {
	for i in 0 ..< MAX_KARL2D_SOUNDS {
		if !state.sound_loaded[i] {return i}
	}
	return -1
}

@(private = "file")
karl2d_audio_first_free_music :: proc(state: ^Karl2D_Audio_State) -> int {
	for i in 0 ..< MAX_KARL2D_MUSIC {
		if !state.music_loaded[i] {return i}
	}
	return -1
}

@(private = "file")
karl2d_audio_sound_valid :: proc(state: ^Karl2D_Audio_State, sound_id: int) -> bool {
	return state != nil && sound_id >= 0 && sound_id < MAX_KARL2D_SOUNDS && state.sound_loaded[sound_id]
}

@(private = "file")
karl2d_audio_music_index :: proc(state: ^Karl2D_Audio_State, handle: eng.Engine_Music_Handle) -> int {
	if state == nil || handle == nil {return -1}
	for i in 0 ..< MAX_KARL2D_MUSIC {
		if rawptr(&state.music[i]) == handle && state.music_loaded[i] {return i}
	}
	return -1
}

@(private = "file")
karl2d_audio_channels :: proc(channels: u32) -> (k2.Audio_Channels, bool) {
	if channels == 1 {return .Mono, true}
	if channels == 2 {return .Stereo, true}
	return .Mono, false
}
