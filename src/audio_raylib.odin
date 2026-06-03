#+build !js
package main

import eng "./engine"
import rl "vendor:raylib"

// ─── Raylib audio backend implementation ─────────────────────────────────────
//
// Desktop only. Excluded from the JS/WASM build (no libraylib.a on web); the web
// build leaves config.audio unset, so the engine falls back to its nil audio
// backend. game_audio_backend's only callers are gated behind when ODIN_OS != .JS.

MAX_RAYLIB_SOUNDS :: 32

Raylib_Audio_State :: struct {
	sounds:  [MAX_RAYLIB_SOUNDS]rl.Sound,
	looping: [MAX_RAYLIB_SOUNDS]bool,
	count:   int,
	enabled: bool,
}

g_raylib_audio: Raylib_Audio_State

game_audio_backend :: proc(audio: ^Game_Audio) -> eng.Engine_Audio_Backend {
	return eng.Engine_Audio_Backend {
		ctx = &g_raylib_audio,
		init_audio = raylib_audio_init,
		shutdown_audio = raylib_audio_shutdown,
		is_audio_ready = raylib_audio_is_ready,
		load_sound = raylib_audio_load_sound,
		unload_sound = raylib_audio_unload_sound,
		play = raylib_audio_play,
		stop = raylib_audio_stop,
		set_volume = raylib_audio_set_volume,
		play_looped = raylib_audio_play_looped,
		is_playing = raylib_audio_is_playing,
		is_enabled = raylib_audio_is_enabled,
		set_enabled = raylib_audio_set_enabled,
		toggle = raylib_audio_toggle,
		set_master_volume = raylib_audio_set_master_volume,
		update = raylib_audio_update,
		load_music = raylib_audio_load_music,
		unload_music = raylib_audio_unload_music,
		play_music = raylib_audio_play_music,
		stop_music = raylib_audio_stop_music,
		pause_music = raylib_audio_pause_music,
		resume_music = raylib_audio_resume_music,
		set_music_volume = raylib_audio_set_music_volume,
		update_music = raylib_audio_update_music,
		is_music_valid = raylib_audio_is_music_valid,
		set_music_looping = raylib_audio_set_music_looping,
		get_frame_time = raylib_audio_get_frame_time,
	}
}

// ── Device lifecycle ──

raylib_audio_init :: proc(ctx: rawptr) -> bool {
	state := cast(^Raylib_Audio_State)ctx
	rl.InitAudioDevice()
	if !rl.IsAudioDeviceReady() {
		state.enabled = false
		return false
	}
	state.enabled = true
	return true
}

raylib_audio_shutdown :: proc(ctx: rawptr) {
	rl.CloseAudioDevice()
}

raylib_audio_is_ready :: proc(ctx: rawptr) -> bool {
	return rl.IsAudioDeviceReady()
}

// ── Sound loading ──

raylib_audio_load_sound :: proc(ctx: rawptr, desc: eng.Engine_Sound_Desc) -> int {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || state.count >= MAX_RAYLIB_SOUNDS {return -1}
	wave := rl.Wave {
		frameCount = desc.frame_count,
		sampleRate = desc.sample_rate,
		sampleSize = desc.sample_size,
		channels   = desc.channels,
		data       = desc.samples,
	}
	sound := rl.LoadSoundFromWave(wave)
	rl.SetSoundVolume(sound, desc.volume)
	id := state.count
	state.sounds[id] = sound
	state.count += 1
	return id
}

raylib_audio_unload_sound :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || sound_id < 0 || sound_id >= state.count {return}
	rl.UnloadSound(state.sounds[sound_id])
}

// ── Playback ──

raylib_audio_play :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || !state.enabled || sound_id < 0 || sound_id >= state.count {return}
	rl.PlaySound(state.sounds[sound_id])
}

raylib_audio_stop :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || sound_id < 0 || sound_id >= state.count {return}
	state.looping[sound_id] = false
	rl.StopSound(state.sounds[sound_id])
}

raylib_audio_set_volume :: proc(ctx: rawptr, sound_id: int, volume: f32) {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || sound_id < 0 || sound_id >= state.count {return}
	rl.SetSoundVolume(state.sounds[sound_id], volume)
}

