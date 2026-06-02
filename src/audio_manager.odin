package main

import rl "vendor:raylib"
import eng "./engine"

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
