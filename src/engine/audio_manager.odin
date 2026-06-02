package engine

Audio_Manager :: struct {
	backend: Engine_Audio_Backend,
}

audio_manager_make :: proc(backend: Engine_Audio_Backend) -> Audio_Manager {
	return Audio_Manager {
		backend = engine_audio_backend_or_default(backend),
	}
}

audio_manager_is_enabled :: proc(audio: ^Audio_Manager) -> bool {
	if audio == nil {
		return false
	}
	return engine_audio_backend_is_enabled(audio.backend)
}

audio_manager_set_enabled :: proc(audio: ^Audio_Manager, enabled: bool) -> bool {
	if audio == nil {
		return false
	}
	return engine_audio_backend_set_enabled(audio.backend, enabled)
}

audio_manager_toggle :: proc(audio: ^Audio_Manager) -> bool {
	if audio == nil {
		return false
	}
	return engine_audio_backend_toggle(audio.backend)
}

audio_manager_play :: proc(audio: ^Audio_Manager, sound_id: int) {
	if audio == nil {
		return
	}
	engine_audio_backend_play(audio.backend, sound_id)
}
