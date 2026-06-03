package main

import eng "./engine"
import rl "vendor:raylib"

// ─── Audio manager facade ────────────────────────────────────────────────────

Audio_Manager :: eng.Audio_Manager

audio_manager_make :: proc() -> Audio_Manager {
	return eng.audio_manager_make(game_audio_backend(&g_audio))
}

audio_manager_is_enabled :: proc(audio: ^Audio_Manager) -> bool {
	return eng.audio_manager_is_enabled(audio)
}

audio_manager_play_sfx :: proc(audio: ^Audio_Manager, stype: Sound_Type) {
	eng.audio_manager_play(audio, int(stype))
}

audio_manager_toggle :: proc(audio: ^Audio_Manager) -> bool {
	return eng.audio_manager_toggle(audio)
}

game_audio_backend :: proc(audio: ^Game_Audio) -> eng.Engine_Audio_Backend {
	return eng.Engine_Audio_Backend {
		ctx = audio,
		play = game_audio_backend_play,
		is_enabled = game_audio_backend_is_enabled,
		set_enabled = game_audio_backend_set_enabled,
		toggle = game_audio_backend_toggle,
		stop = game_audio_backend_stop,
		set_volume = game_audio_backend_set_volume,
		set_master_volume = game_audio_backend_set_master_volume,
		play_looped = game_audio_backend_play_looped,
		update = game_audio_backend_update,
	}
}

game_audio_backend_play :: proc(ctx: rawptr, sound_id: int) {
	audio := cast(^Game_Audio)ctx
	if audio == nil || !audio.enabled || sound_id < 0 || sound_id >= int(len(audio.sounds)) {
		return
	}
	rl.PlaySound(audio.sounds[Sound_Type(sound_id)])
}

game_audio_backend_is_enabled :: proc(ctx: rawptr) -> bool {
	audio := cast(^Game_Audio)ctx
	return audio != nil && audio.enabled
}

game_audio_backend_set_enabled :: proc(ctx: rawptr, enabled: bool) -> bool {
	audio := cast(^Game_Audio)ctx
	if audio == nil || !rl.IsAudioDeviceReady() {
		return false
	}
	audio.enabled = enabled
	return audio.enabled
}

game_audio_backend_toggle :: proc(ctx: rawptr) -> bool {
	audio := cast(^Game_Audio)ctx
	if audio == nil || !rl.IsAudioDeviceReady() {
		return false
	}
	audio.enabled = !audio.enabled
	return audio.enabled
}

audio_manager_stop_sfx :: proc(audio: ^Audio_Manager, stype: Sound_Type) {
	eng.audio_manager_stop(audio, int(stype))
}

audio_manager_set_sfx_volume :: proc(audio: ^Audio_Manager, stype: Sound_Type, volume: f32) {
	eng.audio_manager_set_volume(audio, int(stype), volume)
}

audio_manager_set_master_volume :: proc(audio: ^Audio_Manager, volume: f32) {
	eng.audio_manager_set_master_volume(audio, volume)
}

audio_manager_play_sfx_looped :: proc(audio: ^Audio_Manager, stype: Sound_Type) {
	eng.audio_manager_play_looped(audio, int(stype))
}

game_audio_backend_stop :: proc(ctx: rawptr, sound_id: int) {
	audio := cast(^Game_Audio)ctx
	if audio == nil || sound_id < 0 || sound_id >= int(len(audio.sounds)) {
		return
	}
	stype := Sound_Type(sound_id)
	audio.looping[stype] = false
	rl.StopSound(audio.sounds[stype])
}

game_audio_backend_set_volume :: proc(ctx: rawptr, sound_id: int, volume: f32) {
	audio := cast(^Game_Audio)ctx
	if audio == nil || sound_id < 0 || sound_id >= int(len(audio.sounds)) {
		return
	}
	rl.SetSoundVolume(audio.sounds[Sound_Type(sound_id)], volume)
}

game_audio_backend_set_master_volume :: proc(ctx: rawptr, volume: f32) {
	if !rl.IsAudioDeviceReady() {
		return
	}
	rl.SetMasterVolume(clamp(volume, 0, 1))
}

game_audio_backend_play_looped :: proc(ctx: rawptr, sound_id: int) {
	audio := cast(^Game_Audio)ctx
	if audio == nil || !audio.enabled || sound_id < 0 || sound_id >= int(len(audio.sounds)) {
		return
	}
	stype := Sound_Type(sound_id)
	audio.looping[stype] = true
	if !rl.IsSoundPlaying(audio.sounds[stype]) {
		rl.PlaySound(audio.sounds[stype])
	}
}

game_audio_backend_update :: proc(ctx: rawptr) {
	audio := cast(^Game_Audio)ctx
	if audio == nil || !audio.enabled {
		return
	}
	for stype in Sound_Type {
		if audio.looping[stype] && !rl.IsSoundPlaying(audio.sounds[stype]) {
			rl.PlaySound(audio.sounds[stype])
		}
	}
}
