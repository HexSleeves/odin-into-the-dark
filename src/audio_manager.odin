package main

import rl "vendor:raylib"

// ─── Audio manager facade ────────────────────────────────────────────────────

Audio_Manager :: struct {
	backend: ^Game_Audio,
}

audio_manager_make :: proc() -> Audio_Manager {
	return Audio_Manager {
		backend = &g_audio,
	}
}

audio_manager_is_enabled :: proc(audio: ^Audio_Manager) -> bool {
	if audio == nil || audio.backend == nil {
		return g_audio.enabled
	}
	return audio.backend.enabled
}

audio_manager_play_sfx :: proc(audio: ^Audio_Manager, stype: Sound_Type) {
	if audio == nil || audio.backend == nil {
		play_sfx(stype)
		return
	}
	if !audio.backend.enabled {
		return
	}
	rl.PlaySound(audio.backend.sounds[stype])
}

audio_manager_toggle :: proc(audio: ^Audio_Manager) -> bool {
	if audio == nil || audio.backend == nil || audio.backend == &g_audio {
		audio_toggle()
		return g_audio.enabled
	}
	audio.backend.enabled = !audio.backend.enabled
	return audio.backend.enabled
}