raylib_audio_play_looped :: proc(ctx: rawptr, sound_id: int) {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || !state.enabled || sound_id < 0 || sound_id >= state.count {return}
	state.looping[sound_id] = true
	if !rl.IsSoundPlaying(state.sounds[sound_id]) {
		rl.PlaySound(state.sounds[sound_id])
	}
}

raylib_audio_is_playing :: proc(ctx: rawptr, sound_id: int) -> bool {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || sound_id < 0 || sound_id >= state.count {return false}
	return rl.IsSoundPlaying(state.sounds[sound_id])
}

// ── Global controls ──

raylib_audio_is_enabled :: proc(ctx: rawptr) -> bool {
	state := cast(^Raylib_Audio_State)ctx
	return state != nil && state.enabled
}

raylib_audio_set_enabled :: proc(ctx: rawptr, enabled: bool) -> bool {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || !rl.IsAudioDeviceReady() {return false}
	state.enabled = enabled
	return state.enabled
}

raylib_audio_toggle :: proc(ctx: rawptr) -> bool {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || !rl.IsAudioDeviceReady() {return false}
	state.enabled = !state.enabled
	return state.enabled
}

raylib_audio_set_master_volume :: proc(ctx: rawptr, volume: f32) {
	if !rl.IsAudioDeviceReady() {return}
	rl.SetMasterVolume(clamp(volume, 0, 1))
}

raylib_audio_update :: proc(ctx: rawptr) {
	state := cast(^Raylib_Audio_State)ctx
	if state == nil || !state.enabled {return}
	for i in 0 ..< state.count {
		if state.looping[i] && !rl.IsSoundPlaying(state.sounds[i]) {
			rl.PlaySound(state.sounds[i])
		}
	}
}

// ── Music ──

raylib_audio_load_music :: proc(
	ctx: rawptr,
	format: string,
	data: rawptr,
	data_len: i32,
) -> eng.Engine_Music_Handle {
	cs := rl.Music{}
	// Raylib needs a C-style extension string
	ext: cstring
	switch format {
	case ".wav":
		ext = ".wav"
	case ".ogg":
		ext = ".ogg"
	case ".mp3":
		ext = ".mp3"
	case:
		ext = ".wav"
	}
	cs = rl.LoadMusicStreamFromMemory(ext, data, data_len)
	handle := new(rl.Music)
	handle^ = cs
	return eng.Engine_Music_Handle(handle)
}

raylib_audio_unload_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	if handle == nil {return}
	m := cast(^rl.Music)handle
	rl.UnloadMusicStream(m^)
	free(m)
}

raylib_audio_play_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	if handle == nil {return}
	rl.PlayMusicStream((cast(^rl.Music)handle)^)
}

raylib_audio_stop_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	if handle == nil {return}
	rl.StopMusicStream((cast(^rl.Music)handle)^)
}

raylib_audio_pause_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	if handle == nil {return}
	rl.PauseMusicStream((cast(^rl.Music)handle)^)
}

raylib_audio_resume_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	if handle == nil {return}
	rl.ResumeMusicStream((cast(^rl.Music)handle)^)
}

raylib_audio_set_music_volume :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle, volume: f32) {
	if handle == nil {return}
	rl.SetMusicVolume((cast(^rl.Music)handle)^, volume)
}

raylib_audio_update_music :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) {
	if handle == nil {return}
	rl.UpdateMusicStream((cast(^rl.Music)handle)^)
}

raylib_audio_is_music_valid :: proc(ctx: rawptr, handle: eng.Engine_Music_Handle) -> bool {
	if handle == nil {return false}
	return rl.IsMusicValid((cast(^rl.Music)handle)^)
}

raylib_audio_set_music_looping :: proc(
	ctx: rawptr,
	handle: eng.Engine_Music_Handle,
	looping: bool,
) {
	if handle == nil {return}
	(cast(^rl.Music)handle).looping = looping
}

raylib_audio_get_frame_time :: proc(ctx: rawptr) -> f32 {
	return rl.GetFrameTime()
}
