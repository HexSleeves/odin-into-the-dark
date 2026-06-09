package audio

import eng "../engine"

// ─── Audio manager facade ────────────────────────────────────────────────────
//
// Backend-agnostic. The default backend is karl2d audio; the Raylib backend is
// kept as a legacy desktop fallback.

Audio_Manager :: eng.Audio_Manager

audio_manager_make :: proc() -> Audio_Manager {
	return eng.audio_manager_make(g_audio.backend)
}

audio_manager_is_enabled :: proc(audio: ^Audio_Manager) -> bool {
	return eng.audio_manager_is_enabled(audio)
}

audio_manager_play_sfx :: proc(audio: ^Audio_Manager, stype: Sound_Type) {
	eng.audio_manager_play(audio, g_audio.sounds[stype])
}

audio_manager_toggle :: proc(audio: ^Audio_Manager) -> bool {
	return eng.audio_manager_toggle(audio)
}

audio_manager_stop_sfx :: proc(audio: ^Audio_Manager, stype: Sound_Type) {
	eng.audio_manager_stop(audio, g_audio.sounds[stype])
}

audio_manager_set_sfx_volume :: proc(audio: ^Audio_Manager, stype: Sound_Type, volume: f32) {
	eng.audio_manager_set_volume(audio, g_audio.sounds[stype], volume)
}

audio_manager_set_master_volume :: proc(audio: ^Audio_Manager, volume: f32) {
	eng.audio_manager_set_master_volume(audio, volume)
}

audio_manager_play_sfx_looped :: proc(audio: ^Audio_Manager, stype: Sound_Type) {
	eng.audio_manager_play_looped(audio, g_audio.sounds[stype])
}
